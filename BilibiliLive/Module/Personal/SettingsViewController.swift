//
//  SettingsViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import UIKit

class SettingsViewController: UIViewController {
    class SectionModel: Hashable, Equatable {
        let title: String
        let items: [CellModel]

        init(title: String, @ArrayBuilder<CellModel> items: () -> [CellModel]) {
            self.title = title
            self.items = items()
        }

        static func == (lhs: SectionModel, rhs: SectionModel) -> Bool {
            lhs.title == rhs.title && lhs.items == rhs.items
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(items)
        }
    }

    class CellModel: Hashable, Equatable {
        let title: String
        let desp: () -> String
        /// 右侧显示箭头（进入下一级页面的行）
        let showsChevron: Bool
        let action: ((@escaping () -> Void) -> Void)?

        var updateAction: (() -> Void)?

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
        }

        static func == (lhs: CellModel, rhs: CellModel) -> Bool {
            lhs.title == rhs.title
        }

        init(title: String, desp: @autoclosure @escaping () -> String, showsChevron: Bool = false, action: ((@escaping () -> Void) -> Void)?) {
            self.title = title
            self.desp = desp
            self.showsChevron = showsChevron
            self.action = action
        }
    }

    let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(SettingsSwitchCell.rowHeight))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(SettingsSwitchCell.rowHeight))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(6)

            let section = NSCollectionLayoutSection(group: group)
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(117)
            )

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: "header",
                alignment: .top
            )
            header.pinToVisibleBounds = false
            section.boundarySupplementaryItems = [header]
            // 与 Apple TV 系统设置一致：行高 66、行间距 14
            section.interGroupSpacing = 14
            return section
        }
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    var dataSource: UICollectionViewDiffableDataSource<SectionModel, CellModel>!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(collectionView)
        collectionView.remembersLastFocusedIndexPath = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        collectionView.snp.makeConstraints { make in
            make.top.right.bottom.equalToSuperview()
            make.left.equalToSuperview()
        }

        collectionView.delegate = self
        collectionView.register(SettingsSwitchCell.self, forCellWithReuseIdentifier: String(describing: SettingsSwitchCell.self))
        collectionView.register(SettingsHeaderView.self, forSupplementaryViewOfKind: "header", withReuseIdentifier: "HeaderView")

        configureDataSource()
        setupData()
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SectionModel, CellModel>(collectionView: collectionView) { collectionView, indexPath, cellModel -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: SettingsSwitchCell.self), for: indexPath) as! SettingsSwitchCell
            cell.set(with: cellModel)
            return cell
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as! SettingsHeaderView
            let title = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section].title ?? UUID().uuidString

            header.label.text = title
            return header
        }
    }

    private func setupData() {
        createSnapshot {
            SectionModel(title: "通用") {
                Toggle(title: "启用投屏", setting: Settings.enableDLNA, onChange: Settings.enableDLNA.toggle()) {
                    _ in
                    BiliBiliUpnpDMR.shared.start()
                }

                Toggle(title: "热门个性化推荐", setting: Settings.requestHotWithoutCookie, onChange: Settings.requestHotWithoutCookie.toggle())
            }

            SectionModel(title: "界面") {
                Navigation(title: "自定义Tab栏", desp: "") { [weak self] in
                    let controller = TabBarCustomizationViewController()
                    self?.present(controller, animated: true)
                }

                Actions(title: "视频每行显示个数", message: "重启app生效",
                        current: Settings.displayStyle.desp,
                        options: FeedDisplayStyle.allCases.filter({ !$0.hideInSetting }),
                        optionString: FeedDisplayStyle.allCases.filter({ !$0.hideInSetting }).map({ $0.desp }))
                {
                    Settings.displayStyle = $0
                }
                Toggle(title: "侧边栏菜单自动切换", setting: Settings.sideMenuAutoSelectChange, onChange: Settings.sideMenuAutoSelectChange.toggle())

                Toggle(title: "不显示详情页直接进入视频",
                       setting: Settings.direatlyEnterVideo,
                       onChange: Settings.direatlyEnterVideo.toggle())

                Actions(title: "视频详情相关推荐加载模式", message: "4k以上需要大会员",
                        current: Settings.showRelatedVideoInCurrentVC ? "页面刷新" : "新页面中打开",
                        options: [true, false],
                        optionString: ["页面刷新", "新页面中打开"])
                {
                    Settings.showRelatedVideoInCurrentVC = $0
                }
            }

            SectionModel(title: "推荐") {
                Toggle(title: "使用沉浸式浏览模式",
                       setting: Settings.recommendFeedFlowEnabled,
                       onChange: Settings.recommendFeedFlowEnabled.toggle())
                Actions(title: "沉浸式视频时长上限", message: "用于筛选沉浸式推荐中的短视频",
                        current: Settings.featuredDurationLimit.title,
                        options: FeaturedDurationLimit.allCases,
                        optionString: FeaturedDurationLimit.allCases.map { $0.title })
                {
                    Settings.featuredDurationLimit = $0
                }
                Toggle(title: "沉浸式推荐内容安全过滤",
                       setting: Settings.featuredContentSafetyFilterEnabled,
                       onChange: Settings.featuredContentSafetyFilterEnabled.toggle())
            }

            SectionModel(title: "关注页面") {
                Toggle(title: "关注刷视频模式",
                       setting: Settings.followsFeedFlowEnabled,
                       onChange: Settings.followsFeedFlowEnabled.toggle())
                { _ in
                    NotificationCenter.default.post(name: .followsLayoutModeDidChange, object: nil)
                }
            }

            SectionModel(title: "音视频") {
                Actions(title: "最高画质", message: "4k以上需要大会员",
                        current: Settings.mediaQuality.desp,
                        options: MediaQualityEnum.allCases,
                        optionString: MediaQualityEnum.allCases.map({ $0.desp }))
                {
                    Settings.mediaQuality = $0
                }
                Actions(title: "默认播放速度", message: "默认设置为1.0",
                        current: Settings.mediaPlayerSpeed.name,
                        options: PlaySpeed.blDefaults,
                        optionString: PlaySpeed.blDefaults.map({ $0.name }))
                {
                    Settings.mediaPlayerSpeed = $0
                }
                Toggle(title: "Avc优先(卡顿尝试开启)", setting: Settings.preferAvc, onChange: Settings.preferAvc.toggle())
                Toggle(title: "多 CDN 并发加速", setting: Settings.multiCDNEnabled, onChange: Settings.multiCDNEnabled.toggle())
                Toggle(title: "无损音频和杜比全景声", setting: Settings.losslessAudio, onChange: Settings.losslessAudio.toggle())
                Toggle(title: "匹配视频内容", setting: Settings.contentMatch, onChange: Settings.contentMatch.toggle())
                Toggle(title: "仅在HDR视频匹配视频内容", setting: Settings.contentMatchOnlyInHDR, onChange: Settings.contentMatchOnlyInHDR.toggle())
            }

            SectionModel(title: "进度控制") {
                Toggle(title: "从上次退出的位置继续播放", setting: Settings.continuePlay, onChange: Settings.continuePlay.toggle())
                Toggle(title: "自动跳过片头片尾", setting: Settings.autoSkip, onChange: Settings.autoSkip.toggle())
                Toggle(title: "连续播放", setting: Settings.continouslyPlay, onChange: Settings.continouslyPlay.toggle())
                Actions(title: "空降助手广告屏蔽", message: "",
                        current: Settings.enableSponsorBlock.title,
                        options: SponsorBlockType.allCases,
                        optionString: SponsorBlockType.allCases.map({ $0.title }))
                {
                    Settings.enableSponsorBlock = $0
                }
            }

            SectionModel(title: "弹幕") {
                Toggle(title: "用户自定义弹幕屏蔽", setting: Settings.enableDanmuFilter, onChange: Settings.enableDanmuFilter.toggle()) {
                    enable in
                    if enable {
                        Task {
                            let toast = await VideoDanmuFilter.shared.update()
                            let alert = UIAlertController(title: "同步结果", message: toast, preferredStyle: .alert)
                            alert.addAction(.init(title: "Ok", style: .cancel))
                            self.present(alert, animated: true)
                        }
                    }
                }
                Toggle(title: "移除重复弹幕", setting: Settings.enableDanmuRemoveDup, onChange: Settings.enableDanmuRemoveDup.toggle())
                Actions(title: "弹幕大小", message: "默认为36", current: Settings.danmuSize.title, options: DanmuSize.allCases, optionString: DanmuSize.allCases.map({ $0.title })) {
                    Settings.danmuSize = $0
                }
                Actions(title: "弹幕显示区域", message: "设置弹幕显示区域",
                        current: Settings.danmuArea.title,
                        options: DanmuArea.allCases,
                        optionString: DanmuArea.allCases.map({ $0.title }))
                {
                    Settings.danmuArea = $0
                }
                Toggle(title: "智能防档弹幕", setting: Settings.danmuMask, onChange: Settings.danmuMask.toggle())
                Toggle(title: "按需本地运算智能防档弹幕(Exp)", setting: Settings.vnMask, onChange: Settings.vnMask.toggle())

                // 添加弹幕透明度设置
                Actions(title: "弹幕透明度", message: "调整弹幕的透明度",
                        current: Settings.danmuAlpha.title,
                        options: DanmuAlpha.allCases,
                        optionString: DanmuAlpha.allCases.map({ $0.title }))
                { value in
                    Settings.danmuAlpha = value
                }

                // 添加弹幕描边宽度设置
                Actions(title: "弹幕描边宽度", message: "调整弹幕描边的粗细",
                        current: Settings.danmuStrokeWidth.title,
                        options: DanmuStrokeWidth.allCases,
                        optionString: DanmuStrokeWidth.allCases.map({ $0.title }))
                { value in
                    Settings.danmuStrokeWidth = value
                }

                // 添加弹幕描边透明度设置
                Actions(title: "弹幕描边透明度", message: "调整弹幕描边的透明度",
                        current: Settings.danmuStrokeAlpha.title,
                        options: DanmuStrokeAlpha.allCases,
                        optionString: DanmuStrokeAlpha.allCases.map({ $0.title }))
                { value in
                    Settings.danmuStrokeAlpha = value
                }
            }

            SectionModel(title: "港澳台解锁") {
                Toggle(title: "解锁港澳台番剧限制", setting: Settings.areaLimitUnlock, onChange: Settings.areaLimitUnlock.toggle())
                TextField(title: "设置港澳台解析服务器", message: "为了安全考虑建议自建服务器，公共服务器可用性难保证，请多尝试几个。\n公共服务器请参考：http://985.so/mjq9u", current: Settings.areaLimitCustomServer, placeholder: "api.example.com") {
                    Settings.areaLimitCustomServer = $0 ?? ""
                }
            }
        }
    }
}

