import UIKit
import Combine

/// 章节列表视图控制器 - P1重设计版本（同时作为阅读和编辑的入口）
final class ChapterListViewController: UIViewController {

    // MARK: - 依赖
    private let book: Book
    private let viewModel: ChapterListViewModel
    private let readingProgressRepository: ReadingProgressRepository?
    private var cancellables = Set<AnyCancellable>()
    private var currentChapterId: String?
    private var currentOffset: Int = 0

    // MARK: - UI 组件
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(NRChapterCell.self, forCellReuseIdentifier: NRChapterCell.reuseID)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 72 // 预估行高72pt
        tv.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 16) // 分割线缩进
        tv.backgroundColor = DesignToken.Color.backgroundSecondary
        return tv
    }()

    private lazy var emptyState: NREmptyState = {
        let state = NREmptyState(
            icon: UIImage(systemName: "text.book.closed"),
            title: "还没有章节",
            subtitle: "点击右上角 + 新建第一章",
            actionTitle: "新建章节"
        )
        state.onAction = { [weak self] in
            self?.addChapter()
        }
        return state
    }()

    // MARK: - 书籍信息头部视图
    private lazy var bookHeaderView: NRBookInfoHeader = {
        let header = NRBookInfoHeader(book: book)
        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 140) // 头部高度140pt
        return header
    }()

    /// 更新头部统计信息
    private func updateBookHeaderStats() {
        let chapterCount = viewModel.chapters.count
        let totalWordCount = viewModel.chapters.reduce(0) { $0 + $1.wordCount }
        bookHeaderView.updateStats(chapterCount: chapterCount, totalWordCount: totalWordCount)
    }

    // MARK: - 初始化
    init(book: Book, viewModel: ChapterListViewModel, readingProgressRepository: ReadingProgressRepository? = nil) {
        self.book = book
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
        viewModel.loadChapters()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 更新头部视图尺寸
        if let header = tableView.tableHeaderView {
            let size = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if header.frame.size.height != size.height {
                header.frame.size.height = size.height
                tableView.tableHeaderView = header
            }
        }
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary
        tableView.tableHeaderView = bookHeaderView

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        title = book.title
        navigationController?.navigationBar.prefersLargeTitles = false

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain,
                target: self,
                action: #selector(addChapter)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "arrow.triangle.2.circlepath"),
                style: .plain,
                target: self,
                action: #selector(syncTapped)
            )
        ]
        navigationItem.rightBarButtonItems?.forEach { $0.tintColor = DesignToken.Color.primary }
    }

    // MARK: - 数据绑定
    private func bindViewModel() {
        viewModel.$chapters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chapters in
                self?.tableView.reloadData()
                self?.updateEmptyState(for: chapters)
                self?.loadReadingProgress()
                self?.updateBookHeaderStats()
            }
            .store(in: &cancellables)
    }

    private func updateEmptyState(for chapters: [Chapter]) {
        if chapters.isEmpty {
            emptyState.show(in: tableView)
        } else {
            emptyState.hide()
        }
    }

    // MARK: - 阅读进度
    private func loadReadingProgress() {
        guard let repo = readingProgressRepository else { return }
        repo.fetchProgress(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] progress in
                if let progress = progress {
                    self?.currentChapterId = progress.chapterId
                    self?.currentOffset = progress.offset
                    self?.tableView.reloadData()
                }
            })
            .store(in: &cancellables)
    }

    // MARK: - 动作
    @objc private func addChapter() {
        let alert = UIAlertController(title: "新建章节", message: "输入章节标题", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "章节标题" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建", style: .default, handler: { [weak self] _ in
            if let title = alert.textFields?.first?.text, !title.isEmpty {
                self?.viewModel.createChapter(title: title)
                NRToast.shared.success("章节创建成功")
            }
        }))
        present(alert, animated: true)
    }

    @objc private func syncTapped() {
        let syncVC = AppContainer.shared.makeSyncViewController()
        navigationController?.pushViewController(syncVC, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension ChapterListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.chapters.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.chapters.isEmpty ? nil : "章节列表"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NRChapterCell.reuseID, for: indexPath) as! NRChapterCell
        let chapter = viewModel.chapters[indexPath.row]
        let isCurrent = currentChapterId == chapter.id
        let progress = isCurrent ? min(1.0, Double(currentOffset) / Double(max(1, chapter.content.count))) : 0
        cell.configure(with: chapter, index: indexPath.row, isCurrent: isCurrent, progress: progress)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showChapterActionSheet(at: indexPath)
    }

    // MARK: - 长按菜单（iOS 13+ UIContextMenuInteraction）
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let chapter = viewModel.chapters[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let readAction = UIAction(title: "阅读", image: UIImage(systemName: "book")) { _ in
                self?.openReader(at: indexPath)
            }
            let editAction = UIAction(title: "编辑", image: UIImage(systemName: "pencil")) { _ in
                self?.openEditor(at: indexPath)
            }
            let deleteAction = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.viewModel.deleteChapter(at: indexPath)
                NRToast.shared.success("已删除")
            }
            return UIMenu(title: chapter.title, children: [readAction, editAction, deleteAction])
        }
    }

    // MARK: - 章节操作
    private func showChapterActionSheet(at indexPath: IndexPath) {
        let chapter = viewModel.chapters[indexPath.row]
        let alert = UIAlertController(title: chapter.title, message: "选择操作", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "阅读", style: .default, handler: { [weak self] _ in
            self?.openReader(at: indexPath)
        }))
        alert.addAction(UIAlertAction(title: "编辑", style: .default, handler: { [weak self] _ in
            self?.openEditor(at: indexPath)
        }))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { [weak self] _ in
            self?.viewModel.deleteChapter(at: indexPath)
            NRToast.shared.success("已删除")
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad 适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    private func openReader(at indexPath: IndexPath) {
        let readerVC = AppContainer.shared.makeReaderViewController(book: book, chapters: viewModel.chapters, startIndex: indexPath.row)
        navigationController?.pushViewController(readerVC, animated: true)
    }

    private func openEditor(at indexPath: IndexPath) {
        let chapter = viewModel.chapters[indexPath.row]
        let editorVC = AppContainer.shared.makeEditorViewController(chapter: chapter)
        navigationController?.pushViewController(editorVC, animated: true)
    }
}

