#import "OVSettingsViewController.h"
#import "OVLibrary.h"
#import "OVFolderBrowserViewController.h"
#import "OVThumbnailCache.h"
#import "OVTheme.h"

#import <MobileVLCKit/MobileVLCKit.h>

typedef NS_ENUM(NSInteger, OVSettingsSection) {
    OVSettingsSectionLibrary = 0,
    OVSettingsSectionPlayback,
    OVSettingsSectionSubtitles,
    OVSettingsSectionNetwork,
    OVSettingsSectionStorage,
    OVSettingsSectionAbout,
    OVSettingsSectionCount
};

@interface OVSettingsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation OVSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Ajustes";
    self.view.backgroundColor = [OVTheme background];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [OVTheme background];
    self.tableView.separatorColor = [OVTheme separator];
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.rowHeight = 52.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(libraryChanged)
                                                 name:OVLibraryDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)libraryChanged
{
    if ([self isViewLoaded]) {
        [self.tableView reloadData];
    }
}

#pragma mark - Helpers

- (NSArray *)sources
{
    return [OVLibrary sharedLibrary].sources;
}

- (UISwitch *)switchWithValue:(BOOL)on tag:(NSInteger)tag
{
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
    toggle.onTintColor = [OVTheme orange];
    toggle.on = on;
    toggle.tag = tag;
    [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    return toggle;
}

- (UITableViewCell *)baseCellWithIdentifier:(NSString *)identifier style:(UITableViewCellStyle)style
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:style
                                                   reuseIdentifier:identifier];
    cell.backgroundColor = [OVTheme surface];
    cell.textLabel.textColor = [OVTheme text];
    cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [OVTheme secondaryText];
    cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
    UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
    selected.backgroundColor = [OVTheme surfaceLight];
    cell.selectedBackgroundView = selected;
    return cell;
}

