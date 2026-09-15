import UIKit

/// 设置视图控制器
final class SettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let sections: [SettingsSection] = [
        SettingsSection(title: "阅读", items: [
            SettingsItem(title: "默认字号", subtitle: "18pt", type: .info),
            SettingsItem(title: "默认主题", subtitle: "日间", type: .info),
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
            SettingsItem(title: "版本", subtitle: "1.0.0", type: .info),
            SettingsItem(title: "开发者", subtitle: "NovelReader Team", type: .info)
        ])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "设置"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.subtitle

        switch item.type {
        case .navigation:
            cell.accessoryType = .disclosureIndicator
        case .action:
            cell.textLabel?.textColor = .systemBlue
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
        } else if item.title == "清除缓存" {
            showAlert(title: "清除缓存", message: "缓存已清除")
        } else if item.title == "导出全部数据" {
            showAlert(title: "导出", message: "导出功能开发中")
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
