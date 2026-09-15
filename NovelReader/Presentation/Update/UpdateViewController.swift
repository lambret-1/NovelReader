import UIKit
import Combine

/// 更新提示弹窗
final class UpdateViewController: UIViewController {

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16 // 弹窗圆角16pt，视觉柔和
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "arrow.down.circle.fill")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "发现新版本"
        label.font = .systemFont(ofSize: 20, weight: .bold) // 标题字号20pt加粗，层级清晰
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let versionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold) // 版本号字号16pt半粗，突出显示
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let releaseNotesTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 14) // 正文字号14pt，阅读舒适
        textView.textColor = .secondaryLabel
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private let updateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("立即更新", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12 // 按钮圆角12pt，触控友好
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let laterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("稍后提醒", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.setTitleColor(.secondaryLabel, for: .normal)
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
        label.font = .systemFont(ofSize: 12) // 辅助文字字号12pt，不抢主视觉
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let release: LatestRelease
    private let updateService: UpdateCheckService
    private var cancellables = Set<AnyCancellable>()

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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        versionLabel.text = release.tagName
        releaseNotesTextView.text = release.body ?? "暂无更新说明"
    }

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
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85), // 弹窗宽度85%屏宽

            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24), // 顶部间距24pt
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48), // 图标尺寸48pt
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12), // 间距12pt
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4), // 间距4pt
            versionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            versionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            releaseNotesTextView.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 12),
            releaseNotesTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            releaseNotesTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            releaseNotesTextView.heightAnchor.constraint(equalToConstant: 120), // 发布说明高度120pt

            progressView.topAnchor.constraint(equalTo: releaseNotesTextView.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            progressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            updateButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 16),
            updateButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            updateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            updateButton.heightAnchor.constraint(equalToConstant: 48), // 按钮高度48pt，符合触控目标

            laterButton.topAnchor.constraint(equalTo: updateButton.bottomAnchor, constant: 8), // 间距8pt
            laterButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            laterButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            laterButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16), // 底部间距16pt
            laterButton.heightAnchor.constraint(equalToConstant: 40), // 次要按钮高度40pt
        ])
    }

    private func setupActions() {
        updateButton.addTarget(self, action: #selector(updateButtonTapped), for: .touchUpInside)
        laterButton.addTarget(self, action: #selector(laterButtonTapped), for: .touchUpInside)
    }

    @objc private func updateButtonTapped() {
        guard let downloadUrl = updateService.ipaDownloadUrl(from: release) else {
            showAlert(title: "更新失败", message: "未找到 IPA 下载链接")
            return
        }

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
            self?.presentShareSheet(fileURL: fileURL)
        })
        .store(in: &cancellables)
    }

    @objc private func laterButtonTapped() {
        dismiss(animated: true)
    }

    private func presentShareSheet(fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.dismiss(animated: true)
        }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = updateButton
            popover.sourceRect = updateButton.bounds
        }
        present(activityVC, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
