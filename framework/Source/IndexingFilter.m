//
//  IndexingFilter.m
//  GPUImage
//
//  Created by Solomon Garber on 8/4/16.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

//#import <Foundation/Foundation.h>

#import "IndexingFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kIndexingFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 
 uniform highp vec2 redCenter;
 uniform highp vec2 greenCenter;
 uniform highp vec2 blueCenter;
 
 uniform highp vec2 redScale;
 uniform highp vec2 greenScale;
 uniform highp vec2 blueScale;
 
 uniform highp vec2 redShift;
 uniform highp vec2 greenShift;
 uniform highp vec2 blueShift;
 
 uniform highp float redPhase;
 uniform highp float greenPhase;
 uniform highp float bluePhase;
 
 void main()
 {
     
     highp vec2 rpos = textureCoordinate-redCenter;
     highp float c = cos(redPhase);
     highp float s = sin(redPhase);
     rpos=mod(redScale*vec2(rpos.x*c-rpos.y*s,rpos.x*s+rpos.y*c)+redCenter+redShift,vec2(1.0));
     //rpos=mod(redScale*vec2(rpos.x*c-rpos.y*s,rpos.x*s+rpos.y*c)+redCenter,vec2(1.0));
     highp vec4 redSample = texture2D(inputImageTexture,rpos);
     
     highp vec2 gpos = textureCoordinate-greenCenter;
     c = cos(greenPhase);
     s = sin(greenPhase);
     gpos=mod(greenScale*vec2(gpos.x*c-gpos.y*s,gpos.x*s+gpos.y*c)+greenCenter+greenShift,vec2(1.0));
     //gpos=greenScale*vec2(gpos.x*c-gpos.y*s,gpos.x*s+gpos.y*c)+greenCenter+greenShift;
     highp vec4 greenSample = texture2D(inputImageTexture,gpos);
     
     highp vec2 bpos = textureCoordinate-blueCenter;
     c = cos(bluePhase);
     s = sin(bluePhase);
     bpos=mod(blueScale*vec2(bpos.x*c-bpos.y*s,bpos.x*s+bpos.y*c)+blueCenter+blueShift,vec2(1.0));
     //bpos=mod(blueScale*vec2(bpos.x*c-bpos.y*s,bpos.x*s+bpos.y*c)+blueCenter,vec2(1.0));
     highp vec4 blueSample = texture2D(inputImageTexture,bpos);
     
     gl_FragColor = vec4(redSample.r,greenSample.g,blueSample.b,1.0);
     
     //gl_FragColor=greenSample;
     /*
     highp vec2 rpos = textureCoordinate-redCenter;
     highp float c = cos(redPhase);
     highp float s = sin(redPhase);
     rpos=mod(vec2(rpos.x*c-rpos.y*s,rpos.x*s+rpos.y*c)+redCenter,vec2(1.0));
     gl_FragColor= texture2D(inputImageTexture,rpos);
      */
     
 }
 );
#else
NSString *const kIndexingFragmentShaderString = SHADER_STRING
(
 
 uniform sampler2D inputImageTexture;
 varying vec2 textureCoordinate;
 
 uniform vec2 vignetteCenter;
 uniform vec3 vignetteColor;
 uniform float vignetteStart;
 uniform float vignetteEnd;
 
 void main()
 {
     
     //todo: copy and paste
     
     /*
     highp vec2 rpos = textureCoordinate-redCenter;
     highp float c = cos(redPhase);
     highp float s = sin(redPhase);
     rpos=mod(vec2(rpos.x*c-rpos.y*s,rpos.x*s+rpos.y*c)+redCenter,vec2(1.0));
     highp vec4 redSample = texture2D(inputImageTexture,rpos);
     
     highp vec2 gpos = textureCoordinate-greenCenter;
     c = cos(greenPhase);
     s = sin(greenPhase);
     rpos=mod(vec2(gpos.x*c-gpos.y*s,gpos.x*s+gpos.y*c)+greenCenter,vec2(1.0));
     highp vec4 greenSample = texture2D(inputImageTexture,gpos);
     
     highp vec2 bpos = textureCoordinate-blueCenter;
     c = cos(bluePhase);
     s = sin(bluePhase);
     bpos=mod(vec2(bpos.x*c-bpos.y*s,bpos.x*s+bpos.y*c)+blueCenter,vec2(1.0));
     highp vec4 blueSample = texture2D(inputImageTexture,bpos);
     
     gl_FragColor = vec4(redSample.r,greenSample.g,blueSample.b,1.0);
     
     gl_FragColor=texture2D(inputImageTexture,textureCoordinate);
     */

 }
 );
