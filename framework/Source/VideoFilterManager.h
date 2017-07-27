//
//  VideoFilterManager.h
//  Sing
//
//  Created by Michael Harville on 1/30/15.
//  Copyright (c) 2015 Smule. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUImageFilterGallery.h"
@class GPUImageFilterGroup;

extern NSString * const kAirbrushFilterIdentifier;

typedef NS_ENUM(NSInteger, VideoFilterType) {
    VideoFilterTypeUnknown,
    
    VideoFilterTypeNormal,
    VideoFilterTypeSepia,
    VideoFilterTypeBlackWhite,
    VideoFilterTypeVintage,
    VideoFilterTypeSelfie,
    VideoFilterTypeFightClub
};

// todo: delete
// Transient class where it's only purposes is to store the filter list and vip filter's list
@interface VideoFilterVariables : NSObject

+ (VideoFilterVariables *)sharedInstance;
// The names of the filters as strings.
@property (nonatomic, strong) NSArray *filterList;
// The name of the VIP filters as strings.
@property (nonatomic, strong) NSArray *vipFilters;

@end

@interface VideoFilterManager : NSObject

+ (VideoFilterManager *)sharedInstance;

// Filter name to send to server and map to localized string
- (NSString *)filterNameForType:(VideoFilterType)videoFilterType;

// Check if fiter at specific index is vip
- (BOOL)isVIPOnlyFilter:(VideoFilterType)videoFilterType;

// The names of the filters as strings.
@property (nonatomic, strong) NSArray *filterList;
// The name of the VIP filters as strings.
@property (nonatomic, strong) NSArray *vipFilters;

- (GPUImageOutput<GPUImageInput> *)filterWithFilterNames:(NSArray<NSString *> *)filterNames;

// Old deprecated API using VideoFilterType.
// TODO: Remove once we have switched over to the
// filterWithVideoStyle:colorFilter:airbrushFilterType: method.
- (GPUImageOutput<GPUImageInput> *)filterWithType:(VideoFilterType)videoFilterType
                               airbrushFilterType:(AirbrushFilterType)airbrushFilterType;


- (GPUImageOutput<GPUImageInput> *)filterWithVideoStyle:(ALYCEVideoStyle)videoStyle
                                            colorFilter:(ALYCEColorFilter)colorFilter
                                     airbrushFilterType:(AirbrushFilterType)airbrushFilterType;

@end
