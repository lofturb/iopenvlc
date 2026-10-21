#import "OVNetworkViewController.h"
#import "OVPlayerViewController.h"
#import "OVMediaItem.h"
#import "OVTheme.h"

#import <MobileVLCKit/MobileVLCKit.h>

typedef NS_ENUM(NSInteger, OVNetworkSection) {
    OVNetworkSectionOpen = 0,
    OVNetworkSectionFavorites,
    OVNetworkSectionRecent,
    OVNetworkSectionUPnP,
    OVNetworkSectionCount
};

static NSString *const OVFavoritesKey = @"OVNetworkFavorites";
static NSString *const OVRecentKey = @"OVNetworkRecent";

#pragma mark - UPnP browser

@interface OVUPnPBrowserViewController : UIViewController <UITableViewDataSource,
                                                          UITableViewDelegate,
                                                          VLCMediaDelegate>

@property (nonatomic, strong) VLCMedia *media;
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray *children;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL parsing;

- (instancetype)initWithMedia:(VLCMedia *)media title:(NSString *)title;

@end

#pragma mark - Network controller

@interface OVNetworkViewController () <UITableViewDataSource, UITableViewDelegate,
                                       VLCMediaListDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) NSMutableArray *recent;
@property (nonatomic, strong) VLCMediaDiscoverer *discoverer;
@property (nonatomic, strong) VLCMediaList *discovered;
@property (nonatomic, assign) BOOL discovering;

@end

@implementation OVNetworkViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Red";
    self.view.backgroundColor = [OVTheme background];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self
                                                      action:@selector(promptForURL)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [OVTheme background];
    self.tableView.separatorColor = [OVTheme separator];
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.rowHeight = 60.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.tableView];

    [self loadFavorites];
    [self loadRecent];
    [self startDiscovery];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopDiscovery];
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

#pragma mark - Persistence

- (void)loadFavorites
{
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:OVFavoritesKey];
    self.favorites = [NSMutableArray array];
    for (id entry in saved) {
        if ([entry isKindOfClass:[NSDictionary class]] && entry[@"url"]) {
            [self.favorites addObject:[entry mutableCopy]];
        }
    }
}

- (void)saveFavorites
{
    [[NSUserDefaults standardUserDefaults] setObject:self.favorites forKey:OVFavoritesKey];
}

- (void)loadRecent
{
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:OVRecentKey];
    self.recent = [NSMutableArray array];
    for (id entry in saved) {
        if ([entry isKindOfClass:[NSDictionary class]] && entry[@"url"]) {
            [self.recent addObject:[entry mutableCopy]];
        }
    }
}

- (void)saveRecent
{
    [[NSUserDefaults standardUserDefaults] setObject:self.recent forKey:OVRecentKey];
}

- (void)addToRecent:(NSURL *)url title:(NSString *)title
{
    NSString *absolute = url.absoluteString;
    if (absolute.length == 0) {
        return;
    }
    NSMutableArray *updated = [NSMutableArray array];
    for (NSDictionary *entry in self.recent) {
        if (![entry[@"url"] isEqualToString:absolute]) {
            [updated addObject:entry];
        }
    }
    [updated insertObject:@{ @"url": absolute,
                             @"title": title.length > 0 ? title : [self titleForURL:url] }
                  atIndex:0];
    while (updated.count > 30) {
        [updated removeLastObject];
    }
    self.recent = updated;
    [self saveRecent];
}

- (NSString *)titleForURL:(NSURL *)url
{
    NSString *last = [url lastPathComponent];
    if (last.length > 0 && ![last isEqualToString:@"/"]) {
        return [last stringByRemovingPercentEncoding] ?: last;
    }
    if (url.host.length > 0) {
        return url.host;
    }
    return url.absoluteString ?: @"Red";
}

#pragma mark - URL handling

