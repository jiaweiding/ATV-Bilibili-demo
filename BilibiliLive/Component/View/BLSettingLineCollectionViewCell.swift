//
//  BLSettingLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//

import SnapKit
import UIKit

/// 侧边栏行：图标 + 标题；聚焦/选中时显示白色胶囊（tvOS 26 风格）
class BLSettingLineCollectionViewCell: BLMotionCollectionViewCell {
    static let rowHeight: CGFloat = 66

    let titleLabel = UILabel()
    let iconView = UIImageView()
    private let pillView = UIView()
    private var titleLeadingConstraint: Constraint?

    /// SF Symbol 名称；为空时只显示标题，标题回到普通列表的文字缩进
    var icon: String? {
        didSet {
            let hasIcon = !(icon ?? "").isEmpty
            iconView.image = hasIcon ? UIImage(systemName: icon!, withConfiguration: Self.iconConfiguration) : nil
            iconView.isHidden = !hasIcon
            titleLeadingConstraint?.update(offset: hasIcon ? 68 : 30)
        }
    }

    /// 焦点是否停在侧栏里。焦点在栏内时白色胶囊只跟焦点走，光标移到哪一行就是哪一行；
    /// 焦点离开侧栏（回到内容区或顶栏）后，胶囊交还给当前选中项，作为「这个分区正在显示」的锁定标记。
    var isSidebarFocusActive = false {
        didSet {
            updateView()
        }
    }

    override var isSelected: Bool {
        didSet {
            updateView()
        }
    }

    private static let iconConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
    /// 焦点行的白胶囊
    private static let focusPillColor = UIColor.white.withAlphaComponent(0.95)
    /// 焦点在侧栏内时，当前分区只留一层很淡的白底：够看出「右边显示的是这一项」，又不会和焦点行抢白胶囊
    private static let currentPillColor = UIColor.white.withAlphaComponent(0.15)

    override func setup() {
        super.setup()

        pillView.backgroundColor = Self.focusPillColor
        pillView.layer.cornerRadius = Self.rowHeight / 2
        pillView.layer.cornerCurve = .continuous
        pillView.alpha = 0
        contentView.addSubview(pillView)
        pillView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }

        titleLabel.font = .App.rowTitle
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            // 图标 22 + 30 宽 + 16 间距
            titleLeadingConstraint = make.leading.equalToSuperview().offset(68).constraint
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 侧边栏行不缩放、不视差，只用白色胶囊表达焦点
        coordinator.addCoordinatedAnimations {
            self.updateView()
        }
    }

    private func updateView() {
        // 同一时刻只允许一个白色胶囊：焦点在侧栏内时它属于被聚焦的行，
        // 焦点在栏外时它才回到选中项（否则选中项和焦点行会同时亮两个白底）。
        // 焦点在栏内、选中项失焦时，选中项留一层淡白底表示「现在显示的是这一项」
        let focused = isFocused
        let locked = isSelected && !isSidebarFocusActive
        let current = isSelected && isSidebarFocusActive
        pillView.alpha = (focused || locked || current) ? 1 : 0
        pillView.backgroundColor = (focused || locked) ? Self.focusPillColor : Self.currentPillColor
        let color: UIColor = (focused || locked) ? .black : .white
        titleLabel.textColor = color
        iconView.tintColor = color
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        icon = nil
        updateView()
    }

    static func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                              heightDimension: .absolute(rowHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .absolute(rowHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        // 面板内的行不需要再叠加屏幕安全区，否则整列会被推向右下
        section.contentInsetsReference = .none
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension UICollectionView {
    /// 侧栏焦点进出时，让所有可见行重新决定谁显示白色胶囊
    func blSetSidebarFocusActive(_ active: Bool) {
        for case let cell as BLSettingLineCollectionViewCell in visibleCells {
            cell.isSidebarFocusActive = active
        }
    }
}
