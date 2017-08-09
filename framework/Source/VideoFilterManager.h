//
//  VideoFilterManager.h
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUImageFilterGallery.h"
@class GPUImageFilterGroup;


@interface VideoFilterManager : NSObject

+ (VideoFilterManager *)sharedInstance;

- (GPUImageOutput<GPUImageInput> *)filterWithVideoStyle:(ALYCEVideoStyle)videoStyle
                                            colorFilter:(ALYCEColorFilter)colorFilter
                                     airbrushFilterType:(AirbrushFilterType)airbrushFilterType;

@end
