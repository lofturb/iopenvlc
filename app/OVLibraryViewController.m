#import "OVLibraryViewController.h"
#import "OVLibrary.h"
#import "OVTheme.h"
#import "OVMediaCell.h"
#import "OVThumbnailCache.h"
#import "OVPlayerViewController.h"

@interface OVLibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegate,
                                       UICollectionViewDelegateFlowLayout, UISearchBarDelegate>

@property (nonatomic, assign) OVMediaType mediaType;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *playAllButton;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIImageView *emptyIcon;
@property (nonatomic, strong) UILabel *emptyTitle;
@property (nonatomic, strong) UILabel *emptySubtitle;
@property (nonatomic, strong) UIButton *emptyButton;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, assign) CGFloat lastLayoutWidth;

@end

@implementation OVLibraryViewController

- (instancetype)initWithMediaType:(OVMediaType)type
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mediaType = type;
        _items = @[];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [OVTheme background];
    self.title = (self.mediaType == OVMediaTypeAudio) ? @"Música" : @"Vídeos";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Ordenar"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showSortMenu)];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Buscar por título o carpeta";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.tintColor = [OVTheme orange];
    self.searchBar.barTintColor = [OVTheme background];
    self.searchBar.backgroundColor = [OVTheme background];
    self.searchBar.backgroundImage = [[UIImage alloc] init];
    [self.view addSubview:self.searchBar];

    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerView.backgroundColor = [OVTheme background];
    [self.view addSubview:self.headerView];

    self.countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.countLabel.textColor = [OVTheme secondaryText];
    self.countLabel.font = [OVTheme font:13.0 weight:UIFontWeightMedium];
    [self.headerView addSubview:self.countLabel];

    self.playAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.playAllButton setTitle:@"Reproducir todo" forState:UIControlStateNormal];
    [self.playAllButton setTitleColor:[OVTheme orange] forState:UIControlStateNormal];
    self.playAllButton.titleLabel.font = [OVTheme font:13.0 weight:UIFontWeightSemibold];
    [self.playAllButton addTarget:self action:@selector(playAll) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.playAllButton];

    self.shuffleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.shuffleButton setTitle:@"Aleatorio" forState:UIControlStateNormal];
    [self.shuffleButton setTitleColor:[OVTheme orange] forState:UIControlStateNormal];
    self.shuffleButton.titleLabel.font = [OVTheme font:13.0 weight:UIFontWeightSemibold];
    [self.shuffleButton addTarget:self action:@selector(playShuffle) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.shuffleButton];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 14.0;
    layout.minimumLineSpacing = 16.0;
    layout.sectionInset = UIEdgeInsetsMake(14.0, 16.0, 18.0, 16.0);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = [OVTheme background];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [self.collectionView registerClass:[OVMediaCell class]
            forCellWithReuseIdentifier:@"OVMediaCell"];
    [self.view addSubview:self.collectionView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [OVTheme orange];
    [self.refreshControl addTarget:self action:@selector(refreshPulled)
                  forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.collectionView addGestureRecognizer:longPress];

    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(libraryChanged)
                                                 name:OVLibraryDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scanChanged)
                                                 name:OVLibraryScanProgressNotification
                                               object:nil];
    [self reloadItems];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadItems];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)buildEmptyView
{
    self.emptyView = [[UIView alloc] initWithFrame:CGRectZero];
    self.emptyView.backgroundColor = [OVTheme background];
    [self.view addSubview:self.emptyView];

    self.emptyIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.emptyIcon.image = [OVTheme tabIcon:(self.mediaType == OVMediaTypeAudio
                                             ? OVTabIconMusic : OVTabIconVideos)];
    self.emptyIcon.tintColor = [OVTheme orange];
    self.emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:self.emptyIcon];

    self.emptyTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyTitle.textColor = [OVTheme text];
    self.emptyTitle.font = [OVTheme font:22.0 weight:UIFontWeightSemibold];
    self.emptyTitle.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:self.emptyTitle];

    self.emptySubtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptySubtitle.textColor = [OVTheme secondaryText];
    self.emptySubtitle.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    self.emptySubtitle.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitle.numberOfLines = 2;
    [self.emptyView addSubview:self.emptySubtitle];

    self.emptyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.emptyButton setTitle:@"Elegir carpeta" forState:UIControlStateNormal];
    [self.emptyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.emptyButton.backgroundColor = [OVTheme orange];
    self.emptyButton.titleLabel.font = [OVTheme font:15.0 weight:UIFontWeightSemibold];
    self.emptyButton.layer.cornerRadius = 10.0;
    [self.emptyButton addTarget:self action:@selector(openFoldersTab)
               forControlEvents:UIControlEventTouchUpInside];
    [self.emptyView addSubview:self.emptyButton];

    [self updateEmptyState];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    self.searchBar.frame = CGRectMake(6, 4, width - 12, 42);
    self.headerView.frame = CGRectMake(0, 46, width, 44);

    CGFloat buttonWidth = 108.0;
    if (width < 430) {
        buttonWidth = 96.0;
    }
    self.playAllButton.frame = CGRectMake(width - buttonWidth * 2 - 10, 9, buttonWidth, 26);
    self.shuffleButton.frame = CGRectMake(width - buttonWidth - 10, 9, buttonWidth, 26);
    self.countLabel.frame = CGRectMake(18, 11, width - buttonWidth * 2 - 44, 22);

    self.collectionView.frame = CGRectMake(0, 90, width, height - 90);
    self.emptyView.frame = self.collectionView.frame;

    CGFloat iconSize = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 74.0 : 56.0;
    self.emptyIcon.frame = CGRectMake((width - iconSize) / 2.0, height * 0.22, iconSize, iconSize);
    self.emptyTitle.frame = CGRectMake(20, height * 0.22 + iconSize + 22, width - 40, 30);
    self.emptySubtitle.frame = CGRectMake(40, height * 0.22 + iconSize + 58, width - 80, 42);
    self.emptyButton.frame = CGRectMake((width - 180) / 2.0, height * 0.22 + iconSize + 116, 180, 44);

    if (fabs(width - self.lastLayoutWidth) > 1.0) {
        self.lastLayoutWidth = width;
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
}

#pragma mark - Datos

- (void)libraryChanged
{
    [self reloadItems];
    [self.refreshControl endRefreshing];
}

- (void)scanChanged
{
    [self updateCount];
}

- (void)refreshPulled
{
    [[OVLibrary sharedLibrary] reload];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
    });
}

