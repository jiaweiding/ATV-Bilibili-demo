//
//  VideoDetailViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/17.
//

import AVKit
import Foundation
import UIKit

import Alamofire
import Kingfisher
import SnapKit

private struct PageRange {
    let startIndex: Int
    let endIndex: Int

    var title: String {
        "\(startIndex + 1) - \(endIndex + 1)"
    }
}

/// 元信息行里的一项：图标 + 文字，两者一起居中
private class MetaItemView: UIStackView {
    let label = UILabel()

    init(icon: String?) {
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .center
        spacing = 10
        if let icon {
            let imageView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 27, weight: .medium)))
            imageView.tintColor = UIColor(named: "titleColor")
            imageView.contentMode = .scaleAspectFit
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
            addArrangedSubview(imageView)
        }
        label.font = .App.body
        label.textColor = UIColor(named: "titleColor")
        addArrangedSubview(label)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class VideoDetailViewController: UIViewController {
    /// 合集 / 推荐视频一行里每张卡片多宽
    private static let rowCardWidth: CGFloat = 360

    // 背景
    private let backgroundImageView = UIImageView()
    private let effectContainerView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    // 头部
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let coverImageView = UIImageView()
    private let upButton = BLCustomTextButton()
    private let followButton = BLCustomButton()
    private let followersLabel = UILabel()
    private let noteView = NoteDetailView()
    private let playCountItem = MetaItemView(icon: "play.square")
    private let durationItem = MetaItemView(icon: "clock")
    private let uploadTimeItem = MetaItemView(icon: nil)
    private let bvidItem = MetaItemView(icon: nil)
    private let upRowView = UIStackView()
    private let metaRowView = UIStackView()

    // 操作按钮
    private let actionRowView = UIView()
    private let playButton = BLCustomButton()
    private let likeButton = BLCustomButton()
    private let coinButton = BLCustomButton()
    private let favButton = BLCustomButton()
    private let dislikeButton = BLCustomButton()
    private let actionButtonSpaceView = UIView()

    // 视频选集 / 合集 / 推荐视频 / 评论
    private let pageView = UIView()
    private let pageTitleLabel = UILabel()
    private let ugcView = UIView()
    private let ugcLabel = UILabel()
    private let relatedView = UIView()
    private let relatedLabel = UILabel()
    private let commentsView = UIView()
    private let commentsTitleLabel = UILabel()

    private let loadingView = UIActivityIndicatorView()

    private lazy var pageCollectionView: UICollectionView = makeCollectionView(layout: makePageCollectionViewLayout())
    private lazy var ugcCollectionView: UICollectionView = makeCollectionView(layout: makeFeedRowLayout(cardShowsOwnerLine: false))
    private lazy var recommandCollectionView: UICollectionView = makeCollectionView(layout: makeFeedRowLayout(cardShowsOwnerLine: true))
    private lazy var pageRangeCollectionView: UICollectionView = makeCollectionView(layout: makePageRangeCollectionViewLayout())

    private var pageCollectionViewTopToTitleConstraint: Constraint?
    private var pageCollectionViewTopToRangeConstraint: Constraint?
    private let pageRangeSize = 20
    private var pageRanges = [PageRange]()

    private var epid = 0
    private var seasonId = 0
    private var aid = 0
    private var cid = 0
    private var lastPlayCid: Int?
    private var lastPlayTitle: String?
    private var playTimeInSecond: Int?
    private var subType: Int?
    private var data: VideoDetail?
    private var didSentCoins = 0 {
        didSet {
            if didSentCoins > 0 {
                coinButton.isOn = true
            }
        }
    }

    private var isBangumi = false
    private var pages = [VideoPage]()
    private var replys: Replys?
    /// 评论区的竖排列表
    private let repliesStackView = UIStackView()

    private var allUgcEpisodes = [VideoDetail.Info.UgcSeason.UgcVideoInfo]()

    static func create(aid: Int, cid: Int?, epid: Int? = nil) -> VideoDetailViewController {
        let vc = VideoDetailViewController()
        vc.aid = aid
        vc.cid = cid ?? 0
        vc.epid = epid ?? 0
        return vc
    }

    static func create(epid: Int) -> VideoDetailViewController {
        let vc = VideoDetailViewController()
        vc.epid = epid
        return vc
    }

    static func create(seasonId: Int) -> VideoDetailViewController {
        let vc = VideoDetailViewController()
        vc.seasonId = seasonId
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActionRow()
        setupFocusGuides()
        setupCommentsSection()

        Task { await fetchData() }
    }

    override var preferredFocusedView: UIView? {
        return playButton
    }

    // MARK: - 布局

    private func setupViews() {
        view.backgroundColor = .black

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        view.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(effectContainerView)
        effectContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.contentInsetAdjustmentBehavior = .never
        effectContainerView.contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.axis = .vertical
        scrollView.addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        setupHeader()
        setupActionRow()
        contentStackView.addArrangedSubview(headerView)
        contentStackView.addArrangedSubview(actionRowView)
        contentStackView.setCustomSpacing(20, after: actionRowView)
        setupPageSection()
        setupUgcSection()
        setupRelatedSection()
        setupCommentsSection()
    }

    private func setupHeader() {
        titleLabel.font = .App.pageTitle
        titleLabel.numberOfLines = 2
        titleLabel.textColor = UIColor(named: "titleColor")
        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(headerView.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalTo(headerView.safeAreaLayoutGuide)
        }

        // 封面：右上角，高度和头部一起收在简介下面
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = BLCornerRadius.little
        coverImageView.layer.cornerCurve = .continuous
        headerView.addSubview(coverImageView)
        coverImageView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.trailing.equalTo(headerView.safeAreaLayoutGuide.snp.trailing)
            make.height.equalTo(350)
            make.width.equalTo(coverImageView.snp.height).multipliedBy(16.0 / 9)
            make.bottom.lessThanOrEqualToSuperview()
        }

        followButton.image = UIImage(systemName: "heart")
        followButton.onImage = UIImage(systemName: "heart.fill")
        followButton.addTarget(self, action: #selector(actionFollow(_:)), for: .primaryActionTriggered)
        followButton.snp.makeConstraints { make in
            make.width.height.equalTo(80)
        }

        followersLabel.font = .App.body
        followersLabel.textColor = UIColor(named: "titleColor")
        followersLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        upButton.titleColor = UIColor(named: "titleColor") ?? .white
        upButton.addTarget(self, action: #selector(actionShowUpSpace(_:)), for: .primaryActionTriggered)

        upRowView.axis = .horizontal
        upRowView.alignment = .center
        upRowView.spacing = 16
        upRowView.addArrangedSubview(upButton)
        upRowView.addArrangedSubview(followButton)
        upRowView.addArrangedSubview(followersLabel)
        upRowView.snp.makeConstraints { make in
            make.height.equalTo(120)
        }

        metaRowView.axis = .horizontal
        metaRowView.alignment = .center
        metaRowView.spacing = 30
        for item in [playCountItem, durationItem, uploadTimeItem, bvidItem] {
            metaRowView.addArrangedSubview(item)
        }

        noteView.onPrimaryAction = {
            [weak self] note in
            let detail = ContentDetailViewController.createDesp(content: note.label.text ?? "")
            self?.present(detail, animated: true)
        }
        noteView.snp.makeConstraints { make in
            make.width.equalTo(880)
        }

        let leftColumnView = UIStackView(arrangedSubviews: [upRowView, metaRowView, noteView])
        leftColumnView.axis = .vertical
        leftColumnView.alignment = .leading
        leftColumnView.spacing = 24
        leftColumnView.setCustomSpacing(10, after: metaRowView)
        headerView.addSubview(leftColumnView)
        leftColumnView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.equalTo(headerView.safeAreaLayoutGuide.snp.leading)
            make.bottom.equalToSuperview().offset(-40)
        }
    }

    /// 操作按钮：五个按钮各自是一座 Liquid Glass 胶囊，图标和播放量/点赞数并排放在胶囊里
    private func setupActionRow() {
        for button in [playButton, likeButton, coinButton, favButton, dislikeButton] {
            button.contentLayout = .horizontal
            button.titleColor = UIColor(named: "titleColor") ?? .white
        }
        playButton.image = UIImage(systemName: "play")
        playButton.highLightImage = UIImage(systemName: "play.fill")
        playButton.title = "播放"
        playButton.addTarget(self, action: #selector(actionPlay(_:)), for: .primaryActionTriggered)

        likeButton.image = UIImage(systemName: "hand.thumbsup")
        likeButton.onImage = UIImage(systemName: "hand.thumbsup.fill")
        likeButton.addTarget(self, action: #selector(actionLike(_:)), for: .primaryActionTriggered)
        coinButton.image = UIImage(systemName: "bitcoinsign.circle")
        coinButton.onImage = UIImage(systemName: "bitcoinsign.circle.fill")
        coinButton.addTarget(self, action: #selector(actionCoin(_:)), for: .primaryActionTriggered)
        favButton.image = UIImage(systemName: "star")
        favButton.onImage = UIImage(systemName: "star.fill")
        favButton.addTarget(self, action: #selector(actionFavorite(_:)), for: .primaryActionTriggered)
        dislikeButton.image = UIImage(systemName: "hand.thumbsdown")
        dislikeButton.onImage = UIImage(systemName: "hand.thumbsdown.fill")
        dislikeButton.title = "不喜欢"
        dislikeButton.addTarget(self, action: #selector(actionDislike(_:)), for: .primaryActionTriggered)

        let buttonsStackView = UIStackView(arrangedSubviews: [playButton, likeButton, coinButton, favButton, dislikeButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.alignment = .center
        buttonsStackView.spacing = 16
        playButton.snp.makeConstraints { make in
            make.width.equalTo(240)
        }
        for button in [likeButton, coinButton, favButton, dislikeButton] {
            button.snp.makeConstraints { make in
                make.width.equalTo(200)
            }
        }

        actionRowView.addSubview(buttonsStackView)
        buttonsStackView.snp.makeConstraints { make in
            make.leading.equalTo(actionRowView.safeAreaLayoutGuide.snp.leading)
            make.centerY.equalToSuperview()
            make.height.equalTo(88)
        }
        actionButtonSpaceView.snp.makeConstraints { make in
            make.height.equalTo(88)
        }
        actionRowView.addSubview(actionButtonSpaceView)
        actionButtonSpaceView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(buttonsStackView.snp.trailing)
            make.trailing.equalToSuperview()
        }
        actionRowView.snp.makeConstraints { make in
            make.height.equalTo(88)
        }
    }

    private func setupPageSection() {
        pageTitleLabel.font = .App.pageTitle
        pageTitleLabel.textColor = UIColor(named: "titleColor")
        pageTitleLabel.text = "视频选集"
        pageView.addSubview(pageTitleLabel)
        pageTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.equalTo(pageView.layoutMarginsGuide.snp.leading)
        }

        pageRangeCollectionView.isHidden = true
        pageView.addSubview(pageRangeCollectionView)
        pageRangeCollectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(90)
        }

        pageView.addSubview(pageCollectionView)
        pageCollectionView.snp.makeConstraints { make in
            pageCollectionViewTopToTitleConstraint = make.top.equalTo(pageTitleLabel.snp.bottom).offset(30).constraint
            pageCollectionViewTopToRangeConstraint = make.top.equalTo(pageRangeCollectionView.snp.bottom).offset(30).constraint
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(150)
            make.bottom.equalToSuperview().offset(-20)
        }
        pageCollectionViewTopToRangeConstraint?.deactivate()
        contentStackView.addArrangedSubview(pageView)
    }

    private func setupUgcSection() {
        ugcLabel.font = .App.pageTitle
        ugcLabel.textColor = UIColor(named: "titleColor")
        ugcView.addSubview(ugcLabel)
        ugcLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalTo(ugcView.layoutMarginsGuide.snp.leading)
        }

        ugcView.addSubview(ugcCollectionView)
        ugcCollectionView.snp.makeConstraints { make in
            make.top.equalTo(ugcLabel.snp.bottom).offset(40)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.rowHeight(cardShowsOwnerLine: false))
            make.bottom.equalToSuperview().offset(-20)
        }
        contentStackView.addArrangedSubview(ugcView)
    }

    private func setupRelatedSection() {
        relatedLabel.font = .App.pageTitle
        relatedLabel.textColor = UIColor(named: "titleColor")
        relatedLabel.text = "推荐视频"
        relatedView.addSubview(relatedLabel)
        relatedLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(relatedView.layoutMarginsGuide.snp.leading)
        }

        relatedView.addSubview(recommandCollectionView)
        recommandCollectionView.snp.makeConstraints { make in
            make.top.equalTo(relatedLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.rowHeight(cardShowsOwnerLine: true))
            make.bottom.equalToSuperview().offset(-20)
        }
        contentStackView.addArrangedSubview(relatedView)
    }

    /// 评论区：标题下面是一列竖排的评论卡片
    private func setupCommentsSection() {
        commentsTitleLabel.font = .App.pageTitle
        commentsTitleLabel.textColor = UIColor(named: "titleColor")
        commentsTitleLabel.text = "热门评论"
        commentsView.addSubview(commentsTitleLabel)
        commentsTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(commentsView.layoutMarginsGuide.snp.leading)
        }

        repliesStackView.axis = .vertical
        repliesStackView.spacing = 24
        commentsView.addSubview(repliesStackView)
        repliesStackView.snp.makeConstraints { make in
            make.top.equalTo(commentsTitleLabel.snp.bottom).offset(20)
            make.leading.equalTo(commentsTitleLabel.snp.leading)
            make.trailing.equalTo(commentsView.layoutMarginsGuide.snp.trailing)
            make.bottom.equalToSuperview().offset(-20)
        }
        contentStackView.addArrangedSubview(commentsView)
    }

    private func setupFocusGuides() {
        let followGuide = UIFocusGuide()
        view.addLayoutGuide(followGuide)
        NSLayoutConstraint.activate([
            followGuide.topAnchor.constraint(equalTo: upButton.topAnchor),
            followGuide.leftAnchor.constraint(equalTo: followButton.rightAnchor),
            followGuide.rightAnchor.constraint(equalTo: coverImageView.leftAnchor),
            followGuide.bottomAnchor.constraint(equalTo: upButton.bottomAnchor),
        ])
        followGuide.preferredFocusEnvironments = [followButton]

        let actionGuide = UIFocusGuide()
        view.addLayoutGuide(actionGuide)
        NSLayoutConstraint.activate([
            actionGuide.topAnchor.constraint(equalTo: actionButtonSpaceView.topAnchor),
            actionGuide.leftAnchor.constraint(equalTo: actionButtonSpaceView.leftAnchor),
            actionGuide.rightAnchor.constraint(equalTo: actionButtonSpaceView.rightAnchor),
            actionGuide.bottomAnchor.constraint(equalTo: actionButtonSpaceView.bottomAnchor),
        ])
        actionGuide.preferredFocusEnvironments = [dislikeButton]
    }

    private func makeCollectionView(layout: UICollectionViewLayout) -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(FeedCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: FeedCollectionViewCell.self))
        collectionView.register(BLTextOnlyCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: BLTextOnlyCollectionViewCell.self))
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        return collectionView
    }

    private func setupLoading() {
        effectContainerView.isHidden = true
        view.addSubview(loadingView)
        loadingView.color = .white
        loadingView.style = .large
        loadingView.startAnimating()
        loadingView.makeConstraintsBindToCenterOfSuperview()
    }

    func present(from vc: UIViewController, direatlyEnterVideo: Bool = Settings.direatlyEnterVideo) {
        if !direatlyEnterVideo {
            vc.present(self, animated: true)
        } else {
            vc.present(self, animated: false) { [weak self] in
                guard let self else { return }
                let player = VideoPlayerViewController(playInfo: PlayInfo(aid: self.aid, cid: self.cid, epid: self.epid, seasonId: isBangumi ? self.seasonId : nil, lastPlayCid: self.lastPlayCid, playTimeInSecond: self.playTimeInSecond))
                self.present(player, animated: true)
            }
        }
    }

    private func exit(with error: Error) {
        Logger.warn(error)
        let alertVC = UIAlertController(title: "获取失败", message: error.localizedDescription, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { [weak self] action in
            self?.dismiss(animated: true)
        }))
        present(alertVC, animated: true, completion: nil)
    }

    private func updatePlayProgressIfNeeded(progress: BangumiInfo.UserStatus.Progress?, episode: BangumiInfo.Episode) {
        guard let lastEpId = progress?.last_ep_id,
              let lastTime = progress?.last_time,
              lastEpId == episode.id
        else {
            return
        }
        playTimeInSecond = lastTime
        lastPlayCid = episode.cid
        lastPlayTitle = episode.title + " " + episode.long_title
    }

    private func updatePageRanges() {
        guard pages.count >= pageRangeSize else {
            pageRanges = []
            setPageRangeCollectionViewHidden(true)
            return
        }

        pageRanges = stride(from: 0, to: pages.count, by: pageRangeSize).map { startIndex in
            PageRange(startIndex: startIndex, endIndex: min(startIndex + pageRangeSize, pages.count) - 1)
        }
        setPageRangeCollectionViewHidden(false)
    }

    private func setPageRangeCollectionViewHidden(_ isHidden: Bool) {
        pageRangeCollectionView.isHidden = isHidden
        if isHidden {
            pageCollectionViewTopToRangeConstraint?.deactivate()
            pageCollectionViewTopToTitleConstraint?.activate()
        } else {
            pageCollectionViewTopToTitleConstraint?.deactivate()
            pageCollectionViewTopToRangeConstraint?.activate()
        }
    }

    private func updateComments() {
        repliesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let replies = replys?.replies ?? []
        for reply in replies {
            let row = ReplyRowView()
            row.config(reply: reply)
            row.onPrimaryAction = { [weak self] _ in
                self?.present(ReplyDetailViewController(reply: reply), animated: true)
            }
            repliesStackView.addArrangedSubview(row)
        }
        commentsView.isHidden = replies.isEmpty
    }

    private func fetchData() async {
        scrollView.setContentOffset(.zero, animated: false)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        backgroundImageView.alpha = 0
        setupLoading()
        pageView.isHidden = true
        setPageRangeCollectionViewHidden(true)
        ugcView.isHidden = true
        do {
            if seasonId > 0 {
                isBangumi = true
                let info = try await WebRequest.requestBangumiInfo(seasonID: seasonId)
                subType = info.type
                if let epi = info.episodes.first(where: { $0.id == info.user_status?.progress?.last_ep_id }) ?? info.episodes.first ?? info.section?.first?.episodes.first {
                    aid = epi.aid
                    cid = epi.cid
                    epid = epi.id
                    updatePlayProgressIfNeeded(progress: info.user_status?.progress, episode: epi)
                }
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.id, from: "", part: $0.title + " " + $0.long_title) })
            } else if epid > 0 {
                isBangumi = true
                let info = try await WebRequest.requestBangumiInfo(epid: epid)
                seasonId = info.season_id
                subType = info.type
                if let epi = info.findEpisodeById(epid) ?? info.episodes.first {
                    aid = epi.aid
                    cid = epi.cid
                    updatePlayProgressIfNeeded(progress: info.user_status?.progress, episode: epi)
                } else {
                    throw NSError(domain: "get epi fail", code: -1)
                }
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.id, from: "", part: $0.title + " " + $0.long_title) })
            }
            let data = try await WebRequest.requestDetailVideo(aid: aid)
            self.data = data

            if let redirect = data.View.redirect_url?.lastPathComponent, redirect.starts(with: "ep"), let id = Int(redirect.dropFirst(2)), !isBangumi {
                isBangumi = true
                epid = id
                let info = try await WebRequest.requestBangumiInfo(epid: epid)
                seasonId = info.season_id
                subType = info.type
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.id, from: "", part: $0.title + " " + $0.long_title) })
                if let epi = info.episodes.first(where: { $0.id == epid }) {
                    updatePlayProgressIfNeeded(progress: info.user_status?.progress, episode: epi)
                }
            }
            if !isBangumi {
                let playInfo = try await WebRequest.requestPlayerInfo(aid: aid, cid: cid == 0 ? data.View.cid : cid)
                if cid == 0 {
                    cid = playInfo.last_play_cid > 0 ? playInfo.last_play_cid : data.View.cid
                }
                if playInfo.last_play_cid == cid, let page = data.View.pages?.first(where: { $0.cid == cid }) {
                    playTimeInSecond = playInfo.playTimeInSecond
                    lastPlayCid = playInfo.last_play_cid
                    lastPlayTitle = page.part
                }
            }
            update(with: data)
        } catch let err {
            if case let .statusFail(code, _) = err as? RequestError, code == -404 {
                // 解锁港澳台番剧处理
                if let ok = await fetchAreaLimitBangumiData(), !ok {
                    self.exit(with: err)
                }
            } else {
                self.exit(with: err)
            }
        }

        WebRequest.requestReplys(aid: aid) { [weak self] replys in
            self?.replys = replys
            self?.updateComments()
        }

        WebRequest.requestLikeStatus(aid: aid) { [weak self] isLiked in
            self?.likeButton.isOn = isLiked
        }

        WebRequest.requestCoinStatus(aid: aid) { [weak self] coins in
            self?.didSentCoins = coins
        }

        if isBangumi {
            favButton.isHidden = true
            relatedView.isHidden = true
            return
        }

        WebRequest.requestFavoriteStatus(aid: aid) { [weak self] isFavorited in
            self?.favButton.isOn = isFavorited
        }
    }

    private func fetchAreaLimitBangumiData() async -> Bool? {
        guard Settings.areaLimitUnlock else { return false }

        do {
            var info: ApiRequest.BangumiInfo?

            if seasonId > 0 {
                info = try await ApiRequest.requestBangumiInfo(seasonID: seasonId)
            } else if epid > 0 {
                info = try await ApiRequest.requestBangumiInfo(epid: epid)
            }
            guard let info else { return false }

            let season = try await WebRequest.requestBangumiSeasonView(seasonID: info.season_id)
            isBangumi = true
            if let epi = season.episodes.first(where: { $0.ep_id == epid }) ?? season.episodes.first {
                aid = epi.aid
                cid = epi.cid
                pages = season.episodes.filter { $0.section_type == 0 }.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.ep_id, from: "", part: $0.index + " " + ($0.index_title ?? "")) })

                let userEpisodeInfo = try await WebRequest.requestUserEpisodeInfo(epid: epi.ep_id)

                let data = VideoDetail(View: VideoDetail.Info(aid: aid, cid: cid, title: info.title, videos: nil, pic: epi.cover, desc: info.evaluate, owner: VideoOwner(mid: season.up_info.mid, name: season.up_info.uname, face: season.up_info.avatar), pages: nil, dynamic: nil, bvid: epi.bvid, duration: epi.durationSeconds, pubdate: epi.pubdate, ugc_season: nil, redirect_url: nil, stat: VideoDetail.Info.Stat(favorite: info.stat.favorites, coin: info.stat.coins, like: info.stat.likes, share: info.stat.share, danmaku: info.stat.danmakus, view: info.stat.views)), Related: [], Card: VideoDetail.Owner(following: userEpisodeInfo.related_up.first?.is_follow == 1, follower: season.up_info.follower))

                self.data = data
                update(with: data)
                return true
            }

        } catch let err {
            print(err)
        }

        return false
    }

    private func update(with data: VideoDetail) {
        playCountItem.label.text = data.View.stat.view.numberString()
        followersLabel.text = (data.Card.follower ?? 0).numberString() + "粉丝"
        uploadTimeItem.label.text = data.View.date
        bvidItem.label.text = data.View.bvid
        coinButton.title = data.View.stat.coin.numberString()
        favButton.title = data.View.stat.favorite.numberString()
        likeButton.title = data.View.stat.like.numberString()

        durationItem.label.text = data.View.durationString
        titleLabel.text = data.title
        upButton.title = data.ownerName
        followButton.isOn = data.Card.following

        // 更新播放按钮标题
        if Settings.continuePlay {
            if let lastPlayCid, lastPlayCid == cid {
                playButton.title = "继续播放"
            } else {
                playButton.title = "播放"
            }
        }

        upButton.avatarURL = data.avatar(size: 240)

        coverImageView.kf.setImage(with: data.pic)
        backgroundImageView.kf.setImage(with: data.pic)
        relatedView.isHidden = data.Related.count == 0

        var notes = [String]()
        let status = data.View.dynamic ?? ""
        if status.count > 1, status != data.View.desc {
            notes.append(status)
        }
        notes.append(data.View.desc ?? "")
        noteView.label.text = notes.joined(separator: "\n")
        if !isBangumi {
            pages = data.View.pages ?? []
        }
        updatePageRanges()
        pageRangeCollectionView.reloadData()
        if pages.count > 1 {
            pageCollectionView.reloadData()
            pageView.isHidden = false
            let index = pages.firstIndex { $0.cid == cid } ?? 0
            pageCollectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .left, animated: false)
            if cid == 0 {
                cid = pages.first?.cid ?? 0
            }
        }
        loadingView.stopAnimating()
        loadingView.removeFromSuperview()
        effectContainerView.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.backgroundImageView.alpha = 1
        }

        if let season = data.View.ugc_season {
            if season.sections.count > 1 {
                if let section = season.sections.first(where: { section in section.episodes.contains(where: { episode in episode.aid == data.View.aid }) }) {
                    allUgcEpisodes = section.episodes
                }
            } else {
                allUgcEpisodes = season.sections.first?.episodes ?? []
            }
            allUgcEpisodes.sort { $0.arc.ctime < $1.arc.ctime }
        }

        ugcCollectionView.reloadData()
        ugcLabel.text = "合集 \(data.View.ugc_season?.title ?? "")  \(data.View.ugc_season?.sections.first?.title ?? "")"
        ugcView.isHidden = allUgcEpisodes.count == 0
        if allUgcEpisodes.count > 0 {
            ugcCollectionView.scrollToItem(at: IndexPath(item: allUgcEpisodes.map { $0.aid }.firstIndex(of: aid) ?? 0, section: 0), at: .left, animated: false)
        }

        recommandCollectionView.reloadData()
    }

    // MARK: - Actions

    @IBAction func actionShowUpSpace(_ sender: Any) {
        let upSpaceVC = UpSpaceViewController()
        upSpaceVC.mid = data?.View.owner.mid
        present(upSpaceVC, animated: true)
    }

    @IBAction func actionFollow(_ sender: Any) {
        followButton.isOn.toggle()
        if let mid = data?.View.owner.mid {
            WebRequest.follow(mid: mid, follow: followButton.isOn)
        }
    }

    @IBAction func actionPlay(_ sender: Any) {
        let player = VideoPlayerViewController(playInfo: PlayInfo(aid: aid, cid: cid, epid: epid, seasonId: seasonId, subType: subType, lastPlayCid: lastPlayCid, playTimeInSecond: playTimeInSecond, title: data?.title))
        player.data = data
        if pages.count > 0, let index = pages.firstIndex(where: { $0.cid == cid }) {
            let seq = pages.map({ PlayInfo(aid: aid, cid: $0.cid, epid: $0.epid, seasonId: seasonId, subType: subType, title: $0.part) })
            if seq.count > 0 {
                player.sequenceProvider = VideoSequenceProvider(seq: seq, currentIndex: index)
            }
        }
        if allUgcEpisodes.count > 0, let index = allUgcEpisodes.firstIndex(where: { $0.cid == cid }) {
            let seq = allUgcEpisodes.map({ PlayInfo(aid: $0.aid, cid: $0.cid, title: $0.title) })
            if seq.count > 0 {
                player.sequenceProvider = VideoSequenceProvider(seq: seq, currentIndex: index)
            }
        }
        present(player, animated: true, completion: nil)
    }

    @IBAction func actionLike(_ sender: Any) {
        Task {
            if likeButton.isOn {
                likeButton.title? -= 1
            } else {
                likeButton.title? += 1
            }
            likeButton.isOn.toggle()
            let success = await WebRequest.requestLike(aid: aid, like: likeButton.isOn)
            if !success {
                likeButton.isOn.toggle()
            }
        }
    }

    @IBAction func actionCoin(_ sender: Any) {
        guard didSentCoins < 2 else { return }
        let alert = UIAlertController(title: "投币个数", message: nil, preferredStyle: .actionSheet)
        WebRequest.requestTodayCoins { todayCoins in
            alert.message = "今日已投(\(todayCoins / 10)/5)个币"
        }
        let aid = aid
        alert.addAction(UIAlertAction(title: "1", style: .default) { [weak self] _ in
            guard let self else { return }
            self.coinButton.title? += 1
            if !self.likeButton.isOn {
                self.likeButton.title? += 1
                self.likeButton.isOn = true
            }
            self.didSentCoins += 1
            WebRequest.requestCoin(aid: aid, num: 1)
        })
        if didSentCoins == 0 {
            alert.addAction(UIAlertAction(title: "2", style: .default) { [weak self] _ in
                guard let self else { return }
                self.coinButton.title? += 2
                if !self.likeButton.isOn {
                    self.likeButton.title? += 1
                    self.likeButton.isOn = true
                }
                self.likeButton.isOn = true
                self.didSentCoins += 2
                WebRequest.requestCoin(aid: aid, num: 2)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @IBAction func actionFavorite(_ sender: Any) {
        Task {
            guard let favList = try? await WebRequest.requestFavVideosList() else {
                return
            }
            if favButton.isOn {
                favButton.title? -= 1
                favButton.isOn = false
                WebRequest.removeFavorite(aid: aid, mid: favList.map { $0.id })
                return
            }
            let alert = UIAlertController(title: "收藏", message: nil, preferredStyle: .actionSheet)
            let aid = aid
            for fav in favList {
                alert.addAction(UIAlertAction(title: fav.title, style: .default) { [weak self] _ in
                    self?.favButton.title? += 1
                    self?.favButton.isOn = true
                    WebRequest.requestFavorite(aid: aid, mid: fav.id)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            present(alert, animated: true)
        }
    }

    @IBAction func actionDislike(_ sender: Any) {
        dislikeButton.isOn.toggle()
        ApiRequest.requestDislike(aid: aid, dislike: dislikeButton.isOn)
    }
}

extension VideoDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case pageRangeCollectionView:
            let range = pageRanges[indexPath.item]
            pageCollectionView.scrollToItem(at: IndexPath(item: range.startIndex, section: 0), at: .left, animated: true)
        case pageCollectionView:
            let page = pages[indexPath.item]
            let player = VideoPlayerViewController(playInfo: PlayInfo(aid: isBangumi ? page.page : aid, cid: page.cid, epid: page.epid, seasonId: seasonId, subType: subType, lastPlayCid: lastPlayCid, playTimeInSecond: playTimeInSecond, title: page.part))
            player.data = isBangumi ? nil : data

            let seq = pages.map({ PlayInfo(aid: isBangumi ? $0.page : aid, cid: $0.cid, epid: $0.epid, seasonId: seasonId, subType: subType, title: $0.part) })
            if seq.count > 0 {
                player.sequenceProvider = VideoSequenceProvider(seq: seq, currentIndex: indexPath.item)
            }
            present(player, animated: true, completion: nil)
        case ugcCollectionView:
            let video = allUgcEpisodes[indexPath.item]
            if Settings.showRelatedVideoInCurrentVC {
                aid = video.aid
                cid = video.cid
                Task { await fetchData() }
            } else {
                let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
                detailVC.present(from: self)
            }
        case recommandCollectionView:
            if let video = data?.Related[indexPath.item] {
                if Settings.showRelatedVideoInCurrentVC {
                    aid = video.aid
                    cid = video.cid
                    Task { await fetchData() }
                } else {
                    let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
                    detailVC.present(from: self)
                }
            }
        default:
            break
        }
    }
}

extension VideoDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
        case pageRangeCollectionView:
            return pageRanges.count
        case pageCollectionView:
            return pages.count
        case ugcCollectionView:
            return allUgcEpisodes.count
        case recommandCollectionView:
            return data?.Related.count ?? 0
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
        case pageRangeCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BLTextOnlyCollectionViewCell", for: indexPath) as! BLTextOnlyCollectionViewCell
            cell.titleLabel.text = pageRanges[indexPath.item].title
            return cell
        case pageCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BLTextOnlyCollectionViewCell", for: indexPath) as! BLTextOnlyCollectionViewCell
            let page = pages[indexPath.item]
            cell.titleLabel.text = page.part
            return cell
        case ugcCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: FeedCollectionViewCell.self), for: indexPath) as! FeedCollectionViewCell
            cell.cardShowsOwnerLine = false
            cell.setup(data: allUgcEpisodes[indexPath.row])
            return cell
        case recommandCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: FeedCollectionViewCell.self), for: indexPath) as! FeedCollectionViewCell
            if let related = data?.Related[indexPath.row] {
                cell.setup(data: related)
            }
            return cell
        default:
            return UICollectionViewCell()
        }
    }
}

