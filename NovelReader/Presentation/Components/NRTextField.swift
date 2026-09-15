import UIKit

// MARK: - 自定义输入框
/// 生产级输入框组件，支持左侧图标、右侧清除按钮、错误状态
final class NRTextField: UIView, UITextFieldDelegate {

    // MARK: - 属性
    private let containerView = UIView()
    let textField = UITextField()
    private let iconImageView = UIImageView()
    private let clearButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    /// 左侧图标
    var leftIcon: UIImage? {
        didSet { updateLeftIcon() }
    }

    /// 占位符
    var placeholder: String? {
        didSet { updatePlaceholder() }
    }

    /// 错误信息（设置后显示红色边框和错误文字）
    var errorMessage: String? {
        didSet { updateErrorState() }
    }

    /// 文本内容
    var text: String? {
        get { textField.text }
        set { textField.text = newValue }
    }

    /// 文本变化回调
    var onTextChanged: ((String) -> Void)?

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

        // 容器
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = DesignToken.Color.backgroundSecondary
        containerView.layer.cornerRadius = DesignToken.Radius.md // 输入框圆角8pt
        containerView.layer.borderWidth = 1 // 边框1pt
        containerView.layer.borderColor = DesignToken.Color.border.cgColor
        addSubview(containerView)

        // 左侧图标
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = DesignToken.Color.textSecondary
        iconImageView.isHidden = true
        containerView.addSubview(iconImageView)

        // 输入框
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = DesignToken.Font.body
        textField.textColor = DesignToken.Color.textPrimary
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        containerView.addSubview(textField)

        // 清除按钮
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = DesignToken.Color.textTertiary
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(clearText), for: .touchUpInside)
        containerView.addSubview(clearButton)

        // 错误标签
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = DesignToken.Font.caption1
        errorLabel.textColor = DesignToken.Color.error
        errorLabel.isHidden = true
        errorLabel.numberOfLines = 0
        addSubview(errorLabel)

        // 约束
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: DesignToken.Size.inputHeight), // 输入框高度44pt

            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignToken.Spacing.md),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: DesignToken.Size.iconStandard), // 图标尺寸24pt
            iconImageView.heightAnchor.constraint(equalToConstant: DesignToken.Size.iconStandard),

            textField.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: DesignToken.Spacing.sm),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -DesignToken.Spacing.sm),

            clearButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignToken.Spacing.md),
            clearButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 20), // 清除按钮尺寸20pt
            clearButton.heightAnchor.constraint(equalToConstant: 20),

            errorLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: DesignToken.Spacing.xs),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.sm),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.sm),
            errorLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - 私有方法
    private func updateLeftIcon() {
        iconImageView.image = leftIcon
        iconImageView.isHidden = leftIcon == nil
    }

    private func updatePlaceholder() {
        if let placeholder = placeholder {
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: DesignToken.Color.textTertiary]
            )
        }
    }

    private func updateErrorState() {
        if let error = errorMessage, !error.isEmpty {
            errorLabel.text = error
            errorLabel.isHidden = false
            containerView.layer.borderColor = DesignToken.Color.error.cgColor
        } else {
            errorLabel.isHidden = true
            containerView.layer.borderColor = DesignToken.Color.border.cgColor
        }
    }

    @objc private func textFieldDidChange() {
        clearButton.isHidden = textField.text?.isEmpty ?? true
        onTextChanged?(textField.text ?? "")
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    @objc private func clearText() {
        textField.text = nil
        clearButton.isHidden = true
        onTextChanged?("")
    }

    // MARK: - UITextFieldDelegate
    func textFieldDidBeginEditing(_ textField: UITextField) {
        containerView.layer.borderColor = DesignToken.Color.primary.cgColor // 聚焦时边框变主色
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        containerView.layer.borderColor = errorMessage != nil ? DesignToken.Color.error.cgColor : DesignToken.Color.border.cgColor
    }
}
