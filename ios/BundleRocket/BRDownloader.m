//
//  BundleRocketDownloader.m
//  BundleRocket
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import "BRDownloader.h"

@interface BRDownloader()

@property (copy) BRDownloaderDoneCallback doneCallback;
@property (copy) BRDownloaderFailCallback failCallback;
@property (copy) BRDownloaderProgressCallback progressCallback;

@property BRDownloaderStage stage;

@property (retain) NSOutputStream* outputStream;
@property (retain) NSURLSession* session;

@property (copy) NSString* toFolderPath;
@property (copy) NSString* deploymentKey;
@property (copy) NSString* shasum;

@property (retain) BRMD5* md5;

@property long long totalBytesExpected;
@property long long totalBytesWritten;

@end

@implementation BRDownloader

- (id)init:(BRDownloaderDoneCallback)doneCallback
    failCallback:(BRDownloaderFailCallback)failCallback
progressCallback:(BRDownloaderProgressCallback)progessCallback {
    
    self.stage = BRDownloaderStageInit;

    self.doneCallback = doneCallback;
    self.failCallback = failCallback;
    self.progressCallback = progessCallback;
    
    return (self);
    
}

- (void)download:(NSString *)bundleURL
outputFolderPath:(NSString *)outputFolderPath
          shasum:(NSString *)shasum
   deploymentKey:(NSString *)deploymentKey {
    
    NSLog(@"download from %@ to %@", bundleURL, outputFolderPath);
    
    self.stage = BRDownloaderStageStart;
    self.toFolderPath = outputFolderPath;
    self.shasum = shasum;
    self.deploymentKey = deploymentKey;
    
    // 生成 session 的 configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    // 生成下载缓存文件路径
    NSString *cacheFolderPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *cacheFilePath = [[cacheFolderPath
                                stringByAppendingPathComponent:@"/BundleRocket/"] stringByAppendingPathComponent:@"download.cache"];
    
    // 生成缓存
    config.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:16384
                                                    diskCapacity:268435456
                                                        diskPath:cacheFilePath];

    
    self.session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithURL:[NSURL URLWithString:bundleURL]];
    
    [task resume];

}



#pragma mark NSURLSessionDataDelegate Delegate Methods

// 接受到了响应头
// 如果响应头中 statusCode 不是 2++，那么直接干掉响应；意味着请求已失败。
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
    
    NSInteger statusCode = httpURLResponse.statusCode;
    
    if (statusCode < 200 && statusCode >= 300) {
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    

    self.stage = BRDownloaderStagePending;
    self.totalBytesExpected = httpURLResponse.expectedContentLength;
    self.md5 = [[BRMD5 alloc] init];
    
    NSError* error = nil;
    NSString* toFilePath = self.toFolderPath;
    
    NSFileManager* manager = [NSFileManager defaultManager];
    
    if (![manager createDirectoryAtPath:toFilePath
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error]) {
        
        completionHandler(NSURLSessionResponseCancel);
        self.failCallback(error);
        return;
        
    }

    
    NSString* tmpBundleFilePath = [self.toFolderPath stringByAppendingPathComponent:@"bundle.tar.gz"];
    
    self.outputStream = [NSOutputStream outputStreamToFileAtPath:tmpBundleFilePath
                                                          append:NO];
    
    [self.outputStream open];
    
    completionHandler(NSURLSessionResponseAllow);
    
}

//
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    
    NSInteger bytesLeft = [data length];
    
    self.totalBytesWritten += bytesLeft;
    
    NSOutputStream *outputStream = self.outputStream;
    
    do {
        
        NSInteger bytesWritten = [outputStream write:[data bytes] maxLength:bytesLeft];
        
        if (bytesWritten < 0) {
            break;
        }
        
        bytesLeft -= bytesWritten;
        
    }
    while (bytesLeft > 0);
    
    if (bytesLeft > 0) {
        [outputStream close];
        [dataTask cancel];
        self.failCallback([outputStream streamError]);
        return;
    }
    
    [self.md5 update:data];
    
    self.progressCallback([NSNumber numberWithInteger:self.totalBytesWritten],
                          [NSNumber numberWithInteger:self.totalBytesExpected]);
    
}

- (void)URLSession:(NSURLSession *)session
                task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    
    NSLog(@"download complete");
    
    // 如果在接收数据过程出现了问题，那么就直接返回错误
    if (error) {
        
        NSLog(@"%@", error);
        
        [self.outputStream close];
        self.failCallback(error);
        return;
    }
    
    // 计算下载到的 bundle 的 md5 值
    NSString *md5 = [self.md5 digest];
    
    NSLog(@"bundle md: %@, expected md5: %@", md5, self.shasum);
    
    // 如果 md5 值不匹配，返回 md5 匹配错误
    if (![md5 isEqualToString:self.shasum]) {
        self.failCallback([[NSError alloc] initWithDomain:@"BRErrorDomain"
                                                     code:409
                                                 userInfo:@{NSLocalizedDescriptionKey: @"shasum mismatch"}]);
        return;
    }
    
    // 解压 gzip
    NSString* toFolderPath = self.toFolderPath;
    NSString* tmpBundleFilePath = [toFolderPath stringByAppendingPathComponent:@"bundle.tar.gz"];
    
    NSFileManager* mananger = [NSFileManager defaultManager];
    
    NSData* bundleData = [mananger contentsAtPath:tmpBundleFilePath];
    
    if (![bundleData isGzippedData]) {
        self.failCallback([[NSError alloc]initWithDomain:@"BundleRocket"
                                                    code:500
                                                userInfo:@{NSLocalizedDescriptionKey:@"invalid bundle format; expect`tar.gz` format."}]) ;
        return;
    }
    
    // 解压 tar
    NSError* untarError;
    
    if (![mananger createFilesAndDirectoriesAtPath:toFolderPath
                                  withTarData:[bundleData gunzippedData]
                                        error:&untarError
                                     progress:^(float percent) {
                                         NSLog(@"untar progress: %f", percent);
                                     }]) {
                                         self.failCallback(untarError);
                                         return;
    };
    
   
    // 关闭临时文件输出流
    [self.outputStream close];
    
    // 尝试移除临时 bundle.tar.gz，不成功也没关系
    [mananger removeItemAtPath:tmpBundleFilePath error:nil];
    
    NSLog(@"bundle.tar.gz decompressed");
    
    // 成功
    self.doneCallback(@{
        @"totalBytes": [NSNumber numberWithInteger:self.totalBytesExpected],
        @"location": toFolderPath});
}

@end
