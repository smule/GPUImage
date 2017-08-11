#import "GPUImageOutput.h"
#import "GPUImageFilterGroup.h"
#import "ALYCEVideoStyle.h"
#import "ALYCEColorFilter.h"
#import "ALYCERendererState.h"

@class ALYCEClientPreviewRenderer;

@interface GPUImageALYCEFilter : GPUImageOutput <GPUImageInput>

- (id)initWithRenderer:(ALYCEClientPreviewRenderer *)renderer rendererState:(ALYCERendererState *)rendererState;
- (void)resetForLivePreview;

@end
