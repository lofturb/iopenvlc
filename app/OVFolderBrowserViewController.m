#import "OVFolderBrowserViewController.h"
#import "OVLibrary.h"
#import "OVTheme.h"
#import "OVPlayerViewController.h"

typedef NS_ENUM(NSInteger, OVBrowserSection) {
    OVBrowserSectionPlaces = 0,
    OVBrowserSectionFolders,
    OVBrowserSectionFiles,
    OVBrowserSectionCount
};

@interface OVFolderBrowserViewController () <UITableViewDataSource, UITableViewDelegate>

+ (NSString *)defaultBrowsingPath;

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) void (^subtitleCompletion)(NSString *path);
@property (nonatomic, assign) BOOL subtitleMode;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *pathLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIBarButtonItem *catalogButton;

@property (nonatomic, strong) NSArray *places;        // dictionaries: title, path, subtitle
@property (nonatomic, strong) NSArray *folders;       // names
@property (nonatomic, strong) NSArray *files;         // OVMediaItem or dictionaries for subtitles
@property (nonatomic, strong) NSArray *playableItems; // OVMediaItem for the current folder

@end

@implementation OVFolderBrowserViewController

#pragma mark - Init

- (instancetype)initWithPath:(NSString *)path
{
    return [self initWithPath:path subtitleCompletion:nil];
}

- (instancetype)initWithPath:(NSString *)path
          subtitleCompletion:(void (^)(NSString *))completion
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _path = [self normalizedPath:path] ?: [[self class] defaultBrowsingPath];
        _subtitleCompletion = [completion copy];
        _subtitleMode = (completion != nil);
        _places = @[];
        _folders = @[];
        _files = @[];
        _playableItems = @[];
    }
    return self;
}

+ (NSString *)defaultBrowsingPath
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

- (NSString *)normalizedPath:(NSString *)path
{    if (path.length == 0) {
        return nil;
    }
    NSString *expanded = [path stringByExpandingTildeInPath];
    if ([expanded hasPrefix:@"~"]) {
        expanded = [NSHomeDirectory() stringByAppendingString:[expanded substringFromIndex:1]];
    }
    NSString *standard = [expanded stringByStandardizingPath];
    if (standard.length == 0) {
        return nil;
    }
    if (standard.length > 1 && [standard hasSuffix:@"/"]) {
        standard = [standard substringToIndex:standard.length - 1];
    }
    return standard;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [OVTheme background];
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.navigationController.navigationBar.translucent = NO;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 56.0;
    self.tableView.estimatedRowHeight = 0.0;
    [OVTheme styleTableView:self.tableView];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [OVTheme orange];
    [self.refreshControl addTarget:self action:@selector(refreshPulled)
                  forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0, 58.0)];
    self.headerView.backgroundColor = [OVTheme background];

    self.pathLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.pathLabel.textColor = [OVTheme secondaryText];
    self.pathLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
    self.pathLabel.numberOfLines = 2;
    self.pathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.headerView addSubview:self.pathLabel];

    self.badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.badgeLabel.textColor = [OVTheme orange];
    self.badgeLabel.font = [OVTheme font:12.0 weight:UIFontWeightSemibold];
    [self.headerView addSubview:self.badgeLabel];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.textColor = [OVTheme secondaryText];
    self.emptyLabel.font = [OVTheme font:15.0 weight:UIFontWeightRegular];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 3;

    self.tableView.tableHeaderView = self.headerView;

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.tableView addGestureRecognizer:longPress];

    self.catalogButton =
        [[UIBarButtonItem alloc] initWithImage:[self catalogImage]
                                        style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(toggleCatalog)];
    self.catalogButton.tintColor = [OVTheme orange];
    self.catalogButton.accessibilityLabel = @"Añadir o quitar de la biblioteca";

    UIBarButtonItem *menuButton =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                      target:self
                                                      action:@selector(showOptions)];
    menuButton.tintColor = [OVTheme orange];

    self.navigationItem.rightBarButtonItems = self.subtitleMode
        ? @[menuButton]
        : @[menuButton, self.catalogButton];

    if (self.subtitleMode) {
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                          target:self
                                                          action:@selector(cancelSubtitleSelection)];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(libraryChanged)
                                                 name:OVLibraryDidChangeNotification
                                               object:nil];

    [self reloadContents];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationItem.title = self.subtitleMode ? @"Elegir subtítulo" : [self shortTitle];
    [self reloadContents];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    self.headerView.frame = CGRectMake(0, 0, width, 58.0);
    self.tableView.tableHeaderView = self.headerView;
    self.pathLabel.frame = CGRectMake(16.0, 7.0, width - 32.0, 32.0);
    self.badgeLabel.frame = CGRectMake(16.0, 38.0, width - 32.0, 16.0);
    self.tableView.frame = CGRectMake(0, 0, width, height);
    self.emptyLabel.frame = CGRectMake(40.0, height * 0.42, width - 80.0, 70.0);
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (NSString *)shortTitle
{
    if ([self.path isEqualToString:@"/"]) {
        return @"iPad";
    }
    NSString *name = [self.path lastPathComponent];
    return name.length > 0 ? name : @"Carpetas";
}

