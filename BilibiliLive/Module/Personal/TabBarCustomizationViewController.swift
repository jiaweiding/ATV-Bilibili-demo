//
//  TabBarCustomizationViewController.swift
//  BilibiliLive
//

import SnapKit
import UIKit

class TabBarCustomizationViewController: UIViewController {
    // MARK: - State

    /// 正在排序的页面。`nil` 表示浏览模式。
    private var editingPage: TabBarPage?
    private var pendingFocusIndexPath: IndexPath?
    private var focusedIndexPath: IndexPath?

    /// 归属固定：导航栏和「我的」各自一行，行内可以排序
    private var tabbarPlacements = [Settings.TabBarPagePlacement]()
    private var minePlacements = [Settings.TabBarPagePlacement]()

    private var originalPlacements = [Settings.TabBarPagePlacement]()

    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        return [collectionView]
    }

    // MARK: - Views

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.font = .App.sectionTitle
        label.textColor = UIColor.white
        return label
    }()

    private let restoreDefaultButton: BLCustomTextButton = {
        let button = BLCustomTextButton()
        button.title = "恢复默认"
        button.titleFont = .App.button
        button.titleColor = UIColor.white
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.remembersLastFocusedIndexPath = false
        cv.dataSource = self
        cv.delegate = self
        cv.clipsToBounds = false
        cv.register(TabBarTileCell.self, forCellWithReuseIdentifier: TabBarTileCell.reuseID)
        cv.register(TabBarSectionHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: TabBarSectionHeaderView.reuseID)
        return cv
    }()

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            self?.makeSection(environment: environment)
        }
    }

    private func makeSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let tileSize = TabBarTileCell.tileSize
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(tileSize.width),
                                              heightDimension: .absolute(tileSize.height))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(tileSize.width),
                                               heightDimension: .absolute(tileSize.height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 30
        section.contentInsets = NSDirectionalEdgeInsets(top: 30, leading: 0, bottom: 30, trailing: 40)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                heightDimension: .absolute(50))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]
        return section
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "自定义Tab栏"
        view.backgroundColor = .black

        setupUI()
        reloadPlacementsFromSettings()
        updateHintLabel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if editingPage != nil { stopEditing() }
        commitIfNeeded()
    }

    // MARK: - Press handling

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }

        switch press.type {
        case .select:
            // 确认键：进入 / 结束排序
            editingPage != nil ? stopEditing() : startEditing()
        case .playPause:
            // 播放键：隐藏 / 恢复当前选中的页面
            toggleHiddenAtFocusedItem()
        default:
            super.pressesEnded(presses, with: event)
        }
    }

    // MARK: - Editing

    private func startEditing() {
        guard let ip = focusedIndexPath,
              let p = placement(at: ip)
        else { return }
        editingPage = p.page
        updateHintLabel()
        collectionView.reconfigureItems(at: collectionView.indexPathsForVisibleItems)
    }

    private func stopEditing() {
        editingPage = nil
        updateHintLabel()
        commitIfNeeded()
        collectionView.reconfigureItems(at: collectionView.indexPathsForVisibleItems)
    }

    // MARK: - Hide

    private func toggleHiddenAtFocusedItem() {
        guard let indexPath = focusedIndexPath,
              let placement = placement(at: indexPath)
        else { return }

        if placement.page.isFixedInTabBar {
            presentAlert(title: "「我的」不能隐藏")
            return
        }

        if !placement.isHidden, placement.section == .tabBar,
           tabbarPlacements.filter({ !$0.isHidden }).count <= 3
        {
            presentAlert(title: "导航栏至少保留 3 个页面")
            return
        }

        switch pageSection(for: indexPath) {
        case .tabBar:
            tabbarPlacements[indexPath.item].isHidden.toggle()
        case .personal:
            minePlacements[indexPath.item].isHidden.toggle()
        }
        collectionView.reconfigureItems(at: [indexPath])
    }

    private func presentAlert(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Move

    private func moveEditingItem(from: IndexPath, to: IndexPath) -> Bool {
        let section = pageSection(for: from)
        // 归属固定，不允许跨行移动；排序只在同一行内进行
        guard section == pageSection(for: to) else { return false }

        switch section {
        case .tabBar:
            tabbarPlacements.swapAt(from.item, to.item)
        case .personal:
            minePlacements.swapAt(from.item, to.item)
        }
        return true
    }

    // MARK: - UI helpers

    private func setupUI() {
        view.addSubview(hintLabel)
        view.addSubview(restoreDefaultButton)
        view.addSubview(collectionView)
        restoreDefaultButton.addTarget(self, action: #selector(didTapRestoreDefault), for: .primaryActionTriggered)

        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12)
            make.leading.equalToSuperview().offset(80)
            make.trailing.lessThanOrEqualTo(restoreDefaultButton.snp.leading).offset(-24)
        }

        let focusGuide = UIFocusGuide()
        view.addLayoutGuide(focusGuide)
        NSLayoutConstraint.activate([
            focusGuide.topAnchor.constraint(equalTo: view.topAnchor),
            focusGuide.leftAnchor.constraint(equalTo: view.leftAnchor),
            focusGuide.rightAnchor.constraint(equalTo: view.rightAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: collectionView.topAnchor),
        ])
        focusGuide.preferredFocusEnvironments = [restoreDefaultButton]

        restoreDefaultButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(4)
            make.trailing.equalToSuperview().offset(-80)
            make.height.equalTo(72)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(12)
            make.top.greaterThanOrEqualTo(restoreDefaultButton.snp.bottom).offset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.leading.equalToSuperview().offset(80)
            make.trailing.equalToSuperview().offset(-80)
        }
    }

    private func updateHintLabel() {
        hintLabel.text = editingPage != nil
            ? "排序中：左右移动排序，按播放键隐藏或恢复，按确认键完成"
            : "按确认键排序，按播放键隐藏或恢复选中页面"
    }

    private func commitIfNeeded() {
        let newPlacements = tabbarPlacements + minePlacements
        if newPlacements != originalPlacements {
            Settings.setPlacements(newPlacements)
            originalPlacements = newPlacements
        }
    }

    private func reloadPlacementsFromSettings() {
        let placements = Settings.currentPlacements
        tabbarPlacements = placements.filter { $0.section == .tabBar }
        minePlacements = placements.filter { $0.section == .personal }
        originalPlacements = tabbarPlacements + minePlacements
        collectionView.reloadData()
    }

    @objc
    private func didTapRestoreDefault() {
        if editingPage != nil {
            stopEditing()
        }
        let placements = Settings.defaultPlacements
        tabbarPlacements = placements.filter { $0.section == .tabBar }
        minePlacements = placements.filter { $0.section == .personal }
        updateHintLabel()
        collectionView.reloadData()
        commitIfNeeded()
    }

    // MARK: - Data helpers

    /// 分区顺序：导航栏、我的页面
    private func pageSection(for indexpath: IndexPath) -> Settings.TabBarPageSection {
        Settings.TabBarPageSection.allCases[indexpath.section]
    }

    private func placement(at indexPath: IndexPath) -> Settings.TabBarPagePlacement? {
        switch pageSection(for: indexPath) {
        case .tabBar:
            guard tabbarPlacements.indices.contains(indexPath.item) else { return nil }
            return tabbarPlacements[indexPath.item]
        case .personal:
            guard minePlacements.indices.contains(indexPath.item) else { return nil }
            return minePlacements[indexPath.item]
        }
    }
}

