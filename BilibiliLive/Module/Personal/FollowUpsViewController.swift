//
//  FollowUpsViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/12/6.
//

import Kingfisher
import MarqueeLabel
import SnapKit
import UIKit

class FollowUpsViewController: UIViewController {
    var collectionView: UICollectionView!
    var follows = [WebRequest.FollowingUser]() {
        didSet {
            collectionView.reloadData()
        }
    }

    var page = 1
    var finished = false
    var requesting = false
    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            return self?.makeGridLayoutSection()
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        collectionView.register(UpCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.makeConstraintsToBindToSuperview()
        Task {
            requesting = true
            do {
                follows = try await WebRequest.requestFollowing(page: 1)
            } catch {}
            requesting = false
        }
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let heightDimension = NSCollectionLayoutDimension.estimated(200)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.33),
            heightDimension: heightDimension
        ))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 30)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: heightDimension
            ),
            repeatingSubitem: item,
            count: 3
        )
        let vSpacing: CGFloat = 16
        let baseSpacing: CGFloat = 30
        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(baseSpacing), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))
        let section = NSCollectionLayoutSection(group: group)
        if baseSpacing > 0 {
            section.contentInsets = NSDirectionalEdgeInsets(top: baseSpacing, leading: 0, bottom: 0, trailing: 0)
        }

        return section
    }
}

extension FollowUpsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return follows.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! UpCell
        let data = follows[indexPath.item]
        cell.nameLabel.text = data.uname
        cell.despLabel.text = data.sign
        cell.imageView.kf.setImage(with: data.face, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        return cell
    }
}

extension FollowUpsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let data = follows[indexPath.item]
        let upSpaceVC = UpSpaceViewController()
        upSpaceVC.mid = data.mid
        present(upSpaceVC, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard follows.count > 0 else { return }
        guard indexPath.row == follows.count - 1, !requesting, !finished else {
            return
        }
        requesting = true
        Task {
            do {
                page += 1
                let next = try await WebRequest.requestFollowing(page: page)
                finished = next.count < 40
                follows.append(contentsOf: next)
            } catch {
                finished = true
            }
            requesting = false
        }
    }
}

class UpCell: BLMotionCollectionViewCell {
    let imageView = UIImageView()
    let nameLabel = MarqueeLabel()
    let despLabel = UILabel()

    /// Liquid Glass 底（tvOS 26+），低版本回退毛玻璃
    private let effectView = UIVisualEffectView.makeGlassView(cornerRadius: BLCornerRadius.normal)
    /// 聚焦时盖在玻璃上的白色高光，和详情页按钮、侧栏白胶囊同一套焦点语言
    private let focusOverlayView = UIView()

    override func setup() {
        super.setup()

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

        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(despLabel)
        nameLabel.holdScrolling = true
        imageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(30)
            make.bottom.equalToSuperview().offset(-30)
            make.width.equalTo(imageView.snp.height)
            make.width.equalTo(80)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(30)
        }

        despLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.leading)
            make.top.equalTo(nameLabel.snp.bottom).offset(20)
            make.trailing.equalTo(nameLabel.snp.trailing).offset(-20)
        }

        nameLabel.font = .App.rowTitle
        nameLabel.fadeLength = 60
        despLabel.font = .App.meta
        updateColors()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateColors()
        }
        if isFocused {
            startScroll()
        } else {
            stopScroll()
        }
    }

    /// 聚焦后玻璃变白底，名字和签名都要转黑才看得清
    private func updateColors() {
        focusOverlayView.alpha = isFocused ? 1 : 0
        let color: UIColor = isFocused ? .black : (UIColor(named: "titleColor") ?? .white)
        nameLabel.textColor = color
        despLabel.textColor = color
    }

    private func startScroll() {
        // 同上：先放开 holdScrolling，restartLabel 才会真的开始滚
        nameLabel.holdScrolling = false
        nameLabel.restartLabel()
    }

    private func stopScroll() {
        nameLabel.shutdownLabel()
        nameLabel.holdScrolling = true
    }
}

extension WebRequest {
    static func requestFollowing(page: Int) async throws -> [FollowingUser] {
        guard let mid = ApiRequest.getToken()?.mid else { return [] }
        struct Resp: Codable {
            let list: [FollowingUser]
        }

        let list: Resp = try await request(url: "https://api.bilibili.com/x/relation/followings",
                                           parameters: ["vmid": mid, "order_type": "attention", "pn": page])
        return list.list
    }

    struct FollowingUser: Codable {
        let mid: Int
        let uname: String
        let face: URL
        let sign: String
    }
}
