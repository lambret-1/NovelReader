import UIKit

// MARK: - 单元格类型
/// 单元格样式类型
enum NRCellType {
    /// 标准型：图标+标题+副标题+右箭头
    case standard
    /// 值类型：标题+右侧值
    case value
    /// 开关型：标题+UISwitch
    case `switch`
    /// 按钮型：居中文字按钮
    case button
    /// 危险按钮型：居中红色文字
    case dangerButton
}

// MARK: - 自定义单元格
/// 生产级列表单元格组件，支持5种样式
final class NRTableViewCell: UITableViewCell {

    // MARK: - 属性
    private let cellType: NRCellType
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let switchControl = UISwitch()
    private let stackView = UIStackView()

    /// 开关值变化回调
    var onSwitchChanged: ((Bool) -> Void)?

    /// 按钮点击回调
    var onButtonTapped: (() -> Void)?

    // MARK: - 初始化
    init(type: NRCellType = .standard, reuseIdentifier: String? = nil) {
        self.cellType = type
        super.init(style: .default, reuseIdentifier: reuseIdentifier ?? "NRTableViewCell")
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = DesignToken.Color.backgroundPrimary

        switch cellType {
        case .standard:
            setupStandardCell()
        case .value:
            setupValueCell()
        case .switch:
            setupSwitchCell()
        case .button, .dangerButton:
            setupButtonCell()
        }
    }

    /// 标准型单元格
    private func setupStandardCell() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = DesignToken.Spacing.md // 图标与文字间距12pt
        contentView.addSubview(stackView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = DesignToken.Color.primary
        stackView.addArrangedSubview(iconImageView)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2 // 标题与副标题间距2pt
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(textStack)

        let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowImageView.tintColor = DesignToken.Color.textTertiary
        arrowImageView.contentMode = .scaleAspectFit
        stackView.addArrangedSubview(arrowImageView)

        titleLabel.font = DesignToken.Font.headline // 标题17pt半粗
        titleLabel.textColor = DesignToken.Color.textPrimary
        subtitleLabel.font = DesignToken.Font.footnote // 副标题13pt
        subtitleLabel.textColor = DesignToken.Color.textSecondary
        subtitleLabel.isHidden = true

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg), // 左右边距16pt
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: DesignToken.Spacing.md), // 上下最小边距12pt
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -DesignToken.Spacing.md),

            iconImageView.widthAnchor.constraint(equalToConstant: DesignToken.Size.iconStandard), // 图标24pt
            iconImageView.heightAnchor.constraint(equalToConstant: DesignToken.Size.iconStandard),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12), // 箭头12pt
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    /// 值类型单元格
    private func setupValueCell() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = DesignToken.Font.body // 标题17pt
        titleLabel.textColor = DesignToken.Color.textPrimary
        valueLabel.font = DesignToken.Font.body
        valueLabel.textColor = DesignToken.Color.textSecondary
        valueLabel.textAlignment = .right

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DesignToken.Spacing.md)
        ])
    }

    /// 开关型单元格
    private func setupSwitchCell() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchControl)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        switchControl.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = DesignToken.Font.body
        titleLabel.textColor = DesignToken.Color.textPrimary
        switchControl.onTintColor = DesignToken.Color.primary // 开关开启色为主色
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    /// 按钮型单元格
    private func setupButtonCell() {
        contentView.addSubview(titleLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.font = DesignToken.Font.headline

        if cellType == .dangerButton {
            titleLabel.textColor = DesignToken.Color.error // 危险按钮红色
        } else {
            titleLabel.textColor = DesignToken.Color.primary
        }

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGesture)
    }

    // MARK: - 配置方法
    /// 配置标准型单元格
    func configure(title: String, subtitle: String? = nil, icon: UIImage? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        iconImageView.image = icon
        iconImageView.isHidden = icon == nil
    }

    /// 配置值类型单元格
    func configure(title: String, value: String?) {
        titleLabel.text = title
        valueLabel.text = value
    }

    /// 配置开关型单元格
    func configure(title: String, isOn: Bool) {
        titleLabel.text = title
        switchControl.isOn = isOn
    }

    /// 配置按钮型单元格
    func configure(buttonTitle: String) {
        titleLabel.text = buttonTitle
    }

    // MARK: - 事件
    @objc private func switchValueChanged() {
        onSwitchChanged?(switchControl.isOn)
    }

    @objc private func cellTapped() {
        onButtonTapped?()
        // 点击缩放反馈
        UIView.animate(withDuration: DesignToken.Animation.fast, animations: {
            self.contentView.alpha = 0.7
        }) { _ in
            UIView.animate(withDuration: DesignToken.Animation.fast) {
                self.contentView.alpha = 1.0
            }
        }
    }

    // MARK: - 复用
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        valueLabel.text = nil
        iconImageView.image = nil
        switchControl.isOn = false
    }
}
