//
//  GPUImageFilterGallery.m
//  Pods
//
//  Created by Anton Holmberg on 7/24/17.
//
//

#import "GPUImageFilterGallery.h"
#import "GPUImageALYCEFilter.h"
#import "GPUImage.h"
#import "IndexingFilter.h"
#import "StepFilter.h"
#import "MaskBlendFilter.h"
#import "ScaleFilter.h"

@interface GPUImageFilterGallery () {
    bool isEndProcessing;
}

@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *simpleAirbrushFilterGroup;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *complexAirbrushFilterGroup;
@property (nonatomic, strong) GPUImageALYCEFilter *alyceFilter;
@property (nonatomic, strong) ALYCEClientPreviewRenderer *renderer;

@end

@implementation GPUImageFilterGallery

+ (GPUImageFilterGallery *)sharedInstance {
    static GPUImageFilterGallery *shared = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        shared = [[GPUImageFilterGallery alloc] init];
    });
    
    return shared;
}

- (void)setUserInputIndex:(NSUInteger)userInputIndex
{
    runSynchronouslyOnVideoProcessingQueue(^{
        _userInputIndex = userInputIndex;
        [self.renderer setUserInputIndex:(int32_t)userInputIndex];
        [self updateAirbrushTargets];
    });
}

- (void)setInputCount:(NSUInteger)inputCount
{
    runSynchronouslyOnVideoProcessingQueue(^{
        _inputCount = inputCount;
    });
}

- (void)setAirbrushFilterType:(AirbrushFilterType)airbrushFilterType
{
    runSynchronouslyOnVideoProcessingQueue(^{
        _airbrushFilterType = airbrushFilterType;
        [self updateAirbrushTargets];
    });
}

- (void)updateAirbrushTargets
{
    [self.simpleAirbrushFilterGroup removeAllTargets];
    [self.complexAirbrushFilterGroup removeAllTargets];
    if (self.airbrushFilterType == AirbrushFilterTypeSimple)
    {
        [self.simpleAirbrushFilterGroup addTarget:self.alyceFilter atTextureLocation:self.userInputIndex];
    }
    else if (self.airbrushFilterType == AirbrushFilterTypeComplex)
    {
        [self.complexAirbrushFilterGroup addTarget:self.alyceFilter atTextureLocation:self.userInputIndex];
    }
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            self.inputCount = 1;
            self.renderer = [ALYCEClientPreviewRenderer instantiate];
            isEndProcessing = NO;
            NSBundle *alyceBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"ALYCE_theme_segments" ofType:@"bundle"]];
            
            NSString *configFilePath = [alyceBundle pathForResource:@"theme_segments/client_preview_config.json" ofType:nil];
            if (!configFilePath)
            {
                NSLog(@"Couldn't find ALYCE client config file at: %@", configFilePath);
            }
            else
            {
                NSString *errorDescription = [self.renderer setup:[NSObject new] configFilePath:configFilePath];
                if (errorDescription.length > 0)
                {
                    NSLog(@"Failed to setup ALYCE preview renderer: %@", errorDescription);
                }
            }
            
            self.simpleAirbrushFilterGroup = [self createSimpleAirbrushFilter];
            self.complexAirbrushFilterGroup = [self createComplexAirbrushFilter];
            
            self.alyceFilter = [[GPUImageALYCEFilter alloc] initWithRenderer:self.renderer];
            
            __weak GPUImageFilterGallery *weakSelf = self;
            self.alyceFilter.currentRMSBlock = ^{
                return weakSelf.currentRMSBlock ? weakSelf.currentRMSBlock() : 0.0f;
            };
        });
    }
    
    return self;
}

static const CGFloat kReferenceWidth = 360;
static const CGFloat kReferenceHeight = 480;

- (void)setColorFilter:(ALYCEColorFilter)colorFilter
{
    _colorFilter = colorFilter;
    self.alyceFilter.colorFilter = colorFilter;
}

- (void)setVideoStyle:(ALYCEVideoStyle)videoStyle
{
    _videoStyle = videoStyle;
    self.alyceFilter.videoStyle = videoStyle;
}

- (GPUImageOutput<GPUImageInput> *)createSimpleAirbrushFilter
{
    static const CGFloat scaleDownFactor = 2;
    GPUImageFilterGroup * edgePreservingBlur = [[GPUImageFilterGroup alloc] init];
    
    GPUImageFilter * ident = [[GPUImageFilter alloc] init];
    [edgePreservingBlur addFilter:ident];
    
    GPUImageBoxBlurFilter * smallBox = [[GPUImageBoxBlurFilter alloc] init];
    [smallBox forceProcessingAtSize:CGSizeMake(kReferenceWidth/scaleDownFactor, kReferenceHeight/scaleDownFactor)];
    [smallBox setBlurRadiusInPixels:2];
    [edgePreservingBlur addFilter:smallBox];
    [ident addTarget:smallBox];
    
    GPUImageSobelEdgeDetectionFilter * sobel = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    static const CGFloat kSobelSize = 1.9;
    sobel.texelWidth = 1.0 / kReferenceWidth * kSobelSize;
    sobel.texelHeight = 1.0 / kReferenceHeight * kSobelSize;
    sobel.edgeStrength = 4.7;
    [sobel forceProcessingAtSize:CGSizeMake(kReferenceWidth/scaleDownFactor, kReferenceHeight/scaleDownFactor)];
    [edgePreservingBlur addFilter:sobel];
    [smallBox addTarget:sobel];
    
    MaskBlendFilter * mask = [[MaskBlendFilter alloc] init];
    [edgePreservingBlur addFilter:mask];
    [ident addTarget:mask];
    [smallBox addTarget:mask];
    [sobel addTarget:mask];
    
    [edgePreservingBlur setInitialFilters:@[ident]];
    [edgePreservingBlur setTerminalFilter:mask];
    
    return edgePreservingBlur;
}

