#import "GPUImageMovie.h"
#import "GPUImageMovieWriter.h"

@interface GPUImageMovie ()
{
    BOOL audioEncodingIsFinished, videoEncodingIsFinished;
    GPUImageMovieWriter *synchronizedMovieWriter;
    CVOpenGLESTextureCacheRef coreVideoTextureCache;
    AVAssetReader *reader;
	NSLock* readerLock;
	
	NSMutableArray* previousFrameInfos;
	NSMutableArray* trackDoneReading;
    
    // ian: we need another output texture to support transitions
    GLuint secondOutputTexture;
}

- (void)processAsset;

@end

@implementation GPUImageMovie

@synthesize url = _url;
@synthesize asset = _asset;
@synthesize runBenchmark = _runBenchmark;
@synthesize playAtActualSpeed = _playAtActualSpeed;

@synthesize linkedOverlay = _linkedOverlay;

@synthesize transitionFilter = _transitionFilter;

@synthesize hardFrameDifferenceLimit = _hardFrameDifferenceLimit;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithURL:(NSURL *)url;
{
    if (!(self = [super init])) 
    {
        return nil;
    }

    [self textureCacheSetup];

    self.url = url;
    self.asset = nil;
    self.linkedOverlay = nil;
    self.transitionFilter = nil;
	
	readerLock = [[NSLock alloc] init];

    return self;
}

- (id)initWithAsset:(AVAsset *)asset;
{
    if (!(self = [super init])) 
    {
      return nil;
    }
    
    [self textureCacheSetup];

    self.url = nil;
    self.asset = asset;
    self.linkedOverlay = nil;
    self.transitionFilter = nil;
	
	readerLock = [[NSLock alloc] init];

    return self;
}

- (void)textureCacheSetup;
{
    if ([GPUImageOpenGLESContext supportsFastTextureUpload])
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageOpenGLESContext useImageProcessingContext];
#if defined(__IPHONE_6_0)
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [[GPUImageOpenGLESContext sharedImageProcessingOpenGLESContext] context], NULL, &coreVideoTextureCache);
#else
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge void *)[[GPUImageOpenGLESContext sharedImageProcessingOpenGLESContext] context], NULL, &coreVideoTextureCache);
#endif
            if (err)
            {
                NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
            }
            
            // Need to remove the initially created texture
            [self deleteOutputTexture];
        });
    }
}

- (void)dealloc
{
    if ([GPUImageOpenGLESContext supportsFastTextureUpload])
    {
        CFRelease(coreVideoTextureCache);
    }
}

#pragma mark -
#pragma mark Manage the output texture

- (void)initializeOutputTexture;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageOpenGLESContext useImageProcessingContext];
        
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &outputTexture);
        glBindTexture(GL_TEXTURE_2D, outputTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        // This is necessary for non-power-of-two textures
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glGenTextures(1, &secondOutputTexture);
        glBindTexture(GL_TEXTURE_2D, secondOutputTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);
    });
}

- (void)deleteOutputTexture;
{
    if (outputTexture)
    {
        glDeleteTextures(1, &outputTexture);
        outputTexture = 0;
    }
    
    if (secondOutputTexture)
    {
        glDeleteTextures(1, &secondOutputTexture);
        secondOutputTexture = 0;
    }
}


#pragma mark -
#pragma mark Movie processing

- (void)enableSynchronizedEncodingUsingMovieWriter:(GPUImageMovieWriter *)movieWriter;
{
    synchronizedMovieWriter = movieWriter;
    //movieWriter.encodingLiveVideo = NO;  //mtg: why is this here?
}

