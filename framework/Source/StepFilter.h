//
//  StepFilter.h
//  GPUImage
//
//  Created by Solomon Garber on 7/20/16.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

//#ifndef StepFilter_h
//#define StepFilter_h


//#endif /* StepFilter_h */

#import "GPUImageFilter.h"

/** Adjusts the contrast of the image
 */
@interface StepFilter : GPUImageFilter
{
    GLint edgeOneUniform,edgeTwoUniform;
}

/** Contrast ranges from 0.0 to 4.0 (max contrast), with 1.0 as the normal level
 */
@property(readwrite, nonatomic) CGFloat edgeOne;

@property(readwrite, nonatomic) CGFloat edgeTwo;

@end
