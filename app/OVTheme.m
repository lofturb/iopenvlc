#import "OVTheme.h"
#import <math.h>

@implementation OVTheme

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

// Paleta de VLC para Android (tema oscuro): fondo #131313, barras #121212,
// tarjetas #1E1E1E y naranja VLC #FF8800.
+ (UIColor *)background { return [self colorWithHex:0x131313 alpha:1.0]; }
+ (UIColor *)surface { return [self colorWithHex:0x1E1E1E alpha:1.0]; }
+ (UIColor *)surfaceLight { return [self colorWithHex:0x2A2A2A alpha:1.0]; }
+ (UIColor *)navBackground { return [self colorWithHex:0x121212 alpha:1.0]; }
+ (UIColor *)text { return [self colorWithHex:0xFAFAFA alpha:1.0]; }
+ (UIColor *)secondaryText { return [self colorWithHex:0x9E9E9E alpha:1.0]; }
+ (UIColor *)separator { return [self colorWithHex:0x2A2A2A alpha:1.0]; }
+ (UIColor *)orange { return [self colorWithHex:0xFF8800 alpha:1.0]; }
+ (UIColor *)red { return [self colorWithHex:0xFF453A alpha:1.0]; }

+ (UIFont *)font:(CGFloat)size weight:(CGFloat)weight
{
    return [UIFont systemFontOfSize:size weight:weight];
}

+ (NSString *)formatTime:(double)seconds
{
    if (seconds < 0 || !isfinite(seconds)) {
        return @"--:--";
    }
    int total = (int)floor(seconds + 0.5);
    int h = total / 3600;
    int m = (total % 3600) / 60;
    int s = total % 60;
    if (h > 0) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", h, m, s];
    }
    return [NSString stringWithFormat:@"%02d:%02d", m, s];
}

+ (NSString *)formatBytes:(unsigned long long)bytes
{
    if (bytes >= 1024ULL * 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL) {
        return [NSString stringWithFormat:@"%.0f KB", bytes / 1024.0];
    }
    return [NSString stringWithFormat:@"%llu B", bytes];
}

