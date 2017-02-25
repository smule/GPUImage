//
//  IndexingFilter.h
//  GPUImage
//
//  Created by Solomon Garber on 8/4/16.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

//#ifndef IndexingFilter_h
//#define IndexingFilter_h


//#endif /* IndexingFilter_h */

#import "GPUImageFilter.h"

// Performs a vignetting effect, fading out the image at the edges
 
@interface IndexingFilter : GPUImageFilter
{
    //GLint redCenterUniform, redPhaseUniform;
    GLint redCenterUniform, greenCenterUniform, blueCenterUniform, redScaleUniform, greenScaleUniform, blueScaleUniform, redShiftUniform, greenShiftUniform, blueShiftUniform, redPhaseUniform, greenPhaseUniform, bluePhaseUniform, aspectRatioUniform;
}

// the center for the vignette in tex coords (defaults to 0.5, 0.5)
@property (nonatomic, readwrite) CGPoint redCenter;

// The color to use for the Vignette (defaults to black)
@property (nonatomic, readwrite) CGPoint greenCenter;

// The normalized distance from the center where the vignette effect starts. Default of 0.5.
@property (nonatomic, readwrite) CGPoint blueCenter;


@property (nonatomic, readwrite) CGPoint redScale;

// The color to use for the Vignette (defaults to black)
@property (nonatomic, readwrite) CGPoint greenScale;

// The normalized distance from the center where the vignette effect starts. Default of 0.5.
@property (nonatomic, readwrite) CGPoint blueScale;


@property (nonatomic, readwrite) CGPoint redShift;

// The color to use for the Vignette (defaults to black)
@property (nonatomic, readwrite) CGPoint greenShift;

// The normalized distance from the center where the vignette effect starts. Default of 0.5.
@property (nonatomic, readwrite) CGPoint blueShift;


// The normalized distance from the center where the vignette effect ends. Default of 0.75.
@property (nonatomic, readwrite) CGFloat redPhase;

// The normalized distance from the center where the vignette effect ends. Default of 0.75.
@property (nonatomic, readwrite) CGFloat greenPhase;

// The normalized distance from the center where the vignette effect ends. Default of 0.75.
@property (nonatomic, readwrite) CGFloat bluePhase;

-(void)setCenter:(CGPoint)center;

-(void)setScale:(CGPoint)scale;

-(void)setShift:(CGPoint)shift;

-(void)setPhase:(CGFloat)phase;
 
@end


/*
#import "GPUImageFilter.h"

//Performs a vignetting effect, fading out the image at the edges
 
@interface IndexingFilter : GPUImageFilter
{
    GLint indexingCenterUniform, indexingColorUniform, indexingStartUniform, indexingEndUniform;
}

// the center for the vignette in tex coords (defaults to 0.5, 0.5)
@property (nonatomic, readwrite) CGPoint indexingCenter;

// The color to use for the Vignette (defaults to black)
@property (nonatomic, readwrite) GPUVector3 indexingColor;

// The normalized distance from the center where the vignette effect starts. Default of 0.5.
@property (nonatomic, readwrite) CGFloat indexingStart;

// The normalized distance from the center where the vignette effect ends. Default of 0.75.
@property (nonatomic, readwrite) CGFloat indexingEnd;

-(void)setEverything:(CGRect)faceRect;
@end
 */
