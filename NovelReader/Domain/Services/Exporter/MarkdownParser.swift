//
//  MarkdownParser.swift
//  NovelReader
//
//  轻量 Markdown 解析器：将 Markdown 文本转为带排版的 NSAttributedString
//

import UIKit

/// 轻量 Markdown 解析器
///
/// 支持语法：
/// - `# 一级标题` / `## 二级标题` / `### 三级标题`（支持全角空格）
/// - `**加粗**` / `*斜体*` / `` `行内代码` ``
/// - `[链接文本](链接地址)`
/// - `- 列表项` / `* 列表项`
/// - `> 引用块`
/// - `---` 分隔线
final class MarkdownParser {

    // MARK: 排版常量

    private let bodyFontSize: CGFloat = 14
    private let h1FontSize: CGFloat = 22
    private let h2FontSize: CGFloat = 18
    private let h3FontSize: CGFloat = 16
    private let lineSpacing: CGFloat = 1
    private let paragraphSpacing: CGFloat = 1
    private let firstLineIndent: CGFloat = 28
    private let listIndent: CGFloat = 20
    private let quoteIndent: CGFloat = 20

    // MARK: 预编译正则

    private let headingRegex = try! NSRegularExpression(pattern: #"^(#{1,6})[ \t]+(.+)$"#)
    private let hrRegex = try! NSRegularExpression(pattern: #"^-{3,}$"#)
    private let listRegex = try! NSRegularExpression(pattern: #"^[-*+][ \t]+(.+)$"#)
    private let orderedListRegex = try! NSRegularExpression(pattern: #"^(\d+)[.、][ \t]+(.+)$"#)
    private let quoteRegex = try! NSRegularExpression(pattern: #"^>[ \t]*(.*)$"#)
    private let boldRegex = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
    private let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#)
    private let codeRegex = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
    private let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)

    // MARK: 解析入口

    func parse(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            parseLine(line, into: result)
        }
        return result
    }

    // MARK: 逐行解析

    private func parseLine(_ line: String, into result: NSMutableAttributedString) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let fullRange = NSRange(location: 0, length: (trimmed as NSString).length)

        // 空行
        if trimmed.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
            return
        }

        // 分隔线
        if hrRegex.firstMatch(in: trimmed, range: fullRange) != nil {
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
            return
        }

        // 标题 # / ## / ###
        if let match = headingRegex.firstMatch(in: trimmed, range: fullRange) {
            let hashesRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            let hashes = (trimmed as NSString).substring(with: hashesRange)
            let text = (trimmed as NSString).substring(with: textRange)
            let level = hashes.count
            let size: CGFloat
            let spacingAfter: CGFloat
            switch level {
            case 1: size = h1FontSize; spacingAfter = 4
            case 2: size = h2FontSize; spacingAfter = 4
            default: size = h3FontSize; spacingAfter = 3
            }
            // 一级二级标题下方加分隔线（贴近GitHub风格）
            result.append(NSAttributedString(string: "\n" + text + "\n",
                                            attributes: headingAttributes(size: size, spacingAfter: 2)))
            if level <= 2 {
                let separator = String(repeating: "─", count: 35)
                result.append(NSAttributedString(string: separator + "\n",
                                                attributes: separatorAttributes()))
            }
            return
        }

        // 列表项
        if let match = listRegex.firstMatch(in: trimmed, range: fullRange) {
            let textRange = match.range(at: 1)
            let text = (trimmed as NSString).substring(with: textRange)
            let attr = NSMutableAttributedString(string: "• ", attributes: bodyAttributes(indent: listIndent))
            attr.append(parseInline(text, baseAttributes: bodyAttributes(indent: listIndent)))
            attr.append(NSAttributedString(string: "\n", attributes: bodyAttributes(indent: listIndent)))
            result.append(attr)
            return
        }

        // 有序列表 1. 2. 3.
        if let match = orderedListRegex.firstMatch(in: trimmed, range: fullRange) {
            let numRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            let num = (trimmed as NSString).substring(with: numRange)
            let text = (trimmed as NSString).substring(with: textRange)
            let attr = NSMutableAttributedString(string: "\(num). ", attributes: bodyAttributes(indent: listIndent))
            attr.append(parseInline(text, baseAttributes: bodyAttributes(indent: listIndent)))
            attr.append(NSAttributedString(string: "\n", attributes: bodyAttributes(indent: listIndent)))
            result.append(attr)
            return
        }

        // 引用块
        if let match = quoteRegex.firstMatch(in: trimmed, range: fullRange) {
            let textRange = match.range(at: 1)
            let text = (trimmed as NSString).substring(with: textRange)
            result.append(NSMutableAttributedString(string: text + "\n", attributes: quoteAttributes()))
            return
        }

        // 普通正文
        let attr = parseInline(trimmed, baseAttributes: bodyAttributes())
        attr.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
        result.append(attr)
    }

    // MARK: 行内语法解析

    private func parseInline(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let fullString = result.string as NSString

        // 用字符串扫描处理 **加粗**（从后往前，避免位置偏移）
        var searchRange = NSRange(location: 0, length: fullString.length)
        var boldRanges: [(NSRange, NSRange)] = [] // (整体范围, 内部文本范围)
        while true {
            let firstStar = fullString.range(of: "**", options: [], range: searchRange)
            guard firstStar.location != NSNotFound else { break }
            let afterFirst = NSRange(location: firstStar.location + 2, length: fullString.length - firstStar.location - 2)
            let secondStar = fullString.range(of: "**", options: [], range: afterFirst)
            guard secondStar.location != NSNotFound else { break }
            let fullRange = NSRange(location: firstStar.location, length: secondStar.location + 2 - firstStar.location)
            let innerRange = NSRange(location: firstStar.location + 2, length: secondStar.location - firstStar.location - 2)
            boldRanges.append((fullRange, innerRange))
            searchRange = NSRange(location: secondStar.location + 2, length: fullString.length - secondStar.location - 2)
        }
        // 从后往前替换
        for (fullRange, innerRange) in boldRanges.reversed() {
            let innerText = fullString.substring(with: innerRange)
            var boldAttrs = baseAttributes
            boldAttrs[.font] = UIFont.boldSystemFont(ofSize: bodyFontSize)
            result.replaceCharacters(in: fullRange, with: NSAttributedString(string: innerText, attributes: boldAttrs))
        }

        // 用字符串扫描处理 *斜体*（排除已处理的加粗）
        let currentString = result.string as NSString
        var italicRanges: [(NSRange, NSRange)] = []
        searchRange = NSRange(location: 0, length: currentString.length)
        while true {
            let firstStar = currentString.range(of: "*", options: [], range: searchRange)
            guard firstStar.location != NSNotFound else { break }
            // 跳过 **（加粗已处理，不会有 ** 了，但保险起见）
            if firstStar.location + 1 < currentString.length &&
               currentString.substring(with: NSRange(location: firstStar.location, length: 2)) == "**" {
                searchRange = NSRange(location: firstStar.location + 2, length: currentString.length - firstStar.location - 2)
                continue
            }
            let afterFirst = NSRange(location: firstStar.location + 1, length: currentString.length - firstStar.location - 1)
            let secondStar = currentString.range(of: "*", options: [], range: afterFirst)
            guard secondStar.location != NSNotFound else { break }
            let fullRange = NSRange(location: firstStar.location, length: secondStar.location + 1 - firstStar.location)
            let innerRange = NSRange(location: firstStar.location + 1, length: secondStar.location - firstStar.location - 1)
            italicRanges.append((fullRange, innerRange))
            searchRange = NSRange(location: secondStar.location + 1, length: currentString.length - secondStar.location - 1)
        }
        for (fullRange, innerRange) in italicRanges.reversed() {
            let innerText = currentString.substring(with: innerRange)
            var italicAttrs = baseAttributes
            italicAttrs[.font] = UIFont.italicSystemFont(ofSize: bodyFontSize)
            result.replaceCharacters(in: fullRange, with: NSAttributedString(string: innerText, attributes: italicAttrs))
        }

        // 行内代码 `code`
        let codeString = result.string as NSString
        var codeRanges: [(NSRange, NSRange)] = []
        searchRange = NSRange(location: 0, length: codeString.length)
        while true {
            let firstBacktick = codeString.range(of: "`", options: [], range: searchRange)
            guard firstBacktick.location != NSNotFound else { break }
            let afterFirst = NSRange(location: firstBacktick.location + 1, length: codeString.length - firstBacktick.location - 1)
            let secondBacktick = codeString.range(of: "`", options: [], range: afterFirst)
            guard secondBacktick.location != NSNotFound else { break }
            let fullRange = NSRange(location: firstBacktick.location, length: secondBacktick.location + 1 - firstBacktick.location)
            let innerRange = NSRange(location: firstBacktick.location + 1, length: secondBacktick.location - firstBacktick.location - 1)
            codeRanges.append((fullRange, innerRange))
            searchRange = NSRange(location: secondBacktick.location + 1, length: codeString.length - secondBacktick.location - 1)
        }
        for (fullRange, innerRange) in codeRanges.reversed() {
            let innerText = codeString.substring(with: innerRange)
            var codeAttrs = baseAttributes
            codeAttrs[.font] = UIFont.monospacedSystemFont(ofSize: bodyFontSize - 1, weight: .regular)
            codeAttrs[.foregroundColor] = UIColor.darkGray
            result.replaceCharacters(in: fullRange, with: NSAttributedString(string: innerText, attributes: codeAttrs))
        }

        return result
    }

    /// 应用行内正则替换（从后往前，避免位置偏移）
    private func applyInlineRegex(_ regex: NSRegularExpression,
                                  to attrString: NSMutableAttributedString,
                                  replacement: (String) -> NSAttributedString) {
        let fullRange = NSRange(location: 0, length: attrString.length)
        // 收集所有匹配
        var matches: [NSTextCheckingResult] = []
        regex.enumerateMatches(in: attrString.string, range: fullRange) { result, _, _ in
            if let result = result {
                matches.append(result)
            }
        }
        guard !matches.isEmpty else { return }
        // 从后往前替换
        for match in matches.reversed() {
            let matchRange = match.range(at: 0)
            let innerRange = match.range(at: 1)
            guard innerRange.location != NSNotFound else { continue }
            let innerText = (attrString.string as NSString).substring(with: innerRange)
            attrString.replaceCharacters(in: matchRange, with: replacement(innerText))
        }
    }

    // MARK: 属性构造

    private func bodyAttributes(indent: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        para.paragraphSpacing = paragraphSpacing
        para.firstLineHeadIndent = indent == 0 ? firstLineIndent : 0
        para.headIndent = indent
        return [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .paragraphStyle: para,
            .foregroundColor: UIColor.black
        ]
    }

    private func headingAttributes(size: CGFloat, spacingAfter: CGFloat) -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        para.paragraphSpacingBefore = 2 // 标题上方留空2pt，紧凑排版
        para.paragraphSpacing = spacingAfter
        return [
            .font: UIFont.boldSystemFont(ofSize: size),
            .paragraphStyle: para,
            .foregroundColor: UIColor.black
        ]
    }

    /// 分隔线属性：灰色细字
    private func separatorAttributes() -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 4
        return [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.lightGray,
            .paragraphStyle: para
        ]
    }

    private func quoteAttributes() -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        para.paragraphSpacing = paragraphSpacing
        para.headIndent = quoteIndent
        para.firstLineHeadIndent = quoteIndent
        return [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .paragraphStyle: para,
            .foregroundColor: UIColor.darkGray
        ]
    }
}
