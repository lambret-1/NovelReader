import UIKit

// MARK: - 设计令牌（Design Tokens）
/// 全局统一设计令牌，所有 UI 元素必须引用此处定义，禁止魔法数字
enum DesignToken {

    // MARK: - 颜色令牌

    /// 颜色系统 - 琥珀色系主色调，契合阅读氛围
    enum Color {
        /// 主色 - 琥珀色（按钮/强调/链接）
        static let primary = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)  // 深色模式稍亮
                : UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)  // #F59E0B
        }
        /// 主色按下态
        static let primaryPressed = UIColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 1.0) // #D97706
        /// 主色浅背景
        static let primaryBackground = UIColor(red: 0.998, green: 0.953, blue: 0.78, alpha: 1.0) // #FEF3C7

        /// 成功色
        static let success = UIColor.systemGreen
        /// 警告色
        static let warning = UIColor.systemOrange
        /// 错误/危险色
        static let error = UIColor.systemRed
        /// 信息色
        static let info = UIColor.systemBlue

        // MARK: 文本颜色
        /// 主文本
        static let textPrimary = UIColor.label
        /// 次文本
        static let textSecondary = UIColor.secondaryLabel
        /// 辅助文本
        static let textTertiary = UIColor.tertiaryLabel
        /// 反色文本（深色背景上的白字）
        static let textInverse = UIColor.white

        // MARK: 背景颜色
        /// 主背景
        static let backgroundPrimary = UIColor.systemBackground
        /// 次背景（分组背景）
        static let backgroundSecondary = UIColor.secondarySystemBackground
        /// 三级背景（卡片背景）
        static let backgroundTertiary = UIColor.tertiarySystemBackground
        /// 分组背景（UITableView 用）
        static let backgroundGrouped = UIColor.systemGroupedBackground

        // MARK: 边框/分割线
        /// 分割线
        static let separator = UIColor.separator
        /// 边框
        static let border = UIColor.opaqueSeparator
        /// 细边框（0.5pt）
        static let borderThin = UIColor.separator.withAlphaComponent(0.5)
    }

    // MARK: - 字体令牌

    /// 字体系统 - 基于 SF Pro，支持动态字体
    enum Font {
        /// 34pt Bold - 页面大标题
        static let largeTitle = UIFont.preferredFont(forTextStyle: .largeTitle).bold()
        /// 28pt Bold - 模态页标题
        static let title1 = UIFont.preferredFont(forTextStyle: .title1).bold()
        /// 22pt Semibold - 卡片标题
        static let title2 = UIFont.preferredFont(forTextStyle: .title2).semibold()
        /// 20pt Semibold - 小节标题
        static let title3 = UIFont.preferredFont(forTextStyle: .title3).semibold()
        /// 17pt Semibold - 列表主标题/按钮文字
        static let headline = UIFont.preferredFont(forTextStyle: .headline)
        /// 17pt Regular - 正文
        static let body = UIFont.preferredFont(forTextStyle: .body)
        /// 16pt Regular - 辅助正文
        static let callout = UIFont.preferredFont(forTextStyle: .callout)
        /// 15pt Regular - 列表副标题
        static let subhead = UIFont.preferredFont(forTextStyle: .subheadline)
        /// 13pt Regular - 注释/时间戳
        static let footnote = UIFont.preferredFont(forTextStyle: .footnote)
        /// 12pt Regular - 徽章/标签
        static let caption1 = UIFont.preferredFont(forTextStyle: .caption1)
        /// 11pt Regular - 极小标注
        static let caption2 = UIFont.preferredFont(forTextStyle: .caption2)
    }

    // MARK: - 间距令牌（8pt 网格体系）

    enum Spacing {
        /// 4pt - 极小间距，图标与文字间
        static let xs: CGFloat = 4
        /// 8pt - 小间距，紧凑元素间
        static let sm: CGFloat = 8
        /// 12pt - 中间距，卡片内元素
        static let md: CGFloat = 12
        /// 16pt - 大间距，标准卡片内边距/页面边距
        static let lg: CGFloat = 16
        /// 24pt - 超大间距，区块间分隔
        static let xl: CGFloat = 24
        /// 32pt - 页面级顶部/底部间距
        static let xxl: CGFloat = 32
        /// 48pt - 垂直大间距
        static let xxxl: CGFloat = 48
    }

    // MARK: - 圆角令牌

    enum Radius {
        /// 6pt - 小标签、小按钮
        static let sm: CGFloat = 6
        /// 8pt - 输入框、小卡片
        static let md: CGFloat = 8
        /// 12pt - 按钮、卡片
        static let lg: CGFloat = 12
        /// 16pt - 大卡片、弹窗
        static let xl: CGFloat = 16
        /// 24pt - 底部弹窗、全屏面板
        static let xxl: CGFloat = 24
        /// 999pt - 圆形/胶囊
        static let full: CGFloat = 999
    }

    // MARK: - 阴影令牌

    enum Shadow {
        /// 小阴影 - 卡片悬浮
        static let sm = ShadowConfig(color: UIColor.black.cgColor, opacity: 0.05, offset: CGSize(width: 0, height: 1), radius: 2)
        /// 中阴影 - 弹窗
        static let md = ShadowConfig(color: UIColor.black.cgColor, opacity: 0.08, offset: CGSize(width: 0, height: 4), radius: 12)
        /// 大阴影 - 底部Sheet
        static let lg = ShadowConfig(color: UIColor.black.cgColor, opacity: 0.12, offset: CGSize(width: 0, height: 8), radius: 24)
    }

    /// 阴影配置结构体
    struct ShadowConfig {
        let color: CGColor
        let opacity: Float
        let offset: CGSize
        let radius: CGFloat
    }

    // MARK: - 尺寸令牌

    enum Size {
        /// 按钮最小高度（符合 HIG 触控目标）
        static let buttonHeight: CGFloat = 48
        /// 输入框高度
        static let inputHeight: CGFloat = 44
        /// 列表单元格高度
        static let cellHeight: CGFloat = 56
        /// 图标标准尺寸
        static let iconStandard: CGFloat = 24
        /// 图标大尺寸
        static let iconLarge: CGFloat = 32
        /// 头像尺寸
        static let avatar: CGFloat = 48
        /// 书籍封面宽高比（3:4）
        static let bookCoverRatio: CGFloat = 3.0 / 4.0
    }

    // MARK: - 动画时长

    enum Animation {
        /// 0.15秒 - 快速反馈（按钮按下）
        static let fast: TimeInterval = 0.15
        /// 0.25秒 - 标准动画（转场/弹窗）
        static let normal: TimeInterval = 0.25
        /// 0.4秒 - 慢动画（底部Sheet）
        static let slow: TimeInterval = 0.4
        /// 0.6秒 - 弹性动画
        static let spring: TimeInterval = 0.6
    }
}

// MARK: - UIFont 扩展（粗体/半粗体便捷方法）
extension UIFont {
    /// 返回粗体版本
    func bold() -> UIFont {
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor, size: pointSize)
    }
    /// 返回半粗体版本
    func semibold() -> UIFont {
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitSemibold) ?? fontDescriptor, size: pointSize)
    }
}

// MARK: - UIView 阴影便捷方法
extension UIView {
    /// 应用指定阴影配置
    func applyShadow(_ config: DesignToken.ShadowConfig) {
        layer.shadowColor = config.color
        layer.shadowOpacity = config.opacity
        layer.shadowOffset = config.offset
        layer.shadowRadius = config.radius
        layer.masksToBounds = false
    }
}
