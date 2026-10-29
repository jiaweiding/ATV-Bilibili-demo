//
//  CategoryViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/2/26.
//

import Foundation
import UIKit

class CategoryViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CategoryDisplayModel {
        let title: String
        /// SF Symbol 名称，留空则只显示文字
        var icon: String? = nil
        let contentVC: UIViewController
        var autoSelect: Bool? = true
    }

    var typeCollectionView: UICollectionView!
    var categories = [CategoryDisplayModel]()
    let contentView = UIView()
    weak var currentViewController: UIViewController?
    /// 焦点是否停在侧栏里，决定白色胶囊跟焦点还是跟选中项
    private var sidebarFocusActive = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if categories.isEmpty {
        } else {
            initTypeCollectionView()
        }
    }

    func initTypeCollectionView() {
        if typeCollectionView != nil {
            return
        }
        typeCollectionView = UICollectionView(frame: .zero, collectionViewLayout: BLSettingLineCollectionViewCell.makeLayout())
        // 侧栏在玻璃面板内，不再叠加系统安全区内边距
        typeCollectionView.contentInsetAdjustmentBehavior = .never
        typeCollectionView.backgroundColor = .clear
        typeCollectionView.layer.cornerRadius = BLCornerRadius.lessBig
        typeCollectionView.clipsToBounds = true
        typeCollectionView.backgroundView = UIVisualEffectView.makeGlassView(cornerRadius: BLCornerRadius.lessBig)
        typeCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        view.addSubview(typeCollectionView)
        typeCollectionView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(40)
            make.bottom.equalToSuperview().offset(-40)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.width.equalTo(300)
        }
        typeCollectionView.dataSource = self
        typeCollectionView.delegate = self

        view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.bottom.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.equalTo(typeCollectionView.snp.right)
        }
        typeCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(typeCollectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
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
}

extension CategoryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLSettingLineCollectionViewCell
        cell.titleLabel.text = categories[indexPath.item].title
        cell.icon = categories[indexPath.item].icon
        cell.isSidebarFocusActive = sidebarFocusActive
        return cell
    }
}

extension CategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setViewController(vc: categories[indexPath.item].contentVC)
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
        guard let nextFocusedIndexPath = context.nextFocusedIndexPath else {
            return
        }
        // 白色胶囊始终跟随焦点，保证同一时刻只有一个高亮行
        collectionView.selectItem(at: nextFocusedIndexPath, animated: true, scrollPosition: .centeredHorizontally)
        let categoryModel = categories[nextFocusedIndexPath.item]
        guard categoryModel.autoSelect != false else { return }
        setViewController(vc: categoryModel.contentVC)
    }
}