+ (UIImage *)tabIcon:(OVTabIcon)icon
{
    CGSize size = CGSizeMake(25.0, 25.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *black = [UIColor blackColor];
    CGContextSetFillColorWithColor(ctx, black.CGColor);
    CGContextSetStrokeColorWithColor(ctx, black.CGColor);
    CGContextSetLineWidth(ctx, 1.7);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if (icon == OVTabIconVideos) {
        UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.5, 4.0, 20.0, 17.0)
                                                             cornerRadius:3.0];
        [frame stroke];
        CGContextMoveToPoint(ctx, 10.2, 8.4);
        CGContextAddLineToPoint(ctx, 10.2, 16.6);
        CGContextAddLineToPoint(ctx, 17.0, 12.5);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    } else if (icon == OVTabIconMusic) {
        CGContextFillEllipseInRect(ctx, CGRectMake(4.5, 15.0, 7.0, 6.0));
        CGContextFillRect(ctx, CGRectMake(10.0, 5.0, 1.8, 12.0));
        CGContextMoveToPoint(ctx, 11.8, 5.0);
        CGContextAddCurveToPoint(ctx, 15.0, 6.2, 19.0, 7.2, 19.0, 11.0);
        CGContextAddCurveToPoint(ctx, 19.0, 12.8, 17.8, 13.6, 16.4, 13.6);
        CGContextAddCurveToPoint(ctx, 16.4, 10.2, 14.2, 8.2, 11.8, 7.8);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    } else if (icon == OVTabIconFolders) {
        UIBezierPath *folder = [UIBezierPath bezierPath];
        [folder moveToPoint:CGPointMake(2.5, 7.5)];
        [folder addLineToPoint:CGPointMake(2.5, 20.0)];
        [folder addLineToPoint:CGPointMake(22.5, 20.0)];
        [folder addLineToPoint:CGPointMake(22.5, 8.5)];
        [folder addLineToPoint:CGPointMake(12.0, 8.5)];
        [folder addLineToPoint:CGPointMake(10.0, 5.0)];
        [folder addLineToPoint:CGPointMake(2.5, 5.0)];
        [folder closePath];
        [folder stroke];
    } else if (icon == OVTabIconNetwork) {
        CGContextStrokeEllipseInRect(ctx, CGRectMake(2.5, 2.5, 20.0, 20.0));
        CGContextStrokeEllipseInRect(ctx, CGRectMake(8.0, 2.5, 9.0, 20.0));
        CGContextMoveToPoint(ctx, 2.5, 12.5);
        CGContextAddLineToPoint(ctx, 22.5, 12.5);
        CGContextStrokePath(ctx);
    } else if (icon == OVTabIconPlaylists) {
        CGContextMoveToPoint(ctx, 3.0, 7.0);
        CGContextAddLineToPoint(ctx, 14.0, 7.0);
        CGContextMoveToPoint(ctx, 3.0, 12.5);
        CGContextAddLineToPoint(ctx, 14.0, 12.5);
        CGContextMoveToPoint(ctx, 3.0, 18.0);
        CGContextAddLineToPoint(ctx, 14.0, 18.0);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 15.5, 7.8);
        CGContextAddLineToPoint(ctx, 15.5, 17.2);
        CGContextAddLineToPoint(ctx, 22.0, 12.5);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    } else if (icon == OVTabIconMore) {
        CGContextFillEllipseInRect(ctx, CGRectMake(3.2, 10.6, 4.0, 4.0));
        CGContextFillEllipseInRect(ctx, CGRectMake(10.5, 10.6, 4.0, 4.0));
        CGContextFillEllipseInRect(ctx, CGRectMake(17.8, 10.6, 4.0, 4.0));
    } else if (icon == OVTabIconHistory) {
        CGContextStrokeEllipseInRect(ctx, CGRectMake(3.0, 3.0, 19.0, 19.0));
        CGContextMoveToPoint(ctx, 12.5, 7.0);
        CGContextAddLineToPoint(ctx, 12.5, 13.0);
        CGContextAddLineToPoint(ctx, 17.0, 15.5);
        CGContextStrokePath(ctx);
    } else {
        CGContextMoveToPoint(ctx, 3.0, 7.0);
        CGContextAddLineToPoint(ctx, 22.0, 7.0);
        CGContextMoveToPoint(ctx, 3.0, 12.5);
        CGContextAddLineToPoint(ctx, 22.0, 12.5);
        CGContextMoveToPoint(ctx, 3.0, 18.0);
        CGContextAddLineToPoint(ctx, 22.0, 18.0);
        CGContextStrokePath(ctx);
        CGContextFillEllipseInRect(ctx, CGRectMake(6.0, 4.8, 4.4, 4.4));
        CGContextFillEllipseInRect(ctx, CGRectMake(14.5, 10.3, 4.4, 4.4));
        CGContextFillEllipseInRect(ctx, CGRectMake(8.5, 15.8, 4.4, 4.4));
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)barIcon:(OVBarIcon)icon
{
    CGSize size = CGSizeMake(24.0, 24.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *black = [UIColor blackColor];
    CGContextSetFillColorWithColor(ctx, black.CGColor);
    CGContextSetStrokeColorWithColor(ctx, black.CGColor);
    CGContextSetLineWidth(ctx, 1.9);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if (icon == OVBarIconSearch) {
        CGContextStrokeEllipseInRect(ctx, CGRectMake(3.0, 3.0, 13.0, 13.0));
        CGContextMoveToPoint(ctx, 15.0, 15.0);
        CGContextAddLineToPoint(ctx, 21.0, 21.0);
        CGContextStrokePath(ctx);
    } else if (icon == OVBarIconSort) {
        CGContextMoveToPoint(ctx, 3.0, 6.0);
        CGContextAddLineToPoint(ctx, 18.0, 6.0);
        CGContextMoveToPoint(ctx, 3.0, 12.0);
        CGContextAddLineToPoint(ctx, 14.0, 12.0);
        CGContextMoveToPoint(ctx, 3.0, 18.0);
        CGContextAddLineToPoint(ctx, 10.0, 18.0);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 18.0, 15.0);
        CGContextAddLineToPoint(ctx, 21.0, 18.0);
        CGContextAddLineToPoint(ctx, 18.0, 21.0);
        CGContextStrokePath(ctx);
    } else if (icon == OVBarIconMore) {
        CGContextFillEllipseInRect(ctx, CGRectMake(10.2, 3.4, 3.6, 3.6));
        CGContextFillEllipseInRect(ctx, CGRectMake(10.2, 10.2, 3.6, 3.6));
        CGContextFillEllipseInRect(ctx, CGRectMake(10.2, 17.0, 3.6, 3.6));
    } else if (icon == OVBarIconAdd) {
        CGContextMoveToPoint(ctx, 12.0, 4.0);
        CGContextAddLineToPoint(ctx, 12.0, 20.0);
        CGContextMoveToPoint(ctx, 4.0, 12.0);
        CGContextAddLineToPoint(ctx, 20.0, 12.0);
        CGContextStrokePath(ctx);
    } else if (icon == OVBarIconGrid) {
        UIBezierPath *a = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.0, 3.0, 8.0, 8.0) cornerRadius:1.5];
        UIBezierPath *b = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(13.0, 3.0, 8.0, 8.0) cornerRadius:1.5];
        UIBezierPath *c = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.0, 13.0, 8.0, 8.0) cornerRadius:1.5];
        UIBezierPath *d = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(13.0, 13.0, 8.0, 8.0) cornerRadius:1.5];
        [a fill]; [b fill]; [c fill]; [d fill];
    } else if (icon == OVBarIconList) {
        CGContextMoveToPoint(ctx, 7.0, 6.0);
        CGContextAddLineToPoint(ctx, 21.0, 6.0);
        CGContextMoveToPoint(ctx, 7.0, 12.0);
        CGContextAddLineToPoint(ctx, 21.0, 12.0);
        CGContextMoveToPoint(ctx, 7.0, 18.0);
        CGContextAddLineToPoint(ctx, 21.0, 18.0);
        CGContextStrokePath(ctx);
        CGContextFillEllipseInRect(ctx, CGRectMake(2.5, 4.5, 3.0, 3.0));
        CGContextFillEllipseInRect(ctx, CGRectMake(2.5, 10.5, 3.0, 3.0));
        CGContextFillEllipseInRect(ctx, CGRectMake(2.5, 16.5, 3.0, 3.0));
    } else if (icon == OVBarIconPlay) {
        CGContextMoveToPoint(ctx, 7.0, 4.5);
        CGContextAddLineToPoint(ctx, 7.0, 19.5);
        CGContextAddLineToPoint(ctx, 20.0, 12.0);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    } else if (icon == OVBarIconSettings) {
        CGContextMoveToPoint(ctx, 3.0, 7.0);
        CGContextAddLineToPoint(ctx, 21.0, 7.0);
        CGContextMoveToPoint(ctx, 3.0, 17.0);
        CGContextAddLineToPoint(ctx, 21.0, 17.0);
        CGContextStrokePath(ctx);
        CGContextFillEllipseInRect(ctx, CGRectMake(6.0, 4.5, 5.0, 5.0));
        CGContextFillEllipseInRect(ctx, CGRectMake(13.0, 14.5, 5.0, 5.0));
    } else {
        CGContextStrokeEllipseInRect(ctx, CGRectMake(3.0, 3.0, 18.0, 18.0));
        CGContextFillEllipseInRect(ctx, CGRectMake(10.6, 9.5, 2.8, 2.8));
        CGContextFillRect(ctx, CGRectMake(10.6, 13.5, 2.8, 6.0));
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)vlcCone:(CGFloat)size
{
    if (size <= 0.0) {
        return nil;
    }
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIBezierPath *cone = [UIBezierPath bezierPath];
    [cone moveToPoint:CGPointMake(size * 0.50, size * 0.06)];
    [cone addLineToPoint:CGPointMake(size * 0.63, size * 0.34)];
    [cone addLineToPoint:CGPointMake(size * 0.84, size * 0.80)];
    [cone addQuadCurveToPoint:CGPointMake(size * 0.77, size * 0.91)
                controlPoint:CGPointMake(size * 0.84, size * 0.90)];
    [cone addLineToPoint:CGPointMake(size * 0.23, size * 0.91)];
    [cone addQuadCurveToPoint:CGPointMake(size * 0.16, size * 0.80)
                controlPoint:CGPointMake(size * 0.16, size * 0.90)];
    [cone addLineToPoint:CGPointMake(size * 0.37, size * 0.34)];
    [cone closePath];
    [[self orange] setFill];
    [cone fill];

    CGContextSaveGState(ctx);
    [cone addClip];
    [[self colorWithHex:0xFFF3E0 alpha:0.92] setFill];
    CGContextFillRect(ctx, CGRectMake(0.0, size * 0.40, size, size * 0.10));
    CGContextFillRect(ctx, CGRectMake(0.0, size * 0.58, size, size * 0.08));
    CGContextRestoreGState(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIView *)brandTitleView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 108.0, 34.0)];
    view.backgroundColor = [UIColor clearColor];

    UIImageView *logo = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 4.0, 26.0, 26.0)];
    logo.image = [self vlcCone:26.0];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    [view addSubview:logo];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(32.0, 0.0, 72.0, 34.0)];
    label.text = @"VLC";
    label.textColor = [self orange];
    label.font = [self font:20.0 weight:UIFontWeightBold];
    [view addSubview:label];
    return view;
}