- (UIImage *)catalogImage
{
    BOOL isSource = [[OVLibrary sharedLibrary] isSourcePath:self.path];
    UIImage *icon = [OVTheme tabIcon:OVTabIconFolders];
    if (!isSource) {
        // '+' badge drawn over the folder to hint at adding it.
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(25.0, 25.0), NO, 0.0);
        [icon drawInRect:CGRectMake(0, 0, 25, 25)];
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(ctx, [[OVTheme orange] CGColor]);
        CGContextFillRect(ctx, CGRectMake(15.0, 12.0, 10.0, 2.4));
        CGContextFillRect(ctx, CGRectMake(18.8, 8.2, 2.4, 10.0));
        icon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return icon;
}

#pragma mark - Data

- (void)libraryChanged
{
    if (![self isViewLoaded]) {
        return;
    }
    [self reloadContents];
}

- (void)refreshPulled
{
    [self reloadContents];
    [self.refreshControl endRefreshing];
}

- (BOOL)isDirectoryAtPath:(NSString *)path
{
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        return NO;
    }
    return isDirectory;
}

- (void)reloadContents
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![self isDirectoryAtPath:self.path]) {
        self.folders = @[];
        self.files = @[];
        self.playableItems = @[];
        self.pathLabel.text = self.path;
        self.badgeLabel.text = @"Carpeta no disponible";
        self.emptyLabel.text = @"Esta carpeta ya no existe o no es accesible.\nVuelve atrás y elige otra ubicación.";
        self.catalogButton.enabled = NO;
        [self.tableView reloadData];
        [self updateEmptyView];
        return;
    }

    self.catalogButton.enabled = YES;
    self.catalogButton.image = [self catalogImage];

    // Quick locations, only meaningful when they exist.
    NSMutableArray *places = [NSMutableArray array];
    NSArray *candidates = @[
        @{ @"title": @"Medios del iPad", @"path": @"/var/mobile/Media",
           @"detail": @"/var/mobile/Media" },
        @{ @"title": @"Documentos del iPad", @"path": @"/var/mobile/Documents",
           @"detail": @"/var/mobile/Documents" },
        @{ @"title": @"Documentos de VLC 9", @"path": [self appDocumentsPath],
           @"detail": @"Carpeta privada de la app" }
    ];
    for (NSDictionary *candidate in candidates) {
        NSString *candidatePath = candidate[@"path"];
        if (candidatePath.length == 0 || ![self isDirectoryAtPath:candidatePath]) {
            continue;
        }
        if ([candidatePath isEqualToString:self.path]) {
            continue;
        }
        [places addObject:candidate];
    }
    self.places = places;

    NSMutableArray *folders = [NSMutableArray array];
    NSMutableArray *fileNames = [NSMutableArray array];
    NSArray *names = [fm contentsOfDirectoryAtPath:self.path error:NULL] ?: @[];
    BOOL showSubtitlesOnly = self.subtitleMode;
    NSArray *videoExtensions = [OVLibrary videoExtensions];
    NSArray *audioExtensions = [OVLibrary audioExtensions];
    NSArray *subtitleExtensions = [OVLibrary subtitleExtensions];

    for (NSString *name in names) {
        if ([name hasPrefix:@"."] || [name isEqualToString:@"iTunesArtwork"]) {
            continue;
        }
        NSString *fullPath = [self.path stringByAppendingPathComponent:name];
        BOOL isDirectory = NO;
        if (![fm fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            continue;
        }
        if (isDirectory) {
            [folders addObject:name];
            continue;
        }
        NSString *extension = [name pathExtension].lowercaseString;
        if (showSubtitlesOnly) {
            if ([subtitleExtensions containsObject:extension]) {
                [fileNames addObject:name];
            }
        } else if ([videoExtensions containsObject:extension] ||
                   [audioExtensions containsObject:extension]) {
            [fileNames addObject:name];
        }
    }

    [folders sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a localizedCaseInsensitiveCompare:b];
    }];
    [fileNames sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a localizedCaseInsensitiveCompare:b];
    }];

    NSMutableArray *files = [NSMutableArray array];
    NSMutableArray *playable = [NSMutableArray array];
    for (NSString *name in fileNames) {
        NSString *fullPath = [self.path stringByAppendingPathComponent:name];
        NSString *extension = [name pathExtension].lowercaseString;
        OVMediaType type = [audioExtensions containsObject:extension]
            ? OVMediaTypeAudio : OVMediaTypeVideo;

        OVMediaItem *known = [[OVLibrary sharedLibrary] itemAtPath:fullPath];
        if (known) {
            [files addObject:known];
            [playable addObject:known];
            continue;
        }
        OVMediaItem *item = [[OVMediaItem alloc] initWithPath:fullPath type:type];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:NULL];
        item.size = [attrs[NSFileSize] unsignedLongLongValue];
        item.modified = attrs[NSFileModificationDate] ?: [NSDate date];
        [files addObject:item];
        if (!showSubtitlesOnly) {
            [playable addObject:item];
        }
    }

    self.folders = folders;
    self.files = files;
    self.playableItems = playable;

    self.pathLabel.text = self.path;

    NSDictionary *source = [[OVLibrary sharedLibrary] sourceForPath:self.path];
    if (source) {
        BOOL recursive = [source[@"recursive"] boolValue];
        self.badgeLabel.text = recursive
            ? @"En la biblioteca · incluye subcarpetas"
            : @"En la biblioteca · solo esta carpeta";
        self.badgeLabel.textColor = [OVTheme orange];
    } else {
        self.badgeLabel.text = @"No está en la biblioteca";
        self.badgeLabel.textColor = [OVTheme secondaryText];
    }

    if (self.subtitleMode) {
        self.badgeLabel.text = @"Toca un archivo de subtítulos para usarlo";
    }

    [self.tableView reloadData];
    [self updateEmptyView];
    [self updateTitle];
}

