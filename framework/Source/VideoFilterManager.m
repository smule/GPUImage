//
//  VideoFilterManager.m
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import "GPUImage.h"
#import "VideoFilterManager.h"

@interface VideoFilterManager ()

@property (nonatomic, strong) NSMutableArray *filters;

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

#pragma mark - private methods

- (NSUInteger)filterIndexWithWrapping:(NSUInteger)index {
    if (index > 0 && index <= self.filterList.count) {
        return index - 1;
    } else if (index == 0) {
        return self.filterList.count - 1;
    } else if (index == self.filterList.count + 1) {
        return 0;
    } else if (index == self.filterList.count + 2) {
        return 0;
    }
    
    // we should never get here but if we do, just return 0
    return 0;
}

- (void)setupGPUFilters {
    NSUInteger filterListCount = self.filterList.count + 2;
    self.filters = [[NSMutableArray alloc] initWithCapacity:filterListCount];

    for (int i = 0; i < filterListCount; i++) {
        self.filters[i] = [[GPUImageFilterGroup alloc] init];

        // Chain left filters together

        NSArray *leftFilters = [self filtersWithIndex:[self filterIndexWithWrapping:i]];
        int j = 0;
        for (GPUImageFilter *filter in leftFilters) {
            [self.filters[i] addFilter:filter];
            if (j < (leftFilters.count - 1)) {
                [filter addTarget:leftFilters[j + 1]];
            }
            j++;
        }

        // Chain right filters together

        NSArray *rightFilters = [self filtersWithIndex:[self filterIndexWithWrapping:(i + 1)]];
        j = 0;
        for (GPUImageFilter *filter in rightFilters) {
            [self.filters[i] addFilter:filter];
            if (j < (rightFilters.count - 1)) {
                [filter addTarget:rightFilters[j + 1]];
            }
            j++;
        }

        // Create split filter to filter part of image based on offset

        GPUImageSplitFilter *splitFilter = [[GPUImageSplitFilter alloc] init];
        [self.filters[i] addFilter:splitFilter];

        // Add split filter as a target to the final left and right filter

        [leftFilters[leftFilters.count - 1] addTarget:splitFilter];
        [rightFilters[rightFilters.count - 1] addTarget:splitFilter];

        [self.filters[i] setInitialFilters:[NSArray arrayWithObjects:leftFilters[0],
                                                                     rightFilters[0],
                                                                     splitFilter,
                                                                     nil]];
        [self.filters[i] setTerminalFilter:splitFilter];
    }
}

- (NSArray *)filtersWithIndex:(NSInteger)index {
    VideoFilterType videoFilterType = (VideoFilterType)[self.filterList[index] integerValue];
    
    if (videoFilterType == VideoFilterTypeNormal) {
        return @[[[GPUImageFilter alloc] init]];
    } else if (videoFilterType == VideoFilterTypeSepia) {
        GPUImageCustomLookupFilter *sepia =
        [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_sepia.png"];
        return @[sepia];
    } else if (videoFilterType == VideoFilterTypeSelfie) {
        GPUImageCustomLookupFilter *selfie =
        [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_selfie.png"];
        return @[selfie];
    } else if (videoFilterType == VideoFilterTypeVintage) {
        GPUImageCustomLookupFilter *vintage =
        [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_vintage.png"];
        return @[vintage];
    } else if (videoFilterType == VideoFilterTypeBlackWhite) {
        GPUImageGrayscaleFilter *bw = [[GPUImageGrayscaleFilter alloc] init];
        GPUImageLevelsFilter *levels = [[GPUImageLevelsFilter alloc] init];
        [levels setRedMin:.1 gamma:1.0 max:1.0 minOut:0.0 maxOut:1.0];
        [levels setGreenMin:.1 gamma:1.0 max:1.0 minOut:0.0 maxOut:1.0];
        [levels setBlueMin:.1 gamma:1.0 max:1.0 minOut:0.0 maxOut:1.0];
        return @[bw, levels];
    } else if (videoFilterType == VideoFilterTypeFightClub) {
        GPUImageCustomLookupFilter *fightclub =
        [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_fightclub.png"];
        return @[fightclub];
    } else {
        return @[[[GPUImageFilter alloc] init]];
    }
}

#pragma mark - public methods

- (NSString *)filterNameAtIndex:(NSUInteger)index {
    VideoFilterType type = (VideoFilterType)[self.filterList[index] integerValue];
    return [self filterNameForType:type];
}

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

- (NSUInteger)filterIndexWithName:(NSString *)filterName {
    VideoFilterType type = [self filterTypeForName:filterName];
    if ((NSInteger)type < 0) {
        type = VideoFilterTypeNormal;
    }
    NSUInteger index = [self.filterList indexOfObject:@(type)];
    return index > 0 && index < self.filterList.count ? index : 0;
}

- (BOOL)isVIPOnlyAtIndex:(NSUInteger)index {
    return ([self.vipFilters indexOfObject:self.filterList[index]] != NSNotFound);
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
    return typeNum ? (VideoFilterType)typeNum.integerValue : -1;
}

- (GPUImageFilterGroup *)filterGroupWithName:(NSString *)filterName {
    for (int i = 0; i < self.filterList.count; i++) {
        NSString *name = [self filterNameAtIndex:i];
        if ([name isEqualToString:filterName]) {
            return [self filterGroupAtIndex:i + 1];
        }
    }
    
    // default (normal. no FX).
    // NOTE: 1 index is simply because that's how this confusing class was designed
    // for some reason. the index will be passed through the filterIndexWithWrapping
    // method which will decrement it to 0 (which is the actual index of normal).
    // this is the same reason for using (i + 1) in the line above
    return [self filterGroupAtIndex:1];
}

- (GPUImageFilterGroup *)filterGroupWithName:(NSString *)filterName
                              flipHorizontal:(BOOL)flipHorizontal {
    GPUImageFilterGroup *result = [self filterGroupWithName:filterName];
    if (flipHorizontal) {
        NSArray *filters = result.initialFilters;
        if (filters.count > 0) {
            GPUImageFilter *lastFilter = filters[filters.count - 1];
            [lastFilter setInputRotation:kGPUImageFlipHorizonal atIndex:0];
        }
    }
    return result;
}

- (GPUImageFilterGroup *)filterGroupAtIndex:(NSUInteger)index {
    GPUImageFilterGroup *group = [[GPUImageFilterGroup alloc] init];

    // Chain filters together

    NSArray *filters = [self filtersWithIndex:[self filterIndexWithWrapping:index]];
    int j = 0;
    for (GPUImageFilter *filter in filters) {
        [group addFilter:filter];
        if (j < (filters.count - 1)) {
            [filter addTarget:filters[j + 1]];
        }
        j++;
    }

    [group setInitialFilters:[NSArray arrayWithObjects:filters[0], nil]];
    [group setTerminalFilter:filters[filters.count - 1]];

    return group;
}

- (GPUImageFilterGroup *)splitFilterGroupAtIndex:(NSUInteger)index {
    return self.filters[index];
}

@end
