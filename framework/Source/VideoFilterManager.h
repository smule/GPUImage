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

+ (NSString*)filterNameAtIndex:(NSUInteger)index;

/*
 * Server
 */

+ (GPUImageFilterGroup*)filterGroupAtIndex:(NSUInteger)index;

/*
 * Client
 */

// Return two combined filters for swiping
- (GPUImageFilterGroup*)splitFilterGroupAtIndex:(NSUInteger)index;

@end
