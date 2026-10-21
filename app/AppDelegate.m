#import "AppDelegate.h"
#import "OVLibraryViewController.h"
#import "OVBrowseViewController.h"
#import "OVPlaylistsViewController.h"
#import "OVMoreViewController.h"
#import "OVPlayerViewController.h"
#import "OVMediaItem.h"
#import "OVTheme.h"
#import "OVLibrary.h"

#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [OVTheme background];

    [self configureAudioSession];
    [self configureAppearance];

    OVLibraryViewController *videos =
        [[OVLibraryViewController alloc] initWithMediaType:OVMediaTypeVideo];
    OVLibraryViewController *music =
        [[OVLibraryViewController alloc] initWithMediaType:OVMediaTypeAudio];
    OVBrowseViewController *browse = [[OVBrowseViewController alloc] init];
    OVPlaylistsViewController *playlists = [[OVPlaylistsViewController alloc] init];
    OVMoreViewController *more = [[OVMoreViewController alloc] init];

    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[
        [self navigationControllerWithRoot:videos title:@"Vídeo" icon:OVTabIconVideos tag:0],
        [self navigationControllerWithRoot:music title:@"Audio" icon:OVTabIconMusic tag:1],
        [self navigationControllerWithRoot:browse title:@"Explorar" icon:OVTabIconFolders tag:2],
        [self navigationControllerWithRoot:playlists title:@"Listas" icon:OVTabIconPlaylists tag:3],
        [self navigationControllerWithRoot:more title:@"Más" icon:OVTabIconMore tag:4]
    ];
    self.tabBarController.selectedIndex = 0;
    self.tabBarController.tabBar.barTintColor = [OVTheme navBackground];
    self.tabBarController.tabBar.translucent = NO;
    self.tabBarController.tabBar.tintColor = [OVTheme orange];
    self.tabBarController.tabBar.layer.borderColor = [OVTheme separator].CGColor;
    self.tabBarController.tabBar.layer.borderWidth = 0.5;

    self.window.rootViewController = self.tabBarController;
    [self.window makeKeyAndVisible];

    [[OVLibrary sharedLibrary] reload];

    NSURL *launchURL = launchOptions[UIApplicationLaunchOptionsURLKey];
    if (launchURL) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self openExternalFileAtURL:launchURL];
        });
    }
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary *)options
{
    return [self openExternalFileAtURL:url];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    return [self openExternalFileAtURL:url];
}

#pragma mark - Setup

- (void)configureAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:NULL];
    [session setActive:YES error:NULL];
}

- (void)configureAppearance
{
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlack];
    [[UINavigationBar appearance] setTranslucent:NO];
    [[UINavigationBar appearance] setBarTintColor:[OVTheme navBackground]];
    [[UINavigationBar appearance] setTintColor:[OVTheme orange]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [OVTheme text],
        NSFontAttributeName: [OVTheme font:17.0 weight:UIFontWeightSemibold]
    }];

    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [OVTheme secondaryText],
        NSFontAttributeName: [OVTheme font:10.0 weight:UIFontWeightMedium]
    } forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [OVTheme orange],
        NSFontAttributeName: [OVTheme font:10.0 weight:UIFontWeightSemibold]
    } forState:UIControlStateSelected];

    [[UISwitch appearance] setOnTintColor:[OVTheme orange]];
}

- (NSString *)startingBrowserPath
{
    NSString *media = @"/var/mobile/Media";
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:media isDirectory:&isDirectory] &&
        isDirectory) {
        return media;
    }
    return NSHomeDirectory();
}

- (UINavigationController *)navigationControllerWithRoot:(UIViewController *)root
                                                   title:(NSString *)title
                                                    icon:(OVTabIcon)icon
                                                     tag:(NSInteger)tag
{
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:root];
    [OVTheme styleNavigationBar:nav.navigationBar];
    nav.navigationBar.translucent = NO;
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title
                                                  image:[OVTheme tabIcon:icon]
                                                    tag:tag];
    return nav;
}

#pragma mark - External files

- (BOOL)openExternalFileAtURL:(NSURL *)url
{
    if (!url.isFileURL) {
        return NO;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.count > 0 ? paths[0] : NSTemporaryDirectory();
    NSString *importDirectory = [documents stringByAppendingPathComponent:@"Importados"];
    [[NSFileManager defaultManager] createDirectoryAtPath:importDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    NSString *name = url.lastPathComponent;
    if (name.length == 0) {
        return NO;
    }
    NSString *destination = [importDirectory stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destination]) {
        NSString *base = [name stringByDeletingPathExtension];
        NSString *extension = [name pathExtension];
        NSInteger counter = 1;
        do {
            NSString *candidate = [NSString stringWithFormat:@"%@-%ld.%@", base,
                                   (long)counter, extension];
            destination = [importDirectory stringByAppendingPathComponent:candidate];
            counter++;
        } while ([fm fileExistsAtPath:destination] && counter < 1000);
    }

    NSError *error = nil;
    if (![fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destination] error:&error]) {
        [OVTheme showToast:@"No se pudo importar el archivo"
                    inView:self.tabBarController.view];
        return NO;
    }

    OVMediaItem *item = [[OVMediaItem alloc] initWithPath:destination type:OVMediaTypeVideo];
    OVPlayerViewController *player =
        [[OVPlayerViewController alloc] initWithItems:@[item] startIndex:0];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    UIViewController *presenter = self.tabBarController.selectedViewController
        ?: self.tabBarController;
    [presenter presentViewController:player animated:YES completion:nil];
    return YES;
}

@end
