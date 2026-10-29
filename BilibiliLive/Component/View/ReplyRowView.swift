//
//  ReplyRowView.swift
//  BilibiliLive
//

import Kingfisher
import SnapKit
import UIKit

/// 详情页评论区的单条评论：整行玻璃卡片，头像在左，
/// 右侧第一行是「用户名 时间 …… 共 N 条回复」，下面跟正文
class ReplyRowView: UIControl {
    /// 头像直径
    private static let avatarSize: CGFloat = 76
    private static let horizontalPadding: CGFloat = 32
    private static let verticalPadding: CGFloat = 26
    /// 头像与右侧文字之间的间距
    private static let textSpacing: CGFloat = 24

    var onPrimaryAction: ((ReplyRowView) -> Void)?

    /// 正文最多显示几行；被回复的那条主评论要完整展示，传 0
    var contentNumberOfLines = 3 {
        didSet { contentLabel.numberOfLines = contentNumberOfLines }
    }

    /// 被回复的主评论只是展示，不接受焦点，焦点直接落到下面的回复上
    var isFocusable = true {
        didSet {
            guard isFocusable != oldValue else { return }
            setNeedsFocusUpdate()
        }
    }

    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let replyCountLabel = UILabel()
    private let replyCountStackView = UIStackView()
    private let contentLabel = UILabel()
    /// 正文下面追加的内容（评论配图、跳转按钮），没有内容时自动收起
    private let accessoryStackView = UIStackView()
    private let highlightView = UIView()

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func config(reply: Replys.Reply) {
        avatarImageView.kf.setImage(
            with: URL(string: reply.member.avatar),
            options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 160, height: 160))),
                .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))),
                .cacheSerializer(FormatIndicatedCacheSerializer.png),
            ]
        )
        nameLabel.text = reply.member.uname
        timeLabel.text = Self.timeText(of: reply)
        timeLabel.isHidden = timeLabel.text?.isEmpty ?? true
        replyCountLabel.text = Self.replyCountText(of: reply)
        replyCountStackView.isHidden = replyCountLabel.text == nil
        if let attr = reply.createAttributedString(displayView: contentLabel) {
            contentLabel.attributedText = attr
        } else {
            contentLabel.text = reply.content.message
        }
    }

    private func setup() {
        setGlassEffectView(cornerRadius: BLCornerRadius.lessBig)
        layer.cornerRadius = BLCornerRadius.lessBig
        layer.cornerCurve = .continuous

        // 聚焦只提亮整块玻璃，不倒成白底：评论是长文，反白后重读一行很跳
        highlightView.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        highlightView.layer.cornerRadius = BLCornerRadius.lessBig
        highlightView.layer.cornerCurve = .continuous
        highlightView.alpha = 0
        highlightView.isUserInteractionEnabled = false
        addSubview(highlightView)
        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = Self.avatarSize / 2
        addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.width.height.equalTo(Self.avatarSize)
            // 只有一行短评时，卡片高度也要包住头像
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.verticalPadding)
        }

        nameLabel.font = .App.rowTitle
        nameLabel.textColor = UIColor(named: "titleColor")
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        timeLabel.font = .App.meta
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        replyCountLabel.font = .App.meta
        replyCountLabel.textColor = UIColor.white.withAlphaComponent(0.6)

        let bubbleImageView = UIImageView(image: UIImage(systemName: "text.bubble", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)))
        bubbleImageView.tintColor = UIColor.white.withAlphaComponent(0.6)
        bubbleImageView.contentMode = .scaleAspectFit
        bubbleImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        replyCountStackView.axis = .horizontal
        replyCountStackView.alignment = .center
        replyCountStackView.spacing = 8
        replyCountStackView.addArrangedSubview(bubbleImageView)
        replyCountStackView.addArrangedSubview(replyCountLabel)
        replyCountStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerStackView = UIStackView(arrangedSubviews: [nameLabel, timeLabel, spacer, replyCountStackView])
        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.spacing = 14

        contentLabel.font = .App.body
        contentLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        contentLabel.numberOfLines = contentNumberOfLines
        contentLabel.lineBreakMode = .byTruncatingTail

        accessoryStackView.axis = .vertical
        accessoryStackView.spacing = 20
        accessoryStackView.isHidden = true

        // 右侧一列：标题行 / 正文 / 追加内容
        let textStackView = UIStackView(arrangedSubviews: [headerStackView, contentLabel, accessoryStackView])
        textStackView.axis = .vertical
        textStackView.spacing = 12
        textStackView.setCustomSpacing(16, after: contentLabel)
        addSubview(textStackView)
        textStackView.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(Self.textSpacing)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
        }
    }

    /// 正文下面追加内容，卡片高度自动跟着长
    func addAccessory(_ view: UIView) {
        accessoryStackView.addArrangedSubview(view)
        accessoryStackView.isHidden = false
    }

    override var canBecomeFocused: Bool {
        return isFocusable
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateFocusAppearance()
        }
    }

    private func updateFocusAppearance() {
        highlightView.alpha = isFocused ? 1 : 0
        transform = isFocused ? CGAffineTransform(scaleX: 1.012, y: 1.012) : .identity
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }

    /// 接口直接给了「1天前发布」这样的文案，去掉「发布」两个字当时间戳用
    private static func timeText(of reply: Replys.Reply) -> String? {
        if let desc = reply.reply_control?.time_desc, !desc.isEmpty {
            return desc.hasSuffix("发布") ? String(desc.dropLast(2)) : desc
        }
        guard let ctime = reply.ctime, ctime > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ctime))
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInCurrentYear(date) ? "MM-dd" : "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func replyCountText(of reply: Replys.Reply) -> String? {
        if let entry = reply.reply_control?.sub_reply_entry_text, !entry.isEmpty {
            return entry
        }
        guard let count = reply.rcount, count > 0 else { return nil }
        return "共\(count)条回复"
    }
}

private extension Calendar {
    func isDateInCurrentYear(_ date: Date) -> Bool {
        isDate(date, equalTo: Date(), toGranularity: .year)
    }
}
