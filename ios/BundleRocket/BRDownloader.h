//
//  BundleRocketDownloader.h
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BRMD5.h"
#import "NSData+GZIP.h"
#import "NSFileManager+Tar.h"

typedef void (^BRDownloaderDoneCallback)(NSDictionary *);
typedef void (^BRDownloaderFailCallback)(NSError *);
typedef void (^BRDownloaderProgressCallback)(NSNumber *, NSNumber *);

typedef NS_OPTIONS(NSUInteger, BRDownloaderStage) {
    BRDownloaderStageInit    = 0,
    BRDownloaderStageStart   = 1 << 0,
    BRDownloaderStagePending = 1 << 1,
    BRDownloaderStageDone    = 1 << 2,
    BRDownloaderStageFail    = 1 << 3
};

@interface BRDownloader : NSObject <NSURLSessionDelegate, NSURLSessionDataDelegate>

- (id)init:(BRDownloaderDoneCallback)doneCallback
    failCallback:(BRDownloaderFailCallback)failCallback
progressCallback:(BRDownloaderProgressCallback)progessCallback;

- (void) download:(NSString*)bundleURL
 outputFolderPath:(NSString*)outputFolderPath
           shasum:(NSString*)shasum
    deploymentKey:(NSString*)deploymentKey;

- (void) stop;

@end
