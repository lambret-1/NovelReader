import UIKit

/// 阅读器上工具栏 - 返回按钮 + 章节标题
final class NRReaderTopBar: UIView {

    // MARK: - 回调
    var onBackButtonTapped: (() -> Void)?

    // MARK: - UI 组件
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let separatorView = UIView()

    private lazy var backButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "chevron.left"), for: .normal) // 返回箭头图标
        btn.tintColor = DesignToken.Color.textPrimary
        btn.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        btn.accessibilityLabel = "返回"
        btn.accessibilityHint = "双击返回书架"
        return btn
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.headline // 标题字体17pt
        label.textColor = DesignToken.Color.textPrimary
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail // 超长截断
        label.numberOfLines = 1
        return label
    }()

    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        // 毛玻璃背景
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.alpha = 0.95 // 毛玻璃透明度0.95，确保文字清晰
        addSubview(blurView)

        // 底部分割线
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = DesignToken.Color.separator
        addSubview(separatorView)

        // 返回按钮
        addSubview(backButton)
        // 章节标题
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // 毛玻璃铺满
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 底部分割线
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5), // 分割线0.5pt

            // 返回按钮 - 左侧
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.md), // 左边距12pt
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40), // 按钮触控区域40pt
            backButton.heightAnchor.constraint(equalToConstant: 40),

            // 章节标题 - 居中，左右留边距
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: DesignToken.Spacing.sm), // 左边距8pt
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg), // 右边距16pt
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: - 动作
    @objc private func backButtonTapped() {
        FeedbackManager.shared.lightImpact()
        onBackButtonTapped?()
    }

    // MARK: - 公共方法
    /// 设置章节标题
    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    /// 更新夜间模式
    func updateForNightMode(_ isNight: Bool) {
        if isNight {
            blurView.effect = UIBlurEffect(style: .dark)
            backButton.tintColor = DesignToken.Color.textInverse
            titleLabel.textColor = DesignToken.Color.textInverse
            separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        } else {
            blurView.effect = UIBlurEffect(style: .systemMaterial)
            backButton.tintColor = DesignToken.Color.textPrimary
            titleLabel.textColor = DesignToken.Color.textPrimary
            separatorView.backgroundColor = DesignToken.Color.separator
        }
    }
}