- (GPUImageOutput<GPUImageInput> *)createComplexAirbrushFilter
{
    CGFloat scale = 3.0;
    int edgerad = 3.0;
    int detailblur = 2.0;
    int loblur = 1.0;
    CGFloat premid = 0.175;
    CGFloat prerng = 0.1;
    CGFloat postmid = 0.4;
    CGFloat postrng = 0.33;
    CGFloat coarsemid = 0.175;
    CGFloat coarserng = 0.175;
    
    GPUImageFilterGroup * edgePreservingBlur = [[GPUImageFilterGroup alloc] init];
    
    GPUImageFilter * ident = [[GPUImageFilter alloc] init];
    [edgePreservingBlur addFilter:ident];
    
    //IndexingFilter * ind = [[IndexingFilter alloc] init];
    ScaleFilter * ind = [[ScaleFilter alloc] init];
    [edgePreservingBlur addFilter:ind];
    [ind setScale:(CGPoint){scale,scale}];
    [ident addTarget:ind];
    
    GPUImageSobelEdgeDetectionFilter * sobelDetail = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    [edgePreservingBlur addFilter:sobelDetail];
    [ident addTarget:sobelDetail];
    
    GPUImageSobelEdgeDetectionFilter * sobel = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    [edgePreservingBlur addFilter:sobel];
    [ind addTarget:sobel];
    
    
    GPUImageBoxBlurFilter * smallBox = [[GPUImageBoxBlurFilter alloc] init];
    [smallBox setBlurRadiusInPixels:loblur];
    [edgePreservingBlur addFilter:smallBox];
    [ind addTarget:smallBox];
    
    GPUImageBoxBlurFilter * detailBox = [[GPUImageBoxBlurFilter alloc] init];
    [detailBox setBlurRadiusInPixels:detailblur];
    [edgePreservingBlur addFilter:smallBox];
    [ident addTarget:detailBox];
    
    StepFilter * step = [[StepFilter alloc] init];
    [step setEdgeOne:fmax(premid-prerng,0.0)];
    [step setEdgeTwo:premid+prerng];
    [edgePreservingBlur addFilter:step];
    [sobelDetail addTarget:step];
    
    GPUImageGaussianBlurFilter * edgeBox = [[GPUImageGaussianBlurFilter alloc] init];
    [edgeBox setBlurRadiusInPixels:edgerad];
    [edgePreservingBlur addFilter:edgeBox];
    [step addTarget:edgeBox];
    
    GPUImageBoxBlurFilter * coarseEdgeBox = [[GPUImageBoxBlurFilter alloc] init];
    [coarseEdgeBox setBlurRadiusInPixels:edgerad];
    [edgePreservingBlur addFilter:coarseEdgeBox];
    [sobel addTarget:coarseEdgeBox];
    
    StepFilter * step2 = [[StepFilter alloc] init];
    [step2 setEdgeOne:fmax(postmid-postrng,0.0)];
    [step2 setEdgeTwo:postmid+postrng];
    [edgePreservingBlur addFilter:step2];
    [edgeBox addTarget:step2];
    
    StepFilter * step3 = [[StepFilter alloc] init];
    [step3 setEdgeOne:fmax(coarsemid-coarserng,0.0)];
    [step3 setEdgeTwo:coarsemid+coarserng];
    [edgePreservingBlur addFilter:step3];
    [coarseEdgeBox addTarget:step3];
    
    //IndexingFilter * ind2 = [[IndexingFilter alloc] init];
    ScaleFilter * ind2 = [[ScaleFilter alloc] init];
    [edgePreservingBlur addFilter:ind2];
    [ind2 setScale:(CGPoint){1.0/scale,1.0/scale}];
    [smallBox addTarget:ind2];
    
    //IndexingFilter * ind3 = [[IndexingFilter alloc] init];
    ScaleFilter * ind3 = [[ScaleFilter alloc] init];
    [edgePreservingBlur addFilter:ind3];
    [ind3 setScale:(CGPoint){1.0/scale,1.0/scale}];
    [step3 addTarget:ind3];
    
    MaskBlendFilter * detail = [[MaskBlendFilter alloc] init];
    [edgePreservingBlur addFilter:detail];
    [ident addTarget:detail];
    [detailBox addTarget:detail];
    [step2 addTarget:detail];
    
    MaskBlendFilter * mask = [[MaskBlendFilter alloc] init];
    [edgePreservingBlur addFilter:mask];
    [detail addTarget:mask];
    [ind2 addTarget:mask];
    [ind3 addTarget:mask];
    
    [edgePreservingBlur setInitialFilters:@[ident]];
    [edgePreservingBlur setTerminalFilter:mask];
    return edgePreservingBlur;
}


