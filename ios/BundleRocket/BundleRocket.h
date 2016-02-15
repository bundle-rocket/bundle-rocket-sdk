//
//  BundleRocket.h
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"
#import "BRUtil.h"
#import "BRApp.h"
#import "BRDownloader.h"
#import "RCTConvert+BRInstallMode.h"

@interface BundleRocket : NSObject <RCTBridgeModule>

+ (NSURL*)getBundleURL;

+ (NSURL*)getBundleURL:(NSString*)mainFileName;

+ (NSURL*)getBundleURL:(NSString*)mainFileName
                  extname:(NSString*)extname;

@end
