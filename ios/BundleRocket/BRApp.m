//
//  BRApp.m
//  BundleRocket
//
//  Created by leon on 16/2/3.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import "BRApp.h"
#import "BRUtil.h"

static NSString* const BR_BUNDLE_UPDATE_PENDING = @"BR_BUNDLE_UPDATE_PENDING";
static NSString* const BR_BUNDLE_LOADING = @"BR_BUNDLE_LOADING";

@implementation BRApp

+ (NSString*)getStatusFilePath {
    return [[BRUtil getRootFolderPath] stringByAppendingPathComponent:BR_APP_STATUS_FILE_NAME];
}

+ (NSDictionary*)getStatus:(NSError**)error {

    NSString* statusFilePath = [BRApp getStatusFilePath];
    NSFileManager* mananger = [NSFileManager defaultManager];
    
    NSMutableDictionary* status;
    
    if ([mananger fileExistsAtPath:[BRApp getStatusFilePath]]) {
        
        NSData* data = [mananger contentsAtPath:statusFilePath];
        
        
        status = [[NSJSONSerialization JSONObjectWithData:data
                                                  options:kNilOptions
                                                    error:error] mutableCopy];
        if (*error) {
            return nil;
        }
        
    }
    else {
        status = [[NSMutableDictionary alloc] init];
    }
    
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    
    NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *buildVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
    
    
    NSString *registry = [infoDictionary objectForKey:BR_APP_REGISTRY];
    
    if (registry == nil) {
    
        *error = [[NSError alloc] initWithDomain:@"BRErrorDomain" code:500 userInfo:@{NSLocalizedDescriptionKey: @"missing `BundleRocketRegistry` in your info.plist"}];
        return nil;
    
    }
    
    NSString *deploymentKey = [infoDictionary objectForKey:BR_APP_DEPLOYMENT_KEY];
    
    if (deploymentKey == nil) {
    
        *error = [[NSError alloc] initWithDomain:@"BRErrorDomain" code:500 userInfo:@{NSLocalizedDescriptionKey: @"missing `BundleRocketDeploymentKey` in your info.plist"}];
        
        return nil;
    
    }
    
    [status addEntriesFromDictionary:@{@"appVersion": appVersion,
                                       @"buildVersion": buildVersion,
                                       @"platform": @"ios",
                                       @"deploymentKey": deploymentKey,
                                       @"registry": registry}];
    
    return status;

}

+ (BOOL)saveStatus:(NSDictionary *)status error:(NSError **)error {
    
    
    NSData* data = [NSJSONSerialization dataWithJSONObject:status options:kNilOptions error:error];
    
    if (*error) {
        return NO;
    }
    
    return [[NSFileManager defaultManager] createFileAtPath:[self getStatusFilePath]
                                                   contents:data
                                                 attributes:nil];
    
}

+ (NSString*)getCurrentBundleFilePath:(NSError**)error {

    NSDictionary* status = [self getStatus:error];
    
    if (*error) {
        return nil;
    }
    
    NSString* bundleVersion = status[@"bundleVersion"];
    NSString* mainFileName = status[@"main"];
    
    if (bundleVersion == nil || mainFileName == nil) {
        return nil;
    }
    
    NSString* rootFolderPath = [BRUtil getRootFolderPath];
    NSString* bundleFolderPath = [rootFolderPath stringByAppendingPathComponent:bundleVersion];
    NSString* bundleFilePath = [bundleFolderPath stringByAppendingPathComponent:mainFileName];
    
    NSLog(@"current bundle file path:%@", bundleFilePath);
    
    return bundleFilePath;

}

+ (BOOL)install:(NSDictionary *)bundle
           mode:(BRInstallMode)mode
          error:(NSError *__autoreleasing *)error {

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    // 如果是直接重启，那么需要标识为 pending 和 loading
    if (mode == BRInstallModeNow) {
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:BR_BUNDLE_LOADING];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:BR_BUNDLE_UPDATE_PENDING];
    }
    // 如果是 resume / restart，只需要标识为 pending
    // loading 会在启动时在主模块中进行操作
    else {
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:BR_BUNDLE_UPDATE_PENDING];
    }
    
    [defaults synchronize];
    
    return [self saveStatus:bundle error:error];

}

