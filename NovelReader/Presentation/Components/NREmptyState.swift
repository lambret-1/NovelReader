import UIKit

// MARK: - 空态视图
/// 生产级空态视图组件，用于无数据/加载失败/搜索无结果等场景
final class NREmptyState: UIView {

    // MARK: - 属性
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionButton = NRButton(type: .primary)
    private let stackView = UIStackView()

    /// 操作按钮点击回调
    var onAction: (() -> Void)?

    // MARK: - 初始化
    init(icon: UIImage?, title: String, subtitle: String? = nil, actionTitle: String? = nil) {
        super.init(frame: .zero)
        setupUI()
        configure(icon: icon, title: title, subtitle: subtitle, actionTitle: actionTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // 垂直堆叠视图
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = DesignToken.Spacing.md // 元素间距12pt
        addSubview(stackView)

        // 图标
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = DesignToken.Color.textTertiary
        stackView.addArrangedSubview(iconImageView)

        // 标题
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignToken.Font.title3 // 空态标题20pt半粗
        titleLabel.textColor = DesignToken.Color.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stackView.addArrangedSubview(titleLabel)

        // 副标题
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = DesignToken.Font.subhead // 副标题15pt
        subtitleLabel.textColor = DesignToken.Color.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        stackView.addArrangedSubview(subtitleLabel)

        // 操作按钮
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isHidden = true
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        stackView.addArrangedSubview(actionButton)

        // 约束
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignToken.Spacing.xl), // 左右最小边距24pt
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignToken.Spacing.xl),

            iconImageView.widthAnchor.constraint(equalToConstant: 64), // 空态图标64pt，醒目但不占过多空间
            iconImageView.heightAnchor.constraint(equalToConstant: 64),

            actionButton.widthAnchor.constraint(equalToConstant: 200) // 按钮宽度200pt
        ])

        // 副标题和按钮之间增加间距
        stackView.setCustomSpacing(DesignToken.Spacing.lg, after: subtitleLabel) // 副标题与按钮间距16pt
    }

    // MARK: - 配置
    private func configure(icon: UIImage?, title: String, subtitle: String?, actionTitle: String?) {
        iconImageView.image = icon
        iconImageView.isHidden = icon == nil
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil

        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }

    // MARK: - 事件
    @objc private func actionTapped() {
        onAction?()
    }

    // MARK: - 便捷方法
    /// 显示空态
    func show(in view: UIView) {
        view.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// 隐藏并移除
    func hide() {
        removeFromSuperview()
    }
}
