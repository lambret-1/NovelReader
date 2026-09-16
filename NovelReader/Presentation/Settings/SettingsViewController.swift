import UIKit
import Combine

/// 设置视图控制器
final class SettingsViewController: UIViewController {

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI 组件
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.backgroundColor = DesignToken.Color.backgroundSecondary
        return tv
    }()

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }

    // MARK: - UI 搭建
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        title = "我的"
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - GitHub 登录/登出
    private func handleGitHubLogin() {
        if AppContainer.shared.authService.loadSavedToken() != nil {
            // 已登录，询问是否登出
            let alert = UIAlertController(title: "GitHub", message: "已登录，是否退出登录？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "退出登录", style: .destructive) { [weak self] _ in
                AppContainer.shared.authService.logout()
                self?.tableView.reloadData()
                NRToast.shared.success("已退出登录")
            })
            present(alert, animated: true)
        } else {
            // 未登录，弹出输入框
            let alert = UIAlertController(title: "GitHub 登录", message: "输入 Personal Access Token", preferredStyle: .alert)
            alert.addTextField { $0.placeholder = "ghp_xxxxxxxxxxxx"; $0.isSecureTextEntry = true }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "登录", style: .default) { [weak self] _ in
                guard let token = alert.textFields?.first?.text, !token.isEmpty else { return }
                AppContainer.shared.authService.loginWithPAT(token)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            NRToast.shared.error("登录失败: \(error.localizedDescription)")
                        }
                    }, receiveValue: { [weak self] user in
                        self?.tableView.reloadData()
                        NRToast.shared.success("登录成功: \(user.login)")
                    })
                    .store(in: &self!.cancellables)
            })
            present(alert, animated: true)
        }
    }

    // MARK: - 检查更新
    private func checkForUpdates() {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        NRToast.shared.info("正在检查更新...")

        AppContainer.shared.updateService.checkForUpdates()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    NRToast.shared.error("检查更新失败: \(error.localizedDescription)")
                }
            }, receiveValue: { latest in
                if AppContainer.shared.updateService.hasUpdate(latest: latest, currentVersion: currentVersion) {
                    NRToast.shared.info("发现新版本: \(latest.tagName)")
                } else {
                    NRToast.shared.success("当前已是最新版本 v\(currentVersion)")
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - UITableView DataSource & Delegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3 // 账户、通用、关于
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // GitHub
        case 1: return 3 // 深色模式、数据同步、API刷新
        case 2: return 3 // 检查更新、版本、关于
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "账户"
        case 1: return "通用"
        case 2: return "关于"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = DesignToken.Color.backgroundPrimary

        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.textLabel?.text = "GitHub"
            cell.detailTextLabel?.text = AppContainer.shared.authService.loadSavedToken() != nil ? "已登录" : "未登录"
            cell.accessoryType = .disclosureIndicator
        case (1, 0):
            cell.textLabel?.text = "深色模式"
            let switchView = UISwitch()
            switchView.isOn = ThemeManager.shared.currentMode == .dark
            switchView.addTarget(self, action: #selector(toggleDarkMode(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        case (1, 1):
            cell.textLabel?.text = "数据同步"
            cell.imageView?.image = UIImage(systemName: "arrow.triangle.2.circlepath")
            cell.accessoryType = .disclosureIndicator
        case (1, 2):
            cell.textLabel?.text = "API 刷新书籍"
            cell.accessoryType = .disclosureIndicator
        case (2, 0):
            cell.textLabel?.text = "检查更新"
            cell.accessoryType = .disclosureIndicator
        case (2, 1):
            cell.textLabel?.text = "版本"
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            cell.detailTextLabel?.text = "v\(version) (\(build))"
        case (2, 2):
            cell.textLabel?.text = "关于"
            cell.detailTextLabel?.text = "NovelReader"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            handleGitHubLogin()
        case (1, 1):
            // 数据同步 - 跳转到同步页面
            let syncVC = AppContainer.shared.makeSyncViewController()
            navigationController?.pushViewController(syncVC, animated: true)
        case (1, 2):
            // API 刷新
            guard AppContainer.shared.authService.loadSavedToken() != nil else {
                NRToast.shared.error("请先登录 GitHub")
                return
            }
            tabBarController?.selectedIndex = 0 // 切到书架
            if let nav = tabBarController?.viewControllers?.first as? UINavigationController,
               let libraryVC = nav.viewControllers.first as? LibraryViewController {
                libraryVC.perform(#selector(LibraryViewController.apiRefreshTapped))
            }
        case (2, 0):
            checkForUpdates()
        case (2, 2):
            NRToast.shared.info("NovelReader - 纯原生 iOS 小说阅读器")
        default:
            break
        }
    }

    @objc private func toggleDarkMode(_ sender: UISwitch) {
        ThemeManager.shared.setTheme(sender.isOn ? .dark : .light)
        // 主题已更新，系统会自动应用
    }
}
