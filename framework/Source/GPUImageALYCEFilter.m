#import "GPUImageALYCEFilter.h"
#import "ALYCEClientPreviewRenderer.h"

@interface GPUImageALYCEFilter()
{
    GPUImageRotationMode _firstInputRotationMode;
    GPUImageRotationMode _secondInputRotationMode;
    dispatch_semaphore_t _imageCaptureSemaphore;
}

@property (nonatomic, strong) GPUImageFramebuffer *firstInputFramebuffer;
@property (nonatomic, strong) GPUImageFramebuffer *secondInputFramebuffer;
@property (nonatomic) BOOL isEndProcessing;
@property (nonatomic) BOOL hasSetFirstTexture;
@property (nonatomic) BOOL hasSetSecondTexture;
@property (nonatomic) BOOL hasReceivedFirstFrame;
@property (nonatomic) BOOL hasReceivedSecondFrame;
@property (nonatomic) CMTime currentFrameTime;

@property (nonatomic) CGSize firstInputTextureSize;
@property (nonatomic) CGSize secondInputTextureSize;

@property (nonatomic, strong) ALYCEClientPreviewRenderer *renderer;
@property (nonatomic) float vocalsIntensity;

@end

@implementation GPUImageALYCEFilter

- (id)initWithRenderer:(ALYCEClientPreviewRenderer *)renderer
{
    self = [super init];
    
    if (self)
    {
        self.renderer = renderer;
        self.videoStyle = ALYCEVideoStyleClassic;
        self.colorFilter = ALYCEColorFilterNone;
        _imageCaptureSemaphore = dispatch_semaphore_create(0);
        dispatch_semaphore_signal(_imageCaptureSemaphore);
    }
    
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    if (_imageCaptureSemaphore != NULL)
    {
        dispatch_release(_imageCaptureSemaphore);
    }
#endif

}

- (CGSize)sizeOfFBO
{
    return inputTextureSize;
}

- (CGSize)outputFrameSize
{
    return inputTextureSize;
}

- (float)boostRMS:(float)rms
{
    return MIN(1.0f, 2 * sqrt(rms));
}

#pragma mark - GPUImageInput

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex
{
    runSynchronouslyOnVideoProcessingQueue(^{
        if (self.hasSetFirstTexture && self.hasSetSecondTexture)
        {
            // You can set up infinite update loops, so this helps to short circuit them
            if (self.hasReceivedFirstFrame && self.hasReceivedSecondFrame)
            {
                return;
            }
            
            if (textureIndex == 0)
            {
                self.hasReceivedFirstFrame = YES;
            }
            else if (textureIndex == 1)
            {
                self.hasReceivedSecondFrame = YES;
            }
            
            self.currentFrameTime = CMTimeMaximum(self.currentFrameTime, frameTime);
            
            if (!self.hasReceivedFirstFrame || !self.hasReceivedSecondFrame)
            {
                return;
            }
        }
        else
        {
            self.currentFrameTime = frameTime;
        }
        
        
        [GPUImageContext useImageProcessingContext];
        
        // TODO: Sometimes the framebuffer we get back from the cache is actually 360x360 when we request a 360x480.
        // Investigate why that is the case...
        
        CGSize outputSize = [self sizeOfFBO];
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:outputSize textureOptions:self.outputTextureOptions onlyTexture:NO];
        [outputFramebuffer activateFramebuffer];
        
        if (usingNextFrameForImageCapture)
        {
            [outputFramebuffer lock];
        }
        
        // Update vocals intensity using a low-pass filter
        float newVocalsIntensity = [self boostRMS:self.currentRMSBlock ? self.currentRMSBlock() : 0.0f];
        self.vocalsIntensity += 0.3f * (newVocalsIntensity - self.vocalsIntensity);
        [self.renderer setVocalsIntensity:self.vocalsIntensity];
        
        float timestampInSeconds = CMTIME_IS_VALID(self.currentFrameTime) && !CMTIME_IS_INDEFINITE(self.currentFrameTime) ? CMTimeGetSeconds(self.currentFrameTime) : -1.0f;
        ALYCERenderInput *input1 = [ALYCERenderInput RenderInputWithTextureId:self.firstInputFramebuffer.texture
                                                                        width:self.firstInputFramebuffer.size.width
                                                                       height:self.firstInputFramebuffer.size.height
                                                               flipVertically:YES
                                                             flipHorizontally:_firstInputRotationMode == kGPUImageFlipHorizonal
                                                           timestampInSeconds:timestampInSeconds];
        ALYCERenderInput *input2 = [ALYCERenderInput RenderInputWithTextureId:self.secondInputFramebuffer ? self.secondInputFramebuffer.texture : 0
                                                                        width:self.secondInputFramebuffer ? self.secondInputFramebuffer.size.width : 0
                                                                       height:self.secondInputFramebuffer ? self.secondInputFramebuffer.size.height : 0
                                                               flipVertically:YES
                                                             flipHorizontally:_secondInputRotationMode == kGPUImageFlipHorizonal
                                                           timestampInSeconds:timestampInSeconds];
        
        ALYCERenderOutput *output = [ALYCERenderOutput RenderOutputWithFramebufferId:outputFramebuffer.framebufferId
                                                                               width:outputSize.width
                                                                              height:outputSize.height
                                                                      flipVertically:YES
                                                                    flipHorizontally:NO];
        
        [self.renderer render:[NSObject new]
         videoStyle:self.videoStyle
        colorFilter:self.colorFilter
              processingWidth:360
             processingHeight:outputSize.height / outputSize.width * 360
                       input1:input1
                       input2:input2
                       output:output];
        
        // GPUImage doesn't use VBOs so let's disable it.
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        if (usingNextFrameForImageCapture)
        {
            dispatch_semaphore_signal(_imageCaptureSemaphore);
        }

        [self informTargetsAboutNewFrameAtTime:frameTime];
        
        self.hasReceivedFirstFrame = NO;
        self.hasReceivedSecondFrame = NO;
        
        self.currentFrameTime = CMTimeMake(0, 1);
    });
}

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime;
{
    if (self.frameProcessingCompletionBlock != NULL)
    {
        self.frameProcessingCompletionBlock(self, frameTime);
    }
    
    // Get all targets the framebuffer so they can grab a lock on it
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [self setInputFramebufferForTarget:currentTarget atIndex:textureIndex];
            [currentTarget setInputSize:[self outputFrameSize] atIndex:textureIndex];
        }
    }
    
    // Release our hold so it can return to the cache immediately upon processing
    [[self framebufferForOutput] unlock];
    
    if (usingNextFrameForImageCapture)
    {
        //        usingNextFrameForImageCapture = NO;
    }
    else
    {
        [self removeOutputFramebuffer];
    }
    
    
    // Trigger processing last, so that our unlock comes first in serial execution, avoiding the need for a callback
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

