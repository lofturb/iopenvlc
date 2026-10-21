#import <UIKit/UIKit.h>

@interface OVPlaylistViewController : UIViewController

@property (nonatomic, copy) void (^selectionHandler)(NSInteger index);

- (instancetype)initWithItems:(NSArray *)items currentIndex:(NSInteger)currentIndex;

@end
