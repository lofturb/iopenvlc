#import "OVLibrary.h"
#import "OVTheme.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

NSString *const OVLibraryDidChangeNotification = @"OVLibraryDidChangeNotification";
NSString *const OVLibraryScanProgressNotification = @"OVLibraryScanProgressNotification";
NSString *const OVHistoryDidChangeNotification = @"OVHistoryDidChangeNotification";

static NSString *const OVSourcesKey = @"OVSources";
static NSString *const OVPositionsKey = @"OVPositions";
static NSString *const OVSortModeKey = @"OVSortMode";
static NSString *const OVBackgroundAudioKey = @"OVBackgroundAudio";
static NSString *const OVResumePlaybackKey = @"OVResumePlayback";
static NSString *const OVHardwareAccelerationKey = @"OVHardwareAcceleration";
static NSString *const OVDeinterlaceKey = @"OVDeinterlace";
static NSString *const OVSubtitleEncodingKey = @"OVSubtitleEncoding";
static NSString *const OVNetworkCachingKey = @"OVNetworkCaching";
static NSString *const OVHistoryKey = @"OVHistory";

@interface OVLibrary ()
@property (nonatomic, readwrite) NSArray *sources;
@property (nonatomic, readwrite) NSArray *videos;
@property (nonatomic, readwrite) NSArray *audio;
@property (nonatomic, readwrite) BOOL scanning;
@property (nonatomic, strong) NSMutableDictionary *itemsByPath;
@property (nonatomic, strong) NSMutableDictionary *metaCache;
@property (nonatomic, strong) dispatch_queue_t scanQueue;
@property (nonatomic, assign) BOOL needsRescan;
@end

@implementation OVLibrary

+ (void)initialize
{
    if (self != [OVLibrary class]) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        OVBackgroundAudioKey: @YES,
        OVResumePlaybackKey: @YES,
        OVHardwareAccelerationKey: @YES,
        OVDeinterlaceKey: @NO,
        OVSubtitleEncodingKey: @"UTF-8",
        OVNetworkCachingKey: @1000,
        OVSortModeKey: @(OVSortModeName)
    }];
}

+ (instancetype)sharedLibrary
{
    static OVLibrary *library = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        library = [[OVLibrary alloc] init];
    });
    return library;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _scanQueue = dispatch_queue_create("com.lofturb.vlc9.scan", DISPATCH_QUEUE_SERIAL);
        _itemsByPath = [NSMutableDictionary dictionary];
        _metaCache = [NSMutableDictionary dictionary];
        _videos = @[];
        _audio = @[];
        _sources = @[];
        [self loadCache];
        [self loadSources];
    }
    return self;
}

#pragma mark - Persistencia

- (NSString *)cacheDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *base = paths.count > 0 ? paths[0] : NSTemporaryDirectory();
    NSString *dir = [base stringByAppendingPathComponent:@"OpenVLC"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return dir;
}

- (NSString *)cachePath
{
    return [[self cacheDirectory] stringByAppendingPathComponent:@"index.json"];
}

- (void)loadCache
{
    NSString *path = [self cachePath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSDictionary *meta = json[@"meta"];
    if ([meta isKindOfClass:[NSDictionary class]]) {
        [_metaCache addEntriesFromDictionary:meta];
    }
}

- (void)saveCache
{
    NSDictionary *json = @{ @"version": @1, @"meta": self.metaCache ?: @{} };
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
    if (data) {
        [data writeToFile:[self cachePath] atomically:YES];
    }
}

- (void)loadSources
{
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:OVSourcesKey];
    NSMutableArray *valid = [NSMutableArray array];
    for (id item in saved) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *path = item[@"path"];
        if (![path isKindOfClass:[NSString class]] || path.length == 0) {
            continue;
        }
        [valid addObject:@{ @"path": path, @"recursive": @([item[@"recursive"] boolValue]) }];
    }
    self.sources = valid;
}

- (void)saveSources
{
    [[NSUserDefaults standardUserDefaults] setObject:self.sources forKey:OVSourcesKey];
}

#pragma mark - Fuentes

- (NSString *)normalizedPath:(NSString *)path
{
    if (path.length == 0) {
        return path;
    }
    NSString *standard = [path stringByStandardizingPath];
    if (standard.length > 1 && [standard hasSuffix:@"/"]) {
        standard = [standard substringToIndex:standard.length - 1];
    }
    return standard;
}

