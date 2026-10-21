#import <UIKit/UIKit.h>
#import "OVMediaItem.h"

@interface OVMediaCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;

- (void)configureWithItem:(OVMediaItem *)item thumbnail:(UIImage *)thumbnail;
- (void)setThumbnail:(UIImage *)thumbnail;

@end
