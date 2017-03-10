//
//  ScaleFilter.h
//  Pods
//
//  Created by Solomon Garber on 3/6/17.
//
//

//#ifndef ScaleFilter_h
//#define ScaleFilter_h


//#endif /* ScaleFilter_h */

#import "GPUImageFilter.h"

// Performs a vignetting effect, fading out the image at the edges

@interface ScaleFilter : GPUImageFilter
{
    //GLint redCenterUniform, redPhaseUniform;
    GLint scaleUniform;
}

// The normalized distance from the center where the vignette effect starts. Default of 0.5.
@property (nonatomic, readwrite) CGPoint scale;


-(void)setScale:(CGPoint)scale;

@end
