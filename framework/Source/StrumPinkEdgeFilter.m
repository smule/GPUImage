//
//  StrumPinkEdgeFilter.m
//  SocialVideo
//
//  Created by Ian Simon on 2/4/13.
//  Copyright (c) 2013 Smule. All rights reserved.
//

#import "GPUImage.h"
#import "StrumPinkEdgeFilter.h"

NSString *const kPinkifyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform lowp vec3 col;
 void main()
 {
     lowp float edge = texture2D(inputImageTexture, textureCoordinate).r;
     edge = 1.0 - edge;
     gl_FragColor = vec4(edge*col, 1.0);
 }
);

@interface StrumPinkEdgeFilter ()
@property GPUImageFilter *pinkifyFilter;
@end

@implementation StrumPinkEdgeFilter

- (id)init
{
    self = [super init];
    if (self)
    {
        // blur
        GPUImageMedianFilter *blurFilter = [[GPUImageMedianFilter alloc] init];
        [blurFilter setupFilterForSize:CGSizeMake(480.0, 360.0)];
        [self addFilter:blurFilter];
        
        // sketch
        GPUImageSketchFilter *sketchFilter = [[GPUImageSketchFilter alloc] init];
        [sketchFilter setupFilterForSize:CGSizeMake(480.0, 360.0)];
        [self addFilter:sketchFilter];
        
        // pinkify
        self.pinkifyFilter = [[GPUImageFilter alloc] initWithFragmentShaderFromString:kPinkifyFragmentShaderString];
        [self addFilter:self.pinkifyFilter];
        
        GPUVector3 col = (GPUVector3) {1.0, 0.0, 1.0};
        [self.pinkifyFilter setFloatVec3:col forUniformName:@"col"];
        
        self.initialFilters = [NSArray arrayWithObject:blurFilter];
        [blurFilter addTarget:sketchFilter];
        [sketchFilter addTarget:self.pinkifyFilter];
        self.terminalFilter = self.pinkifyFilter;
    }
    return self;
}

- (void)setBeatPosition:(float)beatPosition
{
    // disable for now
    //float beatOffset = beatPosition - (int)beatPosition;
    
    //float a = (cos(0.25*M_PI*beatOffset) + 1.0) / 2.0;
    //float red = (a < 0.5) ? 1.0 : (2.0 - 2.0*a);
    //float green = 0.0;
    //float blue = (a > 0.5) ? 1.0 : (2.0*a);
    //GPUVector3 col = (GPUVector3) {red, green, blue};
    
    //[self.pinkifyFilter setFloatVec3:col forUniformName:@"col"];
}

@end