- (NSURL *)normalizedURLFromString:(NSString *)string
{
    NSString *trimmed = [string stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return nil;
    }
    NSString *lower = trimmed.lowercaseString;
    BOOL hasScheme = [lower rangeOfString:@"://"].location != NSNotFound;
    if (!hasScheme && ![lower hasPrefix:@"//"]) {
        trimmed = [@"http://" stringByAppendingString:trimmed];
        lower = trimmed.lowercaseString;
    }
    NSURL *url = [NSURL URLWithString:trimmed];
    if (!url || url.scheme.length == 0) {
        return nil;
    }
    NSSet *schemes = [NSSet setWithObjects:@"http", @"https", @"rtsp", @"rtmp", @"rtmps",
                      @"rtp", @"udp", @"mms", @"mmsh", @"ftp", @"sftp", @"smb", @"nfs", nil];
    if (![schemes containsObject:url.scheme.lowercaseString]) {
        return nil;
    }
    return url;
}

- (void)promptForURL
{
    NSURL *clipboardURL = [self normalizedURLFromString:
                           [UIPasteboard generalPasteboard].string ?: @""];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Abrir dirección de red"
                                            message:@"HTTP, HTTPS, RTSP, RTMP, UDP, FTP o SMB."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"http://192.168.1.10:8080/video.mp4";
        textField.text = clipboardURL.absoluteString;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reproducir"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        [self openURLString:text saveAsFavorite:NO];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Guardar en favoritos"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        [self openURLString:text saveAsFavorite:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openFromClipboard
{
    NSString *text = [UIPasteboard generalPasteboard].string;
    NSURL *url = [self normalizedURLFromString:text ?: @""];
    if (!url) {
        [OVTheme showToast:@"El portapapeles no contiene una dirección válida" inView:self.view];
        return;
    }
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:url.absoluteString
                                                      inView:self.view
                                                     popover:nil];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Reproducir"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [self playURL:url title:[self titleForURL:url]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Guardar en favoritos"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [self addFavoriteURL:url title:[self titleForURL:url]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect =
            CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1, 1);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openURLString:(NSString *)string saveAsFavorite:(BOOL)save
{
    NSURL *url = [self normalizedURLFromString:string];
    if (!url) {
        [OVTheme showToast:@"Dirección no válida" inView:self.view];
        return;
    }
    if (save) {
        [self addFavoriteURL:url title:[self titleForURL:url]];
        [OVTheme showToast:@"Añadido a favoritos" inView:self.view];
        [self.tableView reloadData];
        return;
    }
    [self playURL:url title:[self titleForURL:url]];
}

- (void)addFavoriteURL:(NSURL *)url title:(NSString *)title
{
    NSString *absolute = url.absoluteString;
    if (absolute.length == 0) {
        return;
    }
    for (NSInteger i = 0; i < (NSInteger)self.favorites.count; i++) {
        if ([self.favorites[i][@"url"] isEqualToString:absolute]) {
            [self.favorites removeObjectAtIndex:i];
            break;
        }
    }
    [self.favorites insertObject:@{ @"url": absolute,
                                    @"title": title.length > 0 ? title : [self titleForURL:url] }
                         atIndex:0];
    [self saveFavorites];
    [self.tableView reloadData];
}

- (void)playURL:(NSURL *)url title:(NSString *)title
{
    [self addToRecent:url title:title];
    [self.tableView reloadData];

    OVMediaItem *item = [[OVMediaItem alloc] initWithNetworkURL:url title:title];
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:@[item] startIndex:0];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:player animated:YES completion:nil];
}

#pragma mark - UPnP discovery

