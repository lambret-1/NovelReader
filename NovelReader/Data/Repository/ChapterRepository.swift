import Foundation
import GRDB
import Combine

/// 章节仓库实现
final class ChapterRepository: ChapterRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func fetchChapters(bookId: String) -> AnyPublisher<[Chapter], Error> {
        Future { promise in
            do {
                let chapters = try self.dbQueue.read { db in
                    try Chapter
                        .filter(Column("bookId") == bookId)
                        .order(Column("sortOrder"))
                        .fetchAll(db)
                }
                promise(.success(chapters))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func fetchChapter(id: String) -> AnyPublisher<Chapter?, Error> {
        Future { promise in
            do {
                let chapter = try self.dbQueue.read { db in
                    try Chapter.filter(Column("id") == id).fetchOne(db)
                }
                promise(.success(chapter))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func createChapter(_ chapter: Chapter) -> AnyPublisher<Chapter, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try chapter.insert(db)
                }
                promise(.success(chapter))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func updateChapter(_ chapter: Chapter) -> AnyPublisher<Chapter, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try chapter.update(db)
                }
                promise(.success(chapter))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func deleteChapter(id: String) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    _ = try Chapter.filter(Column("id") == id).deleteAll(db)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func reorderChapters(_ chapters: [Chapter]) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    for chapter in chapters {
                        try chapter.update(db)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func fetchDirtyChapters() -> AnyPublisher<[Chapter], Error> {
        Future { promise in
            do {
                let chapters = try self.dbQueue.read { db in
                    try Chapter.filter(Column("isDirty") == true).fetchAll(db)
                }
                promise(.success(chapters))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func markChapterSynced(id: String) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    if var chapter = try Chapter.filter(Column("id") == id).fetchOne(db) {
                        chapter.isDirty = false
                        try chapter.update(db)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}

// MARK: - Chapter 的 GRDB 适配
extension Chapter: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "chapter" }
}
