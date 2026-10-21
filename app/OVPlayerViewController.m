#import "OVPlayerViewController.h"
#import "OVPlaylistViewController.h"
#import "OVFolderBrowserViewController.h"
#import "OVLibrary.h"
#import "OVMediaItem.h"
#import "OVTheme.h"

#import <MobileVLCKit/MobileVLCKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>

typedef NS_ENUM(NSInteger, OVPlayerGlyphType) {
    OVPlayerGlyphPlay = 0,
    OVPlayerGlyphPause,
    OVPlayerGlyphNext,
    OVPlayerGlyphPrevious,
    OVPlayerGlyphClose
};

typedef NS_ENUM(NSInteger, OVPanMode) {
    OVPanModeUndecided = 0,
    OVPanModeSeek,
    OVPanModeBrightness,
    OVPanModeVolume
};

static UIImage *OVPlayerGlyph(OVPlayerGlyphType type, CGFloat size)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *black = [UIColor blackColor];
    CGContextSetFillColorWithColor(ctx, black.CGColor);
    CGContextSetStrokeColorWithColor(ctx, black.CGColor);

    if (type == OVPlayerGlyphPlay) {
        CGContextMoveToPoint(ctx, size * 0.34, size * 0.22);
        CGContextAddLineToPoint(ctx, size * 0.34, size * 0.78);
        CGContextAddLineToPoint(ctx, size * 0.80, size * 0.50);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    } else if (type == OVPlayerGlyphPause) {
        CGContextFillRect(ctx, CGRectMake(size * 0.33, size * 0.24, size * 0.12, size * 0.52));
        CGContextFillRect(ctx, CGRectMake(size * 0.55, size * 0.24, size * 0.12, size * 0.52));
    } else if (type == OVPlayerGlyphNext || type == OVPlayerGlyphPrevious) {
        BOOL next = (type == OVPlayerGlyphNext);
        CGFloat triLeft = next ? size * 0.26 : size * 0.38;
        CGFloat triRight = next ? size * 0.66 : size * 0.78;
        CGContextMoveToPoint(ctx, triLeft, size * 0.24);
        CGContextAddLineToPoint(ctx, triLeft, size * 0.76);
        CGContextAddLineToPoint(ctx, triRight, size * 0.50);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        CGFloat barX = next ? size * 0.70 : size * 0.22;
        CGContextFillRect(ctx, CGRectMake(barX, size * 0.24, size * 0.08, size * 0.52));
    } else if (type == OVPlayerGlyphClose) {
        CGContextSetLineWidth(ctx, size * 0.09);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextMoveToPoint(ctx, size * 0.28, size * 0.28);
        CGContextAddLineToPoint(ctx, size * 0.72, size * 0.72);
        CGContextMoveToPoint(ctx, size * 0.72, size * 0.28);
        CGContextAddLineToPoint(ctx, size * 0.28, size * 0.72);
        CGContextStrokePath(ctx);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface OVPlayerViewController () <VLCMediaPlayerDelegate, VLCMediaListPlayerDelegate,
                                     UIGestureRecognizerDelegate, UIScrollViewDelegate>

// Playback
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) VLCMediaListPlayer *listPlayer;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL resumeApplied;
@property (nonatomic, assign) BOOL durationReported;
@property (nonatomic, assign) BOOL errorShown;
@property (nonatomic, assign) BOOL deinterlaceApplied;
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) CFTimeInterval lastPositionSave;
@property (nonatomic, assign) CFTimeInterval lastNowPlayingUpdate;
@property (nonatomic, assign) BOOL scrubbing;
@property (nonatomic, assign) BOOL videoVisible;
@property (nonatomic, copy) NSString *lastHistoryPath;
@property (nonatomic, strong) NSTimer *sleepTimer;

// Views
@property (nonatomic, strong) UIView *videoView;
@property (nonatomic, strong) UIView *audioView;
@property (nonatomic, strong) UIImageView *audioIcon;
@property (nonatomic, strong) UILabel *audioTitle;
@property (nonatomic, strong) UILabel *audioSubtitle;
@property (nonatomic, strong) UIView *controlsView;
@property (nonatomic, strong) UIVisualEffectView *topBlur;
@property (nonatomic, strong) UIVisualEffectView *bottomBlur;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *optionsButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *previousButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, strong) UISlider *timeSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *audioButton;
@property (nonatomic, strong) UIButton *subtitleButton;
@property (nonatomic, strong) UIButton *speedButton;
@property (nonatomic, strong) UIButton *aspectButton;
@property (nonatomic, strong) UIButton *playlistButton;
@property (nonatomic, strong) UIButton *repeatButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *hudLabel;
@property (nonatomic, assign) NSUInteger hudGeneration;

// State
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, assign) NSUInteger controlsGeneration;
@property (nonatomic, assign) float preferredRate;
@property (nonatomic, copy) NSString *preferredAspect;
@property (nonatomic, assign) float originalBrightness;
@property (nonatomic, assign) BOOL wasPlayingBeforeInterruption;

// Gestures
@property (nonatomic, assign) OVPanMode panMode;
@property (nonatomic, assign) double panStartTime;
@property (nonatomic, assign) int panStartVolume;
@property (nonatomic, assign) CGFloat panStartBrightness;
@property (nonatomic, assign) double panTargetTime;
@property (nonatomic, assign) float pinchStartScale;

// Remote commands
@property (nonatomic, strong) NSArray *remoteCommandTokens;

@end

@implementation OVPlayerViewController

#pragma mark - Init

