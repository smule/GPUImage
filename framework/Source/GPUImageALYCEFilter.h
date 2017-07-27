#import "GPUImageOutput.h"
#import "GPUImageFilterGroup.h"
#import "ALYCEVideoStyle.h"
#import "ALYCEColorFilter.h"

@class ALYCEClientPreviewRenderer;

@interface GPUImageALYCEFilter : GPUImageOutput <GPUImageInput>

- (id)initWithRenderer:(ALYCEClientPreviewRenderer *)renderer;
@property (nonatomic, copy) float (^currentRMSBlock)();
@property (nonatomic) ALYCEVideoStyle videoStyle;
@property (nonatomic) ALYCEColorFilter colorFilter;
@property (nonatomic) BOOL hasReceivedFrame;
- (void)resetForLivePreview;

@end