// MARK: - UICollectionViewDataSource

extension TabBarCustomizationViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Settings.TabBarPageSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Settings.TabBarPageSection.allCases[section] {
        case .tabBar:
            return tabbarPlacements.count
        case .personal:
            return minePlacements.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabBarTileCell.reuseID, for: indexPath) as! TabBarTileCell
        if let placement = placement(at: indexPath) {
            let page = placement.page
            cell.configure(title: page.title,
                           systemImage: page.systemImage,
                           isBeingEdited: page == editingPage,
                           isHidden: placement.isHidden)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView
    {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                   withReuseIdentifier: TabBarSectionHeaderView.reuseID,
                                                                   for: indexPath) as! TabBarSectionHeaderView
        view.label.text = Settings.TabBarPageSection.allCases[indexPath.section].title
        return view
    }
}

// MARK: - UICollectionViewDelegate

extension TabBarCustomizationViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool
    {
        guard editingPage != nil else { return true }

        // For swipe gestures that bypass pressesBegan, derive direction and trigger move.
        if let from = context.previouslyFocusedIndexPath,
           let to = context.nextFocusedIndexPath
        {
            if pendingFocusIndexPath == from {
                return false
            }
            pendingFocusIndexPath = to

            if moveEditingItem(from: from, to: to) == false {
                return false
            }
            collectionView.performBatchUpdates {
                collectionView.moveItem(at: from, to: to)
            } completion: { [weak self] _ in
                self?.pendingFocusIndexPath = nil
            }
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView,
                        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                        with coordinator: UIFocusAnimationCoordinator)
    {
        focusedIndexPath = context.nextFocusedIndexPath
        if focusedIndexPath == pendingFocusIndexPath {
            pendingFocusIndexPath = nil
        }
    }
}

