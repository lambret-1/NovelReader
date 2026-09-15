import UIKit
import Combine

/// 编辑器视图控制器
final class EditorViewController: UIViewController {
    private var chapter: Chapter
    private let viewModel: EditorViewModel
    private var cancellables = Set<AnyCancellable>()
    private var autoSaveCancellable: AnyCancellable?

    // MARK: - UI 组件
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = .systemFont(ofSize: 17)
        tv.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        tv.delegate = self
        tv.autocapitalizationType = .sentences
        return tv
    }()

    private lazy var saveStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.text = "已保存"
        return label
    }()

    private lazy var wordCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private lazy var titleTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.font = .systemFont(ofSize: 20, weight: .bold)
        tf.placeholder = "章节标题"
        tf.borderStyle = .none
        return tf
    }()

    private let toolbar = UIToolbar()

    // MARK: - 初始化
    init(chapter: Chapter, viewModel: EditorViewModel) {
        self.chapter = chapter
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
        loadContent()
        setupAutoSave()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开时强制保存
        saveContent()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "编辑"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )

        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleTextField)
        headerView.addSubview(saveStatusLabel)

        view.addSubview(headerView)
        view.addSubview(textView)
        view.addSubview(wordCountLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            titleTextField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleTextField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleTextField.trailingAnchor.constraint(equalTo: saveStatusLabel.leadingAnchor, constant: -8),

            saveStatusLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            saveStatusLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            textView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: wordCountLabel.topAnchor),

            wordCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wordCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            wordCountLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            wordCountLabel.heightAnchor.constraint(equalToConstant: 20)
        ])

        // 键盘工具栏
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "收起键盘", style: .plain, target: self, action: #selector(dismissKeyboard))
        ]
        toolbar.sizeToFit()
        textView.inputAccessoryView = toolbar
    }

    private func bindViewModel() {
        viewModel.$saveStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.saveStatusLabel.text = status
            }
            .store(in: &cancellables)
    }

    private func loadContent() {
        titleTextField.text = chapter.title
        textView.text = chapter.content
        updateWordCount()
    }

    private func setupAutoSave() {
        // 监听文本变化，防抖 3 秒自动保存
        autoSaveCancellable = NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification, object: textView)
            .debounce(for: .seconds(AppConfig.syncAutoSaveDebounce), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveContent()
            }
    }

    private func updateWordCount() {
        let count = textView.text.count
        wordCountLabel.text = "\(count) 字"
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
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() {
        textView.resignFirstResponder()
    }
}

extension EditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateWordCount()
        viewModel.saveStatus = "编辑中..."
    }
}

/// 编辑器 ViewModel
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

        // 同时更新标题和内容
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
