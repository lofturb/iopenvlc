#import "OVBrowseViewController.h"
#import "OVFolderBrowserViewController.h"
#import "OVNetworkViewController.h"
#import "OVHistoryViewController.h"
#import "OVTheme.h"

@interface OVBrowseCardCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *moreLabel;

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                      icon:(OVTabIcon)icon;

@end

@implementation OVBrowseCardCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [OVTheme surface];
        self.contentView.backgroundColor = [OVTheme surface];
        self.layer.cornerRadius = 6.0;
        self.layer.borderColor = [OVTheme separator].CGColor;
        self.layer.borderWidth = 1.0;
        self.clipsToBounds = YES;

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [OVTheme secondaryText];
        [self.contentView addSubview:_iconView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textColor = [OVTheme text];
        _titleLabel.font = [OVTheme font:14.0 weight:UIFontWeightMedium];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.textColor = [OVTheme secondaryText];
        _subtitleLabel.font = [OVTheme font:11.0 weight:UIFontWeightRegular];
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_subtitleLabel];

        _moreLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _moreLabel.text = @"⋮";
        _moreLabel.textColor = [OVTheme secondaryText];
        _moreLabel.font = [OVTheme font:16.0 weight:UIFontWeightBold];
        _moreLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_moreLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width;
    self.moreLabel.frame = CGRectMake(width - 30.0, 4.0, 24.0, 24.0);
    self.iconView.frame = CGRectMake(14.0, 16.0, 44.0, 44.0);
    self.titleLabel.frame = CGRectMake(14.0, 68.0, width - 28.0, 20.0);
    self.subtitleLabel.frame = CGRectMake(14.0, 90.0, width - 28.0, 18.0);
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                      icon:(OVTabIcon)icon
{
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    self.iconView.image = [OVTheme tabIcon:icon];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [OVTheme surfaceLight] : [OVTheme surface];
    self.contentView.backgroundColor = self.backgroundColor;
}

@end

@interface OVBrowseViewController () <UICollectionViewDataSource,
                                      UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray *sections;

@end

@implementation OVBrowseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Explorar";
    self.view.backgroundColor = [OVTheme background];
    self.navigationItem.titleView = [OVTheme brandTitleView];

    [self buildSections];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 12.0;
    layout.minimumLineSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(0.0, 16.0, 20.0, 16.0);
    layout.headerReferenceSize = CGSizeMake(self.view.bounds.size.width, 52.0);

    self.collectionView =
        [[UICollectionView alloc] initWithFrame:self.view.bounds
                            collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                           UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [OVTheme background];
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[OVBrowseCardCell class]
            forCellWithReuseIdentifier:@"OVBrowseCardCell"];
    [self.collectionView registerClass:[UICollectionReusableView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"OVBrowseHeader"];
    [self.view addSubview:self.collectionView];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (NSString *)storagePath
{
    NSString *media = @"/var/mobile/Media";
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:media isDirectory:&isDirectory] &&
        isDirectory) {
        return media;
    }
    return NSHomeDirectory();
}

- (void)buildSections
{
    NSString *media = [self storagePath];
    NSMutableArray *storage = [NSMutableArray array];
    [storage addObject:@{ @"title": @"Memoria del iPad",
                          @"subtitle": [media lastPathComponent],
                          @"icon": @(OVTabIconFolders),
                          @"kind": @"storage",
                          @"path": media }];

    NSString *documents = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [storage addObject:@{ @"title": @"Documentos",
                          @"subtitle": @"Archivos de la app",
                          @"icon": @(OVTabIconFolders),
                          @"kind": @"storage",
                          @"path": documents }];

    NSString *downloads = @"/var/mobile/Media/Downloads";
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloads isDirectory:&isDirectory] &&
        isDirectory) {
        [storage addObject:@{ @"title": @"Descargas",
                              @"subtitle": @"Media/Downloads",
                              @"icon": @(OVTabIconFolders),
                              @"kind": @"storage",
                              @"path": downloads }];
    }

    self.sections = @[
        @{ @"title": @"Almacenes", @"items": storage },
        @{ @"title": @"Red local", @"items": @[
            @{ @"title": @"Servidores UPnP",
               @"subtitle": @"Buscar en la red",
               @"icon": @(OVTabIconNetwork),
               @"kind": @"network" },
            @{ @"title": @"Dirección de red",
               @"subtitle": @"HTTP · RTSP · FTP",
               @"icon": @(OVTabIconNetwork),
               @"kind": @"network-url" }
        ] },
        @{ @"title": @"Biblioteca", @"items": @[
            @{ @"title": @"Historial",
               @"subtitle": @"Lo último que has visto",
               @"icon": @(OVTabIconHistory),
               @"kind": @"history" },
            @{ @"title": @"Listas",
               @"subtitle": @"Listas de reproducción",
               @"icon": @(OVTabIconPlaylists),
               @"kind": @"playlists" }
        ] }
    ];
}

#pragma mark - Collection

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return (NSInteger)self.sections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return [self.sections[section][@"items"] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    OVBrowseCardCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"OVBrowseCardCell"
                                                  forIndexPath:indexPath];
    NSDictionary *entry = self.sections[indexPath.section][@"items"][indexPath.item];
    [cell configureWithTitle:entry[@"title"]
                    subtitle:entry[@"subtitle"]
                        icon:(OVTabIcon)[entry[@"icon"] integerValue]];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"OVBrowseHeader"
                                                  forIndexPath:indexPath];
    UILabel *label = (UILabel *)[header viewWithTag:701];
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 14.0,
                                                          header.bounds.size.width - 32.0, 30.0)];
        label.tag = 701;
        label.textColor = [OVTheme orange];
        label.font = [OVTheme font:18.0 weight:UIFontWeightSemibold];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [header addSubview:label];
    }
    label.text = self.sections[indexPath.section][@"title"];
    return header;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = self.view.bounds.size.width;
    NSInteger columns = 2;
    if (width > 700.0) {
        columns = 4;
    } else if (width > 520.0) {
        columns = 3;
    }
    CGFloat itemWidth = floor((width - 32.0 - (columns - 1) * 12.0) / columns);
    itemWidth = MIN(itemWidth, 210.0);
    return CGSizeMake(itemWidth, 122.0);
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    NSDictionary *entry = self.sections[indexPath.section][@"items"][indexPath.item];
    NSString *kind = entry[@"kind"];

    if ([kind isEqualToString:@"storage"]) {
        OVFolderBrowserViewController *browser =
            [[OVFolderBrowserViewController alloc] initWithPath:entry[@"path"]];
        [self.navigationController pushViewController:browser animated:YES];
    } else if ([kind isEqualToString:@"network"]) {
        [self.navigationController pushViewController:[[OVNetworkViewController alloc] init]
                                             animated:YES];
    } else if ([kind isEqualToString:@"network-url"]) {
        OVNetworkViewController *network = [[OVNetworkViewController alloc] init];
        [self.navigationController pushViewController:network animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [network promptForURL];
        });
    } else if ([kind isEqualToString:@"history"]) {
        [self.navigationController pushViewController:[[OVHistoryViewController alloc] init]
                                             animated:YES];
    } else if ([kind isEqualToString:@"playlists"]) {
        if (self.tabBarController) {
            self.tabBarController.selectedIndex = 3;
        }
    }
}

@end
