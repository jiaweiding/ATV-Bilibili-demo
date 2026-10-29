//
//  VideoPlayerDiscoveryInfoViewController.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/5.
//

import AVKit
import UIKit

final class VideoPlayerDiscoveryInfoViewController: UIViewController {
    private enum Layout {
        static let cardWidth: CGFloat = 320
        /// 卡片和详情页的合集 / 推荐视频一样，用 Feed 的同款 cell
        static var cardHeight: CGFloat { Settings.displayStyle.cardHeight(cardWidth: cardWidth, cardShowsMetaLine: false) }
        static let sectionInsets = NSDirectionalEdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
        static let interGroupSpacing: CGFloat = 28
        static var preferredHeight: CGFloat { cardHeight + sectionInsets.top + sectionInsets.bottom + 16 }
    }

    struct Entry: Hashable {
        let playInfo: PlayInfo
        let displayData: DiscoveryDisplayData
    }

    struct DiscoveryDisplayData: DisplayData {
        let title: String
        let ownerName: String
        let pic: URL?
    }

    var onSelect: ((PlayInfo) -> Void)?

    private let emptyText: String
    private var entries = [Entry]()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(Layout.cardWidth),
                                                   heightDimension: .absolute(Layout.cardHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = Layout.sectionInsets
            section.interGroupSpacing = Layout.interGroupSpacing
            section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
            return section
        }

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.alwaysBounceVertical = false
        collectionView.clipsToBounds = false
        collectionView.register(FeedCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: FeedCollectionViewCell.self))
        return collectionView
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .App.body
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    init(title: String, emptyText: String) {
        self.emptyText = emptyText
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: Layout.preferredHeight)
        view.backgroundColor = .clear
        emptyLabel.text = emptyText

        view.addSubview(collectionView)
        view.addSubview(emptyLabel)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
        updateEmptyState()
    }

    func update(entries: [Entry]) {
        self.entries = entries
        guard isViewLoaded else { return }
        collectionView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let isEmpty = entries.isEmpty
        emptyLabel.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }
}

extension VideoPlayerDiscoveryInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let entry = entries[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: FeedCollectionViewCell.self),
                                                      for: indexPath) as! FeedCollectionViewCell
        // 这一行只有标题和 UP 主，没有播放量/日期
        cell.cardShowsMetaLine = false
        cell.setup(data: entry.displayData)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(entries[indexPath.item].playInfo)
    }
}
