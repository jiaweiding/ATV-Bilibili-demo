//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/5.
//

import SnapKit
import TVUIKit
import UIKit

protocol DisplayData: Hashable, AvatarProviding {
    var title: String { get }
    var ownerName: String { get }
    var pic: URL? { get }
    var avatar: URL? { get }
    var date: String? { get }
    var isFollowed: Bool { get }
    var overlay: DisplayOverlay? { get }
}

extension DisplayData {
    var avatar: URL? { return nil }
    var date: String? { return nil }
    var isFollowed: Bool { return false }
    var overlay: DisplayOverlay? { return nil }
}

struct AnyDispplayData: Hashable {
    let data: any DisplayData

    static func == (lhs: AnyDispplayData, rhs: AnyDispplayData) -> Bool {
        func eq<T: Equatable>(lhs: T, rhs: any Equatable) -> Bool {
            lhs == rhs as? T
        }
        return eq(lhs: lhs.data, rhs: rhs.data)
    }

    func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
    }
}

struct DisplayOverlay {
    var leftItems: [DisplayOverlayItem]
    var rightItems: [DisplayOverlayItem]
    var badge: DisplayOverlayBadge?

    init(leftItems: [DisplayOverlayItem], rightItems: [DisplayOverlayItem] = [], badge: DisplayOverlayBadge? = nil) {
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.badge = badge
    }

    struct DisplayOverlayItem {
        var icon: String?
        var text: String
    }

    struct DisplayOverlayBadge {
        var color: UIColor?
        var text: String
    }
}

struct FeedHeaderConfig {
    let elementKind: String
    let estimatedHeight: CGFloat
    let viewProvider: (UICollectionView, String, IndexPath) -> UICollectionReusableView?

    init<T: UICollectionReusableView>(
        viewType: T.Type,
        estimatedHeight: CGFloat = 44,
        configure: @escaping (T, IndexPath) -> Void
    ) {
        elementKind = String(describing: viewType)
        self.estimatedHeight = estimatedHeight

        let registration = UICollectionView.SupplementaryRegistration<T>(elementKind: elementKind) { view, _, indexPath in
            configure(view, indexPath)
        }

        viewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: registration, for: indexPath)
        }
    }
}

class FeedCollectionViewController: UIViewController {
    var collectionView: UICollectionView!

    private enum Section: CaseIterable {
        case main
    }

    var styleOverride: FeedDisplayStyle?
    /// 卡片是否有「播放量 · 日期」那一行；番剧 / 追番列表没有，设为 false 让行距收紧
    var cardShowsMetaLine = true
    var didSelect: ((any DisplayData) -> Void)?
    var didLongPress: ((any DisplayData) -> Void)?
    var loadMore: (() -> Void)?
    var finished = false
    var pageSize = 20
    var showHeader: Bool = false
    var headerText = ""
    var customHeaderConfig: FeedHeaderConfig?

    var displayDatas: [any DisplayData] {
        set {
            _displayData = newValue.map { AnyDispplayData(data: $0) }.uniqued()
            finished = false
        }
        get {
            _displayData.map { $0.data }
        }
    }

    private var _displayData = [AnyDispplayData]() {
        didSet {
            var snapshot = NSDiffableDataSourceSnapshot<Section, AnyDispplayData>()
            snapshot.appendSections(Section.allCases)
            snapshot.appendItems(_displayData, toSection: .main)
            dataSource.apply(snapshot)
        }
    }

    private var isLoading = false

    typealias DisplayCellRegistration = UICollectionView.CellRegistration<FeedCollectionViewCell, AnyDispplayData>
    private lazy var dataSource = makeDataSource()

    // MARK: - Public

    func show(in vc: UIViewController) {
        vc.addChild(self)
        vc.view.addSubview(view)
        view.makeConstraintsToBindToSuperview()
        didMove(toParent: vc)
        vc.setContentScrollView(collectionView)
    }