- (NSString *)appDocumentsPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths.count > 0 ? paths[0] : nil;
}

- (void)updateTitle
{
    self.navigationItem.title = self.subtitleMode ? @"Elegir subtítulo" : [self shortTitle];
}

- (void)updateEmptyView
{
    BOOL empty = (self.folders.count + self.files.count + self.places.count) == 0;
    if (empty) {
        self.emptyLabel.text = self.subtitleMode
            ? @"No hay archivos de subtítulos en esta carpeta."
            : @"Esta carpeta está vacía\no no contiene vídeos ni música.";
        self.tableView.backgroundView = self.emptyLabel;
    } else {
        self.tableView.backgroundView = nil;
    }
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return OVBrowserSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case OVBrowserSectionPlaces: return self.places.count;
        case OVBrowserSectionFolders: return self.folders.count;
        case OVBrowserSectionFiles: return self.files.count;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case OVBrowserSectionPlaces: return self.places.count ? @"Accesos rápidos" : nil;
        case OVBrowserSectionFolders: return self.folders.count ? @"Carpetas" : nil;
        case OVBrowserSectionFiles:
            if (self.files.count == 0) {
                return nil;
            }
            return self.subtitleMode ? @"Subtítulos" : @"Vídeos y música";
        default: return nil;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if (!title) {
        return nil;
    }
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 28.0)];
    view.backgroundColor = [OVTheme background];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 8.0,
                                                              tableView.bounds.size.width - 32.0, 18.0)];
    label.text = [title uppercaseString];
    label.textColor = [OVTheme secondaryText];
    label.font = [OVTheme font:11.0 weight:UIFontWeightSemibold];
    [view addSubview:label];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView titleForHeaderInSection:section] ? 28.0 : 0.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVBrowserCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme background];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:16.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.imageView.image = nil;
    cell.imageView.tintColor = [OVTheme orange];
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";
    cell.detailTextLabel.textColor = [OVTheme secondaryText];

    if (indexPath.section == OVBrowserSectionPlaces) {
        NSDictionary *place = self.places[indexPath.row];
        cell.textLabel.text = place[@"title"];
        cell.detailTextLabel.text = place[@"detail"];
        cell.imageView.image = [[OVTheme tabIcon:OVTabIconFolders]
                                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    if (indexPath.section == OVBrowserSectionFolders) {
        NSString *name = self.folders[indexPath.row];
        NSString *fullPath = [self.path stringByAppendingPathComponent:name];
        cell.textLabel.text = name;
        BOOL isSource = [[OVLibrary sharedLibrary] isSourcePath:fullPath];
        cell.imageView.image = [[OVTheme tabIcon:OVTabIconFolders]
                                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        if (isSource) {
            cell.detailTextLabel.text = @"En la biblioteca";
            cell.detailTextLabel.textColor = [OVTheme orange];
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.detailTextLabel.text = @"Carpeta";
            cell.detailTextLabel.textColor = [OVTheme secondaryText];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        return cell;
    }

    OVMediaItem *item = self.files[indexPath.row];
    cell.textLabel.text = item.title;
    cell.imageView.image = [[OVTheme tabIcon:(item.type == OVMediaTypeAudio
                                              ? OVTabIconMusic : OVTabIconVideos)]
                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.detailTextLabel.text = [self detailForItem:item];
    cell.detailTextLabel.textColor = [OVTheme secondaryText];
    if (!self.subtitleMode && item.lastPosition > 5.0) {
        cell.accessoryView = [self resumeBadgeForTime:item.lastPosition];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (UILabel *)resumeBadgeForTime:(double)seconds
{
    UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 62.0, 22.0)];
    badge.text = [OVTheme formatTime:seconds];
    badge.textColor = [OVTheme orange];
    badge.font = [OVTheme font:11.0 weight:UIFontWeightSemibold];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.borderColor = [[OVTheme orange] colorWithAlphaComponent:0.55].CGColor;
    badge.layer.borderWidth = 1.0;
    badge.layer.cornerRadius = 6.0;
    return badge;
}

- (NSString *)detailForItem:(OVMediaItem *)item
{
    NSMutableArray *parts = [NSMutableArray array];
    if (item.extension.length > 0) {
        [parts addObject:item.extension.uppercaseString];
    }
    if (item.size > 0) {
        [parts addObject:[OVTheme formatBytes:item.size]];
    }
    if (item.duration > 0.0) {
        [parts addObject:[OVTheme formatTime:item.duration]];
    }
    if (self.subtitleMode) {
        return [NSString stringWithFormat:@"Subtítulo · %@",
                item.size > 0 ? [OVTheme formatBytes:item.size] : @"archivo"];
    }
    return [parts componentsJoinedByString:@"  ·  "];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == OVBrowserSectionPlaces) {
        NSDictionary *place = self.places[indexPath.row];
        [self pushPath:place[@"path"]];
        return;
    }

    if (indexPath.section == OVBrowserSectionFolders) {
        NSString *name = self.folders[indexPath.row];
        [self pushPath:[self.path stringByAppendingPathComponent:name]];
        return;
    }

    OVMediaItem *item = self.files[indexPath.row];
    if (self.subtitleMode) {
        if (self.subtitleCompletion) {
            self.subtitleCompletion(item.path);
        }
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    NSUInteger index = [self.playableItems indexOfObject:item];
    if (index == NSNotFound) {
        NSArray *single = @[item];
        [self playItems:single startIndex:0];
        return;
    }
    [self playItems:self.playableItems startIndex:(NSInteger)index];
}

#pragma mark - Navigation

- (void)pushPath:(NSString *)path
{
    NSString *normalized = [self normalizedPath:path];
    if (normalized.length == 0 || ![self isDirectoryAtPath:normalized]) {
        [OVTheme showToast:@"Esa carpeta no está disponible" inView:self.view];
        return;
    }
    OVFolderBrowserViewController *browser =
        [[OVFolderBrowserViewController alloc] initWithPath:normalized
                                         subtitleCompletion:self.subtitleCompletion];
    [self.navigationController pushViewController:browser animated:YES];
}

- (void)cancelSubtitleSelection
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playItems:(NSArray *)items startIndex:(NSInteger)startIndex
{
    if (items.count == 0) {
        [OVTheme showToast:@"No hay archivos para reproducir" inView:self.view];
        return;
    }
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:items startIndex:startIndex];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:player animated:YES completion:nil];
}

#pragma mark - Collection helpers

- (NSArray *)mediaItemsInCurrentFolderRecursive:(BOOL)recursive
{
    return [self mediaItemsAtPath:self.path recursive:recursive];
}

- (NSArray *)mediaItemsAtPath:(NSString *)path recursive:(BOOL)recursive
{
    NSMutableArray *results = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *videoExtensions = [OVLibrary videoExtensions];
    NSArray *audioExtensions = [OVLibrary audioExtensions];

    void (^walk)(NSString *, NSInteger) = nil;
    walk = ^(NSString *directory, NSInteger depth) {
        if (depth > 12 || results.count > 2000) {
            return;
        }
        NSArray *names = [fm contentsOfDirectoryAtPath:directory error:NULL] ?: @[];
        for (NSString *name in names) {
            if ([name hasPrefix:@"."]) {
                continue;
            }
            NSString *full = [directory stringByAppendingPathComponent:name];
            BOOL isDirectory = NO;
            if (![fm fileExistsAtPath:full isDirectory:&isDirectory]) {
                continue;
            }
            if (isDirectory) {
                if (recursive) {
                    walk(full, depth + 1);
                }
                continue;
            }
            NSString *extension = [name pathExtension].lowercaseString;
            OVMediaType type;
            if ([videoExtensions containsObject:extension]) {
                type = OVMediaTypeVideo;
            } else if ([audioExtensions containsObject:extension]) {
                type = OVMediaTypeAudio;
            } else {
                continue;
            }
            OVMediaItem *known = [[OVLibrary sharedLibrary] itemAtPath:full];
            if (known) {
                [results addObject:known];
            } else {
                OVMediaItem *item = [[OVMediaItem alloc] initWithPath:full type:type];
                NSDictionary *attrs = [fm attributesOfItemAtPath:full error:NULL];
                item.size = [attrs[NSFileSize] unsignedLongLongValue];
                item.modified = attrs[NSFileModificationDate] ?: [NSDate date];
                [results addObject:item];
            }
        }
    };
    walk(path, 0);

    return [results sortedArrayUsingComparator:^NSComparisonResult(OVMediaItem *a, OVMediaItem *b) {
        return [a.title localizedCaseInsensitiveCompare:b.title];
    }];
}

#pragma mark - Catalog actions

- (void)toggleCatalog
{
    OVLibrary *library = [OVLibrary sharedLibrary];
    if ([library isSourcePath:self.path]) {
        [self confirmRemoveSource];
        return;
    }
    BOOL ok = [library addSource:self.path recursive:YES];
    if (ok) {
        [OVTheme showToast:@"Carpeta añadida a la biblioteca" inView:self.view];
        [self reloadContents];
    } else {
        [OVTheme showToast:@"No se pudo añadir la carpeta" inView:self.view];
    }
}

- (void)confirmRemoveSource
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Quitar de la biblioteca"
                                            message:@"Los archivos no se borran del iPad. Solo se deja de indexar esta carpeta."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Quitar"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action) {
        [[OVLibrary sharedLibrary] removeSource:self.path];
        [OVTheme showToast:@"Carpeta quitada de la biblioteca" inView:self.view];
        [self reloadContents];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showOptions
{
    BOOL isSource = [[OVLibrary sharedLibrary] isSourcePath:self.path];
    NSDictionary *source = [[OVLibrary sharedLibrary] sourceForPath:self.path];
    BOOL recursive = isSource ? [source[@"recursive"] boolValue] : NO;

    UIAlertController *sheet = [OVTheme actionSheetWithTitle:self.path
                                                      inView:self.view
                                                     popover:nil];
    __weak OVFolderBrowserViewController *weakSelf = self;

    if (!self.subtitleMode) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Reproducir esta carpeta"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [weakSelf playCurrentFolder];
        }]];
        NSString *toggleTitle = isSource ? @"Quitar de la biblioteca" : @"Añadir a la biblioteca";
        [sheet addAction:[UIAlertAction actionWithTitle:toggleTitle
                                                 style:isSource ? UIAlertActionStyleDestructive
                                                               : UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [weakSelf toggleCatalog];
        }]];
        if (isSource) {
            NSString *recursiveTitle = recursive
                ? @"No incluir subcarpetas"
                : @"Incluir subcarpetas";
            [sheet addAction:[UIAlertAction actionWithTitle:recursiveTitle
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                [weakSelf setRecursive:!recursive];
            }]];
        }
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Ir a una ruta…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf promptForPath];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Copiar ruta"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = weakSelf.path;
        [OVTheme showToast:@"Ruta copiada" inView:weakSelf.view];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Actualizar"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf reloadContents];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)playCurrentFolder
{
    NSArray *items = [self mediaItemsInCurrentFolderRecursive:YES];
    if (items.count == 0) {
        [OVTheme showToast:@"Esta carpeta no contiene medios" inView:self.view];
        return;
    }
    [self playItems:items startIndex:0];
}

