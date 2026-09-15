import UIKit

// MARK: - 徽章类型
/// 徽章样式类型
enum NRBadgeType {
    /// 数字徽章（未读数量）
    case count(Int)
    /// 状态徽章（文字）
    case status(String, NRBadgeStatus)
    /// 标签徽章（纯文字）
    case tag(String)
}

/// 徽章状态颜色
enum NRBadgeStatus {
    case success
    case warning
    case error
    case info
    case neutral

    var backgroundColor: UIColor {
        switch self {
        case .success: return DesignToken.Color.success.withAlphaComponent(0.15)
        case .warning: return DesignToken.Color.warning.withAlphaComponent(0.15)
        case .error: return DesignToken.Color.error.withAlphaComponent(0.15)
        case .info: return DesignToken.Color.info.withAlphaComponent(0.15)
        case .neutral: return DesignToken.Color.backgroundTertiary
        }
    }

    var textColor: UIColor {
        switch self {
        case .success: return DesignToken.Color.success
        case .warning: return DesignToken.Color.warning
        case .error: return DesignToken.Color.error
        case .info: return DesignToken.Color.info
        case .neutral: return DesignToken.Color.textSecondary
        }
    }
}

// MARK: - 自定义徽章
/// 生产级徽章组件，支持数字/状态/标签三种类型
final class NRBadge: UIView {

    // MARK: - 属性
    private let badgeType: NRBadgeType
    private let textLabel = UILabel()

    // MARK: - 初始化
    init(type: NRBadgeType) {
        self.badgeType = type
        super.init(frame: .zero)
        setupUI()
        configure(with: type)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = DesignToken.Radius.full // 胶囊形状
        clipsToBounds = true

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = DesignToken.Font.caption1 // 徽章字号12pt
        textLabel.textAlignment = .center
        addSubview(textLabel)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2), // 上下内边距2pt
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.sm), // 左右内边距8pt
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.sm)
        ])
    }

    // MARK: - 配置
    private func configure(with type: NRBadgeType) {
        switch type {
        case .count(let count):
            textLabel.text = count > 99 ? "99+" : "\(count)"
            textLabel.textColor = DesignToken.Color.textInverse
            backgroundColor = DesignToken.Color.error
            // 数字徽章最小尺寸
            widthAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true // 最小宽度20pt，容纳数字
            heightAnchor.constraint(equalToConstant: 20).isActive = true

        case .status(let text, let status):
            textLabel.text = text
            textLabel.textColor = status.textColor
            backgroundColor = status.backgroundColor
            heightAnchor.constraint(equalToConstant: 22).isActive = true // 状态徽章高度22pt

        case .tag(let text):
            textLabel.text = text
            textLabel.textColor = DesignToken.Color.textSecondary
            backgroundColor = DesignToken.Color.backgroundTertiary
            heightAnchor.constraint(equalToConstant: 20).isActive = true
        }
    }

    // MARK: - 更新
    /// 更新徽章内容
    func update(with type: NRBadgeType) {
        configure(with: type)
    }
}
