//
//  NowPlayingController.swift
//  LXMusic
//
//  CarPlay 正在播放界面（CPNowPlayingTemplate）
//  与 MPRemoteCommandCenter 自动联动，无需额外控制代码
//

import Foundation
import CarPlay
import MediaPlayer

@available(iOS 13.0, *)
class NowPlayingController {

    private var interfaceController: CPInterfaceController?

    init(interfaceController: CPInterfaceController?) {
        self.interfaceController = interfaceController
    }

    // MARK: - 显示正在播放界面
    func showNowPlaying() {
        // CPNowPlayingTemplate 是单例，自动与 MPNowPlayingInfoCenter 联动
        let nowPlayingTemplate = CPNowPlayingTemplate.shared

        // 配置播放控制按钮（自动映射到 MPRemoteCommandCenter）
        nowPlayingTemplate.updateNowPlayingButtons([])

        interfaceController?.pushTemplate(nowPlayingTemplate, animated: true) { _, _ in }
    }

    // MARK: - 更新播放信息
    // CPNowPlayingTemplate 自动从 MPNowPlayingInfoCenter 读取信息
    // 只需确保 NowPlayingManager 更新了 nowPlayingInfo
    func updateNowPlayingInfo(title: String, artist: String, artwork: UIImage?) {
        // CPNowPlayingTemplate 自动同步，无需额外操作
    }
}
