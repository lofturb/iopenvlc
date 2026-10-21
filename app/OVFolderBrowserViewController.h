#import <UIKit/UIKit.h>

@interface OVFolderBrowserViewController : UIViewController

- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithPath:(NSString *)path
          subtitleCompletion:(void (^)(NSString *path))completion;

@end
