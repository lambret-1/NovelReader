import UIKit
import Combine

/// 阅读器视图控制器（分页模式）
final class ReaderViewController: UIViewController {
    private let book: Book
    private let chapters: [Chapter]
    private var currentChapterIndex: Int
    private var currentPageIndex: Int = 0
    private let viewModel: ReaderViewModel
    private let paginationEngine = PaginationEngine()
    private var currentPages: [PaginationEngine.Page] = []
    private var cancellables = Set<AnyCancellable>()

    // 章节预加载缓存
    private var chapterCache: [Int: [PaginationEngine.Page]] = [:]

    // MARK: - UI 组件
    private lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 0]
        )
        pvc.dataSource = self
        pvc.delegate = self
        pvc.view.translatesAutoresizingMaskIntoConstraints = false
        return pvc
    }()

    private lazy var configPanel: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = CGSize(width: 0, height: -4)
        view.isHidden = true
        return view
    }()

    private lazy var fontSizeSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 12
        slider.maximumValue = 32
        slider.value = Float(AppConfig.defaultFontSize)
        return slider
    }()

    private lazy var lineSpacingSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 20
        slider.value = Float(AppConfig.defaultLineSpacing)
        return slider
    }()

    private lazy var themeSegmented: UISegmentedControl = {
        let items = ReaderTheme.all.map { $0.name }
        let sc = UISegmentedControl(items: items)
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.selectedSegmentIndex = 0
        return sc
    }()

    private lazy var fontButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("字体", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14)
        return btn
    }()

    private lazy var bookmarkButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "bookmark"), for: .normal)
        btn.tintColor = .label
        return btn
    }()

    private lazy var searchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        btn.tintColor = .label
        return btn
    }()

    private lazy var bookmarkListButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        btn.tintColor = .label
        return btn
    }()

    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var chapterTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        return label
    }()

    // MARK: - 初始化
    init(book: Book, chapters: [Chapter], startIndex: Int, viewModel: ReaderViewModel) {
        self.book = book
        self.chapters = chapters
        self.currentChapterIndex = startIndex
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.loadBookmarks(for: book.id)
        loadChapter(at: currentChapterIndex, restorePage: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ReadingStatsManager.shared.startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ReadingStatsManager.shared.endSession()
        saveReadingProgress()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        view.addSubview(chapterTitleLabel)
        view.addSubview(progressLabel)
        view.addSubview(configPanel)

        configPanel.addSubview(fontSizeSlider)
        configPanel.addSubview(lineSpacingSlider)
        configPanel.addSubview(themeSegmented)
        configPanel.addSubview(fontButton)
        configPanel.addSubview(bookmarkButton)
        configPanel.addSubview(searchButton)
        configPanel.addSubview(bookmarkListButton)

        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            chapterTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            chapterTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            chapterTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            configPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            configPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            configPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            configPanel.heightAnchor.constraint(equalToConstant: 200),

            fontSizeSlider.topAnchor.constraint(equalTo: configPanel.topAnchor, constant: 20),
            fontSizeSlider.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            fontSizeSlider.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24),

            lineSpacingSlider.topAnchor.constraint(equalTo: fontSizeSlider.bottomAnchor, constant: 16),
            lineSpacingSlider.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            lineSpacingSlider.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24),

            themeSegmented.topAnchor.constraint(equalTo: lineSpacingSlider.bottomAnchor, constant: 16),
            themeSegmented.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            themeSegmented.widthAnchor.constraint(equalToConstant: 200),

            fontButton.centerYAnchor.constraint(equalTo: themeSegmented.centerYAnchor),
            fontButton.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24),

            bookmarkButton.topAnchor.constraint(equalTo: themeSegmented.bottomAnchor, constant: 16),
            bookmarkButton.trailingAnchor.constraint(equalTo: configPanel.centerXAnchor, constant: -40),

            searchButton.topAnchor.constraint(equalTo: themeSegmented.bottomAnchor, constant: 16),
            searchButton.centerXAnchor.constraint(equalTo: configPanel.centerXAnchor),

            bookmarkListButton.topAnchor.constraint(equalTo: themeSegmented.bottomAnchor, constant: 16),
            bookmarkListButton.leadingAnchor.constraint(equalTo: configPanel.centerXAnchor, constant: 40)
        ])

        // 点击中间区域显示/隐藏菜单
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.delegate = self
        pageViewController.view.addGestureRecognizer(tapGesture)

        fontSizeSlider.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)
        lineSpacingSlider.addTarget(self, action: #selector(lineSpacingChanged), for: .valueChanged)
        themeSegmented.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        fontButton.addTarget(self, action: #selector(showFontPicker), for: .touchUpInside)
        bookmarkButton.addTarget(self, action: #selector(toggleBookmark), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(showSearch), for: .touchUpInside)
        bookmarkListButton.addTarget(self, action: #selector(showBookmarkList), for: .touchUpInside)
    }

    private func bindViewModel() {
        viewModel.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.applyConfig(config)
                ReaderSettingsManager.shared.saveConfig(config)
            }
            .store(in: &cancellables)
    }

    // MARK: - 加载章节
    /// 只加载分页数据，不设置视图控制器（用于数据源方法中）
    private func loadChapterPages(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        currentChapterIndex = index
        let chapter = chapters[index]
        chapterTitleLabel.text = chapter.title

        if let cachedPages = chapterCache[index] {
            currentPages = cachedPages
            return
        }

        let config = viewModel.config
        let attributedString = makeAttributedString(from: chapter.content, config: config)
        let bounds = view.bounds.inset(by: UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20))
        currentPages = paginationEngine.paginate(attributedString: attributedString, bounds: bounds)
        chapterCache[index] = currentPages
    }

    /// 加载章节并设置初始页面
    private func loadChapter(at index: Int, restorePage: Bool = false) {
        loadChapterPages(at: index)
        guard index < chapters.count else { return }
        setupInitialPage(restorePage: restorePage, chapter: chapters[index])
        preloadAdjacentChapters()
    }

    private func setupInitialPage(restorePage: Bool, chapter: Chapter) {
        if restorePage {
            viewModel.loadReadingProgress(for: book.id) { [weak self] progress in
                guard let self = self else { return }
                if let progress = progress, progress.chapterId == chapter.id {
                    self.currentPageIndex = self.paginationEngine.pageIndex(for: progress.offset, in: self.currentPages)
                } else {
                    self.currentPageIndex = 0
                }
                self.currentPageIndex = min(self.currentPageIndex, max(0, self.currentPages.count - 1))
                if let firstVC = self.makePageViewController(at: self.currentPageIndex) {
                    self.pageViewController.setViewControllers([firstVC], direction: .forward, animated: false)
                }
                self.updateProgressLabel()
                self.updateBookmarkButtonState()
            }
        } else {
            currentPageIndex = min(currentPageIndex, max(0, currentPages.count - 1))
            if let firstVC = makePageViewController(at: currentPageIndex) {
                pageViewController.setViewControllers([firstVC], direction: .forward, animated: false)
            }
            updateProgressLabel()
            updateBookmarkButtonState()
        }
    }

    private func makeAttributedString(from text: String, config: ReaderConfig) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = config.lineSpacing
        paragraphStyle.paragraphSpacing = config.lineSpacing * 1.5
        paragraphStyle.firstLineHeadIndent = config.fontSize * 2

        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont(name: config.fontName, size: config.fontSize) ?? .systemFont(ofSize: config.fontSize),
                .foregroundColor: config.currentTheme.textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private func makePageViewController(at index: Int) -> ReaderPageViewController? {
        guard index >= 0 && index < currentPages.count else { return nil }
        return ReaderPageViewController(page: currentPages[index], config: viewModel.config)
    }

    private func preloadAdjacentChapters() {
        let config = viewModel.config
        let bounds = view.bounds.inset(by: UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20))

        for offset in [-1, 1] {
            let idx = currentChapterIndex + offset
            guard idx >= 0 && idx < chapters.count, chapterCache[idx] == nil else { continue }
            let chapter = chapters[idx]
            let attributedString = makeAttributedString(from: chapter.content, config: config)
            chapterCache[idx] = paginationEngine.paginate(attributedString: attributedString, bounds: bounds)
        }
    }

    // MARK: - 配置应用
    private func applyConfig(_ config: ReaderConfig) {
        view.backgroundColor = config.currentTheme.backgroundColor
        chapterCache.removeAll()
        paginationEngine.invalidateCache()

        if currentChapterIndex < chapters.count {
            let chapter = chapters[currentChapterIndex]
            let offset = currentPages.indices.contains(currentPageIndex) ? currentPages[currentPageIndex].range.location : 0
            loadChapter(at: currentChapterIndex, restorePage: false)
            currentPageIndex = paginationEngine.pageIndex(for: offset, in: currentPages)
            if let vc = makePageViewController(at: currentPageIndex) {
                pageViewController.setViewControllers([vc], direction: .forward, animated: false)
            }
            updateProgressLabel()
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    private func updateProgressLabel() {
        let chapterProgress = currentPages.count > 0 ? Double(currentPageIndex + 1) / Double(currentPages.count) : 0
        let totalProgress = (Double(currentChapterIndex) + chapterProgress) / Double(chapters.count)
        progressLabel.text = String(format: "第 %d/%d 章  %.0f%%", currentChapterIndex + 1, chapters.count, totalProgress * 100)
    }

    // MARK: - 阅读进度
    private func saveReadingProgress() {
        guard currentChapterIndex < chapters.count else { return }
        let chapter = chapters[currentChapterIndex]
        let offset = currentPages.indices.contains(currentPageIndex) ? currentPages[currentPageIndex].range.location : 0
        let percent = (Double(currentChapterIndex) + Double(currentPageIndex) / Double(max(1, currentPages.count))) / Double(chapters.count)

        let progress = ReadingProgress(
            bookId: book.id,
            chapterId: chapter.id,
            offset: offset,
            percent: min(1.0, percent),
            updatedAt: Date()
        )
        viewModel.saveReadingProgress(progress)
    }

    // MARK: - 书签列表
    @objc private func showBookmarkList() {
        let bookmarkListVC = BookmarkListViewController(
            book: book,
            chapters: chapters,
            bookmarkRepository: viewModel.bookmarkRepository
        ) { [weak self] chapterIndex, offset in
            guard let self = self else { return }
            self.loadChapter(at: chapterIndex, restorePage: false)
            let targetPage = self.paginationEngine.pageIndex(for: offset, in: self.currentPages)
            self.currentPageIndex = targetPage
            if let vc = self.makePageViewController(at: targetPage) {
                self.pageViewController.setViewControllers([vc], direction: .forward, animated: false)
            }
            self.updateProgressLabel()
        }
        let nav = UINavigationController(rootViewController: bookmarkListVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - 搜索
    @objc private func showSearch() {
        let searchVC = SearchViewController(book: book, chapters: chapters) { [weak self] chapterIndex, offset in
            guard let self = self else { return }
            self.loadChapter(at: chapterIndex, restorePage: false)
            let targetPage = self.paginationEngine.pageIndex(for: offset, in: self.currentPages)
            self.currentPageIndex = targetPage
            if let vc = self.makePageViewController(at: targetPage) {
                self.pageViewController.setViewControllers([vc], direction: .forward, animated: false)
            }
            self.updateProgressLabel()
        }
        let nav = UINavigationController(rootViewController: searchVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - 书签
    @objc private func toggleBookmark() {
        guard currentChapterIndex < chapters.count else { return }
        let chapter = chapters[currentChapterIndex]
        let offset = currentPages.indices.contains(currentPageIndex) ? currentPages[currentPageIndex].range.location : 0

        if viewModel.hasBookmark(bookId: book.id, chapterId: chapter.id, offset: offset) {
            viewModel.removeBookmark(bookId: book.id, chapterId: chapter.id, offset: offset)
            bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        } else {
            let excerpt = String(chapter.content.dropFirst(offset).prefix(30))
            viewModel.addBookmark(bookId: book.id, chapterId: chapter.id, offset: offset, textExcerpt: excerpt)
            bookmarkButton.setImage(UIImage(systemName: "bookmark.fill"), for: .normal)
        }
    }

    private func updateBookmarkButtonState() {
        guard currentChapterIndex < chapters.count else { return }
        let chapter = chapters[currentChapterIndex]
        let offset = currentPages.indices.contains(currentPageIndex) ? currentPages[currentPageIndex].range.location : 0
        let hasBookmark = viewModel.hasBookmark(bookId: book.id, chapterId: chapter.id, offset: offset)
        bookmarkButton.setImage(UIImage(systemName: hasBookmark ? "bookmark.fill" : "bookmark"), for: .normal)
    }

    // MARK: - 动作
    @objc private func handleTap() {
        configPanel.isHidden.toggle()
        navigationController?.setNavigationBarHidden(!configPanel.isHidden, animated: true)
    }

    @objc private func fontSizeChanged() {
        viewModel.updateFontSize(CGFloat(fontSizeSlider.value))
    }

    @objc private func lineSpacingChanged() {
        viewModel.updateLineSpacing(CGFloat(lineSpacingSlider.value))
    }

    @objc private func themeChanged() {
        let theme = ReaderTheme.all[themeSegmented.selectedSegmentIndex]
        viewModel.updateTheme(theme.id)
    }

    @objc private func showFontPicker() {
        let alert = UIAlertController(title: "选择字体", message: nil, preferredStyle: .actionSheet)
        let fonts = ["系统默认", "Georgia", "Times New Roman", "Arial", "Courier New"]
        for font in fonts {
            alert.addAction(UIAlertAction(title: font, style: .default) { [weak self] _ in
                let fontName = font == "系统默认" ? AppConfig.defaultFontName : font
                self?.viewModel.updateFontName(fontName)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = fontButton
        }
        present(alert, animated: true)
    }
}

// MARK: - UIPageViewControllerDataSource
extension ReaderViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if currentPageIndex > 0 {
            return makePageViewController(at: currentPageIndex - 1)
        } else if currentChapterIndex > 0 {
            // 切换到上一章最后一页（只加载分页，不设置视图控制器）
            let prevIndex = currentChapterIndex - 1
            loadChapterPages(at: prevIndex)
            currentPageIndex = max(0, currentPages.count - 1)
            return makePageViewController(at: currentPageIndex)
        }
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if currentPageIndex < currentPages.count - 1 {
            return makePageViewController(at: currentPageIndex + 1)
        } else if currentChapterIndex < chapters.count - 1 {
            // 切换到下一章第一页（只加载分页，不设置视图控制器）
            let nextIndex = currentChapterIndex + 1
            loadChapterPages(at: nextIndex)
            currentPageIndex = 0
            return makePageViewController(at: 0)
        }
        return nil
    }
}

// MARK: - UIPageViewControllerDelegate
extension ReaderViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let vc = pageViewController.viewControllers?.first as? ReaderPageViewController else { return }
        if let index = currentPages.firstIndex(where: { $0.pageIndex == vc.page.pageIndex }) {
            currentPageIndex = index
            updateProgressLabel()
            updateBookmarkButtonState()
            // 更新章节标题
            if currentChapterIndex < chapters.count {
                chapterTitleLabel.text = chapters[currentChapterIndex].title
            }
            preloadAdjacentChapters()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ReaderViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

/// 阅读器 ViewModel
final class ReaderViewModel {
    @Published var config: ReaderConfig
    let readingProgressRepository: ReadingProgressRepository?
    let bookmarkRepository: BookmarkRepository?
    private var cancellables = Set<AnyCancellable>()
    private var cachedBookmarks: [Bookmark] = []

    init(config: ReaderConfig = .default,
         readingProgressRepository: ReadingProgressRepository? = nil,
         bookmarkRepository: BookmarkRepository? = nil) {
        self.config = config
        self.readingProgressRepository = readingProgressRepository
        self.bookmarkRepository = bookmarkRepository
    }

    func updateFontSize(_ size: CGFloat) { config.fontSize = size }
    func updateTheme(_ themeID: String) { config.themeID = themeID }
    func updateLineSpacing(_ spacing: CGFloat) { config.lineSpacing = spacing }
    func updateFontName(_ name: String) { config.fontName = name }

    // MARK: - 阅读进度
    func loadReadingProgress(for bookId: String, completion: @escaping (ReadingProgress?) -> Void) {
        readingProgressRepository?.fetchProgress(bookId: bookId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { progress in
                completion(progress)
            })
            .store(in: &cancellables)
    }

    func saveReadingProgress(_ progress: ReadingProgress) {
        _ = readingProgressRepository?.saveProgress(progress)
    }

    // MARK: - 书签
    func loadBookmarks(for bookId: String) {
        bookmarkRepository?.fetchBookmarks(bookId: bookId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] bookmarks in
                self?.cachedBookmarks = bookmarks
            })
            .store(in: &cancellables)
    }

    func hasBookmark(bookId: String, chapterId: String, offset: Int) -> Bool {
        cachedBookmarks.contains { $0.chapterId == chapterId && abs($0.offset - offset) < 50 }
    }

    func addBookmark(bookId: String, chapterId: String, offset: Int, textExcerpt: String) {
        let bookmark = Bookmark(bookId: bookId, chapterId: chapterId, offset: offset, textExcerpt: textExcerpt)
        cachedBookmarks.append(bookmark)
        _ = bookmarkRepository?.createBookmark(bookmark)
    }

    func removeBookmark(bookId: String, chapterId: String, offset: Int) {
        if let index = cachedBookmarks.firstIndex(where: { $0.chapterId == chapterId && abs($0.offset - offset) < 50 }) {
            let bookmark = cachedBookmarks.remove(at: index)
            _ = bookmarkRepository?.deleteBookmark(id: bookmark.id)
        }
    }
}
