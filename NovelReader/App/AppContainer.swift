import Foundation
import Combine

/// 依赖注入容器 - 统一管理所有对象的创建和依赖关系
final class AppContainer {
    static let shared = AppContainer()

    // MARK: - 单例服务
    let databaseManager = DatabaseManager.shared
    let apiClient = GitHubAPIClient.shared
    let authService: GitHubAuthService
    let fileService: GitHubFileService
    let gitService: GitHubGitService

    // MARK: - Repository
    let bookRepository: BookRepository
    let chapterRepository: ChapterRepository
    let bookmarkRepository: BookmarkRepository
    let readingProgressRepository: ReadingProgressRepository
    let syncMetadataRepository: SyncMetadataRepository

    // MARK: - SyncEngine
    let syncEngine: SyncEngine

    private init() {
        // 服务
        self.authService = GitHubAuthService(apiClient: apiClient)
        self.fileService = GitHubFileService(apiClient: apiClient)
        self.gitService = GitHubGitService(apiClient: apiClient)

        // Repository
        self.bookRepository = BookRepository(dbQueue: databaseManager.dbQueue)
        self.chapterRepository = ChapterRepository(dbQueue: databaseManager.dbQueue)
        self.bookmarkRepository = BookmarkRepository(dbQueue: databaseManager.dbQueue)
        self.readingProgressRepository = ReadingProgressRepository(dbQueue: databaseManager.dbQueue)
        self.syncMetadataRepository = SyncMetadataRepository(dbQueue: databaseManager.dbQueue)

        // SyncEngine
        self.syncEngine = SyncEngine(
            bookRepository: bookRepository,
            chapterRepository: chapterRepository,
            syncMetadataRepository: syncMetadataRepository,
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

    func makeSettingsViewController() -> SettingsViewController {
        SettingsViewController()
    }
}
