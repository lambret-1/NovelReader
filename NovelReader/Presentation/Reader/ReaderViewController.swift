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
        view.backgroundColor = DesignToken.Color.backgroundPrimary
        view.layer.cornerRadius = DesignToken.Radius.xl // 设置面板圆角16pt，视觉柔和
        view.applyShadow(DesignToken.Shadow.lg) // 大阴影，悬浮效果
        view.isHidden = true
        return view
    }()

    // 字体大小调节组（A- / 字号 / A+）
    private lazy var fontSizeDecreaseButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("A-", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14) // 减小按钮字号14pt
        btn.tintColor = DesignToken.Color.textPrimary
        btn.backgroundColor = DesignToken.Color.backgroundSecondary
        btn.layer.cornerRadius = 8 // 按钮圆角8pt
        btn.addTarget(self, action: #selector(fontSizeDecrease), for: .touchUpInside)
        return btn
    }()

    private lazy var fontSizeValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\(Int(AppConfig.defaultFontSize))"
        label.font = DesignToken.Font.subhead // 字号显示15pt
        label.textColor = DesignToken.Color.textPrimary
        label.textAlignment = .center
        return label
    }()

    private lazy var fontSizeIncreaseButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("A+", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18) // 增大按钮字号18pt
        btn.tintColor = DesignToken.Color.textPrimary
        btn.backgroundColor = DesignToken.Color.backgroundSecondary
        btn.layer.cornerRadius = 8 // 按钮圆角8pt
        btn.addTarget(self, action: #selector(fontSizeIncrease), for: .touchUpInside)
        return btn
    }()

    // 行段间距
    private lazy var lineSpacingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "行段间距"
        label.font = DesignToken.Font.subhead // 标签字号15pt
        label.textColor = DesignToken.Color.textPrimary
        return label
    }()

    private lazy var lineSpacingSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 20
        slider.value = Float(AppConfig.defaultLineSpacing)
        slider.minimumTrackTintColor = DesignToken.Color.primary
        slider.thumbTintColor = DesignToken.Color.primary
        return slider
    }()

    // 页面间距
    private lazy var pageMarginLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "页面间距"
        label.font = DesignToken.Font.subhead // 标签字号15pt
        label.textColor = DesignToken.Color.textPrimary
        return label
    }()

    private lazy var pageMarginSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 8
        slider.maximumValue = 40
        slider.value = 20 // 默认页面间距20pt
        slider.minimumTrackTintColor = DesignToken.Color.primary
        slider.thumbTintColor = DesignToken.Color.primary
        return slider
    }()

    private lazy var themeSegmented: UISegmentedControl = {
        let items = ReaderTheme.all.map { $0.name }
        let sc = UISegmentedControl(items: items)
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.selectedSegmentIndex = 0
        sc.selectedSegmentTintColor = DesignToken.Color.primary // 选中段主色
        sc.setTitleTextAttributes([.foregroundColor: DesignToken.Color.textInverse], for: .selected)
        return sc
    }()

    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption2 // 进度字号11pt
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .center
        return label
    }()

    private lazy var chapterTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.footnote // 章节标题13pt
        label.textColor = DesignToken.Color.textSecondary
        label.textAlignment = .left
        return label
    }()

    // MARK: - 新 UI 组件
    private lazy var bottomBar: NRReaderBottomBar = {
        let bar = NRReaderBottomBar()
        bar.onCatalogTapped = { [weak self] in
            self?.showCatalog()
        }
        bar.onSettingsTapped = { [weak self] in
            self?.toggleConfigPanel()
        }
        bar.onProgressTapped = { [weak self] in
            self?.showProgressDetail()
        }
        return bar
    }()

    private var catalogView: NRReaderCatalogView?
    private var areBarsHidden = true // 底部工具栏默认隐藏，点击屏幕呼出，提供沉浸式阅读体验
    private var autoHideTimer: Timer?
    private var isNightMode = false

    // MARK: - 初始化
    init(book: Book, chapters: [Chapter], startIndex: Int, viewModel: ReaderViewModel) {
        self.book = book
        self.chapters = chapters
        self.currentChapterIndex = startIndex
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true // 进入阅读器时隐藏底部 tab 栏，提供沉浸式阅读体验
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
        bottomBar.alpha = 0 // 底部工具栏默认隐藏，沉浸式阅读
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ReadingStatsManager.shared.startSession()
        updateProgress()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ReadingStatsManager.shared.endSession()
        saveReadingProgress()
        // 恢复导航栏显示，防止返回上级页面后导航栏消失
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundPrimary
        navigationController?.setNavigationBarHidden(true, animated: false)

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        // 新 UI 组件
        view.addSubview(bottomBar)

        // 旧组件（保留，后续迁移）
        view.addSubview(chapterTitleLabel)
        view.addSubview(progressLabel)
        view.addSubview(configPanel)
        chapterTitleLabel.isHidden = true
        progressLabel.isHidden = true

        configPanel.addSubview(fontSizeDecreaseButton)
        configPanel.addSubview(fontSizeValueLabel)
        configPanel.addSubview(fontSizeIncreaseButton)
        configPanel.addSubview(lineSpacingLabel)
        configPanel.addSubview(lineSpacingSlider)
        configPanel.addSubview(pageMarginLabel)
        configPanel.addSubview(pageMarginSlider)
        configPanel.addSubview(themeSegmented)

        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), // 阅读区域从安全区顶部开始，移除顶部工具栏后全屏显示
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor), // 阅读区域全屏显示，底部工具栏覆盖在上方

            // 上工具栏
            // 下工具栏
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), // 下工具栏到安全区底部，避免Home Indicator遮挡
            bottomBar.heightAnchor.constraint(equalToConstant: 44), // 下工具栏高度44pt，标准工具栏高度

            chapterTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            chapterTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            chapterTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            configPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.lg),
            configPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignToken.Spacing.lg),
            configPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignToken.Spacing.lg),
            configPanel.heightAnchor.constraint(equalToConstant: 280), // 设置面板高度280pt，容纳更多设置项

            // 字体大小调节组（第一行）
            fontSizeDecreaseButton.topAnchor.constraint(equalTo: configPanel.topAnchor, constant: 20),
            fontSizeDecreaseButton.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            fontSizeDecreaseButton.widthAnchor.constraint(equalToConstant: 44), // 按钮宽度44pt
            fontSizeDecreaseButton.heightAnchor.constraint(equalToConstant: 36), // 按钮高度36pt

            fontSizeValueLabel.centerYAnchor.constraint(equalTo: fontSizeDecreaseButton.centerYAnchor),
            fontSizeValueLabel.centerXAnchor.constraint(equalTo: configPanel.centerXAnchor),
            fontSizeValueLabel.widthAnchor.constraint(equalToConstant: 60), // 字号显示宽度60pt

            fontSizeIncreaseButton.centerYAnchor.constraint(equalTo: fontSizeDecreaseButton.centerYAnchor),
            fontSizeIncreaseButton.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24),
            fontSizeIncreaseButton.widthAnchor.constraint(equalToConstant: 44),
            fontSizeIncreaseButton.heightAnchor.constraint(equalToConstant: 36),

            // 行段间距（第二行）
            lineSpacingLabel.topAnchor.constraint(equalTo: fontSizeDecreaseButton.bottomAnchor, constant: 20),
            lineSpacingLabel.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            lineSpacingLabel.widthAnchor.constraint(equalToConstant: 80), // 标签宽度80pt

            lineSpacingSlider.centerYAnchor.constraint(equalTo: lineSpacingLabel.centerYAnchor),
            lineSpacingSlider.leadingAnchor.constraint(equalTo: lineSpacingLabel.trailingAnchor, constant: 12),
            lineSpacingSlider.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24),

            // 页面间距（第三行）
            pageMarginLabel.topAnchor.constraint(equalTo: lineSpacingLabel.bottomAnchor, constant: 20),
            pageMarginLabel.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            pageMarginLabel.widthAnchor.constraint(equalToConstant: 80),

            pageMarginSlider.centerYAnchor.constraint(equalTo: pageMarginLabel.centerYAnchor),
            pageMarginSlider.leadingAnchor.constraint(equalTo: pageMarginLabel.trailingAnchor, constant: 12),
            pageMarginSlider.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24),

            // 主题选择（第四行）
            themeSegmented.topAnchor.constraint(equalTo: pageMarginLabel.bottomAnchor, constant: 20),
            themeSegmented.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 24),
            themeSegmented.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -24)
        ])

        // 点击中间区域显示/隐藏菜单
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.delegate = self
        pageViewController.view.addGestureRecognizer(tapGesture)

        // 设置面板关闭手势（一直存在，通过面板状态判断是否处理）
        view.addGestureRecognizer(configPanelDismissGesture)

        lineSpacingSlider.addTarget(self, action: #selector(lineSpacingChanged), for: .valueChanged)
        pageMarginSlider.addTarget(self, action: #selector(pageMarginChanged), for: .valueChanged)
        themeSegmented.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
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
        // 使用 config.pageMargin 作为页面左右间距，与 ReaderPageViewController 保持一致
        let bounds = view.bounds.inset(by: UIEdgeInsets(top: 16, left: config.pageMargin, bottom: 16, right: config.pageMargin))
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
            }
        } else {
            currentPageIndex = min(currentPageIndex, max(0, currentPages.count - 1))
            if let firstVC = makePageViewController(at: currentPageIndex) {
                pageViewController.setViewControllers([firstVC], direction: .forward, animated: false)
            }
            updateProgressLabel()
            
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
                .font: UIFont.systemFont(ofSize: config.fontSize), // 统一使用系统默认字体
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
        let bounds = view.bounds.inset(by: UIEdgeInsets(top: 16, left: config.pageMargin, bottom: 16, right: config.pageMargin))

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

        guard currentChapterIndex < chapters.count else {
            setNeedsStatusBarAppearanceUpdate()
            return
        }

        // 保存当前阅读偏移量，用于重新分页后恢复位置
        let savedOffset = currentPages.indices.contains(currentPageIndex) ? currentPages[currentPageIndex].range.location : 0

        // 重新加载章节（内部会重新分页并设置初始页面）
        loadChapter(at: currentChapterIndex, restorePage: false)

        // 根据保存的偏移量重新定位到最接近的页面
        if !currentPages.isEmpty {
            currentPageIndex = paginationEngine.pageIndex(for: savedOffset, in: currentPages)
            currentPageIndex = min(currentPageIndex, currentPages.count - 1)
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
        NRToast.shared.info("书签列表功能开发中")
    }

    // MARK: - 搜索
    @objc private func showSearch() {
        NRToast.shared.info("搜索功能开发中")
    }

    // MARK: - 书签
    @objc private func toggleBookmark() {
        guard currentChapterIndex < chapters.count else { return }
        let chapter = chapters[currentChapterIndex]
        let offset = currentPages.indices.contains(currentPageIndex) ? currentPages[currentPageIndex].range.location : 0

        if viewModel.hasBookmark(bookId: book.id, chapterId: chapter.id, offset: offset) {
            viewModel.removeBookmark(bookId: book.id, chapterId: chapter.id, offset: offset)
            NRToast.shared.info("已移除书签")
        } else {
            let excerpt = String(chapter.content.dropFirst(offset).prefix(30))
            viewModel.addBookmark(bookId: book.id, chapterId: chapter.id, offset: offset, textExcerpt: excerpt)
            NRToast.shared.success("已添加书签")
        }
    }

    // MARK: - 动作
    @objc private func handleTap() {
        // 如果设置面板打开，先关闭面板，不切换工具栏
        if !configPanel.isHidden {
            configPanel.isHidden = true
            return
        }
        toggleBars()
    }
    // MARK: - 设置面板显隐
    // 点击空白区域关闭设置面板的手势（一直存在，通过面板状态判断是否处理）
    private lazy var configPanelDismissGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissConfigPanel))
        gesture.delegate = self
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    @objc private func toggleConfigPanel() {
        let isHidden = configPanel.isHidden
        configPanel.isHidden = !isHidden
        if !isHidden {
            // 同步当前配置到控件
            fontSizeValueLabel.text = "\(Int(viewModel.config.fontSize))"
            lineSpacingSlider.value = Float(viewModel.config.lineSpacing)
            pageMarginSlider.value = Float(viewModel.config.pageMargin)
            if let themeIndex = ReaderTheme.all.firstIndex(where: { $0.id == viewModel.config.themeID }) {
                themeSegmented.selectedSegmentIndex = themeIndex
            }
        }
        FeedbackManager.shared.mediumImpact()
    }

    /// 点击非设置面板区域时关闭面板
    @objc private func dismissConfigPanel(_ gesture: UITapGestureRecognizer) {
        // 面板未打开时不处理
        guard !configPanel.isHidden else { return }

        let location = gesture.location(in: view)
        // 如果点击位置在设置面板内，不关闭
        if configPanel.frame.contains(location) {
            return
        }
        configPanel.isHidden = true
    }

    // MARK: - 工具栏显隐
    private func toggleBars() {
        areBarsHidden.toggle()
        let alpha: CGFloat = areBarsHidden ? 0 : 1
        UIView.animate(withDuration: DesignToken.Animation.normal) {
            self.bottomBar.alpha = alpha
        }
        if !areBarsHidden {
            resetAutoHideTimer() // 呼出后5秒自动隐藏
        } else {
            autoHideTimer?.invalidate()
        }
    }

    private func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in // 呼出后5秒自动隐藏
            self?.hideBars()
        }
    }

    private func hideBars() {
        guard !areBarsHidden else { return }
        areBarsHidden = true
        UIView.animate(withDuration: DesignToken.Animation.normal) {
            self.bottomBar.alpha = 0
        }
    }

    // MARK: - 目录
    private func showCatalog() {
        guard catalogView == nil else { return }
        let catalog = NRReaderCatalogView()
        catalog.configure(chapters: chapters, currentIndex: currentChapterIndex)
        catalog.onChapterSelected = { [weak self] index in
            self?.jumpToChapter(index)
        }
        catalog.onDismiss = { [weak self] in
            self?.catalogView = nil
        }
        catalogView = catalog
        catalog.show(in: view)
        FeedbackManager.shared.lightImpact()
    }

    private func jumpToChapter(_ index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        currentChapterIndex = index
        loadChapter(at: index, restorePage: false)
        updateProgress()
    }

    // MARK: - 夜间模式
    private func toggleNightMode() {
        isNightMode.toggle()
        updateNightModeUI()
        FeedbackManager.shared.mediumImpact()
    }

    private func updateNightModeUI() {
        bottomBar.setNightMode(isNightMode)
        UIView.animate(withDuration: 0.4) {
            if self.isNightMode {
                self.view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            } else {
                self.view.backgroundColor = DesignToken.Color.backgroundPrimary
            }
        }
    }

    // MARK: - 进度详情
    private func showProgressDetail() {
        let chapter = chapters[currentChapterIndex]
        let chapterProgress = Double(currentPageIndex + 1) / Double(max(1, currentPages.count))
        let overallProgress = (Double(currentChapterIndex) + chapterProgress) / Double(max(1, chapters.count))
        let message = "第\(currentChapterIndex + 1)章 \(chapter.title) - 全书\(Int(overallProgress * 100))%"
        NRToast.shared.info(message)
    }

    // MARK: - 更新进度
    private func updateProgress() {
        let chapterProgress = Double(currentPageIndex + 1) / Double(max(1, currentPages.count))
        let overallProgress = (Double(currentChapterIndex) + chapterProgress) / Double(max(1, chapters.count))
        bottomBar.setProgress(overallProgress)
    }


    @objc private func fontSizeDecrease() {
        let newSize = max(12, viewModel.config.fontSize - 1) // 最小字号12pt
        viewModel.updateFontSize(newSize)
        fontSizeValueLabel.text = "\(Int(newSize))"
        FeedbackManager.shared.lightImpact()
    }

    @objc private func fontSizeIncrease() {
        let newSize = min(32, viewModel.config.fontSize + 1) // 最大字号32pt
        viewModel.updateFontSize(newSize)
        fontSizeValueLabel.text = "\(Int(newSize))"
        FeedbackManager.shared.lightImpact()
    }

    @objc private func lineSpacingChanged() {
        viewModel.updateLineSpacing(CGFloat(lineSpacingSlider.value))
    }

    @objc private func pageMarginChanged() {
        viewModel.updatePageMargin(CGFloat(pageMarginSlider.value))
    }

    @objc private func themeChanged() {
        let theme = ReaderTheme.all[themeSegmented.selectedSegmentIndex]
        viewModel.updateTheme(theme.id)
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
        // 设置面板打开时，关闭手势优先识别，不与阅读区点击手势同时识别
        if !configPanel.isHidden && gestureRecognizer == configPanelDismissGesture {
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 设置面板关闭手势：如果触摸在设置面板内，不接收（让面板内控件响应）
        if gestureRecognizer == configPanelDismissGesture {
            let location = touch.location(in: view)
            return !configPanel.frame.contains(location)
        }
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
    func updatePageMargin(_ margin: CGFloat) { config.pageMargin = margin }

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
