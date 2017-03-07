//
//  VideoFilterManager.h
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GPUImageFilterGroup;

typedef NS_ENUM(NSInteger, VideoFilterType) {
    VideoFilterTypeNormal = 0,
    VideoFilterTypeSepia,
    VideoFilterTypeBlackWhite,
    VideoFilterTypeVintage,
    VideoFilterTypeSelfie,
    VideoFilterTypeFightClub,
};



// Transient class where it's only purposes is to store the filter list and vip filter's list
@interface VideoFilterVariables : NSObject

+ (VideoFilterVariables *)sharedInstance;
// The names of the filters as strings.
@property (nonnull, nonatomic, strong) NSArray *filterList;
// The name of the VIP filters as strings.
@property (nonnull, nonatomic, strong) NSArray *vipFilters;

@end

@interface VideoFilterManager : NSObject

+ (VideoFilterManager *)sharedInstance;

// Filter name to send to server and map to localized string
- (NSString*)filterNameAtIndex:(NSUInteger)index;
- (NSString *)filterNameForType:(VideoFilterType)videoFilterType;

// Filter index based on filter name
- (NSUInteger)filterIndexWithName:(NSString *)filterName;

// Check if fiter at specific index is vip
- (BOOL)isVIPOnlyAtIndex:(NSUInteger)index;

// The names of the filters as strings.
@property (nonnull, nonatomic, strong) NSArray *filterList;
// The name of the VIP filters as strings.
@property (nonnull, nonatomic, strong) NSArray *vipFilters;

/*
 * Server
 */
- (GPUImageFilterGroup*)filterGroupWithName:(NSString *)filterName
                             flipHorizontal:(BOOL)flipHorizontal;

- (GPUImageFilterGroup*)filterGroupWithName:(NSString *)filterName;

/*
 * Client
 */

// Return two combined filters for swiping
- (GPUImageFilterGroup*)splitFilterGroupAtIndex:(NSUInteger)index includeAirbrush:(BOOL)includeAirbrush;

@end
