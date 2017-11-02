#import "GPUImageOutput.h"
#import "GPUImageFilterGroup.h"
#import "ALYCEVideoStyle.h"
#import "ALYCEColorFilter.h"
#import "ALYCESmoothingEffectType.h"
#import "ALYCERendererState.h"

@class ALYCEClientPreviewRenderer;

@interface GPUImageALYCEFilter : GPUImageOutput <GPUImageInput>

@property (nonatomic) NSUInteger userInputIndex;
@property (nonatomic) ALYCEVideoStyle videoStyle;
@property (nonatomic) ALYCEColorFilter colorFilter;
@property (nonatomic) ALYCESmoothingEffectType smoothingEffectType;
@property (nonatomic) ALYCEParticleIntensity particleIntensity;
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic) BOOL renderOnlyColorFilter;

/**
 * Should be set to provide the filter with the current vocals RMS.
 * This is used to make video effects response to the vocals input of the user in real-time.
 */
@property (nonatomic, copy) float (^currentRMSBlock)(void);

- (void)runSmoothingEffectAnimationWithDuration:(NSTimeInterval)animationDuration particleAlpha:(float)particleAlpha;

- (void)clearTimedLayouts;

- (void)convertAllLayoutsToDuet;

- (void)setupLoopingTimedLayouts:(BOOL)duetLayouts;

- (void)addTimedLayout:(ALYCETimedLayoutType)type duration:(NSTimeInterval)duration;

@end
