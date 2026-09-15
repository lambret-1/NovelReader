import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

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
            AppLogger.info("启动时已自动加载已保存的 GitHub Token")
        }

        // 启动后延迟检查更新，避免影响启动速度
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in // 延迟2秒检查更新，确保首屏先渲染
            self?.checkForUpdates()
        }

        AppLogger.info("应用启动完成")
        return true
    }

    // MARK: - 检查更新

    /// 检查 GitHub 最新 Release，有更新则弹窗提示
    private func checkForUpdates() {
        let container = AppContainer.shared

        container.updateService.checkForUpdates()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("检查更新失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] latestRelease in
                guard let self = self else { return }

                // 获取当前应用版本
                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

                // 判断是否有新版本
                if container.updateService.hasUpdate(latest: latestRelease, currentVersion: currentVersion) {
                    AppLogger.info("发现新版本: \(latestRelease.tagName)，当前版本: \(currentVersion)")
                    self.presentUpdateAlert(release: latestRelease)
                } else {
                    AppLogger.info("当前已是最新版本: \(currentVersion)")
                }
            })
            .store(in: &cancellables)
    }

    /// 弹出更新提示窗口
    /// - Parameter release: 最新版本信息
    private func presentUpdateAlert(release: LatestRelease) {
        guard let rootVC = window?.rootViewController else { return }

        // 避免重复弹出
        if rootVC.presentedViewController is UpdateViewController {
            return
        }

        let updateVC = AppContainer.shared.makeUpdateViewController(release: release)
        rootVC.present(updateVC, animated: true)
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()
}
