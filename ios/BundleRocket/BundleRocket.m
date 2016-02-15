//
//  BundleRocket.m
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import "BundleRocket.h"

@implementation BundleRocket {
    BOOL _willLoadBundleOnResume;
    NSInteger _id;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE(BundleRocket);

//+ (void)initialize {
//
//    NSLog(@"global initialize");
//    
//    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
//    
//    [center addObserverForName:RCTJavaScriptDidLoadNotification
//                        object:nil
//                         queue:[NSOperationQueue mainQueue]
//                    usingBlock:^(NSNotification* notice) {
//                        NSLog(@"%@", notice);
//                    }];
//
//}

+ (NSURL*)getBundleURL {
    return [self getBundleURL:@"main" extname:@"jsbundle"];
}

+ (NSURL*)getBundleURL:(NSString *)mainFileName {
    return [self getBundleURL:mainFileName extname:@"jsbundle"];
}

+ (NSURL*)getBundleURL:(NSString*)mainFileName
               extname:(NSString*)extname {

    NSError* error;
    
    NSString* bundleFilePath = [BRApp getCurrentBundleFilePath:&error];
    
    if (mainFileName == nil) {
        mainFileName = @"main";
    }
    
    if (extname == nil) {
        extname = @"jsbundle";
    }
    
    if (error || bundleFilePath == nil) {
        return [[NSBundle mainBundle] URLForResource:mainFileName withExtension:extname];
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:bundleFilePath]) {
        return nil;
    }
    
    return [[NSURL alloc] initFileURLWithPath:bundleFilePath];

}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

// 每次 react-native 的 app-js-bridge 启动时都会初始化一个此模块的实例
// 如果我们在下次resume/restart时需要更新bundle，我们将会标识 app 为 pending；
// 如果我们在 pending 状态下被实例化，那么是此 bundle 的首次运行，我们将会标识 app 为 firstRun；同时，我们也会将 app 标识为 loading
// 如果新的 bundle 正确启动，JS 会调用我们的 notifyApplicationReady 接口；此时，我们清除掉 pending / firstRun / loading 以及上一个版本的 bundle 在本地的文件
// 如果新的 bundle 未回调我们的 notifyApplicationReady 接口，我们认为这个 bundle 出错了；这里如果排除忘记回调 notifyApplicationReady 的话，可以认定 bundle 是加载时出错；加载时出错会导致 app 直接 crash，从而 app 会直接重启；此在在下一次 app 重启时，也就是出现了 pending + loading 同时成立的情况，我们会回滚到上一个版本。
- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        _willLoadBundleOnResume = NO;
        _id = arc4random() % 100000;
        
        // 如果正在进行一次延迟更新
        if ([BRApp isBundleInstallPending]) {
            
            NSLog(@"BR: activate in install-pending mode");
            
            // 如果正在进行 bundle 的重新载入
            if ([BRApp isBundleLoading]) {
                
                NSLog(@"BR: there was a uncompleted(unexpected) bundle load, so we are going to rollback");
                
                // 回滚
                [self rollback];
                
            }
            // 否则标识 bundle 正在加载
            else {
                
                NSLog(@"BR: we are going to load new bundle");
                
                [BRApp setBundleLoading:YES];
                
            }
            
        }
        
        NSLog(@"bundle-rocket native: new BundleRocket instance %ld created", (long)_id);
        
    }
    
    return self;
    
}


- (void)dealloc {

    NSLog(@"bundle-rocket native: BundleRocket instance %ld destroyed", (long)_id);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

- (void)reload {
    
    NSLog(@"%ld: try to load bundle", (long)_id);
    
    // This needs to be async dispatched because the _bridge is not set on init
    // when the app first starts, therefore rollbacks will not take effect.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // 如果被添加了这个标识，那么我们需要清理掉这个监听
        if (_willLoadBundleOnResume) {
            
            _willLoadBundleOnResume = NO;
            
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            
        }
        
        NSURL* bundleURL = [BundleRocket getBundleURL];
        
        [_bridge setValue:bundleURL forKey:@"bundleURL"];
        
        [_bridge reload];
        
    });
    
}

- (void)rollback {
    
    NSError* error = nil;
    
    // 回滚
    if (![BRApp rollback:&error] || error) {
        
        NSLog(@"BR: cannot rollback due to %@", error);
        NSLog(@"BR: we are going to rollback to embed bundle");
        
        // TODO
    };
    
    // 重启
    [self reload];
    
}

