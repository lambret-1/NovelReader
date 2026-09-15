import Foundation

/// 书签模型
struct Bookmark: Identifiable, Codable, Equatable {
    let id: String
    let bookId: String
    let chapterId: String
    /// 字符偏移量（稳定定位方式）
    var offset: Int
    /// 选中的文本摘要
    var textExcerpt: String?
    var note: String?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         bookId: String,
         chapterId: String,
         offset: Int = 0,
         textExcerpt: String? = nil,
         note: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.bookId = bookId
        self.chapterId = chapterId
        self.offset = offset
        self.textExcerpt = textExcerpt
        self.note = note
        self.createdAt = createdAt
    }
}
