//
//  BRUtil.m
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import "BRUtil.h"

@implementation BRUtil

+ (NSString *)getFolderPath:(NSInteger)type {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(type, NSUserDomainMask, YES);
    
    return [[paths firstObject] stringByAppendingPathComponent:@"/BundleRocket"];
    
}

+ (NSString *)getRootFolderPath {
    return [self getFolderPath:NSApplicationSupportDirectory];
}

+ (NSString *)getCacheFolderPath {
    return [self getFolderPath:NSCachesDirectory];
}

@end
