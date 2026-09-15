import Foundation

/// 全局应用配置
enum AppConfig {
    /// GitHub OAuth 配置（如使用 Device Flow 则只需 clientID）
    static let githubClientID = "YOUR_CLIENT_ID"
    static let githubClientSecret = "YOUR_CLIENT_SECRET" // 不推荐硬编码，仅 PAT 模式可留空

    /// GitHub API 基础地址
    static let githubAPIBaseURL = "https://api.github.com"

    /// 默认同步仓库名（专门保存小说文本的独立仓库）
    static let defaultRepoName = "MyNovels"

    /// 同步相关
    static let syncAutoSaveDebounce: TimeInterval = 3.0  // 编辑后自动保存防抖
    static let syncMaxRetryCount = 5                       // 最大重试次数
    static let syncRetryBaseDelay: TimeInterval = 1.0     // 重试基础延迟（指数退避）

    /// 数据库
    static let databaseFileName = "novel_reader.db"

    /// 阅读器默认配置
    static let defaultFontSize: CGFloat = 18
    static let defaultLineSpacing: CGFloat = 8
    static let defaultFontName = "Georgia"
}
