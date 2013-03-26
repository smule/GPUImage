#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImageTwoInputFilter.h"
#import "GPUImageOpenGLESContext.h"
#import "GPUImageOutput.h"

@protocol LinkedOverlay <NSObject>
- (void)processFrameAtTargetTime:(CMTime)targetTime;
@end

@protocol TransitionFilterDelegate <NSObject>
- (void)startTransition:(float)startTime forDuration:(float)duration reverse:(BOOL)reverse;
- (void)updateTransition:(float)time;
@end

/** Source object for filtering movies
 */
@interface GPUImageMovie : GPUImageOutput

@property (readwrite, retain) AVAsset *asset;
@property(readwrite, retain) NSURL *url;

/** This enables the benchmarking mode, which logs out instantaneous and average frame times to the console
 */
@property(readwrite, nonatomic) BOOL runBenchmark;

/** This determines whether to play back a movie as fast as the frames can be processed, or if the original speed of the movie should be respected. Defaults to NO.
 */
@property(readwrite, nonatomic) BOOL playAtActualSpeed;

// ian: adding a linked overlay property here
//      Basically, we will inform the linked overlay of our current time every time we process a frame.
//      The overlay is responsible for staying in sync with us.
@property(readwrite, assign) id<LinkedOverlayDelegate> linkedOverlay;

// ian: adding a transition filter property here
@property(readwrite, retain) GPUImageTwoInputFilter<TransitionFilterDelegate> *transitionFilter;

@property float hardFrameDifferenceLimit;

/// @name Initialization and teardown
- (id)initWithAsset:(AVAsset *)asset;
- (id)initWithURL:(NSURL *)url;
- (void)textureCacheSetup;

/// @name Movie processing
- (void)enableSynchronizedEncodingUsingMovieWriter:(GPUImageMovieWriter *)movieWriter;
- (void)readNextVideoFrameFromOutput:(AVAssetReaderTrackOutput *)readerVideoTrackOutput transitionIndex:(int)transitionIndex;
- (void)readNextAudioSampleFromOutput:(AVAssetReaderTrackOutput *)readerAudioTrackOutput;
- (void)startProcessing;
- (void)endProcessing;
- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer transitionIndex:(int)transitionIndex;

@end
