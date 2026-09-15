import UIKit
import Combine

/// 更新提示弹窗 - 显示新版本信息，提供稍后提醒和立即更新选项
final class UpdateViewController: UIViewController {

    // MARK: - UI 组件

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppConfig.Color.backgroundSecondary
        view.layer.cornerRadius = 16 // 弹窗圆角16pt，生产级标准，视觉柔和
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "arrow.down.circle.fill")
        imageView.tintColor = AppConfig.Color.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "发现新版本"
        label.font = AppConfig.Font.title2
        label.textColor = AppConfig.Color.label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let versionLabel: UILabel = {
        let label = UILabel()
        label.font = AppConfig.Font.headline
        label.textColor = AppConfig.Color.accent
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let releaseNotesTextView: UITextView = {
        let textView = UITextView()
        textView.font = AppConfig.Font.body
        textView.textColor = AppConfig.Color.secondaryLabel
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8) // 内边距8pt，阅读舒适
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private let updateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("立即更新", for: .normal)
        button.titleLabel?.font = AppConfig.Font.headline
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = AppConfig.Color.accent
        button.layer.cornerRadius = 12 // 按钮圆角12pt，触控友好
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let laterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("稍后提醒", for: .normal)
        button.titleLabel?.font = AppConfig.Font.body
        button.setTitleColor(AppConfig.Color.secondaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.isHidden = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "正在下载..."
        label.font = AppConfig.Font.caption
        label.textColor = AppConfig.Color.secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - 属性

    private let release: LatestRelease
    private let updateService: UpdateCheckService
    private var cancellables = Set<AnyCancellable>()
    private var downloadedFileURL: URL?

    // MARK: - 初始化

    /// 初始化更新弹窗
    /// - Parameters:
    ///   - release: 最新版本信息
    ///   - updateService: 更新检查服务
    init(release: LatestRelease, updateService: UpdateCheckService) {
        self.release = release
        self.updateService = updateService
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        configureContent()
    }

    // MARK: - UI 搭建

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5) // 半透明遮罩0.5，突出弹窗

        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(versionLabel)
        containerView.addSubview(releaseNotesTextView)
        containerView.addSubview(updateButton)
        containerView.addSubview(laterButton)
        containerView.addSubview(progressView)
        containerView.addSubview(progressLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85), // 弹窗宽度85%屏宽，适配各尺寸
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.7), // 最大高度70%屏高

            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppConfig.Spacing.xl),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48), // 图标尺寸48pt，醒目且不占过多空间
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: AppConfig.Spacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),

            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppConfig.Spacing.xs),
            versionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            versionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),

            releaseNotesTextView.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: AppConfig.Spacing.md),
            releaseNotesTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            releaseNotesTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),
            releaseNotesTextView.heightAnchor.constraint(equalToConstant: 120), // 发布说明高度120pt，可滚动查看更多

            progressView.topAnchor.constraint(equalTo: releaseNotesTextView.bottomAnchor, constant: AppConfig.Spacing.md),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),

            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: AppConfig.Spacing.xs),
            progressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),

            updateButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: AppConfig.Spacing.lg),
            updateButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            updateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),
            updateButton.heightAnchor.constraint(equalToConstant: 48), // 按钮高度48pt，符合触控目标最小尺寸

            laterButton.topAnchor.constraint(equalTo: updateButton.bottomAnchor, constant: AppConfig.Spacing.sm),
            laterButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppConfig.Spacing.lg),
            laterButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppConfig.Spacing.lg),
            laterButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -AppConfig.Spacing.lg),
            laterButton.heightAnchor.constraint(equalToConstant: 40), // 次要按钮高度40pt，视觉层级低于主按钮
        ])
    }

    private func setupActions() {
        updateButton.addTarget(self, action: #selector(updateButtonTapped), for: .touchUpInside)
        laterButton.addTarget(self, action: #selector(laterButtonTapped), for: .touchUpInside)
    }

    private func configureContent() {
        versionLabel.text = release.tagName
        releaseNotesTextView.text = release.body ?? "暂无更新说明"
    }

    // MARK: - 事件处理

    @objc private func updateButtonTapped() {
        guard let downloadUrl = updateService.ipaDownloadUrl(from: release) else {
            showAlert(title: "更新失败", message: "未找到 IPA 下载链接")
            return
        }

        // 显示下载进度
        progressView.isHidden = false
        progressLabel.isHidden = false
        updateButton.isEnabled = false
        updateButton.alpha = 0.5 // 禁用时透明度0.5，视觉反馈明确
        laterButton.isEnabled = false

        updateService.downloadIPA(url: downloadUrl) { [weak self] progress in
            self?.progressView.progress = Float(progress)
            self?.progressLabel.text = String(format: "正在下载... %.0f%%", progress * 100)
        }
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            if case .failure(let error) = completion {
                self?.showAlert(title: "下载失败", message: error.localizedDescription)
                self?.updateButton.isEnabled = true
                self?.updateButton.alpha = 1.0
                self?.laterButton.isEnabled = true
                self?.progressView.isHidden = true
                self?.progressLabel.isHidden = true
            }
        }, receiveValue: { [weak self] fileURL in
            self?.downloadedFileURL = fileURL
            self?.presentShareSheet(fileURL: fileURL)
        })
        .store(in: &cancellables)
    }

    @objc private func laterButtonTapped() {
        dismiss(animated: true)
    }

    // MARK: - 分享功能

    /// 弹出 iOS 系统分享面板，用于安装 IPA
    /// - Parameter fileURL: IPA 文件本地路径
    private func presentShareSheet(fileURL: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.dismiss(animated: true)
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = updateButton
            popover.sourceRect = updateButton.bounds
        }

        present(activityVC, animated: true)
    }

    // MARK: - 工具方法

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
