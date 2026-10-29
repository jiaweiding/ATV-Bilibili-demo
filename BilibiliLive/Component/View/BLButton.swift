//
//  BLButton.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/22.
//

import Kingfisher
import SnapKit
import TVUIKit

@IBDesignable
@MainActor
class BLCustomButton: BLButton {
    /// 图标和文字的排布
    enum ContentLayout {
        /// 图标在玻璃里、文字排在玻璃下方（默认）
        case vertical
        /// 图标和文字并排放在同一块玻璃里，适合做成一行的胶囊按钮
        case horizontal
    }

    @IBInspectable var image: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var onImage: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var highLightImage: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var title: String? {
        didSet {
            updateTitleLabel()
        }
    }

    @IBInspectable var titleColor: UIColor = UIColor.black.withAlphaComponent(0.9) {
        didSet { updateButton() }
    }

    @IBInspectable var titleFont: UIFont = .App.button {
        didSet { titleLabel.font = titleFont }
    }

    var isOn: Bool = false {
        didSet {
            updateButton()
        }
    }

    /// IB 里没有这个开关，横排由代码在 viewDidLoad 里指定
    var contentLayout: ContentLayout = .vertical {
        didSet {
            guard contentLayout != oldValue else { return }
            arrangeContent()
        }
    }

    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    /// 竖排时文字在玻璃外，隐藏后要把约束撤掉，玻璃才能铺满整个按钮
    private var titleIsOutsideGlass: Bool { contentLayout == .vertical }

    override func setup() {
        super.setup()
        titleLabel.isUserInteractionEnabled = false
        titleLabel.numberOfLines = 1
        titleLabel.textAlignment = .center
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        imageView.contentMode = .scaleAspectFit
        arrangeContent()
    }

    /// 按 contentLayout 摆放图标和文字
    private func arrangeContent() {
        titleLabel.removeFromSuperview()
        imageView.snp.removeConstraints()
        titleLabel.snp.removeConstraints()

        switch contentLayout {
        case .vertical:
            effectView.contentView.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(0.5)
                make.height.equalTo(imageView.snp.width)
            }
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalTo(effectView.snp.bottom).offset(10)
            }
        case .horizontal:
            let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel])
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = 8
            stackView.isUserInteractionEnabled = false
            effectView.contentView.addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview().offset(12)
                make.trailing.lessThanOrEqualToSuperview().offset(-12)
            }
            imageView.snp.makeConstraints { make in
                make.height.equalTo(self).multipliedBy(0.4)
                make.width.equalTo(imageView.snp.height)
            }
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        updateTitleLabel(force: true)
        updateButton()
    }

    private func updateTitleLabel(force: Bool = false) {
        let shouldHide = title == nil || title?.count == 0
        titleLabel.text = title
        if force || titleLabel.isHidden != shouldHide {
            titleLabel.isHidden = shouldHide
            guard titleIsOutsideGlass else { return }
            if shouldHide {
                titleLabel.snp.removeConstraints()
            } else {
                titleLabel.snp.makeConstraints { make in
                    make.leading.trailing.bottom.equalToSuperview()
                    make.top.equalTo(effectView.snp.bottom).offset(10)
                }
            }
        }
    }

    private func getImage() -> UIImage? {
        isOn ? onImage : image
    }

    /// 系统图标按固定字号渲染，避免被 imageView 的方框拉伸变形
    private static func sized(_ image: UIImage?) -> UIImage? {
        guard let image, image.isSymbolImage else { return image }
        return image.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 30, weight: .medium))
    }

    private func updateButton() {
        imageView.image = Self.sized(isFocused ? (highLightImage ?? getImage()) : getImage())
        imageView.tintColor = isFocused ? .black : .white
        // 文字在玻璃里时，聚焦后玻璃变白底，文字要跟着转黑；
        // 竖排的文字在玻璃外，保持原色不变
        titleLabel.textColor = (isFocused && !titleIsOutsideGlass) ? .black : titleColor
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateButton()
    }
}

@IBDesignable
@MainActor
class BLCustomTextButton: BLButton {
    /// 玻璃内的左右/上下留白：有头像时左右对称贴着头像，没有头像时按文字按钮的余量给
    private static let avatarPadding: CGFloat = 8
    private static let avatarTextSpacing: CGFloat = 16
    private static let textPadding: CGFloat = 24
    private static let textVerticalPadding: CGFloat = 10

    private let titleLabel = UILabel()
    private let avatarImageView = UIImageView()
    var object: Any?

    /// 头像直径
    var avatarSize: CGFloat = 64 {
        didSet {
            guard avatarSize != oldValue else { return }
            layoutContent()
        }
    }

