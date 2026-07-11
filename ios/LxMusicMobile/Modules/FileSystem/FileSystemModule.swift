//
//  FileSystemModule.swift
//  LXMusic
//
//  文件系统原生模块
//  替代 react-native-file-system fork（Android 专属的 SAF 分区存储 API）
//  iOS 上使用 FileManager 实现，API 签名与 fork 版本对齐
//

import Foundation
import CommonCrypto

// MARK: - 目录常量（对齐 Dirs 枚举）
enum DirType: String {
    case CacheDir       // 临时目录（对应 Dirs.CacheDir）
    case DocumentDir    // 私有存储目录（对应 Dirs.DocumentDir）
    case SDCardDir      // 外部存储目录（iOS 无对应概念，使用 DocumentDir）
}

// MARK: - 文件信息
struct FileInfo {
    var name: String
    var path: String
    var isDirectory: Bool
    var size: Int64
    var lastModified: Date
}

@objc(FileSystemModule)
class FileSystemModule: NSObject {

    // MARK: - 目录路径
    private var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    private var documentDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - 获取目录路径
    @objc(getDir:resolver:rejecter:)
    func getDir(
        dirType: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        switch dirType {
        case "CacheDir":
            resolve(cacheDir.path)
        case "DocumentDir":
            resolve(documentDir.path)
        case "SDCardDir":
            // iOS 无 SD 卡概念，使用 DocumentDir
            resolve(documentDir.path)
        default:
            resolve(documentDir.path)
        }
    }

