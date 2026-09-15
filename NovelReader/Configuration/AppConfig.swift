import Foundation
import UIKit

/// 全局应用配置
enum AppConfig {
    // MARK: - GitHub 配置

    /// GitHub OAuth 配置（如使用 Device Flow 则只需 clientID）
    static let githubClientID = "YOUR_CLIENT_ID"
    static let githubClientSecret = "YOUR_CLIENT_SECRET"

    /// GitHub API 基础地址
    static let githubAPIBaseURL = "https://api.github.com"

    /// 默认同步仓库名（专门保存小说文本的独立仓库）
    static let defaultRepoName = "MyNovels"

    // MARK: - 同步配置

    /// 编辑后自动保存防抖间隔
    static let syncAutoSaveDebounce: TimeInterval = 3.0
    /// 最大重试次数
    static let syncMaxRetryCount = 5
    /// 重试基础延迟（指数退避）
    static let syncRetryBaseDelay: TimeInterval = 1.0

    // MARK: - 数据库

    /// 数据库文件名
    static let databaseFileName = "novel_reader.db"

    // MARK: - 阅读器默认配置

    /// 默认字号
    static let defaultFontSize: CGFloat = 18
    /// 默认行间距
    static let defaultLineSpacing: CGFloat = 8
    /// 默认字体名
    static let defaultFontName = "Georgia"
}

// MARK: - 统一设计令牌（DesignToken）

/// 间距令牌（8pt 网格体系）
enum 间距令牌 {
    /// 4pt - 极小间距，图标与文字间
    static let 极小: CGFloat = 4
    /// 8pt - 小间距，紧凑元素间
    static let 小: CGFloat = 8
    /// 12pt - 中间距，卡片内元素
    static let 中: CGFloat = 12
    /// 16pt - 大间距，标准卡片内边距
    static let 大: CGFloat = 16
    /// 24pt - 超大间距，区块间分隔
    static let 超大: CGFloat = 24
    /// 32pt - 页面级顶部/底部间距
    static let 页面: CGFloat = 32
}

/// 圆角令牌
enum 圆角令牌 {
    /// 6pt - 小按钮、标签
    static let 小: CGFloat = 6
    /// 12pt - 卡片、按钮、输入框
    static let 中: CGFloat = 12
    /// 16pt - 大卡片、弹窗
    static let 大: CGFloat = 16
    /// 24pt - 底部弹窗、全屏面板
    static let 超大: CGFloat = 24
}

/// 字体令牌
enum 字体令牌 {
    /// 12pt - 辅助说明、时间戳
    static let 说明: UIFont = .systemFont(ofSize: 12, weight: .regular)
    /// 14pt - 正文小字、列表副标题
    static let 正文小: UIFont = .systemFont(ofSize: 14, weight: .regular)
    /// 16pt - 正文、按钮文字
    static let 正文: UIFont = .systemFont(ofSize: 16, weight: .regular)
    /// 17pt - 标准导航标题
    static let 标题: UIFont = .systemFont(ofSize: 17, weight: .semibold)
    /// 20pt - 页面大标题
    static let 大标题: UIFont = .systemFont(ofSize: 20, weight: .bold)
    /// 28pt - 欢迎页、数字展示
    static let 展示: UIFont = .systemFont(ofSize: 28, weight: .bold)
}

/// 颜色令牌（适配深色模式）
enum 颜色令牌 {
    /// 主色调 - 系统蓝（自动适配深色模式）
    static let 主色: UIColor = .systemBlue
    /// 成功色 - 系统绿
    static let 成功: UIColor = .systemGreen
    /// 警告色 - 系统橙
    static let 警告: UIColor = .systemOrange
    /// 危险色 - 系统红
    static let 危险: UIColor = .systemRed
    /// 主背景 - 系统背景（深色模式自动变黑）
    static let 背景: UIColor = .systemBackground
    /// 次背景 - 分组背景
    static let 次背景: UIColor = .secondarySystemBackground
    /// 卡片背景 - 三级分组背景
    static let 卡片背景: UIColor = .tertiarySystemBackground
    /// 主文字 - 标签色
    static let 主文字: UIColor = .label
    /// 次文字 - 次标签色
    static let 次文字: UIColor = .secondaryLabel
    /// 辅助文字 - 三级标签色
    static let 辅助文字: UIColor = .tertiaryLabel
    /// 分割线 - 透明灰
    static let 分割线: UIColor = .separator
    /// 边框 - 透明灰
    static let 边框: UIColor = .opaqueSeparator
}
