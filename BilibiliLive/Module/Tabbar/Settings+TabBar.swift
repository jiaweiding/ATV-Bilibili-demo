//
//  Settings+TabBar.swift
//  BilibiliLive
//
//  Created by yicheng on 2026/3/5.
//

import Foundation

extension Settings {
    enum TabBarPageSection: String, CaseIterable {
        case tabBar
        case personal

        var title: String {
            switch self {
            case .tabBar:
                return "导航栏"
            case .personal:
                return "我的页面"
            }
        }
    }

    struct TabBarPagePlacement: Codable, Hashable {
        var page: TabBarPage
        /// 隐藏的页面不进导航栏、也不进「我的」，但卡片还留在自定义页原来的位置
        var isHidden: Bool = false

        /// 归属固定：导航栏那组只能待在导航栏，我的页面那组只能待在「我的」，不能跨区拖动
        var section: TabBarPageSection {
            page.homeSection
        }

        init(page: TabBarPage, isHidden: Bool = false) {
            self.page = page
            self.isHidden = isHidden
        }

        private enum CodingKeys: String, CodingKey {
            case page
            case section
            case isHidden
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let page = try container.decode(TabBarPage.self, forKey: .page)
            // 旧版本用 section == "hidden" 表示隐藏，这里转成 isHidden
            let legacySection = try container.decodeIfPresent(String.self, forKey: .section)
            let storedHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
            self.page = page
            isHidden = storedHidden || legacySection == "hidden"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(page, forKey: .page)
            try container.encode(isHidden, forKey: .isHidden)
        }
    }

    @UserDefaultCodable("Settings.tabBarPagePlacements", defaultValue: [])
    static var tabBarPagePlacements: [TabBarPagePlacement]

    // 导航栏
    static var tabBarPages: [TabBarPage] {
        normalizedPlacements.filter { $0.section == .tabBar && !$0.isHidden }.map(\.page)
    }

    // 个人中心
    static var personalPages: [TabBarPage] {
        normalizedPlacements.filter { $0.section == .personal && !$0.isHidden }.map(\.page)
    }

    // 初始化
    static func bootstrapTabBarPlacementModelIfNeeded() {
        if tabBarPagePlacements.isEmpty {
            tabBarPagePlacements = defaultPlacements
        } else {
            tabBarPagePlacements = normalize(tabBarPagePlacements)
        }
    }

    static func setPlacements(_ placements: [TabBarPagePlacement]) {
        tabBarPagePlacements = normalize(placements)
        NotificationCenter.default.post(name: .tabBarPagesDidChange, object: nil)
    }

    static var currentPlacements: [TabBarPagePlacement] {
        normalizedPlacements
    }

    static var defaultPlacements: [TabBarPagePlacement] {
        TabBarPage.allConfigurablePages.map { .init(page: $0) }
    }

    // MARK: - Private

    private static var normalizedPlacements: [TabBarPagePlacement] {
        let source = tabBarPagePlacements.isEmpty ? defaultPlacements : tabBarPagePlacements
        let normalized = normalize(source)
        if normalized != source {
            tabBarPagePlacements = normalized
        }
        return normalized
    }

    // 标准化
    private static func normalize(_ placements: [TabBarPagePlacement]) -> [TabBarPagePlacement] {
        var result = [TabBarPagePlacement]()
        var used = Set<TabBarPage>()

        for placement in placements {
            guard TabBarPage.allConfigurablePages.contains(placement.page), !used.contains(placement.page) else { continue }
            // 「我的」是设置入口，任何时候都不能隐藏
            let isHidden = placement.page.isFixedInTabBar ? false : placement.isHidden
            result.append(.init(page: placement.page, isHidden: isHidden))
            used.insert(placement.page)
        }

        for page in TabBarPage.allConfigurablePages where !used.contains(page) {
            result.append(.init(page: page))
        }

        return result
    }
}

extension TabBarPage {
    /// 固定归属，和默认分组一致：导航栏那 8 个、我的页面那 6 个
    var homeSection: Settings.TabBarPageSection {
        Self.defaultTabBarPages.contains(self) ? .tabBar : .personal
    }
}
