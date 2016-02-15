//
//  BRTracer.h
//  BundleRocket
//
//  Tracer 会收集当前 Bundle 版本、Bundle 操作记录（下载、安装、回滚）
//  这些数据会汇报给 BundleRocketServer
//
//  Created by leon on 16/2/15.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef BR_TRACER_H

#define BR_TRACER_H

@interface BRTracer : NSObject

+ (void)log:(NSString*)message;

@end


#endif