- (instancetype)initWithItems:(NSArray *)items startIndex:(NSInteger)startIndex
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _items = [items copy] ?: @[];
        _currentIndex = MAX(0, MIN(startIndex, (NSInteger)_items.count - 1));
        _preferredRate = 1.0f;
        _preferredAspect = @"default";
        _videoVisible = YES;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];
    self.modalPresentationCapturesStatusBarAppearance = YES;
    self.originalBrightness = [UIScreen mainScreen].brightness;
    self.duration = [self currentItem].duration;

    [self buildVideoLayer];
    [self buildAudioLayer];
    [self buildControls];
    [self buildGestures];
    [self buildPlayback];
    [self registerNotifications];

    self.controlsVisible = YES;
    self.controlsView.alpha = 1.0;
    [self updateForCurrentItem];
    [self updatePlaybackStateUI];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(handleTap:)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                               action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.delegate = self;
    [self.view addGestureRecognizer:doubleTap];
    [tap requireGestureRecognizerToFail:doubleTap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(handlePan:)];
    pan.delegate = self;
    [self.view addGestureRecognizer:pan];

    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                               action:@selector(handlePinch:)];
    pinch.delegate = self;
    [self.view addGestureRecognizer:pinch];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [[UIScreen mainScreen] setBrightness:MAX(0.05, self.originalBrightness)];
    [self activateAudioSession];
    [self restoreVolume];
    [self setupRemoteCommands];
    if (!self.started) {
        self.started = YES;
        [self showSpinnerWithText:@"Cargando…"];
        [self.listPlayer playItemAtNumber:@(self.currentIndex)];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) {
        [self stopPlayback];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.sleepTimer invalidate];
    self.sleepTimer = nil;
    [self teardownRemoteCommands];
    [self.listPlayer stop];
    self.listPlayer.mediaPlayer.delegate = nil;
    self.listPlayer.delegate = nil;
    self.listPlayer.mediaPlayer.drawable = nil;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    self.videoView.frame = self.view.bounds;
    self.audioView.frame = self.view.bounds;
    self.controlsView.frame = self.view.bounds;

    self.topBar.frame = CGRectMake(0, 0, width, 60.0);
    self.topBlur.frame = self.topBar.frame;
    self.closeButton.frame = CGRectMake(8.0, 6.0, 48.0, 48.0);
    self.optionsButton.frame = CGRectMake(width - 56.0, 6.0, 48.0, 48.0);
    self.titleLabel.frame = CGRectMake(64.0, 8.0, width - 128.0, 24.0);
    self.subtitleLabel.frame = CGRectMake(64.0, 32.0, width - 128.0, 18.0);

    CGFloat bottomHeight = 136.0;
    self.bottomBar.frame = CGRectMake(0, height - bottomHeight, width, bottomHeight);
    self.bottomBlur.frame = self.bottomBar.frame;

    self.currentTimeLabel.frame = CGRectMake(14.0, 6.0, 58.0, 24.0);
    self.durationLabel.frame = CGRectMake(width - 72.0, 6.0, 58.0, 24.0);
    self.timeSlider.frame = CGRectMake(74.0, 4.0, width - 148.0, 28.0);

    CGFloat centerX = width / 2.0;
    self.playButton.frame = CGRectMake(centerX - 28.0, 38.0, 56.0, 56.0);
    self.previousButton.frame = CGRectMake(centerX - 112.0, 46.0, 44.0, 40.0);
    self.nextButton.frame = CGRectMake(centerX + 68.0, 46.0, 44.0, 40.0);
    self.backButton.frame = CGRectMake(centerX - 170.0, 50.0, 48.0, 32.0);
    self.forwardButton.frame = CGRectMake(centerX + 122.0, 50.0, 48.0, 32.0);

    CGFloat secondaryY = 102.0;
    CGFloat secondaryWidth = (width - 24.0) / 6.0;
    NSArray *secondaryButtons = @[self.audioButton, self.subtitleButton, self.speedButton,
                                  self.aspectButton, self.playlistButton, self.repeatButton];
    for (NSInteger i = 0; i < secondaryButtons.count; i++) {
        UIButton *button = secondaryButtons[i];
        button.frame = CGRectMake(12.0 + i * secondaryWidth, secondaryY, secondaryWidth, 28.0);
    }

    CGFloat iconSize = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 104.0 : 72.0;
    self.audioIcon.frame = CGRectMake((width - iconSize) / 2.0, height * 0.30, iconSize, iconSize);
    self.audioTitle.frame = CGRectMake(40.0, height * 0.30 + iconSize + 26.0, width - 80.0, 40.0);
    self.audioSubtitle.frame = CGRectMake(40.0, height * 0.30 + iconSize + 70.0, width - 80.0, 24.0);

    self.spinner.center = CGPointMake(width / 2.0, height / 2.0 - 26.0);
    self.statusLabel.frame = CGRectMake(40.0, height / 2.0 + 8.0, width - 80.0, 44.0);
    self.hudLabel.frame = CGRectMake((width - 260.0) / 2.0, height * 0.22, 260.0, 46.0);
}

#pragma mark - View construction

- (void)buildVideoLayer
{
    self.videoView = [[UIView alloc] initWithFrame:CGRectZero];
    self.videoView.backgroundColor = [UIColor blackColor];
    self.videoView.userInteractionEnabled = YES;
    [self.view addSubview:self.videoView];
}

- (void)buildAudioLayer
{
    self.audioView = [[UIView alloc] initWithFrame:CGRectZero];
    self.audioView.backgroundColor = [OVTheme background];
    self.audioView.hidden = YES;
    [self.view addSubview:self.audioView];

    self.audioIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.audioIcon.image = [OVTheme tabIcon:OVTabIconMusic];
    self.audioIcon.tintColor = [OVTheme orange];
    self.audioIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.audioView addSubview:self.audioIcon];

    self.audioTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.audioTitle.textColor = [OVTheme text];
    self.audioTitle.font = [OVTheme font:24.0 weight:UIFontWeightSemibold];
    self.audioTitle.textAlignment = NSTextAlignmentCenter;
    self.audioTitle.numberOfLines = 2;
    [self.audioView addSubview:self.audioTitle];

    self.audioSubtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.audioSubtitle.textColor = [OVTheme secondaryText];
    self.audioSubtitle.font = [OVTheme font:14.0 weight:UIFontWeightRegular];
    self.audioSubtitle.textAlignment = NSTextAlignmentCenter;
    self.audioSubtitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.audioView addSubview:self.audioSubtitle];
}

