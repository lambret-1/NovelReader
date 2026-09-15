import Foundation
import GRDB

/// 数据库管理器
final class DatabaseManager {
    /// 共享单例（向后兼容，新代码优先使用依赖注入）
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    /// 公开初始化方法，支持依赖注入和测试
    init() {
        let queue: DatabaseQueue
        do {
            let fileManager = FileManager.default
            let docsDir = try fileManager.url(for: .documentDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
            let dbURL = docsDir.appendingPathComponent(AppConfig.databaseFileName)
            queue = try DatabaseQueue(path: dbURL.path)
            AppLogger.info("数据库初始化成功: \(dbURL.path)")
        } catch {
            AppLogger.error("数据库初始化失败: \(error)")
            // 兜底：内存数据库
            queue = try! DatabaseQueue()
        }
        self.dbQueue = queue
        try? migrate()
    }

    /// 数据库迁移
    private func migrate() throws {
        var migrator = DatabaseMigrator()

        // v1: 初始表结构
        migrator.registerMigration("v1_initial") { db in
            // 书籍表
            try db.create(table: "book") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("author", .text).defaults(to: "")
                t.column("coverImagePath", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("remotePath", .text).defaults(to: "")
                t.column("lastSyncedAt", .datetime)
            }

            // 章节表
            try db.create(table: "chapter") { t in
                t.column("id", .text).primaryKey()
                t.column("bookId", .text).notNull().indexed()
                t.column("title", .text).notNull()
                t.column("content", .text).defaults(to: "")
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("wordCount", .integer).defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("contentHash", .text).defaults(to: "")
                t.column("isDirty", .boolean).defaults(to: true)
                t.column("remotePath", .text).defaults(to: "")
            }
            try db.create(index: "idx_chapter_book_sort", on: "chapter", columns: ["bookId", "sortOrder"])
            try db.create(index: "idx_chapter_dirty", on: "chapter", columns: ["isDirty"])

            // 书签表
            try db.create(table: "bookmark") { t in
                t.column("id", .text).primaryKey()
                t.column("bookId", .text).notNull().indexed()
                t.column("chapterId", .text).notNull()
                t.column("offset", .integer).defaults(to: 0)
                t.column("textExcerpt", .text)
                t.column("note", .text)
                t.column("createdAt", .datetime).notNull()
            }

            // 阅读进度表
            try db.create(table: "readingProgress") { t in
                t.column("bookId", .text).primaryKey()
                t.column("chapterId", .text).notNull()
                t.column("offset", .integer).defaults(to: 0)
                t.column("percent", .double).defaults(to: 0)
                t.column("updatedAt", .datetime).notNull()
            }

            // 同步元数据表
            try db.create(table: "syncMetadata") { t in
                t.column("id", .text).primaryKey()
                t.column("lastSyncCommitSHA", .text)
                t.column("lastSyncAt", .datetime)
                t.column("localManifestVersion", .integer).defaults(to: 1)
                t.column("githubUsername", .text)
                t.column("repoFullName", .text)
            }
        }

        try migrator.migrate(dbQueue)
    }
}
