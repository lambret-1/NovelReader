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
    private let conflictRepository: ConflictRepositoryProtocol
    private let readingProgressRepository: ReadingProgressRepositoryProtocol?
    private let fileService: GitHubFileService
    private let gitService: GitHubGitService
    private let apiClient: GitHubAPIClient

    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.novelreader.sync", qos: .utility)

    /// 暂停的同步上下文（冲突等待用户解决时保存）
    private struct PendingSyncContext {
        let promise: (Result<SyncResult, Error>) -> Void
        let metadata: SyncMetadata
        let owner: String
        let repo: String
        let books: [Book]
        let allChapters: [Chapter]
        let diffs: [FileDiff]
        let downloadedCount: Int
    }
    private var pendingContext: PendingSyncContext?

    // MARK: - 初始化

    init(bookRepository: BookRepositoryProtocol,
         chapterRepository: ChapterRepositoryProtocol,
         syncMetadataRepository: SyncMetadataRepositoryProtocol,
         conflictRepository: ConflictRepositoryProtocol,
         readingProgressRepository: ReadingProgressRepositoryProtocol? = nil,
         fileService: GitHubFileService = GitHubFileService(),
         gitService: GitHubGitService = GitHubGitService(),
         apiClient: GitHubAPIClient = .shared) {
        self.bookRepository = bookRepository
        self.chapterRepository = chapterRepository
        self.syncMetadataRepository = syncMetadataRepository
        self.conflictRepository = conflictRepository
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

        // 1.5 清除所有未解决的冲突（强制以GitHub远端为准，不再等待用户解决）
        _ = try? awaitPublisher(conflictRepository.clearAllConflicts())
        pendingContext = nil

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

        // 拉取远端文件树（使用 do-catch 捕获具体错误，避免静默失败）
        var remoteTree: GitTree?
        do {
            remoteTree = try awaitPublisher(fileService.getRepositoryTree(owner: owner, repo: repo))
        } catch {
            // 打印详细错误信息，方便定位问题
            AppLogger.error("拉取远端文件树失败: \(error.localizedDescription)")
            
            // 判断是否为空仓库（无分支/无commit），空仓库时视为远端无文件，继续同步流程
            let errorMsg = error.localizedDescription.lowercased()
            let isEmptyRepo = errorMsg.contains("not found") || 
                              errorMsg.contains("no commit") || 
                              errorMsg.contains("empty") ||
                              errorMsg.contains("409") ||
                              errorMsg.contains("git/refs")
            
            if isEmptyRepo {
                AppLogger.info("检测到空仓库，视为远端无文件，继续同步流程")
                // 空仓库：设置空的remoteTree，继续执行同步流程
                remoteTree = GitTree(sha: "", tree: [], truncated: false)
                // 继续执行下面的同步流程
            } else {
            
            DispatchQueue.main.async {
                self.currentStatus = .error(message: "拉取远端文件失败: \(error.localizedDescription)")
            }
            promise(.failure(SyncError.pullFailed))
            return
        }

        var uploadedCount = 0
        var downloadedCount = 0
        var conflictCount = 0

        guard let remoteTree = remoteTree else {
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

        // 7. 处理冲突：强制以GitHub远端为准，直接下载远端内容覆盖本地，不暂停同步
        let conflicts = diffs.filter { $0.type == .conflict }
        conflictCount = conflicts.count

        if !conflicts.isEmpty {
            AppLogger.info("检测到 \(conflicts.count) 个冲突，强制以远端版本覆盖本地")
            for diff in conflicts {
                if let remoteContent = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: diff.path)) {
                    applyRemoteContent(path: diff.path, content: remoteContent, books: books)
                    downloadedCount += 1
                }
            }
            // 冲突已用远端版本解决，清除冲突记录
            _ = try? awaitPublisher(conflictRepository.clearAllConflicts())
        }

        // 8. 上传本地修改（只上传 dirty 章节和新增书籍）
        DispatchQueue.main.async { self.currentStatus = .pushing(progress: 0.5) }

        let localAdded = diffs.filter { $0.type == .localAdded }
        // 冲突文件已用远端版本覆盖本地，不再上传
        let localChanges = localAdded
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


    }
    // MARK: - 冲突解决

    func resolveConflict(conflictId: String, resolution: ConflictItem.ConflictResolution) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { promise(.success(())); return }
            _ = try? awaitPublisher(self.conflictRepository.updateResolution(conflictId: conflictId, resolution: resolution))

            self.syncQueue.async {
                guard let conflicts = try? self.awaitPublisher(self.conflictRepository.fetchAllConflicts()),
                      let conflict = conflicts.first(where: { $0.id == conflictId }) else {
                    promise(.success(()))
                    return
                }

                switch resolution {
                case .keepLocal:
                    break
                case .keepRemote:
                    if let remoteContent = conflict.remoteContent {
                        self.applyRemoteContent(path: conflict.remotePath, content: remoteContent, books: self.pendingContext?.books ?? [])
                    }
                case .keepBoth:
                    if let remoteContent = conflict.remoteContent,
                       let localContent = conflict.localContent {
                        let merged = localContent + "\n\n--- 远端版本 ---\n\n" + remoteContent
                        self.applyRemoteContent(path: conflict.localPath, content: merged, books: self.pendingContext?.books ?? [])
                    }
                case .manual:
                    if let localContent = conflict.localContent {
                        self.applyRemoteContent(path: conflict.localPath, content: localContent, books: self.pendingContext?.books ?? [])
                    }
                }
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    func continueSyncAfterConflictsResolved() -> AnyPublisher<SyncResult, Error> {
        return Future { [weak self] promise in
            guard let self = self, let context = self.pendingContext else {
                promise(.failure(SyncError.unknown))
                return
            }
            guard let unresolvedCount = try? awaitPublisher(self.conflictRepository.unresolvedCount()),
                  unresolvedCount == 0 else {
                promise(.failure(SyncError.conflictNotResolved))
                return
            }
            self.pendingContext = nil
            self.syncQueue.async {
                self.continueUploadPhase(
                    promise: context.promise,
                    metadata: context.metadata,
                    owner: context.owner,
                    repo: context.repo,
                    books: context.books,
                    allChapters: context.allChapters,
                    diffs: context.diffs,
                    downloadedCount: context.downloadedCount
                )
            }
        }.eraseToAnyPublisher()
    }

    func abortSync() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { promise(.success(())); return }
            _ = try? awaitPublisher(self.conflictRepository.clearAllConflicts())
            self.pendingContext = nil
            DispatchQueue.main.async { self.currentStatus = .idle }
            promise(.success(()))
        }.eraseToAnyPublisher()
    }

    private func continueUploadPhase(promise: @escaping (Result<SyncResult, Error>) -> Void,
                                     metadata: SyncMetadata,
                                     owner: String,
                                     repo: String,
                                     books: [Book],
                                     allChapters: [Chapter],
                                     diffs: [FileDiff],
                                     downloadedCount: Int) {
        var uploadedCount = 0
        DispatchQueue.main.async { self.currentStatus = .pushing(progress: 0.5) }

        let localAdded = diffs.filter { $0.type == .localAdded }
        // 冲突文件已用远端版本覆盖本地，不再上传
        let localChanges = localAdded
        var filesToUpload: [String: String] = [:]
        for diff in localChanges {
            if let (content, _) = localContent(for: diff.path, books: books, chapters: allChapters) {
                filesToUpload[diff.path] = content
            }
        }

        if !filesToUpload.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let message = "Sync: \(filesToUpload.count) files (conflicts resolved) at \(dateFormatter.string(from: Date()))"
            do {
                let commit = try awaitPublisher(fileService.writeFiles(owner: owner, repo: repo, files: filesToUpload, message: message))
                uploadedCount = filesToUpload.count
                for chapter in allChapters {
                    if chapter.isDirty {
                        _ = try? awaitPublisher(chapterRepository.markChapterSynced(id: chapter.id))
                    }
                }
                for book in books {
                    var updatedBook = book
                    updatedBook.lastSyncedAt = Date()
                    _ = try? awaitPublisher(bookRepository.updateBook(updatedBook))
                }
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
            var updatedMetadata = metadata
            updatedMetadata.lastSyncAt = Date()
            _ = try? awaitPublisher(syncMetadataRepository.updateMetadata(updatedMetadata))
        }

        _ = try? awaitPublisher(conflictRepository.clearAllConflicts())
        DispatchQueue.main.async { self.currentStatus = .idle }
        let result = SyncResult(success: true, uploadedCount: uploadedCount, downloadedCount: downloadedCount, conflictCount: 0, message: "同步完成（冲突已解决）")
        promise(.success(result))
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

            // 使用自然排序从文件名提取章节序号（支持"第X章"格式）
            let chapterNum = NaturalSort.extractChapterNumber(from: fileName)
            let sortOrder = chapterNum == Int.max ? 0 : max(0, chapterNum - 1)

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

