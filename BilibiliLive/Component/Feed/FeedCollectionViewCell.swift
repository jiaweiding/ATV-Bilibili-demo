//
//  FeedCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Kingfisher
import SnapKit
import TVUIKit
import UIKit

class FeedCollectionViewCell: BLMotionCollectionViewCell {
    var onLongPress: (() -> Void)?
    var styleOverride: FeedDisplayStyle? { didSet { if oldValue != styleOverride { updateStyle() } }}

    /// 列表的卡片是否有「播放量 · 日期」那一行，决定文本区预留几行
    var cardShowsMetaLine = true { didSet { updateStyle() } }

    /// 卡片是否有「UP主」那一行：合集里的小节没有 UP 主，别留空行
    var cardShowsOwnerLine = true { didSet { updateStyle() } }

    private let titleLabel = UILabel()
    private let nameLabel = UILabel()
    private let followedView = UIImageView()
    private let metaLabel = UILabel()
    /// 信息行内容，字号变化时要重新拼一次（图标尺寸跟着字体走）
    private var viewsText: String?
    private var timeText: String?
    private let imageView = UIImageView()
    private let infoView = UIView()
    private let durationContainer = UIView()
    private let durationLabel = UILabel()
    private let badgeContainer = UIView()
    private let badgeLabel = UILabel()
    private var infoMinHeightConstraint: Constraint?

