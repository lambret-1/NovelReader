import UIKit
import Combine

/// 章节列表视图控制器（同时作为阅读和编辑的入口）
final class ChapterListViewController: UIViewController {
    private let book: Book
    private let viewModel: ChapterListViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "ChapterCell")
        tv.rowHeight = 60
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

    init(book: Book, viewModel: ChapterListViewModel) {
        self.book = book
        self.viewModel = viewModel
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
            }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChapterCell", for: indexPath)
        let chapter = viewModel.chapters[indexPath.row]
        cell.textLabel?.text = "\(chapter.sortOrder + 1). \(chapter.title)"
        cell.detailTextLabel?.text = "\(chapter.wordCount) 字"
        cell.accessoryType = .disclosureIndicator
        if chapter.isDirty {
            cell.textLabel?.textColor = .systemOrange
        } else {
            cell.textLabel?.textColor = .label
        }
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
