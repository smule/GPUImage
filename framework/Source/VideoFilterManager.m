//
//  VideoFilterManager.m
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import "VideoFilterManager.h"
#import "GPUImage.h"
#import "GPUImageSplitFilter.h"
#import "StrumPinkEdgeFilter.h"

typedef enum FILTER_TYPE : NSUInteger{
    FILTER_TYPE_NONE,
    FILTER_TYPE_BLACKNWHITE,
    FILTER_TYPE_SEPIA,
    FILTER_TYPE_VINTAGE,
    FILTER_TYPE_FACE,
    FILTER_TYPE_TURKEY,
    FILTER_TYPE_HALFTONE,
    FILTER_TYPE_PINKEDGE
} FILTER_TYPE;

@interface VideoFilterManager ()

@property (nonatomic, strong) NSMutableArray *filters;

@end

@implementation VideoFilterManager

#pragma mark - Class methods

+ (NSUInteger)numFilters
{
    return [VideoFilterManager filterNames].count;
}

+ (NSString*)filterNameAtIndex:(NSUInteger)index
{
    return [VideoFilterManager filterNames][index];
}

+ (NSString*)filterIDAtIndex:(NSUInteger)index
{
    return [[[VideoFilterManager filterNames][index] stringByReplacingOccurrencesOfString:@" " withString:@"_"] lowercaseString];
}

+ (NSArray*)filterNames
{
    return @[@"Normal",
             @"Black and White",
             @"Sepia",
             @"Vintage",
             @"Face",
             @"Turkey",
             @"Halftone",
             @"Pink Edge"];
}

+ (GPUImageFilterGroup*)filterGroupWithID:(NSString *)filterID
{
    NSString *filterName = [filterID stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    for (int i = 0; i < [VideoFilterManager filterNames].count; i++) {
        NSString *name = [VideoFilterManager filterNames][i];
        if([name caseInsensitiveCompare:filterName]) {
            return [VideoFilterManager filterGroupAtIndex:i+1];
        }
    }
    
    // ID does not match any filter name
    return [VideoFilterManager filterGroupAtIndex:1];
}

+ (GPUImageFilterGroup*)filterGroupAtIndex:(NSUInteger)index
{
    GPUImageFilterGroup *group = [[GPUImageFilterGroup alloc] init];
    
    // Chain filters together
    
    NSArray *filters = [VideoFilterManager filtersWithIndex:index];
    int j = 0;
    for (GPUImageFilter *filter in filters) {
        [group addFilter:filter];
        if(j < (filters.count - 1)) {
            [filter addTarget:filters[j+1]];
        }
        j++;
    }
    
    [group setInitialFilters:[NSArray arrayWithObjects:filters[0], nil]];
    [group setTerminalFilter:filters[filters.count-1]];
    
    return group;
}

+ (NSArray*)filtersWithIndex:(NSUInteger)index
{
    switch (index) {
        case 0:
        {
            // Put the final filter here for circular scrolling
            return [NSArray arrayWithObjects:[[StrumPinkEdgeFilter alloc] init], nil];
        }
        case 1:
        {
            return [NSArray arrayWithObjects:[[GPUImageFilter alloc] init], nil];
        }
        case 2:
        {
            return [NSArray arrayWithObjects:[[GPUImageGrayscaleFilter alloc] init], nil];
        }
        case 3:
        {
            GPUImageGaussianBlurFilter *blur = [[GPUImageGaussianBlurFilter alloc] init];
            [blur setBlurRadiusInPixels:5.0];
            GPUImageSepiaFilter *sepia = [[GPUImageSepiaFilter alloc] init];
            return [NSArray arrayWithObjects:sepia, blur, nil];
        }
        case 4:
        {
            GPUImageSaturationFilter *saturation = [[GPUImageSaturationFilter alloc] init];
            [saturation setSaturation:.8];
            GPUImageContrastFilter *contrast = [[GPUImageContrastFilter alloc] init];
            [contrast setContrast:.8];
            return [NSArray arrayWithObjects:saturation, contrast, nil];
        }
        case 5:
        {
            GPUImageExposureFilter *exposure = [[GPUImageExposureFilter alloc] init];
            [exposure setExposure:1.0];
            GPUImageContrastFilter *contrast = [[GPUImageContrastFilter alloc] init];
            [contrast setContrast:1.1];
            GPUImageVignetteFilter *vignette = [[GPUImageVignetteFilter alloc] init];
            return [NSArray arrayWithObjects:exposure, contrast, vignette, nil];
        }
        case 6:
        {
            GPUImageGaussianBlurFilter *blur = [[GPUImageGaussianBlurFilter alloc] init];
            [blur setBlurRadiusInPixels:8.0];
            return [NSArray arrayWithObjects:blur, nil];
        }
        case 7:
        {
            return [NSArray arrayWithObjects:[[GPUImageHalftoneFilter alloc] init], nil];
        }
        case 8:
        {
            return [NSArray arrayWithObjects:[[StrumPinkEdgeFilter alloc] init], nil];
        }
        case 9:
        {
            // Put the first filter here for circular scrolling
            return [NSArray arrayWithObjects:[[GPUImageFilter alloc] init], nil];
        }
        default:
        {
            return [NSArray arrayWithObjects:[[GPUImageFilter alloc] init], nil];
        }
    }
}

#pragma mark - Instance methods

- (id)init
{
    self = [super init];
    if(self)
    {
        
        self.filters = [[NSMutableArray alloc] initWithCapacity:[VideoFilterManager numFilters]+2];
        
        for (int i = 0; i < [VideoFilterManager numFilters]+2; i++) {
            self.filters[i] = [[GPUImageFilterGroup alloc] init];
            
            // Chain left filters together
            
            NSArray *leftFilters = [VideoFilterManager filtersWithIndex:i];
            int j = 0;
            for (GPUImageFilter *filter in leftFilters) {
                [self.filters[i] addFilter:filter];
                if(j < (leftFilters.count - 1)) {
                    [filter addTarget:leftFilters[j+1]];
                }
                j++;
            }
            
            // Chain right filters together
            
            NSArray *rightFilters = [VideoFilterManager filtersWithIndex:i+1];
            j = 0;
            for (GPUImageFilter *filter in rightFilters) {
                [self.filters[i] addFilter:filter];
                if(j < (rightFilters.count - 1)) {
                    [filter addTarget:rightFilters[j+1]];
                }
                j++;
            }
            
            // Create split filter to filter part of image based on offset
            
            GPUImageSplitFilter *splitFilter = [[GPUImageSplitFilter alloc] init];
            [self.filters[i] addFilter:splitFilter];
            
            // Add split filter as a target to the final left and right filter
            
            [leftFilters[leftFilters.count-1] addTarget:splitFilter];
            [rightFilters[rightFilters.count-1] addTarget:splitFilter];
            
            [self.filters[i] setInitialFilters:[NSArray arrayWithObjects:leftFilters[0], rightFilters[0],splitFilter, nil]];
            [self.filters[i] setTerminalFilter:splitFilter];
        }
    }
    
    return self;
}

- (GPUImageFilterGroup*)splitFilterGroupAtIndex:(NSUInteger)index
{
    return self.filters[index];
}

@end
