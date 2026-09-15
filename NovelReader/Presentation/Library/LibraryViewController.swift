import UIKit
import Combine

/// 书架视图控制器 - 网格布局展示书籍
final class LibraryViewController: UIViewController {

    private let bookRepository = AppContainer.shared.bookRepository
    private var cancellables = Set<AnyCancellable>()
    private var books: [Book] = []

    // MARK: - UI 组件
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = DesignToken.Spacing.md // 列间距12pt
        layout.minimumLineSpacing = DesignToken.Spacing.lg // 行间距16pt
        layout.sectionInset = UIEdgeInsets(
            top: DesignToken.Spacing.lg,
            left: DesignToken.Spacing.lg,
            bottom: DesignToken.Spacing.xl,
            right: DesignToken.Spacing.lg
        )
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(BookCoverCell.self, forCellWithReuseIdentifier: BookCoverCell.reuseID)
        cv.backgroundColor = DesignToken.Color.backgroundSecondary
        cv.alwaysBounceVertical = true
        return cv
    }()

    private lazy var emptyState: NREmptyState = {
        let state = NREmptyState(
            icon: UIImage(systemName: "books.vertical"),
            title: "书架空空如也",
            subtitle: "点击右上角添加你的第一本书"
        )
        state.translatesAutoresizingMaskIntoConstraints = false
        state.isHidden = true
        return state
    }()

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadBooks()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBooks()
    }

    // MARK: - UI 搭建
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary
        view.addSubview(collectionView)
        view.addSubview(emptyState)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyState.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.xl),
            emptyState.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignToken.Spacing.xl)
        ])
    }

    private func setupNavigationBar() {
        title = "书架"
        navigationController?.navigationBar.prefersLargeTitles = true

        // 右侧添加按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(addBookTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = DesignToken.Color.primary

        // 左侧 API 刷新按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise.circle"),
            style: .plain,
            target: self,
            action: #selector(apiRefreshTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = DesignToken.Color.primary
    }

    // MARK: - 数据加载
    private func loadBooks() {
        bookRepository.fetchAllBooks()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] books in
                self?.books = books
                self?.collectionView.reloadData()
                self?.emptyState.isHidden = !books.isEmpty
            })
            .store(in: &cancellables)
    }

    // MARK: - 动作
    @objc private func addBookTapped() {
        let alert = UIAlertController(title: "添加书籍", message: "输入书名", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "书名" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            guard let title = alert.textFields?.first?.text, !title.isEmpty else { return }
            let book = Book(title: title)
            self?.bookRepository.createBook(book)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                    self?.loadBooks()
                    NRToast.shared.success("书籍添加成功")
                })
                .store(in: &self!.cancellables)
        })
        present(alert, animated: true)
    }

    @objc func apiRefreshTapped() {
        guard AppContainer.shared.authService.loadSavedToken() != nil else {
            NRToast.shared.error("请先在我的页面登录 GitHub")
            return
        }

        let alert = UIAlertController(title: "API 刷新书籍", message: "从 MyNovels 仓库拉取所有书籍和章节", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "开始刷新", style: .default) { [weak self] _ in
            self?.startAPIRefresh()
        })
        present(alert, animated: true)
    }

    private func startAPIRefresh() {
        let hud = UIAlertController(title: "正在刷新...", message: "准备中...", preferredStyle: .alert)
        present(hud, animated: true)

        NovelRefreshService.shared.$refreshMessage
            .receive(on: DispatchQueue.main)
            .sink { hud.message = $0 }
            .store(in: &cancellables)

        NovelRefreshService.shared.$refreshProgress
            .receive(on: DispatchQueue.main)
            .sink { hud.title = "正在刷新... \(Int($0 * 100))%" }
            .store(in: &cancellables)

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
                    NRToast.shared.success("新增 \(result.addedBooks) 本，更新 \(result.updatedChapters) 章")
                    self?.loadBooks()
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return books.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BookCoverCell.reuseID, for: indexPath) as! BookCoverCell
        cell.configure(with: books[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.bounds.width - DesignToken.Spacing.lg * 2 - DesignToken.Spacing.md * 2) / 3 // 三列布局
        return CGSize(width: width, height: width * 1.5) // 封面比例3:2
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let book = books[indexPath.item]
        let chapterListVC = AppContainer.shared.makeChapterListViewController(book: book)
        navigationController?.pushViewController(chapterListVC, animated: true)
    }
}

// MARK: - 书籍封面单元格
final class BookCoverCell: UICollectionViewCell {
    static let reuseID = "BookCoverCell"

    private let coverView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DesignToken.Color.primaryBackground
        v.layer.cornerRadius = DesignToken.Radius.md // 圆角12pt
        v.layer.masksToBounds = true
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.headline
        label.textColor = DesignToken.Color.textPrimary
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let chapterCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption2
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        contentView.addSubview(coverView)
        coverView.addSubview(titleLabel)
        contentView.addSubview(chapterCountLabel)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 1.3), // 封面高度

            titleLabel.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: coverView.leadingAnchor, constant: DesignToken.Spacing.sm),
            titleLabel.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -DesignToken.Spacing.sm),

            chapterCountLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: DesignToken.Spacing.xs),
            chapterCountLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    func configure(with book: Book) {
        titleLabel.text = book.title
        chapterCountLabel.text = book.author.isEmpty ? "未知作者" : book.author
    }
}
