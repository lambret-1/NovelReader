import UIKit
import Combine

/// 编辑器视图控制器 - P2重设计版本
final class EditorViewController: UIViewController {

    // MARK: - 依赖
    private var chapter: Chapter
    private let viewModel: EditorViewModel
    private var cancellables = Set<AnyCancellable>()
    private var autoSaveCancellable: AnyCancellable?
    private var hasUnsavedChanges = false

    // MARK: - UI 组件
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignToken.Color.backgroundPrimary
        return view
    }()

    private lazy var titleTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.font = DesignToken.Font.title2 // 标题22pt半粗
        tf.textColor = DesignToken.Color.textPrimary
        tf.placeholder = "章节标题"
        tf.borderStyle = .none
        tf.delegate = self
        return tf
    }()

    private lazy var saveStatusView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignToken.Color.backgroundTertiary
        view.layer.cornerRadius = DesignToken.Radius.full // 胶囊形状
        return view
    }()

    private lazy var saveStatusIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignToken.Color.success
        view.layer.cornerRadius = 3 // 状态点3pt
        return view
    }()

    private lazy var saveStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption1 // 状态字号12pt
        label.textColor = DesignToken.Color.textSecondary
        label.text = "已保存"
        return label
    }()

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = DesignToken.Font.body // 正文17pt
        tv.textColor = DesignToken.Color.textPrimary
        tv.backgroundColor = DesignToken.Color.backgroundPrimary
        tv.textContainerInset = UIEdgeInsets(top: DesignToken.Spacing.lg, left: DesignToken.Spacing.lg, bottom: DesignToken.Spacing.xl, right: DesignToken.Spacing.lg) // 文本内边距
        tv.delegate = self
        tv.autocapitalizationType = .sentences
        tv.alwaysBounceVertical = true
        return tv
    }()

    private lazy var bottomToolbar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignToken.Color.backgroundPrimary
        view.applyShadow(DesignToken.Shadow.sm) // 顶部小阴影
        return view
    }()

    private lazy var wordCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.footnote // 字数13pt
        label.textColor = DesignToken.Color.textSecondary
        label.text = "0 字"
        return label
    }()

    private lazy var cursorPositionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Font.caption2 // 光标位置11pt
        label.textColor = DesignToken.Color.textTertiary
        label.textAlignment = .right
        return label
    }()

    private let keyboardToolbar = UIToolbar()

    // MARK: - 初始化
    init(chapter: Chapter, viewModel: EditorViewModel) {
        self.chapter = chapter
        self.viewModel = viewModel
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
        bindViewModel()
        loadContent()
        setupAutoSave()
        setupKeyboardObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveContent()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundPrimary

        view.addSubview(headerView)
        headerView.addSubview(titleTextField)
        headerView.addSubview(saveStatusView)
        saveStatusView.addSubview(saveStatusIndicator)
        saveStatusView.addSubview(saveStatusLabel)

        view.addSubview(textView)
        view.addSubview(bottomToolbar)
        bottomToolbar.addSubview(wordCountLabel)
        bottomToolbar.addSubview(cursorPositionLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56), // 标题栏高度56pt

            titleTextField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: DesignToken.Spacing.lg), // 左边距16pt
            titleTextField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleTextField.trailingAnchor.constraint(equalTo: saveStatusView.leadingAnchor, constant: -DesignToken.Spacing.sm),

            saveStatusView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -DesignToken.Spacing.lg),
            saveStatusView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            saveStatusView.heightAnchor.constraint(equalToConstant: 28), // 状态胶囊高度28pt

            saveStatusIndicator.leadingAnchor.constraint(equalTo: saveStatusView.leadingAnchor, constant: DesignToken.Spacing.sm),
            saveStatusIndicator.centerYAnchor.constraint(equalTo: saveStatusView.centerYAnchor),
            saveStatusIndicator.widthAnchor.constraint(equalToConstant: 6), // 状态点6pt
            saveStatusIndicator.heightAnchor.constraint(equalToConstant: 6),

            saveStatusLabel.leadingAnchor.constraint(equalTo: saveStatusIndicator.trailingAnchor, constant: DesignToken.Spacing.xs),
            saveStatusLabel.trailingAnchor.constraint(equalTo: saveStatusView.trailingAnchor, constant: -DesignToken.Spacing.sm),
            saveStatusLabel.centerYAnchor.constraint(equalTo: saveStatusView.centerYAnchor),

            textView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor),

            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 44), // 底部工具栏高度44pt

            wordCountLabel.leadingAnchor.constraint(equalTo: bottomToolbar.leadingAnchor, constant: DesignToken.Spacing.lg),
            wordCountLabel.centerYAnchor.constraint(equalTo: bottomToolbar.centerYAnchor),

            cursorPositionLabel.trailingAnchor.constraint(equalTo: bottomToolbar.trailingAnchor, constant: -DesignToken.Spacing.lg),
            cursorPositionLabel.centerYAnchor.constraint(equalTo: bottomToolbar.centerYAnchor)
        ])

        // 分割线
        let headerSeparator = UIView()
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        headerSeparator.backgroundColor = DesignToken.Color.separator
        headerView.addSubview(headerSeparator)
        NSLayoutConstraint.activate([
            headerSeparator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerSeparator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 0.5) // 分割线0.5pt
        ])

        setupKeyboardToolbar()
    }

    private func setupNavigationBar() {
        title = "编辑"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = DesignToken.Color.primary
    }

    // MARK: - 键盘辅助工具栏
    private func setupKeyboardToolbar() {
        keyboardToolbar.items = [
            UIBarButtonItem(title: "“”", style: .plain, target: self, action: #selector(insertQuotes)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "……", style: .plain, target: self, action: #selector(insertEllipsis)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "——", style: .plain, target: self, action: #selector(insertDash)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "收起", style: .plain, target: self, action: #selector(dismissKeyboard))
        ]
        keyboardToolbar.tintColor = DesignToken.Color.primary
        keyboardToolbar.sizeToFit()
        textView.inputAccessoryView = keyboardToolbar
    }

    // MARK: - 数据绑定
    private func bindViewModel() {
        viewModel.$saveStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateSaveStatus(status)
            }
            .store(in: &cancellables)
    }

    private func updateSaveStatus(_ status: String) {
        saveStatusLabel.text = status
        switch status {
        case "已保存":
            saveStatusIndicator.backgroundColor = DesignToken.Color.success
            hasUnsavedChanges = false
        case "保存中...":
            saveStatusIndicator.backgroundColor = DesignToken.Color.warning
        case "编辑中...":
            saveStatusIndicator.backgroundColor = DesignToken.Color.primary
            hasUnsavedChanges = true
        case "保存失败":
            saveStatusIndicator.backgroundColor = DesignToken.Color.error
        default:
            saveStatusIndicator.backgroundColor = DesignToken.Color.textTertiary
        }
    }

    private func loadContent() {
        titleTextField.text = chapter.title
        textView.text = chapter.content
        updateWordCount()
    }

    // MARK: - 自动保存
    private func setupAutoSave() {
        autoSaveCancellable = NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification, object: textView)
            .debounce(for: .seconds(AppConfig.syncAutoSaveDebounce), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveContent()
            }
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
        textView.contentInset.bottom = keyboardHeight
        textView.verticalScrollIndicatorInsets.bottom = keyboardHeight
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        textView.contentInset.bottom = 0
        textView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: - 字数统计
    private func updateWordCount() {
        let count = textView.text.count
        wordCountLabel.text = "\(count) 字"
    }

    private func updateCursorPosition() {
        if let selectedRange = textView.selectedTextRange {
            let cursorPosition = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
            let line = getLineNumber(for: cursorPosition)
            cursorPositionLabel.text = "第\(line)行"
        }
    }

    private func getLineNumber(for position: Int) -> Int {
        let text = textView.text as NSString
        var lineCount = 1
        var charIndex = 0
        while charIndex < position && charIndex < text.length {
            let char = text.character(at: charIndex)
            if char == 10 { // 换行符
                lineCount += 1
            }
            charIndex += 1
        }
        return lineCount
    }

    // MARK: - 保存
    private func saveContent() {
        guard let title = titleTextField.text, !title.isEmpty else { return }
        let content = textView.text ?? ""
        viewModel.saveContent(chapterId: chapter.id, title: title, content: content)
        updateWordCount()
    }

    // MARK: - 动作
    @objc private func doneTapped() {
        saveContent()
        textView.resignFirstResponder()
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    // MARK: - 快捷输入
    @objc private func insertQuotes() {
        textView.insertText("“”")
        if let selectedRange = textView.selectedTextRange {
            let newPosition = textView.position(from: selectedRange.start, offset: -1)
            if let newPosition = newPosition {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        }
    }

    @objc private func insertEllipsis() {
        textView.insertText("……")
    }

    @objc private func insertDash() {
        textView.insertText("——")
    }
}

// MARK: - UITextViewDelegate
extension EditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateWordCount()
        updateCursorPosition()
        viewModel.saveStatus = "编辑中..."
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateCursorPosition()
    }
}