// MARK: - 书籍信息头部视图
final class NRBookInfoHeader: UIView {

    private let coverView = UIView()
    private let coverLabel = UILabel()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let statsStackView = UIStackView()

    init(book: Book, chapterCount: Int = 0, totalWordCount: Int = 0) {
        super.init(frame: .zero)
        setupUI()
        configure(with: book, chapterCount: chapterCount, totalWordCount: totalWordCount)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // 封面
        coverView.translatesAutoresizingMaskIntoConstraints = false
        coverView.backgroundColor = DesignToken.Color.primaryBackground
        coverView.layer.cornerRadius = DesignToken.Radius.md // 封面圆角8pt
        coverView.clipsToBounds = true
        addSubview(coverView)

        coverLabel.translatesAutoresizingMaskIntoConstraints = false
        coverLabel.font = DesignToken.Font.largeTitle // 封面文字34pt粗体
        coverLabel.textColor = DesignToken.Color.primary
        coverLabel.textAlignment = .center
        coverView.addSubview(coverLabel)

        // 标题
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignToken.Font.title2 // 标题22pt半粗
        titleLabel.textColor = DesignToken.Color.textPrimary
        titleLabel.numberOfLines = 2
        addSubview(titleLabel)

        // 作者
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignToken.Font.subhead // 作者15pt
        authorLabel.textColor = DesignToken.Color.textSecondary
        addSubview(authorLabel)

        // 统计信息
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.axis = .horizontal
        statsStackView.spacing = DesignToken.Spacing.lg // 统计项间距16pt
        addSubview(statsStackView)

        NSLayoutConstraint.activate([
            coverView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignToken.Spacing.lg), // 左边距16pt
            coverView.topAnchor.constraint(equalTo: topAnchor, constant: DesignToken.Spacing.lg),
            coverView.widthAnchor.constraint(equalToConstant: 72), // 封面宽度72pt
            coverView.heightAnchor.constraint(equalToConstant: 96), // 封面高度96pt（3:4比例）

            coverLabel.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            coverLabel.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: DesignToken.Spacing.lg),
            titleLabel.topAnchor.constraint(equalTo: coverView.topAnchor, constant: DesignToken.Spacing.xs),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignToken.Spacing.lg),

            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignToken.Spacing.xs),
            authorLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            statsStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statsStackView.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: DesignToken.Spacing.md),
            statsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignToken.Spacing.lg)
        ])
    }

    private func configure(with book: Book, chapterCount: Int, totalWordCount: Int) {
        titleLabel.text = book.title
        authorLabel.text = book.author.isEmpty ? "未知作者" : book.author
        coverLabel.text = String(book.title.prefix(1))

        // 统计项：章节数、总字数
        addStatItem(icon: "text.alignleft", value: "\(chapterCount)", label: "章节")
        addStatItem(icon: "textformat.abc", value: "\(totalWordCount)", label: "字数")
    }

    /// 更新统计数据
    func updateStats(chapterCount: Int, totalWordCount: Int) {
        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addStatItem(icon: "text.alignleft", value: "\(chapterCount)", label: "章节")
        addStatItem(icon: "textformat.abc", value: "\(totalWordCount)", label: "字数")
    }

    private func addStatItem(icon: String, value: String, label: String) {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = DesignToken.Spacing.xs // 图标与文字间距4pt
        container.alignment = .center

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = DesignToken.Color.textTertiary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true // 统计图标14pt
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let valueLabel = UILabel()
        valueLabel.font = DesignToken.Font.footnote // 统计值13pt
        valueLabel.textColor = DesignToken.Color.textPrimary
        valueLabel.text = value

        let labelLabel = UILabel()
        labelLabel.font = DesignToken.Font.caption2 // 统计标签11pt
        labelLabel.textColor = DesignToken.Color.textTertiary
        labelLabel.text = label

        container.addArrangedSubview(iconView)
        container.addArrangedSubview(valueLabel)
        container.addArrangedSubview(labelLabel)

        statsStackView.addArrangedSubview(container)
    }
}

