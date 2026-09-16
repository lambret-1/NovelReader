import Foundation
import Combine

/// 同步引擎 - 仅从 GitHub 下载数据到本地（单向同步）
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
    private let apiClient: GitHubAPIClient

    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.novelreader.sync", qos: .utility)

    // MARK: - 初始化

    init(bookRepository: BookRepositoryProtocol,
         chapterRepository: ChapterRepositoryProtocol,
         syncMetadataRepository: SyncMetadataRepositoryProtocol,
         readingProgressRepository: ReadingProgressRepositoryProtocol? = nil,
         fileService: GitHubFileService = GitHubFileService(),
         apiClient: GitHubAPIClient = .shared) {
        self.bookRepository = bookRepository
        self.chapterRepository = chapterRepository
        self.syncMetadataRepository = syncMetadataRepository
        self.readingProgressRepository = readingProgressRepository
        self.fileService = fileService
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
        var downloadedCount = 0

        // 1. 获取同步元数据
        guard let metadata = try? awaitPublisher(syncMetadataRepository.fetchMetadata()) else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "获取同步元数据失败") }
            promise(.failure(SyncError.metadataError))
            return
        }

        // 兜底逻辑：如果未配置同步仓库，使用默认的 用户名/MyNovels
        var repoFullName = metadata.repoFullName
        if repoFullName == nil {
            if let username = metadata.githubUsername {
                repoFullName = "\(username)/\(AppConfig.defaultRepoName)"
            } else {
                DispatchQueue.main.async { self.currentStatus = .error(message: "未配置同步仓库，请先登录 GitHub") }
                promise(.failure(SyncError.noRepositoryConfigured))
                return
            }
        }

        guard let repoName = repoFullName else {
            promise(.failure(SyncError.noRepositoryConfigured))
            return
        }
        let parts = repoName.components(separatedBy: "/")
        guard parts.count == 2 else {
            promise(.failure(SyncError.invalidRepositoryName))
            return
        }
        let owner = parts[0]
        let repo = parts[1]

        // 2. 拉取远端文件树
        DispatchQueue.main.async { self.currentStatus = .pulling(progress: 0.3) }

        var remoteTree: GitTree?
        do {
            remoteTree = try awaitPublisher(fileService.getRepositoryTree(owner: owner, repo: repo))
        } catch {
            AppLogger.error("拉取远端文件树失败: \(error.localizedDescription)")

            // 判断是否为空仓库
            let errorMsg = error.localizedDescription.lowercased()
            let isEmptyRepo = errorMsg.contains("not found") ||
                              errorMsg.contains("no commit") ||
                              errorMsg.contains("empty") ||
                              errorMsg.contains("409") ||
                              errorMsg.contains("git/refs")

            if isEmptyRepo {
                AppLogger.info("检测到空仓库，同步完成（无数据）")
                DispatchQueue.main.async { self.currentStatus = .idle }
                promise(.success(SyncResult(success: true, downloadedCount: 0, message: "同步完成（仓库为空）")))
                return
            }

            DispatchQueue.main.async {
                self.currentStatus = .error(message: "拉取远端文件失败: \(error.localizedDescription)")
            }
            promise(.failure(SyncError.pullFailed))
            return
        }

        guard let remoteTree = remoteTree else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "拉取远端文件失败") }
            promise(.failure(SyncError.pullFailed))
            return
        }

        // 3. 获取本地所有书籍（用于匹配和创建）
        guard let books = try? awaitPublisher(bookRepository.fetchAllBooks()) else {
            promise(.failure(SyncError.localDataError))
            return
        }

        // 4. 处理远端文件（下载到本地）
        let remoteFiles = (remoteTree.tree ?? []).filter { item in
            item.type == "blob" &&
            (item.path.hasSuffix(".md") || item.path.hasSuffix(".txt")) &&
            !item.path.hasPrefix(".") // 排除隐藏文件
        }
        let totalFiles = Double(remoteFiles.count)
        AppLogger.info("共发现 \(remoteFiles.count) 个章节文件待下载")

        for (index, item) in remoteFiles.enumerated() {
            // 更新进度（每下载一个文件更新一次，0.3→1.0）
            let progress = totalFiles > 0 ? 0.3 + (Double(index) / totalFiles) * 0.7 : 1.0
            DispatchQueue.main.async {
                self.currentStatus = .pulling(progress: progress)
            }

            // 下载文件内容
            if let fileContent = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: item.path)) {
                applyRemoteContent(path: item.path, content: fileContent, books: books)
                downloadedCount += 1
                AppLogger.info("已下载 \(index + 1)/\(remoteFiles.count): \(item.path)")
            }
        }

        // 5. 更新同步元数据
        var updatedMetadata = metadata
        updatedMetadata.lastSyncAt = Date()
        updatedMetadata.lastSyncCommitSHA = remoteTree.sha
        _ = try? awaitPublisher(syncMetadataRepository.updateMetadata(updatedMetadata))

        DispatchQueue.main.async { self.currentStatus = .idle }

        let result = SyncResult(
            success: true,
            downloadedCount: downloadedCount,
            message: "同步完成，下载 \(downloadedCount) 个章节"
        )
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
        var targetBook: Book?
        if let existing = books.first(where: { $0.remotePath == bookRemotePath }) {
            targetBook = existing
        } else {
            // 远端有本地没有的书，自动创建
            let newBook = Book(title: bookRemotePath, remotePath: bookRemotePath)
            if let created = try? awaitPublisher(bookRepository.createBook(newBook)) {
                targetBook = created
            }
        }

        guard let book = targetBook else { return }

        if fileName == "meta.json" {
            return // 不处理元数据文件
        }

        // 解析章节内容
        let parsed = ManifestManager.parseChapterMarkdown(content)

        // 使用自然排序从文件名提取章节序号（支持"第X章"格式）
        let chapterNum = NaturalSort.extractChapterNumber(from: fileName)
        let sortOrder = chapterNum == Int.max ? 0 : max(0, chapterNum - 1)

        // 用 sortOrder 匹配本地章节
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
}

// MARK: - 同步错误

enum SyncError: LocalizedError {
    case notAuthenticated
    case syncInProgress
    case metadataError
    case noRepositoryConfigured
    case invalidRepositoryName
    case pullFailed
    case localDataError
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "未登录 GitHub"
        case .syncInProgress: return "同步正在进行中"
        case .metadataError: return "同步元数据错误"
        case .noRepositoryConfigured: return "未配置同步仓库"
        case .invalidRepositoryName: return "仓库名称无效"
        case .pullFailed: return "拉取远端数据失败"
        case .localDataError: return "本地数据读取失败"
        case .unknown: return "未知错误"
        }
    }
}
