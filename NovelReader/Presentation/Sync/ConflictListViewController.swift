import UIKit
import Combine

/// 冲突列表页面
final class ConflictListViewController: UIViewController {
    private let viewModel: ConflictListViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.register(ConflictCell.self, forCellReuseIdentifier: ConflictCell.reuseID)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 120 // 预估行高120pt，确保内容完整展示
        table.backgroundColor = DesignToken.Color.backgroundGrouped
        return table
    }()

    private lazy var bottomBar: UIView = {
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = DesignToken.Color.backgroundSecondary

        let continueButton = UIButton(type: .system)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.setTitle("继续同步", for: .normal)
        continueButton.titleLabel?.font = DesignToken.Font.headline // 按钮字号17pt
        continueButton.backgroundColor = DesignToken.Color.primary
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 12 // 按钮圆角12pt
        continueButton.addTarget(self, action: #selector(continueSyncTapped), for: .touchUpInside)

        let abortButton = UIButton(type: .system)
        abortButton.translatesAutoresizingMaskIntoConstraints = false
        abortButton.setTitle("放弃同步", for: .normal)
        abortButton.titleLabel?.font = DesignToken.Font.subhead // 次要按钮15pt
        abortButton.setTitleColor(DesignToken.Color.error, for: .normal)
        abortButton.addTarget(self, action: #selector(abortSyncTapped), for: .touchUpInside)

        bar.addSubview(continueButton)
        bar.addSubview(abortButton)

        NSLayoutConstraint.activate([
            continueButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 16), // 顶部间距16pt
            continueButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50), // 按钮高度50pt
            abortButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 8),
            abortButton.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            abortButton.bottomAnchor.constraint(equalTo: bar.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        return bar
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "✅ 所有冲突已解决\n点击\"继续同步\"完成同步"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = DesignToken.Font.title3 // 空态文字18pt
        label.textColor = DesignToken.Color.textSecondary
        label.isHidden = true
        return label
    }()

    init(viewModel: ConflictListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        bindViewModel()
        viewModel.loadConflicts()
    }

    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundGrouped
        view.addSubview(tableView)
        view.addSubview(bottomBar)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60) // 向上偏移60pt，视觉居中
        ])
    }

    private func setupNavigationBar() {
        title = "冲突解决"
        navigationItem.largeTitleDisplayMode = .never
        let menu = UIMenu(title: "批量操作", children: [
            UIAction(title: "全部保留本地", image: UIImage(systemName: "iphone")) { [weak self] _ in
                self?.viewModel.resolveAllKeepLocal()
            },
            UIAction(title: "全部保留远端", image: UIImage(systemName: "cloud")) { [weak self] _ in
                self?.viewModel.resolveAllKeepRemote()
            }
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
    }

    private func bindViewModel() {
        viewModel.$conflicts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conflicts in
                self?.tableView.reloadData()
                self?.emptyLabel.isHidden = !conflicts.isEmpty
                self?.title = conflicts.isEmpty ? "冲突解决" : "冲突解决（\(conflicts.count)）"
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                self?.showConflictAlert(title: "操作失败", message: msg)
            }
            .store(in: &cancellables)

        viewModel.$syncResult
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.showConflictAlert(title: "同步完成", message: result.message) {
                    self?.dismiss(animated: true)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func continueSyncTapped() { viewModel.continueSync() }

    @objc private func abortSyncTapped() {
        let alert = UIAlertController(title: "放弃同步", message: "确定要放弃本次同步吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "放弃", style: .destructive) { [weak self] _ in
            self?.viewModel.abortSync()
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func showConflictAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completion?() })
        present(alert, animated: true)
    }
}

extension ConflictListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.conflicts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConflictCell.reuseID, for: indexPath) as! ConflictCell
        cell.configure(with: viewModel.conflicts[indexPath.row], viewModel: viewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detailVC = ConflictDetailViewController(conflict: viewModel.conflicts[indexPath.row], viewModel: viewModel)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

/// 冲突单元格
final class ConflictCell: UITableViewCell {
    static let reuseID = "ConflictCell"
    private let fileNameLabel = UILabel()
    private let bookNameLabel = UILabel()
    private let localButton = UIButton(type: .system)
    private let remoteButton = UIButton(type: .system)
    private var conflict: ConflictItem?
    private weak var viewModel: ConflictListViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = DesignToken.Color.backgroundSecondary
        card.layer.cornerRadius = 12 // 卡片圆角12pt

        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.font = DesignToken.Font.headline // 文件名16pt
        fileNameLabel.textColor = .label

        bookNameLabel.translatesAutoresizingMaskIntoConstraints = false
        bookNameLabel.font = DesignToken.Font.caption1 // 书名13pt
        bookNameLabel.textColor = DesignToken.Color.textSecondary

        localButton.translatesAutoresizingMaskIntoConstraints = false
        localButton.setTitle("保留本地", for: .normal)
        localButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium) // 按钮14pt
        localButton.backgroundColor = DesignToken.Color.primary.withAlphaComponent(0.1)
        localButton.setTitleColor(DesignToken.Color.primary, for: .normal)
        localButton.layer.cornerRadius = 8 // 小按钮圆角8pt
        localButton.addTarget(self, action: #selector(keepLocal), for: .touchUpInside)

        remoteButton.translatesAutoresizingMaskIntoConstraints = false
        remoteButton.setTitle("保留远端", for: .normal)
        remoteButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        remoteButton.backgroundColor = DesignToken.Color.success.withAlphaComponent(0.1)
        remoteButton.setTitleColor(DesignToken.Color.success, for: .normal)
        remoteButton.layer.cornerRadius = 8
        remoteButton.addTarget(self, action: #selector(keepRemote), for: .touchUpInside)

        contentView.addSubview(card)
        card.addSubview(fileNameLabel)
        card.addSubview(bookNameLabel)
        card.addSubview(localButton)
        card.addSubview(remoteButton)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6), // 单元格间距6pt
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            fileNameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14), // 顶部间距14pt
            fileNameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            fileNameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            bookNameLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 4), // 间距4pt
            bookNameLabel.leadingAnchor.constraint(equalTo: fileNameLabel.leadingAnchor),
            bookNameLabel.trailingAnchor.constraint(equalTo: fileNameLabel.trailingAnchor),
            localButton.topAnchor.constraint(equalTo: bookNameLabel.bottomAnchor, constant: 12), // 按钮间距12pt
            localButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            localButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            localButton.heightAnchor.constraint(equalToConstant: 36), // 按钮高度36pt
            localButton.widthAnchor.constraint(equalToConstant: 100), // 按钮宽度100pt
            remoteButton.topAnchor.constraint(equalTo: localButton.topAnchor),
            remoteButton.leadingAnchor.constraint(equalTo: localButton.trailingAnchor, constant: 10), // 按钮间距10pt
            remoteButton.bottomAnchor.constraint(equalTo: localButton.bottomAnchor),
            remoteButton.heightAnchor.constraint(equalTo: localButton.heightAnchor),
            remoteButton.widthAnchor.constraint(equalTo: localButton.widthAnchor)
        ])
    }

    func configure(with conflict: ConflictItem, viewModel: ConflictListViewModel) {
        self.conflict = conflict
        self.viewModel = viewModel
        fileNameLabel.text = (conflict.localPath as NSString).lastPathComponent
        bookNameLabel.text = conflict.localPath.components(separatedBy: "/").first
    }

    @objc private func keepLocal() {
        guard let conflict = conflict else { return }
        viewModel?.resolveConflict(conflictId: conflict.id, resolution: .keepLocal)
    }

    @objc private func keepRemote() {
        guard let conflict = conflict else { return }
        viewModel?.resolveConflict(conflictId: conflict.id, resolution: .keepRemote)
    }
}

