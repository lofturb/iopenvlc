#import "OVMoreViewController.h"
#import "OVHistoryViewController.h"
#import "OVSettingsViewController.h"
#import "OVTheme.h"

@interface OVMoreViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;

@end

@implementation OVMoreViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Más";
    self.view.backgroundColor = [OVTheme background];
    self.navigationItem.titleView = [OVTheme brandTitleView];

    self.sections = @[
        @{ @"title": @"Biblioteca", @"items": @[
            @{ @"title": @"Historial",
               @"subtitle": @"Lo último que has visto",
               @"icon": @(OVTabIconHistory),
               @"kind": @"history" },
            @{ @"title": @"Listas de reproducción",
               @"subtitle": @"Tus listas guardadas",
               @"icon": @(OVTabIconPlaylists),
               @"kind": @"playlists" }
        ] },
        @{ @"title": @"Aplicación", @"items": @[
            @{ @"title": @"Ajustes",
               @"subtitle": @"Biblioteca, reproducción y red",
               @"icon": @(OVTabIconSettings),
               @"kind": @"settings" },
            @{ @"title": @"Acerca de VLC 9",
               @"subtitle": @"Versión e información",
               @"icon": @(OVTabIconMore),
               @"kind": @"about" },
            @{ @"title": @"Créditos y licencias",
               @"subtitle": @"VLC, VideoLAN y código abierto",
               @"icon": @(OVTabIconMore),
               @"kind": @"credits" }
        ] }
    ];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [OVTheme background];
    self.tableView.separatorColor = [OVTheme separator];
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.rowHeight = 62.0;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.sections[section][@"items"] count];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                            tableView.bounds.size.width, 44.0)];
    view.backgroundColor = [OVTheme background];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 16.0,
                                                              tableView.bounds.size.width - 32.0,
                                                              24.0)];
    label.text = self.sections[section][@"title"];
    label.textColor = [OVTheme orange];
    label.font = [OVTheme font:16.0 weight:UIFontWeightSemibold];
    [view addSubview:label];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 8.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVMoreRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme surface];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        cell.imageView.tintColor = [OVTheme orange];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
    }

    NSDictionary *entry = self.sections[indexPath.section][@"items"][indexPath.row];
    cell.textLabel.text = entry[@"title"];
    cell.detailTextLabel.text = entry[@"subtitle"];
    cell.imageView.image = [OVTheme tabIcon:(OVTabIcon)[entry[@"icon"] integerValue]];

    NSString *kind = entry[@"kind"];
    if ([kind isEqualToString:@"about"] || [kind isEqualToString:@"credits"]) {
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *entry = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *kind = entry[@"kind"];

    if ([kind isEqualToString:@"history"]) {
        [self.navigationController pushViewController:[[OVHistoryViewController alloc] init]
                                             animated:YES];
    } else if ([kind isEqualToString:@"playlists"]) {
        if (self.tabBarController) {
            self.tabBarController.selectedIndex = 3;
        }
    } else if ([kind isEqualToString:@"settings"]) {
        [self.navigationController pushViewController:[[OVSettingsViewController alloc] init]
                                             animated:YES];
    } else if ([kind isEqualToString:@"about"]) {
        [self showAbout];
    } else if ([kind isEqualToString:@"credits"]) {
        [self showCredits];
    }
}

- (void)showAbout
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *message = [NSString stringWithFormat:
                         @"VLC 9 %@\n\n"
                         @"Reproductor para iOS 9 y armv7.\n"
                         @"Motor: MobileVLCKit 3.7.4.\n\n"
                         @"Interfaz basada en VLC para Android 3.7.2.",
                         version ?: @"1.0.0"];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Acerca de VLC 9"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCredits
{
    NSString *message =
        @"VLC es software libre de VideoLAN.\n\n"
        @"Interfaz inspirada en VLC para Android (GPLv2 o posterior).\n"
        @"Motor de reproducción: MobileVLCKit / libVLC (LGPLv2.1 o posterior).\n"
        @"Iconos y elementos visuales propios, basados en el lenguaje de Material Design.";
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Créditos y licencias"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