extension SettingsViewController {
    func Toggle(title: String, setting: @autoclosure @escaping () -> Bool,
                onChange: @autoclosure @escaping () -> Void,
                extraAction: ((Bool) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: setting() ? "开" : "关") {
            update in
            onChange()
            extraAction?(setting())
            update()
        }
    }

    func Actions<T>(title: String,
                    message: String?,
                    current: @autoclosure @escaping () -> String,
                    options: [T],
                    optionString: [String],
                    onSelect: ((T) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: current()) { [weak self] update in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

            for (idx, string) in optionString.enumerated() {
                let action = UIAlertAction(title: string, style: .default) { _ in
                    onSelect?(options[idx])
                    update()
                }
                alert.addAction(action)
            }
            let cancelAction = UIAlertAction(title: nil, style: .cancel)
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
    }

    func TextField(title: String,
                   message: String?,
                   current: String,
                   placeholder: String?,
                   isSecureTextEntry: Bool = false,
                   onSubmit: ((String?) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: current) { [weak self] update in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = current
                textField.keyboardType = .URL
                textField.placeholder = placeholder
                textField.isSecureTextEntry = isSecureTextEntry
            }

            let action = UIAlertAction(title: "确定", style: .default) { _ in
                onSubmit?(alert.textFields![0].text)
                update()
            }
            alert.addAction(action)

            let cancelAction = UIAlertAction(title: nil, style: .cancel)
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
    }

    func Navigation(title: String,
                    desp: @autoclosure @escaping () -> String,
                    onSelect: (() -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: desp(), showsChevron: true) { update in
            onSelect?()
            update()
        }
    }
}

extension SettingsViewController: UICollectionViewDelegate {
    private func createSnapshot(@ArrayBuilder<SectionModel> builder: () -> [SectionModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<SectionModel, CellModel>()
        for section in builder() {
            snapshot.appendSections([section])
            snapshot.appendItems(section.items, toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cellModel = dataSource.itemIdentifier(for: indexPath)!
        cellModel.action?() { [weak cellModel] in
            cellModel?.updateAction?()
        }
    }
}

/// 设置行：深灰胶囊，聚焦时整行变白（Apple TV 系统设置样式）
class SettingsSwitchCell: BLMotionCollectionViewCell {
    /// Apple TV 系统设置实测：行高 66、间距 14；聚焦时白色胶囊比行高出 9（上下各 4.5）
    static let rowHeight: CGFloat = 66
    private static let focusOutset: CGFloat = 4.5

    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let chevronView = UIImageView()
    private let pillView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(with model: SettingsViewController.CellModel) {
        titleLabel.text = model.title
        descLabel.text = model.desp()
        descLabel.isHidden = descLabel.text?.isEmpty ?? true
        chevronView.isHidden = !model.showsChevron
        model.updateAction = { [weak self] in
            self?.descLabel.text = model.desp()
            self?.descLabel.isHidden = self?.descLabel.text?.isEmpty ?? true
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 不缩放，只用白色胶囊表达焦点；外扩随焦点动画一起过渡
        coordinator.addCoordinatedAnimations {
            self.updateColor()
            self.contentView.layoutIfNeeded()
        }
    }

    func setupView() {
        pillView.backgroundColor = Self.normalBackground
        pillView.layer.cornerRadius = Self.rowHeight / 2
        pillView.layer.cornerCurve = .continuous
        contentView.addSubview(pillView)
        pillView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(0)
        }

        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(chevronView)

        // 系统设置里的箭头与文字同高（约 38pt 字号）
        chevronView.image = UIImage(systemName: "chevron.right",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 38, weight: .medium))
        chevronView.contentMode = .scaleAspectFit
        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.font = .App.rowTitle
        descLabel.font = .App.rowTitle

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(descLabel.snp.leading).offset(-20)
        }

        descLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-32)
            make.centerY.equalToSuperview()
        }

        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-32)
            make.centerY.equalToSuperview()
        }

        descLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        updateColor()
    }

    private static let normalBackground = UIColor(white: 1, alpha: 0.1)

    func updateColor() {
        let focused = isFocused
        // 聚焦时白色胶囊四周各外扩 4，圆角保持胶囊形（与系统设置一致）
        pillView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(focused ? -Self.focusOutset : 0)
        }
        pillView.layer.cornerRadius = (Self.rowHeight + (focused ? Self.focusOutset * 2 : 0)) / 2
        pillView.backgroundColor = focused ? .white : Self.normalBackground
        titleLabel.textColor = focused ? .black : .white
        descLabel.textColor = focused ? .black : .secondaryLabel
        chevronView.tintColor = focused ? .black : .secondaryLabel
    }
}

class SettingsHeaderView: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(label)
        label.font = .App.sectionTitle
        label.textColor = UIColor.secondaryLabel
        // 与行内文字左对齐
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
}

extension FeedDisplayStyle {
    var desp: String {
        switch self {
        case .large:
            return "3个"
        case .normal:
            return "4个"
        case .sideBar:
            return "-"
        }
    }
}