    /// 头像：放在玻璃里、名字左边，聚焦时整块一起被选中
    var avatarURL: URL? {
        didSet {
            guard avatarURL != oldValue else { return }
            if let avatarURL {
                avatarImageView.kf.setImage(with: avatarURL, options: [
                    .processor(DownsamplingImageProcessor(size: CGSize(width: avatarSize * 2, height: avatarSize * 2))),
                    .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))),
                    .cacheSerializer(FormatIndicatedCacheSerializer.png),
                ])
            } else {
                avatarImageView.kf.cancelDownloadTask()
                avatarImageView.image = nil
            }
            layoutContent()
        }
    }

    @IBInspectable var title: String? {
        didSet { titleLabel.text = title }
    }

    @IBInspectable var titleColor: UIColor = .white {
        didSet { titleLabel.textColor = titleColor }
    }

    @IBInspectable var titleSelectedColor: UIColor = .black {
        didSet { titleLabel.textColor = titleColor }
    }

    @IBInspectable var titleFont: UIFont = .App.button {
        didSet { titleLabel.font = titleFont }
    }

    override func setup() {
        super.setup()
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        effectView.contentView.addSubview(avatarImageView)
        effectView.contentView.addSubview(titleLabel)
        titleLabel.text = title
        titleLabel.font = titleFont
        titleLabel.textColor = isFocused ? titleSelectedColor : titleColor
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        layoutContent()
    }

    /// 有头像时由头像撑出胶囊高度，没有头像时由文字撑
    private func layoutContent() {
        let hasAvatar = avatarURL != nil
        avatarImageView.isHidden = !hasAvatar
        avatarImageView.layer.cornerRadius = avatarSize / 2
        avatarImageView.snp.removeConstraints()
        titleLabel.snp.removeConstraints()

        if hasAvatar {
            avatarImageView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Self.avatarPadding)
                make.top.equalToSuperview().offset(Self.avatarPadding)
                make.bottom.equalToSuperview().offset(-Self.avatarPadding)
                make.width.height.equalTo(avatarSize)
            }
            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(avatarImageView.snp.trailing).offset(Self.avatarTextSpacing)
                make.trailing.equalToSuperview().offset(-Self.textPadding)
                make.centerY.equalToSuperview()
            }
        } else {
            // 没有头像时收成 0，纯文字按钮的胶囊高度只由文字决定
            avatarImageView.snp.makeConstraints { make in
                make.width.height.equalTo(0)
            }
            titleLabel.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview().inset(Self.textVerticalPadding)
                make.left.right.equalToSuperview().inset(Self.textPadding)
            }
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        titleLabel.textColor = isFocused ? titleSelectedColor : titleColor
    }
}

class BLButton: UIControl {
    private var motionEffect: UIInterpolatingMotionEffect!
    /// Liquid Glass 底（tvOS 26+），低版本回退成深色毛玻璃
    fileprivate let effectView = UIVisualEffectView.makeGlassView()
    private let selectedWhiteView = UIView()

    /// 未聚焦时白色层的透明度。玻璃在纯深色背景上几乎没有边缘，
    /// 这种地方调高一点让圆形边界看得见；背后有内容时保持 0
    var restingWhiteAlpha: CGFloat = 0 {
        didSet {
            // setup 里按未聚焦把它藏了起来，这里只改透明度不会让它出现
            guard !isFocused else { return }
            selectedWhiteView.isHidden = restingWhiteAlpha == 0
            selectedWhiteView.alpha = restingWhiteAlpha
        }
    }

    var onPrimaryAction: ((BLButton) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var canBecomeFocused: Bool { return true }

    func setup() {
        isUserInteractionEnabled = true
        motionEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        motionEffect.maximumRelativeValue = 8
        motionEffect.minimumRelativeValue = -8
        selectedWhiteView.isHidden = !isFocused
        addSubview(effectView)
        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        effectView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
        }
        effectView.contentView.addSubview(selectedWhiteView)
        selectedWhiteView.backgroundColor = UIColor.white
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 胶囊：圆角跟着自身高度走，方形图标按钮就是正圆，宽按钮就是胶囊
        effectView.layer.cornerRadius = effectView.bounds.height / 2
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            selectedWhiteView.isHidden = false
            selectedWhiteView.alpha = 1
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransformMakeScale(1.1, 1.1)
                let scaleDiff = (self.bounds.size.height * 1.1 - self.bounds.size.height) / 2
                self.transform = CGAffineTransformTranslate(self.transform, 0, -scaleDiff)
                self.layer.shadowOffset = CGSizeMake(0, 10)
                self.layer.shadowOpacity = 0.15
                self.layer.shadowRadius = 16.0
                self.addMotionEffect(self.motionEffect)
            }
        } else {
            selectedWhiteView.isHidden = restingWhiteAlpha == 0
            selectedWhiteView.alpha = restingWhiteAlpha
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransformIdentity
                self.layer.shadowOpacity = 0
                self.layer.shadowOffset = CGSizeMake(0, 0)
                self.removeMotionEffect(self.motionEffect)
            }
        }
    }
}
