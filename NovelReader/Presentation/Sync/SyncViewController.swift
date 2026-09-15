import UIKit
import Combine

/// 同步状态视图控制器
final class SyncViewController: UIViewController {
    private let viewModel: SyncViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI 组件
    private lazy var statusIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        return iv
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 18, weight: .medium) // 状态标题字号18pt，清晰醒目
        label.textAlignment = .center
        return label
    }()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14) // 详情文字14pt，辅助信息
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var repoInfoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium) // 仓库信息13pt，紧凑展示
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var changeRepoButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("修改仓库", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14) // 按钮文字14pt
        button.addTarget(self, action: #selector(changeRepoTapped), for: .touchUpInside)
        return button
    }()

    private lazy var progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.isHidden = true
        return pv
    }()

    private lazy var syncButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("立即同步", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold) // 主按钮17pt加粗
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12 // 圆角12pt，标准卡片圆角
        button.addTarget(self, action: #selector(syncTapped), for: .touchUpInside)
        return button
    }()

    private lazy var accountInfoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14) // 账号信息14pt
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("退出登录", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - 初始化
    init(viewModel: SyncViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.checkLoginStatus()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "云同步"

        view.addSubview(statusIcon)
        view.addSubview(statusLabel)
        view.addSubview(detailLabel)
        view.addSubview(repoInfoLabel)
        view.addSubview(changeRepoButton)
        view.addSubview(progressView)
        view.addSubview(syncButton)
        view.addSubview(accountInfoLabel)
        view.addSubview(logoutButton)

        NSLayoutConstraint.activate([
            statusIcon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48), // 顶部间距48pt，留出呼吸空间
            statusIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 60), // 图标60pt，视觉焦点
            statusIcon.heightAnchor.constraint(equalToConstant: 60),

            statusLabel.topAnchor.constraint(equalTo: statusIcon.bottomAnchor, constant: 16), // 图标与标题间距16pt
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8), // 标题与详情间距8pt
            detailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            repoInfoLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 12), // 详情与仓库信息间距12pt
            repoInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            repoInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            changeRepoButton.topAnchor.constraint(equalTo: repoInfoLabel.bottomAnchor, constant: 4), // 仓库信息与按钮间距4pt
            changeRepoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressView.topAnchor.constraint(equalTo: changeRepoButton.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            syncButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 32), // 进度条与按钮间距32pt，突出主操作
            syncButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            syncButton.widthAnchor.constraint(equalToConstant: 200), // 按钮宽度200pt，足够点击
            syncButton.heightAnchor.constraint(equalToConstant: 50), // 按钮高度50pt，符合触控标准

            accountInfoLabel.bottomAnchor.constraint(equalTo: logoutButton.topAnchor, constant: -16),
            accountInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            logoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            logoutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(with: state)
            }
            .store(in: &cancellables)

        viewModel.$syncResult
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.showSyncResult(result)
            }
            .store(in: &cancellables)

        viewModel.$repoFullName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] repo in
                if let repo = repo, !repo.isEmpty {
                    self?.repoInfoLabel.text = "同步仓库：\(repo)"
                    self?.changeRepoButton.isHidden = false
                } else {
                    self?.repoInfoLabel.text = nil
                    self?.changeRepoButton.isHidden = true
                }
            }
            .store(in: &cancellables)
    }

    private func updateUI(with state: SyncViewState) {
        switch state {
        case .notLoggedIn:
            statusIcon.image = UIImage(systemName: "person.crop.circle.badge.questionmark")
            statusIcon.tintColor = .systemGray
            statusLabel.text = "未登录 GitHub"
            detailLabel.text = "请先登录 GitHub 账号以启用云同步"
            progressView.isHidden = true
            syncButton.setTitle("登录 GitHub", for: .normal)
            accountInfoLabel.isHidden = true
            logoutButton.isHidden = true
            changeRepoButton.isHidden = true

        case .idle(let username, let lastSync):
            statusIcon.image = UIImage(systemName: "checkmark.icloud")
            statusIcon.tintColor = .systemGreen
            statusLabel.text = "同步就绪"
            if let lastSync = lastSync {
                let formatter = RelativeDateTimeFormatter()
                detailLabel.text = "上次同步：\(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            } else {
                detailLabel.text = "尚未同步过"
            }
            progressView.isHidden = true
            syncButton.setTitle("立即同步", for: .normal)
            syncButton.isEnabled = true
            accountInfoLabel.text = "已登录：\(username)"
            accountInfoLabel.isHidden = false
            logoutButton.isHidden = false

        case .syncing(let progress, let message):
            statusIcon.image = UIImage(systemName: "arrow.triangle.2.circlepath.icloud")
            statusIcon.tintColor = .systemBlue
            statusLabel.text = message
            detailLabel.text = "正在同步，请稍候..."
            progressView.isHidden = false
            progressView.progress = Float(progress)
            syncButton.setTitle("同步中...", for: .normal)
            syncButton.isEnabled = false

        case .error(let message):
            statusIcon.image = UIImage(systemName: "exclamationmark.icloud")
            statusIcon.tintColor = .systemRed
            statusLabel.text = "同步失败"
            detailLabel.text = message
            progressView.isHidden = true
            syncButton.setTitle("重试同步", for: .normal)
            syncButton.isEnabled = true
        }
    }

    private func showSyncResult(_ result: SyncResult) {
        let message = "上传 \(result.uploadedCount) 个文件，下载 \(result.downloadedCount) 个文件"
        + (result.conflictCount > 0 ? "，\(result.conflictCount) 个冲突" : "")
        showAlert(title: "同步完成", message: message)
    }

    // MARK: - 动作
    @objc private func syncTapped() {
        if case .notLoggedIn = viewModel.viewState {
            showLoginAlert()
        } else {
            viewModel.startSync()
        }
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(title: "退出登录", message: "确定要退出 GitHub 登录吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "退出", style: .destructive, handler: { [weak self] _ in
            self?.viewModel.logout()
        }))
        present(alert, animated: true)
    }

    @objc private func changeRepoTapped() {
        let alert = UIAlertController(title: "修改同步仓库", message: "请输入仓库全名，格式：用户名/仓库名\n例如：lambret-1/MyNovels", preferredStyle: .alert)
        alert.addTextField { [weak self] textField in
            textField.placeholder = "用户名/仓库名"
            textField.text = self?.viewModel.repoFullName
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default, handler: { [weak self] _ in
            if let repo = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !repo.isEmpty {
                self?.viewModel.updateRepository(repoFullName: repo)
            }
        }))
        present(alert, animated: true)
    }

    /// 展示冲突解决页面
    private func showConflictList() {
        // 防止重复弹出
        guard presentedViewController == nil else { return }
        let conflictVC = AppContainer.shared.makeConflictListViewController()
        let nav = UINavigationController(rootViewController: conflictVC)
        // iOS 14 兼容：使用 fullScreen，避免使用 iOS 15+ 的 pageSheet
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showLoginAlert() {
        let alert = UIAlertController(title: "GitHub 登录", message: "请输入 Personal Access Token\n\n在 GitHub → Settings → Developer settings → Personal access tokens 生成，勾选 repo 权限", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "ghp_xxxxxxxxxxxx"
            textField.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "登录", style: .default, handler: { [weak self] _ in
            if let token = alert.textFields?.first?.text, !token.isEmpty {
                self?.viewModel.login(with: token)
            }
        }))
        present(alert, animated: true)
    }
}

