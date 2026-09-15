import Foundation

// MARK: - String 扩展
extension String {
    /// 计算 SHA256
    var sha256: String {
        Chapter.hash(content: self)
    }

    /// 去除首尾空白和换行
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 截取指定长度
    func truncated(to length: Int, trailing: String = "...") -> String {
        guard count > length else { return self }
        return String(prefix(length)) + trailing
    }

    /// 是否是合法的 GitHub 仓库名格式 owner/repo
    var isValidRepoFullName: Bool {
        let parts = components(separatedBy: "/")
        return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
    }
}

// MARK: - Date 扩展
extension Date {
    /// 格式化为字符串
    func formattedString(format: String = "yyyy-MM-dd HH:mm:ss") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

    /// 相对时间描述
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - UIViewController 扩展
extension UIViewController {
    /// 显示提示框
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completion?()
        }))
        present(alert, animated: true)
    }

    /// 显示带输入框的提示框
    func showInputAlert(title: String, message: String, placeholder: String, completion: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = placeholder
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
            completion(nil)
        }))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completion(alert.textFields?.first?.text)
        }))
        present(alert, animated: true)
    }
}

// MARK: - UIColor 扩展
extension UIColor {
    /// 从十六进制字符串创建颜色
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
