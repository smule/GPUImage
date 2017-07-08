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

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, GPUImageFilterGroup *> *filters;
@property (nonatomic, strong) NSMutableDictionary *lookupGPUImagePictures;
// Airbrush filter for use in the split filter groups.
// We reuse it in all split filter groups.
@property (nonatomic, strong) GPUImageFilterGroup *splitComplexAirbrushFilter;
@property (nonatomic, strong) GPUImageFilterGroup *splitSimpleAirbrushFilter;
@property (nonatomic, assign) VideoFilterType currentAirbrushFilterType;

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
        shared.currentAirbrushFilterType = VideoFilterTypeUnknown;
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
    self.filters = [[NSMutableDictionary alloc] initWithCapacity:filterListCount];
    self.lookupGPUImagePictures = [[NSMutableDictionary alloc] init];
    
    self.splitComplexAirbrushFilter = [self createAirbrushFilter];
    self.splitSimpleAirbrushFilter = [self createSimpleAirbrushFilter];
    
    for (int i = 0; i < filterListCount; i++) {
        NSInteger leftIndex = [self filterIndexWithWrapping:i];
        NSInteger rightIndex = [self filterIndexWithWrapping:(i + 1)];
        VideoFilterType leftFilterType = (VideoFilterType)[self.filterList[leftIndex] integerValue];
        VideoFilterType rightFilterType = (VideoFilterType)[self.filterList[rightIndex] integerValue];
        
        GPUImageFilterGroup *filterGroup = [[GPUImageFilterGroup alloc] init];
        
        // Chain left filters together

        NSArray *leftFilters = [self filtersWithType:leftFilterType];
        int j = 0;
        for (GPUImageFilter *filter in leftFilters) {
            [filterGroup addFilter:filter];
            if (j < (leftFilters.count - 1)) {
                [filter addTarget:leftFilters[j + 1]];
            }
            j++;
        }

        // Chain right filters together

        NSArray *rightFilters = [self filtersWithType:rightFilterType];
        j = 0;
        for (GPUImageFilter *filter in rightFilters) {
            [filterGroup addFilter:filter];
            if (j < (rightFilters.count - 1)) {
                [filter addTarget:rightFilters[j + 1]];
            }
            j++;
        }
        
        // Make sure the two first filters in the filters[i] group
        // are the left and right filter so we can easily associate them
        // with the airbrush filter if needed later on.
        [filterGroup removeFilter:rightFilters[0]];
        [filterGroup insertFilter:rightFilters[0] atIndex:1];
        
        // Create split filter to filter part of image based on offset
        
        GPUImageSplitFilter *splitFilter = [[GPUImageSplitFilter alloc] init];
        [filterGroup addFilter:splitFilter];

        // Add split filter as a target to the final left and right filter
        [leftFilters[leftFilters.count - 1] addTarget:splitFilter];
        [rightFilters[rightFilters.count - 1] addTarget:splitFilter];
        
        [filterGroup setInitialFilters:@[leftFilters[0], rightFilters[0]]];
        [filterGroup setTerminalFilter:splitFilter];
        
        self.filters[@(leftFilterType)] = filterGroup;
    }
}

static const CGFloat kReferenceWidth = 360;
static const CGFloat kReferenceHeight = 480;

- (GPUImageFilterGroup *)createSimpleAirbrushFilter
{
    static const CGFloat scaleDownFactor = 2;
    GPUImageFilterGroup * edgePreservingBlur = [[GPUImageFilterGroup alloc] init];
    
    GPUImageFilter * ident = [[GPUImageFilter alloc] init];
    [edgePreservingBlur addFilter:ident];
    
    GPUImageBoxBlurFilter * smallBox = [[GPUImageBoxBlurFilter alloc] init];
    [smallBox forceProcessingAtSize:CGSizeMake(kReferenceWidth/scaleDownFactor, kReferenceHeight/scaleDownFactor)];
    [smallBox setBlurRadiusInPixels:2];
    [edgePreservingBlur addFilter:smallBox];
    [ident addTarget:smallBox];
    
    GPUImageSobelEdgeDetectionFilter * sobel = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    static const CGFloat kSobelSize = 1.9;
    sobel.texelWidth = 1.0 / kReferenceWidth * kSobelSize;
    sobel.texelHeight = 1.0 / kReferenceHeight * kSobelSize;
    sobel.edgeStrength = 4.7;
    [sobel forceProcessingAtSize:CGSizeMake(kReferenceWidth/scaleDownFactor, kReferenceHeight/scaleDownFactor)];
    [edgePreservingBlur addFilter:sobel];
    [smallBox addTarget:sobel];
    
    MaskBlendFilter * mask = [[MaskBlendFilter alloc] init];
    [edgePreservingBlur addFilter:mask];
    [ident addTarget:mask];
    [smallBox addTarget:mask];
    [sobel addTarget:mask];
    
    [edgePreservingBlur setInitialFilters:@[ident]];
    [edgePreservingBlur setTerminalFilter:mask];
    
    return edgePreservingBlur;
}

