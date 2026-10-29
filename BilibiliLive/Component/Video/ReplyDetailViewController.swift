//
// Created by Yam on 2024/6/9.
//

import Alamofire
import Kingfisher
import SnapKit
import UIKit

/// 点评论进来的二级页：上面是被回复的那条评论（完整展示），下面是它的回复列表
class ReplyDetailViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let mainReplyView = ReplyRowView()
    private let repliesSectionView = UIStackView()
    private let repliesTitleLabel = UILabel()
    private let repliesStackView = UIStackView()

    private let reply: Replys.Reply

    init(reply: Replys.Reply) {
        self.reply = reply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        // 主评论只做展示，进来先把焦点交给第一条回复
        guard let firstReply = repliesStackView.arrangedSubviews.first else { return [scrollView] }
        return [firstReply]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        configMainReply()
        configReplies()
    }

    // MARK: - Private

    private func setUpViews() {
        view.backgroundColor = .black

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        titleLabel.font = .App.pageTitle
        titleLabel.text = "评论"
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
        }

        contentView.addSubview(mainReplyView)
        mainReplyView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(60)
            make.leading.equalTo(contentView.snp.leadingMargin)
            make.trailing.equalTo(contentView.snp.trailingMargin)
        }

        repliesTitleLabel.font = .App.sectionTitle
        repliesTitleLabel.textColor = UIColor(named: "upTitleColor")

        repliesStackView.axis = .vertical
        repliesStackView.spacing = 24

        repliesSectionView.axis = .vertical
        repliesSectionView.spacing = 30
        repliesSectionView.addArrangedSubview(repliesTitleLabel)
        repliesSectionView.addArrangedSubview(repliesStackView)
        contentView.addSubview(repliesSectionView)
        repliesSectionView.snp.makeConstraints { make in
            make.top.equalTo(mainReplyView.snp.bottom).offset(60)
            make.leading.equalTo(contentView.snp.leadingMargin)
            make.trailing.equalTo(contentView.snp.trailingMargin)
            make.bottom.equalToSuperview().offset(-80)
        }
    }

    /// 被回复的那条评论：正文完整展示、不接受焦点，配图和跳转按钮都挂在卡片里
    private func configMainReply() {
        mainReplyView.config(reply: reply)
        mainReplyView.contentNumberOfLines = 0
        mainReplyView.isFocusable = false

        if let pictures = reply.content.pictures, !pictures.isEmpty {
            let imageStackView = UIStackView()
            imageStackView.axis = .horizontal
            imageStackView.distribution = .fillEqually
            imageStackView.spacing = 20
            for picture in pictures {
                guard let url = URL(string: picture.img_src) else { continue }
                let imageView = UIImageView()
                imageView.kf.setImage(with: url)
                imageView.contentMode = .scaleAspectFit
                imageView.snp.makeConstraints { make in
                    make.height.lessThanOrEqualTo(500)
                }
                imageStackView.addArrangedSubview(imageView)
            }
            mainReplyView.addAccessory(imageStackView)
        }

        guard let jumpUrls = reply.content.jump_url, !jumpUrls.isEmpty else { return }
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 20
        // 按钮保持自身宽度，尾部留一个空视图吃掉富余宽度，否则会被拉开
        buttonStackView.setContentHuggingPriority(.required, for: .horizontal)
        let buttonRow = UIStackView(arrangedSubviews: [buttonStackView, UIView()])
        buttonRow.axis = .horizontal

        for (url, jump) in jumpUrls {
            Task { [weak self] in
                guard let bvId = await ReplyUrlBVParser.parser(url: url) else { return }
                let button = BLCustomTextButton()
                button.title = jump.title
                button.onPrimaryAction = { [weak self] _ in
                    self?.jumpLink(bvid: bvId)
                }
                if buttonStackView.arrangedSubviews.isEmpty {
                    self?.mainReplyView.addAccessory(buttonRow)
                }
                buttonStackView.addArrangedSubview(button)
            }
        }
    }

    private func configReplies() {
        let replies = reply.replies ?? []
        repliesTitleLabel.text = "共 \(replies.count) 条回复"
        repliesSectionView.isHidden = replies.isEmpty

        for subReply in replies {
            let row = ReplyRowView()
            row.config(reply: subReply)
            row.onPrimaryAction = { [weak self] _ in
                self?.present(ReplyDetailViewController(reply: subReply), animated: true)
            }
            repliesStackView.addArrangedSubview(row)
        }
    }

    private func jumpLink(bvid: String) {
        let aid = BvidConvertor.bv2av(bvid: bvid)
        let detailVC = VideoDetailViewController.create(aid: Int(aid), cid: nil)
        detailVC.present(from: self)
    }
}

enum ReplyUrlBVParser {
    static func parser(url: String) async -> String? {
        if url.hasPrefix("BV"), url.count == 12 {
            return url
        }

        if url.hasPrefix("https://www.bilibili.com/video/") {
            guard let urlComponents = URLComponents(string: url)
            else { return nil }
            let path = urlComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let bvid = path.split(separator: "/").filter({ !$0.isEmpty }).last {
                return await parser(url: String(bvid))
            }
            return nil
        }

        // need to get 302 for real url
        if url.hasPrefix("https://b23.tv/") {
            if let realUrl = await AF.request(url, method: .head).serializingData().response.response?.url {
                return await parser(url: realUrl.absoluteString)
            }
        }

        return nil
    }
}