    override func setup() {
        super.setup()
        // YouTube TV 聚焦时不放大，只描白边 + 标题变白
        scaleFactor = 1.03
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)

        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(9.0 / 16)
        }
        imageView.layer.cornerRadius = BLCornerRadius.little
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        // 时长角标：YouTube 风格右下角黑色圆角标签
        durationContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        durationContainer.layer.cornerRadius = 6
        durationContainer.layer.cornerCurve = .continuous
        durationContainer.isHidden = true
        imageView.addSubview(durationContainer)
        durationContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }
        durationLabel.font = .App.badge
        durationLabel.textColor = .white
        durationContainer.addSubview(durationLabel)
        durationLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        }

        // 状态角标：YouTube 风格左下角红色标签
        badgeContainer.backgroundColor = .systemRed
        badgeContainer.layer.cornerRadius = 6
        badgeContainer.layer.cornerCurve = .continuous
        badgeContainer.isHidden = true
        imageView.addSubview(badgeContainer)
        badgeContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
        }
        badgeLabel.font = .App.badge
        badgeLabel.textColor = .white
        badgeContainer.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        }

        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(12)
            // 按“两行标题 + UP主 + 信息行”预留最小高度，保证同排卡片高度一致
            infoMinHeightConstraint = make.height.greaterThanOrEqualTo(110).constraint
        }

        // YouTube TV 式三段文字：标题 / UP主 ✓ / 播放量 · 时间
        let stackView = UIStackView()
        infoView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        stackView.axis = .vertical
        stackView.addArrangedSubview(titleLabel)
        // 第二行：UP主，已关注时名字后面跟一个圆形对勾；
        // 尾部留一个空视图吃掉富余宽度，否则名字会被拉宽、对勾被推到右边
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, followedView, UIView()])
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 8
        stackView.addArrangedSubview(nameRow)
        stackView.addArrangedSubview(metaLabel)
        stackView.alignment = .fill
        stackView.spacing = 4
        stackView.setCustomSpacing(8, after: titleLabel)
        stackView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        // 未聚焦为灰色，聚焦后变白（YouTube TV 行为）
        titleLabel.textColor = UIColor(named: "upTitleColor")
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        for label in [nameLabel, metaLabel] {
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.textColor = UIColor(named: "upTitleColor")
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        // 名字独占一行，太长时截断（对勾必须留在名字后面，所以不能一起截断）
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        metaLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        // 已关注：名字后的圆形对勾。系统没有圆形对勾 emoji（✅ 是绿方块、☑️ 是投票框），
        // 用 SF Symbol 才能跟着字号缩放并染色
        followedView.tintColor = Self.infoIconColor
        followedView.contentMode = .scaleAspectFit
        followedView.setContentHuggingPriority(.required, for: .horizontal)
        followedView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func setup(data: any DisplayData) {
        titleLabel.text = data.title
        // 复用配置时保持与当前焦点状态一致的颜色
        titleLabel.textColor = isFocused ? UIColor(named: "titleColor") : UIColor(named: "upTitleColor")

        var viewsText: String?
        var durationTexts = [String]()
        if let overlay = data.overlay {
            // 不同接口把时长放在 left/right 的不同位置，按时长格式识别
            for item in overlay.leftItems + overlay.rightItems {
                if Self.isDurationText(item.text) {
                    durationTexts.append(item.text)
                } else if viewsText == nil, Self.isViewCountItem(item) {
                    viewsText = Self.formattedViewsText(item.text)
                }
            }
            if let badge = overlay.badge, !badge.text.isEmpty {
                badgeContainer.isHidden = false
                badgeLabel.text = badge.text
                badgeContainer.backgroundColor = badge.color ?? .systemRed
            } else {
                badgeContainer.isHidden = true
            }
        } else {
            badgeContainer.isHidden = true
        }

        // 信息行：名字 ✓ ▷播放量 时间，已关注用名字后的对勾表示
        nameLabel.text = data.ownerName
        nameLabel.isHidden = data.ownerName.isEmpty
        followedView.isHidden = !data.isFollowed

        self.viewsText = viewsText
        if let date = data.date, Self.isTimeText(date) {
            timeText = Self.displayTimeText(date)
        } else {
            timeText = nil
        }
        updateMetaText()

        let durationText = durationTexts.filter { !$0.isEmpty }.joined(separator: " · ")
        durationContainer.isHidden = durationText.isEmpty
        durationLabel.text = durationText

        if var pic = data.pic {
            if pic.scheme == nil {
                pic = URL(string: "http:\(pic.absoluteString)")!
            }
            imageView.kf.setImage(with: pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 720, height: 404))), .cacheOriginalImage])
        } else {
            imageView.image = nil
        }
        updateStyle()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        titleLabel.textColor = isFocused ? UIColor(named: "titleColor") : UIColor(named: "upTitleColor")
        coordinator.addCoordinatedAnimations {
            // 4pt 在电视上偏细，加到 6pt 让选中态更明确
            self.imageView.layer.borderWidth = self.isFocused ? 6 : 0
        }
    }

    /// 匹配 "23:55"、"1:18:32" 或 "12:30/25:00" 形式的时长文案
    private static func isDurationText(_ text: String) -> Bool {
        text.range(of: #"^\d{1,3}(:\d{2}){1,2}(/\d{1,3}(:\d{2}){1,2})?$"#, options: .regularExpression) != nil
    }

    /// 播放量：接口可能带“观看”后缀，也可能只有数字（通过图标识别）
    private static func isViewCountItem(_ item: DisplayOverlay.DisplayOverlayItem) -> Bool {
        if item.text.contains(":") {
            return false
        }
        if item.text.contains("观看") {
            return true
        }
        return item.icon == "play.rectangle"
    }

    private static func formattedViewsText(_ text: String) -> String {
        let count = text
            .replacingOccurrences(of: "观看", with: "")
            .replacingOccurrences(of: "播放", with: "")
            .components(separatedBy: .whitespaces)
            .joined()
        // 接口用 “-” 表示取不到数据，别拼成 “-播放”
        guard !count.isEmpty, count != "-" else { return count }
        // 部分接口给的是原始数字（如 1234567），统一压到“万/亿”
        let compacted: String
        if let number = Int(count) {
            if number >= 100_000_000 {
                compacted = String(format: "%.1f亿", Double(number) / 100_000_000)
            } else if number >= 10_000 {
                compacted = String(format: "%.1f万", Double(number) / 10_000)
            } else {
                compacted = count
            }
        } else {
            compacted = count
        }
        return "\(trimmedCount(compacted))播放"
    }

    /// 152.0万 → 152万：整数不留小数点
    private static func trimmedCount(_ text: String) -> String {
        text.replacingOccurrences(of: #"\.0(?=[万亿])"#, with: "", options: .regularExpression)
    }

    /// 发布时间：今年的只显示月日（10月10日），跨年补上年份（2020年10月10日）；
    /// 兼容 “2026-10-27 / 10-27 / 10月27日 / 2025年9月8日”，相对时间（刚刚、5天前）原样保留
    private static func displayTimeText(_ text: String) -> String {
        let numbers = text
            .components(separatedBy: CharacterSet(charactersIn: "-年月日/."))
            .filter { !$0.isEmpty }
            .compactMap { Int($0) }
        // “5天前”这类解析不出年月日的，原样显示
        guard numbers.count == 2 || numbers.count == 3, numbers.allSatisfy({ $0 > 0 }) else { return text }
        let month = numbers[numbers.count - 2]
        let day = numbers[numbers.count - 1]
        guard (1...12).contains(month), (1...31).contains(day) else { return text }
        if numbers.count == 3, numbers[0] != Calendar.current.component(.year, from: Date()) {
            return "\(numbers[0])年\(month)月\(day)日"
        }
        return "\(month)月\(day)日"
    }

    /// 信息行里的图标（已关注对勾）：比文字颜色再深一点，安静地跟着文字
    private static var infoIconColor: UIColor {
        (UIColor(named: "upTitleColor") ?? .gray).withAlphaComponent(0.72)
    }

    /// 信息行：播放量 · 时间；两者都可能缺，缺了就不占位置
    private func updateMetaText() {
        let font = (styleOverride ?? Settings.displayStyle).upFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(named: "upTitleColor") ?? .label,
        ]
        let text = NSMutableAttributedString()
        if let viewsText {
            text.append(NSAttributedString(string: viewsText, attributes: attributes))
        }
        if let timeText {
            if text.length > 0 {
                text.append(NSAttributedString(string: " · ", attributes: attributes))
            }
            text.append(NSAttributedString(string: timeText, attributes: attributes))
        }
        metaLabel.attributedText = text.length > 0 ? text : nil
        metaLabel.isHidden = text.length == 0
    }

    /// 信息行只保留日期/相对时间，过滤“已关注”这类推荐理由
    private static func isTimeText(_ text: String) -> Bool {
        let patterns = [
            #"\d{4}-\d{1,2}-\d{1,2}"#,
            #"^\d{1,2}-\d{1,2}$"#,
            #"\d{1,2}月\d{1,2}日"#,
            #"(刚刚|今天|昨天|前天|分钟前|小时前|天前|周前|个月前|年前)$"#,
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private func updateStyle() {
        let style = styleOverride ?? Settings.displayStyle
        titleLabel.font = style.titleFont
        nameLabel.font = style.upFont
        // 对勾跟着字号缩放，圆形直径略小于字高
        let checkConfig = UIImage.SymbolConfiguration(pointSize: (style.upFont.pointSize * 0.9).rounded(), weight: .semibold)
        followedView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
        followedView.tintColor = Self.infoIconColor
        updateMetaText()
        infoMinHeightConstraint?.update(offset: style.infoMinHeight(cardShowsMetaLine: cardShowsMetaLine, cardShowsOwnerLine: cardShowsOwnerLine))
    }

    @objc private func actionLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
        titleLabel.textColor = UIColor(named: "upTitleColor")
        imageView.image = nil
        imageView.layer.borderWidth = 0
        durationContainer.isHidden = true
        badgeContainer.isHidden = true
    }
}

extension FeedDisplayStyle {
    var fractionalWidth: CGFloat {
        switch self {
        case .large:
            return 0.33
        case .normal, .sideBar:
            return 0.25
        }
    }

    var fractionalHeight: CGFloat {
        switch self {
        case .large:
            return fractionalWidth / 1.5
        case .normal:
            return fractionalWidth / 1.5
        case .sideBar:
            return fractionalWidth / 1.15
        }
    }

    /// 文本区最小高度 = 两行标题 + 8 + UP主 +（4 + 信息行），保证同排卡片高度一致。
    /// 番剧 / 追番这类卡片只有标题和一行「更新至第 N 话」，没有「播放量 · 日期」，
    /// 预留那一行会让每排底部空出一条、把行距撑大，所以由列表决定要不要留
    func infoMinHeight(cardShowsMetaLine: Bool = true, cardShowsOwnerLine: Bool = true) -> CGFloat {
        let lineHeight = ceil(upFont.lineHeight)
        return ceil(titleFont.lineHeight) * 2 + 8 + (cardShowsOwnerLine ? lineHeight : 0) + (cardShowsMetaLine ? 4 + lineHeight : 0)
    }

    /// 三个档位共用同一套系统字号，字号差异留给以后按密度调整
    var titleFont: UIFont { .App.cardTitle }

    var upFont: UIFont { .App.meta }

    /// 横向一行里、宽度固定的卡片整体高度（封面 16:9 + 间距 + 文本区）
    func cardHeight(cardWidth: CGFloat, cardShowsMetaLine: Bool = true, cardShowsOwnerLine: Bool = true) -> CGFloat {
        (cardWidth * 9 / 16 + 12 + infoMinHeight(cardShowsMetaLine: cardShowsMetaLine, cardShowsOwnerLine: cardShowsOwnerLine)).rounded(.up)
    }
}
