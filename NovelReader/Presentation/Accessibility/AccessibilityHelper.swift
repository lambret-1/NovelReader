import UIKit

// MARK: - 无障碍辅助工具
/// 统一管理 VoiceOver 标签、提示和特性，提升无障碍体验
enum AccessibilityHelper {

    // MARK: - 页面标识

    /// 书架页
    static let libraryPage = "书架页面"
    /// 章节列表页
    static let chapterListPage = "章节列表页面"
    /// 阅读页
    static let readerPage = "阅读页面"
    /// 编辑页
    static let editorPage = "编辑页面"
    /// 同步页
    static let syncPage = "同步页面"
    /// 设置页
    static let settingsPage = "设置页面"
    /// 冲突列表页
    static let conflictListPage = "冲突列表页面"

    // MARK: - 元素标识

    /// 添加按钮
    static let addButton = "添加"
    /// 设置按钮
    static let settingsButton = "设置"
    /// 同步按钮
    static let syncButton = "同步"
    /// 搜索按钮
    static let searchButton = "搜索"
    /// 完成按钮
    static let doneButton = "完成"
    /// 删除按钮
    static let deleteButton = "删除"
    /// 编辑按钮
    static let editButton = "编辑"
    /// 阅读按钮
    static let readButton = "阅读"

    // MARK: - 便捷方法

    /// 为视图设置 VoiceOver 标签和提示
    /// - Parameters:
    ///   - view: 目标视图
    ///   - label: VoiceOver 标签（简洁描述）
    ///   - hint: VoiceOver 提示（操作说明，可选）
    ///   - traits: 无障碍特性
    static func configure(_ view: UIView, label: String, hint: String? = nil, traits: UIAccessibilityTraits = .button) {
        view.accessibilityLabel = label
        view.accessibilityHint = hint
        view.accessibilityTraits = traits
        view.isAccessibilityElement = true
    }

    /// 为单元格设置 VoiceOver 标签
    static func configureCell(_ cell: UITableViewCell, label: String, hint: String? = nil) {
        cell.accessibilityLabel = label
        cell.accessibilityHint = hint
        cell.accessibilityTraits = .button
    }

    /// 为标题设置 VoiceOver 标签（header 特性）
    static func configureHeader(_ view: UIView, label: String) {
        view.accessibilityLabel = label
        view.accessibilityTraits = .header
        view.isAccessibilityElement = true
    }

    /// 为文本输入框设置 VoiceOver 标签
    static func configureTextField(_ textField: UITextField, label: String, hint: String? = nil) {
        textField.accessibilityLabel = label
        textField.accessibilityHint = hint
        textField.accessibilityTraits = [.searchField, .button]
    }

    /// 为文本视图设置 VoiceOver 标签
    static func configureTextView(_ textView: UITextView, label: String) {
        textView.accessibilityLabel = label
        textView.accessibilityTraits = .staticText
    }

    // MARK: - VoiceOver 通知

    /// 发送 VoiceOver 布局变更通知（页面内容变化时调用）
    static func announceLayoutChange() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }

    /// 发送 VoiceOver 屏幕变更通知（页面切换时调用）
    static func announceScreenChange(_ view: UIView?) {
        UIAccessibility.post(notification: .screenChanged, argument: view)
    }

    /// 发送 VoiceOver 公告通知（提示信息）
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    // MARK: - 动态字体检查

    /// 当前是否使用大字体模式（辅助功能）
    static var isUsingLargeFont: Bool {
        let contentSize = UIApplication.shared.preferredContentSizeCategory
        return contentSize.isAccessibilityCategory
    }

    /// 根据字体模式调整间距
    static func adjustedSpacing(_ baseSpacing: CGFloat) -> CGFloat {
        return isUsingLargeFont ? baseSpacing * 1.5 : baseSpacing // 大字体模式间距增加50%
    }
}

// MARK: - UIViewController 无障碍便捷扩展
extension UIViewController {

    /// 设置页面 VoiceOver 标识
    func setAccessibilityPageLabel(_ label: String) {
        view.accessibilityLabel = label
        view.accessibilityTraits = .none
    }

    /// 页面出现时发送 VoiceOver 通知
    func announceScreenAppearance() {
        UIAccessibility.post(notification: .screenChanged, argument: view)
    }
}

// MARK: - UIBarButtonItem 无障碍便捷扩展
extension UIBarButtonItem {

    /// 设置 VoiceOver 标签和提示
    func setAccessibility(label: String, hint: String? = nil) {
        accessibilityLabel = label
        accessibilityHint = hint
    }
}
