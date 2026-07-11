//
//  ListController.swift
//  LXMusic
//
//  CarPlay 列表界面（CPListTemplate）
//  用于歌单详情、排行榜列表、我的列表
//

import Foundation
import CarPlay

@available(iOS 13.0, *)
class ListController: NSObject, CPListTemplateDelegate {

    private var interfaceController: CPInterfaceController?
    private var items: [CPListItem] = []

    init(interfaceController: CPInterfaceController?) {
        self.interfaceController = interfaceController
    }

    // MARK: - 创建列表模板
    func createListTemplate(title: String, items: [(title: String, subtitle: String?)]) -> CPListTemplate {
        // 分页限制：每个 section 最多 20 条
        let cpItems = items.prefix(20).map { item in
            CPListItem(text: item.title, detailText: item.subtitle)
        }
        self.items = cpItems

        let section = CPListSection(items: cpItems)
        let template = CPListTemplate(title: title, sections: [section])
        template.delegate = self
        return template
    }

    // MARK: - CPListTemplateDelegate
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void) {
        // 用户点击列表项，触发播放
        if let index = items.firstIndex(of: item) {
            // 发送事件到 JS 层播放对应歌曲
            NotificationCenter.default.post(
                name: NSNotification.Name("CarPlayPlayItem"),
                object: nil,
                userInfo: ["index": index, "listTitle": listTemplate.title]
            )
        }
        completionHandler()
    }
}
