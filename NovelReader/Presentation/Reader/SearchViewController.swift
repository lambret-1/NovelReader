import UIKit
import Combine

/// 搜索结果
struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let chapterId: String
    let chapterTitle: String
    let chapterIndex: Int
    let offset: Int
    let matchedText: String
    let contextBefore: String
    let contextAfter: String
}

/// 搜索视图控制器
final class SearchViewController: UIViewController {
    private let book: Book
    private let chapters: [Chapter]
    private let onSelect: (Int, Int) -> Void
    private var cancellables = Set<AnyCancellable>()
    private var results: [SearchResult] = []
    private var searchWorkItem: DispatchWorkItem?

    // MARK: - UI 组件
    private lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.placeholder = "搜索全书内容"
        sb.searchBarStyle = .minimal
        sb.delegate = self
        return sb
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseID)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return tv
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "输入关键词开始搜索"
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.isHidden = false
        return label
    }()

    // MARK: - 初始化
    init(book: Book, chapters: [Chapter], onSelect: @escaping (Int, Int) -> Void) {
        self.book = book
        self.chapters = chapters
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
        searchBar.becomeFirstResponder()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "搜索"

        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissSearch)
        )
    }

    // MARK: - 搜索
    private func performSearch(_ query: String) {
        searchWorkItem?.cancel()

        guard !query.isEmpty else {
            results = []
            tableView.reloadData()
            emptyLabel.text = "输入关键词开始搜索"
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.text = "搜索中..."
        emptyLabel.isHidden = false

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var found: [SearchResult] = []
            let lowercaseQuery = query.lowercased()

            for (index, chapter) in self.chapters.enumerated() {
                let content = chapter.content
                let lowerContent = content.lowercased()
                var searchStart = lowerContent.startIndex

                while searchStart < lowerContent.endIndex {
                    if let range = lowerContent.range(of: lowercaseQuery, range: searchStart..<lowerContent.endIndex) {
                        let offset = lowerContent.distance(from: lowerContent.startIndex, to: range.lowerBound)
                        let matchedStart = max(0, offset - 20)
                        let matchedEnd = min(content.count, offset + query.count + 20)

                        let beforeStart = content.index(content.startIndex, offsetBy: matchedStart)
                        let matchedLower = content.index(content.startIndex, offsetBy: offset)
                        let matchedUpper = content.index(content.startIndex, offsetBy: min(content.count, offset + query.count))
                        let afterEnd = content.index(content.startIndex, offsetBy: matchedEnd)

                        let result = SearchResult(
                            chapterId: chapter.id,
                            chapterTitle: chapter.title,
                            chapterIndex: index,
                            offset: offset,
                            matchedText: String(content[matchedLower..<matchedUpper]),
                            contextBefore: String(content[beforeStart..<matchedLower]),
                            contextAfter: String(content[matchedUpper..<afterEnd])
                        )
                        found.append(result)

                        if found.count >= 200 { break }
                        searchStart = range.upperBound
                    } else {
                        break
                    }
                }
                if found.count >= 200 { break }
            }

            DispatchQueue.main.async {
                self.results = found
                self.tableView.reloadData()
                if found.isEmpty {
                    self.emptyLabel.text = "未找到相关内容"
                    self.emptyLabel.isHidden = false
                } else {
                    self.emptyLabel.isHidden = true
                }
            }
        }

        searchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    @objc private func dismissSearch() {
        dismiss(animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        performSearch(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource & Delegate
extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseID, for: indexPath) as! SearchResultCell
        cell.configure(with: results[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let result = results[indexPath.row]
        onSelect(result.chapterIndex, result.offset)
        dismiss(animated: true)
    }
}

/// 搜索结果单元格
final class SearchResultCell: UITableViewCell {
    static let reuseID = "SearchResultCell"

    private let chapterLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let contentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(chapterLabel)
        contentView.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            chapterLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            chapterLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            chapterLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            contentLabel.topAnchor.constraint(equalTo: chapterLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with result: SearchResult) {
        chapterLabel.text = result.chapterTitle

        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(string: result.contextBefore, attributes: [.foregroundColor: UIColor.secondaryLabel]))
        attributedText.append(NSAttributedString(string: result.matchedText, attributes: [.foregroundColor: UIColor.systemBlue, .font: UIFont.systemFont(ofSize: 15, weight: .bold)]))
        attributedText.append(NSAttributedString(string: result.contextAfter, attributes: [.foregroundColor: UIColor.secondaryLabel]))
        contentLabel.attributedText = attributedText
    }
}
