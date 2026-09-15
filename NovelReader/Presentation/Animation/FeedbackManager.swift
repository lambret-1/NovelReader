import UIKit

// MARK: - 触觉反馈管理器
/// 统一管理触觉反馈，避免重复创建 generator，提升性能
final class FeedbackManager {

    // MARK: - 单例
    static let shared = FeedbackManager()

    // MARK: - 私有属性
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        // 预准备所有 generator，减少首次触发延迟
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - 冲击反馈（按钮按下、卡片点击）

    /// 轻触反馈（小按钮、标签点击）
    func impactLight() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// 中触反馈（标准按钮、列表选中）
    func impactMedium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// 重触反馈（重要操作、删除确认）
    func impactHeavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    // MARK: - 通知反馈（操作结果）

    /// 成功反馈（保存成功、同步完成）
    func notifySuccess() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// 警告反馈（冲突、需要确认）
    func notifyWarning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    /// 错误反馈（保存失败、同步失败）
    func notifyError() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    // MARK: - 选择反馈（开关、分段控件、选择器）

    /// 选择变化反馈
    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }
}

// MARK: - UIButton 触觉反馈便捷扩展
extension UIButton {
    /// 添加触觉反馈（按下时触发）
    func addHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        addTarget(self, action: #selector(triggerHaptic), for: .touchDown)
        objc_setAssociatedObject(self, &UIButton.hapticStyleKey, style, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private func triggerHaptic() {
        let style = objc_getAssociatedObject(self, &UIButton.hapticStyleKey) as? UIImpactFeedbackGenerator.FeedbackStyle ?? .medium
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private static var hapticStyleKey: UInt8 = 0
}
