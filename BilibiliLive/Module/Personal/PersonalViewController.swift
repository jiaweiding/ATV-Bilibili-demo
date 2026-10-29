//
//  PersonalViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/20.
//

import Alamofire
import Kingfisher
import SnapKit
import SwiftyJSON
import UIKit

class PersonalViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CellModel {
        let title: String
        /// SF Symbol 名称，留空则只显示文字
        var icon: String? = nil
        var autoSelect: Bool? = true
        var contentVC: UIViewController? = nil
        var action: (() -> Void)? = nil
    }

    static func create() -> PersonalViewController {
        return PersonalViewController()
    }

    private let leftContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .App.rowTitle
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let leftCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 4
        layout.itemSize = CGSize(width: 268, height: BLSettingLineCollectionViewCell.rowHeight)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        // 侧栏在玻璃面板内，不再叠加系统安全区内边距
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    weak var currentViewController: UIViewController?

    /// 焦点是否停在侧栏里，决定白色胶囊跟焦点还是跟选中项
    private var sidebarFocusActive = false

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = 27.5
        leftCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAccountUpdate),
                                               name: AccountManager.didUpdateNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTabBarPagesDidChange),
                                               name: .tabBarPagesDidChange,
                                               object: nil)
        updateAccountInfo()
        AccountManager.shared.refreshActiveAccountProfile()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupData() {
        cellModels.removeAll()

        // 侧栏只用文字，去掉图标
        let setting = CellModel(title: "设置", contentVC: SettingsViewController())
        cellModels.append(setting)
        cellModels.append(CellModel(title: "账号切换", autoSelect: false, action: { [weak self] in
            let controller = AccountSwitcherViewController()
            controller.modalPresentationStyle = .overFullScreen
            self?.present(controller, animated: true)
        }))

        for page in Settings.personalPages {
            if let model = makeCellModel(for: page) {
                cellModels.append(model)
            }
        }

        let logout = CellModel(title: "登出", autoSelect: false) {
            [weak self] in
            self?.actionLogout()
        }
        cellModels.append(logout)
    }

    private func makeCellModel(for page: TabBarPage) -> CellModel? {
        let vc = TabBarPageVCFactory.createVC(for: page)
        if page.requirePresentInPersonalPage {
            return CellModel(title: page.title) { [weak self] in
                self?.present(vc, animated: true)
            }
        }

        return CellModel(title: page.title, contentVC: vc)
    }

    func setViewController(vc: UIViewController) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }

    func actionLogout() {
        let alert = UIAlertController(title: "确定登出？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) {
            _ in
            WebRequest.logout {
                ApiRequest.logout { hasRemainingAccount in
                    if hasRemainingAccount {
                        AccountManager.shared.refreshActiveAccountProfile()
                    } else {
                        AppDelegate.shared.showLogin()
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleAccountUpdate() {
        updateAccountInfo()
    }

    @objc private func handleTabBarPagesDidChange() {
        setupData()
        leftCollectionView.reloadData()
        let firstIndexPath = IndexPath(item: 0, section: 0)
        leftCollectionView.selectItem(at: firstIndexPath, animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: firstIndexPath)
    }

    private func updateAccountInfo() {
        guard let account = AccountManager.shared.activeAccount else {
            usernameLabel.text = "未登录"
            avatarImageView.image = nil
            return
        }
        usernameLabel.text = account.profile.username
        if let url = URL(string: account.profile.avatar), !account.profile.avatar.isEmpty {
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        }
    }

    private func setupUI() {
        view.addSubview(leftContainerView)
        view.addSubview(contentView)

        leftContainerView.addSubview(profileContainerView)
        leftContainerView.addSubview(leftCollectionView)

        profileContainerView.addSubview(avatarImageView)
        profileContainerView.addSubview(usernameLabel)

        leftCollectionView.delegate = self
        leftCollectionView.dataSource = self

        leftContainerView.setGlassEffectView(cornerRadius: BLCornerRadius.lessBig)
        leftContainerView.layer.cornerRadius = BLCornerRadius.lessBig
        leftContainerView.clipsToBounds = true
        leftContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(40)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.bottom.equalToSuperview().offset(-40)
            make.width.equalTo(300)
        }

        contentView.snp.makeConstraints { make in
            make.leading.equalTo(leftContainerView.snp.trailing).offset(8)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.trailing.bottom.equalToSuperview()
        }

        profileContainerView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(100)
        }

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(55)
        }

        usernameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(avatarImageView.snp.centerY)
        }

        leftCollectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(profileContainerView.snp.bottom).offset(40)
        }
    }
}

extension PersonalViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLSettingLineCollectionViewCell
        cell.titleLabel.text = cellModels[indexPath.item].title
        cell.icon = cellModels[indexPath.item].icon
        cell.isSidebarFocusActive = sidebarFocusActive
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension PersonalViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = cellModels[indexPath.item]
        if let vc = model.contentVC {
            setViewController(vc: vc)
        }
        model.action?()
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 焦点进侧栏：白色胶囊跟焦点；焦点离开：胶囊回到当前选中项
        let sidebarFocused = context.nextFocusedIndexPath != nil
        if sidebarFocusActive != sidebarFocused {
            sidebarFocusActive = sidebarFocused
            coordinator.addCoordinatedAnimations {
                collectionView.blSetSidebarFocusActive(sidebarFocused)
            }
        }
        if Settings.sideMenuAutoSelectChange == false {
            return
        }
        // 检查新的焦点是否是UICollectionViewCell
        guard let nextFocusedIndexPath = context.nextFocusedIndexPath else {
            return
        }
        // 白色胶囊始终跟随焦点，保证同一时刻只有一个高亮行
        collectionView.selectItem(at: nextFocusedIndexPath, animated: true, scrollPosition: .centeredHorizontally)
        let model = cellModels[nextFocusedIndexPath.item]
        guard model.autoSelect != false else { return }
        if let vc = model.contentVC {
            setViewController(vc: vc)
        }
        model.action?()
    }
}

class EmptyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "Nothing Here"
        view.addSubview(label)
        label.makeConstraintsBindToCenterOfSuperview()
    }
}