- (BOOL)addSource:(NSString *)path recursive:(BOOL)recursive
{
    path = [self normalizedPath:path];
    if (path.length == 0) {
        return NO;
    }
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
        return NO;
    }
    NSMutableArray *updated = [NSMutableArray array];
    BOOL replaced = NO;
    for (NSDictionary *source in self.sources) {
        if ([source[@"path"] isEqualToString:path]) {
            [updated addObject:@{ @"path": path, @"recursive": @(recursive) }];
            replaced = YES;
        } else {
            [updated addObject:source];
        }
    }
    if (!replaced) {
        [updated addObject:@{ @"path": path, @"recursive": @(recursive) }];
    }
    self.sources = updated;
    [self saveSources];
    [self reload];
    return YES;
}

- (void)removeSource:(NSString *)path
{
    path = [self normalizedPath:path];
    NSMutableArray *updated = [NSMutableArray array];
    for (NSDictionary *source in self.sources) {
        if (![source[@"path"] isEqualToString:path]) {
            [updated addObject:source];
        }
    }
    self.sources = updated;
    [self saveSources];
    [self reload];
}

- (BOOL)isSourcePath:(NSString *)path
{
    path = [self normalizedPath:path];
    for (NSDictionary *source in self.sources) {
        if ([source[@"path"] isEqualToString:path]) {
            return YES;
        }
    }
    return NO;
}

- (NSDictionary *)sourceForPath:(NSString *)path
{
    path = [self normalizedPath:path];
    for (NSDictionary *source in self.sources) {
        if ([source[@"path"] isEqualToString:path]) {
            return source;
        }
    }
    return nil;
}

- (NSString *)displayNameForSource:(NSDictionary *)source
{
    NSString *path = source[@"path"];
    NSString *name = [path lastPathComponent];
    return name.length > 0 ? name : path;
}

- (NSInteger)countForSource:(NSDictionary *)source
{
    NSString *prefix = [source[@"path"] stringByAppendingString:@"/"];
    NSInteger count = 0;
    for (OVMediaItem *item in self.itemsByPath.allValues) {
        if ([item.path hasPrefix:prefix] || [item.path isEqualToString:source[@"path"]]) {
            count++;
        }
    }
    return count;
}

#pragma mark - Escaneo

- (void)reload
{
    NSArray *sources = [self.sources copy];
    if (_scanning) {
        _needsRescan = YES;
        return;
    }
    self.scanning = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:OVLibraryScanProgressNotification
                                                        object:self];

    dispatch_async(self.scanQueue, ^{
        NSMutableArray *items = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (NSDictionary *source in sources) {
            NSString *path = source[@"path"];
            BOOL recursive = [source[@"recursive"] boolValue];
            [self walkPath:path recursive:recursive depth:0 items:items seen:seen];
        }

        NSMutableDictionary *byPath = [NSMutableDictionary dictionary];
        for (OVMediaItem *item in items) {
            byPath[item.path] = item;
        }
        [self saveCache];

        NSArray *videos = [self sortedItems:[items filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(OVMediaItem *item, NSDictionary *bindings) {
                return item.type == OVMediaTypeVideo;
            }]]];
        NSArray *audio = [self sortedItems:[items filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(OVMediaItem *item, NSDictionary *bindings) {
                return item.type == OVMediaTypeAudio;
            }]]];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = videos;
            self.audio = audio;
            self.itemsByPath = byPath;
            self.scanning = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:OVLibraryDidChangeNotification
                                                                object:self];
            if (self.needsRescan) {
                self.needsRescan = NO;
                [self reload];
            }
        });
    });
}

