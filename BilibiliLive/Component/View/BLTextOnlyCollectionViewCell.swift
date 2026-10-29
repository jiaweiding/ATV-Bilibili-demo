//
//  BLTextOnlyCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/24.
//

import Foundation
import UIKit

class BLTextOnlyCollectionViewCell: BLMotionCollectionViewCell {
    /// Liquid Glass 底（tvOS 26+），低版本回退深色毛玻璃
    private let effectView = UIVisualEffectView.makeGlassView(cornerRadius: BLCornerRadius.lessBig)
    /// 聚焦时盖在玻璃上的白色高光，和 Tab 卡片、侧栏白胶囊同一套焦点语言
    private let focusOverlayView = UIView()
    let titleLabel = UILabel()

    override func setup() {
        super.setup()
        scaleFactor = 1.1

        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        focusOverlayView.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        focusOverlayView.alpha = 0
        effectView.contentView.addSubview(focusOverlayView)
        focusOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        effectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.bottom.lessThanOrEqualToSuperview().inset(8)
        }
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.font = .App.rowTitle
        updateAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 选集卡片 300×150、范围按钮 200×90 共用这个 cell：
        // 圆角跟着高度走，大卡片保持 34，小按钮收一点，避免变成半颗胶囊
        effectView.layer.cornerRadius = min(BLCornerRadius.lessBig, bounds.height * 0.3)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateAppearance()
        }
    }

    /// 聚焦后玻璃变白底，文字转黑才看得清
    private func updateAppearance() {
        focusOverlayView.alpha = isFocused ? 1 : 0
        titleLabel.textColor = isFocused ? .black : .white
    }
}
