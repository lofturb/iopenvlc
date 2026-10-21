// main.m -- punto de entrada de la app.
// En iOS 9 con Theos no se usan storyboards: la interfaz se monta en código.
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
