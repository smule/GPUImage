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

NSString * const kAirbrushFilterIdentifier = @"airbrush";

@interface VideoFilterManager ()

@property (nonatomic, strong) GPUImageFilterGallery *filterGallery;

@end

@implementation VideoFilterVariables

+ (VideoFilterVariables *)sharedInstance {
    static VideoFilterVariables *shared = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        shared = [[VideoFilterVariables alloc] init];
    });
    return shared;
}

@end

@implementation VideoFilterManager

#pragma mark - class methods

+ (VideoFilterManager *)sharedInstance {
    static VideoFilterManager *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        shared = [[VideoFilterManager alloc] init];
        shared.filterList = [VideoFilterVariables sharedInstance].filterList;
        shared.vipFilters = [VideoFilterVariables sharedInstance].vipFilters;
    });
    
    return shared;
}

#pragma mark - properties

- (void)setVipFilters:(NSArray *)vipFilters {
    if (_vipFilters == vipFilters) {
        return;
    }

    if ([vipFilters.firstObject isKindOfClass:[NSString class]]) {
        NSMutableArray *filterArray = [NSMutableArray array];

        for (NSString *filterName in vipFilters) {
            VideoFilterType type = [self filterTypeForName:filterName];
            if ((NSInteger)type >= 0) {
                [filterArray addObject:@(type)];
            }
        }

        _vipFilters = filterArray;
    } else {
        NSLog(@"vip filter list object type is not supported!");
        _vipFilters = @[];
        return;
    }
}

- (void)setFilterList:(NSArray *)filterList {
    if (_filterList == filterList) {
        return;
    }

    // We'll only accept
    if ([filterList.firstObject isKindOfClass:[NSString class]]) {
        NSMutableArray *filterArray = [NSMutableArray array];

        for (NSString *filterName in filterList) {
            VideoFilterType type = [self filterTypeForName:filterName];
            if ((NSInteger)type >= 0) {
                [filterArray addObject:@(type)];
            }
        }

        _filterList = filterArray;
    } else {
        NSLog(@"filter order list object type is not supported! normal will be only filter available");
        _filterList = @[@(VideoFilterTypeNormal)];
        return;
    }

    [self setupGPUFilters];
}

- (void)setupGPUFilters {
    self.filterGallery = [GPUImageFilterGallery sharedInstance];
}

#pragma mark - private methods

- (void)configureGalleryForVideoFilterType:(VideoFilterType)videoFilterType {
    if (videoFilterType == VideoFilterTypeNormal) {
        self.filterGallery.videoStyle = ALYCEVideoStyleClassic;
        self.filterGallery.colorFilter = ALYCEColorFilterNone;
    } else if (videoFilterType == VideoFilterTypeSepia) {
        self.filterGallery.videoStyle = ALYCEVideoStyleClassic;
        self.filterGallery.colorFilter = ALYCEColorFilterSepia;
    } else if (videoFilterType == VideoFilterTypeBlackWhite) {
        self.filterGallery.videoStyle = ALYCEVideoStyleClassic;
        self.filterGallery.colorFilter = ALYCEColorFilterBlackAndWhite;
    } else if (videoFilterType == VideoFilterTypeVintage) {
        self.filterGallery.videoStyle = ALYCEVideoStyleOslo;
        self.filterGallery.colorFilter = ALYCEColorFilterVibrant;
    } else if (videoFilterType == VideoFilterTypeSelfie) {
        self.filterGallery.videoStyle = ALYCEVideoStyleRio;
        self.filterGallery.colorFilter = ALYCEColorFilterSoft;
    } else if (videoFilterType == VideoFilterTypeFightClub) {
        self.filterGallery.videoStyle = ALYCEVideoStylePetra;
        self.filterGallery.colorFilter = ALYCEColorFilterMono;
    } else {
        NSLog(@"Unrecognized video filter type");
    }
}


#pragma mark - public methods

- (NSString *)filterNameForType:(VideoFilterType)videoFilterType {
    switch (videoFilterType) {
    case VideoFilterTypeNormal:
        return @"normal";
        break;
    case VideoFilterTypeSepia:
        return @"sepia";
        break;
    case VideoFilterTypeBlackWhite:
        return @"bw";
        break;
    case VideoFilterTypeVintage:
        return @"vintge";
        break;
    case VideoFilterTypeSelfie:
        return @"selfie";
        break;
    case VideoFilterTypeFightClub:
        return @"fight";
        break;
    default:
        return @"normal";
        break;
    }
}

- (BOOL)isVIPOnlyFilter:(VideoFilterType)videoFilterType {
    return [self.vipFilters containsObject:@(videoFilterType)];
}

- (VideoFilterType)filterTypeForName:(NSString *)videoFilterName {
    NSDictionary *filterNameTypeMap = @{
        @"normal": @(VideoFilterTypeNormal),
        @"sepia": @(VideoFilterTypeSepia),
        @"selfie": @(VideoFilterTypeSelfie),
        @"fight": @(VideoFilterTypeFightClub),
        @"vintage": @(VideoFilterTypeVintage),
        @"bw": @(VideoFilterTypeBlackWhite)
    };

    NSNumber *typeNum = filterNameTypeMap[videoFilterName];
    return (VideoFilterType)typeNum.integerValue;
}

- (GPUImageOutput<GPUImageInput> *)filterWithFilterNames:(NSArray<NSString *> *)filterNames {
    
    BOOL includeAirbrushFilter = [filterNames containsObject:kAirbrushFilterIdentifier];
    NSString *lensFilterName = [filterNames lastObject];
    
    for (int i = 0; i < self.filterList.count; i++) {
        VideoFilterType type = [self.filterList[i] integerValue];
        NSString *name = [self filterNameForType:type];
        
        if ([name isEqualToString:lensFilterName]) {
            return [self filterGroupForType:type includeAirbrushFilter:includeAirbrushFilter];
        }
    }
    
    // default (normal. no FX).
    return [self filterGroupForType:VideoFilterTypeNormal includeAirbrushFilter:includeAirbrushFilter];
}

- (GPUImageOutput <GPUImageInput> *)filterGroupForType:(VideoFilterType)videoFilterType
                                 includeAirbrushFilter:(BOOL)includeAirbrushFilter {
    [self configureGalleryForVideoFilterType:videoFilterType];
    [self.filterGallery removeAllTargets];
    self.filterGallery.airbrushFilterType = includeAirbrushFilter ? AirbrushFilterTypeComplex : AirbrushFilterTypeNone;
    return self.filterGallery;
}

- (GPUImageOutput<GPUImageInput> *)filterWithType:(VideoFilterType)videoFilterType
                               airbrushFilterType:(AirbrushFilterType)airbrushFilterType {
    [self configureGalleryForVideoFilterType:videoFilterType];
    [self.filterGallery removeAllTargets];
    self.filterGallery.airbrushFilterType = airbrushFilterType;
    [self.filterGallery setInputRotation:kGPUImageNoRotation atIndex:0];
    return self.filterGallery;
}

- (GPUImageOutput<GPUImageInput> *)filterWithVideoStyle:(ALYCEVideoStyle)videoStyle
                                            colorFilter:(ALYCEColorFilter)colorFilter
                                     airbrushFilterType:(AirbrushFilterType)airbrushFilterType {
    self.filterGallery.videoStyle = videoStyle;
    self.filterGallery.colorFilter = colorFilter;
    [self.filterGallery removeAllTargets];
    self.filterGallery.airbrushFilterType = airbrushFilterType;
    [self.filterGallery setInputRotation:kGPUImageNoRotation atIndex:0];
    return self.filterGallery;
}

@end
