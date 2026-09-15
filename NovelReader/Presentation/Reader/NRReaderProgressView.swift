import UIKit

/// 全书进度条 - 细线样式 + 百分比文字
final class NRReaderProgressView: UIView {

    // MARK: - UI 组件
    private let trackView = UIView()
    private let fillView = UIView()
    private let percentageLabel = UILabel()

    // MARK: - 属性
    private(set) var progress: Double = 0

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
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // 轨道
        trackView.translatesAutoresizingMaskIntoConstraints = false
        trackView.backgroundColor = DesignToken.Color.textPrimary.withAlphaComponent(0.15) // 轨道透明灰
        trackView.layer.cornerRadius = 1.5 // 轨道圆角1.5pt
        addSubview(trackView)

        // 填充
        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.backgroundColor = DesignToken.Color.primary
        fillView.layer.cornerRadius = 1.5 // 填充圆角1.5pt
        trackView.addSubview(fillView)

        // 百分比文字
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        percentageLabel.font = DesignToken.Font.caption2 // 百分比11pt
        percentageLabel.textColor = DesignToken.Color.textSecondary
        percentageLabel.textAlignment = .right
        percentageLabel.text = "0%"
        addSubview(percentageLabel)

        NSLayoutConstraint.activate([
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 3), // 进度条高度3pt

            percentageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            percentageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentageLabel.widthAnchor.constraint(equalToConstant: 40), // 百分比宽度40pt

            trackView.trailingAnchor.constraint(equalTo: percentageLabel.leadingAnchor, constant: -DesignToken.Spacing.xs), // 进度条与文字间距4pt

            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: 0) // 初始宽度0
        ])
    }

    // MARK: - 公共方法
    /// 设置进度（0-1）
    func setProgress(_ progress: Double, animated: Bool = true) {
        self.progress = max(0, min(1, progress))
        percentageLabel.text = "\(Int(self.progress * 100))%"

        // 更新填充宽度约束
        if let constraint = trackView.constraints.first(where: { $0.firstAttribute == .width && $0.secondItem === fillView }) {
            constraint.isActive = false
        }
        fillView.constraints.forEach { $0.isActive = false }

        let widthConstraint = fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: CGFloat(self.progress))
        widthConstraint.isActive = true

        if animated {
            UIView.animate(withDuration: DesignToken.Animation.normal) { // 进度动画0.25秒
                self.layoutIfNeeded()
            }
        } else {
            layoutIfNeeded()
        }
    }

    /// 更新夜间模式颜色
    func updateForNightMode(_ isNight: Bool) {
        if isNight {
            fillView.backgroundColor = DesignToken.Color.primary // 夜间模式主色更醒目
            trackView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            percentageLabel.textColor = DesignToken.Color.textSecondary
        } else {
            fillView.backgroundColor = DesignToken.Color.primary
            trackView.backgroundColor = DesignToken.Color.textPrimary.withAlphaComponent(0.15)
            percentageLabel.textColor = DesignToken.Color.textSecondary
        }
    }
}
