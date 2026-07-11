//
//  TabBarController.swift
//  LXMusic
//
//  CarPlay 底部导航（CPTabBarTemplate，最多 4 个 Tab）
//

import Foundation
import CarPlay

@available(iOS 13.0, *)
class TabBarController {

    private var interfaceController: CPInterfaceController?

    init(interfaceController: CPInterfaceController?) {
        self.interfaceController = interfaceController
    }

    // MARK: - 创建 TabBar 模板
    func createTabBarTemplate() -> CPTabBarTemplate {
        let myListTab = createMyListTab()
        let leaderboardTab = createLeaderboardTab()
        let searchTab = createSearchTab()
        let nowPlayingTab = createNowPlayingTab()

        return CPTabBarTemplate(templates: [myListTab, leaderboardTab, searchTab, nowPlayingTab])
    }

    // MARK: - Tab: 我的列表
    private func createMyListTab() -> CPListTemplate {
        let tab = CPListTemplate(
            title: "我的列表",
            sections: [CPListSection(items: [CPListItem(text: "加载中...", detailText: nil)])]
        )
        tab.tabTitle = "我的列表"
        tab.tabImage = UIImage(systemName: "music.note.list")
        return tab
    }

    // MARK: - Tab: 排行榜
    private func createLeaderboardTab() -> CPListTemplate {
        let tab = CPListTemplate(
            title: "排行榜",
            sections: [CPListSection(items: [CPListItem(text: "加载中...", detailText: nil)])]
        )
        tab.tabTitle = "排行榜"
        tab.tabImage = UIImage(systemName: "chart.bar")
        return tab
    }

    // MARK: - Tab: 搜索
    private func createSearchTab() -> CPListTemplate {
        let tab = CPListTemplate(
            title: "搜索",
            sections: []
        )
        tab.tabTitle = "搜索"
        tab.tabImage = UIImage(systemName: "magnifyingglass")
        return tab
    }

    // MARK: - Tab: 正在播放
    private func createNowPlayingTab() -> CPListTemplate {
        let tab = CPListTemplate(
            title: "正在播放",
            sections: [CPListSection(items: [CPListItem(text: "暂无播放", detailText: nil)])]
        )
        tab.tabTitle = "正在播放"
        tab.tabImage = UIImage(systemName: "play.circle")
        return tab
    }
}