- (void)walkPath:(NSString *)path
       recursive:(BOOL)recursive
           depth:(NSInteger)depth
           items:(NSMutableArray *)items
            seen:(NSMutableSet *)seen
{
    if (depth > 16 || items.count > 20000) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *names = [fm contentsOfDirectoryAtPath:path error:NULL];
    if (!names) {
        return;
    }
    for (NSString *name in names) {
        if ([name hasPrefix:@"."]) {
            continue;
        }
        NSString *full = [path stringByAppendingPathComponent:name];
        if ([fm destinationOfSymbolicLinkAtPath:full error:NULL] != nil) {
            continue;
        }
        NSDictionary *attrs = [fm attributesOfItemAtPath:full error:NULL];
        NSString *fileType = attrs[NSFileType];
        if ([fileType isEqualToString:NSFileTypeDirectory]) {
            if (recursive) {
                [self walkPath:full recursive:YES depth:depth + 1 items:items seen:seen];
            }
            continue;
        }
        if (![fileType isEqualToString:NSFileTypeRegular]) {
            continue;
        }

        NSString *extension = [name pathExtension].lowercaseString;
        OVMediaType type;
        if ([[OVLibrary videoExtensions] containsObject:extension]) {
            type = OVMediaTypeVideo;
        } else if ([[OVLibrary audioExtensions] containsObject:extension]) {
            type = OVMediaTypeAudio;
        } else {
            continue;
        }
        if ([seen containsObject:full]) {
            continue;
        }
        [seen addObject:full];

        OVMediaItem *item = [[OVMediaItem alloc] initWithPath:full type:type];
        item.size = [attrs[NSFileSize] unsignedLongLongValue];
        item.modified = attrs[NSFileModificationDate] ?: [NSDate date];

        NSDictionary *cached = self.metaCache[full];
        double cachedDuration = 0.0;
        if (cached) {
            unsigned long long cachedSize = [cached[@"size"] unsignedLongLongValue];
            NSTimeInterval cachedDate = [cached[@"mtime"] doubleValue];
            if (cachedSize == item.size &&
                fabs(cachedDate - [item.modified timeIntervalSince1970]) < 2.0) {
                cachedDuration = [cached[@"duration"] doubleValue];
            }
        }
        if (cachedDuration <= 0.0) {
            cachedDuration = [OVLibrary durationForPath:full extension:extension];
        }
        item.duration = cachedDuration;
        item.lastPosition = [self lastPositionForPath:full];

        self.metaCache[full] = @{
            @"size": @(item.size),
            @"mtime": @([item.modified timeIntervalSince1970]),
            @"duration": @(item.duration)
        };
        [items addObject:item];
    }
}

+ (double)durationForPath:(NSString *)path extension:(NSString *)extension
{
    static NSSet *fastExtensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fastExtensions = [NSSet setWithObjects:@"mp4", @"m4v", @"mov", @"mp3", @"m4a",
                          @"m4b", @"wav", @"aif", @"aiff", @"aac", @"3gp", @"caf", nil];
    });
    if (![fastExtensions containsObject:extension]) {
        return 0.0;
    }
    @autoreleasepool {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
        CMTime time = asset.duration;
        if (CMTIME_IS_VALID(time) && CMTIME_IS_NUMERIC(time)) {
            double seconds = CMTimeGetSeconds(time);
            if (isfinite(seconds) && seconds > 0.0) {
                return seconds;
            }
        }
    }
    return 0.0;
}

- (NSArray *)sortedItems:(NSArray *)items
{
    OVSortMode mode = self.sortMode;
    return [items sortedArrayUsingComparator:^NSComparisonResult(OVMediaItem *a, OVMediaItem *b) {
        switch (mode) {
            case OVSortModeDate:
                return [b.modified compare:a.modified];
            case OVSortModeSize:
                if (a.size == b.size) return NSOrderedSame;
                return a.size > b.size ? NSOrderedAscending : NSOrderedDescending;
            case OVSortModeDuration:
                if (a.duration == b.duration) return NSOrderedSame;
                return a.duration > b.duration ? NSOrderedAscending : NSOrderedDescending;
            case OVSortModeName:
            default:
                return [a.title localizedCaseInsensitiveCompare:b.title];
        }
    }];
}

- (NSArray *)itemsForType:(OVMediaType)type
{
    NSArray *items = (type == OVMediaTypeAudio) ? self.audio : self.videos;
    return [self sortedItems:items];
}

- (NSArray *)itemsInFolder:(NSString *)folder recursive:(BOOL)recursive
{
    NSMutableArray *result = [NSMutableArray array];
    NSString *prefix = [folder stringByAppendingString:@"/"];
    for (OVMediaItem *item in self.itemsByPath.allValues) {
        if ([item.path hasPrefix:prefix] &&
            (recursive || [[item.path stringByDeletingLastPathComponent] isEqualToString:folder])) {
            [result addObject:item];
        }
    }
    return [self sortedItems:result];
}

- (OVMediaItem *)itemAtPath:(NSString *)path
{
    return self.itemsByPath[path];
}

- (void)updateDuration:(double)duration forPath:(NSString *)path
{
    if (duration <= 0.0 || path.length == 0) {
        return;
    }
    OVMediaItem *item = self.itemsByPath[path];
    if (item) {
        item.duration = duration;
    }
    dispatch_async(self.scanQueue, ^{
        NSDictionary *old = self.metaCache[path];
        if (old && fabs([old[@"duration"] doubleValue] - duration) < 0.5) {
            return;
        }
        self.metaCache[path] = @{
            @"size": old[@"size"] ?: @(0),
            @"mtime": old[@"mtime"] ?: @([NSDate date].timeIntervalSince1970),
            @"duration": @(duration)
        };
        [self saveCache];
    });
}

