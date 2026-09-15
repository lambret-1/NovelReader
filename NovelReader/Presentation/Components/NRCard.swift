import UIKit

// MARK: - 卡片样式
/// 卡片样式变体
enum NRCardStyle {
    /// 标准卡片 - 浅灰背景
    case standard
    /// 悬浮卡片 - 带阴影
    case elevated
    /// 选中卡片 - 主色边框
    case selected
    /// 透明卡片 - 无边框无背景
    case plain
}

// MARK: - 自定义卡片
/// 生产级卡片组件，支持多种样式和内容布局
final class NRCard: UIView {

    // MARK: - 属性
    private let cardStyle: NRCardStyle

    /// 内容容器视图，所有子视图添加到此容器
    let contentView = UIView()

    /// 点击回调
    var onTap: (() -> Void)?

    private let tapGesture = UITapGestureRecognizer()

    // MARK: - 初始化
    init(style: NRCardStyle = .standard) {
        self.cardStyle = style
        super.init(frame: .zero)
        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: DesignToken.Spacing.md), // 卡片内边距12pt
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.lg), // 左右内边距16pt
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignToken.Spacing.md)
        ])

        applyStyle()
    }

    private func applyStyle() {
        layer.cornerRadius = DesignToken.Radius.xl // 卡片圆角16pt，视觉柔和

        switch cardStyle {
        case .standard:
            backgroundColor = DesignToken.Color.backgroundSecondary
            layer.borderWidth = 0
        case .elevated:
            backgroundColor = DesignToken.Color.backgroundPrimary
            applyShadow(DesignToken.Shadow.sm) // 小阴影，卡片悬浮效果
        case .selected:
            backgroundColor = DesignToken.Color.primaryBackground
            layer.borderWidth = 2 // 选中边框2pt，突出显示
            layer.borderColor = DesignToken.Color.primary.cgColor
        case .plain:
            backgroundColor = .clear
            layer.borderWidth = 0
        }
    }

    // MARK: - 手势
    private func setupGesture() {
        tapGesture.addTarget(self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        // 点击缩放反馈
        UIView.animate(withDuration: DesignToken.Animation.fast, animations: {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98) // 按下缩放0.98
        }) { _ in
            UIView.animate(withDuration: DesignToken.Animation.fast) {
                self.transform = .identity
            }
        }
        onTap?()
    }

    // MARK: - 便捷方法
    /// 设置是否可点击
    func setTapEnabled(_ enabled: Bool) {
        tapGesture.isEnabled = enabled
    }
}
