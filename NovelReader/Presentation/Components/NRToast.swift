import UIKit

// MARK: - Toast 类型
/// Toast 样式类型
enum NRToastType {
    case success
    case error
    case warning
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tintColor: UIColor {
        switch self {
        case .success: return DesignToken.Color.success
        case .error: return DesignToken.Color.error
        case .warning: return DesignToken.Color.warning
        case .info: return DesignToken.Color.info
        }
    }
}

// MARK: - Toast 管理器
/// 全局 Toast 管理器，负责显示和管理 Toast 提示
final class NRToast {

    // MARK: - 单例
    static let shared = NRToast()

    private init() {}

    // MARK: - 公共方法

    /// 显示 Toast 提示
    /// - Parameters:
    ///   - message: 提示文字
    ///   - type: Toast 类型
    ///   - duration: 显示时长（默认2秒）
    func show(message: String, type: NRToastType = .info, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            self?.presentToast(message: message, type: type, duration: duration)
        }
    }

    /// 便捷方法：成功提示
    func success(_ message: String) {
        show(message: message, type: .success)
    }

    /// 便捷方法：错误提示
    func error(_ message: String) {
        show(message: message, type: .error)
    }

    /// 便捷方法：警告提示
    func warning(_ message: String) {
        show(message: message, type: .warning)
    }

    // MARK: - 私有方法
    private func presentToast(message: String, type: NRToastType, duration: TimeInterval) {
        // 移除已存在的 Toast
        UIApplication.shared.windows.first?.subviews
            .compactMap { $0 as? ToastView }
            .forEach { $0.removeFromSuperview() }

        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }

        let toastView = ToastView(message: message, type: type)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(toastView)

        // 约束（顶部显示，避开安全区）
        NSLayoutConstraint.activate([
            toastView.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: DesignToken.Spacing.md), // 顶部间距12pt
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: DesignToken.Spacing.lg), // 左右最小边距16pt
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -DesignToken.Spacing.lg),
            toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor)
        ])

        // 入场动画（从顶部滑入）
        toastView.alpha = 0
        toastView.transform = CGAffineTransform(translationX: 0, y: -50) // 从上方50pt滑入
        UIView.animate(withDuration: DesignToken.Animation.normal, delay: 0, options: .curveEaseOut) {
            toastView.alpha = 1
            toastView.transform = .identity
        }

        // 自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak toastView] in
            guard let toastView = toastView else { return }
            UIView.animate(withDuration: DesignToken.Animation.normal, animations: {
                toastView.alpha = 0
                toastView.transform = CGAffineTransform(translationX: 0, y: -20)
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }
}

// MARK: - Toast 视图
private final class ToastView: UIView {

    private let iconImageView = UIImageView()
    private let messageLabel = UILabel()
    private let stackView = UIStackView()

    init(message: String, type: NRToastType) {
        super.init(frame: .zero)
        setupUI()
        configure(message: message, type: type)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        backgroundColor = DesignToken.Color.backgroundPrimary
        layer.cornerRadius = DesignToken.Radius.lg // Toast圆角12pt
        applyShadow(DesignToken.Shadow.md) // 中阴影，悬浮效果

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = DesignToken.Spacing.sm // 图标与文字间距8pt
        addSubview(stackView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        stackView.addArrangedSubview(iconImageView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = DesignToken.Font.subhead // Toast文字15pt
        messageLabel.textColor = DesignToken.Color.textPrimary
        messageLabel.numberOfLines = 0
        stackView.addArrangedSubview(messageLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: DesignToken.Spacing.md), // 内边距12pt
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignToken.Spacing.md),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.lg), // 左右内边距16pt
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg),

            iconImageView.widthAnchor.constraint(equalToConstant: 20), // 图标尺寸20pt
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func configure(message: String, type: NRToastType) {
        iconImageView.image = UIImage(systemName: type.iconName)
        iconImageView.tintColor = type.tintColor
        messageLabel.text = message
    }
}
