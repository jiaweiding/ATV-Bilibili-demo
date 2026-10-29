import Kingfisher
import UIKit

final class AccountSwitcherViewController: UIViewController {
    /// 卡片尺寸和间距；卡片整体靠左，和标题、副标题同一条左边线
    private enum Layout {
        static let cardWidth: CGFloat = 300
        static let cardHeight: CGFloat = 320
        static let interitemSpacing: CGFloat = 30
        static let sideInset: CGFloat = 60
    }

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 40
        layout.minimumInteritemSpacing = Layout.interitemSpacing
        layout.sectionInset = UIEdgeInsets(top: 40, left: Layout.sideInset, bottom: 40, right: Layout.sideInset)
        layout.itemSize = CGSize(width: Layout.cardWidth, height: Layout.cardHeight)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.remembersLastFocusedIndexPath = true
        collection.register(AccountSwitcherCell.self, forCellWithReuseIdentifier: AccountSwitcherCell.reuseIdentifier)
        collection.register(AccountSwitcherAddCell.self, forCellWithReuseIdentifier: AccountSwitcherAddCell.reuseIdentifier)
        collection.dataSource = self
        collection.delegate = self
        return collection
    }()

    private var accounts: [AccountManager.Account] = []
    /// 账号卡片左右排开，最后跟一张「添加账号」
    private var itemCount: Int { accounts.count + 1 }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupContainer()
        setupHeader()
        setupCollectionView()
        reloadData()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAccountUpdate),
                                               name: AccountManager.didUpdateNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionView]
    }

    private func setupContainer() {
        containerView.clipsToBounds = true
        containerView.layer.cornerRadius = BLCornerRadius.lessBig
        containerView.layer.cornerCurve = .continuous
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Liquid Glass 面板底（tvOS 26+），低版本回退深色毛玻璃
        let glassView = UIVisualEffectView.makeGlassView(style: .dark, cornerRadius: BLCornerRadius.lessBig)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(glassView)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 1100),
            containerView.heightAnchor.constraint(equalToConstant: 600),

            glassView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: containerView.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    private func setupHeader() {
        titleLabel.text = "账号管理"
        titleLabel.font = .App.pageTitle
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "快速切换登录账号或添加新的账号"
        subtitleLabel.font = .App.body
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 60),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 50),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
        ])
    }

    private func setupCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
        ])
    }

    private func reloadData() {
        accounts = AccountManager.shared.accounts
        collectionView.reloadData()
    }

    @objc private func handleAccountUpdate() {
        reloadData()
    }

    private func presentLogin() {
        // 登录页盖在账号管理上（而不是换掉根页面），遥控器按返回能退回这里反悔；
        // 登录成功后 LoginViewController 会自己把根页面换成 Tab 栏，整叠弹窗一起消失
        present(LoginViewController.create(), animated: true)
    }

    private func switchToAccount(_ account: AccountManager.Account) {
        let currentMID = AccountManager.shared.activeAccount?.profile.mid
        AccountManager.shared.setActiveAccount(account)
        dismiss(animated: true) {
            if currentMID == account.profile.mid {
                AccountManager.shared.refreshActiveAccountProfile()
            } else {
                AppDelegate.shared.resetTabBar()
            }
        }
    }
}

extension AccountSwitcherViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < accounts.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AccountSwitcherCell.reuseIdentifier, for: indexPath) as! AccountSwitcherCell
            let account = accounts[indexPath.item]
            cell.configure(with: account, active: account.profile.mid == AccountManager.shared.activeAccount?.profile.mid)
            return cell
        }
        return collectionView.dequeueReusableCell(withReuseIdentifier: AccountSwitcherAddCell.reuseIdentifier, for: indexPath)
    }
}

extension AccountSwitcherViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < accounts.count else {
            presentLogin()
            return
        }
        let account = accounts[indexPath.item]
        guard account.profile.mid != AccountManager.shared.activeAccount?.profile.mid else { return }
        switchToAccount(account)
    }
}

/// 账号卡片：Liquid Glass 底，聚焦时整块变白、文字转黑
private class AccountSwitcherCardCell: UICollectionViewCell {
    static let focusFillColor = UIColor.white.withAlphaComponent(0.95)

    /// Liquid Glass 卡片底（tvOS 26+），低版本回退毛玻璃
    let effectView = UIVisualEffectView.makeGlassView(cornerRadius: BLCornerRadius.lessBig)
    /// 聚焦时盖在玻璃上的白色高光，和侧栏白胶囊、Tab 自定义页同一套焦点语言
    let focusOverlayView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = false
        focusOverlayView.backgroundColor = Self.focusFillColor
        focusOverlayView.alpha = 0

        effectView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(effectView)

        focusOverlayView.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(focusOverlayView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            focusOverlayView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
            focusOverlayView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
            focusOverlayView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
            focusOverlayView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        focusOverlayView.alpha = 0
        transform = .identity
        // 复用出去时多半是未聚焦的，颜色先复位，避免留下上一轮的黑字
        updateContentColor()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.focusOverlayView.alpha = self.isFocused ? 1 : 0
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
            self.updateContentColor()
        }
    }

    /// 子类把图标、文字的颜色跟着焦点一起翻
    func updateContentColor() {}
}

private final class AccountSwitcherCell: AccountSwitcherCardCell {
    static let reuseIdentifier = "AccountSwitcherCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = nil
        avatarView.backgroundColor = .clear
        badgeLabel.isHidden = true
    }

    override func updateContentColor() {
        nameLabel.textColor = isFocused ? .black : .white
    }

    private func configure() {
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 80
        avatarView.clipsToBounds = true

        nameLabel.font = .App.rowTitle
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

        badgeLabel.text = "当前使用"
        badgeLabel.font = .App.badge
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemBlue
        badgeLabel.layer.cornerRadius = 22
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.isHidden = true

        // 头像 / 名字 / 状态徽章居中排一列：徽章隐藏或名字两行时整体自动重新居中，
        // 不会像固定边距那样贴着卡片底边
        let stackView = UIStackView(arrangedSubviews: [avatarView, nameLabel, badgeLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.setCustomSpacing(24, after: avatarView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 160),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            badgeLabel.heightAnchor.constraint(equalToConstant: 44),

            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    func configure(with account: AccountManager.Account, active: Bool) {
        nameLabel.text = account.profile.username
        if let url = URL(string: account.profile.avatar), !account.profile.avatar.isEmpty {
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarView.tintColor = .white
            // 白卡片上也要看得见，占位底色不能太淡
            avatarView.backgroundColor = UIColor(white: 0.3, alpha: 0.6)
        }
        badgeLabel.isHidden = !active
        updateContentColor()
    }
}

private final class AccountSwitcherAddCell: AccountSwitcherCardCell {
    static let reuseIdentifier = "AccountSwitcherAddCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateContentColor() {
        titleLabel.textColor = isFocused ? .black : .white
    }

    private func configure() {
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: "plus.circle.fill")
        iconView.tintColor = .systemBlue

        titleLabel.text = "添加账号"
        titleLabel.font = .App.rowTitle
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        // 和账号卡片一样居中排一列，两张卡片的内容基线一致
        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 120),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
        ])
    }
}