- (void)startProcessing
{
	previousFrameInfos = [[NSMutableArray alloc] init];
	for (int i = 0; i < 2; i++) {
		NSMutableDictionary* previousFrameInfo = [NSMutableDictionary dictionaryWithCapacity:5];
		[previousFrameInfo setObject:[NSValue valueWithCMTime:kCMTimeZero] forKey:@"previousFrameTime"];
		[previousFrameInfo setObject:[NSNumber numberWithDouble:CFAbsoluteTimeGetCurrent()] forKey:@"previousActualFrameTime"];
		[previousFrameInfo setObject:[NSValue valueWithCMTime:kCMTimeZero] forKey:@"previousDisplayFrameTime"];
		CMSampleBufferRef previousSampleBufferRef = (__bridge CMSampleBufferRef)([previousFrameInfo objectForKey:@"previousSampleBufferRef"]);
		if (previousSampleBufferRef) {
			CMSampleBufferInvalidate(previousSampleBufferRef);
			//CFRelease(previousSampleBufferRef);
			[previousFrameInfo removeObjectForKey:@"previousSampleBufferRef"];
		}
		[previousFrameInfos addObject:previousFrameInfo];
	}
	
	trackDoneReading = [[NSMutableArray alloc] init];
	for (int i = 0; i < 2; i++) {
		[trackDoneReading addObject:@(NO)];
	}
	
    if(self.url == nil)
    {
      [self processAsset];
      return;
    }
	
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:self.url options:inputOptions];    
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        NSError *error = nil;
        AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];
        if (!tracksStatus == AVKeyValueStatusLoaded) 
        {
            return;
        }
        self.asset = inputAsset;
        [self processAsset];
    }];
}

- (void)processAsset
{
	[readerLock lock];
	
    //__unsafe_unretained GPUImageMovie *weakSelf = self;
	//ok wtf brad: http://stackoverflow.com/questions/8592289/arc-the-meaning-of-unsafe-unretained
	//see "why would you ever use __unsafe_unretained?"
	__weak GPUImageMovie *weakSelf = self;
    NSError *error = nil;
    reader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
	
	for (AVAssetTrack *assetVideoTrack in [self.asset tracksWithMediaType:AVMediaTypeVideo]) {
		//mtg: naturalSize is NOT deprecated for AVComposition, and since that's what we're primarily using this for...
		//ian: seems to be working for me calling naturalSize on the track
		CGSize assetSize;
		//if ([self.asset isKindOfClass:[AVComposition class]]) {
		//	assetSize = [(AVComposition*)self.asset naturalSize];
		//}
		//else {
			assetSize = [assetVideoTrack naturalSize];
		//}
		
		NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
		[outputSettings setObject: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]  forKey: (NSString*)kCVPixelBufferPixelFormatTypeKey];
		[outputSettings setObject:[NSNumber numberWithInt:assetSize.width] forKey: (NSString*)kCVPixelBufferWidthKey];
		[outputSettings setObject:[NSNumber numberWithInt:assetSize.height] forKey: (NSString*)kCVPixelBufferHeightKey];
		// Maybe set alwaysCopiesSampleData to NO on iOS 5.0 for faster video decoding
		
		AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetVideoTrack outputSettings:outputSettings];
		[reader addOutput:readerVideoTrackOutput];
	}
	
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    BOOL shouldRecordAudioTrack = (([audioTracks count] > 0) && (weakSelf.audioEncodingTarget != nil) );
    AVAssetReaderTrackOutput *readerAudioTrackOutput = nil;

    if (shouldRecordAudioTrack)
    {
        audioEncodingIsFinished = NO;

        // This might need to be extended to handle movies with more than one audio track
        AVAssetTrack* audioTrack = [audioTracks objectAtIndex:0];
        readerAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
        [reader addOutput:readerAudioTrackOutput];
    }
	
	BOOL didStart = [reader startReading];
    if (!didStart)
    {
		NSLog(@"Error reading from file at URL: %@", weakSelf.url);
		[readerLock unlock];
		[self endProcessing];
        return;
    }
    
    if (synchronizedMovieWriter != nil)
    {
        [synchronizedMovieWriter setVideoInputReadyCallback:^{
			//GPUImageMovie *strongSelf = weakSelf;
			if (weakSelf) {
				[weakSelf readNextVideoFrame];
			}
        }];

        [synchronizedMovieWriter setAudioInputReadyCallback:^{
			if (weakSelf) {
				[weakSelf readNextAudioSampleFromOutput:readerAudioTrackOutput];
			}
        }];

        [synchronizedMovieWriter enableSynchronizationCallbacks];
		
		[readerLock unlock];
    }
    else
    {
		[readerLock unlock];
		
        while (reader.status == AVAssetReaderStatusReading)
        {
			//[weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput];
			[weakSelf readNextVideoFrame];
			
            if ( (shouldRecordAudioTrack) && (!audioEncodingIsFinished) )
            {
                    [weakSelf readNextAudioSampleFromOutput:readerAudioTrackOutput];
            }

        }

        if (reader.status == AVAssetWriterStatusCompleted) {
                [weakSelf endProcessing];
        }
    }
}