- (void)buildControls
{
    self.controlsView = [[UIView alloc] initWithFrame:CGRectZero];
    self.controlsView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.controlsView];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.topBlur = [[UIVisualEffectView alloc] initWithEffect:blur];
    [self.controlsView addSubview:self.topBlur];
    self.bottomBlur = [[UIVisualEffectView alloc] initWithEffect:blur];
    [self.controlsView addSubview:self.bottomBlur];

    self.topBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.topBar.backgroundColor = [[OVTheme background] colorWithAlphaComponent:0.25];
    [self.controlsView addSubview:self.topBar];

    self.bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomBar.backgroundColor = [[OVTheme background] colorWithAlphaComponent:0.25];
    [self.controlsView addSubview:self.bottomBar];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setImage:OVPlayerGlyph(OVPlayerGlyphClose, 22.0) forState:UIControlStateNormal];
    self.closeButton.tintColor = [OVTheme text];
    self.closeButton.accessibilityLabel = @"Cerrar";
    [self.closeButton addTarget:self action:@selector(closePlayer)
               forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];

    self.optionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.optionsButton setTitle:@"···" forState:UIControlStateNormal];
    [self.optionsButton setTitleColor:[OVTheme text] forState:UIControlStateNormal];
    self.optionsButton.titleLabel.font = [OVTheme font:26.0 weight:UIFontWeightBold];
    self.optionsButton.accessibilityLabel = @"Opciones";
    [self.optionsButton addTarget:self action:@selector(showOptions)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.optionsButton];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.textColor = [OVTheme text];
    self.titleLabel.font = [OVTheme font:16.0 weight:UIFontWeightSemibold];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.topBar addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.textColor = [OVTheme secondaryText];
    self.subtitleLabel.font = [OVTheme font:11.0 weight:UIFontWeightRegular];
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.topBar addSubview:self.subtitleLabel];

    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playButton.backgroundColor = [OVTheme orange];
    self.playButton.layer.cornerRadius = 28.0;
    self.playButton.tintColor = [UIColor whiteColor];
    [self.playButton setImage:OVPlayerGlyph(OVPlayerGlyphPause, 26.0) forState:UIControlStateNormal];
    [self.playButton addTarget:self action:@selector(togglePlayPause)
              forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.playButton];

    self.previousButton = [self glyphButton:OVPlayerGlyphPrevious action:@selector(playPrevious)];
    [self.bottomBar addSubview:self.previousButton];

    self.nextButton = [self glyphButton:OVPlayerGlyphNext action:@selector(playNext)];
    [self.bottomBar addSubview:self.nextButton];

    self.backButton = [self jumpButtonWithTitle:@"-10" action:@selector(seekBackward)];
    [self.bottomBar addSubview:self.backButton];

    self.forwardButton = [self jumpButtonWithTitle:@"+10" action:@selector(seekForward)];
    [self.bottomBar addSubview:self.forwardButton];

    self.currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.textColor = [OVTheme text];
    self.currentTimeLabel.font = [OVTheme font:12.0 weight:UIFontWeightMedium];
    self.currentTimeLabel.textAlignment = NSTextAlignmentRight;
    [self.bottomBar addSubview:self.currentTimeLabel];

    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.durationLabel.text = @"--:--";
    self.durationLabel.textColor = [OVTheme secondaryText];
    self.durationLabel.font = [OVTheme font:12.0 weight:UIFontWeightMedium];
    [self.bottomBar addSubview:self.durationLabel];

    self.timeSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.timeSlider.minimumValue = 0.0f;
    self.timeSlider.maximumValue = 1.0f;
    self.timeSlider.value = 0.0f;
    self.timeSlider.minimumTrackTintColor = [OVTheme orange];
    self.timeSlider.maximumTrackTintColor = [[OVTheme text] colorWithAlphaComponent:0.22];
    self.timeSlider.thumbTintColor = [OVTheme orange];
    [self.timeSlider addTarget:self action:@selector(sliderTouchDown)
              forControlEvents:UIControlEventTouchDown];
    [self.timeSlider addTarget:self action:@selector(sliderChanged)
              forControlEvents:UIControlEventValueChanged];
    [self.timeSlider addTarget:self action:@selector(sliderTouchUp)
              forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                 UIControlEventTouchCancel];
    [self.bottomBar addSubview:self.timeSlider];

    self.audioButton = [self secondaryButtonWithTitle:@"Audio" action:@selector(showAudioTracks)];
    self.subtitleButton = [self secondaryButtonWithTitle:@"Subs" action:@selector(showSubtitles)];
    self.speedButton = [self secondaryButtonWithTitle:@"1.0×" action:@selector(showSpeedMenu)];
    self.aspectButton = [self secondaryButtonWithTitle:@"Aspecto" action:@selector(showAspectMenu)];
    self.playlistButton = [self secondaryButtonWithTitle:@"Lista" action:@selector(showPlaylist)];
    self.repeatButton = [self secondaryButtonWithTitle:@"Repetir" action:@selector(showRepeatMenu)];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                    UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.textColor = [OVTheme secondaryText];
    self.statusLabel.font = [OVTheme font:14.0 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.hidden = YES;
    [self.view addSubview:self.statusLabel];

    self.hudLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.hudLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
    self.hudLabel.textColor = [OVTheme text];
    self.hudLabel.font = [OVTheme font:15.0 weight:UIFontWeightSemibold];
    self.hudLabel.textAlignment = NSTextAlignmentCenter;
    self.hudLabel.layer.cornerRadius = 10.0;
    self.hudLabel.clipsToBounds = YES;
    self.hudLabel.alpha = 0.0;
    [self.view addSubview:self.hudLabel];
}

- (UIButton *)glyphButton:(OVPlayerGlyphType)glyph action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:OVPlayerGlyph(glyph, 26.0) forState:UIControlStateNormal];
    button.tintColor = [OVTheme text];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)jumpButtonWithTitle:(NSString *)title action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[OVTheme text] forState:UIControlStateNormal];
    button.titleLabel.font = [OVTheme font:12.0 weight:UIFontWeightSemibold];
    button.layer.borderColor = [[OVTheme text] colorWithAlphaComponent:0.28].CGColor;
    button.layer.borderWidth = 1.0;
    button.layer.cornerRadius = 8.0;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)secondaryButtonWithTitle:(NSString *)title action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[OVTheme secondaryText] forState:UIControlStateNormal];
    button.titleLabel.font = [OVTheme font:12.0 weight:UIFontWeightSemibold];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:button];
    return button;
}

- (void)buildGestures
{
    // Gestures are attached to the controller's view so they work with the controls
    // visible as well. UIControl touches are filtered out in the delegate.
}

- (void)buildPlayback
{
    self.listPlayer = [[VLCMediaListPlayer alloc] initWithDrawable:self.videoView];
    self.listPlayer.repeatMode = VLCDoNotRepeat;
    self.listPlayer.delegate = self;
    self.listPlayer.mediaPlayer.delegate = self;

    VLCMediaList *list = [[VLCMediaList alloc] init];
    for (OVMediaItem *item in self.items) {
        VLCMedia *media = nil;
        if (item.isNetwork && item.url) {
            media = [VLCMedia mediaWithURL:item.url];
        } else if (item.url) {
            media = [VLCMedia mediaWithURL:item.url];
        } else if (item.path.length > 0) {
            media = [VLCMedia mediaWithPath:item.path];
        }
        if (!media) {
            media = [VLCMedia mediaWithPath:@""];
        }

        [media addOption:@"--no-video-title-show"];

        if (item.isNetwork) {
            NSInteger caching = [OVLibrary networkCaching];
            if (caching > 0) {
                [media addOption:[NSString stringWithFormat:@"--network-caching=%ld",
                                  (long)caching]];
                [media addOption:[NSString stringWithFormat:@"--live-caching=%ld",
                                  (long)caching]];
            }
        } else {
            // Los archivos locales no necesitan el búfer de red. Un caché pequeño
            // acelera el arranque y evita pausas al buscar dentro del archivo.
            [media addOption:@"--file-caching=300"];
            [media addOption:@"--disc-caching=300"];
        }
        if (![OVLibrary hardwareAcceleration]) {
            [media addOption:@"--avcodec-hw=none"];
        }
        NSString *encoding = [OVLibrary subtitleEncoding];
        if (encoding.length > 0) {
            [media addOption:[NSString stringWithFormat:@"--subsdec-encoding=%@", encoding]];
        }
        if ([OVLibrary deinterlace]) {
            [media addOption:@"--deinterlace=1"];
        }
        [list addMedia:media];
    }
    self.listPlayer.mediaList = list;
}

- (void)registerNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(handleInterruption:)
                   name:AVAudioSessionInterruptionNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleAppBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
}

- (void)activateAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:NULL];
    [session setActive:YES error:NULL];
}

- (void)restoreVolume
{
    NSNumber *stored = [[NSUserDefaults standardUserDefaults] objectForKey:@"OVVolume"];
    int volume = stored ? stored.intValue : 100;
    self.listPlayer.mediaPlayer.audio.volume = MAX(0, MIN(200, volume));
}

#pragma mark - Current item

- (OVMediaItem *)currentItem
{
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.items.count) {
        return nil;
    }
    return self.items[self.currentIndex];
}

- (BOOL)isPlaying
{
    return self.listPlayer.mediaPlayer.isPlaying;
}

