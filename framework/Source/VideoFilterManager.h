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

// Filter name for display purposes
+ (NSString*)filterNameAtIndex:(NSUInteger)index;

// Filter name with spaces removed
+ (NSString*)filterIDAtIndex:(NSUInteger)index;

/*
 * Server
 */

+ (GPUImageFilterGroup*)filterGroupWithID:(NSString*)filterID;

/*
 * Client
 */

// Return two combined filters for swiping
- (GPUImageFilterGroup*)splitFilterGroupAtIndex:(NSUInteger)index;

@end
