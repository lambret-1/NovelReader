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
/// - `# 一级标题` / `## 二级标题` / `### 三级标题`
/// - `**加粗**` / `*斜体*` / `` `行内代码` ``
/// - `- 列表项` / `* 列表项`
/// - `> 引用块`
/// - `---` 分隔线
final class MarkdownParser {

    // MARK: 排版常量

    /// 正文字号
    private let bodyFontSize: CGFloat = 14
    /// 一级标题字号
    private let h1FontSize: CGFloat = 22
    /// 二级标题字号
    private let h2FontSize: CGFloat = 18
    /// 三级标题字号
    private let h3FontSize: CGFloat = 16
    /// 正文行间距
    private let lineSpacing: CGFloat = 1
    /// 段落间距
    private let paragraphSpacing: CGFloat = 1
    /// 首行缩进
    private let firstLineIndent: CGFloat = 28
    /// 列表缩进
    private let listIndent: CGFloat = 20
    /// 引用块左边距
    private let quoteIndent: CGFloat = 20

    // MARK: 解析入口

    /// 解析 Markdown 文本为 NSAttributedString
    /// - Parameter markdown: Markdown 原文
    /// - Returns: 带排版的富文本
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

        // 空行
        if trimmed.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
            return
        }

        // 分隔线 ---
        if trimmed.range(of: #"^-{3,}$"#, options: .regularExpression) != nil {
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
            return
        }

        // 一级标题 #
        if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
            let text = String(trimmed.dropFirst(2))
            result.append(NSAttributedString(string: "\n" + text + "\n",
                                            attributes: headingAttributes(size: h1FontSize, spacingAfter: 12)))
            return
        }

        // 二级标题 ##
        if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
            let text = String(trimmed.dropFirst(3))
            result.append(NSAttributedString(string: "\n" + text + "\n",
                                            attributes: headingAttributes(size: h2FontSize, spacingAfter: 10)))
            return
        }

        // 三级标题 ###
        if trimmed.hasPrefix("### ") {
            let text = String(trimmed.dropFirst(4))
            result.append(NSAttributedString(string: "\n" + text + "\n",
                                            attributes: headingAttributes(size: h3FontSize, spacingAfter: 8)))
            return
        }

        // 列表项 - 或 *
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let text = String(trimmed.dropFirst(2))
            let attr = NSMutableAttributedString(string: "• ", attributes: bodyAttributes())
            attr.append(parseInline(text, baseAttributes: bodyAttributes(indent: listIndent)))
            attr.append(NSAttributedString(string: "\n", attributes: bodyAttributes(indent: listIndent)))
            result.append(attr)
            return
        }

        // 引用块 >
        if trimmed.hasPrefix("> ") {
            let text = String(trimmed.dropFirst(2))
            let quoteAttr = NSMutableAttributedString(string: text + "\n",
                                                      attributes: quoteAttributes())
            result.append(quoteAttr)
            return
        }

        // 普通正文
        let attr = parseInline(trimmed, baseAttributes: bodyAttributes())
        attr.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
        result.append(attr)
    }

    // MARK: 行内语法解析

    /// 解析行内语法：**加粗**、*斜体*、`代码`
    private func parseInline(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)

        // 解析 **加粗**
        result.replaceMatches(pattern: #"\*\*(.+?)\*\*"#) { matchText in
            var attrs = baseAttributes
            attrs[.font] = UIFont.boldSystemFont(ofSize: bodyFontSize)
            return NSAttributedString(string: matchText, attributes: attrs)
        }

        // 解析 *斜体*（避免和加粗冲突，加粗已处理）
        result.replaceMatches(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#) { matchText in
            var attrs = baseAttributes
            attrs[.font] = UIFont.italicSystemFont(ofSize: bodyFontSize)
            return NSAttributedString(string: matchText, attributes: attrs)
        }

        // 解析 `行内代码`
        result.replaceMatches(pattern: #"`([^`]+)`"#) { matchText in
            var attrs = baseAttributes
            attrs[.font] = UIFont.monospacedSystemFont(ofSize: bodyFontSize - 1, weight: .regular)
            attrs[.foregroundColor] = UIColor.darkGray
            return NSAttributedString(string: matchText, attributes: attrs)
        }

        return result
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
        para.paragraphSpacingBefore = 10
        para.paragraphSpacing = spacingAfter
        return [
            .font: UIFont.boldSystemFont(ofSize: size),
            .paragraphStyle: para,
            .foregroundColor: UIColor.black
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

// MARK: - NSAttributedString 正则替换扩展

private extension NSMutableAttributedString {
    /// 用正则匹配并替换为富文本
    /// - Parameters:
    ///   - pattern: 正则表达式
    ///   - replacement: 捕获组1 → 替换为富文本
    func replaceMatches(pattern: String, replacement: (String) -> NSAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        var fullRange = NSRange(location: 0, length: length)

        // 从后往前替换，避免位置偏移
        while fullRange.length > 0 {
            guard let match = regex.firstMatch(in: string, range: fullRange) else { break }
            let matchRange = match.range(at: 0)
            let innerRange = match.range(at: 1)
            let innerText = (string as NSString).substring(with: innerRange)
            let replacementAttr = replacement(innerText)
            replaceCharacters(in: matchRange, with: replacementAttr)
            // 更新剩余搜索范围
            let newLocation = matchRange.location + replacementAttr.length
            fullRange = NSRange(location: newLocation,
                                length: length - newLocation)
        }
    }
}
