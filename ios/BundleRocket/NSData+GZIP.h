//
//  NSData+GZIP.h
//  BundleRocket
//
//  Created by leon on 16/2/3.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef NSDATA_GZIP_H
#define NSDATA_GZIP_H

@interface NSData (GZIP)

- (nullable NSData *)gzippedDataWithCompressionLevel:(float)level;
- (nullable NSData *)gzippedData;
- (nullable NSData *)gunzippedData;
- (BOOL)isGzippedData;

@end

#endif