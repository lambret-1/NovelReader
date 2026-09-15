import Foundation
import GRDB
import Combine

/// 冲突项数据仓库协议
protocol ConflictRepositoryProtocol {
    func fetchUnresolvedConflicts() -> AnyPublisher<[ConflictItem], Error>
    func fetchAllConflicts() -> AnyPublisher<[ConflictItem], Error>
    func saveConflict(_ conflict: ConflictItem) -> AnyPublisher<Void, Error>
    func saveConflicts(_ conflicts: [ConflictItem]) -> AnyPublisher<Void, Error>
    func updateResolution(conflictId: String, resolution: ConflictItem.ConflictResolution) -> AnyPublisher<Void, Error>
    func deleteConflict(conflictId: String) -> AnyPublisher<Void, Error>
    func clearAllConflicts() -> AnyPublisher<Void, Error>
    func unresolvedCount() -> AnyPublisher<Int, Error>
}

/// 冲突项数据库记录
struct ConflictRecord: Codable, FetchableRecord, PersistableRecord {
    let id: String
    let type: String
    let localPath: String
    let remotePath: String
    let localContent: String?
    let remoteContent: String?
    let resolution: String?
    let createdAt: Date
    let resolvedAt: Date?

    static let databaseTableName = "conflictItem"

    func toDomain() -> ConflictItem {
        ConflictItem(
            id: id,
            type: ConflictItem.ConflictType(rawValue: type) ?? .contentModified,
            localPath: localPath,
            remotePath: remotePath,
            localContent: localContent,
            remoteContent: remoteContent,
            resolution: resolution.flatMap { ConflictItem.ConflictResolution(rawValue: $0) }
        )
    }

    static func from(domain: ConflictItem, resolved: Bool = false) -> ConflictRecord {
        ConflictRecord(
            id: domain.id,
            type: domain.type.rawValue,
            localPath: domain.localPath,
            remotePath: domain.remotePath,
            localContent: domain.localContent,
            remoteContent: domain.remoteContent,
            resolution: domain.resolution?.rawValue,
            createdAt: Date(),
            resolvedAt: resolved ? Date() : nil
        )
    }
}

/// 冲突项数据仓库实现
final class ConflictRepository: ConflictRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func fetchUnresolvedConflicts() -> AnyPublisher<[ConflictItem], Error> {
        return Future { promise in
            do {
                let records = try self.dbQueue.read { db in
                    try ConflictRecord
                        .filter(Column("resolution") == nil)
                        .order(Column("createdAt").desc)
                        .fetchAll(db)
                }
                promise(.success(records.map { $0.toDomain() }))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func fetchAllConflicts() -> AnyPublisher<[ConflictItem], Error> {
        return Future { promise in
            do {
                let records = try self.dbQueue.read { db in
                    try ConflictRecord.order(Column("createdAt").desc).fetchAll(db)
                }
                promise(.success(records.map { $0.toDomain() }))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func saveConflict(_ conflict: ConflictItem) -> AnyPublisher<Void, Error> {
        return Future { promise in
            do {
                try self.dbQueue.write { db in
                    try ConflictRecord.from(domain: conflict).save(db)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func saveConflicts(_ conflicts: [ConflictItem]) -> AnyPublisher<Void, Error> {
        return Future { promise in
            do {
                try self.dbQueue.write { db in
                    for conflict in conflicts {
                        try ConflictRecord.from(domain: conflict).save(db)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func updateResolution(conflictId: String, resolution: ConflictItem.ConflictResolution) -> AnyPublisher<Void, Error> {
        return Future { promise in
            do {
                try self.dbQueue.write { db in
                    try db.execute(
                        sql: "UPDATE conflictItem SET resolution = ?, resolvedAt = ? WHERE id = ?",
                        arguments: [resolution.rawValue, Date(), conflictId]
                    )
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func deleteConflict(conflictId: String) -> AnyPublisher<Void, Error> {
        return Future { promise in
            do {
                try self.dbQueue.write { db in
                    _ = try ConflictRecord.deleteOne(db, key: conflictId)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func clearAllConflicts() -> AnyPublisher<Void, Error> {
        return Future { promise in
            do {
                try self.dbQueue.write { db in
                    _ = try ConflictRecord.deleteAll(db)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    func unresolvedCount() -> AnyPublisher<Int, Error> {
        return Future { promise in
            do {
                let count = try self.dbQueue.read { db in
                    try ConflictRecord.filter(Column("resolution") == nil).fetchCount(db)
                }
                promise(.success(count))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}
