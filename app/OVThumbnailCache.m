#import "OVThumbnailCache.h"
#import <MobileVLCKit/MobileVLCKit.h>

@interface OVThumbnailJob : NSObject <VLCMediaThumbnailerDelegate>
@property (nonatomic, strong) VLCMediaThumbnailer *thumbnailer;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, copy) void (^completion)(UIImage *image);
@property (nonatomic, copy) void (^finishBlock)(void);
@property (nonatomic, assign) BOOL finished;
- (void)finishWithImage:(UIImage *)image;
@end

@interface OVThumbnailCache ()
@property (nonatomic, strong) NSCache *memory;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSMutableSet *jobs;
@property (nonatomic, strong) NSMutableSet *failed;
@end

@implementation OVThumbnailCache

+ (instancetype)sharedCache
{
    static OVThumbnailCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[OVThumbnailCache alloc] init];
    });
    return cache;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _memory = [[NSCache alloc] init];
        _memory.countLimit = 120;
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
        _jobs = [NSMutableSet set];
        _failed = [NSMutableSet set];
    }
    return self;
}

- (NSString *)directory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *base = paths.count > 0 ? paths[0] : NSTemporaryDirectory();
    NSString *dir = [base stringByAppendingPathComponent:@"OpenVLC/Thumbs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return dir;
}

- (NSString *)hashForString:(NSString *)string
{
    unsigned long long hash = 1469598103934665603ULL;
    const char *bytes = [string UTF8String];
    while (bytes && *bytes) {
        hash ^= (unsigned long long)(unsigned char)*bytes++;
        hash *= 1099511628211ULL;
    }
    return [NSString stringWithFormat:@"%016llx", hash];
}

- (NSString *)cachePathForPath:(NSString *)path
{
    return [[self directory] stringByAppendingPathComponent:
            [[self hashForString:path] stringByAppendingString:@".jpg"]];
}

- (void)thumbnailForItem:(OVMediaItem *)item completion:(void (^)(UIImage *image))completion
{
    void (^deliver)(UIImage *) = ^(UIImage *image) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image);
            });
        }
    };

    if (!item || item.isNetwork || item.type == OVMediaTypeAudio || item.path.length == 0) {
        deliver(nil);
        return;
    }

    UIImage *cached = [self.memory objectForKey:item.path];
    if (cached) {
        deliver(cached);
        return;
    }
    if ([self.failed containsObject:item.path]) {
        deliver(nil);
        return;
    }

    NSString *cachePath = [self cachePathForPath:item.path];
    UIImage *disk = [UIImage imageWithContentsOfFile:cachePath];
    if (disk) {
        [self.memory setObject:disk forKey:item.path];
        deliver(disk);
        return;
    }

    OVThumbnailJob *job = [[OVThumbnailJob alloc] init];
    job.path = item.path;
    job.cachePath = cachePath;
    job.completion = completion;
    [self.jobs addObject:job];

    __weak OVThumbnailCache *weakSelf = self;
    __weak OVThumbnailJob *weakJob = job;

    [self.queue addOperationWithBlock:^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        job.finishBlock = ^{
            dispatch_semaphore_signal(semaphore);
        };

        VLCMedia *media = [VLCMedia mediaWithURL:[NSURL fileURLWithPath:item.path]];
        [media addOption:@"--no-video-title-show"];
        VLCMediaThumbnailer *thumbnailer =
            [VLCMediaThumbnailer thumbnailerWithMedia:media andDelegate:job];
        thumbnailer.thumbnailWidth = 400.0;
        thumbnailer.thumbnailHeight = 225.0;
        thumbnailer.snapshotPosition = 0.18;
        job.thumbnailer = thumbnailer;
        [thumbnailer fetchThumbnail];

        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC));

        OVThumbnailJob *strongJob = weakJob;
        if (strongJob && !strongJob.finished) {
            [strongJob finishWithImage:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            OVThumbnailCache *strongSelf = weakSelf;
            [strongSelf.jobs removeObject:strongJob];
        });
    }];
}

- (void)storeImage:(UIImage *)image forPath:(NSString *)path cachePath:(NSString *)cachePath
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            [self.memory setObject:image forKey:path];
        } else {
            [self.failed addObject:path];
        }
    });
    if (image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSData *data = UIImageJPEGRepresentation(image, 0.82);
            [data writeToFile:cachePath atomically:YES];
        });
    }
}

- (void)clearCache
{
    [self.memory removeAllObjects];
    [self.failed removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:[self directory] error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self directory]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

@end

@implementation OVThumbnailJob

- (void)mediaThumbnailer:(VLCMediaThumbnailer *)mediaThumbnailer
      didFinishThumbnail:(CGImageRef)thumbnail
{
    UIImage *image = thumbnail ? [UIImage imageWithCGImage:thumbnail] : nil;
    [self finishWithImage:image];
}

- (void)mediaThumbnailerDidTimeOut:(VLCMediaThumbnailer *)mediaThumbnailer
{
    [self finishWithImage:nil];
}

- (void)finishWithImage:(UIImage *)image
{
    if (self.finished) {
        return;
    }
    self.finished = YES;

    OVThumbnailCache *cache = [OVThumbnailCache sharedCache];
    [cache storeImage:image forPath:self.path cachePath:self.cachePath];

    if (self.completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completion(image);
        });
    }
    if (self.finishBlock) {
        self.finishBlock();
        self.finishBlock = nil;
    }
    self.thumbnailer = nil;
}

@end