#pragma mark -
#pragma mark Still image processing

- (void)useNextFrameForImageCapture
{
    [self.alyceFilter useNextFrameForImageCapture];
}

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput
{
    return [self.alyceFilter newCGImageFromCurrentlyProcessedOutput];
}



#pragma mark -
#pragma mark GPUImageOutput overrides

- (void)setTargetToIgnoreForUpdates:(id<GPUImageInput>)targetToIgnoreForUpdates;
{
    [_alyceFilter setTargetToIgnoreForUpdates:targetToIgnoreForUpdates];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    [_alyceFilter addTarget:newTarget atTextureLocation:textureLocation];
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove;
{
    [_alyceFilter removeTarget:targetToRemove];
}

- (void)removeAllTargets;
{
    [_alyceFilter removeAllTargets];
}

- (NSArray *)targets;
{
    return [_alyceFilter targets];
}

- (void)setFrameProcessingCompletionBlock:(void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock;
{
    [_alyceFilter setFrameProcessingCompletionBlock:frameProcessingCompletionBlock];
}

- (void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock;
{
    return [_alyceFilter frameProcessingCompletionBlock];
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    if (textureIndex > 0 && _inputCount < 2)
    {
        return;
    }
    
    if (textureIndex == self.userInputIndex)
    {
        if (self.airbrushFilterType == AirbrushFilterTypeSimple)
        {
            [self.simpleAirbrushFilterGroup newFrameReadyAtTime:frameTime atIndex:0];
        }
        else if (self.airbrushFilterType == AirbrushFilterTypeComplex)
        {
            [self.complexAirbrushFilterGroup newFrameReadyAtTime:frameTime atIndex:0];
        }
        else
        {
            [self.alyceFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
    else
    {
        [self.alyceFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
    }
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    if (textureIndex > 0 && _inputCount < 2)
    {
        return;
    }
    
    if (textureIndex == self.userInputIndex)
    {
        if (self.airbrushFilterType == AirbrushFilterTypeSimple)
        {
            [self.simpleAirbrushFilterGroup setInputFramebuffer:newInputFramebuffer atIndex:0];
        }
        else if (self.airbrushFilterType == AirbrushFilterTypeComplex)
        {
            [self.complexAirbrushFilterGroup setInputFramebuffer:newInputFramebuffer atIndex:0];
        }
        else
        {
            [self.alyceFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
        }
    }
    else
    {
        [self.alyceFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
    }
}

- (NSInteger)nextAvailableTextureIndex;
{
    // We only support addTarget:atTextureLocation:
    return 0;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    if (textureIndex == self.userInputIndex && self.airbrushFilterType != AirbrushFilterTypeNone)
    {
        [self.complexAirbrushFilterGroup setInputSize:newSize atIndex:textureIndex];
        [self.simpleAirbrushFilterGroup setInputSize:newSize atIndex:textureIndex];
    }
    else
    {
        [self.alyceFilter setInputSize:newSize atIndex:textureIndex];
    }
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
    if (textureIndex == self.userInputIndex && self.airbrushFilterType != AirbrushFilterTypeNone)
    {
        [self.complexAirbrushFilterGroup setInputRotation:newInputRotation atIndex:textureIndex];
        [self.simpleAirbrushFilterGroup setInputRotation:newInputRotation atIndex:textureIndex];
    }
    else
    {
        [self.alyceFilter setInputRotation:newInputRotation atIndex:textureIndex];
    }
}

- (void)forceProcessingAtSize:(CGSize)frameSize;
{
    [self.complexAirbrushFilterGroup forceProcessingAtSize:frameSize];
    [self.simpleAirbrushFilterGroup forceProcessingAtSize:frameSize];
    [self.alyceFilter forceProcessingAtSize:frameSize];
}

- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize;
{
    [self.complexAirbrushFilterGroup forceProcessingAtSizeRespectingAspectRatio:frameSize];
    [self.simpleAirbrushFilterGroup forceProcessingAtSizeRespectingAspectRatio:frameSize];
    [self.alyceFilter forceProcessingAtSizeRespectingAspectRatio:frameSize];
}

- (CGSize)maximumOutputSize;
{
    return CGSizeZero;
}

- (void)endProcessing;
{
    if (!isEndProcessing)
    {
        isEndProcessing = YES;
        
        [self.complexAirbrushFilterGroup endProcessing];
        [self.simpleAirbrushFilterGroup endProcessing];
        [self.alyceFilter endProcessing];
    }
}

- (BOOL)wantsMonochromeInput;
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue;
{
    
}

- (void)resetForLivePreview
{
    [self.alyceFilter resetForLivePreview];
    [self.renderer setCurrentTime:-1.0f];
    [self setUserInputIndex:0];
    [self.renderer setupLoopingTimedLayouts];
    [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
}

@end
