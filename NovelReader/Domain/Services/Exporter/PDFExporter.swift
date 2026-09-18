//
//  PDFExporter.swift
//  NovelReader
//
//  将整本书导出为 PDF 文档
//

import UIKit
import CoreText
import Combine

// MARK: - PDF 导出器

/// PDF 导出器：将书籍的全部章节渲染为 A4 PDF 文档
///
/// 设计要点：
/// - A4 页面（595 × 842 pt），边距 50pt
/// - 封面页：书名 + 作者 + 导出时间
/// - 每章新起一页，章节标题居中加粗
/// - 使用 CTFramesetter 计算分页，UIKit 坐标系绘制（避免文字颠倒）
/// - 每页约 1000 字
/// - 章节级进度回调
final class PDFExporter {

    // MARK: 页面布局常量

    /// A4 页面宽度（72dpi）
    private let pageWidth: CGFloat = 595
    /// A4 页面高度（72dpi）
    private let pageHeight: CGFloat = 842
    /// 页面四周边距
    private let pageMargin: CGFloat = 50
    /// 正文行间距（10pt，配合14pt字号使每页约1000字）
    private let lineSpacing: CGFloat = 10
    /// 段落间距
    private let paragraphSpacing: CGFloat = 14
    /// 正文字号
    private let bodyFontSize: CGFloat = 14
    /// 章节标题字号
    private let chapterTitleFontSize: CGFloat = 18
    /// 书名字号
    private let bookTitleFontSize: CGFloat = 28
    /// 作者字号
    private let authorFontSize: CGFloat = 16

    // MARK: 导出入口

    /// 导出整本书为 PDF
    /// - Parameters:
    ///   - book: 书籍模型
    ///   - chapters: 已排序的章节数组
    ///   - progress: 进度回调（0.0 ~ 1.0），在主线程回调
    /// - Returns: 生成的 PDF 临时文件 URL
    /// - Throws: 文件写入或绘制过程中的错误
    func export(book: Book,
                chapters: [Chapter],
                progress: @escaping (Float) -> Void) throws -> URL {

        guard !chapters.isEmpty else {
            throw ExportError.noChapters
        }

        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        // 页面文本区域（扣掉边距）
        let textRect = CGRect(x: pageMargin,
                              y: pageMargin,
                              width: pageWidth - pageMargin * 2,
                              height: pageHeight - pageMargin * 2)

        // 准备字体
        let bodyFont = UIFont.systemFont(ofSize: bodyFontSize)
        let titleFont = UIFont.boldSystemFont(ofSize: chapterTitleFontSize)
        let bookTitleFont = UIFont.boldSystemFont(ofSize: bookTitleFontSize)
        let authorFont = UIFont.systemFont(ofSize: authorFontSize)

        // 段落样式：正文（首行缩进2字符）
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = lineSpacing // 行间距10pt
        bodyParagraph.paragraphSpacing = paragraphSpacing // 段间距14pt
        bodyParagraph.firstLineHeadIndent = bodyFontSize * 2 // 首行缩进2字符

        // 段落样式：章节标题（居中）
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center // 标题居中
        titleParagraph.paragraphSpacing = 20 // 标题与正文间距20pt

        let pdfData = renderer.pdfData { context in
            // 1. 绘制封面页
            drawCover(book: book,
                      in: context,
                      textRect: textRect,
                      bookTitleFont: bookTitleFont,
                      authorFont: authorFont)
            DispatchQueue.main.async { progress(0.02) }

            // 2. 逐章节绘制
            for (index, chapter) in chapters.enumerated() {
                // 每章新起一页：章节标题
                context.beginPage()
                let titleAttr = NSAttributedString(
                    string: chapter.title,
                    attributes: [
                        .font: titleFont,
                        .paragraphStyle: titleParagraph,
                        .foregroundColor: UIColor.black
                    ]
                )
                titleAttr.draw(in: textRect)

                // 正文文本区域：标题下方
                let bodyTopY = textRect.minY + (chapterTitleFontSize + 20)
                let firstPageRect = CGRect(x: textRect.minX,
                                          y: bodyTopY,
                                          width: textRect.width,
                                          height: textRect.maxY - bodyTopY)
                // 后续页完整文本区域
                let nextPageRect = textRect

                // 章节正文属性
                let bodyAttr = NSAttributedString(
                    string: chapter.content,
                    attributes: [
                        .font: bodyFont,
                        .paragraphStyle: bodyParagraph,
                        .foregroundColor: UIColor.black
                    ]
                )

                // 正文分页绘制
                _ = paginateAndDraw(
                    attributedString: bodyAttr,
                    in: context,
                    firstPageRect: firstPageRect,
                    nextPageRect: nextPageRect
                )

                // 进度回调
                let chapterProgress = Float(index + 1) / Float(chapters.count)
                DispatchQueue.main.async {
                    progress(0.02 + chapterProgress * 0.96)
                }
            }
        }

        // 3. 写入临时文件
        let fileName = "\(book.title)_导出.pdf"
            .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>"))
            .joined()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try pdfData.write(to: fileURL)

        DispatchQueue.main.async { progress(1.0) }
        return fileURL
    }

