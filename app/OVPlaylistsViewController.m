#import "OVPlaylistsViewController.h"
#import "OVPlaylistStore.h"
#import "OVPlaylistDetailViewController.h"
#import "OVTheme.h"

@interface OVPlaylistsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;

@end

@implementation OVPlaylistsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Listas";
    self.view.backgroundColor = [OVTheme background];
    self.navigationItem.titleView = [OVTheme brandTitleView];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[OVTheme barIcon:OVBarIconAdd]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(createPlaylist)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [OVTheme background];
    self.tableView.separatorColor = [OVTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 72, 0, 16);
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.rowHeight = 68.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playlistsChanged)
                                                 name:OVPlaylistsDidChangeNotification
                                               object:nil];
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
    [self.view addSubview:self.emptyView];

    CGFloat width = self.view.bounds.size.width;
    CGFloat centerY = self.view.bounds.size.height * 0.40;

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake((width - 64.0) / 2.0,
                                                                     centerY - 92.0, 64.0, 64.0)];
    icon.image = [OVTheme tabIcon:OVTabIconPlaylists];
    icon.tintColor = [OVTheme orange];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                            UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin;
    [self.emptyView addSubview:icon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24.0, centerY - 14.0,
                                                               width - 48.0, 30.0)];
    title.text = @"No hay listas";
    title.textColor = [OVTheme text];
    title.font = [OVTheme font:22.0 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:title];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(40.0, centerY + 22.0,
                                                                  width - 80.0, 44.0)];
    subtitle.text = @"Crea una lista y añade vídeos o música desde la biblioteca.";
    subtitle.textColor = [OVTheme secondaryText];
    subtitle.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 2;
    [self.emptyView addSubview:subtitle];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake((width - 190.0) / 2.0, centerY + 82.0, 190.0, 46.0);
    [button setTitle:@"Crear lista" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [OVTheme font:15.0 weight:UIFontWeightSemibold];
    button.backgroundColor = [OVTheme orange];
    button.layer.cornerRadius = 4.0;
    [button addTarget:self action:@selector(createPlaylist)
     forControlEvents:UIControlEventTouchUpInside];
    [self.emptyView addSubview:button];
}

- (void)playlistsChanged
{
    [self reload];
}

- (void)reload
{
    [self.tableView reloadData];
    self.emptyView.hidden = ([OVPlaylistStore sharedStore].count > 0);
}

#pragma mark - Acciones

- (void)createPlaylist
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Nueva lista"
                                            message:@"Ponle un nombre a la lista."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Nombre de la lista";
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Crear"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        [[OVPlaylistStore sharedStore] createPlaylistWithName:name];
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)renamePlaylistAtIndex:(NSInteger)index
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Renombrar lista"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [[OVPlaylistStore sharedStore] nameForPlaylistAtIndex:index];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Guardar"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [[OVPlaylistStore sharedStore] renamePlaylistAtIndex:index
                                                       name:alert.textFields.firstObject.text];
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmDeletePlaylistAtIndex:(NSInteger)index
{
    NSString *name = [[OVPlaylistStore sharedStore] nameForPlaylistAtIndex:index];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Borrar lista"
                                            message:[NSString stringWithFormat:
                                                     @"¿Borrar «%@» y todo su contenido?", name]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action) {
        [[OVPlaylistStore sharedStore] deletePlaylistAtIndex:index];
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [OVPlaylistStore sharedStore].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVPlaylistRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme background];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:16.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        cell.imageView.tintColor = [OVTheme orange];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
    }

    OVPlaylistStore *store = [OVPlaylistStore sharedStore];
    NSDictionary *playlist = [store playlistAtIndex:indexPath.row];
    NSArray *items = playlist[@"items"];
    cell.textLabel.text = playlist[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu %@",
                                 (unsigned long)items.count,
                                 items.count == 1 ? @"elemento" : @"elementos"];
    cell.imageView.image = [OVTheme tabIcon:OVTabIconPlaylists];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    OVPlaylistDetailViewController *detail =
        [[OVPlaylistDetailViewController alloc] initWithPlaylistIndex:indexPath.row];
    [self.navigationController pushViewController:detail animated:YES];
}

- (NSArray *)tableView:(UITableView *)tableView
        editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak OVPlaylistsViewController *weakSelf = self;
    UITableViewRowAction *rename =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Renombrar"
                                         handler:^(UITableViewRowAction *action,
                                                   NSIndexPath *path) {
        [weakSelf renamePlaylistAtIndex:path.row];
    }];
    rename.backgroundColor = [OVTheme surfaceLight];

    UITableViewRowAction *delete =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Borrar"
                                         handler:^(UITableViewRowAction *action,
                                                   NSIndexPath *path) {
        [weakSelf confirmDeletePlaylistAtIndex:path.row];
    }];
    return @[delete, rename];
}

@end
