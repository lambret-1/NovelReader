import Foundation
import Combine

/// 同步引擎 - 双向同步（本地上传 + 远端下载 + 冲突处理 + 阅读进度/书签同步）
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
    private let bookmarkRepository: BookmarkRepositoryProtocol?
    private let conflictRepository: ConflictRepositoryProtocol?
    private let fileService: GitHubFileService
    private let apiClient: GitHubAPIClient

    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.novelreader.sync", qos: .utility)

    // MARK: - 初始化

    init(bookRepository: BookRepositoryProtocol,
         chapterRepository: ChapterRepositoryProtocol,
         syncMetadataRepository: SyncMetadataRepositoryProtocol,
         readingProgressRepository: ReadingProgressRepositoryProtocol? = nil,
         bookmarkRepository: BookmarkRepositoryProtocol? = nil,
         conflictRepository: ConflictRepositoryProtocol? = nil,
         fileService: GitHubFileService = GitHubFileService(),
         apiClient: GitHubAPIClient = .shared) {
        self.bookRepository = bookRepository
        self.chapterRepository = chapterRepository
        self.syncMetadataRepository = syncMetadataRepository
        self.readingProgressRepository = readingProgressRepository
        self.bookmarkRepository = bookmarkRepository
        self.conflictRepository = conflictRepository
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

    // MARK: - 双向同步核心执行

    private func executeSync(promise: @escaping (Result<SyncResult, Error>) -> Void) {
        var downloadedCount = 0
        var uploadedCount = 0
        var conflictCount = 0

        // 1. 获取同步元数据
        guard let metadata = try? awaitPublisher(syncMetadataRepository.fetchMetadata()) else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "获取同步元数据失败") }
            promise(.failure(SyncError.metadataError))
            return
        }

        // 2. 解析仓库全名（兜底：未配置时用 用户名/MyNovels）
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

        // 3. 确保仓库存在（不存在则自动创建私有仓库）
        DispatchQueue.main.async { self.currentStatus = .pulling(progress: 0.05) }
        do {
            _ = try awaitPublisher(fileService.ensureRepositoryExists(owner: owner, repo: repo))
            AppLogger.info("同步仓库已确认存在: \(owner)/\(repo)")
        } catch {
            AppLogger.error("确保仓库存在失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.currentStatus = .error(message: "同步仓库准备失败: \(error.localizedDescription)")
            }
            promise(.failure(SyncError.repositoryPrepareFailed))
            return
        }

        // 4. 拉取远端文件树
        DispatchQueue.main.async { self.currentStatus = .pulling(progress: 0.1) }

        var remoteTree: GitTree?
        do {
            remoteTree = try awaitPublisher(fileService.getRepositoryTree(owner: owner, repo: repo))
        } catch {
            AppLogger.error("拉取远端文件树失败: \(error.localizedDescription)")

            // 判断是否为空仓库（基于 HTTP 状态码，而非本地化错误消息）
            let isEmptyRepo = Self.isEmptyRepositoryError(error)

            if isEmptyRepo {
                AppLogger.info("检测到空仓库，仅执行本地上传")
                // 空仓库：跳过下载，直接走上传流程
                remoteTree = GitTree(sha: "", tree: [], truncated: false)
            } else {
                DispatchQueue.main.async {
                    self.currentStatus = .error(message: "拉取远端文件失败: \(error.localizedDescription)")
                }
                promise(.failure(SyncError.pullFailed))
                return
            }
        }

        guard let remoteTree = remoteTree else {
            DispatchQueue.main.async { self.currentStatus = .error(message: "拉取远端文件失败") }
            promise(.failure(SyncError.pullFailed))
            return
        }

        // 5. 获取本地所有数据（书籍、章节、阅读进度、书签）
        guard let books = try? awaitPublisher(bookRepository.fetchAllBooks()) else {
            promise(.failure(SyncError.localDataError))
            return
        }

        // 获取所有章节（按书籍分组）
        var allChapters: [Chapter] = []
        for book in books {
            if let chapters = try? awaitPublisher(chapterRepository.fetchChapters(bookId: book.id)) {
                allChapters.append(contentsOf: chapters)
            }
        }

        // 获取阅读进度
        var localProgresses: [ReadingProgress] = []
        if let progressRepo = readingProgressRepository,
           let progresses = try? awaitPublisher(progressRepo.fetchAllProgresses()) {
            localProgresses = progresses
        }

        // 获取书签
        var localBookmarks: [Bookmark] = []
        if let bookmarkRepo = bookmarkRepository,
           let bookmarks = try? awaitPublisher(bookmarkRepo.fetchAllBookmarks()) {
            localBookmarks = bookmarks
        }

        // 6. 生成本地/远端 Manifest 并差异对比
        let localManifest = ManifestManager.generateLocalManifest(books: books, chapters: allChapters)
        let remoteManifest = ManifestManager.generateRemoteManifest(from: remoteTree)
        let diffs = ManifestManager.diff(local: localManifest, remote: remoteManifest)

        // 7. 分类差异
        var remoteAddedChapterPaths: [String] = []   // 远端新增章节，待下载
        var remoteAddedMetaPaths: [String] = []       // 远端新增书籍元数据，待下载
        var localUploadFiles: [String: String] = [:]  // 待上传文件 [路径: 内容]
        var conflictPaths: [String] = []               // 冲突文件路径

        for diff in diffs {
            switch diff.type {
            case .added:
                // 远端新增
                if diff.path.hasSuffix("meta.json") {
                    remoteAddedMetaPaths.append(diff.path)
                } else {
                    remoteAddedChapterPaths.append(diff.path)
                }
            case .localAdded:
                // 本地新增，收集待上传
                if let content = Self.buildUploadContent(path: diff.path, books: books, chapters: allChapters) {
                    localUploadFiles[diff.path] = content
                }
            case .conflict:
                // 双方都修改：保留本地版本上传，记录冲突
                conflictPaths.append(diff.path)
                if let content = Self.buildUploadContent(path: diff.path, books: books, chapters: allChapters) {
                    localUploadFiles[diff.path] = content
                }
            case .unchanged, .deleted, .localDeleted, .localModified, .modified:
                break // P0 不处理删除同步
            }
        }

        conflictCount = conflictPaths.count
        if conflictCount > 0 {
            AppLogger.info("检测到 \(conflictCount) 个冲突文件，保留本地版本上传")
            // 记录冲突到数据库（不保存内容，仅记录路径和类型）
            for path in conflictPaths {
                let conflict = ConflictItem(
                    type: .contentModified,
                    localPath: path,
                    remotePath: path
                )
                if let conflictRepo = conflictRepository {
                    _ = try? awaitPublisher(conflictRepo.saveConflict(conflict))
                }
            }
        }

        // 8. 下载远端新增章节
        let totalDownloads = Double(remoteAddedChapterPaths.count)
        AppLogger.info("待下载章节数: \(remoteAddedChapterPaths.count)")

        for (index, path) in remoteAddedChapterPaths.enumerated() {
            let progress = totalDownloads > 0 ? 0.1 + (Double(index + 1) / totalDownloads) * 0.3 : 0.4
            DispatchQueue.main.async {
                self.currentStatus = .pulling(progress: progress)
            }

            if let fileContent = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: path)) {
                let success = applyRemoteChapter(path: path, content: fileContent, books: books)
                if success {
                    downloadedCount += 1
                }
                AppLogger.info("已下载 \(index + 1)/\(remoteAddedChapterPaths.count): \(path)")
            } else {
                AppLogger.error("下载失败: \(path)")
            }
        }

        // 9. 下载远端新增书籍元数据（更新 title/author，不动 sortOrder）
        for path in remoteAddedMetaPaths {
            if let metaContent = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: path)) {
                applyRemoteBookMeta(path: path, content: metaContent, books: books)
            }
        }

        // 10. 批量提交上传（本地新增 + 冲突保留本地 + 所有书籍元数据）
        // 确保每本书的 meta.json 都在上传列表中（元数据始终以本地为准）
        for book in books {
            let metaPath = "\(book.remotePath)/meta.json"
            localUploadFiles[metaPath] = ManifestManager.bookMetaJSON(book)
        }

        if !localUploadFiles.isEmpty {
            DispatchQueue.main.async { self.currentStatus = .pushing(progress: 0.5) }
            AppLogger.info("待上传文件数: \(localUploadFiles.count)")

            let uploadMessage = "同步更新：新增\(localUploadFiles.count - books.count)个文件，冲突\(conflictCount)个"
            do {
                _ = try awaitPublisher(fileService.writeFiles(
                    owner: owner,
                    repo: repo,
                    files: localUploadFiles,
                    message: uploadMessage
                ))
                uploadedCount = localUploadFiles.count - books.count // 扣除 meta.json
                if uploadedCount < 0 { uploadedCount = 0 }
                AppLogger.info("上传成功，共 \(localUploadFiles.count) 个文件")

                // 11. 标记已上传章节为已同步，并设置 remotePath
                markChaptersSynced(books: books, allChapters: allChapters)
            } catch {
                AppLogger.error("上传失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.currentStatus = .error(message: "上传失败: \(error.localizedDescription)")
                }
                promise(.failure(SyncError.pushFailed))
                return
            }
        } else {
            AppLogger.info("无待上传文件")
        }

        DispatchQueue.main.async { self.currentStatus = .pushing(progress: 0.85) }

        // 12. 同步阅读进度（last write wins）
        syncReadingProgress(owner: owner, repo: repo, books: books, allChapters: allChapters, localProgresses: localProgresses)

        // 13. 同步书签（合并去重）
        syncBookmarks(owner: owner, repo: repo, books: books, allChapters: allChapters, localBookmarks: localBookmarks)

        // 14. 更新同步元数据
        var updatedMetadata = metadata
        updatedMetadata.lastSyncAt = Date()
        updatedMetadata.lastSyncCommitSHA = remoteTree.sha.isEmpty ? nil : remoteTree.sha
        _ = try? awaitPublisher(syncMetadataRepository.updateMetadata(updatedMetadata))

        DispatchQueue.main.async { self.currentStatus = .idle }

        let result = SyncResult(
            success: true,
            downloadedCount: downloadedCount,
            uploadedCount: uploadedCount,
            conflictCount: conflictCount,
            message: "同步完成：下载 \(downloadedCount) 章，上传 \(uploadedCount) 章，冲突 \(conflictCount) 个（已保留本地版本）"
        )
        promise(.success(result))
    }

    // MARK: - 远端章节应用到本地

    /// 将远端章节内容应用到本地（优先用 remotePath 匹配，回退 sortOrder）
    /// - Returns: 是否成功创建或更新章节
    @discardableResult
    private func applyRemoteChapter(path: String, content: String, books: [Book]) -> Bool {
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else { return false }

        let bookRemotePath = components[0]
        let fileName = components[1]

        // 找到对应书籍（按 remotePath 匹配，没有则自动创建）
        var targetBook: Book?
        if let existing = books.first(where: { $0.remotePath == bookRemotePath }) {
            targetBook = existing
        } else {
            let newBook = Book(title: bookRemotePath, remotePath: bookRemotePath)
            if let created = try? awaitPublisher(bookRepository.createBook(newBook)) {
                targetBook = created
            }
        }

        guard let book = targetBook else { return false }

        // 解析章节内容（标题 + 正文）
        let parsed = ManifestManager.parseChapterMarkdown(content)

        // 获取本书所有章节
        guard let chapters = try? awaitPublisher(chapterRepository.fetchChapters(bookId: book.id)) else {
            return false
        }

        // 优先用 remotePath 精确匹配
        if let existing = chapters.first(where: { $0.remotePath == path }) {
            var updated = existing
            updated.title = parsed.title
            updated.updateContent(parsed.body)
            updated.isDirty = false
            updated.remotePath = path
            _ = try? awaitPublisher(chapterRepository.updateChapter(updated))
            return true
        }

        // 回退：用 sortOrder 匹配（从文件名提取章节序号）
        let chapterNum = NaturalSort.extractChapterNumber(from: fileName)
        if chapterNum != Int.max {
            let sortOrder = max(0, chapterNum - 1)
            if let existing = chapters.first(where: { $0.sortOrder == sortOrder }) {
                var updated = existing
                updated.title = parsed.title
                updated.updateContent(parsed.body)
                updated.isDirty = false
                updated.remotePath = path
                _ = try? awaitPublisher(chapterRepository.updateChapter(updated))
                return true
            }
        }

        // 都匹配不到，创建新章节
        let sortOrder = chapterNum == Int.max ? chapters.count : max(0, chapterNum - 1)
        let newChapter = Chapter(
            bookId: book.id,
            title: parsed.title,
            content: parsed.body,
            sortOrder: sortOrder,
            isDirty: false,
            remotePath: path
        )
        _ = try? awaitPublisher(chapterRepository.createChapter(newChapter))
        return true
    }

    // MARK: - 远端书籍元数据应用到本地

    /// 将远端书籍元数据应用到本地（更新 title/author，不动 sortOrder）
    private func applyRemoteBookMeta(path: String, content: String, books: [Book]) {
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else { return }
        let bookRemotePath = components[0]

        guard let meta = ManifestManager.parseBookMetaJSON(content),
              let existing = books.first(where: { $0.remotePath == bookRemotePath }) else {
            return
        }

        var updated = existing
        if !meta.title.isEmpty {
            updated.title = meta.title
        }
        updated.author = meta.author
        // sortOrder  intentionally 不更新：保持用户本地排序
        _ = try? awaitPublisher(bookRepository.updateBook(updated))
    }

    // MARK: - 构造上传文件内容

    /// 根据路径构造待上传文件内容
    /// - Parameters:
    ///   - path: 文件相对路径（如 "书名/001_第一章.md" 或 "书名/meta.json"）
    ///   - books: 本地书籍列表
    ///   - chapters: 本地所有章节
    /// - Returns: 文件内容字符串，无法构造时返回 nil
    private static func buildUploadContent(path: String, books: [Book], chapters: [Chapter]) -> String? {
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else { return nil }
        let bookRemotePath = components[0]
        let fileName = components[1]

        guard let book = books.first(where: { $0.remotePath == bookRemotePath }) else {
            return nil
        }

        if fileName == "meta.json" {
            return ManifestManager.bookMetaJSON(book)
        }

        // 章节文件：优先用 remotePath 匹配，回退用文件名匹配
        let bookChapters = chapters.filter { $0.bookId == book.id }
        if let chapter = bookChapters.first(where: { $0.remotePath == path }) {
            return ManifestManager.chapterMarkdown(chapter: chapter)
        }
        // 回退：remoteFileName 匹配
        if let chapter = bookChapters.first(where: { $0.remoteFileName() == fileName }) {
            return ManifestManager.chapterMarkdown(chapter: chapter)
        }
        return nil
    }

    // MARK: - 标记章节已同步

    /// 标记所有章节为已同步（isDirty=false），并确保 remotePath 已设置
    private func markChaptersSynced(books: [Book], allChapters: [Chapter]) {
        for book in books {
            let bookChapters = allChapters.filter { $0.bookId == book.id }
            for chapter in bookChapters {
                var updated = chapter
                updated.isDirty = false
                if updated.remotePath.isEmpty {
                    updated.remotePath = "\(book.remotePath)/\(chapter.remoteFileName())"
                }
                _ = try? awaitPublisher(chapterRepository.updateChapter(updated))
            }
        }
    }

    // MARK: - 阅读进度同步

    /// 同步阅读进度：下载远端 → 合并（last write wins）→ 上传
    private func syncReadingProgress(owner: String, repo: String, books: [Book], allChapters: [Chapter], localProgresses: [ReadingProgress]) {
        guard let progressRepo = readingProgressRepository else { return }

        // 1. 下载远端阅读进度
        var remoteProgressFile: RemoteReadingProgressFile?
        if let content = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: RemoteReadingProgressFile.filePath)) {
            remoteProgressFile = ManifestManager.parseProgressJSON(content)
        }

        // 2. 合并：按 bookPath + chapterPath 为 key，last write wins
        var mergedDict: [String: RemoteReadingProgress] = [:]

        // 先放入远端进度
        if let remote = remoteProgressFile {
            for rp in remote.progresses {
                let key = "\(rp.bookPath)|\(rp.chapterPath)"
                mergedDict[key] = rp
            }
        }

        // 本地进度转换为远端格式，与远端比较 updatedAt
        let localRemote = ManifestManager.makeRemoteProgresses(progresses: localProgresses, books: books, chapters: allChapters)
        for rp in localRemote.progresses {
            let key = "\(rp.bookPath)|\(rp.chapterPath)"
            if let existing = mergedDict[key] {
                // 双方都有：取 updatedAt 较新的
                if rp.updatedAt >= existing.updatedAt {
                    mergedDict[key] = rp
                }
            } else {
                mergedDict[key] = rp
            }
        }

        let mergedFile = RemoteReadingProgressFile(progresses: Array(mergedDict.values))

        // 3. 将合并后的进度应用到本地（远端更新的进度需要写入本地数据库）
        let bookMap = Dictionary(uniqueKeysWithValues: books.map { ($0.remotePath, $0) })
        let chapterMap = Dictionary(uniqueKeysWithValues: allChapters.map { ($0.remotePath.isEmpty ? "\(bookMap[$0.bookId]?.remotePath ?? "")/\($0.remoteFileName())" : $0.remotePath, $0) })

        for rp in mergedFile.progresses {
            guard let book = bookMap[rp.bookPath] else { continue }
            // 查找本地章节：优先 remotePath 匹配，回退 sortOrder
            var targetChapter: Chapter?
            if let chapter = chapterMap[rp.chapterPath] {
                targetChapter = chapter
            } else {
                let bookChapters = allChapters.filter { $0.bookId == book.id }
                targetChapter = bookChapters.first(where: { $0.sortOrder == rp.chapterSortOrder })
            }
            guard let chapter = targetChapter else { continue }

            let progress = ReadingProgress(
                bookId: book.id,
                chapterId: chapter.id,
                offset: rp.offset,
                percent: rp.percent,
                updatedAt: Date(timeIntervalSince1970: rp.updatedAt)
            )
            _ = try? awaitPublisher(progressRepo.saveProgress(progress))
        }

        // 4. 上传合并后的阅读进度
        let progressJSON = ManifestManager.progressJSON(mergedFile)
        do {
            _ = try awaitPublisher(fileService.writeFile(
                owner: owner,
                repo: repo,
                path: RemoteReadingProgressFile.filePath,
                content: progressJSON,
                message: "同步阅读进度"
            ))
            AppLogger.info("阅读进度同步完成")
        } catch {
            AppLogger.error("阅读进度上传失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 书签同步

    /// 同步书签：下载远端 → 合并去重 → 上传
    private func syncBookmarks(owner: String, repo: String, books: [Book], allChapters: [Chapter], localBookmarks: [Bookmark]) {
        guard let bookmarkRepo = bookmarkRepository else { return }

        // 1. 下载远端书签
        var remoteBookmarkFile: RemoteBookmarkFile?
        if let content = try? awaitPublisher(fileService.getFileContent(owner: owner, repo: repo, path: RemoteBookmarkFile.filePath)) {
            remoteBookmarkFile = ManifestManager.parseBookmarksJSON(content)
        }

        // 2. 合并去重：按 bookPath + chapterPath + offset 为 key
        var mergedDict: [String: RemoteBookmark] = [:]

        // 先放入远端书签
        if let remote = remoteBookmarkFile {
            for bm in remote.bookmarks {
                let key = "\(bm.bookPath)|\(bm.chapterPath)|\(bm.offset)"
                mergedDict[key] = bm
            }
        }

        // 本地书签转换为远端格式，同一位置保留本地（本地可能有笔记）
        let localRemote = ManifestManager.makeRemoteBookmarks(bookmarks: localBookmarks, books: books, chapters: allChapters)
        for bm in localRemote.bookmarks {
            let key = "\(bm.bookPath)|\(bm.chapterPath)|\(bm.offset)"
            // 本地优先（保留本地笔记）
            mergedDict[key] = bm
        }

        let mergedFile = RemoteBookmarkFile(bookmarks: Array(mergedDict.values))

        // 3. 将远端新增的书签写入本地数据库
        let bookMap = Dictionary(uniqueKeysWithValues: books.map { ($0.remotePath, $0) })
        let localKeySet = Set(localBookmarks.map { bm -> String in
            let book = books.first(where: { $0.id == bm.bookId })
            let chapter = allChapters.first(where: { $0.id == bm.chapterId })
            let chapterPath = chapter?.remotePath.isEmpty == false ? chapter!.remotePath : "\(book?.remotePath ?? "")/\(chapter?.remoteFileName() ?? "")"
            return "\(book?.remotePath ?? "")|\(chapterPath)|\(bm.offset)"
        })

        for bm in mergedFile.bookmarks {
            let key = "\(bm.bookPath)|\(bm.chapterPath)|\(bm.offset)"
            guard !localKeySet.contains(key) else { continue } // 本地已有，跳过

            guard let book = bookMap[bm.bookPath] else { continue }
            // 查找本地章节
            let bookChapters = allChapters.filter { $0.bookId == book.id }
            var targetChapter: Chapter?
            if let chapter = bookChapters.first(where: { $0.remotePath == bm.chapterPath }) {
                targetChapter = chapter
            } else {
                targetChapter = bookChapters.first(where: { $0.sortOrder == bm.chapterSortOrder })
            }
            guard let chapter = targetChapter else { continue }

            let bookmark = Bookmark(
                bookId: book.id,
                chapterId: chapter.id,
                offset: bm.offset,
                textExcerpt: bm.textExcerpt,
                note: bm.note,
                createdAt: Date(timeIntervalSince1970: bm.createdAt)
            )
            _ = try? awaitPublisher(bookmarkRepo.createBookmark(bookmark))
        }

        // 4. 上传合并后的书签
        let bookmarksJSON = ManifestManager.bookmarksJSON(mergedFile)
        do {
            _ = try awaitPublisher(fileService.writeFile(
                owner: owner,
                repo: repo,
                path: RemoteBookmarkFile.filePath,
                content: bookmarksJSON,
                message: "同步书签"
            ))
            AppLogger.info("书签同步完成")
        } catch {
            AppLogger.error("书签上传失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 空仓库错误判断

    /// 判断错误是否为空仓库（基于 GitHub 错误类型和状态码，而非本地化字符串）
    private static func isEmptyRepositoryError(_ error: Error) -> Bool {
        if case let GitHubError.apiError(_, statusCode) = error {
            // 空仓库 Git Data API 返回 409
            return statusCode == 409
        }
        if case let GitHubError.httpError(statusCode) = error {
            return statusCode == 409
        }
        return false
    }

    // MARK: - 私有工具方法

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
    case repositoryPrepareFailed
    case pullFailed
    case pushFailed
    case localDataError
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "未登录 GitHub"
        case .syncInProgress: return "同步正在进行中"
        case .metadataError: return "同步元数据错误"
        case .noRepositoryConfigured: return "未配置同步仓库"
        case .invalidRepositoryName: return "仓库名称无效"
        case .repositoryPrepareFailed: return "同步仓库准备失败"
        case .pullFailed: return "拉取远端数据失败"
        case .pushFailed: return "上传本地数据失败"
        case .localDataError: return "本地数据读取失败"
        case .unknown: return "未知错误"
        }
    }
}
