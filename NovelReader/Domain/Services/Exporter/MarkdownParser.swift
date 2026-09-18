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

    /// 正文字号（可外部配置，阅读器和PDF导出共用）
    var bodyFontSize: CGFloat = 14
    /// 标题字号相对于正文字号的缩放比例
    var h1Scale: CGFloat = 1.6
    var h2Scale: CGFloat = 1.3
    var h3Scale: CGFloat = 1.15
    /// 行间距
    var lineSpacing: CGFloat = 1
    /// 段间距
    var paragraphSpacing: CGFloat = 1
    /// 首行缩进
    var firstLineIndent: CGFloat = 28
    /// 正文颜色
    var textColor: UIColor = .black
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

        // 按优先级从高到低处理：代码 > 链接 > 加粗 > 斜体
        applyInlineRegex(codeRegex, to: result) { inner in
            var attrs = baseAttributes
            attrs[.font] = UIFont.monospacedSystemFont(ofSize: bodyFontSize - 1, weight: .regular)
            attrs[.foregroundColor] = UIColor.darkGray
            return NSAttributedString(string: inner, attributes: attrs)
        }

        applyInlineRegex(linkRegex, to: result) { inner in
            var attrs = baseAttributes
            attrs[.font] = UIFont.systemFont(ofSize: bodyFontSize)
            attrs[.foregroundColor] = UIColor.systemBlue
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            return NSAttributedString(string: inner, attributes: attrs)
        }

        applyInlineRegex(boldRegex, to: result) { inner in
            var attrs = baseAttributes
            attrs[.font] = UIFont.boldSystemFont(ofSize: bodyFontSize)
            return NSAttributedString(string: inner, attributes: attrs)
        }

        applyInlineRegex(italicRegex, to: result) { inner in
            var attrs = baseAttributes
            attrs[.font] = UIFont.italicSystemFont(ofSize: bodyFontSize)
            return NSAttributedString(string: inner, attributes: attrs)
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
            .foregroundColor: textColor
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
            .foregroundColor: textColor
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