    // MARK: - 列出目录内容（对应 FileSystem.ls）
    @objc(ls:resolver:rejecter:)
    func ls(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)
            resolve(items)
        } catch {
            reject("FS_ERROR", "无法列出目录: \(error.localizedDescription)", error)
        }
    }

    // MARK: - 删除文件/目录（对应 FileSystem.unlink）
    @objc(unlink:resolver:rejecter:)
    func unlink(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try FileManager.default.removeItem(atPath: path)
            resolve(nil)
        } catch {
            reject("FS_ERROR", "无法删除: \(error.localizedDescription)", error)
        }
    }

    // MARK: - 创建目录（对应 FileSystem.mkdir）
    @objc(mkdir:resolver:rejecter:)
    func mkdir(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            resolve(nil)
        } catch {
            reject("FS_ERROR", "无法创建目录: \(error.localizedDescription)", error)
        }
    }

    // MARK: - 获取文件信息（对应 FileSystem.stat）
    @objc(stat:resolver:rejecter:)
    func stat(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            let name = (path as NSString).lastPathComponent
            let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
            let size = (attrs[.size] as? Int64) ?? 0
            let modified = (attrs[.modificationDate] as? Date) ?? Date()

            let info: [String: Any] = [
                "name": name,
                "path": path,
                "isDirectory": isDir,
                "size": size,
                "lastModified": modified.timeIntervalSince1970 * 1000,
            ]
            resolve(info)
        } catch {
            reject("FS_ERROR", "无法获取信息: \(error.localizedDescription)", error)
        }
    }

    // MARK: - 文件哈希（对应 FileSystem.hash）
    @objc(hash:algorithm:resolver:rejecter:)
    func hash(
        path: String,
        algorithm: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let data = FileManager.default.contents(atPath: path) else {
            reject("FS_ERROR", "无法读取文件", nil)
            return
        }

        var hash: String?
        switch algorithm.lowercased() {
        case "md5":
            hash = data.md5Hash
        case "sha1":
            hash = data.sha1Hash
        case "sha256":
            hash = data.sha256Hash
        default:
            reject("FS_ERROR", "不支持的哈希算法: \(algorithm)", nil)
            return
        }

        resolve(hash)
    }

    // MARK: - 读取文件（对应 FileSystem.readFile）
    @objc(readFile:encoding:resolver:rejecter:)
    func readFile(
        path: String,
        encoding: String?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let data = FileManager.default.contents(atPath: path) else {
            reject("FS_ERROR", "无法读取文件", nil)
            return
        }

        if encoding == nil || encoding == "utf8" {
            resolve(String(data: data, encoding: .utf8))
        } else if encoding == "base64" {
            resolve(data.base64EncodedString())
        } else {
            // 默认 utf8
            resolve(String(data: data, encoding: .utf8))
        }
    }

    // MARK: - 移动文件（对应 FileSystem.mv）
    @objc(mv:toPath:resolver:rejecter:)
    func mv(
        fromPath: String,
        toPath: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try FileManager.default.moveItem(atPath: fromPath, toPath: toPath)
            resolve(nil)
        } catch {
            reject("FS_ERROR", "无法移动文件: \(error.localizedDescription)", error)
        }
    }

    // MARK: - 重命名（对应 FileSystem.rename）
    @objc(rename:name:resolver:rejecter:)
    func rename(
        path: String,
        name: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let dir = (path as NSString).deletingLastPathComponent
        let newPath = (dir as NSString).appendingPathComponent(name)
        do {
            try FileManager.default.moveItem(atPath: path, toPath: newPath)
            resolve(nil)
        } catch {
            reject("FS_ERROR", "无法重命名: \(error.localizedDescription)", error)
        }
    }

    // MARK: - 写入文件（对应 FileSystem.writeFile）
    @objc(writeFile:data:encoding:resolver:rejecter:)
    func writeFile(
        path: String,
        data: String,
        encoding: String?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let fileData: Data
        if encoding == "base64" {
            fileData = Data(base64Encoded: data) ?? Data()
        } else {
            fileData = data.data(using: .utf8) ?? Data()
        }
        FileManager.default.createFile(atPath: path, contents: fileData)
        resolve(nil)
    }

    // MARK: - 追加写入（对应 FileSystem.appendFile）
    @objc(appendFile:data:encoding:resolver:rejecter:)
    func appendFile(
        path: String,
        data: String,
        encoding: String?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let appendData: Data
        if encoding == "base64" {
            appendData = Data(base64Encoded: data) ?? Data()
        } else {
            appendData = data.data(using: .utf8) ?? Data()
        }

        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            handle.seekToEndOfFile()
            handle.write(appendData)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: appendData)
        }
        resolve(nil)
    }

    // MARK: - 文件是否存在（对应 FileSystem.exists）
    @objc(exists:resolver:rejecter:)
    func exists(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(FileManager.default.fileExists(atPath: path))
    }

    // MARK: - Gzip 压缩（对应 FileSystem.gzipFile / gzipString）
    @objc(gzipFile:toPath:resolver:rejecter:)
    func gzipFile(
        fromPath: String,
        toPath: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let data = FileManager.default.contents(atPath: fromPath) else {
            reject("FS_ERROR", "无法读取文件", nil)
            return
        }
        do {
            let compressed = try (data as NSData).compressed(using: .zlib)
            try compressed.write(to: URL(fileURLWithPath: toPath))
            resolve(nil)
        } catch {
            reject("FS_ERROR", "Gzip 压缩失败: \(error.localizedDescription)", error)
        }
    }

    @objc(unGzipFile:toPath:resolver:rejecter:)
    func unGzipFile(
        fromPath: String,
        toPath: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let data = FileManager.default.contents(atPath: fromPath) else {
            reject("FS_ERROR", "无法读取文件", nil)
            return
        }
        do {
            let decompressed = try (data as NSData).decompressed(using: .zlib)
            try decompressed.write(to: URL(fileURLWithPath: toPath))
            resolve(nil)
        } catch {
            reject("FS_ERROR", "Gzip 解压失败: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Android Scoped Storage 兼容（iOS 无对应概念，返回空/默认值）

    @objc(openDocumentTree:resolver:rejecter:)
    func openDocumentTree(
        isPersist: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // iOS 无 SAF 分区存储概念，使用 UIDocumentPickerViewController
        // 此方法在 iOS 上返回 nil，由 JS 侧使用平台分支处理
        resolve(nil)
    }

    @objc(openDocument:resolver:rejecter:)
    func openDocument(
        options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // iOS 上文件选择使用 UIDocumentPickerViewController
        // 此方法在 iOS 上返回 nil
        resolve(nil)
    }

    @objc(releasePersistableUriPermission:resolver:rejecter:)
    func releasePersistableUriPermission(
        path: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(nil)
    }

    @objc(getPersistedUriPermissions:rejecter:)
    func getPersistedUriPermissions(
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve([])
    }

    @objc(getExternalStoragePaths:rejecter:)
    func getExternalStoragePaths(
        isRemovable: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // iOS 无外部存储概念
        resolve([documentDir.path])
    }
}

// MARK: - Data 扩展（哈希计算，使用 CommonCrypto）
extension Data {
    var md5Hash: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        self.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(self.count), &digest) }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    var sha1Hash: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        self.withUnsafeBytes { _ = CC_SHA1($0.baseAddress, CC_LONG(self.count), &digest) }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    var sha256Hash: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &digest) }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
