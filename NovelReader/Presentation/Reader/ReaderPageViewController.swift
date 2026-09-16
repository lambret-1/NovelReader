import UIKit

/// 单页阅读视图控制器
final class ReaderPageViewController: UIViewController {
    let page: PaginationEngine.Page
    private var config: ReaderConfig

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.showsVerticalScrollIndicator = false
        tv.showsHorizontalScrollIndicator = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.backgroundColor = .clear
        return tv
    }()

    // textView 约束引用，用于动态更新页面间距
    private var textViewLeadingConstraint: NSLayoutConstraint!
    private var textViewTrailingConstraint: NSLayoutConstraint!

    init(page: PaginationEngine.Page, config: ReaderConfig) {
        self.page = page
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = config.currentTheme.backgroundColor
        view.addSubview(textView)

        // 使用 config.pageMargin 作为页面左右间距
        textViewLeadingConstraint = textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: config.pageMargin)
        textViewTrailingConstraint = textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -config.pageMargin)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), // 顶部间距16pt
            textViewLeadingConstraint,
            textViewTrailingConstraint,
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16) // 底部间距16pt
        ])

        textView.attributedText = page.attributedString
    }

    /// 更新配置（主题/页面间距变化时调用）
    func updateConfig(_ config: ReaderConfig) {
        self.config = config
        view.backgroundColor = config.currentTheme.backgroundColor
        // 动态更新页面左右间距
        textViewLeadingConstraint.constant = config.pageMargin
        textViewTrailingConstraint.constant = -config.pageMargin
        view.layoutIfNeeded()
    }
}
