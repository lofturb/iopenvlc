#import "OVPlaylistStore.h"

NSString *const OVPlaylistsDidChangeNotification = @"OVPlaylistsDidChangeNotification";

static NSString *const OVPlaylistsKey = @"OVSavedPlaylists";

@interface OVPlaylistStore ()

@property (nonatomic, strong) NSMutableArray *mutablePlaylists;

@end

@implementation OVPlaylistStore

+ (instancetype)sharedStore
{
    static OVPlaylistStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[OVPlaylistStore alloc] init];
    });
    return store;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self load];
    }
    return self;
}

- (NSArray *)playlists
{
    return [self.mutablePlaylists copy];
}

- (NSInteger)count
{
    return (NSInteger)self.mutablePlaylists.count;
}

#pragma mark - Persistencia

- (void)load
{
    self.mutablePlaylists = [NSMutableArray array];
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:OVPlaylistsKey];
    for (id entry in saved) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *name = entry[@"name"];
        NSArray *items = entry[@"items"];
        if (![name isKindOfClass:[NSString class]] || name.length == 0) {
            continue;
        }
        if (![items isKindOfClass:[NSArray class]]) {
            items = @[];
        }
        NSMutableArray *clean = [NSMutableArray array];
        for (id rawItem in items) {
            if ([rawItem isKindOfClass:[NSDictionary class]] &&
                [rawItem[@"path"] isKindOfClass:[NSString class]]) {
                [clean addObject:[rawItem mutableCopy]];
            }
        }
        [self.mutablePlaylists addObject:[@{ @"name": name,
                                             @"items": clean } mutableCopy]];
    }
}

- (void)save
{
    [[NSUserDefaults standardUserDefaults] setObject:self.mutablePlaylists
                                              forKey:OVPlaylistsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:OVPlaylistsDidChangeNotification
                                                        object:self];
}

#pragma mark - Consulta

- (NSDictionary *)playlistAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.mutablePlaylists.count) {
        return nil;
    }
    return self.mutablePlaylists[index];
}

- (NSString *)nameForPlaylistAtIndex:(NSInteger)index
{
    return [self playlistAtIndex:index][@"name"] ?: @"Lista";
}

- (NSArray *)mediaItemsForPlaylistAtIndex:(NSInteger)index
{
    NSDictionary *playlist = [self playlistAtIndex:index];
    NSArray *rawItems = playlist[@"items"];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *raw in rawItems) {
        NSString *path = raw[@"path"];
        NSString *title = raw[@"title"];
        BOOL network = [raw[@"network"] boolValue];
        NSString *urlString = raw[@"url"];
        OVMediaType type = (OVMediaType)[raw[@"type"] integerValue];

        OVMediaItem *item = nil;
        if (network && urlString.length > 0) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) {
                item = [[OVMediaItem alloc] initWithNetworkURL:url title:title];
            }
        } else if (path.length > 0) {
            item = [[OVMediaItem alloc] initWithPath:path type:type];
            item.title = title.length > 0 ? title : item.title;
        }
        if (item) {
            item.duration = [raw[@"duration"] doubleValue];
            item.size = [raw[@"size"] unsignedLongLongValue];
            [items addObject:item];
        }
    }
    return items;
}

#pragma mark - Mutaciones

- (NSInteger)createPlaylistWithName:(NSString *)name
{
    NSString *clean = [name stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) {
        clean = [NSString stringWithFormat:@"Lista %lu",
                 (unsigned long)(self.mutablePlaylists.count + 1)];
    }
    NSMutableDictionary *playlist = [@{ @"name": clean,
                                        @"items": [NSMutableArray array] } mutableCopy];
    [self.mutablePlaylists addObject:playlist];
    [self save];
    return (NSInteger)self.mutablePlaylists.count - 1;
}

- (void)renamePlaylistAtIndex:(NSInteger)index name:(NSString *)name
{
    NSMutableDictionary *playlist = [self playlistAtIndex:index];
    NSString *clean = [name stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!playlist || clean.length == 0) {
        return;
    }
    playlist[@"name"] = clean;
    [self save];
}

- (void)deletePlaylistAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.mutablePlaylists.count) {
        return;
    }
    [self.mutablePlaylists removeObjectAtIndex:index];
    [self save];
}

- (BOOL)addItem:(OVMediaItem *)item toPlaylistAtIndex:(NSInteger)index
{
    if (!item || index < 0 || index >= (NSInteger)self.mutablePlaylists.count) {
        return NO;
    }
    NSMutableDictionary *playlist = self.mutablePlaylists[index];
    NSMutableArray *items = playlist[@"items"];
    NSMutableDictionary *raw = [@{
        @"path": item.path ?: @"",
        @"title": item.title ?: @"",
        @"type": @(item.type),
        @"network": @(item.isNetwork),
        @"url": item.url.absoluteString ?: @"",
        @"duration": @(item.duration),
        @"size": @(item.size)
    } mutableCopy];
    [items addObject:raw];
    playlist[@"items"] = items;
    [self save];
    return YES;
}

- (void)removeItemAtIndex:(NSInteger)itemIndex fromPlaylistAtIndex:(NSInteger)playlistIndex
{
    NSMutableDictionary *playlist = [self playlistAtIndex:playlistIndex];
    NSMutableArray *items = playlist[@"items"];
    if (itemIndex < 0 || itemIndex >= (NSInteger)items.count) {
        return;
    }
    [items removeObjectAtIndex:itemIndex];
    playlist[@"items"] = items;
    [self save];
}

@end
