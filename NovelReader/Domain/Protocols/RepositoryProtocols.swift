import Foundation
import Combine

/// 书籍仓库协议
protocol BookRepositoryProtocol {
    func fetchAllBooks() -> AnyPublisher<[Book], Error>
    func fetchBook(id: String) -> AnyPublisher<Book?, Error>
    func createBook(_ book: Book) -> AnyPublisher<Book, Error>
    func updateBook(_ book: Book) -> AnyPublisher<Book, Error>
    func deleteBook(id: String) -> AnyPublisher<Void, Error>
    func reorderBooks(_ books: [Book]) -> AnyPublisher<Void, Error>
}

/// 章节仓库协议
protocol ChapterRepositoryProtocol {
    func fetchChapters(bookId: String) -> AnyPublisher<[Chapter], Error>
    func fetchChapter(id: String) -> AnyPublisher<Chapter?, Error>
    func createChapter(_ chapter: Chapter) -> AnyPublisher<Chapter, Error>
    func updateChapter(_ chapter: Chapter) -> AnyPublisher<Chapter, Error>
    func deleteChapter(id: String) -> AnyPublisher<Void, Error>
    func reorderChapters(_ chapters: [Chapter]) -> AnyPublisher<Void, Error>
    func fetchDirtyChapters() -> AnyPublisher<[Chapter], Error>
    func markChapterSynced(id: String) -> AnyPublisher<Void, Error>
}

/// 书签仓库协议
protocol BookmarkRepositoryProtocol {
    func fetchBookmarks(bookId: String) -> AnyPublisher<[Bookmark], Error>
    func fetchAllBookmarks() -> AnyPublisher<[Bookmark], Error>
    func createBookmark(_ bookmark: Bookmark) -> AnyPublisher<Bookmark, Error>
    func deleteBookmark(id: String) -> AnyPublisher<Void, Error>
}

/// 阅读进度仓库协议
protocol ReadingProgressRepositoryProtocol {
    func fetchProgress(bookId: String) -> AnyPublisher<ReadingProgress?, Error>
    func fetchAllProgresses() -> AnyPublisher<[ReadingProgress], Error>
    func saveProgress(_ progress: ReadingProgress) -> AnyPublisher<Void, Error>
}

/// 同步元数据仓库协议
protocol SyncMetadataRepositoryProtocol {
    func fetchMetadata() -> AnyPublisher<SyncMetadata, Error>
    func updateMetadata(_ metadata: SyncMetadata) -> AnyPublisher<SyncMetadata, Error>
}