- (GPUImageFilterGroup *)createAirbrushFilter
{
    CGFloat scale = 3.0;
    int edgerad = 3.0;
    int detailblur = 2.0;
    int loblur = 1.0;
    CGFloat premid = 0.175;
    CGFloat prerng = 0.1;
    CGFloat postmid = 0.4;
    CGFloat postrng = 0.33;
    CGFloat coarsemid = 0.175;
    CGFloat coarserng = 0.175;
    
    GPUImageFilterGroup * edgePreservingBlur = [[GPUImageFilterGroup alloc] init];
    
    GPUImageFilter * ident = [[GPUImageFilter alloc] init];
    [edgePreservingBlur addFilter:ident];
    
    
    //IndexingFilter * ind = [[IndexingFilter alloc] init];
    ScaleFilter * ind = [[ScaleFilter alloc] init];
    [edgePreservingBlur addFilter:ind];
    [ind setScale:(CGPoint){scale,scale}];
    [ident addTarget:ind];
    
    GPUImageSobelEdgeDetectionFilter * sobelDetail = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    [edgePreservingBlur addFilter:sobelDetail];
    [ident addTarget:sobelDetail];
    
    GPUImageSobelEdgeDetectionFilter * sobel = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    [edgePreservingBlur addFilter:sobel];
    [ind addTarget:sobel];
    
    
    GPUImageBoxBlurFilter * smallBox = [[GPUImageBoxBlurFilter alloc] init];
    [smallBox setBlurRadiusInPixels:loblur];
    [edgePreservingBlur addFilter:smallBox];
    [ind addTarget:smallBox];
    
    GPUImageBoxBlurFilter * detailBox = [[GPUImageBoxBlurFilter alloc] init];
    [detailBox setBlurRadiusInPixels:detailblur];
    [edgePreservingBlur addFilter:smallBox];
    [ident addTarget:detailBox];
    
    StepFilter * step = [[StepFilter alloc] init];
    [step setEdgeOne:fmax(premid-prerng,0.0)];
    [step setEdgeTwo:premid+prerng];
    [edgePreservingBlur addFilter:step];
    [sobelDetail addTarget:step];
    
    GPUImageGaussianBlurFilter * edgeBox = [[GPUImageGaussianBlurFilter alloc] init];
    [edgeBox setBlurRadiusInPixels:edgerad];
    [edgePreservingBlur addFilter:edgeBox];
    [step addTarget:edgeBox];
    
    GPUImageBoxBlurFilter * coarseEdgeBox = [[GPUImageBoxBlurFilter alloc] init];
    [coarseEdgeBox setBlurRadiusInPixels:edgerad];
    [edgePreservingBlur addFilter:coarseEdgeBox];
    [sobel addTarget:coarseEdgeBox];
    
    StepFilter * step2 = [[StepFilter alloc] init];
    [step2 setEdgeOne:fmax(postmid-postrng,0.0)];
    [step2 setEdgeTwo:postmid+postrng];
    [edgePreservingBlur addFilter:step2];
    [edgeBox addTarget:step2];
    
    StepFilter * step3 = [[StepFilter alloc] init];
    [step3 setEdgeOne:fmax(coarsemid-coarserng,0.0)];
    [step3 setEdgeTwo:coarsemid+coarserng];
    [edgePreservingBlur addFilter:step3];
    [coarseEdgeBox addTarget:step3];
    
    //IndexingFilter * ind2 = [[IndexingFilter alloc] init];
    ScaleFilter * ind2 = [[ScaleFilter alloc] init];
    [edgePreservingBlur addFilter:ind2];
    [ind2 setScale:(CGPoint){1.0/scale,1.0/scale}];
    [smallBox addTarget:ind2];
    
    //IndexingFilter * ind3 = [[IndexingFilter alloc] init];
    ScaleFilter * ind3 = [[ScaleFilter alloc] init];
    [edgePreservingBlur addFilter:ind3];
    [ind3 setScale:(CGPoint){1.0/scale,1.0/scale}];
    [step3 addTarget:ind3];
    
    MaskBlendFilter * detail = [[MaskBlendFilter alloc] init];
    [edgePreservingBlur addFilter:detail];
    [ident addTarget:detail];
    [detailBox addTarget:detail];
    [step2 addTarget:detail];
    
    MaskBlendFilter * mask = [[MaskBlendFilter alloc] init];
    [edgePreservingBlur addFilter:mask];
    [detail addTarget:mask];
    [ind2 addTarget:mask];
    [ind3 addTarget:mask];
    
    [edgePreservingBlur setInitialFilters:@[ident]];
    [edgePreservingBlur setTerminalFilter:mask];
    return edgePreservingBlur;
}

