import Foundation

/// 自然排序工具 - 智能识别文件名中的数字进行排序
/// 解决字符串排序问题：第1章、第10章、第2章 → 第1章、第2章、第10章
enum NaturalSort {

    /// 从字符串中提取章节序号
    /// 支持格式：第1章、第2章、第10章、1.xxx、001_xxx、纯数字开头
    /// - Parameter string: 待解析的字符串
    /// - Returns: 提取到的数字，无法识别时返回 Int.max（排到最后）
    static func extractChapterNumber(from string: String) -> Int {
        // 去除路径前缀，只取文件名
        let fileName = (string as NSString).lastPathComponent
        // 去除文件扩展名
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension

        // 使用 Scanner 提取第一个数字
        // Scanner 会自动跳过非数字字符，然后扫描连续的数字
        let scanner = Scanner(string: nameWithoutExtension)
        scanner.charactersToBeSkipped = CharacterSet.decimalDigits.inverted

        var number: Int = 0
        if scanner.scanInt(&number) {
            return number
        }

        // 无法识别数字，排到最后
        return Int.max
    }

    /// 自然排序比较
    /// - Parameters:
    ///   - lhs: 左侧字符串
    ///   - rhs: 右侧字符串
    /// - Returns: lhs 是否应该排在 rhs 前面
    static func compare(_ lhs: String, _ rhs: String) -> Bool {
        let leftNum = extractChapterNumber(from: lhs)
        let rightNum = extractChapterNumber(from: rhs)

        if leftNum != rightNum {
            return leftNum < rightNum
        }

        // 数字相同时，按完整字符串排序
        return lhs < rhs
    }
}

// MARK: - Array 扩展
extension Array where Element == String {
    /// 自然排序（智能识别章节数字）
    /// - Returns: 排序后的数组
    func naturalSorted() -> [String] {
        return sorted { NaturalSort.compare($0, $1) }
    }
}
