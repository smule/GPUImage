//
//  VideoFilterManager.h
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GPUImageFilterGroup;

@interface VideoFilterManager : NSObject

// Total number of filters a user can select
+ (NSUInteger)numFilters;

// Filter name to send to server and map to localized string
+ (NSString*)filterNameAtIndex:(NSUInteger)index;

// Filter index based on filter name
+ (NSUInteger)filterIndexWithName:(NSString *)filterName;

// Check if fiter at specific index is vip
+ (BOOL)isVIPOnlyAtIndex:(NSUInteger)index;

/*
 * Server
 */

+ (GPUImageFilterGroup*)filterGroupWithName:(NSString *)filterName;

/*
 * Client
 */

// Return two combined filters for swiping
- (GPUImageFilterGroup*)splitFilterGroupAtIndex:(NSUInteger)index;

@end
