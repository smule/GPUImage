//
//  ReviewVideoFilterChain.m
//  Sing
//
//  Created by Anton Holmberg on 8/9/17.
//  Copyright © 2017 Smule. All rights reserved.
//

#import "ReviewVideoFilterChain.h"
#import "GPUImageALYCEFilter.h"

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
        self.alyceFilter = [[GPUImageALYCEFilter alloc] init];
        self.alyceFilter.currentTime = 0.0;
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
    if (![[self.localFilterMovie targets] containsObject:self.alyceFilter])
    {
        [self unchainGPUImageMovieFromFilterView];
        [self chainGPUImageMovieToFilterView:userIsLeft];
    }
}

- (void)chainGPUImageMovieToFilterView:(BOOL)userIsLeft
{
    // There's nothing to do if we don't have a filter view
    if (!_filterView)
    {
        return;
    }
    
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
        if (userIsLeft)
        {
            [prevFilter addTarget:self.alyceFilter atTextureLocation:0];
            [self.duetSeedFilterMovie addTarget:self.alyceFilter atTextureLocation:1];
            self.alyceFilter.userInputIndex = 0;
            [self.alyceFilter setUserInputIndex:0];
        }
        else
        {
            [self.duetSeedFilterMovie addTarget:self.alyceFilter atTextureLocation:0];
            [prevFilter addTarget:self.alyceFilter atTextureLocation:1];
            self.alyceFilter.userInputIndex = 1;
        }
    }
    else
    {
        [prevFilter addTarget:self.alyceFilter];
    }
    
    [self.alyceFilter addTarget:_filterView];
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
    
    [self.alyceFilter removeAllTargets];
}

@end
