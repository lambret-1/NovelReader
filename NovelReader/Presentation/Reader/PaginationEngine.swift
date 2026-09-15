import UIKit

/// 分页引擎：基于 TextKit 计算文本分页
/// 每次 paginate 调用使用独立的 TextKit 实例，避免互相干扰
final class PaginationEngine {
    /// 单页内容
    struct Page: Equatable {
        let attributedString: NSAttributedString
        let range: NSRange
        let pageIndex: Int
    }

    /// 分页结果缓存
    private var cachedPages: [Page] = []
    private var cachedKey: String?

    /// 计算分页
    /// - Parameters:
    ///   - attributedString: 富文本
    ///   - bounds: 页面可用区域
    /// - Returns: 分页结果
    func paginate(attributedString: NSAttributedString, bounds: CGRect) -> [Page] {
        let key = "\(attributedString.hashValue)-\(Int(bounds.width))-\(Int(bounds.height))"
        if key == cachedKey, !cachedPages.isEmpty {
            return cachedPages
        }

        // 每次调用创建独立的 TextKit 实例，避免共享状态导致的干扰
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(attributedString)

        var pages: [Page] = []
        var currentLocation = 0
        var pageIndex = 0
        let maxPages = 10000 // 安全上限，防止死循环

        while currentLocation < attributedString.length && pageIndex < maxPages {
            // 每次循环创建新的 container，确保获取最新范围
            let container = NSTextContainer(size: CGSize(width: bounds.width, height: bounds.height))
            container.lineFragmentPadding = 0
            container.maximumNumberOfLines = 0
            layoutManager.addTextContainer(container)

            // 强制布局，确保 glyph 已生成
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            // 安全检查：无内容或超出范围则停止
            guard charRange.length > 0, charRange.location < attributedString.length else {
                break
            }

            let pageAttributed = attributedString.attributedSubstring(from: charRange)
            pages.append(Page(attributedString: pageAttributed, range: charRange, pageIndex: pageIndex))

            currentLocation = charRange.upperBound
            pageIndex += 1
        }

        cachedPages = pages
        cachedKey = key
        return pages
    }

    /// 根据字符偏移找到页码
    func pageIndex(for offset: Int, in pages: [Page]) -> Int {
        guard !pages.isEmpty else { return 0 }
        for (index, page) in pages.enumerated() {
            if NSLocationInRange(offset, page.range) || offset == page.range.upperBound {
                return index
            }
        }
        return max(0, pages.count - 1)
    }

    /// 清除缓存
    func invalidateCache() {
        cachedPages = []
        cachedKey = nil
    }
}
