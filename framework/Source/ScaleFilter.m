//
//  ScaleFilter.m
//  Pods
//
//  Created by Solomon Garber on 3/6/17.
//
//

//#import <Foundation/Foundation.h>

#import "ScaleFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kScaleFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 
 uniform highp vec2 scale;
 
 void main()
 {
     
     
      gl_FragColor= texture2D(inputImageTexture,textureCoordinate*scale);
     
     
 }
 );
#else
NSString *const kScaleFragmentShaderString = SHADER_STRING
(
 
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 
 uniform highp vec2 scale;
 
 void main()
 {
     
     
     gl_FragColor= texture2D(inputImageTexture,textureCoordinate*scale);
     
     
 }
 );
#endif

@interface ScaleFilter ()

@property (readwrite, nonatomic) CGFloat aspectRatio;

- (void)adjustAspectRatio;

@end


@implementation ScaleFilter



@synthesize scale = _scale;


@synthesize aspectRatio = _aspectRatio;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kScaleFragmentShaderString]))
    {
        return nil;
    }
    

    scaleUniform = [filterProgram uniformIndex:@"scale"];
    
    self.scale = (CGPoint){ 1.0f, 1.0f };
    
    return self;
}

- (void)adjustAspectRatio;
{
    if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
    {
        [self setAspectRatio:(inputTextureSize.width / inputTextureSize.height)];
    }
    else
    {
        [self setAspectRatio:(inputTextureSize.height / inputTextureSize.width)];
    }
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
    [super setInputRotation:newInputRotation atIndex:textureIndex];
    [self adjustAspectRatio];
}

- (void)forceProcessingAtSize:(CGSize)frameSize;
{
    [super forceProcessingAtSize:frameSize];
    [self adjustAspectRatio];
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    CGSize oldInputSize = inputTextureSize;
    [super setInputSize:newSize atIndex:textureIndex];
    
    if ( (!CGSizeEqualToSize(oldInputSize, inputTextureSize)) && (!CGSizeEqualToSize(newSize, CGSizeZero)) )
    {
        [self adjustAspectRatio];
    }
}


#pragma mark -
#pragma mark Accessors

- (void)setScale:(CGPoint)newValue
{
    _scale = newValue;
    
    [self setPoint:_scale forUniform:scaleUniform program:filterProgram];
}

@end


