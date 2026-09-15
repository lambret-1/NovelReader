import Foundation
import Combine

/// 获取所有书籍
struct FetchBooksUseCase {
    private let repository: BookRepositoryProtocol

    init(repository: BookRepositoryProtocol) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<[Book], Error> {
        repository.fetchAllBooks()
    }
}

/// 创建书籍
struct CreateBookUseCase {
    private let repository: BookRepositoryProtocol

    init(repository: BookRepositoryProtocol) {
        self.repository = repository
    }

    func execute(title: String, author: String = "") -> AnyPublisher<Book, Error> {
        let book = Book(title: title, author: author)
        return repository.createBook(book)
    }
}

/// 删除书籍（级联删除章节）
struct DeleteBookUseCase {
    private let bookRepository: BookRepositoryProtocol
    private let chapterRepository: ChapterRepositoryProtocol

    init(bookRepository: BookRepositoryProtocol, chapterRepository: ChapterRepositoryProtocol) {
        self.bookRepository = bookRepository
        self.chapterRepository = chapterRepository
    }

    func execute(bookId: String) -> AnyPublisher<Void, Error> {
        chapterRepository.fetchChapters(bookId: bookId)
            .flatMap { chapters -> AnyPublisher<Void, Error> in
                let deletes = chapters.map { self.chapterRepository.deleteChapter(id: $0.id) }
                return Publishers.MergeMany(deletes)
                    .collect()
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
            .flatMap { _ in self.bookRepository.deleteBook(id: bookId) }
            .eraseToAnyPublisher()
    }
}
