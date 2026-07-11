import { Platform } from 'react-native'
import RNFS from 'react-native-fs'

// iOS 上使用原生模块 FileSystemModule，Android 上使用 react-native-file-system
// 使用条件 require 避免 iOS 上导入 Android 专属依赖导致运行时错误
const isIOS = Platform.OS === 'ios'

// 类型导入（编译时移除，不影响运行时）
import type {
  OpenDocumentOptions,
  Encoding,
  HashAlgorithm,
} from 'react-native-file-system'

export type {
  FileType,
} from 'react-native-file-system'

// Android 上条件加载 react-native-file-system
const RNFileSystem = isIOS ? null : require('react-native-file-system')
const Dirs = isIOS ? null : RNFileSystem.Dirs
const FileSystem = isIOS ? null : RNFileSystem.FileSystem
const AndroidScoped = isIOS ? null : RNFileSystem.AndroidScoped
const _getExternalStoragePaths = isIOS ? null : RNFileSystem.getExternalStoragePaths

export const extname = (name: string) => name.lastIndexOf('.') > 0 ? name.substring(name.lastIndexOf('.') + 1) : ''

// 路径常量：iOS 使用 RNFS 路径，Android 使用 Dirs 枚举
export const temporaryDirectoryPath = isIOS ? RNFS.CachesDirectoryPath : Dirs.CacheDir
export const externalStorageDirectoryPath = isIOS ? RNFS.DocumentDirectoryPath : Dirs.SDCardDir
export const privateStorageDirectoryPath = isIOS ? RNFS.DocumentDirectoryPath : Dirs.DocumentDir

export const getExternalStoragePaths = async(is_removable?: boolean) => isIOS
  ? [RNFS.DocumentDirectoryPath]
  : _getExternalStoragePaths(is_removable)

// Android Scoped Storage 在 iOS 上无对应概念，返回空值
export const selectManagedFolder = async(isPersist: boolean = false) => isIOS ? null : AndroidScoped.openDocumentTree(isPersist)
export const selectFile = async(options: OpenDocumentOptions) => isIOS ? null : AndroidScoped.openDocument(options)
export const removeManagedFolder = async(path: string) => isIOS ? undefined : AndroidScoped.releasePersistableUriPermission(path)
export const getManagedFolders = async() => isIOS ? [] : AndroidScoped.getPersistedUriPermissions()

export const getPersistedUriList = async() => isIOS ? [] : AndroidScoped.getPersistedUriPermissions()


export const readDir = async(path: string) => FileSystem.ls(path)

export const unlink = async(path: string) => FileSystem.unlink(path)

export const mkdir = async(path: string) => FileSystem.mkdir(path)

export const stat = async(path: string) => FileSystem.stat(path)
export const hash = async(path: string, algorithm: HashAlgorithm) => FileSystem.hash(path, algorithm)

export const readFile = async(path: string, encoding?: Encoding) => FileSystem.readFile(path, encoding)


export const moveFile = async(fromPath: string, toPath: string) => FileSystem.mv(fromPath, toPath)
export const gzipFile = async(fromPath: string, toPath: string) => FileSystem.gzipFile(fromPath, toPath)
export const unGzipFile = async(fromPath: string, toPath: string) => FileSystem.unGzipFile(fromPath, toPath)
export const gzipString = async(data: string, encoding?: Encoding) => FileSystem.gzipString(data, encoding)
export const unGzipString = async(data: string, encoding?: Encoding) => FileSystem.unGzipString(data, encoding)

export const existsFile = async(path: string) => FileSystem.exists(path)

export const rename = async(path: string, name: string) => FileSystem.rename(path, name)

export const writeFile = async(path: string, data: string, encoding?: Encoding) => FileSystem.writeFile(path, data, encoding)

export const appendFile = async(path: string, data: string, encoding?: Encoding) => FileSystem.appendFile(path, data, encoding)

export const downloadFile = (url: string, path: string, options: Omit<RNFS.DownloadFileOptions, 'fromUrl' | 'toFile'> = {}) => {
  if (!options.headers) {
    options.headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Mobile Safari/537.36',
    }
  }
  return RNFS.downloadFile({
    fromUrl: url,
    toFile: path,
    ...options,
  })
}

export const stopDownload = (jobId: number) => {
  RNFS.stopDownload(jobId)
}
