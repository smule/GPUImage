//
//  MaskBlendFilter.m
//  GPUImage
//
//  Created by Solomon Garber on 7/21/16.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

//#import <Foundation/Foundation.h>

#import "MaskBlendFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kMaskBlendFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 varying highp vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 void main()
 {
     lowp vec4 base = texture2D(inputImageTexture, textureCoordinate);
     lowp vec4 overlayer = texture2D(inputImageTexture2, textureCoordinate2);
     lowp vec4 mask = texture2D(inputImageTexture3,textureCoordinate3);
     
     gl_FragColor = base*mask+overlayer*(vec4(1.0)-mask);
     //gl_FragColor = overlayer * base + overlayer * (1.0 - base.a) + base * (1.0 - overlayer.a);
 }
 );
#else
NSString *const kMaskBlendFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 varying vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 void main()
 {
     vec4 base = texture2D(inputImageTexture, textureCoordinate);
     vec4 overlayer = texture2D(inputImageTexture2, textureCoordinate2);
     vec4 mask = texture2D(inputImageTexture3,textureCoordinate3);
     
     gl_FragColor = base*mask+overlayer*(vec4(1.0)-mask);
     //gl_FragColor = overlayer * base + overlayer * (1.0 - base.a) + base * (1.0 - overlayer.a);
 }
 );
#endif

@implementation MaskBlendFilter

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kMaskBlendFragmentShaderString]))
    {
        return nil;
    }
    
    return self;
}

@end