- (NSInteger)nextAvailableTextureIndex
{
    // We only support addTarget:atTextureLocation:
    return 0;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue
{
    // Ignored
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    if (textureIndex == 0)
    {
        if (self.firstInputFramebuffer)
        {
            [self.firstInputFramebuffer unlock];
        }
        self.firstInputFramebuffer = newInputFramebuffer;
        self.hasSetFirstTexture = YES;
        [self.firstInputFramebuffer lock];
    }
    else
    {
        if (self.secondInputFramebuffer)
        {
            [self.secondInputFramebuffer unlock];
        }
        self.secondInputFramebuffer = newInputFramebuffer;
        self.hasSetSecondTexture = YES;
        [self.secondInputFramebuffer lock];
    }
}

- (BOOL)hasReceivedFramebuffer
{
    return self.hasReceivedFirstFrame || self.hasReceivedSecondFrame;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    if (CGSizeEqualToSize(newSize, CGSizeZero))
    {
        inputTextureSize = CGSizeZero;
        self.firstInputTextureSize = CGSizeZero;
        self.secondInputTextureSize = CGSizeZero;
        self.hasSetFirstTexture = NO;
        self.hasSetSecondTexture = NO;
        
        if (self.firstInputFramebuffer)
        {
            [self.firstInputFramebuffer unlock];
            self.firstInputFramebuffer = nil;
        }
        if (self.secondInputFramebuffer)
        {
            [self.secondInputFramebuffer unlock];
            self.secondInputFramebuffer = nil;
        }
    }
    else
    {
        if (textureIndex == 0)
        {
            self.firstInputTextureSize = newSize;
        }
        else
        {
            self.secondInputTextureSize = newSize;
        }
        
        
        inputTextureSize = self.firstInputTextureSize.width > self.secondInputTextureSize.width ? self.firstInputTextureSize : self.secondInputTextureSize;
    }
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex
{
    if (textureIndex == 0)
    {
        _firstInputRotationMode = newInputRotation;
    }
    else
    {
        _secondInputRotationMode = newInputRotation;
    }
}

- (CGSize)maximumOutputSize
{
    return CGSizeZero;
}

- (void)endProcessing
{
    if (!self.isEndProcessing)
    {
        self.isEndProcessing = YES;
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            [currentTarget endProcessing];
        }
    }
}

- (BOOL)wantsMonochromeInput
{
    return NO;
}

- (void)resetForLivePreview
{
    self.hasSetSecondTexture = NO;
}

#pragma mark - Still image processing

- (void)useNextFrameForImageCapture;
{
    usingNextFrameForImageCapture = YES;
    
    // Set the semaphore high, if it isn't already
    if (dispatch_semaphore_wait(_imageCaptureSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }
}

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput
{
    // Give it three seconds to process, then abort if they forgot to set up the image capture properly
    double timeoutForImageCapture = 3.0;
    dispatch_time_t convertedTimeout = dispatch_time(DISPATCH_TIME_NOW, timeoutForImageCapture * NSEC_PER_SEC);
    
    if (dispatch_semaphore_wait(_imageCaptureSemaphore, convertedTimeout) != 0)
    {
        return NULL;
    }
    
    GPUImageFramebuffer* framebuffer = [self framebufferForOutput];
    
    usingNextFrameForImageCapture = NO;
    dispatch_semaphore_signal(_imageCaptureSemaphore);
    
    CGImageRef image = [framebuffer newCGImageFromFramebufferContents];
    return image;
}

@end
