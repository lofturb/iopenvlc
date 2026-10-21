#import <UIKit/UIKit.h>
#import "OVMediaItem.h"

@interface OVThumbnailCache : NSObject

+ (instancetype)sharedCache;
- (void)thumbnailForItem:(OVMediaItem *)item completion:(void (^)(UIImage *image))completion;
- (void)clearCache;

@end
