//
//  NSFileManager+Tar.h
//  BundleRocket
//
//  Created by leon on 16/2/3.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  Block to follow the extracting of the archive
 *
 *  @param float Percentage of the archive extracted
 */
typedef void(^NSFileManagerTarProgressBlock)(float);


@interface NSFileManager (Tar)


/**
 *  Extract the tar archive into the directory at the url.
 *
 *  @param url           URL of the destination directory
 *  @param tarData       Tar archive
 *  @param error         Error occuring during the extraction of the archive
 *  @param progressBlock Block to follow the percentage of archive extracted
 *
 *  @return `YES` if the archive has been successfully extracted
 */
- (BOOL)createFilesAndDirectoriesAtURL:(NSURL *)url
                           withTarData:(NSData *)tarData
                                 error:(NSError **)error
                              progress:(NSFileManagerTarProgressBlock)progressBlock;
/**
 *  Extract the tar archive into the given directory.
 *
 *  @param path          Path of the destination directory
 *  @param tarData       Tar archive
 *  @param error         Error occuring during the extraction of the archive
 *  @param progressBlock Block to follow the percent of archive extracted
 *
 *  @return `YES` if the archive has been successfully extracted
 */
- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path
                            withTarData:(NSData *)tarData
                                  error:(NSError **)error
                               progress:(NSFileManagerTarProgressBlock)progressBlock;
/**
 *  Extract the tar archive into the directory at the url.
 *
 *  @param path          Path of the destination directory
 *  @param tarPath       Path of the archive
 *  @param error         Error occuring during the extraction of the archive
 *  @param progressBlock Block to follow the percent of archive extracted
 *
 *  @return `YES` if the archive has been successfully extracted
 */
- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path
                            withTarPath:(NSString *)tarPath
                                  error:(NSError **)error
                               progress:(NSFileManagerTarProgressBlock)progressBlock;


@end

/**
 *  Error corresponding particularly to Light-Untar library.
 */
extern NSString * const NSFileManagerLightUntarErrorDomain;
