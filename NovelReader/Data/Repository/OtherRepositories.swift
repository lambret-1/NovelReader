import Foundation
import GRDB
import Combine

/// 书签仓库实现
final class BookmarkRepository: BookmarkRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func fetchBookmarks(bookId: String) -> AnyPublisher<[Bookmark], Error> {
        Future { promise in
            do {
                let bookmarks = try self.dbQueue.read { db in
                    try Bookmark
                        .filter(Column("bookId") == bookId)
                        .order(Column("createdAt").desc)
                        .fetchAll(db)
                }
                promise(.success(bookmarks))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func fetchAllBookmarks() -> AnyPublisher<[Bookmark], Error> {
        Future { promise in
            do {
                let bookmarks = try self.dbQueue.read { db in
                    try Bookmark
                        .order(Column("createdAt").desc)
                        .fetchAll(db)
                }
                promise(.success(bookmarks))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func createBookmark(_ bookmark: Bookmark) -> AnyPublisher<Bookmark, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try bookmark.insert(db)
                }
                promise(.success(bookmark))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func deleteBookmark(id: String) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    _ = try Bookmark.filter(Column("id") == id).deleteAll(db)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}

extension Bookmark: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "bookmark" }
}

/// 阅读进度仓库实现
final class ReadingProgressRepository: ReadingProgressRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func fetchProgress(bookId: String) -> AnyPublisher<ReadingProgress?, Error> {
        Future { promise in
            do {
                let progress = try self.dbQueue.read { db in
                    try ReadingProgress.filter(Column("bookId") == bookId).fetchOne(db)
                }
                promise(.success(progress))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func fetchAllProgresses() -> AnyPublisher<[ReadingProgress], Error> {
        Future { promise in
            do {
                let progresses = try self.dbQueue.read { db in
                    try ReadingProgress
                        .order(Column("updatedAt").desc)
                        .fetchAll(db)
                }
                promise(.success(progresses))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func saveProgress(_ progress: ReadingProgress) -> AnyPublisher<Void, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try progress.save(db) // save = insert or update
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}

extension ReadingProgress: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "readingProgress" }
}

/// 同步元数据仓库实现
final class SyncMetadataRepository: SyncMetadataRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func fetchMetadata() -> AnyPublisher<SyncMetadata, Error> {
        Future { promise in
            do {
                let metadata = try self.dbQueue.read { db -> SyncMetadata in
                    if let existing = try SyncMetadata.filter(Column("id") == SyncMetadata.sharedID).fetchOne(db) {
                        return existing
                    }
                    return SyncMetadata.default
                }
                promise(.success(metadata))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func updateMetadata(_ metadata: SyncMetadata) -> AnyPublisher<SyncMetadata, Error> {
        Future { promise in
            do {
                try self.dbQueue.write { db in
                    try metadata.save(db)
                }
                promise(.success(metadata))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}

extension SyncMetadata: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "syncMetadata" }
}
