//
//  BRApp.h
//  BundleRocket
//
//  Created by leon on 16/2/3.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//



#import <Foundation/Foundation.h>
#import "BRUtil.h"

#ifndef BR_APP_H
#define BR_APP_H

static NSString* const BR_APP_STATUS_FILE_NAME = @"bundle-rocket-app.json";
static NSString* const BR_APP_DEPLOYMENT_KEY = @"BundleRocketDeploymentKey";
static NSString* const BR_APP_REGISTRY = @"BundleRocketRegistry";
static NSString* const BR_APP_INSTALL_MODE = @"BundleRocketInstallMode";

typedef NS_ENUM(NSInteger, BRInstallMode) {
    BRInstallModeNow = 0,
    BRInstallModeOnNextRestart = 1,
    BRInstallModeOnNextResume = 2
};

@interface BRApp : NSObject

// 获取 App 状态文件路径
+ (NSString*)getStatusFilePath;

// 获取当前 App 状态
+ (NSDictionary*)getStatus:(NSError**)error;

// 获取当前 Bundle 的文件路径
+ (NSString*)getCurrentBundleFilePath:(NSError**)error;

// 保存 App 状态
+ (BOOL)saveStatus:(NSDictionary*)status error:(NSError**)error;

// 安装 Bundle
+ (BOOL)install:(NSDictionary*)bundle mode:(BRInstallMode)mode error:(NSError**)error;

// 回滚到上一个 Bundle
+ (BOOL)rollback:(NSError**)error;

// 标识一个 Bundle 安装出错
+ (BOOL)setBundleInstallError:(NSString*)bundleVersion error:(NSError**)error;

// 标识 app 为重启 bundle 状态
+ (void)setBundleLoading:(BOOL)isLoading;

// app 是否为加载 bundle 状态
+ (BOOL)isBundleLoading;

// app 是否为更新状态
+ (BOOL)isBundleInstallPending;

// 安装完成后的清理操作
+ (BOOL)clearUpAfterBundleInstallSucceed:(NSError**)error;

+ (NSArray*)getErrorBundleVersions;

@end

#endif