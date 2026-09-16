import UIKit
import Combine

/// 同步视图控制器
final class SyncViewController: UIViewController {

    private let syncEngine = AppContainer.shared.syncEngine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI 组件
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentView = UIView()

    private let statusCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DesignToken.Color.backgroundPrimary
        v.layer.cornerRadius = DesignToken.Radius.lg // 圆角16pt
        return v
    }()

    private let statusIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = DesignToken.Color.primary
        return iv
    }()

    private let statusTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.title3
        label.textColor = DesignToken.Color.textPrimary
        label.textAlignment = .center
        return label
    }()

    private let statusDetailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.subhead
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.progressTintColor = DesignToken.Color.primary
        pv.trackTintColor = DesignToken.Color.separator
        pv.isHidden = true
        return pv
    }()

    private lazy var syncButton: NRButton = {
        let btn = NRButton(type: .primary)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("开始同步", for: .normal)
        btn.addTarget(self, action: #selector(startSync), for: .touchUpInside)
        return btn
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption1
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "同步数据将保存到 GitHub 仓库\n包含书籍、章节、阅读进度和书签"
        return label
    }()

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        updateStatus()
        bindSyncStatus()
    }

    // MARK: - UI 搭建
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(statusCard)
        statusCard.addSubview(statusIconView)
        statusCard.addSubview(statusTitleLabel)
        statusCard.addSubview(statusDetailLabel)
        statusCard.addSubview(progressView)
        contentView.addSubview(syncButton)
        contentView.addSubview(infoLabel)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            statusCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignToken.Spacing.xl),
            statusCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg),
            statusCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.lg),

            statusIconView.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: DesignToken.Spacing.xl),
            statusIconView.centerXAnchor.constraint(equalTo: statusCard.centerXAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 48), // 图标尺寸48pt
            statusIconView.heightAnchor.constraint(equalToConstant: 48),

            statusTitleLabel.topAnchor.constraint(equalTo: statusIconView.bottomAnchor, constant: DesignToken.Spacing.md),
            statusTitleLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: DesignToken.Spacing.lg),
            statusTitleLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -DesignToken.Spacing.lg),

            statusDetailLabel.topAnchor.constraint(equalTo: statusTitleLabel.bottomAnchor, constant: DesignToken.Spacing.sm),
            statusDetailLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: DesignToken.Spacing.lg),
            statusDetailLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -DesignToken.Spacing.lg),

            progressView.topAnchor.constraint(equalTo: statusDetailLabel.bottomAnchor, constant: DesignToken.Spacing.lg),
            progressView.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: DesignToken.Spacing.xl),
            progressView.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -DesignToken.Spacing.xl),
            progressView.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -DesignToken.Spacing.xl),

            syncButton.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: DesignToken.Spacing.xl),
            syncButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg),
            syncButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            syncButton.heightAnchor.constraint(equalToConstant: 48), // 按钮高度48pt

            infoLabel.topAnchor.constraint(equalTo: syncButton.bottomAnchor, constant: DesignToken.Spacing.lg),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.xl),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.xl),
            infoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignToken.Spacing.xl)
        ])
    }

    private func setupNavigationBar() {
        title = "同步"
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - 状态更新
    private func updateStatus() {
        let isLoggedIn = AppContainer.shared.authService.loadSavedToken() != nil

        if !isLoggedIn {
            statusIconView.image = UIImage(systemName: "person.crop.circle.badge.questionmark")
            statusTitleLabel.text = "未登录 GitHub"
            statusDetailLabel.text = "请先在「我的」页面登录 GitHub 账号"
            syncButton.isEnabled = false
            syncButton.setTitle("请先登录", for: .normal)
        } else {
            statusIconView.image = UIImage(systemName: "checkmark.circle.fill")
            statusTitleLabel.text = "已连接 GitHub"
            statusDetailLabel.text = "数据将同步到 MyNovels 仓库"
            syncButton.isEnabled = true
            syncButton.setTitle("开始下载", for: .normal)
        }
    }

    private func bindSyncStatus() {
        syncEngine.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleSyncStatus(status)
            }
            .store(in: &cancellables)
    }

    private func handleSyncStatus(_ status: SyncStatus) {
        switch status {
        case .idle:
            progressView.isHidden = true
            syncButton.isEnabled = true
            syncButton.setTitle("开始下载", for: .normal)
        case .pulling(let progress):
            progressView.isHidden = false
            progressView.setProgress(Float(progress), animated: true)
            statusTitleLabel.text = "正在拉取..."
            statusDetailLabel.text = "从 GitHub 拉取最新数据"
            syncButton.isEnabled = false
        case .idle:
            progressView.isHidden = true
            statusIconView.image = UIImage(systemName: "checkmark.circle.fill")
            statusIconView.tintColor = DesignToken.Color.success
            statusTitleLabel.text = "同步完成"
            statusDetailLabel.text = "数据已同步"
            syncButton.isEnabled = true
            syncButton.setTitle("再次下载", for: .normal)
        case .error(let message):
            progressView.isHidden = true
            statusIconView.image = UIImage(systemName: "xmark.circle.fill")
            statusIconView.tintColor = DesignToken.Color.error
            statusTitleLabel.text = "同步失败"
            statusDetailLabel.text = message
            syncButton.isEnabled = true
            syncButton.setTitle("重试", for: .normal)
            NRToast.shared.error(message)
        case .merging:
            statusTitleLabel.text = "正在处理..."
            statusDetailLabel.text = "下载并保存章节数据"
        }
    }

    // MARK: - 动作
    @objc private func startSync() {
        guard AppContainer.shared.authService.loadSavedToken() != nil else {
            NRToast.shared.error("请先登录 GitHub")
            return
        }

        syncEngine.startSync()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}
