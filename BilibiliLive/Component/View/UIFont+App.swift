//
//  UIFont+App.swift
//  BilibiliLive
//
//  Created by jiaweiding on 2026/10/28.
//

import UIKit

extension UIFont {
    /// 全 App 统一的文字角色，全部取自 tvOS 动态字体，跟随系统「文字大小」设置。
    /// tvOS 的样式阶梯比 iOS 陡得多（headline 就有 38pt），跨两档就过大，跨零档又没层次，
    /// 所以每个页面里相邻层级只差一档：rowTitle 31 / meta 25，body 29 / meta 25。
    enum App {
        /// 页面大标题
        static var pageTitle: UIFont { .preferredFont(forTextStyle: .title3) }
        /// 分区标题（设置页的「通用」「界面」这类灰色小标题）
        static var sectionTitle: UIFont { .preferredFont(forTextStyle: .footnote) }
        /// 列表行、侧栏的主标题（设置页、我的侧栏），31pt 在 66pt 行高里留白最舒服
        static var rowTitle: UIFont { .preferredFont(forTextStyle: .callout) }
        /// Feed 卡片标题，比列表行小一档，和 25pt 的元信息搭配时密度更舒服
        static var cardTitle: UIFont { .preferredFont(forTextStyle: .body) }
        /// 按钮文字
        static var button: UIFont { .preferredFont(forTextStyle: .callout) }
        /// 正文、副标题、说明
        static var body: UIFont { .preferredFont(forTextStyle: .body) }
        /// 次级信息（UP 主、时间、播放量、简介），比主标题低一档
        static var meta: UIFont { .preferredFont(forTextStyle: .caption1) }
        /// 角标、徽章
        static var badge: UIFont { .preferredFont(forTextStyle: .caption2) }
    }
}
