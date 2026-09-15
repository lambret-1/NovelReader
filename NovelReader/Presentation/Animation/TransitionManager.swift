import UIKit

// MARK: - 转场动画管理器
/// 自定义视图控制器转场动画，提供淡入淡出、缩放、滑动等效果
final class TransitionManager: NSObject, UIViewControllerAnimatedTransitioning {

    // MARK: - 转场类型
    enum TransitionType {
        /// 淡入淡出
        case fade
        /// 缩放（从中心放大）
        case scale
        /// 从右侧滑入
        case slideFromRight
        /// 从底部滑入
        case slideFromBottom
    }

    // MARK: - 属性
    private let type: TransitionType
    private let duration: TimeInterval
    private let isPresenting: Bool

    // MARK: - 初始化
    init(type: TransitionType = .fade, duration: TimeInterval = DesignToken.Animation.normal, isPresenting: Bool = true) {
        self.type = type
        self.duration = duration
        self.isPresenting = isPresenting
    }

    // MARK: - UIViewControllerAnimatedTransitioning
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView

        if isPresenting {
            containerView.addSubview(toView)
            configureInitialState(for: toView)
        }

        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            if self.isPresenting {
                self.configureFinalState(for: toView)
            } else {
                self.configureDismissState(for: fromView)
            }
        }) { _ in
            if !self.isPresenting {
                fromView.removeFromSuperview()
            }
            transitionContext.completeTransition(true)
        }
    }

    // MARK: - 私有方法
    private func configureInitialState(for view: UIView) {
        switch type {
        case .fade:
            view.alpha = 0
        case .scale:
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8) // 初始缩放0.8
        case .slideFromRight:
            view.transform = CGAffineTransform(translationX: view.bounds.width, y: 0) // 从右侧滑入
        case .slideFromBottom:
            view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height) // 从底部滑入
        }
    }

    private func configureFinalState(for view: UIView) {
        switch type {
        case .fade:
            view.alpha = 1
        case .scale:
            view.alpha = 1
            view.transform = .identity
        case .slideFromRight, .slideFromBottom:
            view.transform = .identity
        }
    }

    private func configureDismissState(for view: UIView) {
        switch type {
        case .fade:
            view.alpha = 0
        case .scale:
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        case .slideFromRight:
            view.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
        case .slideFromBottom:
            view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        }
    }
}

// MARK: - UIViewController 便捷转场扩展
extension UIViewController {

    /// 使用自定义转场 present 视图控制器
    func presentWithTransition(_ viewController: UIViewController, type: TransitionManager.TransitionType = .fade, duration: TimeInterval = DesignToken.Animation.normal, completion: (() -> Void)? = nil) {
        viewController.transitioningDelegate = self
        objc_setAssociatedObject(self, &UIViewController.transitionTypeKey, type.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &UIViewController.transitionDurationKey, duration, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        present(viewController, animated: true, completion: completion)
    }

    private static var transitionTypeKey: UInt8 = 0
    private static var transitionDurationKey: UInt8 = 0
}

// MARK: - UIViewControllerTransitioningDelegate
extension UIViewController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let typeRaw = objc_getAssociatedObject(self, &UIViewController.transitionTypeKey) as? Int ?? 0
        let duration = objc_getAssociatedObject(self, &UIViewController.transitionDurationKey) as? TimeInterval ?? DesignToken.Animation.normal
        let type = TransitionManager.TransitionType(rawValue: typeRaw) ?? .fade
        return TransitionManager(type: type, duration: duration, isPresenting: true)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let typeRaw = objc_getAssociatedObject(self, &UIViewController.transitionTypeKey) as? Int ?? 0
        let duration = objc_getAssociatedObject(self, &UIViewController.transitionDurationKey) as? TimeInterval ?? DesignToken.Animation.normal
        let type = TransitionManager.TransitionType(rawValue: typeRaw) ?? .fade
        return TransitionManager(type: type, duration: duration, isPresenting: false)
    }
}

// MARK: - TransitionType RawValue 支持
extension TransitionManager.TransitionType: RawRepresentable {
    typealias RawValue = Int

    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .fade
        case 1: self = .scale
        case 2: self = .slideFromRight
        case 3: self = .slideFromBottom
        default: return nil
        }
    }

    var rawValue: Int {
        switch self {
        case .fade: return 0
        case .scale: return 1
        case .slideFromRight: return 2
        case .slideFromBottom: return 3
        }
    }
}
