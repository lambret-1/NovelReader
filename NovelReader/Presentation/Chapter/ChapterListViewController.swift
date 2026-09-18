import UIKit
import Combine

/// 章节列表视图控制器
final class ChapterListViewController: UIViewController {

    private let book: Book
    private let chapterRepository = AppContainer.shared.chapterRepository
    private var cancellables = Set<AnyCancellable>()
    private var chapters: [Chapter] = []

    // MARK: - UI 组件
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(ChapterCell.self, forCellReuseIdentifier: ChapterCell.reuseID)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 60 // 预估行高60pt
        tv.separatorStyle = .none
        tv.backgroundColor = DesignToken.Color.backgroundSecondary
        tv.contentInset = UIEdgeInsets(top: DesignToken.Spacing.md, left: 0, bottom: DesignToken.Spacing.xl, right: 0)
        return tv
    }()

    private lazy var emptyState: NREmptyState = {
        let state = NREmptyState(
            icon: UIImage(systemName: "doc.text"),
            title: "暂无章节",
            subtitle: "这本书还没有章节"
        )
        state.translatesAutoresizingMaskIntoConstraints = false
        state.isHidden = true
        return state
    }()

    // MARK: - 初始化
    init(book: Book) {
        self.book = book
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
        loadChapters()
    }

    // MARK: - UI 搭建
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary
        view.addSubview(tableView)
        view.addSubview(emptyState)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupNavigationBar() {
        title = book.title
        navigationController?.navigationBar.prefersLargeTitles = false

        // 右侧阅读按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "阅读",
            style: .plain,
            target: self,
            action: #selector(startReading)
        )
        navigationItem.rightBarButtonItem?.tintColor = DesignToken.Color.primary
    }

    // MARK: - 数据加载
    private func loadChapters() {
        chapterRepository.fetchChapters(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] chapters in
                // 显示前按章节标题中的数字重新排序，确保第1章到第100章正确顺序
                let sortedChapters = chapters.sorted { chapter1, chapter2 in
                    let num1 = NaturalSort.extractChapterNumber(from: chapter1.title)
                    let num2 = NaturalSort.extractChapterNumber(from: chapter2.title)
                    if num1 != num2 {
                        return num1 < num2
                    }
                    return chapter1.title < chapter2.title
                }
                self?.chapters = sortedChapters
                self?.tableView.reloadData()
                self?.emptyState.isHidden = !chapters.isEmpty
            })
            .store(in: &cancellables)
    }

    // MARK: - 动作
    @objc private func startReading() {
        guard !chapters.isEmpty else {
            NRToast.shared.info("暂无章节可阅读")
            return
        }
        let readerVC = AppContainer.shared.makeReaderViewController(book: book, chapters: chapters, startIndex: 0)
        navigationController?.pushViewController(readerVC, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate
extension ChapterListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chapters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChapterCell.reuseID, for: indexPath) as! ChapterCell
        cell.configure(with: chapters[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let readerVC = AppContainer.shared.makeReaderViewController(book: book, chapters: chapters, startIndex: indexPath.row)
        navigationController?.pushViewController(readerVC, animated: true)
    }
}

// MARK: - 章节单元格
final class ChapterCell: UITableViewCell {
    static let reuseID = "ChapterCell"

    private let cardView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DesignToken.Color.backgroundPrimary
        v.layer.cornerRadius = DesignToken.Radius.md // 圆角12pt
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.body
        label.textColor = DesignToken.Color.textPrimary
        label.numberOfLines = 1
        return label
    }()

    private let wordCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption2
        label.textColor = DesignToken.Color.textSecondary
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(wordCountLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignToken.Spacing.xs),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.md),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignToken.Spacing.md),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignToken.Spacing.xs),

            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DesignToken.Spacing.lg),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: DesignToken.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DesignToken.Spacing.md),

            wordCountLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            wordCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignToken.Spacing.xs),
            wordCountLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DesignToken.Spacing.md)
        ])
    }

    func configure(with chapter: Chapter) {
        titleLabel.text = chapter.title
        wordCountLabel.text = "\(chapter.wordCount) 字"
    }
}
