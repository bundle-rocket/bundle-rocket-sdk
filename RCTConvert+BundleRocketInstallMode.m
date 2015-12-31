#import "BundleRocket.h"
#import "RCTConvert.h"

// Extending the RCTConvert class allows the React Native
// bridge to handle args of type "BundleRocketInstallMode"
@implementation RCTConvert (BundleRocketInstallMode)

RCT_ENUM_CONVERTER(BundleRocketInstallMode, (@{ @"bundleRocketInstallModeImmediate": @(BundleRocketInstallModeImmediate),
                                            @"bundleRocketInstallModeOnNextRestart": @(BundleRocketInstallModeOnNextRestart),
                                            @"bundleRocketInstallModeOnNextResume": @(BundleRocketInstallModeOnNextResume) }),
                   BundleRocketInstallModeImmediate, // Default enum value
                   integerValue)

@end