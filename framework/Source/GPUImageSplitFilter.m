//
//  GPUImageSplitFilter.m
//  Pods
//
//  Created by Michael Harville on 3/19/15.
//
//

#import "GPUImageSplitFilter.h"

NSString *const kGPUImageSplitFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 uniform lowp float offset;
 
 void main()
 {
     if(textureCoordinate.x > offset) {
         gl_FragColor = texture2D(inputImageTexture2, textureCoordinate2);
     }
     else {
         gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
     }
 }
 );

@implementation GPUImageSplitFilter

- (id)init
{
    if(!(self = [super initWithFragmentShaderFromString:kGPUImageSplitFragmentShaderString]))
    {
       return nil;
    }
    
    return self;
}

- (void)setOffset:(CGFloat)offset
{
    [self setFloat:(1.0-offset) forUniformName:@"offset"];
}

@end