+ (UIImage *)placeholderWithSymbol:(NSString *)symbol
{
    CGSize size = CGSizeMake(400.0, 225.0);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(ctx, [self surface].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));

    CGContextSetStrokeColorWithColor(ctx, [[self secondaryText] colorWithAlphaComponent:0.55].CGColor);
    CGContextSetLineWidth(ctx, 8.0);
    CGContextSetLineCap(ctx, kCGLineCapRound);

    if ([symbol isEqualToString:@"music"]) {
        CGContextSetFillColorWithColor(ctx, [[self secondaryText] colorWithAlphaComponent:0.55].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(150, 120, 52, 42));
        CGContextFillRect(ctx, CGRectMake(192, 65, 12, 90));
        CGContextMoveToPoint(ctx, 204, 65);
        CGContextAddCurveToPoint(ctx, 226, 72, 250, 82, 250, 108);
        CGContextAddCurveToPoint(ctx, 250, 122, 240, 128, 230, 128);
        CGContextAddCurveToPoint(ctx, 230, 104, 218, 92, 204, 88);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    } else {
        UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(135, 55, 130, 110)
                                                             cornerRadius:14.0];
        [frame stroke];
        CGContextMoveToPoint(ctx, 185, 85);
        CGContextAddLineToPoint(ctx, 185, 135);
        CGContextAddLineToPoint(ctx, 225, 110);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)videoPlaceholder { return [self placeholderWithSymbol:@"video"]; }