#pragma mark - Orden

- (OVSortMode)sortMode
{
    return (OVSortMode)[[NSUserDefaults standardUserDefaults] integerForKey:OVSortModeKey];
}

- (void)setSortMode:(OVSortMode)sortMode
{
    [[NSUserDefaults standardUserDefaults] setInteger:sortMode forKey:OVSortModeKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:OVLibraryDidChangeNotification object:self];
}

#pragma mark - Posiciones

- (double)lastPositionForPath:(NSString *)path
{
    NSDictionary *positions = [[NSUserDefaults standardUserDefaults] dictionaryForKey:OVPositionsKey];
    return [positions[path] doubleValue];
}

- (void)setLastPosition:(double)position forPath:(NSString *)path duration:(double)duration
{
    if (path.length == 0) {
        return;
    }
    NSMutableDictionary *positions =
        [[[NSUserDefaults standardUserDefaults] dictionaryForKey:OVPositionsKey] mutableCopy];
    if (!positions) {
        positions = [NSMutableDictionary dictionary];
    }
    if (position < 10.0 || (duration > 0.0 && position > duration - 15.0)) {
        [positions removeObjectForKey:path];
    } else {
        positions[path] = @(position);
    }
    [[NSUserDefaults standardUserDefaults] setObject:positions forKey:OVPositionsKey];
    OVMediaItem *item = self.itemsByPath[path];
    if (item) {
        BOOL finished = (duration > 0.0 && position > duration - 15.0);
        item.lastPosition = (position < 10.0 || finished) ? 0.0 : position;
    }
}

- (void)clearPositionForPath:(NSString *)path
{
    [self setLastPosition:0.0 forPath:path duration:0.0];
}

#pragma mark - Subtitulos

- (NSString *)subtitlePathForMediaPath:(NSString *)path
{
    NSString *directory = [path stringByDeletingLastPathComponent];
    NSString *base = [[path lastPathComponent] stringByDeletingPathExtension];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    NSArray *subtitleExtensions = [OVLibrary subtitleExtensions];
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSString *name in contents) {
        NSString *extension = [name pathExtension].lowercaseString;
        if (![subtitleExtensions containsObject:extension]) {
            continue;
        }
        NSString *candidateBase = [name stringByDeletingPathExtension];
        if ([candidateBase isEqualToString:base] ||
            [candidateBase hasPrefix:[base stringByAppendingString:@"."]]) {
            [candidates addObject:name];
        }
    }
    [candidates sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (candidates.count == 0) {
        return nil;
    }
    return [directory stringByAppendingPathComponent:candidates[0]];
}

#pragma mark - Historial

- (NSString *)historyKeyForItem:(OVMediaItem *)item
{
    if (item.isNetwork) {
        return item.url.absoluteString ?: item.path;
    }
    return item.path;
}

- (void)recordHistoryForItem:(OVMediaItem *)item
{
    NSString *key = [self historyKeyForItem:item];
    if (key.length == 0) {
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *history = [[defaults arrayForKey:OVHistoryKey] mutableCopy];
    if (!history) {
        history = [NSMutableArray array];
    }

    NSMutableArray *clean = [NSMutableArray array];
    for (id entry in history) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *path = entry[@"path"];
        if (![path isEqualToString:key]) {
            [clean addObject:entry];
        }
    }

    NSDictionary *record = @{
        @"path": key,
        @"title": item.title ?: @"",
        @"type": @(item.type),
        @"network": @(item.isNetwork),
        @"url": item.url.absoluteString ?: @"",
        @"folder": item.folder ?: @"",
        @"duration": @(item.duration),
        @"lastPlayed": @([[NSDate date] timeIntervalSince1970])
    };
    [clean insertObject:record atIndex:0];
    while (clean.count > 100) {
        [clean removeLastObject];
    }
    [defaults setObject:clean forKey:OVHistoryKey];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:OVHistoryDidChangeNotification
                                                        object:self];
}

