#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, OVTabIcon) {
    OVTabIconVideos = 0,
    OVTabIconMusic,
    OVTabIconFolders,
    OVTabIconNetwork,
    OVTabIconSettings
};

@interface OVTheme : NSObject

+ (UIColor *)background;
+ (UIColor *)surface;
+ (UIColor *)surfaceLight;
+ (UIColor *)text;
+ (UIColor *)secondaryText;
+ (UIColor *)separator;
+ (UIColor *)orange;
+ (UIColor *)red;

+ (UIFont *)font:(CGFloat)size weight:(UIFontWeight)weight;
+ (NSString *)formatTime:(double)seconds;
+ (NSString *)formatBytes:(unsigned long long)bytes;

+ (UIImage *)tabIcon:(OVTabIcon)icon;
+ (UIImage *)videoPlaceholder;
+ (UIImage *)musicPlaceholder;

+ (void)styleNavigationBar:(UINavigationBar *)bar;
+ (void)styleTableView:(UITableView *)tableView;
+ (void)showToast:(NSString *)text inView:(UIView *)view;

+ (UIAlertController *)actionSheetWithTitle:(NSString *)title
                                   inView:(UIView *)view
                                    popover:(UIView *)source;

@end
