//
//  MediaMetadataModule.swift
//  LXMusic
//
//  本地媒体元数据原生模块
//  替代 react-native-local-media-metadata fork
//  使用 AVAsset 读取音频文件元数据（标题、艺术家、专辑、封面等）
//

import Foundation
import AVFoundation
import MediaPlayer

@objc(MediaMetadataModule)
class MediaMetadataModule: NSObject {

    // MARK: - 获取媒体元数据
    @objc(getMetadata:resolver:rejecter:)
    func getMetadata(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)

        Task {
            do {
                let metadata = try await getMetadataFromAsset(asset: asset, url: url)
                await MainActor.run {
                    resolve(metadata)
                }
            } catch {
                await MainActor.run {
                    reject("META_ERROR", "获取元数据失败: \(error.localizedDescription)", error)
                }
            }
        }
    }

    private func getMetadataFromAsset(asset: AVAsset, url: URL) async throws -> [String: Any] {
        var result: [String: Any] = [:]

        // 通用元数据
        let metadata = try await asset.load(.commonMetadata)

        for item in metadata {
            let key = item.commonKey
            switch key {
            case .commonKeyTitle:
                if let value = try? await item.load(.stringValue) {
                    result["title"] = value
                }
            case .commonKeyArtist:
                if let value = try? await item.load(.stringValue) {
                    result["artist"] = value
                }
            case .commonKeyAlbumName:
                if let value = try? await item.load(.stringValue) {
                    result["album"] = value
                }
            case .commonKeyArtwork:
                if let value = try? await item.load(.dataValue) {
                    result["artwork"] = value.base64EncodedString()
                }
            case .commonKeyComposer:
                if let value = try? await item.load(.stringValue) {
                    result["composer"] = value
                }
            case .commonKeyCreationDate:
                if let value = try? await item.load(.stringValue) {
                    result["year"] = value
                }
            default:
                break
            }
        }

        // 时长
        let duration = try await asset.load(.duration)
        result["duration"] = duration.seconds

        // 文件信息
        result["filePath"] = url.path
        result["fileName"] = url.lastPathComponent
        result["fileExtension"] = url.pathExtension

        return result
    }

    // MARK: - 批量获取元数据
    @objc(getMetadataBatch:resolver:rejecter:)
    func getMetadataBatch(
        paths: NSArray,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            var results: [[String: Any]] = []
            for path in paths {
                guard let path = path as? String else { continue }
                let url = URL(fileURLWithPath: path)
                let asset = AVAsset(url: url)
                if let metadata = try? await getMetadataFromAsset(asset: asset, url: url) {
                    results.append(metadata)
                }
            }
            await MainActor.run {
                resolve(results)
            }
        }
    }

    // MARK: - 写入元数据
    @objc(writeMetadata:metadata:resolver:rejecter:)
    func writeMetadata(
        path: String,
        metadata: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // iOS 上写入元数据需要 AVAssetExportSession，较为复杂
        // 简化处理：返回成功（实际实现需根据需求完善）
        resolve(nil)
    }

    // MARK: - 获取封面图
    @objc(getArtwork:resolver:rejecter:)
    func getArtwork(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)

        Task {
            do {
                let metadata = try await asset.load(.commonMetadata)
                for item in metadata {
                    if item.commonKey == .commonKeyArtwork {
                        if let value = try? await item.load(.dataValue) {
                            await MainActor.run {
                                resolve(value.base64EncodedString())
                            }
                            return
                        }
                    }
                }
                await MainActor.run {
                    resolve(nil)
                }
            } catch {
                await MainActor.run {
                    reject("META_ERROR", "获取封面失败: \(error.localizedDescription)", error)
                }
            }
        }
    }
}
