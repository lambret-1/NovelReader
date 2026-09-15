import Foundation
import Combine

/// API 自动刷新书籍服务 - 从 MyNovels 仓库拉取书籍和章节
/// 仓库结构：顶层文件夹=书名，文件夹下文件=章节
final class NovelRefreshService {

    // MARK: - 单例
    static let shared = NovelRefreshService()

    // MARK: - 依赖
    private let fileService: GitHubFileService
    private let bookRepository: BookRepository
    private let chapterRepository: ChapterRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 刷新状态
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshProgress: Double = 0
    @Published private(set) var refreshMessage: String = ""

    // MARK: - 初始化
    init(fileService: GitHubFileService = GitHubFileService(),
         bookRepository: BookRepository = BookRepository(),
         chapterRepository: ChapterRepository = ChapterRepository()) {
        self.fileService = fileService
        self.bookRepository = bookRepository
        self.chapterRepository = chapterRepository
    }

    // MARK: - 公共方法

    /// 从 MyNovels 仓库刷新所有书籍
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名，默认 MyNovels
    /// - Returns: 刷新结果（新增书籍数、更新章节数）
    func refreshBooks(owner: String = "lambret-1", repo: String = "MyNovels") -> AnyPublisher<(addedBooks: Int, updatedChapters: Int), Error> {
        guard !isRefreshing else {
            return Fail(error: NSError(domain: "NovelRefresh", code: -1, userInfo: [NSLocalizedDescriptionKey: "正在刷新中，请稍候"]))
                .eraseToAnyPublisher()
        }

        isRefreshing = true
        refreshProgress = 0
        refreshMessage = "正在获取仓库文件列表..."

        return Future { [weak self] promise in
            guard let self = self else { return }

            // 1. 获取仓库完整文件树
            self.fileService.getRepositoryTree(owner: owner, repo: repo)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.isRefreshing = false
                        self.refreshMessage = "刷新失败: \(error.localizedDescription)"
                        promise(.failure(error))
                    }
                }, receiveValue: { tree in
                    self.refreshMessage = "解析书籍目录..."
                    self.refreshProgress = 0.1

                    // 2. 解析顶层文件夹为书籍
                    let bookFolders = self.extractBookFolders(from: tree)
                    self.refreshMessage = "发现 \(bookFolders.count) 本书籍，开始下载..."

                    // 3. 逐本书处理
                    self.processBooks(bookFolders, owner: owner, repo: repo)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            self.isRefreshing = false
                            if case .failure(let error) = completion {
                                self.refreshMessage = "刷新失败: \(error.localizedDescription)"
                                promise(.failure(error))
                            }
                        }, receiveValue: { result in
                            self.refreshProgress = 1.0
                            self.refreshMessage = "刷新完成：新增 \(result.addedBooks) 本书，更新 \(result.updatedChapters) 个章节"
                            promise(.success(result))
                        })
                        .store(in: &self.cancellables)
                })
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 私有方法

    /// 从文件树中提取顶层书籍文件夹
    private func extractBookFolders(from tree: GitTree) -> [String] {
        guard let items = tree.tree else { return [] }
        // 顶层文件夹（路径中不含 /）且类型为 tree
        let folders = items
            .filter { $0.type == "tree" && !$0.path.contains("/") }
            .map { $0.path }
            .sorted() // 按名称排序
        return folders
    }

    /// 从文件树中提取指定书籍下的章节文件
    private func extractChapterFiles(from tree: GitTree, bookFolder: String) -> [GitTreeItem] {
        guard let items = tree.tree else { return [] }
        // 路径以 "书名/" 开头，类型为 blob，且是 .md 或 .txt 文件
        let prefix = "\(bookFolder)/"
        return items
            .filter { item in
                item.type == "blob" &&
                item.path.hasPrefix(prefix) &&
                !item.path.hasPrefix("\(prefix).") // 排除隐藏文件
            }
            .sorted { $0.path < $1.path } // 按路径排序（文件名通常带序号）
    }

    /// 处理所有书籍
    private func processBooks(_ bookFolders: [String], owner: String, repo: String) -> AnyPublisher<(addedBooks: Int, updatedChapters: Int), Error> {
        let total = Double(bookFolders.count)
        var addedBooks = 0
        var updatedChapters = 0

        // 使用 Publishers.Sequence 逐本处理
        return Publishers.Sequence(sequence: bookFolders)
            .flatMap(maxPublishers: .max(1)) { folder -> AnyPublisher<Void, Error> in
                self.processSingleBook(folder, owner: owner, repo: repo)
                    .handleEvents(receiveOutput: { result in
                        addedBooks += result.addedBook ? 1 : 0
                        updatedChapters += result.updatedChapters
                    })
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
            .collect()
            .tryMap { _ in
                return (addedBooks, updatedChapters)
            }
            .eraseToAnyPublisher()
    }

    /// 处理单本书籍
    private func processSingleBook(_ folder: String, owner: String, repo: String) -> AnyPublisher<(addedBook: Bool, updatedChapters: Int), Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }

            // 1. 获取这本书的完整文件树（再次获取以确保拿到所有文件）
            self.fileService.getRepositoryTree(owner: owner, repo: repo)
                .flatMap { tree -> AnyPublisher<(Book, [GitTreeItem]), Error> in
                    // 2. 提取章节文件
                    let chapterFiles = self.extractChapterFiles(from: tree, bookFolder: folder)

                    // 3. 创建或获取书籍
                    return self.upsertBook(title: folder, remotePath: folder)
                        .map { book in (book, chapterFiles) }
                        .eraseToAnyPublisher()
                }
                .flatMap { (book, chapterFiles) -> AnyPublisher<(Book, Int), Error> in
                    // 4. 下载并保存所有章节
                    self.processChapters(chapterFiles, book: book, owner: owner, repo: repo)
                        .map { updatedCount in (book, updatedCount) }
                        .eraseToAnyPublisher()
                }
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.error("处理书籍 \(folder) 失败: \(error.localizedDescription)")
                        promise(.failure(error))
                    }
                }, receiveValue: { (book, updatedCount) in
                    let addedBook = book.createdAt.timeIntervalSinceNow > -60 // 刚创建的视为新增
                    promise(.success((addedBook, updatedCount)))
                })
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    /// 创建或更新书籍
    private func upsertBook(title: String, remotePath: String) -> AnyPublisher<Book, Error> {
        return bookRepository.fetchAllBooks()
            .flatMap { books -> AnyPublisher<Book, Error> in
                // 查找是否已存在（按 remotePath 或 title 匹配）
                if let existing = books.first(where: { $0.remotePath == remotePath || $0.title == title }) {
                    var updated = existing
                    updated.title = title
                    updated.updatedAt = Date()
                    return self.bookRepository.updateBook(updated)
                } else {
                    // 创建新书
                    let newBook = Book(title: title, remotePath: remotePath)
                    return self.bookRepository.createBook(newBook)
                }
            }
            .eraseToAnyPublisher()
    }

    /// 处理一本书的所有章节
    private func processChapters(_ chapterFiles: [GitTreeItem], book: Book, owner: String, repo: String) -> AnyPublisher<Int, Error> {
        let total = Double(chapterFiles.count)
        var updatedCount = 0

        guard !chapterFiles.isEmpty else {
            return Just(0).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return Publishers.Sequence(sequence: chapterFiles.enumerated())
            .flatMap(maxPublishers: .max(1)) { (index, file) -> AnyPublisher<Void, Error> in
                // 更新进度
                DispatchQueue.main.async {
                    self.refreshProgress = 0.1 + 0.9 * (Double(index) / total)
                    self.refreshMessage = "正在下载 \(book.title) - \(file.path.components(separatedBy: "/").last ?? "")"
                }

                // 下载章节内容并保存
                return self.downloadAndSaveChapter(file, book: book, owner: owner, repo: repo, sortOrder: index)
                    .handleEvents(receiveOutput: { updated in
                        if updated { updatedCount += 1 }
                    })
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
            .collect()
            .tryMap { _ in updatedCount }
            .eraseToAnyPublisher()
    }

    /// 下载并保存单个章节
    private func downloadAndSaveChapter(_ file: GitTreeItem, book: Book, owner: String, repo: String, sortOrder: Int) -> AnyPublisher<Bool, Error> {
        // 从路径提取章节标题（去掉 .md/.txt 后缀和序号前缀）
        let fileName = file.path.components(separatedBy: "/").last ?? file.path
        let title = extractChapterTitle(from: fileName)

        return fileService.getFileContent(owner: owner, repo: repo, path: file.path)
            .flatMap { content -> AnyPublisher<Bool, Error> in
                // 查找是否已存在该章节
                return self.chapterRepository.fetchChapters(bookId: book.id)
                    .flatMap { chapters -> AnyPublisher<Bool, Error> in
                        // 按 remotePath 或标题匹配
                        if let existing = chapters.first(where: { $0.remotePath == file.path || $0.title == title }) {
                            // 内容有变化才更新
                            let newHash = Chapter.hash(content: content)
                            if existing.contentHash != newHash {
                                var updated = existing
                                updated.updateContent(content)
                                updated.title = title
                                updated.sortOrder = sortOrder
                                updated.remotePath = file.path
                                return self.chapterRepository.updateChapter(updated)
                                    .map { _ in true }
                                    .eraseToAnyPublisher()
                            } else {
                                return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
                            }
                        } else {
                            // 创建新章节
                            let newChapter = Chapter(
                                bookId: book.id,
                                title: title,
                                content: content,
                                sortOrder: sortOrder,
                                remotePath: file.path
                            )
                            return self.chapterRepository.createChapter(newChapter)
                                .map { _ in true }
                                .eraseToAnyPublisher()
                        }
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// 从文件名提取章节标题
    /// 例如："001_第一章 初入江湖.md" -> "第一章 初入江湖"
    private func extractChapterTitle(from fileName: String) -> String {
        // 去掉文件扩展名
        var title = fileName
        if let dotRange = title.range(of: ".", options: .backwards) {
            title = String(title[..<dotRange.lowerBound])
        }
        // 去掉开头的序号前缀（如 "001_"、"01-"、"1."）
        if let range = title.range(of: #"^\d+[_\-\.\s]+"#, options: .regularExpression) {
            title = String(title[range.upperBound...])
        }
        return title.isEmpty ? fileName : title
    }
}
