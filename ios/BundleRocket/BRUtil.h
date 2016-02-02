//
//  BRUtil.h
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRUtil : NSObject

+ (NSString *)getFolderPath:(NSInteger)type;

+ (NSString *)getRootFolderPath;

+ (NSString *)getCacheFolderPath;

//+ (NSString *)shasum:(NSFileHandle *)fileHandle;

@end
