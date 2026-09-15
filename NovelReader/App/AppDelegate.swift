import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

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

        AppLogger.info("应用启动完成")
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
