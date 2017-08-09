//
//  VideoFilterManager.m
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import "GPUImage.h"
#import "IndexingFilter.h"
#import "StepFilter.h"
#import "VideoFilterManager.h"
#import "MaskBlendFilter.h"
#import "ScaleFilter.h"


@interface VideoFilterManager ()

@property (nonatomic, strong) GPUImageFilterGallery *filterGallery;

@end

@implementation VideoFilterManager

#pragma mark - class methods

+ (VideoFilterManager *)sharedInstance {
    static VideoFilterManager *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        shared = [[VideoFilterManager alloc] init];
    });
    
    return shared;
}

- (instancetype)init
{
    if (self = [super init]) {
        [self setupGPUFilters];
    }
    
    return self;
}

- (void)setupGPUFilters {
    self.filterGallery = [GPUImageFilterGallery sharedInstance];
}

#pragma mark - public methods

- (GPUImageOutput<GPUImageInput> *)filterWithVideoStyle:(ALYCEVideoStyle)videoStyle
                                            colorFilter:(ALYCEColorFilter)colorFilter
                                     airbrushFilterType:(AirbrushFilterType)airbrushFilterType {
    runSynchronouslyOnVideoProcessingQueue(^{
        [self.filterGallery setInputRotation:kGPUImageNoRotation atIndex:0];
        self.filterGallery.videoStyle = videoStyle;
        self.filterGallery.colorFilter = colorFilter;
        self.filterGallery.airbrushFilterType = airbrushFilterType;
    });
    return self.filterGallery;
}

@end
