//
//  StepFilter.m
//  GPUImage
//
//  Created by Solomon Garber on 7/20/16.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

//#import <Foundation/Foundation.h>

#import "StepFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kStepFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform highp float edgeOne;
 uniform highp float edgeTwo;
 
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     lowp float intensity = dot(textureColor.rgb,vec3(.33333,.33333,.333333));
     
     gl_FragColor=vec4(vec3(smoothstep(edgeOne,edgeTwo,intensity)),1.0);
     
     //gl_FragColor = vec4(((textureColor.rgb - vec3(0.5)) * contrast + vec3(0.5)), textureColor.w);
 }
 );
#else
NSString *const kStepFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform float contrast;
 
 void main()
 {
     vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     
     gl_FragColor = vec4(((textureColor.rgb - vec3(0.5)) * contrast + vec3(0.5)), textureColor.w);
 }
 );
#endif

@implementation StepFilter;

@synthesize edgeOne = _edgeOne;
@synthesize edgeTwo = _edgeTwo;

#pragma mark -
#pragma mark Initialization

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kStepFragmentShaderString]))
    {
        return nil;
    }
    
    edgeOneUniform = [filterProgram uniformIndex:@"edgeOne"];
    self.edgeOne = 0.0;
    edgeTwoUniform = [filterProgram uniformIndex:@"edgeTwo"];
    self.edgeTwo = 0.1;
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setEdgeOne:(CGFloat)newValue;
{
    _edgeOne = newValue;
    
    [self setFloat:_edgeOne forUniform:edgeOneUniform program:filterProgram];
}

- (void)setEdgeTwo:(CGFloat)newValue;
{
    _edgeTwo = newValue;
    
    [self setFloat:_edgeTwo forUniform:edgeTwoUniform program:filterProgram];
}

@end

