import UIKit
import Combine

/// 冲突详情页面 - 左右对比本地和远端内容
final class ConflictDetailViewController: UIViewController {
    private let conflict: ConflictItem
    private weak var viewModel: ConflictListViewModel?

    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16 // 区块间距16pt，8pt网格
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16) // 四周边距16pt
        return stack
    }()

    private lazy var localTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = DesignToken.Font.footnote // 正文14pt
        tv.textColor = .label
        tv.backgroundColor = DesignToken.Color.backgroundSecondary
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.layer.cornerRadius = 12 // 圆角12pt
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12) // 内边距12pt
        return tv
    }()

    private lazy var remoteTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = DesignToken.Font.footnote
        tv.textColor = .label
        tv.backgroundColor = DesignToken.Color.backgroundSecondary
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return tv
    }()

    private lazy var localHeader: UILabel = {
        let label = UILabel()
        label.text = "📱 本地版本"
        label.font = DesignToken.Font.title3 // 标题16pt加粗
        label.textColor = DesignToken.Color.primary
        return label
    }()

    private lazy var remoteHeader: UILabel = {
        let label = UILabel()
        label.text = "☁️ 远端版本"
        label.font = DesignToken.Font.title3
        label.textColor = DesignToken.Color.success
        return label
    }()

    private lazy var keepLocalButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("保留本地", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold) // 按钮16pt
        btn.backgroundColor = DesignToken.Color.primary
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12 // 圆角12pt
        btn.addTarget(self, action: #selector(keepLocalTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var keepRemoteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("保留远端", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.backgroundColor = DesignToken.Color.success
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.addTarget(self, action: #selector(keepRemoteTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var keepBothButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("保留双方（合并）", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium) // 次要按钮15pt
        btn.backgroundColor = DesignToken.Color.warning.withAlphaComponent(0.15)
        btn.setTitleColor(DesignToken.Color.warning, for: .normal)
        btn.layer.cornerRadius = 12
        btn.addTarget(self, action: #selector(keepBothTapped), for: .touchUpInside)
        return btn
    }()

    init(conflict: ConflictItem, viewModel: ConflictListViewModel) {
        self.conflict = conflict
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        title = (conflict.localPath as NSString).lastPathComponent
        localTextView.text = conflict.localContent ?? "（本地内容为空）"
        remoteTextView.text = conflict.remoteContent ?? "（远端内容为空）"
    }

    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundGrouped
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        let localStack = UIStackView(arrangedSubviews: [localHeader, localTextView])
        localStack.axis = .vertical
        localStack.spacing = 8 // 标题与内容间距8pt

        let remoteStack = UIStackView(arrangedSubviews: [remoteHeader, remoteTextView])
        remoteStack.axis = .vertical
        remoteStack.spacing = 8

        let buttonStack = UIStackView(arrangedSubviews: [keepLocalButton, keepRemoteButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12 // 按钮间距12pt
        buttonStack.distribution = .fillEqually

        contentStack.addArrangedSubview(localStack)
        contentStack.addArrangedSubview(remoteStack)
        contentStack.addArrangedSubview(buttonStack)
        contentStack.addArrangedSubview(keepBothButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            localTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150), // 最小高度150pt
            remoteTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
            keepLocalButton.heightAnchor.constraint(equalToConstant: 48), // 按钮高度48pt
            keepRemoteButton.heightAnchor.constraint(equalToConstant: 48),
            keepBothButton.heightAnchor.constraint(equalToConstant: 44) // 次要按钮44pt
        ])
    }

    @objc private func keepLocalTapped() { resolveAndPop(.keepLocal) }
    @objc private func keepRemoteTapped() { resolveAndPop(.keepRemote) }
    @objc private func keepBothTapped() { resolveAndPop(.keepBoth) }

    private func resolveAndPop(_ resolution: ConflictItem.ConflictResolution) {
        viewModel?.resolveConflict(conflictId: conflict.id, resolution: resolution)
        navigationController?.popViewController(animated: true)
    }
}
