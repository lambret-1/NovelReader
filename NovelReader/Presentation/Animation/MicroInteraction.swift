import UIKit

// MARK: - 微交互动效扩展
/// 为 UIView 提供按压、悬浮等微交互动效
extension UIView {

    /// 按压缩放动画（按钮、卡片点击效果）
    /// - Parameter scale: 缩放比例，默认0.97
    func pressAnimation(scale: CGFloat = 0.97, duration: TimeInterval = DesignToken.Animation.fast) {
        UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .curveEaseInOut]) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    /// 释放恢复动画
    func releaseAnimation(duration: TimeInterval = DesignToken.Animation.fast) {
        UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .curveEaseInOut]) {
            self.transform = .identity
        }
    }

    /// 悬浮阴影动画（卡片悬浮效果）
    func hoverShadowAnimation(isHovering: Bool, duration: TimeInterval = DesignToken.Animation.normal) {
        UIView.animate(withDuration: duration) {
            if isHovering {
                self.applyShadow(DesignToken.Shadow.md) // 悬浮时中阴影
                self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02) // 悬浮放大1.02
            } else {
                self.applyShadow(DesignToken.Shadow.sm) // 正常时小阴影
                self.transform = .identity
            }
        }
    }

    /// 淡入动画
    func fadeIn(duration: TimeInterval = DesignToken.Animation.normal, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        alpha = 0
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseInOut, animations: {
            self.alpha = 1
        }, completion: { _ in
            completion?()
        })
    }

    /// 淡出动画
    func fadeOut(duration: TimeInterval = DesignToken.Animation.normal, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseInOut, animations: {
            self.alpha = 0
        }, completion: { _ in
            completion?()
        })
    }

    /// 滑入动画（从指定方向）
    func slideIn(from direction: SlideDirection, duration: TimeInterval = DesignToken.Animation.normal, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let offset: CGFloat = 50 // 滑动距离50pt
        switch direction {
        case .top:
            transform = CGAffineTransform(translationX: 0, y: -offset)
        case .bottom:
            transform = CGAffineTransform(translationX: 0, y: offset)
        case .left:
            transform = CGAffineTransform(translationX: -offset, y: 0)
        case .right:
            transform = CGAffineTransform(translationX: offset, y: 0)
        }
        alpha = 0

        UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.transform = .identity
            self.alpha = 1
        }, completion: { _ in
            completion?()
        })
    }

    /// 滑出动画（向指定方向）
    func slideOut(to direction: SlideDirection, duration: TimeInterval = DesignToken.Animation.normal, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let offset: CGFloat = 50
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseInOut, animations: {
            switch direction {
            case .top:
                self.transform = CGAffineTransform(translationX: 0, y: -offset)
            case .bottom:
                self.transform = CGAffineTransform(translationX: 0, y: offset)
            case .left:
                self.transform = CGAffineTransform(translationX: -offset, y: 0)
            case .right:
                self.transform = CGAffineTransform(translationX: offset, y: 0)
            }
            self.alpha = 0
        }, completion: { _ in
            completion?()
        })
    }

    /// 弹性出现动画（用于弹窗、卡片）
    func springIn(duration: TimeInterval = DesignToken.Animation.spring, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        transform = CGAffineTransform(scaleX: 0.5, y: 0.5) // 初始缩放0.5
        alpha = 0

        UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: .curveEaseInOut, animations: {
            self.transform = .identity
            self.alpha = 1
        }, completion: { _ in
            completion?()
        })
    }

    /// 脉冲动画（用于强调、提示）
    func pulse(duration: TimeInterval = DesignToken.Animation.normal, repeatCount: Float = 1) {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.05 // 脉冲放大1.05
        animation.duration = duration / 2
        animation.autoreverses = true
        animation.repeatCount = repeatCount
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "pulse")
    }
}

// MARK: - 滑动方向
enum SlideDirection {
    case top
    case bottom
    case left
    case right
}

// MARK: - UITableView 列表动效扩展
extension UITableView {

    /// 重新加载数据并附带淡入动画
    func reloadDataWithFade(duration: TimeInterval = DesignToken.Animation.normal) {
        UIView.transition(with: self, duration: duration, options: .transitionCrossDissolve, animations: {
            self.reloadData()
        })
    }

    /// 插入行动画（从底部滑入）
    func insertRowsWithAnimation(at indexPaths: [IndexPath]) {
        beginUpdates()
        insertRows(at: indexPaths, with: .fade)
        endUpdates()
    }

    /// 删除行动画（淡出）
    func deleteRowsWithAnimation(at indexPaths: [IndexPath]) {
        beginUpdates()
        deleteRows(at: indexPaths, with: .fade)
        endUpdates()
    }
}
