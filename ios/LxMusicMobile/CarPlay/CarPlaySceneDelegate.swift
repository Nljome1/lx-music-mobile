//
//  CarPlaySceneDelegate.swift
//  LXMusic
//
//  CarPlay Scene 入口，注册模板
//  对应 ADR-0003：CarPlay 作为独立原生入口，纯 Swift 渲染模板
//

import Foundation
import CarPlay
import React

@available(iOS 13.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - CarPlay 界面控制器
    var interfaceController: CPInterfaceController?
    var tabBarTemplate: CPTabBarTemplate?

    // MARK: - 数据桥接
    var dataBridge: CarPlayDataBridge?

    // MARK: - CarPlay 连接
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // 初始化数据桥接
        dataBridge = CarPlayDataBridge()

        // 构建底部 Tab 导航（最多 4 个 Tab）
        let tabs = buildTabs()
        tabBarTemplate = CPTabBarTemplate(templates: tabs)
        interfaceController.setRootTemplate(tabBarTemplate!, animated: true) { _, _ in }
    }

    // MARK: - CarPlay 断开
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.tabBarTemplate = nil
        self.dataBridge = nil
    }

    // MARK: - 构建 Tab 导航
    private func buildTabs() -> [CPListTemplate] {
        // Tab 1: 我的列表
        let myListTab = CPListTemplate(
            title: "我的列表",
            sections: dataBridge?.getMyListSections() ?? []
        )
        myListTab.tabTitle = "我的列表"
        myListTab.tabImage = UIImage(systemName: "music.note.list")

        // Tab 2: 排行榜
        let leaderboardTab = CPListTemplate(
            title: "排行榜",
            sections: dataBridge?.getLeaderboardSections() ?? []
        )
        leaderboardTab.tabTitle = "排行榜"
        leaderboardTab.tabImage = UIImage(systemName: "chart.bar")

        // Tab 3: 搜索
        let searchTab = CPListTemplate(
            title: "搜索",
            sections: []
        )
        searchTab.tabTitle = "搜索"
        searchTab.tabImage = UIImage(systemName: "magnifyingglass")
        // 搜索 Tab 使用 CPSearchTemplate 包装
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = dataBridge
        // 将搜索模板作为 Tab 的根模板

        // Tab 4: 正在播放
        let nowPlayingTab = CPListTemplate(
            title: "正在播放",
            sections: dataBridge?.getNowPlayingSections() ?? []
        )
        nowPlayingTab.tabTitle = "正在播放"
        nowPlayingTab.tabImage = UIImage(systemName: "play.circle")

        return [myListTab, leaderboardTab, searchTab, nowPlayingTab]
    }
}