- (void)updateForCurrentItem
{
    OVMediaItem *item = [self currentItem];
    if (!item) {
        return;
    }
    NSString *historyKey = item.isNetwork ? item.url.absoluteString : item.path;
    if (historyKey.length > 0 && ![historyKey isEqualToString:self.lastHistoryPath]) {
        self.lastHistoryPath = historyKey;
        [[OVLibrary sharedLibrary] recordHistoryForItem:item];
    }

    self.titleLabel.text = item.title;
    self.subtitleLabel.text = item.isNetwork
        ? (item.url.absoluteString ?: @"Red")
        : item.folder;
    self.audioTitle.text = item.title;
    self.audioSubtitle.text = item.isNetwork ? @"Reproducción por red" : item.folder;

    self.resumeApplied = NO;
    self.durationReported = NO;
    self.errorShown = NO;
    self.deinterlaceApplied = NO;
    self.lastPositionSave = 0.0;
    self.lastNowPlayingUpdate = 0.0;
    self.duration = item.duration;
    self.durationLabel.text = item.duration > 0.0
        ? [OVTheme formatTime:item.duration] : @"--:--";
    self.currentTimeLabel.text = @"00:00";
    self.timeSlider.value = 0.0f;
    self.statusLabel.hidden = YES;
    self.spinner.hidden = YES;

    self.playlistButton.enabled = self.items.count > 1;
    self.previousButton.enabled = self.currentIndex > 0;
    self.nextButton.enabled = self.currentIndex + 1 < (NSInteger)self.items.count;

    [self updateRepeatButton];    [self updateSpeedButton];
    [self updateNowPlayingInfo];
}

- (void)prepareForIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.items.count) {
        return;
    }
    self.currentIndex = index;
    [self updateForCurrentItem];
    [self updatePlaybackStateUI];
}

#pragma mark - Playback control

- (void)togglePlayPause
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    if (player.isPlaying) {
        [self saveCurrentPosition];
        [self.listPlayer pause];
        [self showControls];
    } else {
        if (player.state == VLCMediaPlayerStateStopped ||
            player.state == VLCMediaPlayerStateEnded ||
            player.state == VLCMediaPlayerStateError) {
            [self prepareForIndex:self.currentIndex];
            [self.listPlayer playItemAtNumber:@(self.currentIndex)];
        } else {
            [self.listPlayer play];
        }
        [self scheduleAutoHide];
    }
    [self updatePlayButton];
}

- (void)playPrevious
{
    if (self.currentIndex > 0) {
        [self saveCurrentPosition];
        [self prepareForIndex:self.currentIndex - 1];
        [self.listPlayer playItemAtNumber:@(self.currentIndex)];
    } else {
        [self seekToTime:0.0];
    }
}

- (void)playNext
{
    if (self.currentIndex + 1 < (NSInteger)self.items.count) {
        [self saveCurrentPosition];
        [self prepareForIndex:self.currentIndex + 1];
        [self.listPlayer playItemAtNumber:@(self.currentIndex)];
    } else {
        [OVTheme showToast:@"No hay más elementos en la lista" inView:self.view];
    }
}

- (void)seekBackward
{
    [self seekBySeconds:-10.0];
}

- (void)seekForward
{
    [self seekBySeconds:10.0];
}

- (void)seekBySeconds:(double)delta
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    double total = [self resolvedDuration];
    double current = player.time.intValue / 1000.0;
    double target = current + delta;
    if (total > 0.0) {
        target = MIN(total, target);
    }
    target = MAX(0.0, target);
    [self seekToTime:target];
}

- (void)seekToTime:(double)seconds
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    if (!player.isSeekable) {
        return;
    }
    [player setTime:[VLCTime timeWithInt:(int)(MAX(0.0, seconds) * 1000.0)]];
    self.scrubbing = NO;
    [self showHUDWithText:[OVTheme formatTime:seconds]];
}

- (void)seekToPosition:(float)position
{
    double total = [self resolvedDuration];
    if (total <= 0.0) {
        return;
    }
    [self seekToTime:position * total];
}

- (double)resolvedDuration
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    double length = player.media.length.intValue / 1000.0;
    if (length > 0.0) {
        return length;
    }
    if (self.duration > 0.0) {
        return self.duration;
    }
    int t = player.time.intValue;
    int r = player.remainingTime.intValue;
    if (t > 0 && r > 0) {
        return (t + r) / 1000.0;
    }
    return 0.0;
}

- (void)closePlayer
{
    [self saveCurrentPosition];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)stopPlayback
{
    [self saveCurrentPosition];
    [self teardownRemoteCommands];
    [self.listPlayer stop];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[UIScreen mainScreen] setBrightness:self.originalBrightness];
}

- (void)saveCurrentPosition
{
    OVMediaItem *item = [self currentItem];
    if (!item || item.isNetwork || item.path.length == 0) {
        return;
    }
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    double current = player.time.intValue / 1000.0;
    double total = [self resolvedDuration];
    if (total <= 0.0) {
        total = item.duration;
    }
    [[OVLibrary sharedLibrary] setLastPosition:current forPath:item.path duration:total];
    self.lastPositionSave = CFAbsoluteTimeGetCurrent();
}

- (void)applyResumeIfNeeded
{
    if (self.resumeApplied) {
        return;
    }
    OVMediaItem *item = [self currentItem];
    if (!item || item.isNetwork || item.path.length == 0 || ![OVLibrary resumePlayback]) {
        self.resumeApplied = YES;
        return;
    }
    double saved = [[OVLibrary sharedLibrary] lastPositionForPath:item.path];
    if (saved <= 10.0) {
        self.resumeApplied = YES;
        return;
    }
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    if (!player.isSeekable) {
        return;
    }
    if (player.time.intValue > 8000) {
        self.resumeApplied = YES;
        return;
    }
    [player setTime:[VLCTime timeWithInt:(int)(saved * 1000.0)]];
    self.resumeApplied = YES;
    [OVTheme showToast:[NSString stringWithFormat:@"Reanudando en %@",
                        [OVTheme formatTime:saved]] inView:self.view];
}

#pragma mark - Slider

- (void)sliderTouchDown
{
    self.scrubbing = YES;
    self.controlsGeneration++;
}

- (void)sliderChanged
{
    if (!self.scrubbing) {
        return;
    }
    double total = [self resolvedDuration];
    self.currentTimeLabel.text = [OVTheme formatTime:self.timeSlider.value * total];
}

- (void)sliderTouchUp
{
    if (!self.scrubbing) {
        return;
    }
    self.scrubbing = NO;
    [self seekToPosition:self.timeSlider.value];
    [self scheduleAutoHide];
}

#pragma mark - Gestures

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UIControl class]]) {
            return NO;
        }
        if (view == self.view) {
            break;
        }
        view = view.superview;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}

