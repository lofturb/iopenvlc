#import <Foundation/Foundation.h>
#import "OVMediaItem.h"

extern NSString *const OVPlaylistsDidChangeNotification;

@interface OVPlaylistStore : NSObject

+ (instancetype)sharedStore;

@property (nonatomic, readonly) NSArray *playlists;

- (NSInteger)count;
- (NSDictionary *)playlistAtIndex:(NSInteger)index;
- (NSString *)nameForPlaylistAtIndex:(NSInteger)index;
- (NSArray *)mediaItemsForPlaylistAtIndex:(NSInteger)index;

- (NSInteger)createPlaylistWithName:(NSString *)name;
- (void)renamePlaylistAtIndex:(NSInteger)index name:(NSString *)name;
- (void)deletePlaylistAtIndex:(NSInteger)index;

- (BOOL)addItem:(OVMediaItem *)item toPlaylistAtIndex:(NSInteger)index;
- (void)removeItemAtIndex:(NSInteger)itemIndex fromPlaylistAtIndex:(NSInteger)playlistIndex;

@end
