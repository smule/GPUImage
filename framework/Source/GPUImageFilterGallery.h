//
//  GPUImageFilterGallery.h
//  Pods
//
//  Created by Anton Holmberg on 7/24/17.
//
//

#import "GPUImageOutput.h"
#import "GPUImageFilterGroup.h"
#import "ALYCEClientPreviewRenderer.h"
#import "ALYCEVideoStyle.h"
#import "ALYCEColorFilter.h"

typedef NS_ENUM(NSInteger, AirbrushFilterType) {
    AirbrushFilterTypeNone,
    AirbrushFilterTypeSimple,
    AirbrushFilterTypeComplex
};

@interface GPUImageFilterGallery : GPUImageOutput <GPUImageInput>

@property (nonatomic) NSUInteger inputCount;
@property (nonatomic) NSUInteger userInputIndex;
@property (nonatomic) ALYCEVideoStyle videoStyle;
@property (nonatomic) ALYCEColorFilter colorFilter;
@property (nonatomic) AirbrushFilterType airbrushFilterType;
@property (nonatomic, readonly) ALYCEClientPreviewRenderer *renderer;
@property (nonatomic, copy) float (^currentRMSBlock)();

+ (GPUImageFilterGallery *)sharedInstance;

- (void)resetForLivePreview;

@end