- (void)readNextVideoFrame {
	//read all video tracks!
    int transitionIndex = 0;
    int trackIndex = 0;
	BOOL shouldEnd = YES;
    CMTime earliestPreviousFrameTime = kCMTimePositiveInfinity;
    int transitionIndexToProcess;
    int trackIndexToProcess;
	for (AVAssetReaderTrackOutput* output in reader.outputs) {
		if ([output.mediaType isEqualToString:AVMediaTypeVideo]) {
			if (![[trackDoneReading objectAtIndex:transitionIndex] boolValue]) {
                // check if this track has the earliest previous frame
                NSMutableDictionary* previousFrameInfo = [previousFrameInfos objectAtIndex:transitionIndex];
                CMTime previousFrameTime = [[previousFrameInfo objectForKey:@"previousFrameTime"] CMTimeValue];
                if (CMTimeCompare(previousFrameTime, earliestPreviousFrameTime) < 0)
                {
                    earliestPreviousFrameTime = previousFrameTime;
                    transitionIndexToProcess = transitionIndex;
                    trackIndexToProcess = trackIndex;
                }

				shouldEnd = NO;
			}
            transitionIndex += 1;
		}
        trackIndex += 1;
	}
	if (shouldEnd) { //if all tracks are done reading...
		[self endProcessing];
	}
    else
    {
        [self readNextVideoFrameFromOutput:[reader.outputs objectAtIndex:trackIndexToProcess] transitionIndex:transitionIndexToProcess];
    }
}

