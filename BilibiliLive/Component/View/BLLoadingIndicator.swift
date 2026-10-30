//
//  BLLoadingIndicator.swift
//  BilibiliLive
//
//  刷新/加载时右下角的加载指示：玻璃圆片 + 旋转圆弧
//

import SnapKit
import UIKit

final class BLLoadingIndicator: UIView {
    // 电视上观看距离远，64 太小不明显；加大到 88，圆弧同步放大
    private static let puckSize: CGFloat = 88
    private static let arcDiameter: CGFloat = 44
    private static let arcWidth: CGFloat = 5

    private let puckView = UIVisualEffectView.makeGlassView(cornerRadius: BLLoadingIndicator.puckSize / 2)
    private let trackLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    /// 记录目标状态：淡出动画进行中又被要求显示时，结束回调不能再把它藏起来
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        isHidden = true

        addSubview(puckView)
        puckView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 底环让圆片在深色背景上有个形，圆弧再压在上面转
        trackLayer.fillColor = nil
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.16).cgColor
        trackLayer.lineWidth = Self.arcWidth
        trackLayer.strokeStart = 0
        trackLayer.strokeEnd = 1
        layer.addSublayer(trackLayer)

        arcLayer.fillColor = nil
        arcLayer.strokeColor = UIColor.white.withAlphaComponent(0.95).cgColor
        arcLayer.lineWidth = Self.arcWidth
        arcLayer.lineCap = .round
        arcLayer.strokeStart = 0
        arcLayer.strokeEnd = 0.72
        // 加在玻璃之上
        layer.addSublayer(arcLayer)

        snp.makeConstraints { make in
            make.width.height.equalTo(Self.puckSize)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                                radius: Self.arcDiameter / 2,
                                startAngle: -.pi / 2,
                                endAngle: .pi * 1.5,
                                clockwise: true).cgPath
        trackLayer.frame = bounds
        trackLayer.path = path
        arcLayer.frame = bounds
        arcLayer.path = path
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        isHidden = false
        addSpinAnimation()
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        } completion: { _ in
            guard !self.isAnimating else { return }
            self.isHidden = true
            self.arcLayer.removeAnimation(forKey: "spin")
        }
    }

    private func addSpinAnimation() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = 1.1
        spin.repeatCount = .infinity
        arcLayer.add(spin, forKey: "spin")
    }
}

private var loadingIndicatorKey: UInt8 = 0

extension UIViewController {
    /// 刷新/加载时在右下角显示加载指示；多次调用以最后一次为准
    func blSetLoading(_ loading: Bool) {
        guard loading else {
            (objc_getAssociatedObject(self, &loadingIndicatorKey) as? BLLoadingIndicator)?.stopAnimating()
            return
        }

        let indicator: BLLoadingIndicator
        if let existing = objc_getAssociatedObject(self, &loadingIndicatorKey) as? BLLoadingIndicator {
            indicator = existing
        } else {
            indicator = BLLoadingIndicator()
            view.addSubview(indicator)
            indicator.snp.makeConstraints { make in
                make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-24)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
            }
            objc_setAssociatedObject(self, &loadingIndicatorKey, indicator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        indicator.startAnimating()
    }
}
