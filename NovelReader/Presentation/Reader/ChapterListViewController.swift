import UIKit
import Combine

/// 章节列表视图控制器（同时作为阅读和编辑的入口）
final class ChapterListViewController: UIViewController {
    private let book: Book
    private let viewModel: ChapterListViewModel
    private let readingProgressRepository: ReadingProgressRepository?
    private var cancellables = Set<AnyCancellable>()
    private var currentChapterId: String?
    private var currentOffset: Int = 0

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(ChapterCell.self, forCellReuseIdentifier: ChapterCell.reuseID)
        tv.rowHeight = 72
        return tv
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "还没有章节\n点击右上角 + 新建"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.isHidden = true
        return label
    }()

    init(book: Book, viewModel: ChapterListViewModel, readingProgressRepository: ReadingProgressRepository? = nil) {
        self.book = book
        self.viewModel = viewModel
        self.readingProgressRepository = readingProgressRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.loadChapters()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = book.title

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addChapter)),
            UIBarButtonItem(title: "同步", style: .plain, target: self, action: #selector(syncTapped))
        ]

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$chapters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chapters in
                self?.tableView.reloadData()
                self?.emptyLabel.isHidden = !chapters.isEmpty
                self?.loadReadingProgress()
            }
            .store(in: &cancellables)
    }

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

    @objc private func addChapter() {
        let alert = UIAlertController(title: "新建章节", message: "输入章节标题", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "章节标题" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建", style: .default, handler: { [weak self] _ in
            if let title = alert.textFields?.first?.text, !title.isEmpty {
                self?.viewModel.createChapter(title: title)
            }
        }))
        present(alert, animated: true)
    }

    @objc private func syncTapped() {
        let syncVC = AppContainer.shared.makeSyncViewController()
        navigationController?.pushViewController(syncVC, animated: true)
    }
}

extension ChapterListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.chapters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChapterCell.reuseID, for: indexPath) as! ChapterCell
        let chapter = viewModel.chapters[indexPath.row]
        let isCurrent = currentChapterId == chapter.id
        let progress = isCurrent ? min(1.0, Double(currentOffset) / Double(max(1, chapter.content.count))) : 0
        cell.configure(with: chapter, index: indexPath.row, isCurrent: isCurrent, progress: progress)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chapter = viewModel.chapters[indexPath.row]

        // 弹出选择：阅读 / 编辑
        let alert = UIAlertController(title: chapter.title, message: "选择操作", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "阅读", style: .default, handler: { [weak self] _ in
            let readerVC = AppContainer.shared.makeReaderViewController(book: self!.book, chapters: self!.viewModel.chapters, startIndex: indexPath.row)
            self?.navigationController?.pushViewController(readerVC, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "编辑", style: .default, handler: { [weak self] _ in
            let editorVC = AppContainer.shared.makeEditorViewController(chapter: chapter)
            self?.navigationController?.pushViewController(editorVC, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { [weak self] _ in
            self?.viewModel.deleteChapter(at: indexPath)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

/// 章节单元格
final class ChapterCell: UITableViewCell {
    static let reuseID = "ChapterCell"

    private let indexLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.backgroundColor = .systemGray6
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private let progressBar: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.progressTintColor = .systemGreen
        pv.trackTintColor = .systemGray5
        pv.layer.cornerRadius = 2
        pv.clipsToBounds = true
        return pv
    }()

    private let dirtyIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemOrange
        view.layer.cornerRadius = 4
        return view
    }()

    private let currentIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 3
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        accessoryType = .disclosureIndicator
        contentView.addSubview(indexLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(metaLabel)
        contentView.addSubview(progressBar)
        contentView.addSubview(dirtyIndicator)
        contentView.addSubview(currentIndicator)

        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            indexLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 32),
            indexLabel.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: dirtyIndicator.leadingAnchor, constant: -8),

            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            progressBar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBar.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 6),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            progressBar.heightAnchor.constraint(equalToConstant: 3),
            progressBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            dirtyIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            dirtyIndicator.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            dirtyIndicator.widthAnchor.constraint(equalToConstant: 8),
            dirtyIndicator.heightAnchor.constraint(equalToConstant: 8),

            currentIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            currentIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            currentIndicator.widthAnchor.constraint(equalToConstant: 4),
            currentIndicator.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(with chapter: Chapter, index: Int, isCurrent: Bool, progress: Double) {
        indexLabel.text = "\(index + 1)"
        titleLabel.text = chapter.title
        metaLabel.text = "\(chapter.wordCount) 字"
        titleLabel.textColor = chapter.isDirty ? .systemOrange : .label
        dirtyIndicator.isHidden = !chapter.isDirty
        currentIndicator.isHidden = !isCurrent
        progressBar.isHidden = !isCurrent || progress == 0
        progressBar.progress = Float(progress)
        indexLabel.backgroundColor = isCurrent ? .systemGreen.withAlphaComponent(0.2) : .systemGray6
        indexLabel.textColor = isCurrent ? .systemGreen : .secondaryLabel
    }
}

/// 章节列表 ViewModel
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