+ (UIImage *)musicPlaceholder { return [self placeholderWithSymbol:@"music"]; }

+ (void)styleNavigationBar:(UINavigationBar *)bar
{
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    bar.barTintColor = [self navBackground];
    bar.tintColor = [self orange];
    bar.titleTextAttributes = @{
        NSForegroundColorAttributeName: [self text],
        NSFontAttributeName: [self font:17.0 weight:UIFontWeightSemibold]
    };
    if ([bar respondsToSelector:@selector(setShadowImage:)]) {
        bar.shadowImage = [[UIImage alloc] init];
    }
}

+ (void)styleTableView:(UITableView *)tableView
{
    tableView.backgroundColor = [self background];
    tableView.separatorColor = [self separator];
    tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    tableView.rowHeight = 54.0;
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

+ (void)showToast:(NSString *)text inView:(UIView *)view
{
    if (!view || text.length == 0) {
        return;
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = [self text];
    label.font = [self font:14.0 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.88];
    label.layer.cornerRadius = 12.0;
    label.clipsToBounds = YES;

    CGSize maxSize = CGSizeMake(view.bounds.size.width - 80.0, 90.0);
    CGSize fitted = [label sizeThatFits:maxSize];
    CGFloat width = MAX(120.0, MIN(maxSize.width, fitted.width + 34.0));
    CGFloat height = MAX(42.0, MIN(maxSize.height, fitted.height + 20.0));
    label.frame = CGRectMake(floor((view.bounds.size.width - width) / 2.0),
                             floor(view.bounds.size.height - height - 90.0),
                             width, height);
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleRightMargin |
                             UIViewAutoresizingFlexibleTopMargin;
    label.alpha = 0.0;
    [view addSubview:label];

    [UIView animateWithDuration:0.18 animations:^{
        label.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:1.8 options:0 animations:^{
            label.alpha = 0.0;
        } completion:^(BOOL done) {
            [label removeFromSuperview];
        }];
    }];
}

+ (UIAlertController *)actionSheetWithTitle:(NSString *)title
                                     inView:(UIView *)view
                                    popover:(UIView *)source
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = source ?: view;
        CGRect rect = source ? source.bounds : CGRectMake(view.bounds.size.width / 2.0,
                                                          view.bounds.size.height / 2.0, 1, 1);
        sheet.popoverPresentationController.sourceRect = rect;
        sheet.popoverPresentationController.permittedArrowDirections = 0;
        sheet.popoverPresentationController.backgroundColor = [self surface];
    }
    return sheet;
}

@end
