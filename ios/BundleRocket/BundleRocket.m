//
//  BundleRocket.m
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import "BundleRocket.h"
#import "BRDownloader.h"
#import "BRUtil.h"

@implementation BundleRocket

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE(BundleRocket);

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();;
}

RCT_EXPORT_METHOD(download:(NSString *)bundleURL
                  toFilePath:(NSString *)toFilePath
                  taskId:(NSString *)taskId
                  shasum:(NSString*)shasum
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    
        BRDownloader *downloader = [[BRDownloader alloc] init:^(NSDictionary* cacheFileInfo) {
            
            resolve(cacheFileInfo);
            
        } failCallback:^(NSError *error) {
            
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
            
        } progressCallback:^(NSNumber *totalBytesWritten, NSNumber *totalBytesExpected) {
            // 通过 taskId 来触发 progress 事件回调
            [self.bridge.eventDispatcher
                sendDeviceEventWithName:@"BundleRocketDownloadProgress"
                body:@{
                       @"taskId": taskId,
                       @"totalBytesWritten": totalBytesWritten,
                       @"totalBytesExpected": totalBytesExpected}];
        }];
        
        [downloader download:bundleURL outputFilePath:toFilePath shasum:shasum];
    
    });
    
    
}

- (NSDictionary *)constantsToExport {
    return @{
        @"rootFolderPath": [BRUtil getRootFolderPath],
        @"cacheFolderPath": [BRUtil getCacheFolderPath]
    };
}

@end
