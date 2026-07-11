import RNFS from 'react-native-fs'

// 类型定义（替代原 react-native-file-system 的类型）
export interface FileType {
  name: string
  path: string
  size: number
  mimeType?: string
  isDirectory?: boolean
}

export type Encoding = 'utf8' | 'base64'
export type HashAlgorithm = 'md5' | 'sha1' | 'sha256' | 'sha512'

// 路径常量
export const temporaryDirectoryPath = RNFS.CachesDirectoryPath
export const externalStorageDirectoryPath = RNFS.DocumentDirectoryPath
export const privateStorageDirectoryPath = RNFS.DocumentDirectoryPath

export const getExternalStoragePaths = async(_is_removable?: boolean) => [RNFS.DocumentDirectoryPath]

// iOS 无 Scoped Storage 概念，返回空值
export const selectManagedFolder = async(_isPersist: boolean = false) => null
export const selectFile = async(_options: Record<string, any>) => null
export const removeManagedFolder = async(_path: string) => undefined
export const getManagedFolders = async() => []
export const getPersistedUriList = async() => []

export const extname = (name: string) => name.lastIndexOf('.') > 0 ? name.substring(name.lastIndexOf('.') + 1) : ''

// 文件系统操作（使用 react-native-fs）
export const readDir = async(path: string): Promise<FileType[]> => {
  const items = await RNFS.readDir(path)
  return items.map(item => ({
    name: item.name,
    path: item.path,
    size: item.size,
    mimeType: item.mimeType,
    isDirectory: item.isDirectory(),
  }))
}

export const unlink = async(path: string) => RNFS.unlink(path)

export const mkdir = async(path: string) => RNFS.mkdir(path)

export const stat = async(path: string) => {
  const result = await RNFS.stat(path)
  return {
    ...result,
    lastModified: new Date(result.mtime).getTime(),
  }
}

export const hash = async(path: string, algorithm: string) => RNFS.hash(path, algorithm)

export const readFile = async(path: string, encoding?: Encoding) => {
  if (encoding === 'base64') return RNFS.readFile(path, 'base64')
  return RNFS.readFile(path, 'utf8')
}

export const moveFile = async(fromPath: string, toPath: string) => RNFS.moveFile(fromPath, toPath)

// gzip 压缩/解压（iOS 上暂不支持，返回原始数据）
export const gzipFile = async(fromPath: string, _toPath: string) => {
  console.warn('gzipFile is not supported on iOS, copying instead')
  await RNFS.copyFile(fromPath, _toPath)
}
export const unGzipFile = async(fromPath: string, _toPath: string) => {
  console.warn('unGzipFile is not supported on iOS, copying instead')
  await RNFS.copyFile(fromPath, _toPath)
}
export const gzipString = async(data: string, _encoding?: Encoding) => data
export const unGzipString = async(data: string, _encoding?: Encoding) => data

export const existsFile = async(path: string) => RNFS.exists(path)

export const rename = async(path: string, name: string) => {
  const parentPath = path.substring(0, path.lastIndexOf('/'))
  const newPath = `${parentPath}/${name}`
  await RNFS.moveFile(path, newPath)
}

export const writeFile = async(path: string, data: string, encoding?: Encoding) => {
  if (encoding === 'base64') return RNFS.writeFile(path, data, 'base64')
  return RNFS.writeFile(path, data, 'utf8')
}

export const appendFile = async(path: string, data: string, encoding?: Encoding) => {
  if (encoding === 'base64') return RNFS.appendFile(path, data, 'base64')
  return RNFS.appendFile(path, data, 'utf8')
}

export const downloadFile = (url: string, path: string, options: Omit<RNFS.DownloadFileOptions, 'fromUrl' | 'toFile'> = {}) => {
  if (!options.headers) {
    options.headers = {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
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
