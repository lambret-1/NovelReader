//
//  ExportProgressHUD.swift
//  NovelReader
//
//  导出进度 HUD：半透明遮罩 + 圆形进度环 + 文字提示
//

import UIKit

/// 导出进度 HUD
///
/// 使用方式：
/// ```
/// let hud = ExportProgressHUD()
/// hud.show(in: view, message: "正在导出...")
/// hud.updateProgress(0.5, message: "导出中 50%")
/// hud.hide(animated: true)
/// ```
final class ExportProgressHUD {

    // MARK: - 私有组件

    /// 遮罩容器
    private let containerView = UIView()
    /// 圆角卡片
    private let cardView = UIView()
    /// 圆形进度环
    private let progressRingLayer = CAShapeLayer()
    /// 中心百分比标签
    private let percentLabel = UILabel()
    /// 底部状态文字
    private let messageLabel = UILabel()

    /// 容器视图
    private weak var hostView: UIView?

    // MARK: - 尺寸常量

    /// 卡片尺寸（宽高）
    private let cardSize: CGFloat = 160 // 卡片160x160pt
    /// 进度环线宽
    private let ringLineWidth: CGFloat = 4 // 进度环线宽4pt
    /// 进度环直径
    private let ringDiameter: CGFloat = 80 // 进度环直径80pt

    // MARK: - 显示/隐藏

    /// 在指定视图上显示 HUD
    func show(in view: UIView, message: String) {
        hostView = view
        view.addSubview(containerView)
        containerView.frame = view.bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.3) // 半透明黑色遮罩30%

        // 卡片
        cardView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.9) // 深灰卡片90%不透明
        cardView.layer.cornerRadius = 12 // 圆角12pt
        cardView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cardView)

        // 中心百分比标签
        percentLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold) // 百分比18pt半粗
        percentLabel.textColor = .white
        percentLabel.textAlignment = .center
        percentLabel.text = "0%"
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(percentLabel)

        // 状态文字
        messageLabel.font = UIFont.systemFont(ofSize: 12) // 状态文字12pt
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = message
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(messageLabel)

        // 布局
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: cardSize), // 卡片宽度160pt
            cardView.heightAnchor.constraint(equalToConstant: cardSize), // 卡片高度160pt

            percentLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            percentLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor, constant: -10), // 百分比向上偏移10pt

            messageLabel.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 8), // 状态文字距百分比8pt
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
        ])

        // 配置进度环
        setupProgressRing()

        // 入场动画
        containerView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.containerView.alpha = 1
        }
    }

    /// 配置圆形进度环
    private func setupProgressRing() {
        let center = CGPoint(x: cardSize / 2, y: cardSize / 2 - 10) // 圆环中心，与百分比标签对齐
        let radius = ringDiameter / 2 - ringLineWidth // 圆环半径
        let circularPath = UIBezierPath(arcCenter: center,
                                        radius: radius,
                                        startAngle: -.pi / 2, // 从12点方向开始
                                        endAngle: .pi * 1.5,
                                        clockwise: true)

        // 背景圆环
        let backgroundRing = CAShapeLayer()
        backgroundRing.path = circularPath.cgPath
        backgroundRing.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor // 背景圆环20%透明度
        backgroundRing.fillColor = UIColor.clear.cgColor
        backgroundRing.lineWidth = ringLineWidth
        backgroundRing.frame = CGRect(x: 0, y: 0, width: cardSize, height: cardSize)
        cardView.layer.addSublayer(backgroundRing)

        // 前景进度环
        progressRingLayer.path = circularPath.cgPath
        progressRingLayer.strokeColor = UIColor.systemBlue.cgColor // 进度环蓝色
        progressRingLayer.fillColor = UIColor.clear.cgColor
        progressRingLayer.lineWidth = ringLineWidth
        progressRingLayer.lineCap = .round // 圆形端点
        progressRingLayer.strokeEnd = 0
        progressRingLayer.frame = CGRect(x: 0, y: 0, width: cardSize, height: cardSize)
        cardView.layer.addSublayer(progressRingLayer)
    }

    /// 更新进度
    /// - Parameters:
    ///   - progress: 进度 0.0 ~ 1.0
    ///   - message: 新的状态文字
    func updateProgress(_ progress: Float, message: String) {
        progressRingLayer.strokeEnd = CGFloat(progress)
        let percent = Int(round(progress * 100))
        percentLabel.text = "\(percent)%"
        messageLabel.text = message
    }

    /// 隐藏并移除
    func hide(animated: Bool) {
        guard animated else {
            containerView.removeFromSuperview()
            return
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.containerView.alpha = 0
        }) { _ in
            self.containerView.removeFromSuperview()
        }
    }
}