- (NSString *)freeSpaceText
{
    NSDictionary *attributes = [[NSFileManager defaultManager]
                                attributesOfFileSystemForPath:NSHomeDirectory() error:NULL];
    unsigned long long freeBytes = [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
    if (freeBytes == 0) {
        return @"—";
    }
    return [OVTheme formatBytes:freeBytes];
}

- (NSString *)cacheSizeText
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *base = paths.count > 0 ? paths[0] : NSTemporaryDirectory();
    NSString *directory = [base stringByAppendingPathComponent:@"OpenVLC"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *enumerator = [fm enumeratorAtPath:directory].allObjects;
    unsigned long long total = 0;
    for (NSString *relative in enumerator) {
        NSString *full = [directory stringByAppendingPathComponent:relative];
        NSDictionary *attrs = [fm attributesOfItemAtPath:full error:NULL];
        total += [attrs[NSFileSize] unsignedLongLongValue];
    }
    return [OVTheme formatBytes:total];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return OVSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case OVSettingsSectionLibrary: return self.sources.count + 2;
        case OVSettingsSectionPlayback: return 4;
        case OVSettingsSectionSubtitles: return 1;
        case OVSettingsSectionNetwork: return 1;
        case OVSettingsSectionStorage: return 4;
        case OVSettingsSectionAbout: return 3;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case OVSettingsSectionLibrary: return @"Biblioteca";
        case OVSettingsSectionPlayback: return @"Reproducción";
        case OVSettingsSectionSubtitles: return @"Subtítulos";
        case OVSettingsSectionNetwork: return @"Red";
        case OVSettingsSectionStorage: return @"Almacenamiento";
        case OVSettingsSectionAbout: return @"Acerca de VLC 9";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == OVSettingsSectionLibrary) {
        return @"Añade cualquier carpeta del iPad, por ejemplo /var/mobile/Media. "
               @"Los archivos se indexan sin copiarse ni modificarse.";
    }
    if (section == OVSettingsSectionPlayback) {
        return @"La aceleración por hardware usa VideoToolbox. Desactívala solo si un vídeo se ve mal.";
    }
    if (section == OVSettingsSectionNetwork) {
        return @"Más caché mejora la reproducción por Wi-Fi, pero tarda más en empezar.";
    }
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if (!title) {
        return nil;
    }
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 34.0)];
    view.backgroundColor = [OVTheme background];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 12.0,
                                                              tableView.bounds.size.width - 32.0, 18.0)];
    label.text = [title uppercaseString];
    label.textColor = [OVTheme secondaryText];
    label.font = [OVTheme font:11.0 weight:UIFontWeightSemibold];
    [view addSubview:label];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 34.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *plain = @"OVSettingsPlain";
    static NSString *value = @"OVSettingsValue";
    static NSString *source = @"OVSettingsSource";

    if (indexPath.section == OVSettingsSectionLibrary) {
        NSArray *sources = self.sources;
        if (indexPath.row < (NSInteger)sources.count) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:source];
            if (!cell) {
                cell = [self baseCellWithIdentifier:source style:UITableViewCellStyleSubtitle];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.imageView.image = [[OVTheme tabIcon:OVTabIconFolders]
                                        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                cell.imageView.tintColor = [OVTheme orange];
            }
            NSDictionary *sourceInfo = sources[indexPath.row];
            NSString *path = sourceInfo[@"path"];
            cell.textLabel.text = [[OVLibrary sharedLibrary] displayNameForSource:sourceInfo];
            NSInteger count = [[OVLibrary sharedLibrary] countForSource:sourceInfo];
            NSString *recursive = [sourceInfo[@"recursive"] boolValue]
                ? @"subcarpetas incluidas" : @"solo esta carpeta";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld archivos · %@",
                                         (long)count, recursive];
            return cell;
        }

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:plain];
        if (!cell) {
            cell = [self baseCellWithIdentifier:plain style:UITableViewCellStyleDefault];
            cell.textLabel.textColor = [OVTheme orange];
            cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];
        }
        cell.imageView.image = nil;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        if (indexPath.row == (NSInteger)sources.count) {
            cell.textLabel.text = @"Añadir carpeta…";
        } else {
            cell.textLabel.text = @"Analizar de nuevo";
        }
        return cell;
    }

    if (indexPath.section == OVSettingsSectionPlayback) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:plain];
        if (!cell) {
            cell = [self baseCellWithIdentifier:plain style:UITableViewCellStyleDefault];
        }
        cell.imageView.image = nil;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.text = nil;
        NSArray *titles = @[@"Reanudar donde lo dejaste",
                            @"Audio en segundo plano",
                            @"Aceleración por hardware",
                            @"Desentrelazado"];
        NSArray *values = @[@([OVLibrary resumePlayback]),
                            @([OVLibrary backgroundAudio]),
                            @([OVLibrary hardwareAcceleration]),
                            @([OVLibrary deinterlace])];
        cell.textLabel.text = titles[indexPath.row];
        cell.textLabel.textColor = [OVTheme text];
        cell.accessoryView = [self switchWithValue:[values[indexPath.row] boolValue]
                                               tag:indexPath.row];
        return cell;
    }

    if (indexPath.section == OVSettingsSectionSubtitles) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:value];
        if (!cell) {
            cell = [self baseCellWithIdentifier:value style:UITableViewCellStyleValue1];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Codificación";
        cell.textLabel.textColor = [OVTheme text];
        cell.detailTextLabel.text = [OVLibrary subtitleEncoding];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    if (indexPath.section == OVSettingsSectionNetwork) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:value];
        if (!cell) {
            cell = [self baseCellWithIdentifier:value style:UITableViewCellStyleValue1];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Caché de red";
        cell.textLabel.textColor = [OVTheme text];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld ms",
                                     (long)[OVLibrary networkCaching]];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    if (indexPath.section == OVSettingsSectionStorage) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:value];
        if (!cell) {
            cell = [self baseCellWithIdentifier:value style:UITableViewCellStyleValue1];
        }
        cell.accessoryView = nil;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Borrar miniaturas";
            cell.detailTextLabel.text = [self cacheSizeText];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [OVTheme text];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Borrar posiciones de reproducción";
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [OVTheme text];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Restablecer ajustes";
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [OVTheme red];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else {
            cell.textLabel.text = @"Espacio libre";
            cell.detailTextLabel.text = [self freeSpaceText];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [OVTheme text];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:value];
    if (!cell) {
        cell = [self baseCellWithIdentifier:value style:UITableViewCellStyleValue1];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryView = nil;
    cell.textLabel.textColor = [OVTheme text];
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Versión de VLC 9";
        cell.detailTextLabel.text = [[NSBundle mainBundle]
                                     objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Motor VLC";
        cell.detailTextLabel.text = [VLCLibrary sharedLibrary].version ?: @"3.x";
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text = @"Créditos y licencia";
        cell.detailTextLabel.text = @"LGPL 2.1";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == OVSettingsSectionLibrary) {
        NSArray *sources = self.sources;
        if (indexPath.row < (NSInteger)sources.count) {
            NSString *path = sources[indexPath.row][@"path"];
            [self openBrowserAtPath:path];
        } else if (indexPath.row == (NSInteger)sources.count) {
            [self openBrowserAtPath:[self defaultLibraryPath]];
        } else {
            [[OVLibrary sharedLibrary] reload];
            [OVTheme showToast:@"Analizando carpetas…" inView:self.view];
        }
        return;
    }

    if (indexPath.section == OVSettingsSectionSubtitles) {
        [self showEncodingMenu];
        return;
    }

    if (indexPath.section == OVSettingsSectionNetwork) {
        [self showCachingMenu];
        return;
    }

    if (indexPath.section == OVSettingsSectionStorage) {
        if (indexPath.row == 0) {
            [self confirmClearThumbnails];
        } else if (indexPath.row == 1) {
            [self confirmClearPositions];
        } else if (indexPath.row == 2) {
            [self confirmResetSettings];
        }
        return;
    }

    if (indexPath.section == OVSettingsSectionAbout && indexPath.row == 2) {
        [self showCredits];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == OVSettingsSectionLibrary &&
           indexPath.row < (NSInteger)self.sources.count;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    NSArray *sources = self.sources;
    if (indexPath.row < (NSInteger)sources.count) {
        [[OVLibrary sharedLibrary] removeSource:sources[indexPath.row][@"path"]];
        [self.tableView reloadData];
    }
}

#pragma mark - Navigation

- (NSString *)defaultLibraryPath
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *candidates = @[@"/var/mobile/Media",
                            @"/var/mobile/Documents",
                            NSHomeDirectory()];
    for (NSString *candidate in candidates) {
        BOOL isDirectory = NO;
        if ([fm fileExistsAtPath:candidate isDirectory:&isDirectory] && isDirectory) {
            return candidate;
        }
    }
    return NSHomeDirectory();
}

