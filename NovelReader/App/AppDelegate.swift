import UIKit
import Combine

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var cancellables = Set<AnyCancellable>()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化数据库
        _ = DatabaseManager.shared

        // 启动网络监控
        NetworkMonitor.shared.startMonitoring()

        // 初始化依赖注入容器
        let container = AppContainer.shared

        // 启动时自动从 Keychain 加载已保存的 Token，避免每次同步都重新输入
        if let savedToken = container.authService.loadSavedToken() {
            container.apiClient.setToken(savedToken)
            GitHubAPIClient.shared.setToken(savedToken) // 确保单例也有 Token
            AppLogger.info("启动时已自动加载已保存的 GitHub Token")
        }

        // 启动后延迟检查更新，确保首屏先渲染完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in // 延迟2秒，等待SceneDelegate设置window
            self?.checkForUpdates()
        }

        AppLogger.info("应用启动完成")
        return true
    }

    // MARK: - 检查更新

    /// 检查 GitHub 最新 Release，有更新则弹窗提示
    private func checkForUpdates() {
        let container = AppContainer.shared
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

        AppLogger.info("开始检查更新，当前版本: \(currentVersion)")

        container.updateService.checkForUpdates()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("检查更新失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] latestRelease in
                guard let self = self else { return }

                AppLogger.info("检查更新完成，最新版本: \(latestRelease.tagName)")

                if container.updateService.hasUpdate(latest: latestRelease, currentVersion: currentVersion) {
                    AppLogger.info("发现新版本 \(latestRelease.tagName)，准备弹出更新提示")
                    self.presentUpdateAlert(release: latestRelease)
                } else {
                    AppLogger.info("当前已是最新版本 \(currentVersion)")
                }
            })
            .store(in: &cancellables)
    }

    /// 获取当前最顶层的视图控制器，用于弹出更新窗口
    /// - Returns: 当前可见的视图控制器
    private func topMostViewController() -> UIViewController? {
        // 从连接的场景中获取当前活动的 windowScene
        let activeScenes = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }

        guard let windowScene = activeScenes.first else {
            AppLogger.error("无法获取活动的 windowScene")
            return nil
        }

        // 获取 keyWindow
        guard let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            AppLogger.error("无法获取 keyWindow")
            return nil
        }

        // 从 rootViewController 开始查找最顶层的 presentedViewController
        var topController = keyWindow.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }

        return topController
    }

    /// 弹出更新提示窗口
    /// - Parameter release: 最新版本信息
    private func presentUpdateAlert(release: LatestRelease) {
        guard let rootVC = topMostViewController() else {
            AppLogger.error("无法获取顶层视图控制器，更新提示弹出失败")
            return
        }

        let alert = UIAlertController(
            title: "发现新版本 \(release.tagName)",
            message: release.body ?? "有新的更新可用",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "稍后提醒", style: .cancel))
        alert.addAction(UIAlertAction(title: "立即更新", style: .default) { [weak self] _ in
            self?.downloadAndShareIPA(release: release)
        })
        rootVC.present(alert, animated: true)
        AppLogger.info("更新提示窗口已弹出")
    }

    /// 下载 IPA 并弹出分享面板
    /// - Parameter release: 最新版本信息
    private func downloadAndShareIPA(release: LatestRelease) {
        guard let rootVC = topMostViewController() else { return }
        guard let ipaUrl = AppContainer.shared.updateService.ipaDownloadUrl(from: release) else {
            NRToast.shared.error("未找到 IPA 下载链接")
            return
        }

        // 显示下载进度 HUD
        let hud = UIAlertController(title: "正在下载...", message: "准备中...", preferredStyle: .alert)
        rootVC.present(hud, animated: true)

        AppLogger.info("开始下载 IPA: \(ipaUrl.lastPathComponent)")

        AppContainer.shared.updateService.downloadIPA(url: ipaUrl) { progress in
            DispatchQueue.main.async {
                hud.title = "正在下载... \(Int(progress * 100))%"
                hud.message = "下载中，请稍候"
            }
        }
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
            hud.dismiss(animated: true) {
                if case .failure(let error) = completion {
                    AppLogger.error("IPA 下载失败: \(error.localizedDescription)")
                    NRToast.shared.error("下载失败: \(error.localizedDescription)")
                }
            }
        }, receiveValue: { [weak self] localURL in
            hud.dismiss(animated: true) {
                AppLogger.info("IPA 下载完成: \(localURL.path)")
                self?.presentShareSheet(for: localURL, title: release.tagName)
            }
        })
        .store(in: &cancellables)
    }

    /// 弹出分享面板
    /// - Parameters:
    ///   - fileURL: 本地文件 URL
    ///   - title: 分享标题
    private func presentShareSheet(for fileURL: URL, title: String) {
        guard let rootVC = topMostViewController() else { return }

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        activityVC.title = "NovelReader \(title)"
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: rootVC.view.bounds.midX,
            y: rootVC.view.bounds.midY,
            width: 0,
            height: 0
        )
        activityVC.completionWithItemsHandler = { [weak self] activityType, completed, _, error in
            if completed {
                NRToast.shared.success("分享成功")
            } else if let error = error {
                NRToast.shared.error("分享失败: \(error.localizedDescription)")
            }
            // 分享完成后清理临时文件
            try? FileManager.default.removeItem(at: fileURL)
            AppLogger.info("分享面板已关闭，临时文件已清理")
        }
        rootVC.present(activityVC, animated: true)
        FeedbackManager.shared.lightImpact()
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
