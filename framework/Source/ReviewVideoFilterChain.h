//
//  ReviewVideoFilterChain.h
//  Sing
//
//  Created by Anton Holmberg on 8/9/17.
//  Copyright © 2017 Smule. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUImage.h"
#import <AVFoundation/AVFoundation.h>
#import "GPUImageFilterGallery.h"

static const CGFloat kDefaultGammaAdjustment = 1.0f;
static const CGFloat kDefaultSaturationAdjustment = 1.0f;

// ReviewVideoFilterChain manages the GPUImage filter chain on the review screen.

@interface ReviewVideoFilterChain : NSObject

@property (nonatomic) CGFloat gammaAdjustment;
@property (nonatomic) CGFloat saturationAdjustment;
@property (nonatomic, readonly) BOOL hasSetPlayerItem;

- (void)setLocalVideoPlayerItem:(AVPlayerItem *)localVideoPlayerItem;
- (void)setDuetSeedPlayerItem:(AVPlayerItem *)duetSeedPlayerItem;
- (void)setFilterView:(GPUImageView *)filterView;

- (void)setVideoStyle:(ALYCEVideoStyle)videoStyle
          colorFilter:(ALYCEColorFilter)colorFilter
   airbrushFilterType:(AirbrushFilterType)airbrushFilterType;

- (void)startProcessing;
- (void)pauseProcessing;
- (void)resumeProcessing;
- (void)endProcessing;

- (void)updateChain:(BOOL)userIsLeft;
- (void)unchainGPUImageMovieFromFilterView;
- (void)chainGPUImageMovieToFilterView:(BOOL)userIsLeft;

@end