- (void)setRecursive:(BOOL)recursive
{
    [[OVLibrary sharedLibrary] addSource:self.path recursive:recursive];
    [self reloadContents];
}

- (void)promptForPath
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Ir a una ruta"
                                            message:@"Escribe una ruta del iPad, por ejemplo /var/mobile/Media"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.path;
        textField.placeholder = @"/var/mobile/Media";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ir"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        NSString *typed = alert.textFields.firstObject.text;
        [self navigateToTypedPath:typed];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)navigateToTypedPath:(NSString *)typed
{
    NSString *path = [self normalizedPath:[typed stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    if (path.length == 0) {
        return;
    }
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] ||
        !isDirectory) {
        [OVTheme showToast:@"La ruta no existe o no es una carpeta" inView:self.view];
        return;
    }
    [self pushPath:path];
}

#pragma mark - Long press

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint point = [gesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
    if (!indexPath || indexPath.section != OVBrowserSectionFolders) {
        return;
    }
    NSString *name = self.folders[indexPath.row];
    NSString *folderPath = [self.path stringByAppendingPathComponent:name];
    BOOL isSource = [[OVLibrary sharedLibrary] isSourcePath:folderPath];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];

    UIAlertController *sheet = [OVTheme actionSheetWithTitle:name
                                                      inView:self.view
                                                     popover:cell];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Abrir"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [self pushPath:folderPath];
    }]];
    if (!self.subtitleMode) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Reproducir carpeta"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            NSArray *items = [self mediaItemsAtPath:folderPath recursive:YES];
            [self playItems:items startIndex:0];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:(isSource ? @"Quitar de la biblioteca"
                                                               : @"Añadir a la biblioteca")
                                             style:(isSource ? UIAlertActionStyleDestructive
                                                            : UIAlertActionStyleDefault)
                                           handler:^(UIAlertAction *action) {
        if (isSource) {
            [[OVLibrary sharedLibrary] removeSource:folderPath];
        } else {
            [[OVLibrary sharedLibrary] addSource:folderPath recursive:YES];
        }
        [self reloadContents];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