/// 同步视图状态
enum SyncViewState: Equatable {
    case notLoggedIn
    case idle(username: String, lastSync: Date?)
    case syncing(progress: Double, message: String)
    case error(message: String)
}

/// 同步 ViewModel
final class SyncViewModel {
    @Published var viewState: SyncViewState = .notLoggedIn
    @Published var syncResult: SyncResult?
    @Published var repoFullName: String?
    /// 当前登录用户名，用于同步完成后重置 UI 状态
    private var currentUsername: String?

    private let authService: GitHubAuthService
    private let syncEngine: SyncEngineProtocol
    private let syncMetadataRepository: SyncMetadataRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(authService: GitHubAuthService,
         syncEngine: SyncEngineProtocol,
         syncMetadataRepository: SyncMetadataRepositoryProtocol) {
        self.authService = authService
        self.syncEngine = syncEngine
        self.syncMetadataRepository = syncMetadataRepository
        bindSyncStatus()
    }

    private func bindSyncStatus() {
        syncEngine.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .idle:
                    break
                case .pulling(let progress):
                    self?.viewState = .syncing(progress: progress, message: "正在拉取远端数据...")
                case .merging:
                    self?.viewState = .syncing(progress: 0.6, message: "正在合并数据...")
                case .pushing(let progress):
                    self?.viewState = .syncing(progress: 0.7 + progress * 0.3, message: "正在上传本地数据...")
                case .conflictWaiting(let count):
                    self?.viewState = .error(message: "存在 \(count) 个冲突需要解决")
                case .error(let message):
                    self?.viewState = .error(message: message)
                }
            }
            .store(in: &cancellables)
    }

    func checkLoginStatus() {
        if let token = authService.loadSavedToken() {
            // Token 已在 AppDelegate 启动时设置到容器的 apiClient 实例
            // 此处验证 Token 是否仍然有效
            authService.fetchCurrentUser()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.viewState = .notLoggedIn
                    }
                }, receiveValue: { [weak self] user in
                    self?.loadMetadata(username: user.login)
                })
                .store(in: &cancellables)
        } else {
            viewState = .notLoggedIn
        }
    }

    private func loadMetadata(username: String) {
        currentUsername = username
        syncMetadataRepository.fetchMetadata()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] metadata in
                // 如果未配置仓库，自动设置为 username/MyNovels
                var meta = metadata
                if meta.repoFullName == nil {
                    meta.repoFullName = "\(username)/MyNovels"
                    meta.githubUsername = username
                    _ = self?.syncMetadataRepository.updateMetadata(meta)
                }
                self?.repoFullName = meta.repoFullName
                self?.viewState = .idle(username: username, lastSync: meta.lastSyncAt)
            })
            .store(in: &cancellables)
    }

    func login(with token: String) {
        viewState = .syncing(progress: 0, message: "正在验证 Token...")
        authService.loginWithPAT(token)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .error(message: "登录失败：\(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] user in
                self?.loadMetadata(username: user.login)
            })
            .store(in: &cancellables)
    }

    func logout() {
        authService.logout()
        currentUsername = nil
        repoFullName = nil
        viewState = .notLoggedIn
    }

    func updateRepository(repoFullName: String) {
        syncMetadataRepository.fetchMetadata()
            .flatMap { metadata -> AnyPublisher<SyncMetadata, Error> in
                var meta = metadata
                meta.repoFullName = repoFullName
                return self.syncMetadataRepository.updateMetadata(meta)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("更新仓库配置失败: \(error)")
                }
            }, receiveValue: { [weak self] meta in
                self?.repoFullName = meta.repoFullName
            })
            .store(in: &cancellables)
    }

    func startSync() {
        syncEngine.startSync()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .error(message: error.localizedDescription)
                }
            }, receiveValue: { [weak self] result in
                self?.syncResult = result
                // 同步完成后无论当前状态都重置为 idle，修复进度条卡住问题
                if let username = self?.currentUsername {
                    self?.viewState = .idle(username: username, lastSync: Date())
                }
            })
            .store(in: &cancellables)
    }
}