// MARK: - 布局

extension VideoDetailViewController {
    func makePageCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(300), heightDimension: .absolute(150))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 40
            return section
        }
    }

    func makePageRangeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(200), heightDimension: .fractionalHeight(1))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 40
            return section
        }
    }

    /// 合集 / 推荐视频：和 Feed 一样的一行卡片，横向滚动。
    /// 标题与卡片之间的间距放在外层约束里，卡片高度就是整行的高度
    func makeFeedRowLayout(cardShowsOwnerLine: Bool) -> UICollectionViewLayout {
        let cardWidth = Self.rowCardWidth
        let cardHeight = Self.rowHeight(cardShowsOwnerLine: cardShowsOwnerLine)
        return UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(cardHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 40
            return section
        }
    }

    static func rowHeight(cardShowsOwnerLine: Bool) -> CGFloat {
        Settings.displayStyle.cardHeight(cardWidth: rowCardWidth, cardShowsOwnerLine: cardShowsOwnerLine)
    }
}

class NoteDetailView: UIControl {
    let label = UILabel()
    var onPrimaryAction: ((NoteDetailView) -> Void)?
    private let backgroundView = UIView()
    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        addSubview(backgroundView)
        backgroundView.backgroundColor = UIColor(named: "bgColor")
        backgroundView.layer.shadowOffset = CGSizeMake(0, 10)
        backgroundView.layer.shadowOpacity = 0.15
        backgroundView.layer.shadowRadius = 16.0
        backgroundView.layer.cornerRadius = BLCornerRadius.normal
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.isHidden = !isFocused
        backgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(-20)
            make.right.equalToSuperview().offset(20)
        }

        addSubview(label)
        label.numberOfLines = 0
        label.font = .App.body
        label.textColor = UIColor(named: "titleColor")
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
        }
    }

    override var canBecomeFocused: Bool {
        return true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        backgroundView.isHidden = !isFocused
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }
}

class ContentDetailViewController: UIViewController {
    private let titleLabel = UILabel()
    private let contentTextView = UITextView()

    static func createDesp(content: String) -> ContentDetailViewController {
        let vc = ContentDetailViewController()
        vc.titleLabel.text = "简介"
        vc.contentTextView.text = content
        return vc
    }

    static func createReply(content: String) -> ContentDetailViewController {
        let vc = ContentDetailViewController()
        vc.titleLabel.text = "评论"
        vc.contentTextView.text = content
        return vc
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [contentTextView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(titleLabel)
        view.addSubview(contentTextView)
        titleLabel.font = .App.pageTitle
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(80)
            make.centerX.equalToSuperview()
        }
        contentTextView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        contentTextView.isScrollEnabled = true
        contentTextView.isUserInteractionEnabled = true
        contentTextView.isSelectable = true
        contentTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().inset(60)
            make.bottom.equalToSuperview().inset(80)
        }
    }
}