- (GPUImagePicture *)GPUImagePictureForImage:(NSString *)imageName
{
    GPUImagePicture *picture = nil;

    picture = [self.lookupGPUImagePictures objectForKey:imageName];
    if (!picture) {
        UIImage *image = [UIImage imageNamed:imageName];
        picture = [[GPUImagePicture alloc] initWithImage:image];
        [self.lookupGPUImagePictures setObject:picture forKey:imageName];
    }

    return picture;
}

- (NSArray *)filtersWithType:(VideoFilterType)videoFilterType {
    if (videoFilterType == VideoFilterTypeNormal) {
        return @[[[GPUImageFilter alloc] init]];
    } else if (videoFilterType == VideoFilterTypeSepia) {
        GPUImageCustomLookupFilter *sepia =
        [[GPUImageCustomLookupFilter alloc] initWithGPUImagePicture:[self GPUImagePictureForImage:@"lookup_sepia.png"]];
        return @[sepia];
    } else if (videoFilterType == VideoFilterTypeSelfie) {
        GPUImageCustomLookupFilter *selfie =
        [[GPUImageCustomLookupFilter alloc] initWithGPUImagePicture:[self GPUImagePictureForImage:@"lookup_selfie.png"]];
        return @[selfie];
    } else if (videoFilterType == VideoFilterTypeVintage) {
        GPUImageCustomLookupFilter *vintage =
        [[GPUImageCustomLookupFilter alloc] initWithGPUImagePicture:[self GPUImagePictureForImage:@"lookup_vintage.png"]];
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
        [[GPUImageCustomLookupFilter alloc] initWithGPUImagePicture:[self GPUImagePictureForImage:@"lookup_fightclub.png"]];
        return @[fightclub];
    } else {
        return @[[[GPUImageFilter alloc] init]];
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
    return ([self.vipFilters indexOfObject:[self filterNameForType:videoFilterType]] != VideoFilterTypeUnknown);
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

- (GPUImageFilterGroup *)filterGroupWithFilterNames:(NSArray<NSString *> *)filterNames {
    
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

- (GPUImageFilterGroup *)filterGroupForType:(VideoFilterType)videoFilterType includeAirbrushFilter:(BOOL)includeAirbrushFilter {

    GPUImageFilterGroup *group = [[GPUImageFilterGroup alloc] init];

    // Chain filters together

    NSMutableArray *filters = [[self filtersWithType:videoFilterType] mutableCopy];
    if (includeAirbrushFilter) {
        [filters insertObject:[self createAirbrushFilter] atIndex:0];
    }
    int j = 0;
    for (GPUImageFilter *filter in filters) {
        [group addFilter:filter];
        if (j < (filters.count - 1)) {
            [filter addTarget:filters[j + 1]];
        }
        j++;
    }

    [group setInitialFilters:@[filters[0]]];
    [group setTerminalFilter:filters[filters.count - 1]];

    return group;
}

- (void)addAirbrushFilter:(GPUImageFilterGroup *)airbrushFilter toSplitFilterGroup:(GPUImageFilterGroup *)filterGroup {
    if (filterGroup.filterCount < 2) {
        return;
    }
    // Assumptions:
    // The first left filter is at index 0 in the filter group.
    // The first right filter is at index 1 in the filter group.
    GPUImageFilter *firstLeftFilter = (GPUImageFilter *)[filterGroup filterAtIndex:0];
    GPUImageFilter *firstRightFilter = (GPUImageFilter *)[filterGroup filterAtIndex:1];
    
    // The video appears flipped unless we add, remove and then add the targets again.
    // TODO (Anton): Investigate why that is the case. However, this is not very CPU intense
    // code and will be called very rarely so it's not high priority to fix.
    [airbrushFilter addTarget:firstLeftFilter];
    [airbrushFilter addTarget:firstRightFilter];
    
    [filterGroup insertFilter:airbrushFilter atIndex:0];
    [filterGroup setInitialFilters:@[airbrushFilter]];
}

- (void)removeAirbrushFilterFromSplitFilterGroup:(GPUImageFilterGroup *)filterGroup {
    if (filterGroup.filterCount < 3) {
        return;
    }
    
    // Assumptions:
    // The airbrush filter is at index 0 in the filter group.
    // The first left filter is at index 1 in the filter group.
    // The first right filter is at index 2 in the filter group.
    GPUImageFilterGroup *airbrushFilter = (GPUImageFilterGroup *)[filterGroup filterAtIndex:0];
    [airbrushFilter removeAllTargets];
    [filterGroup removeFilter:airbrushFilter];
    
    // The first left filter will now be at index 0 in the filter group.
    // The first right filter will now be at index 1 in the filter group.
    GPUImageFilter *firstLeftFilter = (GPUImageFilter *)[filterGroup filterAtIndex:0];
    GPUImageFilter *firstRightFilter = (GPUImageFilter *)[filterGroup filterAtIndex:1];
    [filterGroup setInitialFilters:@[firstLeftFilter, firstRightFilter]];
}

- (GPUImageFilterGroup *)splitFilterGroupForType:(VideoFilterType)videoFilterType airbrushFilterType:(AirbrushFilterType)airbrushFilterType {
    
    GPUImageFilterGroup *filterGroup = [self.filters objectForKey:@(videoFilterType)];
    GPUImageFilterGroup *airbrushGroup = [self.filters objectForKey:@(self.currentAirbrushFilterType)];
    
    // Make sure the rotation of the initial filters are reset
    for ( int i = 0; i < filterGroup.initialFilters.count; i++ )
    {
        [filterGroup.initialFilters[i] setInputRotation:kGPUImageNoRotation atIndex:0];
    }
    
    BOOL includeAirbrush = airbrushFilterType != AirbrushFilterTypeNone;
    
    // Update the filter group to include/exclude airbrush filter if needed
    if (includeAirbrush) {
        GPUImageFilterGroup *airbrushFilter = airbrushFilterType == AirbrushFilterTypeSimple ? self.splitSimpleAirbrushFilter : self.splitComplexAirbrushFilter;
        if (self.currentAirbrushFilterType != VideoFilterTypeUnknown) {
            GPUImageFilterGroup *currentAirbrushFilterGroup = airbrushGroup;
            GPUImageFilterGroup *currentAirbrushFilter =(GPUImageFilterGroup *) [currentAirbrushFilterGroup filterAtIndex:0];
            if (self.currentAirbrushFilterType != videoFilterType || airbrushFilter != currentAirbrushFilter)
            {
                [self removeAirbrushFilterFromSplitFilterGroup:currentAirbrushFilterGroup];
                [self addAirbrushFilter:airbrushFilter toSplitFilterGroup:filterGroup];
                self.currentAirbrushFilterType = videoFilterType;
            }
            else
            {
                // The airbrush is already part of the current filter gorup
            }
        }
        else
        {
            [self addAirbrushFilter:airbrushFilter toSplitFilterGroup:filterGroup];
            self.currentAirbrushFilterType = videoFilterType;
        }
    } else {
        if (self.currentAirbrushFilterType != VideoFilterTypeUnknown) {
            [self removeAirbrushFilterFromSplitFilterGroup:airbrushGroup];
            self.currentAirbrushFilterType = VideoFilterTypeUnknown;
        }
    }
    
    return filterGroup;
}

@end