- (NSArray *)historyItems
{
    NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey:OVHistoryKey];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *record in history) {
        if (![record isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *path = record[@"path"];
        BOOL network = [record[@"network"] boolValue];
        NSString *title = record[@"title"];
        OVMediaType type = (OVMediaType)[record[@"type"] integerValue];

        OVMediaItem *item = nil;
        if (network && path.length > 0) {
            NSURL *url = [NSURL URLWithString:path];
            if (url) {
                item = [[OVMediaItem alloc] initWithNetworkURL:url title:title];
            }
        } else if (path.length > 0) {
            item = [[OVMediaItem alloc] initWithPath:path type:type];
            item.title = title.length > 0 ? title : item.title;
            OVMediaItem *libraryItem = self.itemsByPath[path];
            if (libraryItem) {
                item.duration = libraryItem.duration;
                item.size = libraryItem.size;
                item.lastPosition = libraryItem.lastPosition;
            }
        }
        if (item) {
            [items addObject:item];
        }
    }
    return items;
}

- (void)removeHistoryItemWithPath:(NSString *)path
{
    if (path.length == 0) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *history = [defaults arrayForKey:OVHistoryKey];
    NSMutableArray *clean = [NSMutableArray array];
    for (NSDictionary *record in history) {
        if ([record isKindOfClass:[NSDictionary class]] &&
            ![record[@"path"] isEqualToString:path]) {
            [clean addObject:record];
        }
    }
    [defaults setObject:clean forKey:OVHistoryKey];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:OVHistoryDidChangeNotification
                                                        object:self];
}

- (void)clearHistory
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:OVHistoryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:OVHistoryDidChangeNotification
                                                        object:self];
}

#pragma mark - Ajustes

+ (BOOL)backgroundAudio { return [[NSUserDefaults standardUserDefaults] boolForKey:OVBackgroundAudioKey]; }
+ (void)setBackgroundAudio:(BOOL)value { [[NSUserDefaults standardUserDefaults] setBool:value forKey:OVBackgroundAudioKey]; }
+ (BOOL)resumePlayback { return [[NSUserDefaults standardUserDefaults] boolForKey:OVResumePlaybackKey]; }
+ (void)setResumePlayback:(BOOL)value { [[NSUserDefaults standardUserDefaults] setBool:value forKey:OVResumePlaybackKey]; }
+ (BOOL)hardwareAcceleration { return [[NSUserDefaults standardUserDefaults] boolForKey:OVHardwareAccelerationKey]; }
+ (void)setHardwareAcceleration:(BOOL)value { [[NSUserDefaults standardUserDefaults] setBool:value forKey:OVHardwareAccelerationKey]; }
+ (BOOL)deinterlace { return [[NSUserDefaults standardUserDefaults] boolForKey:OVDeinterlaceKey]; }
+ (void)setDeinterlace:(BOOL)value { [[NSUserDefaults standardUserDefaults] setBool:value forKey:OVDeinterlaceKey]; }
+ (NSString *)subtitleEncoding { return [[NSUserDefaults standardUserDefaults] stringForKey:OVSubtitleEncodingKey] ?: @"UTF-8"; }
+ (void)setSubtitleEncoding:(NSString *)value { [[NSUserDefaults standardUserDefaults] setObject:value forKey:OVSubtitleEncodingKey]; }
+ (NSInteger)networkCaching { return [[NSUserDefaults standardUserDefaults] integerForKey:OVNetworkCachingKey]; }
+ (void)setNetworkCaching:(NSInteger)value { [[NSUserDefaults standardUserDefaults] setInteger:value forKey:OVNetworkCachingKey]; }

+ (NSArray *)videoExtensions
{
    static NSArray *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = @[@"mp4", @"m4v", @"mov", @"mkv", @"avi", @"wmv", @"flv", @"webm",
                       @"ts", @"m2ts", @"mts", @"mpg", @"mpeg", @"mpe", @"3gp", @"3g2",
                       @"ogv", @"ogg", @"divx", @"vob", @"rm", @"rmvb", @"asf", @"f4v",
                       @"mxf", @"wtv", @"dv", @"m2v", @"m1v"];
    });
    return extensions;
}

+ (NSArray *)audioExtensions
{
    static NSArray *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = @[@"mp3", @"m4a", @"m4b", @"aac", @"flac", @"wav", @"aif", @"aiff",
                       @"alac", @"ogg", @"oga", @"opus", @"wma", @"ape", @"mka", @"ac3",
                       @"dts", @"caf", @"amr", @"au", @"mid", @"midi", @"wv", @"tta"];
    });
    return extensions;
}

+ (NSArray *)subtitleExtensions
{
    static NSArray *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = @[@"srt", @"ass", @"ssa", @"vtt", @"sub", @"idx", @"smi", @"sami", @"txt"];
    });
    return extensions;
}

@end
