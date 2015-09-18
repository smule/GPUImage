//
//  VideoFilterManager.m
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import "VideoFilterManager.h"
#import "GPUImage.h"

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

+ (NSUInteger)filterIndexWithName:(NSString *)filterName
{
    NSUInteger index = [[VideoFilterManager filterNames] indexOfObject:filterName];
    if(index > 0 && index < [VideoFilterManager filterNames].count)
    {
        return index;
    }
    else
    {
        return 0;
    }
}

+ (BOOL)isVIPOnlyAtIndex:(NSUInteger)index
{
    if(index == 0) {
        return NO;
    }
    else {
        return YES;
    }
}

+ (NSArray*)filterNames
{
    return @[@"normal",
             @"bw",
             @"sepia",
             @"vintge",
             @"selfie",
             @"fight",
             ];
}

+ (GPUImageFilterGroup*)filterGroupWithName:(NSString *)filterName
{
    for (int i = 0; i < [VideoFilterManager filterNames].count; i++) {
        NSString *name = [VideoFilterManager filterNames][i];
        if([name isEqualToString:filterName]) {
            return [VideoFilterManager filterGroupAtIndex:i+1];
        }
    }
    // default
    return [VideoFilterManager filterGroupAtIndex:1];
}

+ (GPUImageFilterGroup*)filterGroupWithName:(NSString *)filterName
                             flipHorizontal:(BOOL)flipHorizontal
{
    GPUImageFilterGroup* result = [VideoFilterManager filterGroupWithName:filterName];
    if(flipHorizontal) {
        NSArray* filters = result.initialFilters;
        if(filters.count > 0) {
            GPUImageFilter* lastFilter = filters[filters.count - 1];
            [lastFilter setInputRotation:kGPUImageFlipHorizonal atIndex:0];
        }
    }
    return result;
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
            
        case 7: /* fall through -- wrap around for circular scrolling */
        case 1:
        {
            return [NSArray arrayWithObjects:[[GPUImageFilter alloc] init], nil];
        }
        case 2:
        {
            GPUImageGrayscaleFilter *bw = [[GPUImageGrayscaleFilter alloc] init];
            GPUImageLevelsFilter *levels = [[GPUImageLevelsFilter alloc] init];
            [levels setRedMin:.1 gamma:1.0 max:1.0 minOut:0.0 maxOut:1.0];
            [levels setGreenMin:.1 gamma:1.0 max:1.0 minOut:0.0 maxOut:1.0];
            [levels setBlueMin:.1 gamma:1.0 max:1.0 minOut:0.0 maxOut:1.0];
            return [NSArray arrayWithObjects:bw, levels, nil];
        }
        case 3:
        {
            GPUImageCustomLookupFilter *sepia = [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_sepia.png"];
            return [NSArray arrayWithObjects:sepia, nil];
        }
        case 4:
        {
            GPUImageCustomLookupFilter *vintage = [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_vintage.png"];
            return [NSArray arrayWithObjects:vintage, nil];
        }
        case 5:
        {
            GPUImageCustomLookupFilter *selfie = [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_selfie.png"];
            return [NSArray arrayWithObjects:selfie, nil];
        }
            
        case 0: /* fall through -- wrap around for circular scrolling */
        case 6:
        {
            GPUImageCustomLookupFilter *fightclub = [[GPUImageCustomLookupFilter alloc] initWithImageNamed:@"lookup_fightclub.png"];
            return [NSArray arrayWithObjects:fightclub, nil];
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
