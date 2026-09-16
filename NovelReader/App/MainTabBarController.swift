import UIKit

/// 主标签栏控制器 - 书架/我的
final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }

    private func setupTabBar() {
        tabBar.tintColor = DesignToken.Color.primary // 选中色琥珀色
        tabBar.unselectedItemTintColor = DesignToken.Color.textSecondary // 未选中色灰色
        tabBar.backgroundColor = DesignToken.Color.backgroundPrimary
        tabBar.isTranslucent = true
    }

    private func setupViewControllers() {
        // 书架
        let libraryVC = AppContainer.shared.makeLibraryViewController()
        let libraryNav = BaseNavigationController(rootViewController: libraryVC)
        libraryNav.tabBarItem = UITabBarItem(
            title: "书架",
            image: UIImage(systemName: "books.vertical"),
            selectedImage: UIImage(systemName: "books.vertical.fill")
        )

        // 我的（设置）
        let settingsVC = AppContainer.shared.makeSettingsViewController()
        let settingsNav = BaseNavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "我的",
            image: UIImage(systemName: "person.circle"),
            selectedImage: UIImage(systemName: "person.circle.fill")
        )

        viewControllers = [libraryNav, settingsNav]
        selectedIndex = 0 // 默认选中书架
    }
}