// MARK: - 章节单元格
final class NRChapterCell: UITableViewCell {
    static let reuseID = "NRChapterCell"

    private let indexLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption1 // 序号12pt
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        label.layer.cornerRadius = DesignToken.Radius.sm // 序号圆角6pt
        label.layer.masksToBounds = true
        label.backgroundColor = DesignToken.Color.backgroundTertiary
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.body // 标题17pt
        label.textColor = DesignToken.Color.textPrimary
        label.numberOfLines = 1
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption2 // 元信息11pt
        label.textColor = DesignToken.Color.textTertiary
        return label
    }()

    private let progressBar: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.progressTintColor = DesignToken.Color.success
        pv.trackTintColor = DesignToken.Color.backgroundTertiary
        pv.layer.cornerRadius = 2 // 进度条圆角2pt
        pv.clipsToBounds = true
        pv.isHidden = true
        return pv
    }()

    private let dirtyIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignToken.Color.warning
        view.layer.cornerRadius = 4 // 未同步指示器4pt
        view.isHidden = true
        return view
    }()

    private let currentBadge: NRBadge = {
        let badge = NRBadge(type: .status("阅读中", .info))
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isHidden = true
        return badge
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        backgroundColor = DesignToken.Color.backgroundPrimary
        accessoryType = .disclosureIndicator

        contentView.addSubview(indexLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(metaLabel)
        contentView.addSubview(progressBar)
        contentView.addSubview(dirtyIndicator)
        contentView.addSubview(currentBadge)

        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.md), // 左边距12pt
            indexLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 28), // 序号宽度28pt
            indexLabel.heightAnchor.constraint(equalToConstant: 28), // 序号高度28pt

            titleLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: DesignToken.Spacing.md),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignToken.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: currentBadge.leadingAnchor, constant: -DesignToken.Spacing.sm),

            currentBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.xl), // 右边距32pt（给箭头留空间）
            currentBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignToken.Spacing.xs),
            metaLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.xl),

            progressBar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBar.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: DesignToken.Spacing.xs),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.xl),
            progressBar.heightAnchor.constraint(equalToConstant: 3), // 进度条高度3pt
            progressBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignToken.Spacing.sm),

            dirtyIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.sm),
            dirtyIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignToken.Spacing.sm),
            dirtyIndicator.widthAnchor.constraint(equalToConstant: 8), // 未同步点8pt
            dirtyIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    func configure(with chapter: Chapter, index: Int, isCurrent: Bool, progress: Double) {
        indexLabel.text = "\(index + 1)"
        titleLabel.text = chapter.title
        metaLabel.text = "\(chapter.content.count) 字"

        // 当前阅读章节
        currentBadge.isHidden = !isCurrent
        if isCurrent {
            titleLabel.textColor = DesignToken.Color.primary
            indexLabel.backgroundColor = DesignToken.Color.primaryBackground
            indexLabel.textColor = DesignToken.Color.primary
        } else {
            titleLabel.textColor = DesignToken.Color.textPrimary
            indexLabel.backgroundColor = DesignToken.Color.backgroundTertiary
            indexLabel.textColor = DesignToken.Color.textSecondary
        }

        // 阅读进度条
        if isCurrent && progress > 0 && progress < 1 {
            progressBar.isHidden = false
            progressBar.setProgress(Float(progress), animated: true)
        } else {
            progressBar.isHidden = true
        }

        // 未同步指示器
        dirtyIndicator.isHidden = !chapter.isDirty
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        metaLabel.text = nil
        indexLabel.text = nil
        progressBar.isHidden = true
        dirtyIndicator.isHidden = true
        currentBadge.isHidden = true
        titleLabel.textColor = DesignToken.Color.textPrimary
    }
}