- (void)openBrowserAtPath:(NSString *)path
{
    if (path.length == 0) {
        return;
    }
    OVFolderBrowserViewController *browser =
        [[OVFolderBrowserViewController alloc] initWithPath:path];
    [self.navigationController pushViewController:browser animated:YES];
}

#pragma mark - Switches

- (void)switchChanged:(UISwitch *)toggle
{
    switch (toggle.tag) {
        case 0: [OVLibrary setResumePlayback:toggle.isOn]; break;
        case 1: [OVLibrary setBackgroundAudio:toggle.isOn]; break;
        case 2: [OVLibrary setHardwareAcceleration:toggle.isOn]; break;
        case 3: [OVLibrary setDeinterlace:toggle.isOn]; break;
        default: break;
    }
}

#pragma mark - Menus

- (void)showEncodingMenu
{
    NSArray *encodings = @[@"UTF-8", @"ISO-8859-1", @"Windows-1252", @"UTF-16", @"CP850"];
    NSString *current = [OVLibrary subtitleEncoding];
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Codificación de subtítulos"
                                                      inView:self.view
                                                     popover:nil];
    for (NSString *encoding in encodings) {
        NSString *title = [encoding isEqualToString:current]
            ? [@"✓  " stringByAppendingString:encoding] : encoding;
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [OVLibrary setSubtitleEncoding:encoding];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentSheet:sheet fromCellAtIndexPath:[NSIndexPath indexPathForRow:0
                                                                    inSection:OVSettingsSectionSubtitles]];
}

- (void)showCachingMenu
{
    NSArray *values = @[@500, @1000, @1500, @3000, @5000, @10000];
    NSInteger current = [OVLibrary networkCaching];
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Caché de red"
                                                      inView:self.view
                                                     popover:nil];
    for (NSNumber *value in values) {
        NSInteger milliseconds = value.integerValue;
        NSString *title = [NSString stringWithFormat:@"%ld ms", (long)milliseconds];
        if (milliseconds == current) {
            title = [@"✓  " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [OVLibrary setNetworkCaching:milliseconds];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentSheet:sheet fromCellAtIndexPath:[NSIndexPath indexPathForRow:0
                                                                    inSection:OVSettingsSectionNetwork]];
}

- (void)presentSheet:(UIAlertController *)sheet fromCellAtIndexPath:(NSIndexPath *)indexPath
{
    if (sheet.popoverPresentationController) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        sheet.popoverPresentationController.sourceView = cell ?: self.view;
        sheet.popoverPresentationController.sourceRect = cell
            ? cell.bounds
            : CGRectMake(self.view.bounds.size.width / 2.0,
                         self.view.bounds.size.height / 2.0, 1, 1);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Maintenance

- (void)confirmClearThumbnails
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Borrar miniaturas"
                                            message:@"Se eliminarán las miniaturas guardadas. Se volverán a generar al navegar."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action) {
        [[OVThumbnailCache sharedCache] clearCache];
        [self.tableView reloadData];
        [OVTheme showToast:@"Miniaturas borradas" inView:self.view];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmClearPositions
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Borrar posiciones"
                                            message:@"Se olvidará el punto de reanudación de todos los archivos."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"OVPositions"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[OVLibrary sharedLibrary] reload];
        [[NSNotificationCenter defaultCenter] postNotificationName:OVLibraryDidChangeNotification
                                                            object:[OVLibrary sharedLibrary]];
        [self.tableView reloadData];
        [OVTheme showToast:@"Posiciones borradas" inView:self.view];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmResetSettings
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Restablecer ajustes"
                                            message:@"Se restauran las preferencias de reproducción, subtítulos y red. Las carpetas de la biblioteca se conservan."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restablecer"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *keys = @[@"OVSortMode", @"OVBackgroundAudio", @"OVResumePlayback",
                          @"OVHardwareAcceleration", @"OVDeinterlace", @"OVSubtitleEncoding",
                          @"OVNetworkCaching", @"OVVolume"];
        for (NSString *key in keys) {
            [defaults removeObjectForKey:key];
        }
        [defaults synchronize];
        [self.tableView reloadData];
        [OVTheme showToast:@"Ajustes restablecidos" inView:self.view];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCredits
{
    NSString *message =
        @"VLC 9 usa el motor de VLC media player (MobileVLCKit), "
        @"distribuido bajo la licencia GNU LGPL 2.1.\n\n"
        @"VLC es una marca de VideoLAN. Esta aplicación es un reproductor "
        @"independiente para iPad con iOS 9.\n\n"
        @"Iconos e interfaz: diseño propio inspirado en VLC.";
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Créditos y licencia"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
