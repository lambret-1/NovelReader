import Foundation
import Combine

/// 同步引擎 - 负责本地与 GitHub 之间的全量/增量同步
final class SyncEngine: SyncEngineProtocol {

    // MARK: - 公开属性

    @Published private(set) var currentStatus: SyncStatus = .idle
    var statusPublisher: AnyPublisher<SyncStatus, Never> {
        $currentStatus.eraseToAnyPublisher()
    }

    // MARK: - 依赖

    private let bookRepository: BookRepositoryProtocol
    private let chapterRepository: ChapterRepositoryProtocol
    private let syncMetadataRepository: SyncMetadataRepositoryProtocol
    private let readingProgressRepository: ReadingProgressRepositoryProtocol?
    private let fileService: GitHubFileService
    private let gitService: GitHubGitService
    private let apiClient: GitHubAPIClient

    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.novelreader.sync", qos: .utility)

    // MARK: - 初始化

    init(bookRepository: BookRepositoryProtocol,
         chapterRepository: ChapterRepositoryProtocol,
         syncMetadataRepository: SyncMetadataRepositoryProtocol,
         readingProgressRepository: ReadingProgressRepositoryProtocol? = nil,
         fileService: GitHubFileService = GitHubFileService(),
         gitService: GitHubGitService = GitHubGitService(),
         apiClient: GitHubAPIClient = .shared) {
        self.bookRepository = bookRepository
        self.chapterRepository = chapterRepository
        self.syncMetadataRepository = syncMetadataRepository
        self.readingProgressRepository = readingProgressRepository
        self.fileService = fileService
        self.gitService = gitService
        self.apiClient = apiClient
    }

    // MARK: - 同步主流程

    func startSync() -> AnyPublisher<SyncResult, Error> {
        guard apiClient.isAuthenticated else {
            return Fail(error: SyncError.notAuthenticated).eraseToAnyPublisher()
        }

        guard !currentStatus.isSyncing else {
            return Fail(error: SyncError.syncInProgress).eraseToAnyPublisher()
        }

        return Future { [weak self] promise in
            guard let self = self else { return }
            self.currentStatus = .pulling(progress: 0)

            self.syncQueue.async {
                self.executeSync(promise: promise)
            }
        }.eraseToAnyPublisher()
    }

