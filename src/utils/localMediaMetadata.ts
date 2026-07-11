import { NativeModules } from 'react-native'

const { MediaMetadataModule } = NativeModules

// 元数据类型定义
export interface MusicMetadata {
  type: 'mp3' | 'flac' | 'ogg' | 'wav'
  bitrate: string
  interval: number
  size: number
  ext: 'mp3' | 'flac' | 'ogg' | 'wav'
  albumName: string
  singer: string
  name: string
}

export interface MusicMetadataFull extends MusicMetadata {
  albumName?: string
  singer?: string
  name?: string
  albumPic?: string
  lyric?: string
}

// 适配层：将原 react-native-local-media-metadata API 映射到 iOS MediaMetadataModule
export const readMetadata = async(filePath: string): Promise<MusicMetadata | null> => {
  return MediaMetadataModule.getMetadata(filePath)
}

export const writeMetadata = async(filePath: string, metadata: Record<string, any>): Promise<void> => {
  return MediaMetadataModule.writeMetadata(filePath, metadata)
}

export const writePic = async(_filePath: string, _picPath: string): Promise<void> => {
  // iOS MediaMetadataModule 暂不支持写入封面
  console.warn('writePic is not supported on iOS')
}

export const readLyric = async(_filePath: string): Promise<string> => {
  // iOS MediaMetadataModule 暂不支持读取歌词
  console.warn('readLyric is not supported on iOS')
  return ''
}

export const writeLyric = async(_filePath: string, _lyric: string): Promise<void> => {
  // iOS MediaMetadataModule 暂不支持写入歌词
  console.warn('writeLyric is not supported on iOS')
}

// 读取封面图片到缓存目录
export const readPic = async(filePath: string, cachePath: string): Promise<string> => {
  return MediaMetadataModule.getArtwork(filePath, cachePath)
}
