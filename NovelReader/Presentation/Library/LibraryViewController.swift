import UIKit
import Combine

/// 书架视图控制器 - 网格布局展示书籍，支持长按管理菜单和多选批量操作
final class LibraryViewController: UIViewController {

    private let bookRepository = AppContainer.shared.bookRepository
    private let chapterRepository = AppContainer.shared.chapterRepository
    private let readingProgressRepository = AppContainer.shared.readingProgressRepository
    private var cancellables = Set<AnyCancellable>()
    private var books: [Book] = []

    // 多选模式状态
    private var isEditingMode = false
    private var selectedBookIds: Set<String> = []

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
        cv.allowsMultipleSelection = true
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

    // 多选模式底部工具栏
    private lazy var editingToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isHidden = true
        toolbar.backgroundColor = DesignToken.Color.backgroundPrimary
        return toolbar
    }()

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupLongPressGesture()
        loadBooks()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 显式恢复导航栏显示和大标题模式，防止从阅读器返回后导航栏消失
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadBooks()
    }

    // MARK: - UI 搭建
    private func setupUI() {
        view.backgroundColor = DesignToken.Color.backgroundSecondary
        view.addSubview(collectionView)
        view.addSubview(emptyState)
        view.addSubview(editingToolbar)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyState.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignToken.Spacing.xl),
            emptyState.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignToken.Spacing.xl),

            editingToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editingToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editingToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            editingToolbar.heightAnchor.constraint(equalToConstant: 44) // 工具栏高度44pt
        ])
    }

    private func setupNavigationBar() {
        title = "书架"
        navigationController?.navigationBar.prefersLargeTitles = true
        updateNavigationBarItems()
    }

    private func updateNavigationBarItems() {
        if isEditingMode {
            // 多选模式：取消 + 全选
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "取消",
                style: .plain,
                target: self,
                action: #selector(cancelEditing)
            )
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: selectedBookIds.count == books.count ? "取消全选" : "全选",
                style: .plain,
                target: self,
                action: #selector(toggleSelectAll)
            )
        } else {
            // 正常模式：API刷新 + 管理 + 添加
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.clockwise.circle"),
                style: .plain,
                target: self,
                action: #selector(apiRefreshTapped)
            )
            navigationItem.leftBarButtonItem?.tintColor = DesignToken.Color.primary

            let manageButton = UIBarButtonItem(
                title: "管理",
                style: .plain,
                target: self,
                action: #selector(enterEditingMode)
            )

            let addButton = UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain,
                target: self,
                action: #selector(addBookTapped)
            )
            addButton.tintColor = DesignToken.Color.primary

            navigationItem.rightBarButtonItems = [addButton, manageButton]
        }
    }

    private func setupEditingToolbar() {
        let deleteItem = UIBarButtonItem(
            title: "删除",
            style: .plain,
            target: self,
            action: #selector(deleteSelectedBooks)
        )
        deleteItem.tintColor = DesignToken.Color.error

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let countItem = UIBarButtonItem(
            title: "已选 \(selectedBookIds.count) 本",
            style: .plain,
            target: nil,
            action: nil
        )

        editingToolbar.items = [deleteItem, flexibleSpace, countItem]
    }

    // MARK: - 长按手势
    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5 // 长按0.5秒触发管理菜单
        collectionView.addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        let book = books[indexPath.item]
        showBookManagementMenu(for: book, at: indexPath)
        FeedbackManager.shared.mediumImpact()
    }

    // MARK: - 书籍管理菜单
    private func showBookManagementMenu(for book: Book, at indexPath: IndexPath) {
        let alert = UIAlertController(title: book.title, message: "选择操作", preferredStyle: .actionSheet)

        // 打开书籍
        alert.addAction(UIAlertAction(title: "打开", style: .default) { [weak self] _ in
            self?.openBook(book)
        })

        // 重命名
        alert.addAction(UIAlertAction(title: "重命名", style: .default) { [weak self] _ in
            self?.renameBook(book)
        })

        // 查看详情
        alert.addAction(UIAlertAction(title: "书籍详情", style: .default) { [weak self] _ in
            self?.showBookDetail(book)
        })

        // 多选
        // 导出为 PDF
        alert.addAction(UIAlertAction(title: "导出为 PDF", style: .default) { [weak self] _ in
            self?.exportBookAsPDF(book, sourceView: alert.view, sourceRect: alert.view.bounds)
        })

        // 导出为 TXT
        alert.addAction(UIAlertAction(title: "导出为 TXT", style: .default) { [weak self] _ in
            self?.exportBookAsTXT(book, sourceView: alert.view, sourceRect: alert.view.bounds)
        })

        alert.addAction(UIAlertAction(title: "多选管理", style: .default) { [weak self] _ in
            self?.enterEditingMode()
            self?.selectedBookIds.insert(book.id)
            self?.collectionView.reloadData()
            self?.updateNavigationBarItems()
            self?.setupEditingToolbar()
        })

        // 删除
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.confirmDeleteBook(book)
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad 适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = collectionView
            popover.sourceRect = collectionView.cellForItem(at: indexPath)?.frame ?? CGRect.zero
        }

        present(alert, animated: true)
    }

    // MARK: - 多选模式
    @objc private func enterEditingMode() {
        isEditingMode = true
        selectedBookIds.removeAll()
        collectionView.reloadData()
        updateNavigationBarItems()
        setupEditingToolbar()
        UIView.animate(withDuration: 0.2) {
            self.editingToolbar.isHidden = false
        }
    }

    @objc private func cancelEditing() {
        isEditingMode = false
        selectedBookIds.removeAll()
        collectionView.reloadData()
        updateNavigationBarItems()
        UIView.animate(withDuration: 0.2) {
            self.editingToolbar.isHidden = true
        }
    }

    @objc private func toggleSelectAll() {
        if selectedBookIds.count == books.count {
            selectedBookIds.removeAll()
        } else {
            selectedBookIds = Set(books.map { $0.id })
        }
        collectionView.reloadData()
        updateNavigationBarItems()
        setupEditingToolbar()
    }

    @objc private func deleteSelectedBooks() {
        guard !selectedBookIds.isEmpty else {
            NRToast.shared.info("请先选择要删除的书籍")
            return
        }

        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除选中的 \(selectedBookIds.count) 本书籍吗？此操作不可恢复",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.performDeleteSelectedBooks()
        })
        present(alert, animated: true)
    }

    private func performDeleteSelectedBooks() {
        let idsToDelete = Array(selectedBookIds)
        var deletedCount = 0

        for id in idsToDelete {
            bookRepository.deleteBook(id: id)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                    deletedCount += 1
                    if deletedCount == idsToDelete.count {
                        NRToast.shared.success("已删除 \(deletedCount) 本书籍")
                        self.cancelEditing()
                        self.loadBooks()
                    }
                })
                .store(in: &cancellables)
        }
    }

    // MARK: - 单本书操作
    private func openBookFromLastPosition(_ book: Book) {
        // 先检查是否有保存的阅读进度
        readingProgressRepository.fetchProgress(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    // 读取进度失败，正常进入章节列表
                    self?.openBook(book)
                }
            }, receiveValue: { [weak self] progress in
                guard let self = self else { return }
                if let progress = progress, !progress.chapterId.isEmpty {
                    // 有阅读进度，加载章节并直接跳转到阅读器
                    self.chapterRepository.fetchChapters(bookId: book.id)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { [weak self] completion in
                            if case .failure = completion {
                                self?.openBook(book)
                            }
                        }, receiveValue: { [weak self] chapters in
                            guard let self = self else { return }
                            // 找到上次阅读章节的索引
                            if let chapterIndex = chapters.firstIndex(where: { $0.id == progress.chapterId }) {
                                // 直接跳转到阅读器，定位到上次阅读章节
                                let readerVC = AppContainer.shared.makeReaderViewController(
                                    book: book,
                                    chapters: chapters,
                                    startIndex: chapterIndex
                                )
                                self.navigationController?.pushViewController(readerVC, animated: true)
                            } else {
                                // 找不到对应章节，进入章节列表
                                self.openBook(book)
                            }
                        })
                        .store(in: &self.cancellables)
                } else {
                    // 无阅读进度，正常进入章节列表
                    self.openBook(book)
                }
            })
            .store(in: &cancellables)
    }

    private func openBook(_ book: Book) {
        let chapterListVC = AppContainer.shared.makeChapterListViewController(book: book)
        navigationController?.pushViewController(chapterListVC, animated: true)
    }

    private func renameBook(_ book: Book) {
        let alert = UIAlertController(title: "重命名书籍", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = book.title }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let newTitle = alert.textFields?.first?.text, !newTitle.isEmpty else { return }
            var updatedBook = book
            updatedBook.title = newTitle
            self?.bookRepository.updateBook(updatedBook)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                    NRToast.shared.success("重命名成功")
                    self?.loadBooks()
                })
                .store(in: &self!.cancellables)
        })
        present(alert, animated: true)
    }

    private func confirmDeleteBook(_ book: Book) {
        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除《\(book.title)》吗？此操作不可恢复",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.bookRepository.deleteBook(id: book.id)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                    NRToast.shared.success("删除成功")
                    self?.loadBooks()
                })
                .store(in: &self!.cancellables)
        })
        present(alert, animated: true)
    }

    // MARK: - PDF 导出

    /// 导出整本书为 PDF 并调起系统分享面板
    /// - Parameters:
    ///   - book: 要导出的书籍
    ///   - sourceView: iPad popover 来源视图
    ///   - sourceRect: iPad popover 来源矩形
    private func exportBookAsPDF(_ book: Book, sourceView: UIView?, sourceRect: CGRect) {
        // 显示导出 HUD
        let hud = showExportHUD(message: "正在准备章节...")

        // 先拉取章节列表
        chapterRepository.fetchChapters(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    hud.hide(animated: true)
                    NRToast.shared.show(message: "章节加载失败：\(error.localizedDescription)", type: .error)
                }
            }, receiveValue: { [weak self] chapters in
                guard let self = self else { return }
                guard !chapters.isEmpty else {
                    hud.hide(animated: true)
                    NRToast.shared.show(message: "书籍暂无章节，无法导出", type: .warning)
                    return
                }
                // 章节按 sortOrder 排序
                let sortedChapters = chapters.sorted(by: { $0.sortOrder < $1.sortOrder })

                // 在后台队列执行 PDF 绘制
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let exporter = PDFExporter()
                        let fileURL = try exporter.export(
                            book: book,
                            chapters: sortedChapters,
                            progress: { progressValue in
                                DispatchQueue.main.async {
                                    hud.updateProgress(progressValue,
                                                        message: String(format: "正在导出 PDF %.0f%%", progressValue * 100))
                                }
                            }
                        )

                        // 导出完成，回到主线程调起分享面板
                        DispatchQueue.main.async {
                            hud.hide(animated: true)
                            self.presentSharePanel(fileURL: fileURL,
                                                   fileName: fileURL.lastPathComponent,
                                                   sourceView: sourceView,
                                                   sourceRect: sourceRect)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            hud.hide(animated: true)
                            NRToast.shared.show(message: "PDF 导出失败：\(error.localizedDescription)", type: .error)
                        }
                    }
                }
            })
            .store(in: &self.cancellables)
    }

    /// 导出整本书为 TXT 纯文本文件
    private func exportBookAsTXT(_ book: Book, sourceView: UIView?, sourceRect: CGRect) {
        let hud = showExportHUD(message: "正在准备章节...")

        chapterRepository.fetchChapters(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    hud.hide(animated: true)
                    NRToast.shared.show(message: "章节加载失败：\(error.localizedDescription)", type: .error)
                }
            }, receiveValue: { [weak self] chapters in
                guard let self = self else { return }
                guard !chapters.isEmpty else {
                    hud.hide(animated: true)
                    NRToast.shared.show(message: "书籍暂无章节，无法导出", type: .warning)
                    return
                }
                let sortedChapters = chapters.sorted(by: { $0.sortOrder < $1.sortOrder })

                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        // 拼接 TXT 内容
                        var text = ""
                        text += "《\(book.title)》\n"
                        text += "作者：\(book.author.isEmpty ? "佚名" : book.author)\n"
                        text += String(repeating: "=", count: 30) + "\n\n"

                        for (index, chapter) in sortedChapters.enumerated() {
                            text += "\(chapter.title)\n\n"
                            text += "\(chapter.content)\n\n"
                            text += String(repeating: "-", count: 20) + "\n\n"
                            let progressValue = Float(index + 1) / Float(sortedChapters.count)
                            DispatchQueue.main.async {
                                hud.updateProgress(progressValue,
                                                    message: String(format: "正在导出 TXT %.0f%%", progressValue * 100))
                            }
                        }

                        // 写入临时文件（UTF-8 编码）
                        let fileName = "\(book.title)_导出.txt"
                            .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>"))
                            .joined()
                        let fileURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(fileName)
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try FileManager.default.removeItem(at: fileURL)
                        }
                        try text.write(to: fileURL, atomically: true, encoding: .utf8)

                        DispatchQueue.main.async {
                            hud.hide(animated: true)
                            self.presentSharePanel(fileURL: fileURL,
                                                   fileName: fileURL.lastPathComponent,
                                                   sourceView: sourceView,
                                                   sourceRect: sourceRect)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            hud.hide(animated: true)
                            NRToast.shared.show(message: "TXT 导出失败：\(error.localizedDescription)", type: .error)
                        }
                    }
                }
            })
            .store(in: &self.cancellables)
    }

    /// 调起系统分享面板分享文件
    private func presentSharePanel(fileURL: URL, fileName: String, sourceView: UIView?, sourceRect: CGRect) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        // 完成后清理临时文件
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.cleanupTempFile(at: fileURL)
        }

        // iPad 适配 popover
        if let popover = activityVC.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceRect
            } else {
                popover.sourceView = self.view
                popover.sourceRect = self.view.bounds
            }
        }
        activityVC.modalPresentationStyle = .formSheet
        present(activityVC, animated: true)
    }

    /// 清理临时文件
    private func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// 显示导出 HUD（带进度更新能力）
    private func showExportHUD(message: String) -> ExportProgressHUD {
        let hud = ExportProgressHUD()
        hud.show(in: view, message: message)
        return hud
    }

    private func showBookDetail(_ book: Book) {
        chapterRepository.fetchChapters(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] chapters in
                let totalWords = chapters.reduce(0) { $0 + $1.content.count }
                let message = """
                作者：\(book.author.isEmpty ? "未知" : book.author)
                章节数：\(chapters.count) 章
                总字数：\(totalWords) 字
                添加时间：\(Self.dateFormatter.string(from: book.createdAt))
                最后更新：\(Self.dateFormatter.string(from: book.updatedAt))
                """
                let alert = UIAlertController(title: book.title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
                self?.present(alert, animated: true)
            })
            .store(in: &cancellables)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

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
        let book = books[indexPath.item]
        cell.configure(with: book)
        cell.setSelected(selectedBookIds.contains(book.id), isEditing: isEditingMode)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.bounds.width - DesignToken.Spacing.lg * 2 - DesignToken.Spacing.md * 2) / 3 // 三列布局
        return CGSize(width: width, height: width * 1.5) // 封面比例3:2
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let book = books[indexPath.item]

        if isEditingMode {
            // 多选模式：切换选中状态
            if selectedBookIds.contains(book.id) {
                selectedBookIds.remove(book.id)
            } else {
                selectedBookIds.insert(book.id)
            }
            collectionView.reloadItems(at: [indexPath])
            updateNavigationBarItems()
            setupEditingToolbar()
        } else {
            // 正常模式：检查阅读进度，直接进入上次阅读位置
            collectionView.deselectItem(at: indexPath, animated: true)
            openBookFromLastPosition(book)
        }
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

    // 多选模式选中标记
    private let selectionIndicator: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DesignToken.Color.primary
        v.layer.cornerRadius = 12 // 选中标记圆角12pt，圆形
        v.isHidden = true
        return v
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
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
        contentView.addSubview(selectionIndicator)
        selectionIndicator.addSubview(checkmarkImageView)

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
            chapterCountLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // 选中标记 - 右上角
            selectionIndicator.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 8), // 选中标记距顶部8pt
            selectionIndicator.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -8), // 选中标记距右侧8pt
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24), // 选中标记尺寸24pt
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),

            checkmarkImageView.centerXAnchor.constraint(equalTo: selectionIndicator.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: selectionIndicator.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 14), // 勾选图标尺寸14pt
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    func configure(with book: Book) {
        titleLabel.text = book.title
        chapterCountLabel.text = book.author.isEmpty ? "未知作者" : book.author
    }

    func setSelected(_ selected: Bool, isEditing: Bool) {
        selectionIndicator.isHidden = !isEditing
        if isEditing {
            selectionIndicator.backgroundColor = selected ? DesignToken.Color.primary : UIColor.clear
            selectionIndicator.layer.borderWidth = selected ? 0 : 2 // 未选中时显示边框2pt
            selectionIndicator.layer.borderColor = UIColor.white.cgColor
            checkmarkImageView.isHidden = !selected
            // 选中时封面变暗
            coverView.alpha = selected ? 0.7 : 1.0
        } else {
            coverView.alpha = 1.0
        }
    }
}
