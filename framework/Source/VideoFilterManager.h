//
//  VideoFilterManager.h
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GPUImageFilterGroup;

typedef enum {
    VideoFilterTypeNormal = 0,
    VideoFilterTypeSepia,
    VideoFilterTypeBlackWhite,
    VideoFilterTypeVintage,
    VideoFilterTypeSelfie,
    VideoFilterTypeFightClub,
} VideoFilterType;

@interface VideoFilterManager : NSObject

+ (VideoFilterManager *)sharedInstance;

// Filter name to send to server and map to localized string
- (NSString*)filterNameAtIndex:(NSUInteger)index;
- (NSString *)filterNameForType:(VideoFilterType)videoFilterType;

// Filter index based on filter name
- (NSUInteger)filterIndexWithName:(NSString *)filterName;

// Check if fiter at specific index is vip
- (BOOL)isVIPOnlyAtIndex:(NSUInteger)index;

@property (nonnull, nonatomic, strong) NSArray *filterList;
@property (nonnull, nonatomic, strong) NSArray *vipFilters;;

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
- (GPUImageFilterGroup*)splitFilterGroupAtIndex:(NSUInteger)index;

@end
