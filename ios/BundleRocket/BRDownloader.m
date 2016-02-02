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
@property NSOutputStream *outputStream;
@property (retain) NSURLSession *session;
@property (retain) NSString *toFilePath;
@property (retain) BRMD5* md5;
@property (copy) NSString* shasum;

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
  outputFilePath:(NSString *)outputFilePath
          shasum:(NSString *)shasum {
    
    NSLog(@"download from %@ to %@", bundleURL, outputFilePath);
    
    self.stage = BRDownloaderStageStart;
    self.toFilePath = outputFilePath;
    self.shasum = shasum;
    
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
    self.outputStream = [NSOutputStream outputStreamToFileAtPath:self.toFilePath append:NO];
    
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
    
    if (error) {
        [self.outputStream close];
        self.failCallback(error);
        return;
    }
    
    NSString *md5 = [self.md5 digest];
    
    NSLog(@"bundle file md5[%@] vs expected md5[%@]", md5, self.shasum);
    
    if (![md5 isEqualToString:self.shasum]) {
        self.failCallback([[NSError alloc] initWithDomain:@"BundleRocket"
                                                     code:409
                                                 userInfo:@{NSLocalizedDescriptionKey: @"shasum mismatch"}]);
        return;
    }
    
    self.doneCallback(@{@"totalBytesExpected": [NSNumber numberWithInteger:self.totalBytesExpected]});
}

@end