- (void)handleTap:(UITapGestureRecognizer *)gesture
{
    if (self.controlsVisible) {
        [self hideControls];
    } else {
        [self showControls];
        [self scheduleAutoHide];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture
{
    CGPoint point = [gesture locationInView:self.view];
    CGFloat width = self.view.bounds.size.width;
    if (point.x < width * 0.32) {
        [self seekBySeconds:-10.0];
    } else if (point.x > width * 0.68) {
        [self seekBySeconds:10.0];
    } else {
        [self togglePlayPause];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture
{
    CGPoint translation = [gesture translationInView:self.view];
    CGFloat width = MAX(1.0, self.view.bounds.size.width);
    CGFloat height = MAX(1.0, self.view.bounds.size.height);

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.panMode = OVPanModeUndecided;
        self.panStartTime = self.listPlayer.mediaPlayer.time.intValue / 1000.0;
        self.panStartVolume = self.listPlayer.mediaPlayer.audio.volume;
        self.panStartBrightness = [UIScreen mainScreen].brightness;
        self.panTargetTime = self.panStartTime;
        self.controlsGeneration++;
        return;
    }

    if (self.panMode == OVPanModeUndecided) {
        if (fabs(translation.x) < 14.0 && fabs(translation.y) < 14.0) {
            return;
        }
        if (fabs(translation.x) >= fabs(translation.y)) {
            if (!self.listPlayer.mediaPlayer.isSeekable) {
                return;
            }
            self.panMode = OVPanModeSeek;
        } else {
            CGPoint location = [gesture locationInView:self.view];
            self.panMode = (location.x < width / 2.0) ? OVPanModeBrightness : OVPanModeVolume;
        }
    }

    if (self.panMode == OVPanModeSeek) {
        double total = [self resolvedDuration];
        double target = self.panStartTime + (translation.x / width) * 180.0;
        target = MAX(0.0, total > 0.0 ? MIN(total, target) : MAX(0.0, target));
        self.panTargetTime = target;
        [self showHUDWithText:[NSString stringWithFormat:@"%@ / %@",
                               [OVTheme formatTime:target],
                               total > 0.0 ? [OVTheme formatTime:total] : @"--:--"]];
        if (gesture.state == UIGestureRecognizerStateEnded ||
            gesture.state == UIGestureRecognizerStateCancelled) {
            [self seekToTime:self.panTargetTime];
        }
        return;
    }

    if (self.panMode == OVPanModeBrightness) {
        CGFloat value = self.panStartBrightness - (translation.y / height);
        value = MAX(0.0, MIN(1.0, value));
        [[UIScreen mainScreen] setBrightness:value];
        [self showHUDWithText:[NSString stringWithFormat:@"Brillo %d%%",
                               (int)lroundf(value * 100.0f)]];
        return;
    }

    if (self.panMode == OVPanModeVolume) {
        CGFloat delta = -(translation.y / height) * 160.0;
        int volume = (int)lroundf(self.panStartVolume + delta);
        volume = MAX(0, MIN(200, volume));
        self.listPlayer.mediaPlayer.audio.volume = volume;
        [self showHUDWithText:[NSString stringWithFormat:@"Volumen %d%%", volume]];
        if (gesture.state == UIGestureRecognizerStateEnded ||
            gesture.state == UIGestureRecognizerStateCancelled) {
            [[NSUserDefaults standardUserDefaults] setInteger:volume forKey:@"OVVolume"];
        }
        return;
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gesture
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    if (!self.videoVisible || !player.hasVideoOut) {
        return;
    }
    if (gesture.state == UIGestureRecognizerStateBegan) {
        float scale = player.scaleFactor;
        self.pinchStartScale = (scale > 0.05f) ? scale : 1.0f;
        self.controlsGeneration++;
    }
    float scale = self.pinchStartScale * gesture.scale;
    player.scaleFactor = MAX(0.5f, MIN(3.0f, scale));
    [self showHUDWithText:[NSString stringWithFormat:@"Zoom %.1f×",
                           (double)player.scaleFactor]];
}

#pragma mark - Overlay

- (void)showControls
{
    [self setControlsVisible:YES animated:YES];
}

- (void)hideControls
{
    [self setControlsVisible:NO animated:YES];
}

- (void)setControlsVisible:(BOOL)visible animated:(BOOL)animated
{
    self.controlsVisible = visible;
    self.controlsView.userInteractionEnabled = visible;
    self.controlsGeneration++;
    void (^changes)(void) = ^{
        self.controlsView.alpha = visible ? 1.0 : 0.0;
    };
    if (animated) {
        [UIView animateWithDuration:0.22 animations:changes];
    } else {
        changes();
    }
}

- (void)scheduleAutoHide
{
    self.controlsGeneration++;
    NSUInteger generation = self.controlsGeneration;
    if (![self isPlaying]) {
        return;
    }
    __weak OVPlayerViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.controlsGeneration != generation) {
            return;
        }
        if (strongSelf.controlsVisible && [strongSelf isPlaying] && !strongSelf.scrubbing) {
            [strongSelf setControlsVisible:NO animated:YES];
        }
    });
}

- (void)showHUDWithText:(NSString *)text
{
    self.hudLabel.text = text;
    self.hudGeneration++;
    NSUInteger generation = self.hudGeneration;
    [self.view bringSubviewToFront:self.hudLabel];
    self.hudLabel.alpha = 1.0;
    __weak OVPlayerViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.hudGeneration != generation) {
            return;
        }
        [UIView animateWithDuration:0.3 animations:^{
            strongSelf.hudLabel.alpha = 0.0;
        }];
    });
}

#pragma mark - Spinner / status

- (void)showSpinnerWithText:(NSString *)text
{
    self.statusLabel.text = text;
    self.statusLabel.hidden = (text.length == 0);
    [self.view bringSubviewToFront:self.spinner];
    [self.view bringSubviewToFront:self.statusLabel];
    [self.spinner startAnimating];
}

- (void)hideSpinner
{
    [self.spinner stopAnimating];
    self.statusLabel.hidden = YES;
}

#pragma mark - UI state

- (void)updatePlaybackStateUI
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    VLCMediaPlayerState state = player.state;

    BOOL playing = (state == VLCMediaPlayerStatePlaying);
    BOOL opening = (state == VLCMediaPlayerStateOpening);
    BOOL buffering = (state == VLCMediaPlayerStateBuffering);

    if (opening) {
        [self showSpinnerWithText:@"Cargando…"];
    } else if (buffering) {
        // En archivos locales el estado de búfer dura milisegundos y no debe
        // mostrar un aviso. Solo los streams de red necesitan precargar datos.
        if ([self currentItem].isNetwork) {
            [self showSpinnerWithText:@"Cargando…"];
        } else {
            [self hideSpinner];
        }
    } else if (state == VLCMediaPlayerStateError) {
        [self hideSpinner];
        self.statusLabel.text = @"No se pudo reproducir este archivo.";
        self.statusLabel.hidden = NO;
    } else if (state == VLCMediaPlayerStateStopped ||
               state == VLCMediaPlayerStateEnded) {
        [self hideSpinner];
    } else {
        [self hideSpinner];
    }

    if (playing) {
        [self applyResumeIfNeeded];
        [self applyDeinterlace];
        self.listPlayer.mediaPlayer.rate = self.preferredRate;
        if (self.preferredAspect && ![self.preferredAspect isEqualToString:@"default"]) {
            [self applyAspectRatio:self.preferredAspect];
        }
        [self scheduleAutoHide];
    }
    if (!playing) {
        [self showControls];
    }

    [self updatePlayButton];
    [self updateVideoOrAudioView];
    [self updateNowPlayingInfo];
    [self updateTrackButtons];
}

