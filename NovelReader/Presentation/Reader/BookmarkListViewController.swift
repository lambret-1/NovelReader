import UIKit
import Combine

/// 书签列表视图控制器
final class BookmarkListViewController: UIViewController {
    private let book: Book
    private let chapters: [Chapter]
    private let bookmarkRepository: BookmarkRepository?
    private let onSelect: (Int, Int) -> Void
    private var cancellables = Set<AnyCancellable>()
    private var bookmarks: [Bookmark] = []

    // MARK: - UI 组件
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(BookmarkCell.self, forCellReuseIdentifier: BookmarkCell.reuseID)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return tv
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "还没有书签\n在阅读时点击书签按钮添加"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.isHidden = true
        return label
    }()

    // MARK: - 初始化
    init(book: Book, chapters: [Chapter], bookmarkRepository: BookmarkRepository?, onSelect: @escaping (Int, Int) -> Void) {
        self.book = book
        self.chapters = chapters
        self.bookmarkRepository = bookmarkRepository
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadBookmarks()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "书签"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissBookmarks)
        )

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    // MARK: - 加载书签
    private func loadBookmarks() {
        guard let repo = bookmarkRepository else { return }
        repo.fetchBookmarks(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] bookmarks in
                self?.bookmarks = bookmarks
                self?.tableView.reloadData()
                self?.emptyLabel.isHidden = !bookmarks.isEmpty
            })
            .store(in: &cancellables)
    }

    @objc private func dismissBookmarks() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension BookmarkListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BookmarkCell.reuseID, for: indexPath) as! BookmarkCell
        let bookmark = bookmarks[indexPath.row]
        let chapter = chapters.first { $0.id == bookmark.chapterId }
        cell.configure(with: bookmark, chapterTitle: chapter?.title ?? "未知章节")
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let bookmark = bookmarks[indexPath.row]
        if let chapterIndex = chapters.firstIndex(where: { $0.id == bookmark.chapterId }) {
            onSelect(chapterIndex, bookmark.offset)
            dismiss(animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else { return }
            let bookmark = self.bookmarks[indexPath.row]
            self.bookmarkRepository?.deleteBookmark(id: bookmark.id)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                    self?.bookmarks.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    self?.emptyLabel.isHidden = !(self?.bookmarks.isEmpty ?? true)
                })
                .store(in: &self.cancellables)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

/// 书签单元格
final class BookmarkCell: UITableViewCell {
    static let reuseID = "BookmarkCell"

    private let chapterLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let excerptLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.textAlignment = .right
        return label
    }()

    private let bookmarkIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "bookmark.fill"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .systemOrange
        iv.contentMode = .scaleAspectFit
        return iv
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
        contentView.addSubview(bookmarkIcon)
        contentView.addSubview(chapterLabel)
        contentView.addSubview(excerptLabel)
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            bookmarkIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bookmarkIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            bookmarkIcon.widthAnchor.constraint(equalToConstant: 16),
            bookmarkIcon.heightAnchor.constraint(equalToConstant: 20),

            chapterLabel.leadingAnchor.constraint(equalTo: bookmarkIcon.trailingAnchor, constant: 10),
            chapterLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            chapterLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            timeLabel.centerYAnchor.constraint(equalTo: chapterLabel.centerYAnchor),
            timeLabel.widthAnchor.constraint(equalToConstant: 80),

            excerptLabel.leadingAnchor.constraint(equalTo: chapterLabel.leadingAnchor),
            excerptLabel.topAnchor.constraint(equalTo: chapterLabel.bottomAnchor, constant: 4),
            excerptLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            excerptLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with bookmark: Bookmark, chapterTitle: String) {
        chapterLabel.text = chapterTitle
        excerptLabel.text = bookmark.textExcerpt ?? "位置 \(bookmark.offset)"
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        timeLabel.text = formatter.string(from: bookmark.createdAt)
    }
}
