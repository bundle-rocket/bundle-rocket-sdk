//
//  RCTConvert+BRInstallMode.m
//  BundleRocket
//
//  Created by leon on 16/2/15.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//


#import "RCTConvert+BRInstallMode.h"
#import "BRApp.h"

@implementation RCTConvert (BRInstallMode)

RCT_ENUM_CONVERTER(
                   BRInstallMode,
                   (@{ @"bundleRocketInstallModeOnNextRestart": @(BRInstallModeOnNextRestart),
                                    @"bundleRocketInstallModeOnNextResume": @(BRInstallModeOnNextResume),
                                    @"bundldRocketInstallModeNow" : @(BRInstallModeNow)}),
                   UIStatusBarAnimationNone,
                   integerValue);

@end
