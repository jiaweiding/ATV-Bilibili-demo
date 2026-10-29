//
//  UpSpaceTitleSupplementaryView.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/27.
//

import SnapKit
import UIKit

class UpSpaceTitleSupplementaryView: UICollectionReusableView {
    let imageView = UIImageView()
    let nameLabel = UILabel()
    let despLabel = UILabel()
    let followButton = BLCustomButton()
    let blockButton = BLCustomButton()
    let sortButton = BLCustomButton()
    private let focusGuide = UIFocusGuide()

    var onFollowTapped: ((Bool) -> Void)?
    var onBlockTapped: ((Bool) -> Void)?
    var onSortTapped: ((Bool) -> Void)?
    var mid: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupUI() {
        addSubview(imageView)
        addSubview(nameLabel)
        addSubview(despLabel)
        addSubview(followButton)
        addSubview(blockButton)
        addSubview(sortButton)
        addLayoutGuide(focusGuide)

        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-30)
            make.width.equalTo(imageView.snp.height)
            make.width.equalTo(110)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.leading.equalTo(imageView.snp.trailing).offset(20)
        }

        despLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.leading)
            make.top.equalTo(nameLabel.snp.bottom).offset(20)
            make.trailing.lessThanOrEqualTo(sortButton.snp.leading).offset(-40)
        }

        // 纯图标按钮做成和详情页关注按钮一样的正圆：
        // 玻璃圆角跟着高度走，宽高不相等时就是扁的圆角矩形。
        // 这一排背后没有封面，玻璃本身看不出边缘，垫一层淡白色
        for button in [sortButton, followButton, blockButton] {
            button.restingWhiteAlpha = 0.12
            button.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.width.height.equalTo(80)
            }
        }

        blockButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-30)
        }

        followButton.snp.makeConstraints { make in
            make.trailing.equalTo(blockButton.snp.leading).offset(-20)
        }

        sortButton.snp.makeConstraints { make in
            make.trailing.equalTo(followButton.snp.leading).offset(-20)
        }

        nameLabel.font = .App.rowTitle
        despLabel.font = .App.meta
        despLabel.textColor = UIColor(named: "titleColor")
        despLabel.numberOfLines = 2

        followButton.image = UIImage(systemName: "heart")
        followButton.onImage = UIImage(systemName: "heart.fill")
        followButton.onPrimaryAction = { [weak self] _ in
            self?.followButtonTapped()
        }

        blockButton.image = UIImage(systemName: "slash.circle")
        blockButton.onImage = UIImage(systemName: "person.crop.circle.badge.minus")
        blockButton.onPrimaryAction = { [weak self] _ in
            self?.blockButtonTapped()
        }

        // isOn = 按播放量排序，off = 按最新发布
        sortButton.image = UIImage(systemName: "clock")
        sortButton.onImage = UIImage(systemName: "flame.fill")
        sortButton.onPrimaryAction = { [weak self] _ in
            self?.sortButtonTapped()
        }

        focusGuide.preferredFocusEnvironments = [sortButton, followButton, blockButton]
        focusGuide.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalTo(sortButton)
            make.trailing.equalTo(sortButton.snp.leading)
        }
    }

    @objc private func sortButtonTapped() {
        sortButton.isOn.toggle()
        onSortTapped?(sortButton.isOn)
    }

    @objc private func followButtonTapped() {
        followButton.isOn.toggle()
        onFollowTapped?(followButton.isOn)

        if let mid = mid {
            WebRequest.follow(mid: mid, follow: followButton.isOn)
        }
    }

    @objc private func blockButtonTapped() {
        blockButton.isOn.toggle()

        if let mid = mid {
            WebRequest.block(mid: mid, block: blockButton.isOn) { [weak self] _ in
                guard let self else { return }
                self.onBlockTapped?(self.blockButton.isOn)
            }
        }
    }
}