#endif

@interface IndexingFilter ()

@property (readwrite, nonatomic) CGFloat aspectRatio;

- (void)adjustAspectRatio;

@end


@implementation IndexingFilter

@synthesize redCenter = _redCenter;
@synthesize greenCenter = _greenCenter;
@synthesize blueCenter = _blueCenter;

@synthesize redScale = _redScale;
@synthesize greenScale = _greenScale;
@synthesize blueScale = _blueScale;

@synthesize redShift = _redShift;
@synthesize greenShift = _greenShift;
@synthesize blueShift = _blueShift;

@synthesize redPhase = _redPhase;
@synthesize greenPhase = _greenPhase;
@synthesize bluePhase = _bluePhase;

@synthesize aspectRatio = _aspectRatio;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kIndexingFragmentShaderString]))
    {
        return nil;
    }
    
    redCenterUniform = [filterProgram uniformIndex:@"redCenter"];
    greenCenterUniform = [filterProgram uniformIndex:@"greenCenter"];
    blueCenterUniform = [filterProgram uniformIndex:@"blueCenter"];
    
    redScaleUniform = [filterProgram uniformIndex:@"redScale"];
    greenScaleUniform = [filterProgram uniformIndex:@"greenScale"];
    blueScaleUniform = [filterProgram uniformIndex:@"blueScale"];
    
    redShiftUniform = [filterProgram uniformIndex:@"redShift"];
    greenShiftUniform = [filterProgram uniformIndex:@"greenShift"];
    blueShiftUniform = [filterProgram uniformIndex:@"blueShift"];
    
    redPhaseUniform = [filterProgram uniformIndex:@"redPhase"];
    greenPhaseUniform = [filterProgram uniformIndex:@"greenPhase"];
    bluePhaseUniform = [filterProgram uniformIndex:@"bluePhase"];

    aspectRatioUniform = [filterProgram uniformIndex:@"aspectRatio"];
    
    self.redCenter = (CGPoint){ 0.5f, 0.5f };
    self.greenCenter = (CGPoint){ 0.5f, 0.5f };
    self.blueCenter = (CGPoint){ 0.5f, 0.5f };
    
    self.redScale = (CGPoint){ 1.0f, 1.0f };
    self.greenScale = (CGPoint){ 1.0f, 1.0f };
    self.blueScale = (CGPoint){ 1.0f, 1.0f };
    
    self.redShift = (CGPoint){ 0.0f, 0.0f };
    self.greenShift = (CGPoint){ 0.0f, 0.0f };
    self.blueShift = (CGPoint){ 0.0f, 0.0f };
    
    self.redPhase = 0.0;
    self.greenPhase = 0.0;
    self.bluePhase = 0.0;
    
    
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

- (void)setRedCenter:(CGPoint)newValue
{
    _redCenter = newValue;
    
    [self setPoint:_redCenter forUniform:redCenterUniform program:filterProgram];
}


- (void)setGreenCenter:(CGPoint)newValue
{
    _greenCenter = newValue;
    
    [self setPoint:_greenCenter forUniform:greenCenterUniform program:filterProgram];
}