    private func executeSync(promise: @escaping (Result<SyncResult, Error>) -> Void) {
        var uploadedCount = 0
        var downloadedCount = 0
        var conflictCount = 0

        // 1. 获取同步元数据
        guard let metadata = try? awaitPublisher(syncMetadataRepository.fetchMetadata()) else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "获取同步元数据失败") }
            promise(.failure(SyncError.metadataError))
            return
        }

        guard let repoFullName = metadata.repoFullName else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "未配置同步仓库") }
            promise(.failure(SyncError.noRepositoryConfigured))
            return
        }

        let parts = repoFullName.components(separatedBy: "/")
        guard parts.count == 2 else {
            promise(.failure(SyncError.invalidRepositoryName))
            return
        }
        let owner = parts[0]
        let repo = parts[1]

        // 2. 确保仓库存在（不存在则自动创建）
        DispatchQueue.main.async { self.currentStatus = .pulling(progress: 0.1) }
        do {
            _ = try awaitPublisher(fileService.ensureRepositoryExists(owner: owner, repo: repo))
        } catch {
            DispatchQueue.main.async { self.currentStatus = .error(message: "仓库检查/创建失败: \(error.localizedDescription)") }
            promise(.failure(SyncError.repositoryNotFound))
            return
        }

        // 3. 拉取远端文件树（自动检测默认分支）
        DispatchQueue.main.async { self.currentStatus = .pulling(progress: 0.3) }

        guard let remoteTree = try? awaitPublisher(fileService.getRepositoryTree(owner: owner, repo: repo)) else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "拉取远端文件失败") }
            promise(.failure(SyncError.pullFailed))
            return
        }

        let remoteManifest = ManifestManager.generateRemoteManifest(from: remoteTree)

        // 4. 获取本地所有书籍和章节
        guard let books = try? awaitPublisher(bookRepository.fetchAllBooks()) else {
            promise(.failure(SyncError.localDataError))
            return
        }

        guard let allChapters = try? awaitPublisher(
            Publishers.MergeMany(books.map { chapterRepository.fetchChapters(bookId: $0.id) })
                .collect()
                .map { $0.flatMap { $0 } }
                .eraseToAnyPublisher()
        ) else {
            promise(.failure(SyncError.localDataError))
            return
        }

        let localManifest = ManifestManager.generateLocalManifest(books: books, chapters: allChapters)

        // 5. 对比差异
        let diffs = ManifestManager.diff(local: localManifest, remote: remoteManifest)

        DispatchQueue.main.async { self.currentStatus = .merging }

        // 6. 处理远端新增（下载到本地）
        let remoteChanges = diffs.filter { $0.type == .added }
        downloadedCount = remoteChanges.count

        for diff in remoteChanges {
            if let content = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: diff.path)) {
                applyRemoteContent(path: diff.path, content: content, books: books)
            }
        }

        // 7. 处理冲突（简化：保留本地版本上传）
        let conflicts = diffs.filter { $0.type == .conflict }
        conflictCount = conflicts.count

        // 8. 上传本地修改（只上传 dirty 章节和新增书籍）
        DispatchQueue.main.async { self.currentStatus = .pushing(progress: 0.5) }

        let localChanges = diffs.filter { $0.type == .localAdded || $0.type == .conflict }
        var filesToUpload: [String: String] = [:]

        for diff in localChanges {
            if let (content, _) = localContent(for: diff.path, books: books, chapters: allChapters) {
                filesToUpload[diff.path] = content
            }
        }

        if !filesToUpload.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let message = "Sync: \(filesToUpload.count) files updated at \(dateFormatter.string(from: Date()))"

            do {
                let commit = try awaitPublisher(fileService.writeFiles(owner: owner, repo: repo, files: filesToUpload, message: message))
                uploadedCount = filesToUpload.count

                // 标记章节已同步
                for chapter in allChapters {
                    if chapter.isDirty {
                        _ = try? awaitPublisher(chapterRepository.markChapterSynced(id: chapter.id))
                    }
                }

                // 更新书籍最后同步时间
                for book in books {
                    var updatedBook = book
                    updatedBook.lastSyncedAt = Date()
                    _ = try? awaitPublisher(bookRepository.updateBook(updatedBook))
                }

                // 更新同步元数据中的 commit SHA
                var updatedMetadata = metadata
                updatedMetadata.lastSyncCommitSHA = commit.sha
                updatedMetadata.lastSyncAt = Date()
                updatedMetadata.localManifestVersion += 1
                _ = try? awaitPublisher(syncMetadataRepository.updateMetadata(updatedMetadata))

            } catch {
                DispatchQueue.main.async { self.currentStatus = .error(message: "上传失败: \(error.localizedDescription)") }
                promise(.failure(SyncError.pushFailed))
                return
            }
        } else {
            // 无文件需要上传，仍更新同步时间
            var updatedMetadata = metadata
            updatedMetadata.lastSyncAt = Date()
            _ = try? awaitPublisher(syncMetadataRepository.updateMetadata(updatedMetadata))
        }

        DispatchQueue.main.async { self.currentStatus = .idle }

        let result = SyncResult(
            success: true,
            uploadedCount: uploadedCount,
            downloadedCount: downloadedCount,
            conflictCount: conflictCount,
            message: conflictCount > 0 ? "同步完成，有 \(conflictCount) 个冲突" : "同步完成"
        )
        promise(.success(result))
    }

    // MARK: - 冲突解决

    func resolveConflict(conflictId: String, resolution: ConflictItem.ConflictResolution) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    // MARK: - 私有工具方法

    /// 将远端内容应用到本地（用 sortOrder 匹配章节，避免标题修改导致重复）
    private func applyRemoteContent(path: String, content: String, books: [Book]) {
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else { return }

        let bookRemotePath = components[0]
        let fileName = components[1]

        // 找到对应书籍
        guard let book = books.first(where: { $0.remotePath == bookRemotePath }) else {
            // 远端有本地没有的书，自动创建
            let newBook = Book(title: bookRemotePath, remotePath: bookRemotePath)
            _ = try? awaitPublisher(bookRepository.createBook(newBook))
            return
        }

        if fileName == "meta.json" {
            // 更新书籍元数据（简化：不处理）
            return
        }

        if fileName.hasSuffix(".md") {
            let parsed = ManifestManager.parseChapterMarkdown(content)

            // 从文件名解析序号（文件名是 sortOrder+1，所以需要减 1）
            let orderPrefix = String(fileName.prefix(3))
            let sortOrder = max(0, (Int(orderPrefix) ?? 1) - 1)

            // 用 sortOrder 匹配本地章节（比标题匹配更可靠）
            if let chapters = try? awaitPublisher(chapterRepository.fetchChapters(bookId: book.id)),
               let chapter = chapters.first(where: { $0.sortOrder == sortOrder }) {
                // 更新已有章节
                var updated = chapter
                updated.title = parsed.title
                updated.updateContent(parsed.body)
                updated.isDirty = false
                _ = try? awaitPublisher(chapterRepository.updateChapter(updated))
            } else {
                // 创建新章节
                let newChapter = Chapter(
                    bookId: book.id,
                    title: parsed.title,
                    content: parsed.body,
                    sortOrder: sortOrder,
                    isDirty: false
                )
                _ = try? awaitPublisher(chapterRepository.createChapter(newChapter))
            }
        }
    }

    /// 获取本地文件内容（用于上传）
    private func localContent(for path: String, books: [Book], chapters: [Chapter]) -> (content: String, entry: ManifestEntry)? {
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else { return nil }

        let bookRemotePath = components[0]
        let fileName = components[1]

        guard let book = books.first(where: { $0.remotePath == bookRemotePath }) else { return nil }

        if fileName == "meta.json" {
            let content = bookMetaJSON(book)
            return (content, ManifestEntry(path: path, sha: Chapter.hash(content: content), size: content.utf8.count, lastModified: book.updatedAt.timeIntervalSince1970))
        }

        if fileName.hasSuffix(".md") {
            let bookChapters = chapters.filter { $0.bookId == book.id }
            if let chapter = bookChapters.first(where: { $0.remoteFileName() == fileName }) {
                let content = ManifestManager.chapterMarkdown(chapter: chapter)
                return (content, ManifestEntry(path: path, sha: Chapter.hash(content: content), size: content.utf8.count, lastModified: chapter.updatedAt.timeIntervalSince1970))
            }
        }

        return nil
    }

    private func bookMetaJSON(_ book: Book) -> String {
        let dict: [String: Any] = [
            "id": book.id,
            "title": book.title,
            "author": book.author,
            "created_at": ISO8601DateFormatter().string(from: book.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: book.updatedAt)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// 同步等待 Publisher 结果（在 syncQueue 中调用）
    private func awaitPublisher<T: Publisher>(_ publisher: T) throws -> T.Output {
        var result: Result<T.Output, Error>?
        let semaphore = DispatchSemaphore(value: 0)

        let cancellable = publisher
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    result = .failure(error)
                }
                semaphore.signal()
            }, receiveValue: { value in
                result = .success(value)
            })

        semaphore.wait()
        cancellable.cancel()

        guard let result = result else {
            throw SyncError.unknown
        }

        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    // MARK: - 阅读进度同步

    /// 同步阅读进度（上传本地进度 + 下载远端进度）
    func syncReadingProgress(repoFullName: String) {
        guard let progressRepo = readingProgressRepository else { return }

        let repoComponents = repoFullName.components(separatedBy: "/")
        guard repoComponents.count == 2 else { return }
        let owner = repoComponents[0]
        let repo = repoComponents[1]

        guard let books = try? awaitPublisher(bookRepository.fetchAllBooks()) else { return }

        // 上传本地阅读进度
        var progressList: [[String: Any]] = []
        for book in books {
            if let progress = try? awaitPublisher(progressRepo.fetchProgress(bookId: book.id)) {
                progressList.append([
                    "book_id": progress.bookId,
                    "chapter_id": progress.chapterId,
                    "offset": progress.offset,
                    "percent": progress.percent,
                    "updated_at": ISO8601DateFormatter().string(from: progress.updatedAt)
                ])
            }
        }

        if !progressList.isEmpty {
            let dict: [String: Any] = ["progresses": progressList]
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                _ = try? awaitPublisher(fileService.writeFile(
                    owner: owner,
                    repo: repo,
                    path: ".novel-sync/progress.json",
                    content: json,
                    message: "更新阅读进度"
                ))
            }
        }

        // 下载远端阅读进度（如果本地没有）
        if let remoteContent = try? awaitPublisher(fileService.getFileContent(
            owner: owner,
            repo: repo,
            path: ".novel-sync/progress.json"
        )) {
            if let data = remoteContent.data(using: String.Encoding.utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let progresses = dict["progresses"] as? [[String: Any]] {
                for item in progresses {
                    guard let bookId = item["book_id"] as? String,
                          let chapterId = item["chapter_id"] as? String,
                          let offset = item["offset"] as? Int,
                          let percent = item["percent"] as? Double else { continue }

                    if (try? awaitPublisher(progressRepo.fetchProgress(bookId: bookId))) == nil {
                        let progress = ReadingProgress(
                            bookId: bookId,
                            chapterId: chapterId,
                            offset: offset,
                            percent: percent,
                            updatedAt: Date()
                        )
                        _ = try? awaitPublisher(progressRepo.saveProgress(progress))
                    }
                }
            }
        }
    }
}

// MARK: - 同步错误

enum SyncError: LocalizedError {
    case notAuthenticated
    case syncInProgress
    case metadataError
    case noRepositoryConfigured
    case invalidRepositoryName
    case repositoryNotFound
    case pullFailed
    case pushFailed
    case localDataError
    case conflictNotResolved
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "未登录 GitHub"
        case .syncInProgress: return "同步正在进行中"
        case .metadataError: return "同步元数据错误"
        case .noRepositoryConfigured: return "未配置同步仓库"
        case .invalidRepositoryName: return "仓库名称无效"
        case .repositoryNotFound: return "同步仓库不存在且创建失败"
        case .pullFailed: return "拉取远端数据失败"
        case .pushFailed: return "上传本地数据失败"
        case .localDataError: return "本地数据读取失败"
        case .conflictNotResolved: return "存在未解决的冲突"
        case .unknown: return "未知错误"
        }
    }
}
