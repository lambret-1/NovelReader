import UIKit

/// 基础导航控制器 - 全局统一管理右滑返回边缘手势
/// 确保所有页面都支持从屏幕左边缘右滑返回上一页
final class BaseNavigationController: UINavigationController {

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwipeBackGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 每次出现时重新确保手势可用，避免被其他页面修改
        enableSwipeBackGesture()
    }

    // MARK: - 右滑返回手势配置
    private func setupSwipeBackGesture() {
        // 设置手势代理为自身，统一管理
        interactivePopGestureRecognizer?.delegate = self
        // 确保手势启用
        interactivePopGestureRecognizer?.isEnabled = true
        // 设置手势为边缘滑动（从屏幕左边缘开始）
        if let gesture = interactivePopGestureRecognizer as? UIScreenEdgePanGestureRecognizer {
            gesture.edges = .left // 从左边缘滑动
        }
    }

    /// 启用右滑返回手势
    private func enableSwipeBackGesture() {
        interactivePopGestureRecognizer?.isEnabled = true
        interactivePopGestureRecognizer?.delegate = self
    }

    // MARK: - 页面 push/pop 时的处理
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        // push 后确保手势可用
        enableSwipeBackGesture()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)
        // pop 后确保手势可用
        enableSwipeBackGesture()
        return popped
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        let popped = super.popToRootViewController(animated: animated)
        // pop 到根视图后禁用手势（根视图没有上一页可返回）
        interactivePopGestureRecognizer?.isEnabled = false
        return popped
    }
}

// MARK: - UIGestureRecognizerDelegate
extension BaseNavigationController: UIGestureRecognizerDelegate {

    /// 控制手势是否应该开始
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只有当导航栈中有超过1个页面时才允许右滑返回
        // 根视图控制器时不允许滑动
        guard viewControllers.count > 1 else {
            return false
        }

        // 检查当前顶层视图控制器是否禁用了右滑返回
        if let topVC = topViewController as? SwipeBackConfigurable {
            return topVC.shouldEnableSwipeBack
        }

        return true
    }

    /// 允许多个手势同时识别（避免与其他手势冲突）
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    /// 手势是否需要等待其他手势失败
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 右滑返回手势优先，不等待其他手势
        return false
    }
}

// MARK: - 右滑返回配置协议
/// 视图控制器可实现此协议来控制是否启用右滑返回
protocol SwipeBackConfigurable: AnyObject {
    /// 是否启用右滑返回手势，默认 true
    var shouldEnableSwipeBack: Bool { get }
}

// 默认实现
extension SwipeBackConfigurable {
    var shouldEnableSwipeBack: Bool {
        return true
    }
}
