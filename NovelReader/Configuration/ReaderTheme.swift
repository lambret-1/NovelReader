import UIKit

/// 阅读主题配置
struct ReaderTheme: Equatable {
    let id: String
    let name: String
    let backgroundColor: UIColor
    let textColor: UIColor
    let tintColor: UIColor
    let statusBarStyle: UIStatusBarStyle

    /// 内置主题列表
    static let all: [ReaderTheme] = [.day, .night, .eyeCare, .sepia]

    /// 日间主题 - 浅色背景深色文字，深色模式下自动切换为深灰背景
    static let day = ReaderTheme(
        id: "day",
        name: "日间",
        backgroundColor: UIColor { traitCollection in
            // 浅色模式：米白背景；深色模式：跟随系统深灰
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                : UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
        },
        textColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0)
                : UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        },
        tintColor: .systemBlue,
        statusBarStyle: .default
    )

    /// 夜间主题 - 深色背景浅色文字
    static let night = ReaderTheme(
        id: "night",
        name: "夜间",
        backgroundColor: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
        textColor: UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.0),
        tintColor: UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),
        statusBarStyle: .lightContent
    )

    /// 护眼主题 - 绿色背景，深色模式下自动变暗绿
    static let eyeCare = ReaderTheme(
        id: "eye_care",
        name: "护眼",
        backgroundColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.14, blue: 0.10, alpha: 1.0)
                : UIColor(red: 0.76, green: 0.84, blue: 0.68, alpha: 1.0)
        },
        textColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.80, green: 0.85, blue: 0.75, alpha: 1.0)
                : UIColor(red: 0.18, green: 0.25, blue: 0.15, alpha: 1.0)
        },
        tintColor: UIColor(red: 0.30, green: 0.50, blue: 0.25, alpha: 1.0),
        statusBarStyle: .default
    )

    /// 羊皮纸主题 - 暖黄色背景，深色模式下自动变暗棕
    static let sepia = ReaderTheme(
        id: "sepia",
        name: "羊皮纸",
        backgroundColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1.0)
                : UIColor(red: 0.92, green: 0.87, blue: 0.78, alpha: 1.0)
        },
        textColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1.0)
                : UIColor(red: 0.25, green: 0.20, blue: 0.15, alpha: 1.0)
        },
        tintColor: UIColor(red: 0.55, green: 0.40, blue: 0.20, alpha: 1.0),
        statusBarStyle: .default
    )
}

/// 阅读器配置（用户可调）
struct ReaderConfig: Equatable {
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    var fontName: String
    var themeID: String
    var pageTransition: PageTransition

    enum PageTransition: String, CaseIterable {
        case pageCurl = "仿真翻页"
        case scroll = "左右滑动"
        case vertical = "上下滚动"
    }

    static let `default` = ReaderConfig(
        fontSize: AppConfig.defaultFontSize,
        lineSpacing: AppConfig.defaultLineSpacing,
        fontName: AppConfig.defaultFontName,
        themeID: ReaderTheme.day.id,
        pageTransition: .scroll
    )

    var currentTheme: ReaderTheme {
        ReaderTheme.all.first { $0.id == themeID } ?? .day
    }
}
