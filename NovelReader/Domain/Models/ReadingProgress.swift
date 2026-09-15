import Foundation

/// 阅读进度模型
struct ReadingProgress: Codable, Equatable {
    let bookId: String
    var chapterId: String
    /// 字符偏移
    var offset: Int
    /// 阅读百分比 0.0 ~ 1.0
    var percent: Double
    var updatedAt: Date

    init(bookId: String,
         chapterId: String,
         offset: Int = 0,
         percent: Double = 0,
         updatedAt: Date = Date()) {
        self.bookId = bookId
        self.chapterId = chapterId
        self.offset = offset
        self.percent = percent
        self.updatedAt = updatedAt
    }
}