- (void)startDiscovery
{
    if (self.discovering) {
        return;
    }
    NSArray *services =
        [VLCMediaDiscoverer availableMediaDiscovererForCategoryType:VLCMediaDiscovererCategoryTypeLAN];
    NSDictionary *selected = nil;
    for (NSDictionary *service in services) {
        NSString *name = service[VLCMediaDiscovererName];
        if ([name isKindOfClass:[NSString class]] &&
            [name rangeOfString:@"upnp" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            selected = service;
            break;
        }
    }
    if (!selected && services.count > 0) {
        selected = services.firstObject;
    }
    NSString *name = selected[VLCMediaDiscovererName];
    if (name.length == 0) {
        return;
    }

    self.discoverer = [[VLCMediaDiscoverer alloc] initWithName:name];
    self.discovered = self.discoverer.discoveredMedia;
    self.discovered.delegate = self;
    int result = [self.discoverer startDiscoverer];
    self.discovering = (result == 0 && self.discoverer.isRunning);
    [self.tableView reloadData];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)stopDiscovery
{
    if (!self.discoverer) {
        return;
    }
    self.discovered.delegate = nil;
    [self.discoverer stopDiscoverer];
    self.discoverer = nil;
    self.discovered = nil;
    self.discovering = NO;
}

- (NSString *)titleForMedia:(VLCMedia *)media
{
    NSString *title = media.metaData.title;
    if (title.length > 0) {
        return title;
    }
    NSString *last = [media.url lastPathComponent];
    if (last.length > 0) {
        return [last stringByRemovingPercentEncoding] ?: last;
    }
    if (media.url.host.length > 0) {
        return media.url.host;
    }
    return @"Servidor";
}

- (void)mediaList:(VLCMediaList *)mediaList mediaAdded:(VLCMedia *)media atIndex:(NSUInteger)index
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)mediaList:(VLCMediaList *)mediaList mediaRemovedAtIndex:(NSUInteger)index
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return OVNetworkSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case OVNetworkSectionOpen: return 2;
        case OVNetworkSectionFavorites: return MAX(1, (NSInteger)self.favorites.count);
        case OVNetworkSectionRecent: return MAX(1, (NSInteger)self.recent.count);
        case OVNetworkSectionUPnP: {
            NSInteger count = self.discovered.count;
            return MAX(1, count);
        }
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case OVNetworkSectionOpen: return @"Abrir";
        case OVNetworkSectionFavorites: return @"Favoritos";
        case OVNetworkSectionRecent: return @"Recientes";
        case OVNetworkSectionUPnP: return @"Red local (UPnP)";
        default: return nil;
    }
}

- (BOOL)isPlaceholderRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == OVNetworkSectionFavorites) {
        return self.favorites.count == 0;
    }
    if (indexPath.section == OVNetworkSectionRecent) {
        return self.recent.count == 0;
    }
    if (indexPath.section == OVNetworkSectionUPnP) {
        return self.discovered.count == 0;
    }
    return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVNetworkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme surface];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    cell.textLabel.textColor = [OVTheme text];
    cell.detailTextLabel.textColor = [OVTheme secondaryText];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    if ([self isPlaceholderRowAtIndexPath:indexPath]) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = [OVTheme secondaryText];
        cell.textLabel.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
        if (indexPath.section == OVNetworkSectionFavorites) {
            cell.textLabel.text = @"Sin favoritos";
            cell.detailTextLabel.text = @"Usa + para guardar una dirección de red.";
        } else if (indexPath.section == OVNetworkSectionRecent) {
            cell.textLabel.text = @"Sin reproducciones recientes";
            cell.detailTextLabel.text = @"Las direcciones que abras aparecerán aquí.";
        } else {
            cell.textLabel.text = self.discovering
                ? @"Buscando servidores UPnP…"
                : @"Red local no disponible";
            cell.detailTextLabel.text = self.discovering
                ? @"Asegúrate de estar en la misma red Wi-Fi."
                : @"El servicio de descubrimiento no pudo iniciarse.";
        }
        return cell;
    }

    cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];

    if (indexPath.section == OVNetworkSectionOpen) {
        cell.textLabel.text = (indexPath.row == 0)
            ? @"Introducir dirección de red…" : @"Abrir desde el portapapeles";
        cell.detailTextLabel.text = (indexPath.row == 0)
            ? @"HTTP, HTTPS, RTSP, RTMP, UDP, FTP, SMB" : @"Pega un enlace y reprodúcelo";
    } else if (indexPath.section == OVNetworkSectionFavorites) {
        NSDictionary *entry = self.favorites[indexPath.row];
        cell.textLabel.text = entry[@"title"] ?: @"Favorito";
        cell.detailTextLabel.text = entry[@"url"];
    } else if (indexPath.section == OVNetworkSectionRecent) {
        NSDictionary *entry = self.recent[indexPath.row];
        cell.textLabel.text = entry[@"title"] ?: @"Reciente";
        cell.detailTextLabel.text = entry[@"url"];
    } else {
        VLCMedia *media = [self.discovered mediaAtIndex:(NSUInteger)indexPath.row];
        cell.textLabel.text = [self titleForMedia:media];
        cell.detailTextLabel.text = media.url.host.length > 0
            ? media.url.host : @"Servidor de medios";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == OVNetworkSectionFavorites ||
            indexPath.section == OVNetworkSectionRecent) &&
           ![self isPlaceholderRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    if (indexPath.section == OVNetworkSectionFavorites &&
        indexPath.row < (NSInteger)self.favorites.count) {
        [self.favorites removeObjectAtIndex:indexPath.row];
        [self saveFavorites];
    } else if (indexPath.section == OVNetworkSectionRecent &&
               indexPath.row < (NSInteger)self.recent.count) {
        [self.recent removeObjectAtIndex:indexPath.row];
        [self saveRecent];
    }
    [tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self isPlaceholderRowAtIndexPath:indexPath]) {
        return;
    }

    if (indexPath.section == OVNetworkSectionOpen) {
        if (indexPath.row == 0) {
            [self promptForURL];
        } else {
            [self openFromClipboard];
        }
        return;
    }

    if (indexPath.section == OVNetworkSectionFavorites) {
        NSDictionary *entry = self.favorites[indexPath.row];
        NSURL *url = [NSURL URLWithString:entry[@"url"]];
        if (url) {
            [self playURL:url title:entry[@"title"]];
        }
        return;
    }

    if (indexPath.section == OVNetworkSectionRecent) {
        NSDictionary *entry = self.recent[indexPath.row];
        NSURL *url = [NSURL URLWithString:entry[@"url"]];
        if (url) {
            [self playURL:url title:entry[@"title"]];
        }
        return;
    }

    VLCMedia *media = [self.discovered mediaAtIndex:(NSUInteger)indexPath.row];
    if (!media) {
        return;
    }
    OVUPnPBrowserViewController *browser =
        [[OVUPnPBrowserViewController alloc] initWithMedia:media
                                                    title:[self titleForMedia:media]];
    [self.navigationController pushViewController:browser animated:YES];
}

