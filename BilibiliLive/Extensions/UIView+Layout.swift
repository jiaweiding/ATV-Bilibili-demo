//
//  UIView+Layout.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit

/// 全局圆角规范，统一各页面卡片的视觉语言
enum BLCornerRadius {
    static let small: CGFloat = 8
    static let little: CGFloat = 12
    static let moreLittle: CGFloat = 18
    static let normal: CGFloat = 25
    static let lessBig: CGFloat = 34
    static let big: CGFloat = 45
}

extension UIVisualEffectView {
    /// tvOS 26+ 使用 Liquid Glass 玻璃材质，低版本回退为毛玻璃
    static func makeGlassView(style: UIBlurEffect.Style = .regular,
                              cornerRadius: CGFloat = 0) -> UIVisualEffectView
    {
        let effectView: UIVisualEffectView
        if #available(tvOS 26.0, *) {
            effectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: style))
        }
        effectView.isUserInteractionEnabled = false
        effectView.layer.cornerRadius = cornerRadius
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = cornerRadius > 0
        return effectView
    }
}

extension UIView {
    /// 在视图底层插入一层玻璃背景（tvOS 26+ 为 Liquid Glass，低版本为毛玻璃）
    func setGlassEffectView(cornerRadius: CGFloat = 0) {
        let effectView = UIVisualEffectView.makeGlassView(cornerRadius: cornerRadius)
        insertSubview(effectView, at: 0)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// 在视图底层插入一层毛玻璃
    func setBlurEffectView(style: UIBlurEffect.Style = .regular,
                           cornerRadius: CGFloat = 0,
                           alpha: CGFloat = 1)
    {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: style))
        effectView.alpha = alpha
        effectView.isUserInteractionEnabled = false
        effectView.layer.cornerRadius = cornerRadius
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = cornerRadius > 0
        insertSubview(effectView, at: 0)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// 设置圆角、边框与阴影；传入 shadowColor 时不裁切子视图以便显示阴影
    func setCornerRadius(_ cornerRadius: CGFloat,
                         cornerMask: CACornerMask? = nil,
                         borderColor: UIColor? = nil,
                         borderWidth: CGFloat = 0,
                         shadowColor: UIColor? = nil,
                         shadowRadius: CGFloat = 12,
                         shadowOffset: CGSize = .zero,
                         shadowAlpha: CGFloat = 0.3)
    {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous

        if let cornerMask {
            layer.maskedCorners = cornerMask
        }
        if let borderColor {
            layer.borderColor = borderColor.cgColor
        }
        if borderWidth > 0 {
            layer.borderWidth = borderWidth
        }

        if let shadowColor {
            layer.shadowColor = shadowColor.cgColor
            layer.shadowRadius = shadowRadius
            layer.shadowOffset = shadowOffset
            layer.shadowOpacity = Float(shadowAlpha)
            layer.masksToBounds = false
        } else {
            layer.masksToBounds = true
        }
    }

    @discardableResult
    func makeConstraints(_ block: (UIView) -> [NSLayoutConstraint]) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(block(self))
        return self
    }

    @discardableResult
    func makeConstraintsToBindToSuperview(_ inset: UIEdgeInsets = .zero) -> Self {
        return makeConstraints { [
            $0.leftAnchor.constraint(equalTo: $0.superview!.leftAnchor, constant: inset.left),
            $0.rightAnchor.constraint(equalTo: $0.superview!.rightAnchor, constant: -inset.right),
            $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: inset.top),
            $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: -inset.bottom),
        ] }
    }

    @discardableResult
    func makeConstraintsBindToCenterOfSuperview() -> Self {
        return makeConstraints { [
            $0.centerXAnchor.constraint(equalTo: $0.superview!.centerXAnchor),
            $0.centerYAnchor.constraint(equalTo: $0.superview!.centerYAnchor),
        ] }
    }
}