+ (BOOL)rollback:(NSError**)error {
    
    // 清除 pending / loading 标识
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults removeObjectForKey:BR_BUNDLE_UPDATE_PENDING];
    [defaults removeObjectForKey:BR_BUNDLE_LOADING];
    [defaults synchronize];
    
    NSLog(@"BR: app pending/loading tag removed");
    
    // 获取当前应用状态
    NSMutableDictionary* status = [[self getStatus:error] mutableCopy];
    
    if (*error) {
        NSLog(@"BR fatal: cannot get app status due to %@", *error);
        return NO;
    }
    
    // 尝试删除当前这个挂掉的 bundle
    NSString* currentBundleFilePath = [self getCurrentBundleFilePath:error];
    
    if (!currentBundleFilePath || *error) {
        return NO;
    }
    
    NSString* currentBundleFolderPath = [currentBundleFilePath stringByDeletingLastPathComponent];
    NSError* removeErrorBundleError = nil;
    
    if (![[NSFileManager defaultManager] removeItemAtPath:currentBundleFolderPath
                                                   error:&removeErrorBundleError]) {
        
        NSLog(@"BR warning:cannot remove error bundle folder[%@]: %@", currentBundleFolderPath, removeErrorBundleError);

    }
    
    NSString* bundleVersion = status[@"bundleVersion"];
    NSString* previousBundleVersion = status[@"previousBundleVersion"];
    
    // 把当前 bundle 加入黑名单
    NSError* markErrorBundleError = nil;
    if (![self setBundleInstallError:bundleVersion error:&markErrorBundleError]) {
        NSLog(@"BR warning:cannot save error bundle info %@", markErrorBundleError);
    }
    
    NSLog(@"BR: current bundle version %@, previous bundle version %@", bundleVersion, previousBundleVersion);
    
    // 更新 app 的状态
    if (previousBundleVersion == nil) {
        NSLog(@"BR:cannot find previous bundle version, we are going to use embed bundle.");
        [status removeObjectForKey:@"bundleVersion"];
    }
    else {
        NSLog(@"BR:get previous bundle version %@", previousBundleVersion);
        [status setValue:previousBundleVersion forKey:@"bundleVersion"];
    }
    
    [status removeObjectForKey:@"previousBundleVersion"];

    if (![self saveStatus:status error:error]) {
        return NO;
    }
    
    // TODO 报告当前 bundle 挂球了
    
    
    return YES;
    
}

static NSString* const BR_ERROR_BUNDLE_FILE_NAME = @"bundle-rocket-error-bundles.json";

+ (BOOL)setBundleInstallError:(NSString *)bundleVersion error:(NSError *__autoreleasing *)error {

    NSString* rootFile = [BRUtil getRootFolderPath];
    NSString* errorBundleFilePath = [rootFile stringByAppendingPathComponent:BR_ERROR_BUNDLE_FILE_NAME];
    
    NSFileManager* manager = [NSFileManager defaultManager];
    
    NSMutableArray* errorBundles;
    
    if ([manager fileExistsAtPath:errorBundleFilePath]) {
        
        NSData* content = [manager contentsAtPath:errorBundleFilePath];
        
        errorBundles = [[NSJSONSerialization JSONObjectWithData:content
                                                       options:kNilOptions
                                                         error:error] mutableCopy];
        
        if (*error) {
            return NO;
        }
        
        
    } else {
        errorBundles = [[NSMutableArray alloc] init];
    }
    
    [errorBundles addObject:bundleVersion];
    
    [manager createFileAtPath:errorBundleFilePath
                     contents:[NSJSONSerialization dataWithJSONObject:errorBundles
                                                              options:kNilOptions
                                                                error:error]
                   attributes:nil];
    
    if (*error) {
        return NO;
    }
    
    return YES;

}

+ (BOOL)isBundleInstallPending {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    return [[defaults objectForKey:BR_BUNDLE_UPDATE_PENDING] boolValue];
    
}

+ (BOOL)isBundleLoading {
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:BR_BUNDLE_LOADING] boolValue];
    
}

+ (void)setBundleLoading:(BOOL)isLoading {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[NSNumber numberWithBool:YES] forKey:BR_BUNDLE_LOADING];
    [defaults synchronize];
    
}

+ (BOOL)clearUpAfterBundleInstallSucceed:(NSError**)error {

    // 清除掉状态标识
    NSUserDefaults* preferences = [NSUserDefaults standardUserDefaults];
    
    [preferences removeObjectForKey:BR_BUNDLE_UPDATE_PENDING];
    [preferences removeObjectForKey:BR_BUNDLE_LOADING];
    [preferences synchronize];
    
    
    NSMutableDictionary* status = [[self getStatus:error] mutableCopy];
    
    if (*error) {
        return NO;
    }
    
    // 更新 app 状态文件：移除状态文件中的 previousBundleVersion 字段
    [status removeObjectForKey:@"previousBundleVersion"];
    
    if (![self saveStatus:status error:error]) {
        return NO;
    }
    
    // 尝试删掉上一个版本文件
    NSString* previousBundleVersion = status[@"previousBundleVersion"];
    
    if (previousBundleVersion) {
        
        NSFileManager* manager = [NSFileManager defaultManager];
        NSString* rootFolderPath = [BRUtil getRootFolderPath];
        NSString* previousBundleFolderPath = [rootFolderPath stringByAppendingPathComponent:previousBundleVersion];
        NSError* deletePreviousBundleError = nil;
        
        [manager removeItemAtPath:previousBundleFolderPath error:&deletePreviousBundleError];
        
        if (deletePreviousBundleError) {
            NSLog(@"[warn] BR: cannot delete previous bundle files %@: %@", previousBundleFolderPath, deletePreviousBundleError);
        }
    
    }
    
    return YES;
    
}

+ (NSArray*)getErrorBundleVersions {

    NSFileManager* manager = [NSFileManager defaultManager];
    NSString* rootFolderPath = [BRUtil getRootFolderPath];
    NSString* errorBundleFilePath = [rootFolderPath stringByAppendingPathComponent:BR_ERROR_BUNDLE_FILE_NAME];
    
    if (![manager fileExistsAtPath:errorBundleFilePath]) {
        return nil;
    }
    
    NSData* content = [manager contentsAtPath:errorBundleFilePath];
    
    NSError* error = nil;
    
    NSArray* data = [NSJSONSerialization JSONObjectWithData:content options:kNilOptions error:&error];
    
    if (error) {
        return nil;
    }
    
    return data;

}

@end