@end

#pragma mark - UPnP browser implementation

@implementation OVUPnPBrowserViewController

- (instancetype)initWithMedia:(VLCMedia *)media title:(NSString *)title
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _media = media;
        _displayTitle = [title copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = self.displayTitle.length > 0 ? self.displayTitle : @"Red local";
    self.view.backgroundColor = [OVTheme background];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [OVTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                    UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.textColor = [OVTheme secondaryText];
    self.emptyLabel.font = [OVTheme font:15.0 weight:UIFontWeightRegular];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 3;
    self.emptyLabel.text = @"Cargando contenido del servidor…";

    self.media.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.loaded || self.parsing) {
        return;
    }
    self.parsing = YES;
    [self startLoading];
    int result = [self.media parseWithOptions:(VLCMediaParsingOptionsParseNetwork |
                                              VLCMediaParsingOptionsFetchNetwork)
                                      timeout:12000];
    if (result != 0) {
        self.parsing = NO;
        [self finishLoadingWithError];
        return;
    }
    __weak OVUPnPBrowserViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(13.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        OVUPnPBrowserViewController *strongSelf = weakSelf;
        if (strongSelf && strongSelf.parsing) {
            [strongSelf refreshChildren];
        }
    });
}

- (void)dealloc
{
    self.media.delegate = nil;
    [self.media parseStop];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    self.tableView.frame = self.view.bounds;
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0,
                                      self.view.bounds.size.height / 2.0);
    self.emptyLabel.frame = CGRectMake(40.0, self.view.bounds.size.height * 0.4,
                                       self.view.bounds.size.width - 80.0, 80.0);
}

- (void)startLoading
{
    [self.spinner startAnimating];
    self.tableView.backgroundView = self.emptyLabel;
    self.emptyLabel.text = @"Cargando contenido del servidor…";
    [self.tableView reloadData];
}

- (void)finishLoadingWithError
{
    [self.spinner stopAnimating];
    self.emptyLabel.text = @"No se pudo abrir este servidor.\nComprueba la conexión Wi-Fi e inténtalo de nuevo.";
    self.tableView.backgroundView = self.emptyLabel;
}

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshChildren];
    });
}

