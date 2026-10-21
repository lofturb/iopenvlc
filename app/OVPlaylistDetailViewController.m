#import "OVPlaylistDetailViewController.h"
#import "OVPlaylistStore.h"
#import "OVPlayerViewController.h"
#import "OVTheme.h"

@interface OVPlaylistDetailViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, assign) NSInteger playlistIndex;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSArray *items;

@end

@implementation OVPlaylistDetailViewController

- (instancetype)initWithPlaylistIndex:(NSInteger)index
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _playlistIndex = index;
        _items = @[];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [OVTheme background];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[OVTheme barIcon:OVBarIconPlay]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(playAll)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [OVTheme background];
    self.tableView.separatorColor = [OVTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 62, 0, 16);
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.rowHeight = 62.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    [self buildHeader];
    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storeChanged)
                                                 name:OVPlaylistsDidChangeNotification
                                               object:nil];
    [self reload];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reload];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)buildHeader
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                              self.view.bounds.size.width, 56.0)];
    header.backgroundColor = [OVTheme background];

    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.frame = CGRectMake(16.0, 8.0, 170.0, 40.0);
    [play setTitle:@"Reproducir todo" forState:UIControlStateNormal];
    [play setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    play.titleLabel.font = [OVTheme font:14.0 weight:UIFontWeightSemibold];
    play.backgroundColor = [OVTheme orange];
    play.layer.cornerRadius = 4.0;
    [play addTarget:self action:@selector(playAll)
   forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:play];

    UIButton *shuffle = [UIButton buttonWithType:UIButtonTypeSystem];
    shuffle.frame = CGRectMake(196.0, 8.0, 120.0, 40.0);
    [shuffle setTitle:@"Aleatorio" forState:UIControlStateNormal];
    [shuffle setTitleColor:[OVTheme orange] forState:UIControlStateNormal];
    shuffle.titleLabel.font = [OVTheme font:14.0 weight:UIFontWeightSemibold];
    [shuffle addTarget:self action:@selector(playShuffle)
      forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:shuffle];

    self.tableView.tableHeaderView = header;
}

- (void)buildEmptyView
{
    self.emptyView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.emptyView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.emptyView.backgroundColor = [OVTheme background];

    CGFloat width = self.view.bounds.size.width;
    CGFloat centerY = self.view.bounds.size.height * 0.40;

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake((width - 58.0) / 2.0,
                                                                     centerY - 84.0, 58.0, 58.0)];
    icon.image = [OVTheme tabIcon:OVTabIconPlaylists];
    icon.tintColor = [OVTheme orange];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:icon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24.0, centerY - 10.0,
                                                               width - 48.0, 30.0)];
    title.text = @"Esta lista está vacía";
    title.textColor = [OVTheme text];
    title.font = [OVTheme font:21.0 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:title];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(40.0, centerY + 26.0,
                                                                  width - 80.0, 46.0)];
    subtitle.text = @"Mantén pulsado un vídeo o una canción en la biblioteca y elige "
                    @"«Añadir a lista».";
    subtitle.textColor = [OVTheme secondaryText];
    subtitle.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 2;
    [self.emptyView addSubview:subtitle];

    [self.view addSubview:self.emptyView];
}

- (void)storeChanged
{
    [self reload];
}

- (void)reload
{
    NSString *name = [[OVPlaylistStore sharedStore] nameForPlaylistAtIndex:self.playlistIndex];
    self.title = name.length > 0 ? name : @"Lista";
    self.items = [[OVPlaylistStore sharedStore] mediaItemsForPlaylistAtIndex:self.playlistIndex];
    [self.tableView reloadData];
    self.emptyView.hidden = (self.items.count > 0);
    self.navigationItem.rightBarButtonItem.enabled = (self.items.count > 0);
}

#pragma mark - Reproducción

- (void)playFromIndex:(NSInteger)index
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
    [self playFromIndex:0];
}

- (void)playShuffle
{
    if (self.items.count == 0) {
        [OVTheme showToast:@"Esta lista está vacía" inView:self.view];
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

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVPlaylistItemRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme background];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
    }

    OVMediaItem *item = self.items[indexPath.row];
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = [item subtitleText];
    cell.imageView.image = [OVTheme tabIcon:(item.type == OVMediaTypeAudio
                                           ? OVTabIconMusic : OVTabIconVideos)];
    cell.imageView.tintColor = [OVTheme secondaryText];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self playFromIndex:indexPath.row];
}

- (NSArray *)tableView:(UITableView *)tableView
        editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak OVPlaylistDetailViewController *weakSelf = self;
    UITableViewRowAction *delete =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Quitar"
                                         handler:^(UITableViewRowAction *action,
                                                   NSIndexPath *path) {
        [[OVPlaylistStore sharedStore] removeItemAtIndex:path.row
                                     fromPlaylistAtIndex:weakSelf.playlistIndex];
        [weakSelf reload];
    }];
    return @[delete];
}

@end
