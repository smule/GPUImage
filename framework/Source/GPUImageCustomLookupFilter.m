//
//  GPUImageCustomLookupFilter.m
//  Pods
//
//  Created by Michael Harville on 3/27/15.
//
//

#import "GPUImageCustomLookupFilter.h"
#import "GPUImagePicture.h"
#import "GPUImageLookupFilter.h"

@implementation GPUImageCustomLookupFilter

- (id)initWithImageNamed:(NSString *)name
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    UIImage *image = [UIImage imageNamed:name];
#else
    NSImage *image = [NSImage imageNamed:name];
#endif
    
    NSAssert(image, @"To use GPUImageMissEtikateFilter you need to add lookup_miss_etikate.png from GPUImage/framework/Resources to your application bundle.");
    
    lookupImageSource = [[GPUImagePicture alloc] initWithImage:image];
    GPUImageLookupFilter *lookupFilter = [[GPUImageLookupFilter alloc] init];
    [self addFilter:lookupFilter];
    
    [lookupImageSource addTarget:lookupFilter atTextureLocation:1];
    [lookupImageSource processImage];
    
    self.initialFilters = [NSArray arrayWithObjects:lookupFilter, nil];
    self.terminalFilter = lookupFilter;
    
    return self;
}

- (id)initWithGPUImagePicture:(GPUImagePicture *)picture
{
    if (!(self = [super init]))
    {
        return nil;
    }

    GPUImageLookupFilter *lookupFilter = [[GPUImageLookupFilter alloc] init];
    [self addFilter:lookupFilter];

    lookupImageSource = picture;
    [lookupImageSource addTarget:lookupFilter atTextureLocation:1];
    [lookupImageSource processImage];

    self.initialFilters = [NSArray arrayWithObjects:lookupFilter, nil];
    self.terminalFilter = lookupFilter;

    return self;
}

@end
