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
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
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
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(syncTapped), for: .touchUpInside)
        return button
    }()

    private lazy var accountInfoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
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
        view.addSubview(progressView)
        view.addSubview(syncButton)
        view.addSubview(accountInfoLabel)
        view.addSubview(logoutButton)

        NSLayoutConstraint.activate([
            statusIcon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            statusIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 60),
            statusIcon.heightAnchor.constraint(equalToConstant: 60),

            statusLabel.topAnchor.constraint(equalTo: statusIcon.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            progressView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            syncButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 40),
            syncButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            syncButton.widthAnchor.constraint(equalToConstant: 200),
            syncButton.heightAnchor.constraint(equalToConstant: 50),

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
            GitHubAPIClient.shared.setToken(token)
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
        syncMetadataRepository.fetchMetadata()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] metadata in
                // 如果未配置仓库，自动设置为 username/NovelReader
                var meta = metadata
                if meta.repoFullName == nil {
                    meta.repoFullName = "\(username)/NovelReader"
                    meta.githubUsername = username
                    _ = self?.syncMetadataRepository.updateMetadata(meta)
                }
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
        viewState = .notLoggedIn
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
                // 刷新状态
                if case .idle(let username, _) = self?.viewState {
                    self?.viewState = .idle(username: username, lastSync: Date())
                }
            })
            .store(in: &cancellables)
    }
}
