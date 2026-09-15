import UIKit

// MARK: - 骨架屏视图
/// 生产级骨架屏组件，用于数据加载时的占位显示
final class NRSkeletonView: UIView {

    // MARK: - 属性
    private var gradientLayer = CAGradientLayer()
    private var isAnimating = false

    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    // MARK: - UI 搭建
    private func setupUI() {
        backgroundColor = DesignToken.Color.backgroundTertiary
        layer.cornerRadius = DesignToken.Radius.md // 骨架圆角8pt
        clipsToBounds = true

        // 渐变层（闪烁效果）
        gradientLayer.colors = [
            DesignToken.Color.backgroundTertiary.cgColor,
            DesignToken.Color.backgroundSecondary.cgColor,
            DesignToken.Color.backgroundTertiary.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.5, 1]
        layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - 动画控制
    /// 开始骨架动画
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.5 // 动画周期1.5秒
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: "skeletonAnimation")
    }

    /// 停止骨架动画
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        gradientLayer.removeAnimation(forKey: "skeletonAnimation")
    }

    // MARK: - 便捷方法
    /// 创建指定尺寸的骨架视图
    static func create(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = DesignToken.Radius.md) -> NRSkeletonView {
        let view = NRSkeletonView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = cornerRadius
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height)
        ])
        return view
    }
}

// MARK: - 骨架屏容器（书籍列表用）
/// 书籍列表骨架屏，包含封面、标题、副标题占位
final class NRBookSkeletonCell: UITableViewCell {

    static let reuseIdentifier = "NRBookSkeletonCell"

    private let coverSkeleton = NRSkeletonView()
    private let titleSkeleton = NRSkeletonView()
    private let subtitleSkeleton = NRSkeletonView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        [coverSkeleton, titleSkeleton, subtitleSkeleton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            coverSkeleton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignToken.Spacing.lg), // 左边距16pt
            coverSkeleton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            coverSkeleton.widthAnchor.constraint(equalToConstant: 48), // 封面占位48pt
            coverSkeleton.heightAnchor.constraint(equalToConstant: 64), // 封面高度64pt（3:4比例）

            titleSkeleton.leadingAnchor.constraint(equalTo: coverSkeleton.trailingAnchor, constant: DesignToken.Spacing.md),
            titleSkeleton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignToken.Spacing.lg),
            titleSkeleton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.5), // 标题占位宽度50%
            titleSkeleton.heightAnchor.constraint(equalToConstant: 16), // 标题高度16pt

            subtitleSkeleton.leadingAnchor.constraint(equalTo: titleSkeleton.leadingAnchor),
            subtitleSkeleton.topAnchor.constraint(equalTo: titleSkeleton.bottomAnchor, constant: DesignToken.Spacing.sm),
            subtitleSkeleton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.3), // 副标题占位宽度30%
            subtitleSkeleton.heightAnchor.constraint(equalToConstant: 12) // 副标题高度12pt
        ])
    }

    func startAnimating() {
        coverSkeleton.startAnimating()
        titleSkeleton.startAnimating()
        subtitleSkeleton.startAnimating()
    }

    func stopAnimating() {
        coverSkeleton.stopAnimating()
        titleSkeleton.stopAnimating()
        subtitleSkeleton.stopAnimating()
    }
}
