import UIKit

/// 阅读器下工具栏 - 目录按钮 + 全书进度条 + 设置按钮
final class NRReaderBottomBar: UIView {

    // MARK: - 回调
    var onCatalogTapped: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onProgressTapped: (() -> Void)?

    // MARK: - UI 组件
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let separatorView = UIView()

    private lazy var catalogButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "list.bullet"), for: .normal) // 目录图标
        btn.tintColor = DesignToken.Color.textPrimary
        btn.accessibilityLabel = "目录"
        btn.accessibilityHint = "双击打开章节目录"
        btn.addTarget(self, action: #selector(catalogTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var catalogLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "目录"
        label.font = DesignToken.Font.caption2 // 目录文字10pt
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        return label
    }()

    private let progressView = NRReaderProgressView()

    private lazy var settingsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "gearshape.fill"), for: .normal) // 设置齿轮图标
        btn.tintColor = DesignToken.Color.textPrimary
        btn.accessibilityLabel = "阅读设置"
        btn.accessibilityHint = "双击打开阅读设置面板"
        btn.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var settingsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "设置"
        label.font = DesignToken.Font.caption2 // 设置文字10pt
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        return label
    }()

    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        // 毛玻璃背景
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.alpha = 0.9
        addSubview(blurView)

        // 顶部分割线
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = DesignToken.Color.separator
        addSubview(separatorView)

        // 目录按钮容器
        let catalogContainer = UIStackView()
        catalogContainer.translatesAutoresizingMaskIntoConstraints = false
        catalogContainer.axis = .vertical
        catalogContainer.spacing = 2 // 图标与文字间距2pt
        catalogContainer.alignment = .center
        catalogContainer.addArrangedSubview(catalogButton)
        catalogContainer.addArrangedSubview(catalogLabel)
        addSubview(catalogContainer)

        // 进度条
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        // 设置按钮容器
        let settingsContainer = UIStackView()
        settingsContainer.translatesAutoresizingMaskIntoConstraints = false
        settingsContainer.axis = .vertical
        settingsContainer.spacing = 2 // 图标与文字间距2pt
        settingsContainer.alignment = .center
        settingsContainer.addArrangedSubview(settingsButton)
        settingsContainer.addArrangedSubview(settingsLabel)
        addSubview(settingsContainer)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),

            catalogContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.lg), // 左边距16pt
            catalogContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            catalogContainer.widthAnchor.constraint(equalToConstant: 44), // 目录按钮宽度44pt

            settingsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg), // 右边距16pt
            settingsContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsContainer.widthAnchor.constraint(equalToConstant: 44), // 设置按钮宽度44pt

            progressView.leadingAnchor.constraint(equalTo: catalogContainer.trailingAnchor, constant: DesignToken.Spacing.md), // 进度条左边距12pt
            progressView.trailingAnchor.constraint(equalTo: settingsContainer.leadingAnchor, constant: -DesignToken.Spacing.md),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),

            catalogButton.widthAnchor.constraint(equalToConstant: 24), // 图标24pt
            catalogButton.heightAnchor.constraint(equalToConstant: 24),
            settingsButton.widthAnchor.constraint(equalToConstant: 24), // 设置图标24pt
            settingsButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    // MARK: - 手势
    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(progressTapped))
        progressView.addGestureRecognizer(tapGesture)
        progressView.isUserInteractionEnabled = true
    }

    // MARK: - 动作
    @objc private func catalogTapped() {
        FeedbackManager.shared.lightImpact()
        onCatalogTapped?()
    }

    @objc private func settingsTapped() {
        FeedbackManager.shared.mediumImpact()
        onSettingsTapped?()
    }

    @objc private func progressTapped() {
        FeedbackManager.shared.lightImpact()
        onProgressTapped?()
    }

    // MARK: - 公共方法
    /// 设置进度
    func setProgress(_ progress: Double, animated: Bool = true) {
        progressView.setProgress(progress, animated: animated)
    }

    /// 更新夜间模式（外部调用，仅更新背景和文字颜色）
    func setNightMode(_ isNight: Bool) {
        if isNight {
            blurView.effect = UIBlurEffect(style: .dark)
            separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            catalogButton.tintColor = DesignToken.Color.textInverse
            settingsButton.tintColor = DesignToken.Color.textInverse
            catalogLabel.textColor = DesignToken.Color.textSecondary
            settingsLabel.textColor = DesignToken.Color.textSecondary
        } else {
            blurView.effect = UIBlurEffect(style: .systemMaterial)
            separatorView.backgroundColor = DesignToken.Color.separator
            catalogButton.tintColor = DesignToken.Color.textPrimary
            settingsButton.tintColor = DesignToken.Color.textPrimary
            catalogLabel.textColor = DesignToken.Color.textSecondary
            settingsLabel.textColor = DesignToken.Color.textSecondary
        }
    }
}