// MARK: - Tile Cell

class TabBarTileCell: BLMotionCollectionViewCell {
    static let reuseID = String(describing: TabBarTileCell.self)
    /// 卡片圆角和侧栏面板同一档
    static let tileSize = CGSize(width: 200, height: 140)

    private static let iconConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
    private static let badgeConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
    /// 聚焦时的白色高光：和侧栏白胶囊、系统设置行同一种焦点表达
    private static let focusFillColor = UIColor.white.withAlphaComponent(0.95)

    private var isBeingEdited = false
    /// 被隐藏的页面：卡片留在原位，压暗并在右上角挂一个眼睛划掉的角标
    private var isHiddenPage = false

    /// Liquid Glass 底（tvOS 26+），低版本回退毛玻璃
    private let effectView = UIVisualEffectView.makeGlassView(cornerRadius: BLCornerRadius.lessBig)
    /// 聚焦时盖在玻璃上的白色高光
    private let focusOverlayView = UIView()
    private let iconView = UIImageView()
    /// 隐藏角标挂在 cell 上而不是 contentView 里：contentView 压暗时角标要保持清晰
    private let hiddenBadgeView = UIView()
    private let hiddenBadgeIconView = UIImageView()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .App.rowTitle
        l.textAlignment = .center
        l.numberOfLines = 2
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, systemImage: String, isBeingEdited: Bool, isHidden: Bool) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: systemImage, withConfiguration: Self.iconConfiguration)
        self.isBeingEdited = isBeingEdited
        isHiddenPage = isHidden
        setShaking(isBeingEdited)
        updateAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.layer.removeAnimation(forKey: "shake")
        transform = .identity
        isBeingEdited = false
        isHiddenPage = false
    }

    // MARK: - Private

    private func setShaking(_ shaking: Bool) {
        if shaking {
            guard contentView.layer.animation(forKey: "shake") == nil else { return }
            let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            anim.values = [-0.015, 0.015, -0.015]
            anim.duration = 0.22
            anim.repeatCount = .infinity
            contentView.layer.add(anim, forKey: "shake")
        } else {
            contentView.layer.removeAnimation(forKey: "shake")
        }
    }

    private func setupView() {
        layer.shadowColor = UIColor.black.cgColor

        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        focusOverlayView.backgroundColor = Self.focusFillColor
        focusOverlayView.alpha = 0
        effectView.contentView.addSubview(focusOverlayView)
        focusOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(52)
        }

        // 图标在上、文字在下，和 Tab 栏里的项目一一对应
        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.isUserInteractionEnabled = false
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }

        // 隐藏角标：右上角，避开居中的图标和标题
        hiddenBadgeView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hiddenBadgeView.layer.cornerRadius = 20
        hiddenBadgeView.isHidden = true
        addSubview(hiddenBadgeView)
        hiddenBadgeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.width.height.equalTo(40)
        }

        hiddenBadgeIconView.image = UIImage(systemName: "eye.slash", withConfiguration: Self.badgeConfiguration)
        hiddenBadgeIconView.tintColor = .white
        hiddenBadgeIconView.contentMode = .scaleAspectFit
        hiddenBadgeView.addSubview(hiddenBadgeIconView)
        hiddenBadgeIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(22)
        }

        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateAppearance()
        }
    }

    private func updateAppearance() {
        // 聚焦时整块玻璃变白、图标和文字转黑（阴影交给基类随缩放一起做）
        focusOverlayView.alpha = isFocused ? 1 : 0
        let contentColor: UIColor = isFocused ? .black : .white
        titleLabel.textColor = contentColor
        iconView.tintColor = contentColor
        hiddenBadgeView.isHidden = !isHiddenPage
        // 角标底色跟着卡片反着来：白卡上用深底，暗卡上用浅底，两种状态都看得清
        hiddenBadgeView.backgroundColor = isFocused
            ? UIColor.black.withAlphaComponent(0.6)
            : UIColor.white.withAlphaComponent(0.18)
        // 隐藏的卡片浏览时明显压暗，聚焦后亮起来（角标一直在，仍然能看出是隐藏项）
        contentView.alpha = (isHiddenPage && !isFocused) ? 0.35 : 1
    }
}

// MARK: - Section Header

class TabBarSectionHeaderView: UICollectionReusableView {
    static let reuseID = String(describing: TabBarSectionHeaderView.self)

    let label: UILabel = {
        let l = UILabel()
        l.font = .App.sectionTitle
        l.textColor = .white
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview().offset(-4)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
