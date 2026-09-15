import UIKit

/// 分页引擎：基于 TextKit 计算文本分页
final class PaginationEngine {
    /// 单页内容
    struct Page: Equatable {
        let attributedString: NSAttributedString
        let range: NSRange
        let pageIndex: Int
    }

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private var textContainer: NSTextContainer?

    /// 分页结果缓存
    private var cachedPages: [Page] = []
    private var cachedKey: String?

    init() {
        textStorage.addLayoutManager(layoutManager)
    }

    /// 计算分页
    /// - Parameters:
    ///   - attributedString: 富文本
    ///   - bounds: 页面可用区域
    /// - Returns: 分页结果
    func paginate(attributedString: NSAttributedString, bounds: CGRect) -> [Page] {
        let key = "\(attributedString.hashValue)-\(bounds.width)-\(bounds.height)"
        if key == cachedKey, !cachedPages.isEmpty {
            return cachedPages
        }

        textStorage.setAttributedString(attributedString)

        let container = NSTextContainer(size: CGSize(width: bounds.width, height: bounds.height))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 0
        layoutManager.addTextContainer(container)
        textContainer = container

        var pages: [Page] = []
        var currentRange = NSRange(location: 0, length: 0)
        var pageIndex = 0

        while currentRange.location < attributedString.length {
            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            if charRange.location >= attributedString.length || charRange.length == 0 {
                break
            }

            let pageAttributed = attributedString.attributedSubstring(from: charRange)
            pages.append(Page(attributedString: pageAttributed, range: charRange, pageIndex: pageIndex))

            currentRange = NSRange(location: charRange.upperBound, length: 0)
            pageIndex += 1

            if currentRange.location < attributedString.length {
                let newContainer = NSTextContainer(size: container.size)
                newContainer.lineFragmentPadding = 0
                layoutManager.addTextContainer(newContainer)
                textContainer = newContainer
            }
        }

        // 清理多余的 container
        while layoutManager.textContainers.count > pages.count {
            layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
        }

        cachedPages = pages
        cachedKey = key
        return pages
    }

    /// 根据字符偏移找到页码
    func pageIndex(for offset: Int, in pages: [Page]) -> Int {
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
