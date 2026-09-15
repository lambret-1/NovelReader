import Foundation
import GRDB
import Combine

/// 书籍仓库实现
final class BookRepository: BookRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func fetchAllBooks() -> AnyPublisher<[Book], Error> {
        Future { promise in
            do {
                let books = try self.dbQueue.read { db in
                    try Book.order(Column("sortOrder")).fetchAll(db)
                }
                promise(.success(books))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func fetchBook(id: String) -> AnyPublisher<Book?, Error> {
        Future { promise in
            do {
                let book = try self.dbQueue.read { db in
                    try Book.filter(Column("id") == id).fetchOne(db)
                }
                promise(.success(book))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func createBook(_ book: Book) -> AnyPublisher<Book, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try book.insert(db)
                }
                promise(.success(book))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func updateBook(_ book: Book) -> AnyPublisher<Book, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try book.update(db)
                }
                promise(.success(book))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func deleteBook(id: String) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    _ = try Book.filter(Column("id") == id).deleteAll(db)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func reorderBooks(_ books: [Book]) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    for book in books {
                        try book.update(db)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}

// MARK: - Book 的 GRDB 适配
extension Book: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "book" }
}