- (void)readNextVideoFrameFromOutput:(AVAssetReaderTrackOutput *)readerVideoTrackOutput transitionIndex:(int)transitionIndex;
{
	[readerLock lock];
	
	AVAssetReaderStatus readerStatus = reader.status;
	
    if (readerStatus == AVAssetReaderStatusReading)
    {
        CMSampleBufferRef sampleBufferRef = [readerVideoTrackOutput copyNextSampleBuffer];
		[readerLock unlock];
        if (sampleBufferRef)
        {
			NSMutableDictionary* previousFrameInfo = [previousFrameInfos objectAtIndex:transitionIndex];
			CMTime previousFrameTime = [[previousFrameInfo objectForKey:@"previousFrameTime"] CMTimeValue];
			CMTime previousDisplayFrameTime = [[previousFrameInfo objectForKey:@"previousDisplayFrameTime"] CMTimeValue];
			CFAbsoluteTime previousActualFrameTime = [[previousFrameInfo objectForKey:@"previousActualFrameTime"] doubleValue];
			CMSampleBufferRef previousSampleBufferRef = (CMSampleBufferRef)CFBridgingRetain([previousFrameInfo objectForKey:@"previousSampleBufferRef"]);
			
			// Do this outside of the video processing queue to not slow that down while waiting
			CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
			CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime);
			CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
			
			CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
			CGFloat actualTimeDifference = currentActualTime - previousActualFrameTime;
			
			CGFloat frameTimeDisplayDifference = CMTimeGetSeconds(CMTimeSubtract(previousFrameTime, previousDisplayFrameTime));
			
            // ian: have the linked overlay process a frame at our current time
            if (self.linkedOverlay)
            {
                [self.linkedOverlay processFrameAtTargetTime:currentSampleTime];
            }
            
			//mtg: filter out frames that are displayed too quickly that we'll never realistically display them
			//mtg: glitch frames always come just barely (160 ns) before the correct frame, filter these out too, what's the magic number though?? 10 usec seems to do it
			if (previousSampleBufferRef && (CMTIME_IS_INVALID(previousDisplayFrameTime) || (frameTimeDisplayDifference > _hardFrameDifferenceLimit && frameTimeDifference > 1e-5)))
			{
				if (_playAtActualSpeed && frameTimeDifference > actualTimeDifference)
				{
					usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
				}
				
				previousDisplayFrameTime = previousFrameTime;
				previousActualFrameTime = CFAbsoluteTimeGetCurrent();
				
				__unsafe_unretained GPUImageMovie *weakSelf = self;
				runSynchronouslyOnVideoProcessingQueue(^{
					[weakSelf processMovieFrame:previousSampleBufferRef transitionIndex:transitionIndex];
				});
				
				//NSLog(@"displayed frame at %lld / %d (%e %e)", previousFrameTime.value, previousFrameTime.timescale, frameTimeDifference, frameTimeDisplayDifference);
			}
			//			else {
			//				NSLog(@"skipped frame at %lld / %d (%e %e)", previousFrameTime.value, previousFrameTime.timescale, frameTimeDifference, frameTimeDisplayDifference);
			//			}
			
			if (frameTimeDisplayDifference < 0) {
				previousDisplayFrameTime = kCMTimeZero;
			}
			
			if (previousSampleBufferRef) {
				CMSampleBufferInvalidate(previousSampleBufferRef);
				CFRelease(previousSampleBufferRef);
			}
			previousSampleBufferRef = sampleBufferRef;
			previousFrameTime = currentSampleTime;
			
			[previousFrameInfo setObject:[NSValue valueWithCMTime:previousFrameTime] forKey:@"previousFrameTime"];
			[previousFrameInfo setObject:[NSValue valueWithCMTime:previousDisplayFrameTime] forKey:@"previousDisplayFrameTime"];
			[previousFrameInfo setObject:[NSNumber numberWithDouble:previousActualFrameTime] forKey:@"previousActualFrameTime"];
			[previousFrameInfo setObject:(id)CFBridgingRelease(previousSampleBufferRef) forKey:@"previousSampleBufferRef"];
			[previousFrameInfos replaceObjectAtIndex:transitionIndex withObject:previousFrameInfo];
        }
        else
        {
			//other tracks could be still going, wait for AVAssetWriterStatusCompleted
//            videoEncodingIsFinished = YES;
//            [self endProcessing];
			[trackDoneReading replaceObjectAtIndex:transitionIndex withObject:@(YES)];
        }
    }
    else if (synchronizedMovieWriter != nil)
    {
        if (readerStatus == AVAssetWriterStatusCompleted)
        {
			[readerLock unlock];
            [self endProcessing];
        }
		else {
			[readerLock unlock];
		}
    }
	else {
		[readerLock unlock];
	}
}

- (void)readNextAudioSampleFromOutput:(AVAssetReaderTrackOutput *)readerAudioTrackOutput;
{
    if (audioEncodingIsFinished)
    {
        return;
    }

    CMSampleBufferRef audioSampleBufferRef = [readerAudioTrackOutput copyNextSampleBuffer];
    
    if (audioSampleBufferRef) 
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            [self.audioEncodingTarget processAudioBuffer:audioSampleBufferRef];
            
            CMSampleBufferInvalidate(audioSampleBufferRef);
            CFRelease(audioSampleBufferRef);
        });
    }
    else
    {
        audioEncodingIsFinished = YES;
    }
}

- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer transitionIndex:(int)transitionIndex
{
//    CMTimeGetSeconds
//    CMTimeSubtract
    
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);

    int bufferHeight = CVPixelBufferGetHeight(movieFrame);
#if TARGET_IPHONE_SIMULATOR
    int bufferWidth = CVPixelBufferGetBytesPerRow(movieFrame) / 4; // This works around certain movie frame types on the Simulator (see https://github.com/BradLarson/GPUImage/issues/424)
#else
    int bufferWidth = CVPixelBufferGetWidth(movieFrame);
#endif

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    if ([GPUImageOpenGLESContext supportsFastTextureUpload])
    {
        CVPixelBufferLockBaseAddress(movieFrame, 0);
        
        [GPUImageOpenGLESContext useImageProcessingContext];
        CVOpenGLESTextureRef texture = NULL;
        CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
																	coreVideoTextureCache,
																	movieFrame,
																	NULL,
																	GL_TEXTURE_2D,
																	GL_RGBA,
																	bufferWidth,
																	bufferHeight,
																	GL_RGBA,  //GL_BRGA  since we're reading the pixels directly...
																	GL_UNSIGNED_BYTE,
																	0,
																	&texture);
        
        if (!texture || err) {
            NSLog(@"Movie CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);  
            return;
        }
        
		if (transitionIndex == 0) {
			outputTexture = CVOpenGLESTextureGetName(texture);
		}
		else {
			secondOutputTexture = CVOpenGLESTextureGetName(texture);
		}
        //        glBindTexture(CVOpenGLESTextureGetTarget(texture), outputTexture);
        glBindTexture(GL_TEXTURE_2D, (transitionIndex == 0) ? outputTexture : secondOutputTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        if (self.transitionFilter)
        {
			//printf("%d\n", transitionIndex);
//			if (transitionIndex == 0) {
				[self.transitionFilter updateTransition:CMTimeGetSeconds(currentSampleTime)];
//			}
            [self.transitionFilter setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:transitionIndex];
            [self.transitionFilter setInputTexture:((transitionIndex == 0) ? outputTexture : secondOutputTexture) atIndex:transitionIndex];
            [self.transitionFilter newFrameReadyAtTime:currentSampleTime atIndex:transitionIndex];
        }
        else
        {
            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                [currentTarget setInputTexture:outputTexture atIndex:targetTextureIndex];
                
                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
            }
        }
        
        CVPixelBufferUnlockBaseAddress(movieFrame, 0);
        
        // Flush the CVOpenGLESTexture cache and release the texture
        CVOpenGLESTextureCacheFlush(coreVideoTextureCache, 0);
        CFRelease(texture);
        
        if (transitionIndex == 0)
            outputTexture = 0;
        else
            secondOutputTexture = 0;
    }
    else
    {
        // Upload to texture
        CVPixelBufferLockBaseAddress(movieFrame, 0);
        
        glBindTexture(GL_TEXTURE_2D, (transitionIndex == 0) ? outputTexture : secondOutputTexture);
        // Using BGRA extension to pull in video frame data directly
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(movieFrame));
        
        CGSize currentSize = CGSizeMake(bufferWidth, bufferHeight);
        
        if (self.transitionFilter)
        {
            [self.transitionFilter setInputSize:currentSize atIndex:transitionIndex];
			[self.transitionFilter updateTransition:CMTimeGetSeconds(currentSampleTime)];
            [self.transitionFilter newFrameReadyAtTime:currentSampleTime atIndex:transitionIndex];
        }
        else
        {
            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                
                [currentTarget setInputSize:currentSize atIndex:targetTextureIndex];
                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
            }
        }
        
        CVPixelBufferUnlockBaseAddress(movieFrame, 0);
    }
    
    if (_runBenchmark)
    {
        CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
        NSLog(@"Current frame time : %f ms", 1000.0 * currentFrameTime);
    }
}

