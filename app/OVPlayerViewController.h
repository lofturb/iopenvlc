#import <UIKit/UIKit.h>

@class OVMediaItem;

@interface OVPlayerViewController : UIViewController

/// Items can be local files or network URLs wrapped in OVMediaItem.
- (instancetype)initWithItems:(NSArray *)items startIndex:(NSInteger)startIndex;

@end
