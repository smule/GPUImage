//
//  ReviewVideoFilterChain.m
//  Sing
//
//  Created by Anton Holmberg on 8/9/17.
//  Copyright © 2017 Smule. All rights reserved.
//

#import "ReviewVideoFilterChain.h"

@interface ReviewVideoFilterChain ()

@property(nonatomic, strong) GPUImageView *filterView;
@property(nonatomic, strong) GPUImageGammaFilter *gammaFilter;
@property(nonatomic, strong) GPUImageSaturationFilter *saturationFilter;
@property(nonatomic, strong) GPUImageMovie *localFilterMovie;
@property(nonatomic, strong) GPUImageMovie *duetSeedFilterMovie;
@property (nonatomic) BOOL localFilterMovieIsProcessing;
@property (nonatomic) BOOL duetSeedFilterMovieIsProcessing;

@end

@implementation ReviewVideoFilterChain

- (id)init
{
    self = [super init];
    
    if (self)
    {
        self.gammaAdjustment = kDefaultGammaAdjustment;
        self.saturationAdjustment = kDefaultSaturationAdjustment;
    }
    
    return self;
}

- (void)setLocalVideoPlayerItem:(AVPlayerItem *)localVideoPlayerItem
{
    _localFilterMovie = [[GPUImageMovie alloc] initWithPlayerItem:localVideoPlayerItem];
}

- (void)setDuetSeedPlayerItem:(AVPlayerItem *)duetSeedPlayerItem
{
    _duetSeedFilterMovie = [[GPUImageMovie alloc] initWithPlayerItem:duetSeedPlayerItem];
}

- (BOOL)hasSetPlayerItem
{
    return self.localFilterMovie || self.duetSeedFilterMovie;
}

- (void)setFilterView:(GPUImageView *)filterView
{
    _filterView = filterView;
}

- (void)startProcessing
{
    if (self.localFilterMovie && !self.localFilterMovieIsProcessing)
    {
        [self.localFilterMovie startProcessing];
        self.localFilterMovieIsProcessing = YES;
    }
    
    if (self.duetSeedFilterMovie && !self.duetSeedFilterMovieIsProcessing)
    {
        [self.duetSeedFilterMovie startProcessing];
        self.duetSeedFilterMovieIsProcessing = YES;
    }
}

- (void)pauseProcessing
{
    [self.localFilterMovie pauseProcessing];
    [self.duetSeedFilterMovie pauseProcessing];
    self.localFilterMovieIsProcessing = NO;
    self.duetSeedFilterMovieIsProcessing = NO;
}

- (void)resumeProcessing
{
    if (self.localFilterMovie)
    {
        [self.localFilterMovie resumeProcessing];
        self.localFilterMovieIsProcessing = YES;
    }
    if (self.duetSeedFilterMovie)
    {
        [self.duetSeedFilterMovie resumeProcessing];
        self.duetSeedFilterMovieIsProcessing = YES;
    }
}

- (void)endProcessing
{
    [self.localFilterMovie endProcessing];
    [self.duetSeedFilterMovie endProcessing];
    self.localFilterMovieIsProcessing = NO;
    self.duetSeedFilterMovieIsProcessing = NO;
}

- (void)updateChain:(BOOL)userIsLeft
{
    
    if ( ![[self.localFilterMovie targets] containsObject:[GPUImageFilterGallery sharedInstance]])
    {
        [self unchainGPUImageMovieFromFilterView];
        [self chainGPUImageMovieToFilterView:userIsLeft];
    }
}

- (void)chainGPUImageMovieToFilterView:(BOOL)userIsLeft
{
    GPUImageOutput *prevFilter = _localFilterMovie;
    
    // put together the filter chain
    if (userIsLeft && _gammaAdjustment != kDefaultGammaAdjustment)
    {
        if (!_gammaFilter)
        {
            _gammaFilter = [[GPUImageGammaFilter alloc] init];
        }
        
        _gammaFilter.gamma = _gammaAdjustment;
        [prevFilter addTarget:_gammaFilter];
        prevFilter = _gammaFilter;
    }
    if (userIsLeft && _saturationAdjustment != kDefaultSaturationAdjustment)
    {
        if (!_saturationFilter)
        {
            _saturationFilter = [[GPUImageSaturationFilter alloc] init];
        }
        
        _saturationFilter.saturation = _saturationAdjustment;
        [prevFilter addTarget:_saturationFilter];
        prevFilter = _saturationFilter;
    }
    
    if (self.duetSeedFilterMovie && self.localFilterMovie)
    {
        [GPUImageFilterGallery sharedInstance].inputCount = 2;
        if (userIsLeft)
        {
            [prevFilter addTarget:[GPUImageFilterGallery sharedInstance] atTextureLocation:0];
            [self.duetSeedFilterMovie addTarget:[GPUImageFilterGallery sharedInstance] atTextureLocation:1];
            [[GPUImageFilterGallery sharedInstance] setUserInputIndex:0];
        }
        else
        {
            [self.duetSeedFilterMovie addTarget:[GPUImageFilterGallery sharedInstance] atTextureLocation:0];
            [prevFilter addTarget:[GPUImageFilterGallery sharedInstance] atTextureLocation:1];
            [[GPUImageFilterGallery sharedInstance] setUserInputIndex:1];
        }
    }
    else
    {
        [prevFilter addTarget:[GPUImageFilterGallery sharedInstance]];
    }
    
    [[GPUImageFilterGallery sharedInstance] addTarget:_filterView];
}

- (void)unchainGPUImageMovieFromFilterView
{
    [_localFilterMovie removeAllTargets];
    
    if (_duetSeedFilterMovie)
    {
        [_duetSeedFilterMovie removeAllTargets];
    }
    
    if (_gammaFilter)
    {
        [_gammaFilter removeAllTargets];
    }
    
    if (_saturationFilter)
    {
        [_saturationFilter removeAllTargets];
    }
    
    [[GPUImageFilterGallery sharedInstance] removeAllTargets];
}

- (void)setVideoStyle:(ALYCEVideoStyle)videoStyle
          colorFilter:(ALYCEColorFilter)colorFilter
   airbrushFilterType:(AirbrushFilterType)airbrushFilterType
{
    [GPUImageFilterGallery sharedInstance].videoStyle = videoStyle;
    [GPUImageFilterGallery sharedInstance].colorFilter = colorFilter;
    [GPUImageFilterGallery sharedInstance].airbrushFilterType = airbrushFilterType;
}

@end
