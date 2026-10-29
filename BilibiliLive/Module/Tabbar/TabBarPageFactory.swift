//
//  TabBarPageFactory.swift
//  BilibiliLive
//
//  Created by yicheng on 2026/3/5.
//

import UIKit

class TabBarPageVCFactory {
    static func createVC(for page: TabBarPage) -> UIViewController {
        let vc: UIViewController
        switch page {
        case .live:
            vc = LiveViewController()
        case .feed:
            vc = RecommendViewController()
        case .tvRecommend:
            let tvRecommendVC = TVRecommendBrowserViewController()
            tvRecommendVC.modalPresentationStyle = .fullScreen
            vc = tvRecommendVC
        case .hot:
            vc = HotViewController()
        case .ranking:
            vc = RankingViewController()
        case .follows:
            vc = FollowsViewController()
        case .favorite:
            vc = FavoriteViewController()
        case .personal:
            let personalVC = PersonalViewController.create()
            personalVC.extendedLayoutIncludesOpaqueBars = true
            vc = personalVC
        case .search:
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            vc = UISearchContainerViewController(searchController: searchVC)
        case .followBangumi:
            vc = FollowBangumiViewController()
        case .followUps:
            vc = FollowUpsViewController()
        case .toView:
            vc = ToViewViewController()
        case .history:
            vc = HistoryViewController()
        case .weeklyWatch:
            vc = WeeklyWatchViewController()
        }

        // Tab 栏图标默认墨水高约 16pt，放大到略低于标题（29pt 字号）更接近系统观感。
        // 选中态由系统绘制：selectedImage 的尺寸、选中态标题字体都会被忽略，这里不再设置
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        vc.tabBarItem.image = UIImage(systemName: page.systemImage, withConfiguration: iconConfig)
        if page != .search {
            vc.tabBarItem.title = page.title
            // 标题默认约 25pt，提升一档
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.App.body]
            vc.tabBarItem.setTitleTextAttributes(titleAttributes, for: .normal)
        }
        vc.tabBarItem.accessibilityIdentifier = page.rawValue
        return vc
    }
}