    // MARK: - 私有绘制方法

    /// 绘制封面页
    private func drawCover(book: Book,
                           in context: UIGraphicsPDFRendererContext,
                           textRect: CGRect,
                           bookTitleFont: UIFont,
                           authorFont: UIFont) {
        context.beginPage()

        let titleAttr = NSAttributedString(
            string: "《\(book.title)》",
            attributes: [
                .font: bookTitleFont,
                .foregroundColor: UIColor.black
            ]
        )
        let authorAttr = NSAttributedString(
            string: "作者：\(book.author.isEmpty ? "佚名" : book.author)",
            attributes: [
                .font: authorFont,
                .foregroundColor: UIColor.darkGray
            ]
        )
        let dateAttr = NSAttributedString(
            string: "导出时间：\(Self.dateFormatter.string(from: Date()))",
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray
            ]
        )

        // 计算总高度做垂直居中
        let titleSize = titleAttr.boundingRect(with: textRect.size,
                                               options: [.usesLineFragmentOrigin],
                                               context: nil)
        let authorSize = authorAttr.boundingRect(with: textRect.size,
                                                 options: [.usesLineFragmentOrigin],
                                                 context: nil)
        let dateSize = dateAttr.boundingRect(with: textRect.size,
                                             options: [.usesLineFragmentOrigin],
                                             context: nil)
        let totalHeight = titleSize.height + 30 + authorSize.height + 60 + dateSize.height
        var y = textRect.midY - totalHeight / 2

        let titleRect = CGRect(x: textRect.minX, y: y, width: textRect.width, height: titleSize.height)
        titleAttr.draw(in: titleRect)
        y += titleSize.height + 30

        let authorRect = CGRect(x: textRect.minX, y: y, width: textRect.width, height: authorSize.height)
        authorAttr.draw(in: authorRect)
        y += authorSize.height + 60

        let dateRect = CGRect(x: textRect.minX, y: y, width: textRect.width, height: dateSize.height)
        dateAttr.draw(in: dateRect)
    }

    /// 将长文本按页面空间分页绘制（使用 UIKit 坐标系，文字方向正确）
    /// - Parameters:
    ///   - attributedString: 正文属性串
    ///   - context: PDF 上下文
    ///   - firstPageRect: 首页（标题下方）的可用区域
    ///   - nextPageRect: 后续页的完整文本区域
    /// - Returns: 额外绘制的页数（不含首页）
    @discardableResult
    private func paginateAndDraw(attributedString: NSAttributedString,
                                 in context: UIGraphicsPDFRendererContext,
                                 firstPageRect: CGRect,
                                 nextPageRect: CGRect) -> Int {
        guard attributedString.length > 0 else { return 0 }

        let cfAttr = attributedString as CFAttributedString
        let framesetter = CTFramesetterCreateWithAttributedString(cfAttr)

        var remainingRange = CFRange(location: 0, length: 0)
        var currentRect = firstPageRect
        var extraPages = 0
        var firstPage = true

        while true {
            // 用 CTFramesetter 计算当前区域能放下多少字符
            var fitRange = CFRange()
            _ = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                remainingRange,
                nil,
                currentRect.size,
                &fitRange
            )

            // 本页要绘制的字符范围
            let pageRange = NSRange(location: remainingRange.location, length: fitRange.length)
            guard pageRange.length > 0 else { break }

            // 切片出本页文本
            let pageText = attributedString.attributedSubstring(from: pageRange)

            if !firstPage {
                context.beginPage()
                extraPages += 1
            }

            // 用 UIKit 坐标系绘制（文字方向正确）
            let drawOptions: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
            pageText.draw(with: currentRect, options: drawOptions, context: nil)

            remainingRange.location += fitRange.length
            remainingRange.length = 0
            firstPage = false

            // 绘制完所有字符
            if remainingRange.location >= attributedString.length {
                break
            }
            currentRect = nextPageRect
        }
        return extraPages
    }

    // MARK: - 日期格式化

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

// MARK: - 导出错误

/// 导出过程中可能出现的错误
enum ExportError: Error, LocalizedError {
    case noChapters

    var errorDescription: String? {
        switch self {
        case .noChapters:
            return "书籍暂无章节内容，无法导出"
        }
    }
}