- (void)reloadItems
{
    NSArray *all = [[OVLibrary sharedLibrary] itemsForType:self.mediaType];
    NSString *query = [self.searchBar.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
    if (query.length > 0) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (OVMediaItem *item in all) {
            if ([item.title rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [item.folder rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:item];
            }
        }
        all = filtered;
    }
    self.items = all;
    [self.collectionView reloadData];
    [self updateCount];
    [self updateEmptyState];
}

- (void)updateCount
{
    if ([OVLibrary sharedLibrary].scanning) {
        self.countLabel.text = @"Analizando carpetas…";
        return;
    }
    if (self.items.count == 0) {
        self.countLabel.text = (self.mediaType == OVMediaTypeAudio) ? @"Sin música" : @"Sin vídeos";
        return;
    }
    NSString *unit = (self.items.count == 1)
        ? ((self.mediaType == OVMediaTypeAudio) ? @"pista" : @"vídeo")
        : ((self.mediaType == OVMediaTypeAudio) ? @"pistas" : @"vídeos");
    self.countLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)self.items.count, unit];
}

- (void)updateEmptyState
{
    BOOL empty = self.items.count == 0;
    self.emptyView.hidden = !empty;
    self.collectionView.hidden = empty;
    if (!empty) {
        return;
    }
    if ([OVLibrary sharedLibrary].scanning) {
        self.emptyTitle.text = @"Analizando carpetas…";
        self.emptySubtitle.text = @"Buscando vídeos y música en las carpetas añadidas.";
        self.emptyButton.hidden = YES;
    } else if ([OVLibrary sharedLibrary].sources.count == 0) {
        self.emptyTitle.text = (self.mediaType == OVMediaTypeAudio) ? @"Sin música todavía" : @"Sin vídeos todavía";
        self.emptySubtitle.text = @"Añade una carpeta del iPad y VLC 9 mostrará aquí todo su contenido.";
        self.emptyButton.hidden = NO;
    } else {
        self.emptyTitle.text = @"No hay archivos";
        self.emptySubtitle.text = @"Las carpetas añadidas no contienen archivos de este tipo.";
        self.emptyButton.hidden = NO;
    }
}

