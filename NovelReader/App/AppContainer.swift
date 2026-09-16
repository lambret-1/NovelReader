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
         apiClient: GitHubAPIClient = .shared) {
        self.databaseManager = databaseManager
        self.apiClient = apiClient

        // Repository（先初始化，服务依赖这些 Repository）
        self.bookRepository = BookRepository(dbQueue: databaseManager.dbQueue)
        self.chapterRepository = ChapterRepository(dbQueue: databaseManager.dbQueue)
        self.bookmarkRepository = BookmarkRepository(dbQueue: databaseManager.dbQueue)
        self.readingProgressRepository = ReadingProgressRepository(dbQueue: databaseManager.dbQueue)
        self.syncMetadataRepository = SyncMetadataRepository(dbQueue: databaseManager.dbQueue)
        self.conflictRepository = ConflictRepository(dbQueue: databaseManager.dbQueue)

        // 服务
        self.authService = GitHubAuthService(apiClient: apiClient, syncMetadataRepository: syncMetadataRepository)
        self.fileService = GitHubFileService(apiClient: apiClient)
        self.gitService = GitHubGitService(apiClient: apiClient)
        self.updateService = UpdateCheckService(apiClient: apiClient)

        // SyncEngine
        self.syncEngine = SyncEngine(
            bookRepository: bookRepository,
            chapterRepository: chapterRepository,
            syncMetadataRepository: syncMetadataRepository,
            readingProgressRepository: readingProgressRepository,
            fileService: fileService,
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
        return LibraryViewController()
    }

    func makeChapterListViewController(book: Book) -> ChapterListViewController {
        return ChapterListViewController(book: book)
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

    func makeSyncViewController() -> SyncViewController {
        return SyncViewController()
    }

    func makeSettingsViewController() -> SettingsViewController {
        return SettingsViewController()
    }
}