- (void)endProcessing;
{
	if (synchronizedMovieWriter != nil)
	{
		[synchronizedMovieWriter setVideoInputReadyCallback:^{}];
		[synchronizedMovieWriter setAudioInputReadyCallback:^{}];
		[synchronizedMovieWriter endProcessing];  //we want the writer to stop ASAP
	}
	
	[readerLock lock];
	
	if (reader.status == AVAssetReaderStatusReading) {
		[reader cancelReading];
	}
	
	//block until reading stops!
	while (reader.status == AVAssetReaderStatusReading) {
		[NSThread sleepForTimeInterval:0.1];
	}
	
	[readerLock unlock];
	
	for (id<GPUImageInput> currentTarget in targets)
	{
		[currentTarget endProcessing];
	}
}

// ian: if there's a transition filter, add the targets to that instead (& same with remove)
- (void)addTarget:(id<GPUImageInput>)newTarget;
{
    if (self.transitionFilter)
        [self.transitionFilter addTarget:newTarget];
    else
        [super addTarget:newTarget];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    if (self.transitionFilter)
        [self.transitionFilter addTarget:newTarget atTextureLocation:textureLocation];
    else
        [super addTarget:newTarget atTextureLocation:textureLocation];
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove
{
    if (self.transitionFilter)
        [self.transitionFilter removeTarget:targetToRemove];
    else
        [super removeTarget:targetToRemove];
}

- (void)removeAllTargets
{
    if (self.transitionFilter)
        [self.transitionFilter removeAllTargets];
    else
        [super removeAllTargets];
}

- (void)setTransitionFilter:(GPUImageTwoInputFilter<TransitionFilterDelegate> *)newTransitionFilter
{
    if (_transitionFilter)
    {
        // there was a previous transition filter -- remove all its targets and add them to this new one
        NSArray *oldTargets = _transitionFilter.targets;
        NSArray *oldIndices = _transitionFilter.targetTextureIndices;
        [_transitionFilter removeAllTargets];
        
        if (newTransitionFilter)
        {
            for (id<GPUImageInput> target in oldTargets)
            {
                NSInteger indexOfObject = [oldTargets indexOfObject:target];
                NSInteger textureIndexOfTarget = [[oldIndices objectAtIndex:indexOfObject] integerValue];
                [newTransitionFilter addTarget:target atTextureLocation:textureIndexOfTarget];
            }
        }
        else
        {
            // add the targets to the movie itself
            for (id<GPUImageInput> target in oldTargets)
            {
                NSInteger indexOfObject = [oldTargets indexOfObject:target];
                NSInteger textureIndexOfTarget = [[oldIndices objectAtIndex:indexOfObject] integerValue];
                [super addTarget:target atTextureLocation:textureIndexOfTarget];
            }
        }
        
        // remove the old transition filter as a target
        runSynchronouslyOnVideoProcessingQueue(^{
            [_transitionFilter setInputSize:CGSizeZero atIndex:0];
            [_transitionFilter setInputTexture:0 atIndex:0];
            [_transitionFilter setInputRotation:kGPUImageNoRotation atIndex:0];
            
            [_transitionFilter setInputSize:CGSizeZero atIndex:1];
            [_transitionFilter setInputTexture:0 atIndex:1];
            [_transitionFilter setInputRotation:kGPUImageNoRotation atIndex:1];
        });
    }
    
    if (newTransitionFilter)
    {
        // add the new transition filter as a target
        runSynchronouslyOnVideoProcessingQueue(^{
            [newTransitionFilter setInputTexture:outputTexture atIndex:0];
            [newTransitionFilter setInputTexture:secondOutputTexture atIndex:1];
        });
    }
    
    _transitionFilter = newTransitionFilter;
}

- (GPUImageTwoInputFilter<TransitionFilterDelegate> *)transitionFilter
{
    return _transitionFilter;
}

@end