- (void)openFoldersTab
{
    self.tabBarController.selectedIndex = 2;
}

#pragma mark - Acciones

- (void)playItemAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.items.count) {
        return;
    }
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:self.items startIndex:index];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:player animated:YES completion:nil];
}

- (void)playAll
{
    if (self.items.count == 0) {
        [OVTheme showToast:@"No hay archivos para reproducir" inView:self.view];
        return;
    }
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:self.items startIndex:0];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:player animated:YES completion:nil];
}

- (void)playShuffle
{
    if (self.items.count == 0) {
        [OVTheme showToast:@"No hay archivos para reproducir" inView:self.view];
        return;
    }
    NSMutableArray *shuffled = [self.items mutableCopy];
    for (NSInteger i = shuffled.count - 1; i > 0; i--) {
        NSInteger j = arc4random_uniform((uint32_t)(i + 1));
        [shuffled exchangeObjectAtIndex:i withObjectAtIndex:j];
    }
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:shuffled startIndex:0];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:player animated:YES completion:nil];
}

- (void)showSortMenu
{
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Ordenar por"
                                                      inView:self.view
                                                     popover:nil];
    NSArray *titles = @[@"Nombre", @"Fecha (recientes primero)", @"Tamaño", @"Duración"];
    OVSortMode current = [OVLibrary sharedLibrary].sortMode;
    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *title = titles[i];
        if (i == current) {
            title = [@"✓  " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [OVLibrary sharedLibrary].sortMode = (OVSortMode)i;
            [self reloadItems];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint point = [gesture locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    if (!indexPath) {
        return;
    }
    OVMediaItem *item = self.items[indexPath.item];
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:item.title
                                                      inView:self.view
                                                     popover:[self.collectionView cellForItemAtIndexPath:indexPath]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Reproducir"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [self playItemAtIndex:indexPath.item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Información"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [self showInfoForItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showInfoForItem:(OVMediaItem *)item
{
    NSMutableString *message = [NSMutableString string];
    [message appendFormat:@"%@\n\n", item.path];
    [message appendFormat:@"Tipo: %@\n", item.extension.uppercaseString];
    [message appendFormat:@"Tamaño: %@\n", [OVTheme formatBytes:item.size]];
    if (item.duration > 0.0) {
        [message appendFormat:@"Duración: %@\n", [OVTheme formatTime:item.duration]];
    }
    if (item.lastPosition > 5.0) {
        [message appendFormat:@"Reanudar en: %@\n", [OVTheme formatTime:item.lastPosition]];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item.title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self reloadItems];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self reloadItems];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    OVMediaCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"OVMediaCell"
                                                                  forIndexPath:indexPath];
    OVMediaItem *item = self.items[indexPath.item];
    UIImage *placeholder = (item.type == OVMediaTypeAudio)
        ? [OVTheme musicPlaceholder] : [OVTheme videoPlaceholder];
    [cell configureWithItem:item thumbnail:placeholder];

    if (item.type == OVMediaTypeVideo && !item.isNetwork) {
        [[OVThumbnailCache sharedCache] thumbnailForItem:item completion:^(UIImage *image) {
            if (!image) {
                return;
            }
            NSIndexPath *current = [collectionView indexPathForCell:cell];
            if (current && current.item == indexPath.item) {
                [cell setThumbnail:image];
            }
        }];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = self.view.bounds.size.width;
    NSInteger columns = 2;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        columns = (width > 820.0) ? 4 : 3;
    } else if (width > 500.0) {
        columns = 3;
    }
    CGFloat itemWidth = floor((width - 32.0 - (columns - 1) * 14.0) / columns);
    CGFloat itemHeight = floor(itemWidth * 9.0 / 16.0) + 54.0;
    return CGSizeMake(itemWidth, itemHeight);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self playItemAtIndex:indexPath.item];
}

@end