- (void)updatePlayButton
{
    UIImage *glyph = [self currentItem] && self.listPlayer.mediaPlayer.isPlaying
        ? OVPlayerGlyph(OVPlayerGlyphPause, 26.0)
        : OVPlayerGlyph(OVPlayerGlyphPlay, 26.0);
    [self.playButton setImage:glyph forState:UIControlStateNormal];
}

- (void)updateVideoOrAudioView
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    BOOL hasVideo = player.hasVideoOut;
    self.videoVisible = hasVideo;
    self.videoView.hidden = !hasVideo;
    self.audioView.hidden = hasVideo;
    self.audioButton.enabled = (player.numberOfAudioTracks > 1);
    self.subtitleButton.enabled = (player.numberOfSubtitlesTracks > 0 || hasVideo);
}

- (void)updateTrackButtons
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    [self.audioButton setTitle:(player.numberOfAudioTracks > 1
                               ? [NSString stringWithFormat:@"Audio %d", player.currentAudioTrackIndex]
                               : @"Audio")
                      forState:UIControlStateNormal];
    NSInteger subtitles = player.numberOfSubtitlesTracks;
    [self.subtitleButton setTitle:(subtitles > 0
                                   ? [NSString stringWithFormat:@"Subs %ld", (long)subtitles]
                                   : @"Subs")
                          forState:UIControlStateNormal];
}

- (void)updateSpeedButton
{
    [self.speedButton setTitle:[NSString stringWithFormat:@"%g×", self.preferredRate]
                      forState:UIControlStateNormal];
}

- (void)updateRepeatButton
{
    NSString *title = @"Repetir";
    if (self.listPlayer.repeatMode == VLCRepeatAllItems) {
        title = @"Repetir todo";
    } else if (self.listPlayer.repeatMode == VLCRepeatCurrentItem) {
        title = @"Repetir uno";
    }
    [self.repeatButton setTitle:title forState:UIControlStateNormal];
}

- (void)applyDeinterlace
{
    if (![OVLibrary deinterlace] || self.deinterlaceApplied) {
        return;
    }
    self.deinterlaceApplied = YES;
    [self.listPlayer.mediaPlayer setDeinterlace:VLCDeinterlaceOn withFilter:@"blend"];
}

#pragma mark - Time updates

- (void)refreshTimeUI
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    int currentMS = player.time.intValue;
    double total = [self resolvedDuration];
    self.duration = total;

    if (!self.scrubbing) {
        double current = MAX(0.0, currentMS / 1000.0);
        self.currentTimeLabel.text = [OVTheme formatTime:current];
        self.durationLabel.text = total > 0.0 ? [OVTheme formatTime:total] : @"--:--";
        self.timeSlider.enabled = (total > 0.0);
        self.timeSlider.value = (total > 0.0)
            ? (float)MAX(0.0, MIN(1.0, current / total)) : 0.0f;
    }

    OVMediaItem *item = [self currentItem];
    if (item && !item.isNetwork && total > 0.0 && !self.durationReported) {
        self.durationReported = YES;
        item.duration = total;
        [[OVLibrary sharedLibrary] updateDuration:total forPath:item.path];
    }

    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - self.lastPositionSave > 5.0) {
        [self saveCurrentPosition];
    }
    if (now - self.lastNowPlayingUpdate > 1.0) {
        [self updateNowPlayingInfo];
    }

    [self applyResumeIfNeeded];
    [self updateVideoOrAudioView];
}

#pragma mark - VLC delegates

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updatePlaybackStateUI];
        });
        return;
    }
    [self updatePlaybackStateUI];
}

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshTimeUI];
        });
        return;
    }
    [self refreshTimeUI];
}

- (void)mediaPlayerTitleChanged:(NSNotification *)aNotification
{
}

- (void)mediaListPlayer:(VLCMediaListPlayer *)player nextMedia:(VLCMedia *)media
{
    NSInteger index = [player.mediaList indexOfMedia:media];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (index != NSNotFound) {
            [self prepareForIndex:index];
        } else {
            [self updateForCurrentItem];
        }
    });
}

- (void)mediaListPlayerFinishedPlayback:(VLCMediaListPlayer *)player
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self saveCurrentPosition];
        [self showControls];
        [self updatePlayButton];
        self.statusLabel.text = @"Fin de la lista de reproducción";
        self.statusLabel.hidden = NO;
        [self.spinner stopAnimating];
    });
}

- (void)mediaListPlayerStopped:(VLCMediaListPlayer *)player
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePlayButton];
    });
}

#pragma mark - Menu: general

- (void)showOptions
{
    [self showControls];
    self.controlsGeneration++;

    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:[self currentItem].title
                                                      inView:self.view
                                                     popover:self.optionsButton];
    __weak OVPlayerViewController *weakSelf = self;

    if (player.numberOfAudioTracks > 1) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Pista de audio"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [weakSelf showAudioTracks];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Subtítulos"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showSubtitles];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Velocidad de reproducción"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showSpeedMenu];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Relación de aspecto"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showAspectMenu];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Retardo de subtítulos"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showSubtitleDelayMenu];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Lista de reproducción"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showPlaylist];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Repetir"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showRepeatMenu];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(self.sleepTimer
                                                      ? @"Temporizador de sueño (activo)"
                                                      : @"Temporizador de sueño")
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showSleepTimerMenu];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cargar subtítulo externo…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf pickExternalSubtitle];
    }]];
    if (player.hasVideoOut) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Captura de pantalla"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [weakSelf takeSnapshot];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Restablecer zoom"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.listPlayer.mediaPlayer.scaleFactor = 1.0f;
            [weakSelf showHUDWithText:@"Zoom 1.0×"];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Información"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showInfo];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    sheet.popoverPresentationController.sourceView = self.optionsButton;
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceRect = self.optionsButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showSleepTimerMenu
{
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Temporizador de sueño"
                                                      inView:self.view
                                                     popover:self.optionsButton];
    __weak OVPlayerViewController *weakSelf = self;
    NSArray *minutes = @[@15, @30, @45, @60, @90];
    for (NSNumber *value in minutes) {
        NSString *title = [NSString stringWithFormat:@"%@ minutos", value];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [weakSelf startSleepTimerWithMinutes:value.integerValue];
        }]];
    }
    if (self.sleepTimer) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Desactivar temporizador"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
            [weakSelf.sleepTimer invalidate];
            weakSelf.sleepTimer = nil;
            [weakSelf showHUDWithText:@"Temporizador desactivado"];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)startSleepTimerWithMinutes:(NSInteger)minutes
{
    [self.sleepTimer invalidate];
    self.sleepTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(minutes * 60)
                                                      target:self
                                                    selector:@selector(sleepTimerFired:)
                                                    userInfo:nil
                                                     repeats:NO];
    [self showHUDWithText:[NSString stringWithFormat:@"Se pausará en %ld min",
                           (long)minutes]];
}

- (void)sleepTimerFired:(NSTimer *)timer
{
    self.sleepTimer = nil;
    [self saveCurrentPosition];
    [self.listPlayer pause];
    [self showHUDWithText:@"Reproducción pausada"];
    [self showControls];
}

#pragma mark - Menu: tracks and subtitles

