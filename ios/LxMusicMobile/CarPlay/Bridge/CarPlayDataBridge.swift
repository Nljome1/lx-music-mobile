//
//  CarPlayDataBridge.swift
//  LXMusic
//
//  与 JS 层 core/ 的数据桥接
//  通过 RN EventEmitter 发送/接收事件
//

import Foundation
import CarPlay
import React

@available(iOS 13.0, *)
class CarPlayDataBridge: NSObject, CPListTemplateDelegate, CPSearchTemplateDelegate {

    // MARK: - RN 事件发送
    private func sendEventToJS(_ name: String, body: Any?) {
        // 通过 PlayerModule 或专用 EventEmitter 发送事件到 JS 层
        // 实际实现需通过 RCTBridge 获取事件分发器
        NotificationCenter.default.post(name: NSNotification.Name("CarPlayEvent"), object: nil, userInfo: [
            "name": name,
            "body": body ?? NSNull(),
        ])
    }

    // MARK: - 获取我的列表数据
    func getMyListSections() -> [CPListSection] {
        // 从 JS 层获取我的列表数据
        // 返回空 section，实际数据由 JS 层通过 Bridge 填充
        let item = CPListItem(text: "加载中...", detailText: nil)
        return [CPListSection(items: [item])]
    }

    // MARK: - 获取排行榜数据
    func getLeaderboardSections() -> [CPListSection] {
        let item = CPListItem(text: "加载中...", detailText: nil)
        return [CPListSection(items: [item])]
    }

    // MARK: - 获取正在播放数据
    func getNowPlayingSections() -> [CPListSection] {
        let item = CPListItem(text: "暂无播放", detailText: nil)
        return [CPListSection(items: [item])]
    }

    // MARK: - CPListTemplateDelegate
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void) {
        // 用户点击歌曲/歌单
        sendEventToJS("carplay_item_select", body: [
            "tab": listTemplate.title,
            "itemTitle": item.text,
        ])
        completionHandler()
    }

    // MARK: - CPSearchTemplateDelegate
    func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
        // 执行搜索
        sendEventToJS("carplay_search", body: nil)
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        // 搜索文本变化，发送到 JS 层获取结果
        sendEventToJS("carplay_search_text", body: ["text": searchText])

        // 返回搜索结果（分页限制：最多 20 条）
        let items = (0..<min(20, 5)).map { i in
            CPListItem(text: "搜索结果 \(i + 1)", detailText: searchText)
        }
        completionHandler(items)
    }

    func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate, searchText: String) {
        sendEventToJS("carplay_search_submit", body: ["text": searchText])
    }

    // MARK: - 分页适配
    // CarPlay 模板的 section 最多 12 个，每个 section 的 item 最多 20 个（iOS 14+）
    func paginateItems(_ items: [CPListItem], pageSize: Int = 20) -> [CPListSection] {
        var sections: [CPListSection] = []
        let chunked = stride(from: 0, to: items.count, by: pageSize).map {
            Array(items[$0..<min($0 + pageSize, items.count)])
        }
        // 最多 12 个 section
        for chunk in chunked.prefix(12) {
            sections.append(CPListSection(items: chunk))
        }
        return sections
    }

    // MARK: - 从 JS 层接收数据更新
    func updateListData(tab: String, items: [[String: Any]]) {
        // JS 层通过调用此方法更新 CarPlay 列表数据
        // 实际实现需通过原生模块方法调用
    }
}
