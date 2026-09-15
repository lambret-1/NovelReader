import UIKit
import Combine

/// 阅读器视图控制器
final class ReaderViewController: UIViewController {
    private let book: Book
    private let chapters: [Chapter]
    private var currentIndex: Int
    private let viewModel: ReaderViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI 组件
    private lazy var contentTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.showsVerticalScrollIndicator = false
        tv.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return tv
    }()

    private lazy var configPanel: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowRadius = 8
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

    private lazy var themeSegmented: UISegmentedControl = {
        let items = ReaderTheme.all.map { $0.name }
        let sc = UISegmentedControl(items: items)
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.selectedSegmentIndex = 0
        return sc
    }()

    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    // MARK: - 初始化
    init(book: Book, chapters: [Chapter], startIndex: Int, viewModel: ReaderViewModel) {
        self.book = book
        self.chapters = chapters
        self.currentIndex = startIndex
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
        loadChapter(at: currentIndex)
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        view.addSubview(contentTextView)
        view.addSubview(progressLabel)
        view.addSubview(configPanel)

        configPanel.addSubview(fontSizeSlider)
        configPanel.addSubview(themeSegmented)

        NSLayoutConstraint.activate([
            contentTextView.topAnchor.constraint(equalTo: view.topAnchor),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            configPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            configPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            configPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            configPanel.heightAnchor.constraint(equalToConstant: 120),

            fontSizeSlider.topAnchor.constraint(equalTo: configPanel.topAnchor, constant: 16),
            fontSizeSlider.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 20),
            fontSizeSlider.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -20),

            themeSegmented.topAnchor.constraint(equalTo: fontSizeSlider.bottomAnchor, constant: 16),
            themeSegmented.leadingAnchor.constraint(equalTo: configPanel.leadingAnchor, constant: 20),
            themeSegmented.trailingAnchor.constraint(equalTo: configPanel.trailingAnchor, constant: -20)
        ])

        // 点击中间区域显示/隐藏菜单
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentTextView.addGestureRecognizer(tapGesture)

        // 左右滑动切换章节
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(prevChapter))
        leftSwipe.direction = .right
        contentTextView.addGestureRecognizer(leftSwipe)

        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(nextChapter))
        rightSwipe.direction = .left
        contentTextView.addGestureRecognizer(rightSwipe)

        fontSizeSlider.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)
        themeSegmented.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
    }

    private func bindViewModel() {
        viewModel.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.applyConfig(config)
            }
            .store(in: &cancellables)
    }

    // MARK: - 加载章节
    private func loadChapter(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        currentIndex = index
        let chapter = chapters[index]
        title = chapter.title

        let config = viewModel.config
        let attributedString = NSAttributedString(
            string: chapter.content,
            attributes: [
                .font: UIFont(name: config.fontName, size: config.fontSize) ?? .systemFont(ofSize: config.fontSize),
                .foregroundColor: config.currentTheme.textColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = config.lineSpacing
                    style.paragraphSpacing = config.lineSpacing * 1.5
                    return style
                }()
            ]
        )
        contentTextView.attributedText = attributedString
        contentTextView.setContentOffset(.zero, animated: false)

        progressLabel.text = "第 \(index + 1) / \(chapters.count) 章"
    }

    private func applyConfig(_ config: ReaderConfig) {
        view.backgroundColor = config.currentTheme.backgroundColor
        contentTextView.backgroundColor = config.currentTheme.backgroundColor
        contentTextView.textColor = config.currentTheme.textColor

        // 重新应用当前章节的样式
        if currentIndex < chapters.count {
            loadChapter(at: currentIndex)
        }

        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - 动作
    @objc private func handleTap() {
        configPanel.isHidden.toggle()
        navigationController?.setNavigationBarHidden(!configPanel.isHidden, animated: true)
    }

    @objc private func prevChapter() {
        if currentIndex > 0 {
            loadChapter(at: currentIndex - 1)
        }
    }

    @objc private func nextChapter() {
        if currentIndex < chapters.count - 1 {
            loadChapter(at: currentIndex + 1)
        }
    }

    @objc private func fontSizeChanged() {
        viewModel.updateFontSize(CGFloat(fontSizeSlider.value))
    }

    @objc private func themeChanged() {
        let theme = ReaderTheme.all[themeSegmented.selectedSegmentIndex]
        viewModel.updateTheme(theme.id)
    }
}

/// 阅读器 ViewModel
final class ReaderViewModel {
    @Published var config: ReaderConfig

    init(config: ReaderConfig = .default) {
        self.config = config
    }

    func updateFontSize(_ size: CGFloat) {
        config.fontSize = size
    }

    func updateTheme(_ themeID: String) {
        config.themeID = themeID
    }

    func updateLineSpacing(_ spacing: CGFloat) {
        config.lineSpacing = spacing
    }
}
