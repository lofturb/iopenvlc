#import <Foundation/Foundation.h>
#import "OVMediaItem.h"

extern NSString *const OVLibraryDidChangeNotification;
extern NSString *const OVLibraryScanProgressNotification;
extern NSString *const OVHistoryDidChangeNotification;

typedef NS_ENUM(NSInteger, OVSortMode) {
    OVSortModeName = 0,
    OVSortModeDate,
    OVSortModeSize,
    OVSortModeDuration
};

@interface OVLibrary : NSObject

@property (nonatomic, readonly) NSArray *sources;
@property (nonatomic, readonly) NSArray *videos;
@property (nonatomic, readonly) NSArray *audio;
@property (nonatomic, readonly) BOOL scanning;
@property (nonatomic, assign) OVSortMode sortMode;

+ (instancetype)sharedLibrary;

- (void)reload;
- (NSArray *)itemsForType:(OVMediaType)type;
- (NSArray *)itemsInFolder:(NSString *)folder recursive:(BOOL)recursive;
- (OVMediaItem *)itemAtPath:(NSString *)path;
- (void)updateDuration:(double)duration forPath:(NSString *)path;

- (BOOL)addSource:(NSString *)path recursive:(BOOL)recursive;
- (void)removeSource:(NSString *)path;
- (BOOL)isSourcePath:(NSString *)path;
- (NSDictionary *)sourceForPath:(NSString *)path;
- (NSString *)displayNameForSource:(NSDictionary *)source;
- (NSInteger)countForSource:(NSDictionary *)source;

- (double)lastPositionForPath:(NSString *)path;
- (void)setLastPosition:(double)position forPath:(NSString *)path duration:(double)duration;
- (void)clearPositionForPath:(NSString *)path;

- (NSString *)subtitlePathForMediaPath:(NSString *)path;

- (void)recordHistoryForItem:(OVMediaItem *)item;
- (NSArray *)historyItems;
- (void)removeHistoryItemWithPath:(NSString *)path;
- (void)clearHistory;

+ (BOOL)backgroundAudio;
+ (void)setBackgroundAudio:(BOOL)value;
+ (BOOL)resumePlayback;
+ (void)setResumePlayback:(BOOL)value;
+ (BOOL)hardwareAcceleration;
+ (void)setHardwareAcceleration:(BOOL)value;
+ (BOOL)deinterlace;
+ (void)setDeinterlace:(BOOL)value;
+ (NSString *)subtitleEncoding;
+ (void)setSubtitleEncoding:(NSString *)value;
+ (NSInteger)networkCaching;
+ (void)setNetworkCaching:(NSInteger)value;

+ (NSArray *)videoExtensions;
+ (NSArray *)audioExtensions;
+ (NSArray *)subtitleExtensions;

@end
