//
//  GPUImageCustomLookupFilter.h
//  Pods
//
//  Created by Michael Harville on 3/27/15.
//
//

#import "GPUImageFilterGroup.h"

@class GPUImagePicture;

@interface GPUImageCustomLookupFilter : GPUImageFilterGroup
{
    GPUImagePicture *lookupImageSource;
}

- (id)initWithImageNamed:(NSString*)name;
- (id)initWithGPUImagePicture:(GPUImagePicture *)picture;

@end