RCT_EXPORT_METHOD(getAppStatusInfo:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSError* error;
        
        NSDictionary* status = [BRApp getStatus:&error];
        
        if (error) {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
            return;
        }
        
        resolve(status);
        
    });
    
}

RCT_EXPORT_METHOD(download:(NSDictionary *)bundle
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    NSLog(@"native download start");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        BRDownloader *downloader = [[BRDownloader alloc] init:^(NSDictionary* bundleFileResult) {
            
            resolve(bundleFileResult);
            
        } failCallback:^(NSError *error) {
            
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
            
        } progressCallback:^(NSNumber *totalBytesWritten, NSNumber *totalBytesExpected) {
            
            // 通过 taskId 来触发 progress 事件回调
            [self.bridge.eventDispatcher
                sendAppEventWithName:[@"BundleRocketDownloadProgress/" stringByAppendingString:bundle[@"taskId"]]
                body:@{
                       @"totalBytesWritten": totalBytesWritten,
                       @"totalBytesExpected": totalBytesExpected}];
            
        }];
        
        [downloader download:bundle[@"location"]
            outputFolderPath:bundle[@"outputFolderPath"]
                      shasum:bundle[@"shasum"]
               deploymentKey:bundle[@"deploymentKey"]];
    
    });
    
    
}

RCT_EXPORT_METHOD(install:(NSDictionary*)bundle
                  mode:(BRInstallMode)mode
                  resolver:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {

    // This needs to be async dispatched because the _bridge is not set on init
    // when the app first starts, therefore rollbacks will not take effect.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSError* error = nil;
        
        if (![BRApp install:bundle mode:mode error:&error]) {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
            return;
        }
        
        // 重启时重载比较简单，只需要标识状态即可；状态标识在上边的 install 中处理好了，这里直接返回就好
        if (mode == BRInstallModeOnNextRestart) {
            resolve(nil);
            return;
        }
        
        // 如果是立即重载，那么就重启喽
        if (mode == BRInstallModeNow) {
            [self reload];
            resolve(nil);
            return;
        }
        
        // 如果是 resume 重载，那么通过
        if (mode == BRInstallModeOnNextResume) {
            
            NSLog(@"try to reload bundle on next resume");
            
            
            if (_willLoadBundleOnResume == NO) {
                
                // Ensure we do not add the listener twice.
                // Register for app resume notifications so that we
                // can check for pending updates which support "restart on resume"
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(reload)
                                                             name:UIApplicationWillEnterForegroundNotification
                                                           object:[UIApplication sharedApplication]];
                
                
                _willLoadBundleOnResume = YES;
                
            }

            resolve(nil);
            return;
        }
        
        // 其他奇怪的安装模式，拒绝它
        NSError* unknownInstallModeError = [[NSError alloc] initWithDomain:@"BRErrorDomain"
                                                    code:401
                                                userInfo:@{NSLocalizedDescriptionKey: @"unexpected install mode"}];
        
        reject([NSString stringWithFormat: @"%lu", (long)unknownInstallModeError.code], unknownInstallModeError.localizedDescription, unknownInstallModeError);
        
    });


}

RCT_EXPORT_METHOD(notifyApplicationReady:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if (![BRApp isBundleLoading]) {
            resolve(nil);
            return;
        }
        
        NSError* error = nil;
        
        if (![BRApp clearUpAfterBundleInstallSucceed:&error]) {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
            return;
        }
        
        resolve(nil);
        
    });
    

}

RCT_EXPORT_METHOD(isBundleInstallPending:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        resolve([NSNumber numberWithBool:[BRApp isBundleInstallPending]]);
        
    });

}

RCT_EXPORT_METHOD(isBundleLoading:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        resolve([NSNumber numberWithBool:[BRApp isBundleLoading]]);
        
    });

}


RCT_EXPORT_METHOD(restart) {
    [self reload];
}

RCT_EXPORT_METHOD(getErrorBundles:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        resolve([BRApp getErrorBundleVersions]);
    });
    
}

- (NSDictionary *)constantsToExport {
    return @{
        @"rootFolderPath": [BRUtil getRootFolderPath],
        @"cacheFolderPath": [BRUtil getCacheFolderPath]
    };
}

@end