// MARK: - 章节列表 ViewModel
final class ChapterListViewModel {
    @Published private(set) var chapters: [Chapter] = []

    private let book: Book
    private let fetchChaptersUseCase: FetchChaptersUseCase
    private let createChapterUseCase: CreateChapterUseCase
    private let deleteChapterUseCase: DeleteChapterUseCase
    private var cancellables = Set<AnyCancellable>()

    init(book: Book,
         fetchChaptersUseCase: FetchChaptersUseCase,
         createChapterUseCase: CreateChapterUseCase,
         deleteChapterUseCase: DeleteChapterUseCase) {
        self.book = book
        self.fetchChaptersUseCase = fetchChaptersUseCase
        self.createChapterUseCase = createChapterUseCase
        self.deleteChapterUseCase = deleteChapterUseCase
    }

    func loadChapters() {
        fetchChaptersUseCase.execute(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] chapters in
                self?.chapters = chapters
            })
            .store(in: &cancellables)
    }

    func createChapter(title: String) {
        createChapterUseCase.execute(bookId: book.id, title: title, sortOrder: chapters.count)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                self?.loadChapters()
            })
            .store(in: &cancellables)
    }

    func deleteChapter(at indexPath: IndexPath) {
        guard indexPath.row < chapters.count else { return }
        let chapter = chapters[indexPath.row]
        deleteChapterUseCase.execute(chapterId: chapter.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                self?.loadChapters()
            })
            .store(in: &cancellables)
    }
}
