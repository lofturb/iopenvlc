#import "OVHistoryViewController.h"
#import "OVLibrary.h"
#import "OVPlayerViewController.h"
#import "OVTheme.h"

@interface OVHistoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSArray *items;

@end

@implementation OVHistoryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Historial";
    self.view.backgroundColor = [OVTheme background];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Borrar"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(confirmClear)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [OVTheme background];
    self.tableView.separatorColor = [OVTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 62, 0, 16);
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.rowHeight = 64.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:OVHistoryDidChangeNotification
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
    icon.image = [OVTheme tabIcon:OVTabIconHistory];
    icon.tintColor = [OVTheme orange];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:icon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24.0, centerY - 10.0,
                                                               width - 48.0, 30.0)];
    title.text = @"Sin historial";
    title.textColor = [OVTheme text];
    title.font = [OVTheme font:21.0 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:title];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(40.0, centerY + 26.0,
                                                                  width - 80.0, 44.0)];
    subtitle.text = @"Los vídeos y la música que reproduzcas aparecerán aquí.";
    subtitle.textColor = [OVTheme secondaryText];
    subtitle.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 2;
    [self.emptyView addSubview:subtitle];

    [self.view addSubview:self.emptyView];
}

- (void)reload
{
    self.items = [[OVLibrary sharedLibrary] historyItems];
    [self.tableView reloadData];
    self.emptyView.hidden = (self.items.count > 0);
    self.navigationItem.rightBarButtonItem.enabled = (self.items.count > 0);
}

- (void)confirmClear
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Borrar historial"
                                            message:@"¿Quieres borrar todo el historial?"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action) {
        [[OVLibrary sharedLibrary] clearHistory];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVHistoryRow";
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
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:self.items startIndex:indexPath.row];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:player animated:YES completion:nil];
}

- (NSArray *)tableView:(UITableView *)tableView
        editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak OVHistoryViewController *weakSelf = self;
    UITableViewRowAction *delete =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Quitar"
                                         handler:^(UITableViewRowAction *action,
                                                   NSIndexPath *path) {
        OVMediaItem *item = weakSelf.items[path.row];
        [[OVLibrary sharedLibrary] removeHistoryItemWithPath:item.path];
    }];
    return @[delete];
}

@end
