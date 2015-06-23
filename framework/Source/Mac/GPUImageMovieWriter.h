#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImageContext.h"

extern NSString *const kGPUImageColorSwizzlingFragmentShaderString;

@protocol GPUImageMovieWriterDelegate <NSObject>

@optional
- (void)movieRecordingCompleted;
- (void)movieRecordingFailedWithError:(NSError*)error;

@end

@interface GPUImageMovieWriter : NSObject <GPUImageInput>
{
    CMVideoDimensions videoDimensions;
	CMVideoCodecType videoType;

    NSURL *movieURL;
    NSString *fileType;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterAudioInput;
	AVAssetWriterInput *assetWriterVideoInput;
    AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferInput;
	dispatch_queue_t movieWritingQueue;
    
    CGSize videoSize;
    GPUImageRotationMode inputRotation;
}

@property(readwrite, nonatomic) BOOL hasAudioTrack;
@property(readwrite, nonatomic) BOOL shouldPassthroughAudio;
@property(nonatomic, copy) void(^completionBlock)(void);
@property(nonatomic, copy) void(^failureBlock)(NSError*);
@property(nonatomic, assign) id<GPUImageMovieWriterDelegate> delegate;
@property(readwrite, nonatomic) BOOL encodingLiveVideo;
@property(nonatomic, copy) void(^videoInputReadyCallback)(void);
@property(nonatomic, copy) void(^audioInputReadyCallback)(void);
@property(nonatomic) BOOL enabled;

// Smule Hack: Adds a "pre-encode" callback when the frame data is processed and
// ready to sned to the encoder.
@property(nonatomic, copy) void(^preEncodeFrameCallback)( double_t timeval, int w, int h, uint8_t *pixelData);

// Initialization and teardown
- (id)initWithMovieURL:(NSURL *)newMovieURL
                  size:(CGSize)newSize;

- (id)initWithMovieURL:(NSURL *)newMovieURL
                  size:(CGSize)newSize
              metadata:(NSArray *)metadata;

- (id)initWithMovieURL:(NSURL *)newMovieURL
                  size:(CGSize)newSize
              fileType:(NSString *)newFileType
        outputSettings:(NSMutableDictionary *)outputSettings
              metadata:(NSArray *)metadata;

- (void)setHasAudioTrack:(BOOL)hasAudioTrack audioSettings:(NSDictionary *)audioOutputSettings;

// Movie recording
- (void)startRecording;
- (void)startRecordingInOrientation:(CGAffineTransform)orientationTransform;
- (void)finishRecording;
- (void)finishRecordingWithCompletionHandler:(void (^)(void))handler;
- (void)cancelRecording;

- (void)finishRecordingSafelyWithCompletionHandler:(void (^)(void))handler;

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;
- (void)enableSynchronizationCallbacks;

@end
