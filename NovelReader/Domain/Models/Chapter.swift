import Foundation
import CommonCrypto

/// 章节模型
struct Chapter: Identifiable, Codable, Equatable {
    let id: String
    let bookId: String
    var title: String
    var content: String
    var sortOrder: Int
    var wordCount: Int
    var createdAt: Date
    var updatedAt: Date
    /// 内容 SHA256，用于差异对比
    var contentHash: String
    /// 是否有未同步的修改
    var isDirty: Bool
    /// GitHub 上的相对文件路径，如 "我的第一本书/001_第一章.md"
    var remotePath: String

    init(id: String = UUID().uuidString,
         bookId: String,
         title: String,
         content: String = "",
         sortOrder: Int = 0,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         isDirty: Bool = true,
         remotePath: String = "") {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.content = content
        self.sortOrder = sortOrder
        self.wordCount = content.count
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contentHash = Chapter.hash(content: content)
        self.isDirty = isDirty
        self.remotePath = remotePath
    }

    /// 计算内容 SHA256
    static func hash(content: String) -> String {
        let data = Data(content.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// 更新内容并重新计算 hash 和字数
    mutating func updateContent(_ newContent: String) {
        content = newContent
        wordCount = newContent.count
        contentHash = Chapter.hash(content: newContent)
        updatedAt = Date()
        isDirty = true
    }

    /// 生成远程文件名：标题.md（不含数字序号前缀）
    func remoteFileName() -> String {
        let safeTitle = title.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(safeTitle.isEmpty ? "未命名" : safeTitle).md"
    }
}
