//
//  SearchController.swift
//  LXMusic
//
//  CarPlay 搜索界面（CPSearchTemplate）
//

import Foundation
import CarPlay

@available(iOS 13.0, *)
class SearchController: NSObject, CPSearchTemplateDelegate {

    private var interfaceController: CPInterfaceController?
    private var searchResults: [CPListItem] = []

    init(interfaceController: CPInterfaceController?) {
        self.interfaceController = interfaceController
    }

    // MARK: - 创建搜索模板
    func createSearchTemplate() -> CPSearchTemplate {
        let template = CPSearchTemplate()
        template.delegate = self
        return template
    }

    // MARK: - CPSearchTemplateDelegate
    func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
        // 搜索按钮按下
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        // 发送搜索请求到 JS 层
        NotificationCenter.default.post(
            name: NSNotification.Name("CarPlaySearch"),
            object: nil,
            userInfo: ["text": searchText]
        )

        // 返回搜索结果（最多 20 条）
        let results = (0..<min(20, 5)).map { i in
            CPListItem(text: "搜索结果 \(i + 1)", detailText: searchText)
        }
        self.searchResults = results
        completionHandler(results)
    }
}