- (void)setBlueCenter:(CGPoint)newValue
{
    _blueCenter = newValue;
    
    [self setPoint:_blueCenter forUniform:blueCenterUniform program:filterProgram];
}

- (void)setCenter:(CGPoint)newValue
{
    _redCenter = newValue;
    
    [self setPoint:_redCenter forUniform:redCenterUniform program:filterProgram];
    
    _greenCenter = newValue;
    
    [self setPoint:_greenCenter forUniform:greenCenterUniform program:filterProgram];
    
    _blueCenter = newValue;
    
    [self setPoint:_blueCenter forUniform:blueCenterUniform program:filterProgram];

}

- (void)setRedScale:(CGPoint)newValue
{
    _redScale = newValue;
    
    [self setPoint:_redScale forUniform:redScaleUniform program:filterProgram];
}


- (void)setGreenScale:(CGPoint)newValue
{
    _greenScale = newValue;
    
    [self setPoint:_greenScale forUniform:greenScaleUniform program:filterProgram];
}

- (void)setBlueScale:(CGPoint)newValue
{
    _blueScale = newValue;
    
    [self setPoint:_blueScale forUniform:blueScaleUniform program:filterProgram];
}

- (void)setScale:(CGPoint)newValue
{
    _redScale = newValue;
    
    [self setPoint:_redScale forUniform:redScaleUniform program:filterProgram];
    
    _greenScale = newValue;
    
    [self setPoint:_greenScale forUniform:greenScaleUniform program:filterProgram];
    
    _blueScale = newValue;
    
    [self setPoint:_blueScale forUniform:blueScaleUniform program:filterProgram];
    
}


- (void)setRedShift:(CGPoint)newValue
{
    _redShift = newValue;
    
    [self setPoint:_redShift forUniform:redShiftUniform program:filterProgram];}


- (void)setGreenShift:(CGPoint)newValue
{
    _greenShift = newValue;
    
    [self setPoint:_greenShift forUniform:greenShiftUniform program:filterProgram];
}

- (void)setBlueShift:(CGPoint)newValue
{
    _blueShift = newValue;
    
    [self setPoint:_blueShift forUniform:blueShiftUniform program:filterProgram];
}

- (void)setShift:(CGPoint)newValue
{
    _redShift = newValue;
    
    [self setPoint:_redShift forUniform:redShiftUniform program:filterProgram];
    
    _greenShift = newValue;
    
    [self setPoint:_greenShift forUniform:greenShiftUniform program:filterProgram];
    
    _blueShift = newValue;
    
    [self setPoint:_blueShift forUniform:blueShiftUniform program:filterProgram];
    
}


- (void)setRedPhase:(CGFloat)newValue;
{
    _redPhase = newValue;
    
    [self setFloat:_redPhase forUniform:redPhaseUniform program:filterProgram];
}

- (void)setGreenPhase:(CGFloat)newValue;
{
    _greenPhase = newValue;
    
    [self setFloat:_greenPhase forUniform:greenPhaseUniform program:filterProgram];
}

- (void)setBluePhase:(CGFloat)newValue;
{
    _bluePhase = newValue;
    
    [self setFloat:_bluePhase forUniform:bluePhaseUniform program:filterProgram];
}

- (void)setPhase:(CGFloat)newValue;
{
    _redPhase = newValue;
    
    [self setFloat:_redPhase forUniform:redPhaseUniform program:filterProgram];
    
    _greenPhase = newValue;
    
    [self setFloat:_greenPhase forUniform:greenPhaseUniform program:filterProgram];

    _bluePhase = newValue;
    
    [self setFloat:_bluePhase forUniform:bluePhaseUniform program:filterProgram];

}

- (void)setAspectRatio:(CGFloat)newValue;
{
    _aspectRatio = newValue;
    
    [self setFloat:_aspectRatio forUniform:aspectRatioUniform program:filterProgram];
}

@end


