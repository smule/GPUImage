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
#import "ALYCETimedLayoutType.h"
typedef NS_ENUM(NSInteger, AirbrushFilterType) {
    AirbrushFilterTypeNone,
    AirbrushFilterTypeSimple, // Should be used during singing. Not computationally intense.
    AirbrushFilterTypeComplex // Should be used in the pre-singing and review screens. Computationally intense.
};

/**
 * GPUImageFilterGallery is the main interface for ALYCE video rendering in Sing iOS.
 * It manages loading of resources (images, config files etc) needed to render,
 * and renders video frames using C++ OpenGL-based code shared between iOS and Android.
 * GPUImageFilterGallery is implemented as a singleton because we only want to load
 * resources once during the life-time of the app.
 *
 * The filter gallery is a subclass of GPUImageOutput to allow it to be hooked up to
 * GPUImage filter chains. Users of this class should do that to hook up camera input,
 * and camera preview in an OpenGL view.
 *
 * Since the filter gallery is a singleton it's important that it's only hooked up to one
 * filter chain at any given time. However, the Sing! iOS app is designed in such a way that
 * there are never any conflicts about who wants to use the filter gallery in a filter chain.
 *
 * Changing the properties of the filter gallery changes the appearance of the video rendering.
 * The most important properties are videoStyle, colorFilter and airbrushFilterType which will
 * dramatically change the look of the preview.
 */
@interface GPUImageFilterGallery : GPUImageOutput <GPUImageInput>

+ (GPUImageFilterGallery *)sharedInstance;

/**
 * The number of inputs we are expecting. One by default.
 * Should be set to 2 on the review screen when joining an ALYCE duet seed.
 */
@property (nonatomic) NSUInteger inputCount;
/**
 * The input index of the current user running the app.
 */
@property (nonatomic) NSUInteger userInputIndex;
/**
 * The video style to apply when rendering video frames.
 */
@property (nonatomic) ALYCEVideoStyle videoStyle;
/**
 * The color filter to apply when rendering video frames.
 */
@property (nonatomic) ALYCEColorFilter colorFilter;
/**
 * The airbrush filter type (smoothing effect) to apply when  rendering video frames.
 */
@property (nonatomic) AirbrushFilterType airbrushFilterType;
/**
 * Should be set to provide the filte gallery with the current RMS.
 * This is used to make video effects response to the vocals input of the user in real-time.
 */
@property (nonatomic, copy) float (^currentRMSBlock)();

@property (nonatomic) NSTimeInterval currentTime;

@property (nonatomic) BOOL renderOnlyColorFilter;

/**
 * Resets all internal state to the live preview config.
 */
- (void)resetForLivePreview;

/**
 * Resets all internal state to the review screen config.
 */
- (void)resetForReviewScreen;

- (void)runSmoothingEffectAnimationWithDuration:(NSTimeInterval)animationDuration particleAlpha:(float)particleAlpha;

- (void)clearTimedLayouts;
    
- (void)convertAllLayoutsToDuet;

- (void)setupLoopingTimedLayouts;

- (void)addTimedLayout:(ALYCETimedLayoutType)type duration:(NSTimeInterval)duration;

@end