- (void)showAudioTracks
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    NSArray *names = player.audioTrackNames;
    NSArray *indexes = player.audioTrackIndexes;
    if (names.count == 0) {
        [OVTheme showToast:@"Este archivo no tiene varias pistas de audio" inView:self.view];
        return;
    }
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Pista de audio"
                                                      inView:self.view
                                                     popover:self.audioButton];
    __weak OVPlayerViewController *weakSelf = self;
    for (NSInteger i = 0; i < names.count; i++) {
        int trackIndex = [indexes[i] intValue];
        NSString *title = [names[i] description];
        BOOL current = (trackIndex == player.currentAudioTrackIndex);
        if (current) {
            title = [@"✓  " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.listPlayer.mediaPlayer.currentAudioTrackIndex = trackIndex;
            [weakSelf updateTrackButtons];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showSubtitles
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    NSArray *names = player.videoSubTitlesNames;
    NSArray *indexes = player.videoSubTitlesIndexes;

    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Subtítulos"
                                                      inView:self.view
                                                     popover:self.subtitleButton];
    __weak OVPlayerViewController *weakSelf = self;

    if (names.count == 0) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Sin pistas de subtítulos"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];
    } else {
        NSString *offTitle = (player.currentVideoSubTitleIndex < 0)
            ? @"✓  Desactivados" : @"Desactivados";
        [sheet addAction:[UIAlertAction actionWithTitle:offTitle
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.listPlayer.mediaPlayer.currentVideoSubTitleIndex = -1;
        }]];
        for (NSInteger i = 0; i < names.count; i++) {
            int trackIndex = [indexes[i] intValue];
            NSString *title = [names[i] description];
            if (trackIndex == player.currentVideoSubTitleIndex) {
                title = [@"✓  " stringByAppendingString:title];
            }
            [sheet addAction:[UIAlertAction actionWithTitle:title
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                weakSelf.listPlayer.mediaPlayer.currentVideoSubTitleIndex = trackIndex;
            }]];
        }
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cargar archivo de subtítulos…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf pickExternalSubtitle];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Retardo de subtítulos"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showSubtitleDelayMenu];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showSubtitleDelayMenu
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    double seconds = player.currentVideoSubTitleDelay / 1000000.0;
    NSString *title = [NSString stringWithFormat:@"Retardo de subtítulos (%+.1f s)", seconds];
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:title
                                                      inView:self.view
                                                     popover:self.subtitleButton];
    __weak OVPlayerViewController *weakSelf = self;
    NSArray *values = @[@(-1.0), @(-0.5), @(0.5), @(1.0)];
    for (NSNumber *value in values) {
        double delta = value.doubleValue;
        NSString *label = [NSString stringWithFormat:@"%+.1f segundos", delta];
        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            VLCMediaPlayer *mp = weakSelf.listPlayer.mediaPlayer;
            mp.currentVideoSubTitleDelay += (NSInteger)(delta * 1000000.0);
            [weakSelf showHUDWithText:label];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Restablecer"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        weakSelf.listPlayer.mediaPlayer.currentVideoSubTitleDelay = 0;
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pickExternalSubtitle
{
    OVMediaItem *item = [self currentItem];
    NSString *startPath = item.folder.length > 0 ? item.folder : NSHomeDirectory();
    OVFolderBrowserViewController *browser =
        [[OVFolderBrowserViewController alloc] initWithPath:startPath
                                         subtitleCompletion:^(NSString *path) {
            [self attachSubtitleAtPath:path];
        }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:browser];
    [OVTheme styleNavigationBar:nav.navigationBar];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)attachSubtitleAtPath:(NSString *)path
{
    int result = [self.listPlayer.mediaPlayer addPlaybackSlave:[NSURL fileURLWithPath:path]
                                                         type:VLCMediaPlaybackSlaveTypeSubtitle
                                                      enforce:YES];
    if (result == 0) {
        [OVTheme showToast:@"Subtítulo cargado" inView:self.view];
    } else {
        [OVTheme showToast:@"No se pudo cargar el subtítulo" inView:self.view];
    }
}

#pragma mark - Menu: playback options

- (void)showSpeedMenu
{
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Velocidad de reproducción"
                                                      inView:self.view
                                                     popover:self.speedButton];
    NSArray *rates = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    __weak OVPlayerViewController *weakSelf = self;
    for (NSNumber *rate in rates) {
        NSString *title = [NSString stringWithFormat:@"%g×", rate.doubleValue];
        if (fabs(rate.doubleValue - self.preferredRate) < 0.01) {
            title = [@"✓  " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            float value = rate.floatValue;
            weakSelf.preferredRate = value;
            weakSelf.listPlayer.mediaPlayer.rate = value;
            [weakSelf updateSpeedButton];
            [weakSelf showHUDWithText:[NSString stringWithFormat:@"Velocidad %g×",
                                       value]];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showAspectMenu
{
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Relación de aspecto"
                                                      inView:self.view
                                                     popover:self.aspectButton];
    NSArray *titles = @[@"Predeterminado", @"16:9", @"4:3", @"1:1", @"21:9"];
    NSArray *values = @[@"default", @"16:9", @"4:3", @"1:1", @"21:9"];
    __weak OVPlayerViewController *weakSelf = self;
    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *title = titles[i];
        if ([values[i] isEqualToString:self.preferredAspect]) {
            title = [@"✓  " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.preferredAspect = values[i];
            [weakSelf applyAspectRatio:values[i]];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)applyAspectRatio:(NSString *)aspect
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    if ([aspect isEqualToString:@"16:9"]) {
        player.videoAspectRatio = (char *)"16:9";
    } else if ([aspect isEqualToString:@"4:3"]) {
        player.videoAspectRatio = (char *)"4:3";
    } else if ([aspect isEqualToString:@"1:1"]) {
        player.videoAspectRatio = (char *)"1:1";
    } else if ([aspect isEqualToString:@"21:9"]) {
        player.videoAspectRatio = (char *)"21:9";
    } else {
        player.videoAspectRatio = NULL;
    }
}

- (void)showRepeatMenu
{
    UIAlertController *sheet = [OVTheme actionSheetWithTitle:@"Repetir"
                                                      inView:self.view
                                                     popover:self.repeatButton];
    NSArray *titles = @[@"No repetir", @"Repetir uno", @"Repetir todo"];
    VLCRepeatMode current = self.listPlayer.repeatMode;
    __weak OVPlayerViewController *weakSelf = self;
    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *title = titles[i];
        if ((NSInteger)current == i) {
            title = [@"✓  " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.listPlayer.repeatMode = (VLCRepeatMode)i;
            [weakSelf updateRepeatButton];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showPlaylist
{
    [self saveCurrentPosition];
    OVPlaylistViewController *playlist =
        [[OVPlaylistViewController alloc] initWithItems:self.items currentIndex:self.currentIndex];
    __weak OVPlayerViewController *weakSelf = self;
    playlist.selectionHandler = ^(NSInteger index) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf prepareForIndex:index];
        [strongSelf.listPlayer playItemAtNumber:@(index)];
        [strongSelf showControls];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:playlist];
    [OVTheme styleNavigationBar:nav.navigationBar];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Snapshot / info

- (void)takeSnapshot
{
    UIImage *snapshot = self.listPlayer.mediaPlayer.lastSnapshot;
    if (!snapshot) {
        [OVTheme showToast:@"No hay imagen disponible" inView:self.view];
        return;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = paths.count > 0 ? paths[0] : NSTemporaryDirectory();
    NSString *name = [NSString stringWithFormat:@"VLC9-%@.png",
                      [[NSDate date] description]];
    name = [name stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    name = [name stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString *path = [directory stringByAppendingPathComponent:name];
    NSData *data = UIImagePNGRepresentation(snapshot);
    if ([data writeToFile:path atomically:YES]) {
        [OVTheme showToast:@"Captura guardada en Documentos" inView:self.view];
    } else {
        [OVTheme showToast:@"No se pudo guardar la captura" inView:self.view];
    }
}

- (void)showInfo
{
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    OVMediaItem *item = [self currentItem];
    NSMutableString *message = [NSMutableString string];
    if (item) {
        [message appendFormat:@"%@\n\n", item.isNetwork ? item.url.absoluteString : item.path];
        [message appendFormat:@"Tipo: %@\n", item.extension.length > 0
            ? item.extension.uppercaseString : (item.isNetwork ? @"Red" : @"—")];
        if (item.size > 0) {
            [message appendFormat:@"Tamaño: %@\n", [OVTheme formatBytes:item.size]];
        }
    }
    double total = [self resolvedDuration];
    if (total > 0.0) {
        [message appendFormat:@"Duración: %@\n", [OVTheme formatTime:total]];
    }
    CGSize size = player.videoSize;
    if (size.width > 0.0 && size.height > 0.0) {
        [message appendFormat:@"Vídeo: %.0f × %.0f\n", size.width, size.height];
    }
    [message appendFormat:@"Pistas de audio: %d\n", player.numberOfAudioTracks];
    [message appendFormat:@"Pistas de subtítulos: %d\n", player.numberOfSubtitlesTracks];
    [message appendFormat:@"Motor: %@", [VLCLibrary sharedLibrary].version];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:item.title ?: @"Reproducción"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Now Playing / remote

- (void)updateNowPlayingInfo
{
    OVMediaItem *item = [self currentItem];
    if (!item) {
        return;
    }
    VLCMediaPlayer *player = self.listPlayer.mediaPlayer;
    double total = [self resolvedDuration];
    double elapsed = player.time.intValue / 1000.0;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = item.title ?: @"VLC 9";
    info[MPMediaItemPropertyArtist] = item.isNetwork ? @"Red" : (item.folder ?: @"VLC 9");
    info[MPMediaItemPropertyAlbumTitle] = @"VLC 9";
    if (total > 0.0) {
        info[MPMediaItemPropertyPlaybackDuration] = @(total);
    }
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(MAX(0.0, elapsed));
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(player.isPlaying ? player.rate : 0.0);
    info[MPMediaItemPropertyMediaType] = @(item.type == OVMediaTypeAudio
                                           ? MPMediaTypeMusic : MPMediaTypeMovie);

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    self.lastNowPlayingUpdate = CFAbsoluteTimeGetCurrent();
}

- (void)setupRemoteCommands
{
    if (self.remoteCommandTokens.count > 0) {
        return;
    }
    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];
    center.playCommand.enabled = YES;
    center.pauseCommand.enabled = YES;
    center.togglePlayPauseCommand.enabled = YES;
    center.nextTrackCommand.enabled = (self.items.count > 1);
    center.previousTrackCommand.enabled = (self.items.count > 1);
    if ([center respondsToSelector:@selector(changePlaybackPositionCommand)]) {
        center.changePlaybackPositionCommand.enabled = YES;
    }

    __weak OVPlayerViewController *weakSelf = self;

    id playToken = [center.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return MPRemoteCommandHandlerStatusCommandFailed;
        if (!strongSelf.listPlayer.mediaPlayer.isPlaying && strongSelf.listPlayer.mediaPlayer.canPause) {
            [strongSelf.listPlayer play];
        }
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    id pauseToken = [center.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return MPRemoteCommandHandlerStatusCommandFailed;
        [strongSelf.listPlayer pause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    id toggleToken = [center.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return MPRemoteCommandHandlerStatusCommandFailed;
        [strongSelf togglePlayPause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    id nextToken = [center.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return MPRemoteCommandHandlerStatusCommandFailed;
        if (strongSelf.currentIndex + 1 >= (NSInteger)strongSelf.items.count) {
            return MPRemoteCommandHandlerStatusNoSuchContent;
        }
        [strongSelf playNext];
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    id previousToken = [center.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return MPRemoteCommandHandlerStatusCommandFailed;
        if (strongSelf.currentIndex <= 0) {
            return MPRemoteCommandHandlerStatusNoSuchContent;
        }
        [strongSelf playPrevious];
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    id positionToken = [center.changePlaybackPositionCommand addTargetWithHandler:
                        ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        OVPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return MPRemoteCommandHandlerStatusCommandFailed;
        if ([event isKindOfClass:[MPChangePlaybackPositionCommandEvent class]]) {
            MPChangePlaybackPositionCommandEvent *positionEvent =
                (MPChangePlaybackPositionCommandEvent *)event;
            [strongSelf seekToTime:positionEvent.positionTime];
            return MPRemoteCommandHandlerStatusSuccess;
        }
        return MPRemoteCommandHandlerStatusCommandFailed;
    }];

    NSMutableArray *tokens = [NSMutableArray array];
    if (playToken) [tokens addObject:playToken];
    if (pauseToken) [tokens addObject:pauseToken];
    if (toggleToken) [tokens addObject:toggleToken];
    if (nextToken) [tokens addObject:nextToken];
    if (previousToken) [tokens addObject:previousToken];
    if (positionToken) [tokens addObject:positionToken];
    self.remoteCommandTokens = tokens;
}

- (void)teardownRemoteCommands
{
    if (self.remoteCommandTokens.count == 0) {
        return;
    }
    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];
    NSArray *tokens = [self.remoteCommandTokens copy];
    self.remoteCommandTokens = nil;

    NSArray *commands = @[center.playCommand, center.pauseCommand,
                          center.togglePlayPauseCommand, center.nextTrackCommand,
                          center.previousTrackCommand,
                          center.changePlaybackPositionCommand];
    for (id token in tokens) {
        for (MPRemoteCommand *command in commands) {
            [command removeTarget:token];
        }
    }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
}

#pragma mark - Interruptions / background

- (void)handleInterruption:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *typeValue = userInfo[AVAudioSessionInterruptionTypeKey];
    if (!typeValue) {
        return;
    }
    if (typeValue.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan) {
        self.wasPlayingBeforeInterruption = self.listPlayer.mediaPlayer.isPlaying;
        [self.listPlayer pause];
    } else {
        NSNumber *options = userInfo[AVAudioSessionInterruptionOptionKey];
        BOOL shouldResume = (options.unsignedIntegerValue &
                             AVAudioSessionInterruptionOptionShouldResume) != 0;
        if (shouldResume && self.wasPlayingBeforeInterruption) {
            [self.listPlayer play];
        }
        self.wasPlayingBeforeInterruption = NO;
    }
}

- (void)handleAppBackground:(NSNotification *)notification
{
    if (![OVLibrary backgroundAudio] && self.listPlayer.mediaPlayer.isPlaying) {
        [self.listPlayer pause];
    }
}

@end
