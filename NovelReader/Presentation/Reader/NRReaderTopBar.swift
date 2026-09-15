import UIKit

/// 阅读器上工具栏 - 更多菜单按钮
final class NRReaderTopBar: UIView {

    // MARK: - 回调
    var onMoreButtonTapped: (() -> Void)?

    // MARK: - UI 组件
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let separatorView = UIView()
    private lazy var moreButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "ellipsis"), for: .normal) // 三个竖点图标
        btn.tintColor = DesignToken.Color.textPrimary
        btn.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
        btn.accessibilityLabel = "更多菜单"
        btn.accessibilityHint = "双击打开更多选项"
        return btn
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
        blurView.alpha = 0.9 // 毛玻璃透明度0.9
        addSubview(blurView)

        // 底部分割线
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = DesignToken.Color.separator
        addSubview(separatorView)

        // 更多按钮
        addSubview(moreButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5), // 分割线0.5pt

            moreButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg), // 右边距16pt
            moreButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 32), // 按钮触控区域32pt
            moreButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - 动作
    @objc private func moreButtonTapped() {
        FeedbackManager.shared.lightImpact()
        onMoreButtonTapped?()
    }

    // MARK: - 公共方法
    /// 更新夜间模式
    func updateForNightMode(_ isNight: Bool) {
        if isNight {
            blurView.effect = UIBlurEffect(style: .dark)
            moreButton.tintColor = DesignToken.Color.textInverse
            separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        } else {
            blurView.effect = UIBlurEffect(style: .systemMaterial)
            moreButton.tintColor = DesignToken.Color.textPrimary
            separatorView.backgroundColor = DesignToken.Color.separator
        }
    }
}