    func appendData(displayData: [any DisplayData]) {
        isLoading = false
        _displayData.append(contentsOf: displayData.map { AnyDispplayData(data: $0) }.filter({ !_displayData.contains($0) }))
        if displayData.count < pageSize - 5 || displayData.count == 0 {
            finished = true
            return
        }

        if _displayData.count < 12 {
            isLoading = true
            loadMore?()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        collectionView.dataSource = dataSource
        collectionView.delegate = self
    }

    // MARK: - Private

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, environment in
            return self?.makeGridLayoutSection(environment: environment)
        }
    }

    private func makeGridLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var style = Settings.displayStyle
        if parent?.parent is PersonalViewController {
            style = .sideBar
        }
        if let styleOverride {
            style = styleOverride
        }

        let hSpacing: CGFloat = style == .large ? 25 : 20
        let vSpacing: CGFloat = 60
        let edgeSpacing: CGFloat = 30
        let baseSpacing: CGFloat = style == .sideBar ? 24 : 0

        // 左右各补偿一段安全区，让首尾卡片对齐系统内容边距；
        // 列表本身就在安全区之外时（如直播页侧栏右侧）没有可补偿的边距，保留卡片内边距
        let compLeading = min(hSpacing, max(0, collectionView.safeAreaInsets.left))
        let compTrailing = min(hSpacing, max(0, collectionView.safeAreaInsets.right))

        // 用卡片内容的精确高度作为估算值：估算值偏大时卡片底部会多出空白，把行间距撑得很大
        let containerWidth = environment.container.effectiveContentSize.width
        let sectionWidth = (containerWidth > 0 ? containerWidth : 1760) + compLeading + compTrailing
        let itemWidth = sectionWidth * style.fractionalWidth
        let cardWidth = itemWidth - hSpacing * 2
        let estimatedHeight = cardWidth * 9 / 16 + 12 + style.infoMinHeight(cardShowsMetaLine: cardShowsMetaLine)

        let heightDimension = NSCollectionLayoutDimension.estimated(estimatedHeight)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(style.fractionalWidth),
            heightDimension: heightDimension
        ))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: heightDimension
            ),
            repeatingSubitem: item,
            count: style.feedColCount
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = vSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: baseSpacing + edgeSpacing, leading: -compLeading, bottom: edgeSpacing, trailing: -compTrailing)

        if showHeader {
            let headerHeight = customHeaderConfig?.estimatedHeight ?? 44
            let headerKind = customHeaderConfig?.elementKind ?? TitleSupplementaryView.reuseIdentifier
            let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .estimated(headerHeight))
            let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: titleSize,
                elementKind: headerKind,
                alignment: .top
            )
            // 头部标题与卡片左边缘对齐
            titleSupplementary.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
            section.boundarySupplementaryItems = [titleSupplementary]
        }
        return section
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AnyDispplayData> {
        let dataSource = UICollectionViewDiffableDataSource<Section, AnyDispplayData>(collectionView: collectionView, cellProvider: makeCellRegistration().cellProvider)

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: TitleSupplementaryView.reuseIdentifier) {
            [weak self] supplementaryView, string, indexPath in
            guard let self else { return }
            supplementaryView.label.text = self.headerText
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return nil }

            // 如果有自定义 header 配置，使用自定义的
            if let customConfig = self.customHeaderConfig, kind == customConfig.elementKind {
                return customConfig.viewProvider(collectionView, kind, indexPath)
            }

            // 否则使用默认的 TitleSupplementaryView
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: indexPath
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, indexPath, displayData in
            cell.styleOverride = self?.styleOverride
            cell.cardShowsMetaLine = self?.cardShowsMetaLine ?? true
            cell.setup(data: displayData.data)
            cell.onLongPress = {
                self?.didLongPress?(displayData.data)
            }
        }
    }
}

extension FeedCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let data = dataSource.itemIdentifier(for: indexPath) {
            didSelect?(data.data)
        }
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        let indexPath = IndexPath(item: 0, section: 0)
        return indexPath
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard _displayData.count > 0 else { return }
        guard indexPath.row == _displayData.count - 1, !isLoading, !finished else {
            return
        }
        isLoading = true
        loadMore?()
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        collectionView.visibleCells.compactMap { $0 as? BLMotionCollectionViewCell }.forEach { cell in
            cell.updateTransform()
        }
    }
}

extension FeedDisplayStyle {
    var feedColCount: Int {
        switch self {
        case .normal, .sideBar: return 4
        case .large: return 3
        }
    }
}