- (void)refreshChildren
{
    VLCMediaList *subitems = self.media.subitems;
    NSMutableArray *children = [NSMutableArray array];
    if (subitems) {
        NSInteger count = subitems.count;
        for (NSInteger i = 0; i < count; i++) {
            VLCMedia *media = [subitems mediaAtIndex:(NSUInteger)i];
            if (media) {
                [children addObject:media];
            }
        }
    }

    [children sortUsingComparator:^NSComparisonResult(VLCMedia *a, VLCMedia *b) {
        BOOL aDir = [self isDirectoryMedia:a];
        BOOL bDir = [self isDirectoryMedia:b];
        if (aDir != bDir) {
            return aDir ? NSOrderedAscending : NSOrderedDescending;
        }
        return [[self titleForMedia:a] localizedCaseInsensitiveCompare:[self titleForMedia:b]];
    }];

    self.children = children;
    self.parsing = NO;
    self.loaded = YES;
    [self.spinner stopAnimating];

    if (children.count == 0) {
        self.emptyLabel.text = @"Este servidor no contiene elementos visibles.";
        self.tableView.backgroundView = self.emptyLabel;
    } else {
        self.tableView.backgroundView = nil;
    }
    [self.tableView reloadData];
}

- (NSString *)titleForMedia:(VLCMedia *)media
{
    NSString *title = media.metaData.title;
    if (title.length > 0) {
        return title;
    }
    NSString *last = [media.url lastPathComponent];
    if (last.length > 0) {
        return [last stringByRemovingPercentEncoding] ?: last;
    }
    if (media.url.host.length > 0) {
        return media.url.host;
    }
    return @"Elemento";
}

- (BOOL)isDirectoryMedia:(VLCMedia *)media
{
    if (media.mediaType == VLCMediaTypeDirectory) {
        return YES;
    }
    if (media.mediaType == VLCMediaTypeFile) {
        return NO;
    }
    NSString *path = media.url.path;
    if ([path hasSuffix:@"/"]) {
        return YES;
    }
    VLCMediaList *subitems = media.subitems;
    if (subitems && subitems.count > 0) {
        return YES;
    }

    // Los contenedores UPnP/DLNA suelen no tener extensión en la URL.
    NSString *scheme = media.url.scheme.lowercaseString;
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        NSString *last = path.lastPathComponent;
        if (last.length > 0 && last.pathExtension.length == 0) {
            NSString *query = media.url.query.lowercaseString;
            BOOL looksLikeStream = [query containsString:@"m3u8"] ||
                                   [query containsString:@".mp4"] ||
                                   [query containsString:@".mkv"];
            if (!looksLikeStream) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.children.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVUPnPCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme background];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
        cell.imageView.tintColor = [OVTheme orange];
    }

    VLCMedia *media = self.children[indexPath.row];
    cell.textLabel.text = [self titleForMedia:media];
    BOOL isDirectory = [self isDirectoryMedia:media];
    cell.imageView.image = [[OVTheme tabIcon:(isDirectory ? OVTabIconFolders : OVTabIconVideos)]
                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.detailTextLabel.text = isDirectory
        ? @"Carpeta"
        : (media.url.host.length > 0 ? media.url.host : @"Secuencia de red");
    cell.accessoryType = isDirectory ? UITableViewCellAccessoryDisclosureIndicator
                                     : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    VLCMedia *media = self.children[indexPath.row];

    if ([self isDirectoryMedia:media] && media.subitems.count > 0) {
        OVUPnPBrowserViewController *browser =
            [[OVUPnPBrowserViewController alloc] initWithMedia:media
                                                        title:[self titleForMedia:media]];
        [self.navigationController pushViewController:browser animated:YES];
        return;
    }
    if (media.mediaType == VLCMediaTypeDirectory) {
        OVUPnPBrowserViewController *browser =
            [[OVUPnPBrowserViewController alloc] initWithMedia:media
                                                        title:[self titleForMedia:media]];
        [self.navigationController pushViewController:browser animated:YES];
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    NSInteger startIndex = 0;
    for (VLCMedia *candidate in self.children) {
        if (candidate.url == nil) {
            continue;
        }
        if ([self isDirectoryMedia:candidate] && candidate != media) {
            continue;
        }
        OVMediaItem *item =
            [[OVMediaItem alloc] initWithNetworkURL:candidate.url
                                             title:[self titleForMedia:candidate]];
        if (candidate == media) {
            startIndex = (NSInteger)items.count;
        }
        [items addObject:item];
    }

    if (items.count == 0) {
        [OVTheme showToast:@"Este elemento no se puede reproducir" inView:self.view];
        return;
    }
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:items startIndex:startIndex];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:player animated:YES completion:nil];
}

@end
