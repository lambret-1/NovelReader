import UIKit

// MARK: - 按钮类型
/// 按钮样式类型
enum NRButtonType {
    /// 主按钮 - 琥珀色填充
    case primary
    /// 次按钮 - 灰色填充
    case secondary
    /// 文字按钮 - 透明背景
    case text
    /// 危险按钮 - 红色填充
    case danger
    /// 幽灵按钮 - 透明背景+边框
    case ghost
}

// MARK: - 自定义按钮
/// 生产级按钮组件，支持多种样式、加载态、禁用态
final class NRButton: UIButton {

    // MARK: - 属性
    private let style: NRButtonType
    private var originalTitle: String?
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    /// 是否处于加载状态
    var isLoading: Bool = false {
        didSet { updateLoadingState() }
    }

    // MARK: - 初始化
    init(type: NRButtonType = .primary, title: String? = nil) {
        self.style = type
        super.init(frame: .zero)
        self.originalTitle = title
        setupUI(title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI(title: String?) {
        setTitle(title, for: .normal)
        titleLabel?.font = DesignToken.Font.headline
        layer.cornerRadius = DesignToken.Radius.lg // 按钮圆角12pt，触控友好
        clipsToBounds = true

        // 高度约束
        heightAnchor.constraint(equalToConstant: DesignToken.Size.buttonHeight).isActive = true // 按钮高度48pt，符合HIG触控目标

        applyStyle(for: .normal)

        // 加载指示器
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: - 样式应用
    private func applyStyle(for state: UIControl.State) {
        switch style {
        case .primary:
            backgroundColor = state == .highlighted ? DesignToken.Color.primaryPressed : DesignToken.Color.primary
            setTitleColor(DesignToken.Color.textInverse, for: .normal)
            setTitleColor(DesignToken.Color.textInverse.withAlphaComponent(0.7), for: .highlighted)
        case .secondary:
            backgroundColor = DesignToken.Color.backgroundTertiary
            setTitleColor(DesignToken.Color.textPrimary, for: .normal)
            setTitleColor(DesignToken.Color.textSecondary, for: .highlighted)
        case .text:
            backgroundColor = .clear
            setTitleColor(DesignToken.Color.primary, for: .normal)
            setTitleColor(DesignToken.Color.primaryPressed, for: .highlighted)
        case .danger:
            backgroundColor = state == .highlighted ? DesignToken.Color.error.withAlphaComponent(0.8) : DesignToken.Color.error
            setTitleColor(DesignToken.Color.textInverse, for: .normal)
        case .ghost:
            backgroundColor = .clear
            layer.borderWidth = 1 // 边框宽度1pt，清晰可见
            layer.borderColor = DesignToken.Color.border.cgColor
            setTitleColor(DesignToken.Color.textPrimary, for: .normal)
        }

        // 禁用态
        if state == .disabled {
            alpha = 0.5 // 禁用时透明度0.5，视觉反馈明确
        } else {
            alpha = 1.0
        }
    }

    // MARK: - 状态更新
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: DesignToken.Animation.fast) {
                self.applyStyle(for: self.isHighlighted ? .highlighted : .normal)
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity // 按下缩放0.97，触觉反馈
            }
        }
    }

    override var isEnabled: Bool {
        didSet {
            applyStyle(for: isEnabled ? .normal : .disabled)
        }
    }

    private func updateLoadingState() {
        if isLoading {
            originalTitle = title(for: .normal)
            setTitle(nil, for: .normal)
            activityIndicator.startAnimating()
            isEnabled = false
        } else {
            setTitle(originalTitle, for: .normal)
            activityIndicator.stopAnimating()
            isEnabled = true
        }
    }
}
