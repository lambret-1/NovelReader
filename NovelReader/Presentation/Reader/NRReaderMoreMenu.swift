import UIKit

/// 阅读器更多菜单 - 气泡式弹出菜单
final class NRReaderMoreMenu: UIView {

    // MARK: - 菜单项类型
    enum MenuItemType {
        case fontSize
        case typography
        case bookmark
        case search
        case share
        case info

        var iconName: String {
            switch self {
            case .fontSize: return "textformat.size"
            case .typography: return "text.alignleft"
            case .bookmark: return "bookmark"
            case .search: return "magnifyingglass"
            case .share: return "square.and.arrow.up"
            case .info: return "info.circle"
            }
        }

        var title: String {
            switch self {
            case .fontSize: return "字号调节"
            case .typography: return "排版设置"
            case .bookmark: return "添加书签"
            case .search: return "搜索"
            case .share: return "分享"
            case .info: return "阅读信息"
            }
        }
    }

    // MARK: - 回调
    var onMenuItemSelected: ((MenuItemType) -> Void)?
    var onMenuDismissed: (() -> Void)?

    // MARK: - UI 组件
    private let backgroundView = UIView()
    private let menuContainer = UIView()
    private let arrowView = UIView()

    private let items: [MenuItemType] = [.fontSize, .typography, .bookmark, .search, .share, .info]

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

        // 背景遮罩
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4) // 遮罩透明度0.4
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tapGesture)
        addSubview(backgroundView)

        // 菜单容器
        menuContainer.translatesAutoresizingMaskIntoConstraints = false
        menuContainer.backgroundColor = DesignToken.Color.backgroundPrimary
        menuContainer.layer.cornerRadius = DesignToken.Radius.lg // 菜单圆角12pt
        menuContainer.applyShadow(DesignToken.Shadow.md) // 中阴影
        addSubview(menuContainer)

        // 箭头（三角形）
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.backgroundColor = DesignToken.Color.backgroundPrimary
        arrowView.transform = CGAffineTransform(rotationAngle: .pi / 4) // 旋转45度形成三角形
        addSubview(arrowView)

        // 菜单项
        var previousView: UIView?
        for (index, item) in items.enumerated() {
            let itemView = createMenuItemView(item, tag: index)
            menuContainer.addSubview(itemView)

            NSLayoutConstraint.activate([
                itemView.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor),
                itemView.heightAnchor.constraint(equalToConstant: 44), // 菜单项高度44pt
                itemView.topAnchor.constraint(equalTo: previousView?.bottomAnchor ?? menuContainer.topAnchor)
            ])

            // 分隔线（除了最后一项）
            if index < items.count - 1 {
                let separator = UIView()
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.backgroundColor = DesignToken.Color.separator
                menuContainer.addSubview(separator)
                NSLayoutConstraint.activate([
                    separator.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: DesignToken.Spacing.lg),
                    separator.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -DesignToken.Spacing.lg),
                    separator.bottomAnchor.constraint(equalTo: itemView.bottomAnchor),
                    separator.heightAnchor.constraint(equalToConstant: 0.5)
                ])
            }

            previousView = itemView
        }

        // 约束
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            menuContainer.topAnchor.constraint(equalTo: topAnchor, constant: 50), // 菜单顶部距离50pt（在工具栏下方）
            menuContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg), // 右边距16pt
            menuContainer.widthAnchor.constraint(equalToConstant: 200), // 菜单宽度200pt

            arrowView.topAnchor.constraint(equalTo: menuContainer.topAnchor, constant: -6), // 箭头位置
            arrowView.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -20),
            arrowView.widthAnchor.constraint(equalToConstant: 12), // 箭头大小12pt
            arrowView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    // MARK: - 创建菜单项
    private func createMenuItemView(_ item: MenuItemType, tag: Int) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tag = tag

        let iconView = UIImageView(image: UIImage(systemName: item.iconName))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = DesignToken.Color.primary
        iconView.contentMode = .scaleAspectFit
        view.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = item.title
        titleLabel.font = DesignToken.Font.body // 菜单项文字17pt
        titleLabel.textColor = DesignToken.Color.textPrimary
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.lg),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20), // 图标20pt
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DesignToken.Spacing.md),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignToken.Spacing.lg)
        ])

        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(menuItemTapped(_:)))
        view.addGestureRecognizer(tapGesture)

        return view
    }

    // MARK: - 动作
    @objc private func menuItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let item = items[view.tag]
        FeedbackManager.shared.lightImpact()
        onMenuItemSelected?(item)
        dismiss()
    }

    @objc private func dismiss() {
        UIView.animate(withDuration: DesignToken.Animation.fast, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.onMenuDismissed?()
        }
    }

    // MARK: - 公共方法
    /// 显示菜单
    func show(in view: UIView) {
        view.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 入场动画
        alpha = 0
        menuContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8) // 初始缩放0.8
        menuContainer.alpha = 0
        UIView.animate(withDuration: DesignToken.Animation.normal, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.alpha = 1
            self.menuContainer.transform = .identity
            self.menuContainer.alpha = 1
        }
    }
}
