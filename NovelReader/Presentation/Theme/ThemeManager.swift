import UIKit
import Combine

// MARK: - 主题模式枚举
/// 应用主题模式
enum AppThemeMode: String, CaseIterable {
    /// 跟随系统
    case system = "system"
    /// 强制浅色
    case light = "light"
    /// 强制深色
    case dark = "dark"

    /// 显示名称
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - 主题管理器
/// 全局主题管理器，负责深色模式切换和主题持久化
final class ThemeManager {

    // MARK: - 单例
    static let shared = ThemeManager()

    // MARK: - 发布者
    /// 当前主题模式发布者
    @Published private(set) var currentMode: AppThemeMode = .system

    // MARK: - 私有属性
    private let userDefaultsKey = "app_theme_mode"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化
    private init() {
        loadSavedTheme()
        observeSystemThemeChanges()
    }

    // MARK: - 公共方法

    /// 切换主题模式
    /// - Parameter mode: 目标主题模式
    func setTheme(_ mode: AppThemeMode) {
        currentMode = mode
        saveTheme(mode)
        applyTheme(mode)
    }

    /// 切换到下一个主题模式（循环：system → light → dark → system）
    func toggleNextTheme() {
        let allCases = AppThemeMode.allCases
        if let currentIndex = allCases.firstIndex(of: currentMode) {
            let nextIndex = (currentIndex + 1) % allCases.count
            setTheme(allCases[nextIndex])
        }
    }

    /// 当前是否为深色模式
    var isDarkMode: Bool {
        switch currentMode {
        case .system:
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        case .dark:
            return true
        case .light:
            return false
        }
    }

    // MARK: - 私有方法

    /// 加载已保存的主题
    private func loadSavedTheme() {
        if let savedRaw = UserDefaults.standard.string(forKey: userDefaultsKey),
           let savedMode = AppThemeMode(rawValue: savedRaw) {
            currentMode = savedMode
            applyTheme(savedMode)
        } else {
            currentMode = .system
        }
    }

    /// 保存主题到 UserDefaults
    private func saveTheme(_ mode: AppThemeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: userDefaultsKey)
    }

    /// 应用主题到全局窗口
    private func applyTheme(_ mode: AppThemeMode) {
        let style: UIUserInterfaceStyle
        switch mode {
        case .system:
            style = .unspecified
        case .light:
            style = .light
        case .dark:
            style = .dark
        }

        // 应用到所有连接的场景窗口
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                UIView.animate(withDuration: DesignToken.Animation.normal) {
                    window.overrideUserInterfaceStyle = style
                }
            }
    }

    /// 监听系统主题变化（仅在跟随系统模式下生效）
    private func observeSystemThemeChanges() {
        // 监听应用进入前台，重新应用主题
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.currentMode == .system {
                    self.applyTheme(.system)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - UIViewController 主题便捷扩展
extension UIViewController {
    /// 当前主题管理器
    var themeManager: ThemeManager { ThemeManager.shared }

    /// 监听主题变化，在主题改变时执行回调
    /// - Parameter callback: 主题变化回调
    func observeThemeChanges(_ callback: @escaping (AppThemeMode) -> Void) {
        themeManager.$currentMode
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: callback)
            .store(in: &associatedCancellables)
    }

    /// 关联的 Cancellables 存储
    private var associatedCancellables: Set<AnyCancellable> {
        get {
            if let existing = objc_getAssociatedObject(self, &UIViewController.cancellablesKey) as? Set<AnyCancellable> {
                return existing
            }
            let newSet = Set<AnyCancellable>()
            objc_setAssociatedObject(self, &UIViewController.cancellablesKey, newSet, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return newSet
        }
        set {
            objc_setAssociatedObject(self, &UIViewController.cancellablesKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private static var cancellablesKey: UInt8 = 0
}
