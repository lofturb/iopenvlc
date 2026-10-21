#import "OVMediaItem.h"
#import "OVTheme.h"

@implementation OVMediaItem

- (instancetype)initWithPath:(NSString *)path type:(OVMediaType)type
{
    self = [super init];
    if (self) {
        _path = [path copy];
        _type = type;
        _extension = [[path pathExtension] lowercaseString];
        _title = [[path lastPathComponent] stringByDeletingPathExtension];
        _folder = [[path stringByDeletingLastPathComponent] lastPathComponent];
        _isNetwork = NO;
        _duration = 0.0;
        _lastPosition = 0.0;
    }
    return self;
}

- (instancetype)initWithNetworkURL:(NSURL *)url title:(NSString *)title
{
    self = [super init];
    if (self) {
        _url = url;
        _path = [url absoluteString];
        _title = title.length > 0 ? [title copy] : [url host] ?: [url absoluteString];
        _folder = [url host] ?: @"Red";
        _extension = [[url pathExtension] lowercaseString];
        _type = OVMediaTypeVideo;
        _isNetwork = YES;
    }
    return self;
}

- (NSString *)subtitleText
{
    if (self.isNetwork) {
        return self.url.host.length > 0 ? self.url.host : @"Secuencia de red";
    }
    NSMutableArray *parts = [NSMutableArray array];
    if (self.folder.length > 0) {
        [parts addObject:self.folder];
    }
    if (self.duration > 0.0) {
        [parts addObject:[OVTheme formatTime:self.duration]];
    }
    if (self.size > 0) {
        [parts addObject:[OVTheme formatBytes:self.size]];
    }
    if (parts.count == 0) {
        return self.extension.uppercaseString;
    }
    return [parts componentsJoinedByString:@"  ·  "];
}

- (NSString *)detailText
{
    if (self.isNetwork) {
        return self.url.absoluteString;
    }
    return self.path;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[OVMediaItem class]]) {
        return NO;
    }
    OVMediaItem *other = (OVMediaItem *)object;
    return [self.path isEqualToString:other.path];
}

- (NSUInteger)hash
{
    return [self.path hash];
}

@end