// MARK: - UITextFieldDelegate
extension EditorViewController: UITextFieldDelegate {
    func textFieldDidChangeSelection(_ textField: UITextField) {
        viewModel.saveStatus = "编辑中..."
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textView.becomeFirstResponder()
        return true
    }
}

// MARK: - 编辑器 ViewModel
final class EditorViewModel {
    @Published var saveStatus: String = "已保存"

    private let updateContentUseCase: UpdateChapterContentUseCase
    private let updateTitleUseCase: UpdateChapterTitleUseCase
    private var cancellables = Set<AnyCancellable>()

    init(updateContentUseCase: UpdateChapterContentUseCase,
         updateTitleUseCase: UpdateChapterTitleUseCase) {
        self.updateContentUseCase = updateContentUseCase
        self.updateTitleUseCase = updateTitleUseCase
    }

    func saveContent(chapterId: String, title: String, content: String) {
        saveStatus = "保存中..."

        updateTitleUseCase.execute(chapterId: chapterId, title: title)
            .flatMap { _ in
                self.updateContentUseCase.execute(chapterId: chapterId, content: content)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.saveStatus = "保存失败"
                }
            }, receiveValue: { [weak self] _ in
                self?.saveStatus = "已保存"
            })
            .store(in: &cancellables)
    }
}
