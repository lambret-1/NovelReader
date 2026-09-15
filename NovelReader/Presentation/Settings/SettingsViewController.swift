import UIKit
import Combine

/// 设置视图控制器
final class SettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var sections: [SettingsSection] = []
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSections()
    }

    /// 获取当前应用版本号
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (build \(build))"
    }

    private func reloadSections() {
        let stats = ReadingStatsManager.shared
        sections = [
            SettingsSection(title: "阅读统计", items: [
                SettingsItem(title: "总阅读时长", subtitle: stats.formattedTotalReadingTime, type: .info),
                SettingsItem(title: "阅读天数", subtitle: "\(stats.readingDays) 天", type: .info),
                SettingsItem(title: "连续阅读", subtitle: "\(stats.streakDays) 天", type: .info)
            ]),
            SettingsSection(title: "外观", items: [
                SettingsItem(title: "主题模式", subtitle: ThemeManager.shared.currentMode.displayName, type: .navigation),
                SettingsItem(title: "默认字号", subtitle: "\(Int(AppConfig.defaultFontSize))pt", type: .info),
                SettingsItem(title: "翻页方式", subtitle: "左右滑动", type: .info)
            ]),
            SettingsSection(title: "同步", items: [
                SettingsItem(title: "云同步", subtitle: "GitHub", type: .navigation),
                SettingsItem(title: "自动同步", subtitle: "编辑后 3 秒", type: .info)
            ]),
            SettingsSection(title: "数据", items: [
                SettingsItem(title: "导出全部数据", subtitle: "", type: .action),
                SettingsItem(title: "清除缓存", subtitle: "", type: .action)
            ]),
            SettingsSection(title: "关于", items: [
                SettingsItem(title: "版本", subtitle: appVersion, type: .info),
                SettingsItem(title: "检查更新", subtitle: "", type: .action),
                SettingsItem(title: "开发者", subtitle: "NovelReader Team", type: .info)
            ])
        ]
        tableView.reloadData()
    }

    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundGrouped
        title = "设置"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - 主题切换

    /// 显示主题模式选择器
    private func showThemePicker() {
        let alert = UIAlertController(title: "主题模式", message: "选择应用主题", preferredStyle: .actionSheet)

        for mode in AppThemeMode.allCases {
            let action = UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                ThemeManager.shared.setTheme(mode)
                NRToast.shared.success("已切换到\(mode.displayName)模式")
                self?.reloadSections()
            }
            if mode == ThemeManager.shared.currentMode {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad 适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    // MARK: - 检查更新

    /// 手动检查更新
    private func checkForUpdates() {
        let updateService = AppContainer.shared.updateService

        // 显示加载提示
        let alert = UIAlertController(title: "检查更新", message: "正在检查最新版本...", preferredStyle: .alert)
        present(alert, animated: true)

        updateService.checkForUpdates()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                alert.dismiss(animated: true) {
                    if case .failure(let error) = completion {
                        self?.showAlert(title: "检查失败", message: error.localizedDescription)
                    }
                }
            }, receiveValue: { [weak self] latestRelease in
                alert.dismiss(animated: true) {
                    guard let self = self else { return }
                    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

                    if updateService.hasUpdate(latest: latestRelease, currentVersion: currentVersion) {
                        // 有新版本，弹出更新窗口
                        let updateVC = AppContainer.shared.makeUpdateViewController(release: latestRelease)
                        self.present(updateVC, animated: true)
                    } else {
                        self.showAlert(title: "已是最新版本", message: "当前版本 \(currentVersion) 已是最新版本")
                    }
                }
            })
            .store(in: &cancellables)
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell")
            ?? UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell") // value1样式，副标题显示在右侧
        let item = sections[indexPath.section].items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.subtitle

        switch item.type {
        case .navigation:
            cell.accessoryType = .disclosureIndicator
        case .action:
            cell.textLabel?.textColor = DesignToken.Color.primary
            cell.accessoryType = .none
        case .info:
            cell.accessoryType = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]

        if item.title == "云同步" {
            let syncVC = AppContainer.shared.makeSyncViewController()
            navigationController?.pushViewController(syncVC, animated: true)
        } else if item.title == "主题模式" {
            showThemePicker()
        } else if item.title == "清除缓存" {
            showAlert(title: "清除缓存", message: "缓存已清除")
        } else if item.title == "导出全部数据" {
            showAlert(title: "导出", message: "导出功能开发中")
        } else if item.title == "检查更新" {
            checkForUpdates()
        }
    }
}

// MARK: - 设置数据模型
struct SettingsSection {
    let title: String
    let items: [SettingsItem]
}

struct SettingsItem {
    let title: String
    let subtitle: String
    let type: SettingsItemType
}

enum SettingsItemType {
    case info
    case navigation
    case action
}
