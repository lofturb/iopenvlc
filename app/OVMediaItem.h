#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, OVMediaType) {
    OVMediaTypeVideo = 0,
    OVMediaTypeAudio = 1
};

@interface OVMediaItem : NSObject

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *folder;
@property (nonatomic, copy) NSString *extension;
@property (nonatomic, assign) OVMediaType type;
@property (nonatomic, assign) unsigned long long size;
@property (nonatomic, strong) NSDate *modified;
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) double lastPosition;

@property (nonatomic, assign) BOOL isNetwork;
@property (nonatomic, strong) NSURL *url;

- (instancetype)initWithPath:(NSString *)path type:(OVMediaType)type;
- (instancetype)initWithNetworkURL:(NSURL *)url title:(NSString *)title;

- (NSString *)subtitleText;
- (NSString *)detailText;

@end
