//
//  BRMD5.m
//
//  Created by leon on 16/2/2.
//  Copyright © 2016年 com.ludafa. All rights reserved.
//

#import "BRMD5.h"

@implementation BRMD5 {
    
    CC_MD5_CTX hash;
    
}

- (id)init {
    
    CC_MD5_Init(&hash);
    
    return (self);
    
}

- (void)update:(NSData *)data {
    
    unsigned int dataLength = (unsigned int)[data length];
    
    CC_MD5_Update(&hash, [data bytes], dataLength);
    
}

- (NSString *)digest {
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5_Final(digest, &hash);
    
    NSString* s = [NSString stringWithFormat:
                   @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    
    return s;
    
}

@end


