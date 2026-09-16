import Foundation
import UIKit

/// 阅读设置持久化管理器
final class ReaderSettingsManager {
    static let shared = ReaderSettingsManager()

    private let defaults = UserDefaults.standard
    private let keys = (
        fontSize: "reader_font_size",
        lineSpacing: "reader_line_spacing",
        pageMargin: "reader_page_margin",
        themeID: "reader_theme_id",
        pageTransition: "reader_page_transition"
    )

    private init() {}

    /// 保存阅读配置
    func saveConfig(_ config: ReaderConfig) {
        defaults.set(Double(config.fontSize), forKey: keys.fontSize)
        defaults.set(Double(config.lineSpacing), forKey: keys.lineSpacing)
        defaults.set(Double(config.pageMargin), forKey: keys.pageMargin)
        defaults.set(config.themeID, forKey: keys.themeID)
        defaults.set(config.pageTransition.rawValue, forKey: keys.pageTransition)
    }

    /// 加载阅读配置
    func loadConfig() -> ReaderConfig {
        var config = ReaderConfig.default

        if defaults.object(forKey: keys.fontSize) != nil {
            config.fontSize = CGFloat(defaults.double(forKey: keys.fontSize))
        }
        if defaults.object(forKey: keys.lineSpacing) != nil {
            config.lineSpacing = CGFloat(defaults.double(forKey: keys.lineSpacing))
        }
        if defaults.object(forKey: keys.pageMargin) != nil {
            config.pageMargin = CGFloat(defaults.double(forKey: keys.pageMargin))
        }
        if let themeID = defaults.string(forKey: keys.themeID) {
            config.themeID = themeID
        }
        if let transitionRaw = defaults.string(forKey: keys.pageTransition),
           let transition = ReaderConfig.PageTransition(rawValue: transitionRaw) {
            config.pageTransition = transition
        }

        return config
    }

    /// 重置为默认配置
    func resetToDefault() {
        defaults.removeObject(forKey: keys.fontSize)
        defaults.removeObject(forKey: keys.lineSpacing)
        defaults.removeObject(forKey: keys.pageMargin)
        defaults.removeObject(forKey: keys.themeID)
        defaults.removeObject(forKey: keys.pageTransition)
    }
}
