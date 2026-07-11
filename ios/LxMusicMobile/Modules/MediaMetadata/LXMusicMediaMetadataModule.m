//
//  LXMusicMediaMetadataModule.m
//  LXMusic
//
//  ObjC Bridge - 将 Swift MediaMetadataModule 的方法暴露给 React Native
//

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(MediaMetadataModule, NSObject)

RCT_EXTERN_METHOD(getMetadata:(NSString *)path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getMetadataBatch:(NSArray *)paths
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(writeMetadata:(NSString *)path
                  metadata:(NSDictionary *)metadata
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getArtwork:(NSString *)path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end
