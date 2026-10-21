#import "OVMediaCell.h"
#import "OVTheme.h"

@interface OVMediaCell ()

@property (nonatomic, assign) CGFloat progressRatio;

@end

@implementation OVMediaCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [OVTheme surface];
        self.contentView.backgroundColor = [OVTheme surface];
        self.contentView.clipsToBounds = YES;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 12.0;

        _thumbnailView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailView.clipsToBounds = YES;
        _thumbnailView.backgroundColor = [OVTheme surfaceLight];
        [self.contentView addSubview:_thumbnailView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textColor = [OVTheme text];
        _titleLabel.font = [OVTheme font:14.0 weight:UIFontWeightSemibold];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.textColor = [OVTheme secondaryText];
        _subtitleLabel.font = [OVTheme font:11.5 weight:UIFontWeightRegular];
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_subtitleLabel];

        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
        _badgeLabel.font = [OVTheme font:11.0 weight:UIFontWeightSemibold];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.cornerRadius = 4.0;
        _badgeLabel.clipsToBounds = YES;
        [self.contentView addSubview:_badgeLabel];

        _progressTrack = [[UIView alloc] initWithFrame:CGRectZero];
        _progressTrack.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        _progressTrack.hidden = YES;
        [self.contentView addSubview:_progressTrack];

        _progressFill = [[UIView alloc] initWithFrame:CGRectZero];
        _progressFill.backgroundColor = [OVTheme orange];
        [_progressTrack addSubview:_progressFill];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width;
    CGFloat imageHeight = floor(width * 9.0 / 16.0);

    self.thumbnailView.frame = CGRectMake(0, 0, width, imageHeight);
    self.titleLabel.frame = CGRectMake(10, imageHeight + 8, width - 20, 19);
    self.subtitleLabel.frame = CGRectMake(10, imageHeight + 28, width - 20, 16);

    CGSize badge = [self.badgeLabel sizeThatFits:CGSizeMake(120, 20)];
    CGFloat badgeWidth = MAX(38.0, badge.width + 10.0);
    self.badgeLabel.frame = CGRectMake(width - badgeWidth - 8, imageHeight - 25, badgeWidth, 17);

    self.progressTrack.frame = CGRectMake(0, imageHeight - 3, width, 3);
    self.progressFill.frame = CGRectMake(0, 0,
                                         floor(width * self.progressRatio), 3);
}

- (void)configureWithItem:(OVMediaItem *)item thumbnail:(UIImage *)thumbnail
{
    self.titleLabel.text = item.title.length > 0 ? item.title : item.path.lastPathComponent;
    self.subtitleLabel.text = [item subtitleText];
    self.badgeLabel.text = item.duration > 0.0 ? [OVTheme formatTime:item.duration] : @"";
    self.badgeLabel.hidden = item.duration <= 0.0 || item.isNetwork;
    [self setThumbnail:thumbnail];

    if (item.duration > 0.0 && item.lastPosition > 5.0) {
        self.progressTrack.hidden = NO;
        self.progressRatio = MIN(1.0, item.lastPosition / item.duration);
        [self setNeedsLayout];
    } else {
        self.progressTrack.hidden = YES;
        self.progressRatio = 0.0;
        self.progressFill.frame = CGRectZero;
    }
}

- (void)setThumbnail:(UIImage *)thumbnail
{
    if (thumbnail) {
        self.thumbnailView.image = thumbnail;
    } else {
        self.thumbnailView.image = nil;
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.thumbnailView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.badgeLabel.text = nil;
    self.progressTrack.hidden = YES;
    self.progressFill.frame = CGRectZero;
    self.progressRatio = 0.0;
    self.transform = CGAffineTransformIdentity;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.97, 0.97)
                                     : CGAffineTransformIdentity;
    }];
}

@end
