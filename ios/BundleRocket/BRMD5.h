//
//  BRMD5.h
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CommonCrypto/CommonDigest.h>

@interface BRMD5 : NSObject

- (void)update:(NSData *)data;

- (NSString *)digest;

@end
