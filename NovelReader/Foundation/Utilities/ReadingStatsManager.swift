import Foundation

/// 阅读统计管理器
final class ReadingStatsManager {
    static let shared = ReadingStatsManager()

    private let defaults = UserDefaults.standard
    private let keys = (
        totalReadingTime: "stats_total_reading_time",
        readingDays: "stats_reading_days",
        lastReadingDate: "stats_last_reading_date",
        streakDays: "stats_streak_days",
        sessionStartTime: "stats_session_start_time"
    )

    private var sessionStartTime: Date?

    private init() {}

    // MARK: - 会话管理

    /// 开始阅读会话
    func startSession() {
        sessionStartTime = Date()
    }

    /// 结束阅读会话并保存统计
    func endSession() {
        guard let start = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        sessionStartTime = nil

        // 只记录超过 10 秒的会话
        guard duration > 10 else { return }

        addReadingTime(duration)
        updateReadingDays()
    }

    // MARK: - 统计数据

    /// 总阅读时长（秒）
    var totalReadingTime: TimeInterval {
        defaults.double(forKey: keys.totalReadingTime)
    }

    /// 总阅读时长（格式化字符串）
    var formattedTotalReadingTime: String {
        let hours = Int(totalReadingTime) / 3600
        let minutes = (Int(totalReadingTime) % 3600) / 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        } else {
            return "\(minutes) 分钟"
        }
    }

    /// 阅读天数
    var readingDays: Int {
        defaults.integer(forKey: keys.readingDays)
    }

    /// 连续阅读天数
    var streakDays: Int {
        defaults.integer(forKey: keys.streakDays)
    }

    // MARK: - 私有方法

    private func addReadingTime(_ duration: TimeInterval) {
        let current = defaults.double(forKey: keys.totalReadingTime)
        defaults.set(current + duration, forKey: keys.totalReadingTime)
    }

    private func updateReadingDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = defaults.object(forKey: keys.lastReadingDate) as? Date {
            let lastDay = calendar.startOfDay(for: lastDate)

            if lastDay != today {
                // 新的一天
                var days = defaults.integer(forKey: keys.readingDays)
                days += 1
                defaults.set(days, forKey: keys.readingDays)

                // 更新连续天数
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                   calendar.isDate(lastDay, inSameDayAs: yesterday) {
                    var streak = defaults.integer(forKey: keys.streakDays)
                    streak += 1
                    defaults.set(streak, forKey: keys.streakDays)
                } else {
                    defaults.set(1, forKey: keys.streakDays)
                }
            }
        } else {
            // 第一次阅读
            defaults.set(1, forKey: keys.readingDays)
            defaults.set(1, forKey: keys.streakDays)
        }

        defaults.set(today, forKey: keys.lastReadingDate)
    }

    /// 重置统计数据
    func resetStats() {
        defaults.removeObject(forKey: keys.totalReadingTime)
        defaults.removeObject(forKey: keys.readingDays)
        defaults.removeObject(forKey: keys.lastReadingDate)
        defaults.removeObject(forKey: keys.streakDays)
    }
}
