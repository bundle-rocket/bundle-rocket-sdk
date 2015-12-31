#import "BundleRocket.h"

@implementation BundleRocketConfig {
    NSMutableDictionary *_configDictionary;
}

static BundleRocketConfig *_currentConfig;

static NSString * const AppVersionConfigKey = @"appVersion";
static NSString * const BuildVdersionConfigKey = @"buildVersion";
static NSString * const DeploymentKeyConfigKey = @"deploymentKey";
static NSString * const ServerURLConfigKey = @"serverUrl";

+ (instancetype)current
{
    return _currentConfig;
}

+ (void)initialize
{
    _currentConfig = [[BundleRocketConfig alloc] init];
}

- (instancetype)init
{
    self = [super init];
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];

    NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *buildVersion = [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *deploymentKey = [infoDictionary objectForKey:@"BundleRocketDeploymentKey"];
    NSString *serverURL = [infoDictionary objectForKey:@"BundleRocketServerURL"];

    if (!serverURL) {
        serverURL = @"https://codepush.azurewebsites.net/";
    }

    _configDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                            appVersion,AppVersionConfigKey,
                            buildVersion,BuildVdersionConfigKey,
                            serverURL,ServerURLConfigKey,
                            deploymentKey,DeploymentKeyConfigKey,
                            nil];

    return self;
}

- (NSString *)appVersion
{
    return [_configDictionary objectForKey:AppVersionConfigKey];
}

- (NSString *)buildVersion
{
    return [_configDictionary objectForKey:BuildVdersionConfigKey];
}

- (NSDictionary *)configuration
{
    return _configDictionary;
}

- (NSString *)deploymentKey
{
    return [_configDictionary objectForKey:DeploymentKeyConfigKey];
}

- (NSString *)serverURL
{
    return [_configDictionary objectForKey:ServerURLConfigKey];
}

- (void)setDeploymentKey:(NSString *)deploymentKey
{
    [_configDictionary setValue:deploymentKey forKey:DeploymentKeyConfigKey];
}

- (void)setServerURL:(NSString *)serverURL
{
    [_configDictionary setValue:serverURL forKey:ServerURLConfigKey];
}

@end