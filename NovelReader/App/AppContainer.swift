import Foundation
import Combine

/// 依赖注入容器 - 统一管理所有对象的创建和依赖关系
final class AppContainer {
    /// 共享单例（向后兼容，新代码优先通过 init 注入）
    static let shared = AppContainer()

    // MARK: - 核心服务
    let databaseManager: DatabaseManager
    let apiClient: GitHubAPIClient
    let authService: GitHubAuthService
    let fileService: GitHubFileService
    let gitService: GitHubGitService
    let updateService: UpdateCheckService

    // MARK: - Repository
    let bookRepository: BookRepository
    let chapterRepository: ChapterRepository
    let bookmarkRepository: BookmarkRepository
    let readingProgressRepository: ReadingProgressRepository
    let syncMetadataRepository: SyncMetadataRepository
    let conflictRepository: ConflictRepository

    // MARK: - SyncEngine
    let syncEngine: SyncEngine

    // MARK: - 初始化

    /// 公开初始化方法，支持依赖注入和测试
    /// - Parameters:
    ///   - databaseManager: 数据库管理器，默认创建新实例
    ///   - apiClient: GitHub API 客户端，默认创建新实例
    init(databaseManager: DatabaseManager = DatabaseManager(),
         apiClient: GitHubAPIClient = GitHubAPIClient()) {
        self.databaseManager = databaseManager
        self.apiClient = apiClient

        // 服务
        self.authService = GitHubAuthService(apiClient: apiClient)
        self.fileService = GitHubFileService(apiClient: apiClient)
        self.gitService = GitHubGitService(apiClient: apiClient)
        self.updateService = UpdateCheckService(apiClient: apiClient)

        // Repository
        self.bookRepository = BookRepository(dbQueue: databaseManager.dbQueue)
        self.chapterRepository = ChapterRepository(dbQueue: databaseManager.dbQueue)
        self.bookmarkRepository = BookmarkRepository(dbQueue: databaseManager.dbQueue)
        self.readingProgressRepository = ReadingProgressRepository(dbQueue: databaseManager.dbQueue)
        self.syncMetadataRepository = SyncMetadataRepository(dbQueue: databaseManager.dbQueue)
        self.conflictRepository = ConflictRepository(dbQueue: databaseManager.dbQueue)

        // SyncEngine
        self.syncEngine = SyncEngine(
            bookRepository: bookRepository,
            chapterRepository: chapterRepository,
            syncMetadataRepository: syncMetadataRepository,
            conflictRepository: conflictRepository,
            readingProgressRepository: readingProgressRepository,
            fileService: fileService,
            gitService: gitService,
            apiClient: apiClient
        )
    }

    // MARK: - UseCase 工厂

    func makeFetchBooksUseCase() -> FetchBooksUseCase {
        FetchBooksUseCase(repository: bookRepository)
    }

    func makeCreateBookUseCase() -> CreateBookUseCase {
        CreateBookUseCase(repository: bookRepository)
    }

    func makeDeleteBookUseCase() -> DeleteBookUseCase {
        DeleteBookUseCase(bookRepository: bookRepository, chapterRepository: chapterRepository)
    }

    func makeFetchChaptersUseCase() -> FetchChaptersUseCase {
        FetchChaptersUseCase(repository: chapterRepository)
    }

    func makeCreateChapterUseCase() -> CreateChapterUseCase {
        CreateChapterUseCase(repository: chapterRepository)
    }

    func makeDeleteChapterUseCase() -> DeleteChapterUseCase {
        DeleteChapterUseCase(repository: chapterRepository)
    }

    func makeUpdateChapterContentUseCase() -> UpdateChapterContentUseCase {
        UpdateChapterContentUseCase(repository: chapterRepository)
    }

    func makeUpdateChapterTitleUseCase() -> UpdateChapterTitleUseCase {
        UpdateChapterTitleUseCase(repository: chapterRepository)
    }

    // MARK: - ViewController 工厂

    func makeLibraryViewController() -> LibraryViewController {
        let viewModel = LibraryViewModel(
            fetchBooksUseCase: makeFetchBooksUseCase(),
            createBookUseCase: makeCreateBookUseCase(),
            deleteBookUseCase: makeDeleteBookUseCase()
        )
        return LibraryViewController(viewModel: viewModel, readingProgressRepository: readingProgressRepository)
    }

    func makeChapterListViewController(book: Book) -> ChapterListViewController {
        let viewModel = ChapterListViewModel(
            book: book,
            fetchChaptersUseCase: makeFetchChaptersUseCase(),
            createChapterUseCase: makeCreateChapterUseCase(),
            deleteChapterUseCase: makeDeleteChapterUseCase()
        )
        return ChapterListViewController(book: book, viewModel: viewModel, readingProgressRepository: readingProgressRepository)
    }

    func makeReaderViewController(book: Book, chapters: [Chapter], startIndex: Int) -> ReaderViewController {
        let config = ReaderSettingsManager.shared.loadConfig()
        let viewModel = ReaderViewModel(
            config: config,
            readingProgressRepository: readingProgressRepository,
            bookmarkRepository: bookmarkRepository
        )
        return ReaderViewController(book: book, chapters: chapters, startIndex: startIndex, viewModel: viewModel)
    }

    func makeEditorViewController(chapter: Chapter) -> EditorViewController {
        let viewModel = EditorViewModel(
            updateContentUseCase: makeUpdateChapterContentUseCase(),
            updateTitleUseCase: makeUpdateChapterTitleUseCase()
        )
        return EditorViewController(chapter: chapter, viewModel: viewModel)
    }

    func makeSyncViewController() -> SyncViewController {
        let viewModel = SyncViewModel(
            authService: authService,
            syncEngine: syncEngine,
            syncMetadataRepository: syncMetadataRepository
        )
        return SyncViewController(viewModel: viewModel)
    }

    func makeConflictListViewController() -> ConflictListViewController {
        let viewModel = ConflictListViewModel(
            conflictRepository: conflictRepository,
            syncEngine: syncEngine
        )
        return ConflictListViewController(viewModel: viewModel)
    }

    func makeSettingsViewController() -> SettingsViewController {
        SettingsViewController()
    }

    func makeUpdateViewController(release: LatestRelease) -> UpdateViewController {
        UpdateViewController(release: release, updateService: updateService)
    }
}


