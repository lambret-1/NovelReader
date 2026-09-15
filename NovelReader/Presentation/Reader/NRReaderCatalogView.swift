import UIKit

/// 阅读器章节目录侧边栏
final class NRReaderCatalogView: UIView {

    // MARK: - 回调
    var onChapterSelected: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - 属性
    private var chapters: [Chapter] = []
    private var currentChapterIndex: Int = 0

    // MARK: - UI 组件
    private let backgroundView = UIView()
    private let containerView = UIView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton()
    private let separatorView = UIView()
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "ChapterCell")
        tv.separatorStyle = .none
        tv.backgroundColor = DesignToken.Color.backgroundPrimary
        tv.contentInset = UIEdgeInsets(top: DesignToken.Spacing.sm, left: 0, bottom: 0, right: 0)
        return tv
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

        // 背景遮罩
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4) // 遮罩透明度0.4
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tapGesture)
        addSubview(backgroundView)

        // 容器
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = DesignToken.Color.backgroundPrimary
        containerView.applyShadow(DesignToken.Shadow.lg) // 大阴影
        addSubview(containerView)

        // 头部
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = DesignToken.Color.backgroundPrimary
        containerView.addSubview(headerView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "目录"
        titleLabel.font = DesignToken.Font.headline // 标题17pt半粗
        titleLabel.textColor = DesignToken.Color.textPrimary
        headerView.addSubview(titleLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = DesignToken.Color.textSecondary
        closeButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        closeButton.accessibilityLabel = "关闭目录"
        headerView.addSubview(closeButton)

        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = DesignToken.Color.separator
        headerView.addSubview(separatorView)

        // 列表
        containerView.addSubview(tableView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.7), // 宽度70%

            headerView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56), // 头部高度56pt

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: DesignToken.Spacing.lg),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            separatorView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    // MARK: - 配置
    func configure(chapters: [Chapter], currentIndex: Int) {
        self.chapters = chapters
        self.currentChapterIndex = currentIndex
        tableView.reloadData()

        // 滚动到当前章节
        if currentIndex < chapters.count {
            let indexPath = IndexPath(row: currentIndex, section: 0)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        }
    }

    // MARK: - 动作
    @objc private func dismiss() {
        UIView.animate(withDuration: DesignToken.Animation.normal, animations: {
            self.containerView.transform = CGAffineTransform(translationX: -self.containerView.bounds.width, y: 0)
            self.backgroundView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        }
    }

    // MARK: - 显示
    func show(in view: UIView) {
        view.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 入场动画
        containerView.transform = CGAffineTransform(translationX: -containerView.bounds.width, y: 0)
        backgroundView.alpha = 0
        UIView.animate(withDuration: DesignToken.Animation.normal, delay: 0, options: .curveEaseInOut) {
            self.containerView.transform = .identity
            self.backgroundView.alpha = 1
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension NRReaderCatalogView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        chapters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChapterCell", for: indexPath)
        let chapter = chapters[indexPath.row]
        let isCurrent = indexPath.row == currentChapterIndex

        cell.textLabel?.text = chapter.title
        cell.textLabel?.font = isCurrent ? DesignToken.Font.headline : DesignToken.Font.body
        cell.textLabel?.textColor = isCurrent ? DesignToken.Color.primary : DesignToken.Color.textPrimary
        cell.backgroundColor = isCurrent ? DesignToken.Color.primaryBackground : DesignToken.Color.backgroundPrimary
        cell.selectionStyle = .none

        // 当前章节左侧指示条
        if isCurrent {
            let indicator = UIView()
            indicator.backgroundColor = DesignToken.Color.primary
            indicator.frame = CGRect(x: 0, y: 14, width: 3, height: 24) // 指示条3pt宽
            cell.contentView.addSubview(indicator)
        }

        // 章节序号
        cell.textLabel?.frame = CGRect(x: 16, y: 0, width: cell.bounds.width - 32, height: 52)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52 // 单元格高度52pt
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        FeedbackManager.shared.mediumImpact()
        onChapterSelected?(indexPath.row)
        dismiss()
    }
}
