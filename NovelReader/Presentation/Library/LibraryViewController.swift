import UIKit
import Combine

/// 书架视图控制器 - P1重设计版本
final class LibraryViewController: UIViewController {

    // MARK: - 依赖
    private let viewModel: LibraryViewModel
    private let readingProgressRepository: ReadingProgressRepository?
    private var cancellables = Set<AnyCancellable>()
    private var progressCache: [String: Double] = [:]

    // MARK: - UI 组件
    private lazy var searchBar: NRTextField = {
        let field = NRTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "搜索书籍..."
        field.leftIcon = UIImage(systemName: "magnifyingglass")
        field.onTextChanged = { [weak self] text in
            self?.filterBooks(text)
        }
        return field
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(NRBookCardCell.self, forCellReuseIdentifier: NRBookCardCell.reuseID)
        tv.register(NRBookSkeletonCell.self, forCellReuseIdentifier: NRBookSkeletonCell.reuseIdentifier)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 100 // 预估行高100pt，自适应
        tv.separatorStyle = .none
        tv.backgroundColor = DesignToken.Color.backgroundSecondary
        tv.contentInset = UIEdgeInsets(top: DesignToken.Spacing.md, left: 0, bottom: DesignToken.Spacing.xl, right: 0) // 上下内边距
        return tv
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = DesignToken.Color.primary
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    private lazy var emptyState: NREmptyState = {
        let state = NREmptyState(
            icon: UIImage(systemName: "books.vertical"),
            title: "还没有书籍",
            subtitle: "点击右上角 + 创建你的第一本小说",
            actionTitle: "立即创建"
        )
        state.onAction = { [weak self] in
            self?.addBookTapped()
        }
        return state
    }()

    private lazy var syncStatusView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignToken.Color.backgroundPrimary
        view.layer.cornerRadius = DesignToken.Radius.lg // 同步状态圆角12pt
        view.applyShadow(DesignToken.Shadow.sm)

        let icon = UIImageView(image: UIImage(systemName: "arrow.triangle.2.circlepath"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = DesignToken.Color.primary
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "下拉刷新同步"
        label.font = DesignToken.Font.footnote // 同步提示字号13pt
        label.textColor = DesignToken.Color.textSecondary

        view.addSubview(icon)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 36), // 同步状态高度36pt
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.md),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16), // 图标16pt
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: DesignToken.Spacing.xs),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }()

    // MARK: - 搜索过滤
    private var filteredBooks: [Book] = []
    private var isSearching: Bool = false

    // MARK: - 初始化
    init(viewModel: LibraryViewModel, readingProgressRepository: ReadingProgressRepository? = nil) {
        self.viewModel = viewModel
        self.readingProgressRepository = readingProgressRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        bindViewModel()
        viewModel.refreshTrigger.send()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshTrigger.send()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary

        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(syncStatusView)

        tableView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignToken.Spacing.sm), // 搜索栏顶部间距8pt
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.lg), // 左右边距16pt
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignToken.Spacing.lg),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: DesignToken.Spacing.sm),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: syncStatusView.topAnchor, constant: -DesignToken.Spacing.sm),

            syncStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.lg),
            syncStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignToken.Spacing.lg),
            syncStatusView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignToken.Spacing.sm)
        ])
    }

    private func setupNavigationBar() {
        title = "书架"
        navigationController?.navigationBar.prefersLargeTitles = true

        // 右侧：添加按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(addBookTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = DesignToken.Color.primary

        // 左侧：API刷新 + 设置 + 主题切换
        let apiRefreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise.circle"),
            style: .plain,
            target: self,
            action: #selector(apiRefreshTapped)
        )
        apiRefreshButton.tintColor = DesignToken.Color.primary
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        let themeButton = UIBarButtonItem(
            image: UIImage(systemName: ThemeManager.shared.currentMode.iconName),
            style: .plain,
            target: self,
            action: #selector(themeTapped)
        )
        navigationItem.leftBarButtonItems = [apiRefreshButton, settingsButton, themeButton]
    }

    // MARK: - 数据绑定
    private func bindViewModel() {
        viewModel.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] books in
                self?.tableView.reloadData()
                self?.updateEmptyState(for: books)
                self?.loadReadingProgress(for: books)
                self?.refreshControl.endRefreshing()
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                if loading {
                    self?.tableView.reloadData()
                }
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                NRToast.shared.error(message)
            }
            .store(in: &cancellables)

        // 监听主题变化，更新主题按钮图标
        observeThemeChanges { [weak self] mode in
            self?.navigationItem.leftBarButtonItems?.last?.image = UIImage(systemName: mode.iconName)
        }
    }

    // MARK: - 空态管理
    private func updateEmptyState(for books: [Book]) {
        let displayBooks = isSearching ? filteredBooks : books
        if displayBooks.isEmpty && !viewModel.isLoading {
            if isSearching {
                emptyState.configure(
                    icon: UIImage(systemName: "magnifyingglass"),
                    title: "未找到匹配的书籍",
                    subtitle: "试试其他关键词",
                    actionTitle: nil
                )
            } else {
                emptyState.configure(
                    icon: UIImage(systemName: "books.vertical"),
                    title: "还没有书籍",
                    subtitle: "点击右上角 + 创建你的第一本小说",
                    actionTitle: "立即创建"
                )
            }
            emptyState.show(in: tableView)
        } else {
            emptyState.hide()
        }
    }

    // MARK: - 搜索过滤
    private func filterBooks(_ text: String) {
        isSearching = !text.isEmpty
        if isSearching {
            filteredBooks = viewModel.books.filter { book in
                book.title.lowercased().contains(text.lowercased())
            }
        }
        tableView.reloadData()
        updateEmptyState(for: viewModel.books)
    }

    // MARK: - 阅读进度
    private func loadReadingProgress(for books: [Book]) {
        guard let repo = readingProgressRepository else { return }
        progressCache.removeAll()
        for book in books {
            repo.fetchProgress(bookId: book.id)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] progress in
                    if let progress = progress {
                        self?.progressCache[book.id] = progress.percent
                        self?.tableView.reloadData()
                    }
                })
                .store(in: &cancellables)
        }
    }

    // MARK: - 动作
    @objc private func addBookTapped() {
        let alert = UIAlertController(title: "新建书籍", message: "输入书名", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "书名"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建", style: .default, handler: { [weak self] _ in
            if let title = alert.textFields?.first?.text, !title.isEmpty {
                self?.viewModel.createBookTrigger.send(title)
                NRToast.shared.success("书籍创建成功")
            }
        }))
        present(alert, animated: true)
    }

    @objc private func settingsTapped() {
        let settingsVC = AppContainer.shared.makeSettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    @objc private func themeTapped() {
        ThemeManager.shared.toggleNextTheme()
        NRToast.shared.info("已切换到\(ThemeManager.shared.currentMode.displayName)模式")
    }

    @objc private func handleRefresh() {
        viewModel.refreshTrigger.send()
    }

    // MARK: - API 自动刷新书籍
    @objc private func apiRefreshTapped() {
        guard !NovelRefreshService.shared.isRefreshing else {
            NRToast.shared.info("正在刷新中，请稍候...")
            return
        }

        // 检查 Token
        guard GitHubAuthService.shared.loadSavedToken() != nil else {
            NRToast.shared.error("请先在设置中登录 GitHub")
            return
        }

        let alert = UIAlertController(
            title: "API 刷新书籍",
            message: "将从 MyNovels 仓库拉取所有书籍和章节，文件夹名=书名，文件名=章节名。是否继续？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "开始刷新", style: .default) { [weak self] _ in
            self?.startAPIRefresh()
        })
        present(alert, animated: true)
    }

    private func startAPIRefresh() {
        // 显示进度 HUD
        let hud = UIAlertController(title: "正在刷新...", message: "准备中...", preferredStyle: .alert)
        present(hud, animated: true)

        // 监听进度
        NovelRefreshService.shared.$refreshMessage
            .receive(on: DispatchQueue.main)
            .sink { message in
                hud.message = message
            }
            .store(in: &cancellables)

        NovelRefreshService.shared.$refreshProgress
            .receive(on: DispatchQueue.main)
            .sink { progress in
                hud.title = "正在刷新... \(Int(progress * 100))%"
            }
            .store(in: &cancellables)

        // 执行刷新
        NovelRefreshService.shared.refreshBooks()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                hud.dismiss(animated: true) {
                    if case .failure(let error) = completion {
                        NRToast.shared.error("刷新失败: \(error.localizedDescription)")
                    }
                }
            }, receiveValue: { [weak self] result in
                hud.dismiss(animated: true) {
                    NRToast.shared.success("刷新完成：新增 \(result.addedBooks) 本书，更新 \(result.updatedChapters) 个章节")
                    // 刷新书架列表
                    self?.viewModel.refreshTrigger.send()
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension LibraryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if viewModel.isLoading {
            return 6 // 加载时显示6个骨架单元格
        }
        return isSearching ? filteredBooks.count : viewModel.books.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 加载态：骨架屏
        if viewModel.isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: NRBookSkeletonCell.reuseIdentifier, for: indexPath) as! NRBookSkeletonCell
            cell.startAnimating()
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: NRBookCardCell.reuseID, for: indexPath) as! NRBookCardCell
        let books = isSearching ? filteredBooks : viewModel.books
        if let book = books[safe: indexPath.row] {
            let progress = progressCache[book.id] ?? 0
            cell.configure(with: book, progress: progress)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let books = isSearching ? filteredBooks : viewModel.books
        if let book = books[safe: indexPath.row] {
            let chapterListVC = AppContainer.shared.makeChapterListViewController(book: book)
            navigationController?.pushViewController(chapterListVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if viewModel.isLoading { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.viewModel.deleteBookTrigger.send(indexPath)
            NRToast.shared.success("已删除")
            completion(true)
        }
        deleteAction.backgroundColor = DesignToken.Color.error
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - 书籍卡片单元格
final class NRBookCardCell: UITableViewCell {
    static let reuseID = "NRBookCardCell"

    private let cardView = UIView()
    private let coverView = UIView()
    private let coverLabel = UILabel()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let progressBar = UIProgressView()
    private let progressLabel = UILabel()
    private let updateTimeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // 卡片容器
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = DesignToken.Color.backgroundPrimary
        cardView.layer.cornerRadius = DesignToken.Radius.lg // 卡片圆角12pt
        cardView.applyShadow(DesignToken.Shadow.sm)
        contentView.addSubview(cardView)

        // 封面
        coverView.translatesAutoresizingMaskIntoConstraints = false
        coverView.backgroundColor = DesignToken.Color.primaryBackground
        coverView.layer.cornerRadius = DesignToken.Radius.sm // 封面圆角6pt
        coverView.clipsToBounds = true
        cardView.addSubview(coverView)

        coverLabel.translatesAutoresizingMaskIntoConstraints = false
        coverLabel.font = DesignToken.Font.title3 // 封面文字20pt半粗
        coverLabel.textColor = DesignToken.Color.primary
        coverLabel.textAlignment = .center
        coverLabel.numberOfLines = 2
        coverView.addSubview(coverLabel)

        // 标题
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignToken.Font.headline // 标题17pt半粗
        titleLabel.textColor = DesignToken.Color.textPrimary
        titleLabel.numberOfLines = 1
        cardView.addSubview(titleLabel)

        // 作者
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignToken.Font.footnote // 作者字号13pt
        authorLabel.textColor = DesignToken.Color.textSecondary
        cardView.addSubview(authorLabel)

        // 进度条
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = DesignToken.Color.primary
        progressBar.trackTintColor = DesignToken.Color.backgroundTertiary
        progressBar.layer.cornerRadius = 2 // 进度条圆角2pt
        progressBar.clipsToBounds = true
        cardView.addSubview(progressBar)

        // 进度文字
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = DesignToken.Font.caption2 // 进度字号11pt
        progressLabel.textColor = DesignToken.Color.textTertiary
        progressLabel.textAlignment = .right
        cardView.addSubview(progressLabel)

        // 更新时间
        updateTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        updateTimeLabel.font = DesignToken.Font.caption2 // 更新时间11pt
        updateTimeLabel.textColor = DesignToken.Color.textTertiary
        updateTimeLabel.textAlignment = .right
        cardView.addSubview(updateTimeLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignToken.Spacing.xs), // 卡片上下间距4pt
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg), // 左右边距16pt
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignToken.Spacing.xs),

            coverView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DesignToken.Spacing.md), // 封面左边距12pt
            coverView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: DesignToken.Spacing.md),
            coverView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DesignToken.Spacing.md),
            coverView.widthAnchor.constraint(equalToConstant: 56), // 封面宽度56pt
            coverView.heightAnchor.constraint(equalToConstant: 75), // 封面高度75pt（3:4比例）

            coverLabel.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            coverLabel.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            coverLabel.leadingAnchor.constraint(equalTo: coverView.leadingAnchor, constant: 4),
            coverLabel.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -4),

            titleLabel.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: DesignToken.Spacing.md),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: DesignToken.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: updateTimeLabel.leadingAnchor, constant: -DesignToken.Spacing.sm),

            updateTimeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DesignToken.Spacing.md),
            updateTimeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignToken.Spacing.xs),
            authorLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DesignToken.Spacing.md),

            progressBar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DesignToken.Spacing.md),
            progressBar.widthAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 0.5), // 进度条宽度50%
            progressBar.heightAnchor.constraint(equalToConstant: 4), // 进度条高度4pt

            progressLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DesignToken.Spacing.md),
            progressLabel.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressLabel.leadingAnchor.constraint(equalTo: progressBar.trailingAnchor, constant: DesignToken.Spacing.xs)
        ])
    }

    func configure(with book: Book, progress: Double) {
        titleLabel.text = book.title
        authorLabel.text = book.author.isEmpty ? "未知作者" : book.author
        coverLabel.text = String(book.title.prefix(1)) // 封面显示书名首字
        progressBar.setProgress(Float(progress), animated: true)
        progressLabel.text = "\(Int(progress * 100))%"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd"
        updateTimeLabel.text = dateFormatter.string(from: book.updatedAt)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        authorLabel.text = nil
        coverLabel.text = nil
        progressBar.setProgress(0, animated: false)
        progressLabel.text = nil
        updateTimeLabel.text = nil
    }
}

// MARK: - Array 安全下标
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
