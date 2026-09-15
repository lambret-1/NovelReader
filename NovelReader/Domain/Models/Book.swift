import Foundation

/// 书籍模型
struct Book: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var author: String
    var coverImagePath: String?
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    /// GitHub 上的相对目录路径，如 "我的第一本书"
    var remotePath: String
    var lastSyncedAt: Date?

    init(id: String = UUID().uuidString,
         title: String,
         author: String = "",
         coverImagePath: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         sortOrder: Int = 0,
         remotePath: String = "",
         lastSyncedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.coverImagePath = coverImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        // 安全处理：移除路径中的特殊字符，防止路径层级错误
        let safePath = remotePath.isEmpty ? title : remotePath
        self.remotePath = safePath
            .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastSyncedAt = lastSyncedAt
    }
}
