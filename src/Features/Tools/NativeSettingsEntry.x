#import "../../Utils.h"
#import <objc/runtime.h>

// Sparkle's single visible entry point: a ✦ button in the navigation bar of
// Instagram's own "Settings and activity" screen. Everything else that used to
// open Sparkle (tab-bar long-press, profile ☰ long-press, inbox pencil
// long-press) stands down once this button is in place — see
// SPKNativeSettingsEntryInstalled().
//
// The host is a Swift generic: Settings.Views.IGSettingsHostingController<
// IGSettingScreenView>, mangled as
// _TtGC14Settings2Views27IGSettingsHostingControllerVS_19IGSettingScreenView_.
// The name carries no per-build hash, so it survives app updates as long as
// Meta keeps its own type names. A scan by fragment covers the case where the
// generic parameter changes.

static const void *kSPKNativeSettingsButtonAssocKey = &kSPKNativeSettingsButtonAssocKey;
static BOOL SPKNativeSettingsEntryDidInstall = NO;

BOOL SPKNativeSettingsEntryInstalled(void) {
    return SPKNativeSettingsEntryDidInstall;
}

static Class SPKSettingsHostingControllerClass(void) {
    static Class resolved;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        resolved = objc_getClass("_TtGC14Settings2Views27IGSettingsHostingControllerVS_19IGSettingScreenView_");
        if (resolved)
            return;

        // The generic parameter changed: find the hosting controller by the
        // stable part of its name instead of the whole mangled string.
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            const char *name = class_getName(classes[i]);
            if (name && strstr(name, "IGSettingsHostingController")) {
                resolved = classes[i];
                break;
            }
        }
        free(classes);
    });
    return resolved;
}

@interface SPKNativeSettingsEntryTarget : NSObject
+ (instancetype)sharedTarget;
- (void)openSparkleSettings:(id)sender;
@end

@implementation SPKNativeSettingsEntryTarget

+ (instancetype)sharedTarget {
    static SPKNativeSettingsEntryTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [SPKNativeSettingsEntryTarget new];
    });
    return target;
}

- (void)openSparkleSettings:(id)sender {
    UIWindow *window = nil;
    if ([sender isKindOfClass:[UIView class]])
        window = ((UIView *)sender).window;
    if (!window)
        window = [UIApplication sharedApplication].keyWindow;
    [SPKUtils showSettingsVC:window];
}

@end

%group SPKNativeSettingsEntryHooks
%hook SPKSettingsHostingController

- (void)viewWillAppear:(BOOL)animated {
    %orig;

    UIViewController *controller = (UIViewController *)self;
    UINavigationItem *item = controller.navigationItem;
    if (!item)
        return;

    // The screen is SwiftUI-hosted and may rebuild its bar between
    // appearances, so the button is re-seated every time rather than once.
    UIBarButtonItem *existing = objc_getAssociatedObject(controller, kSPKNativeSettingsButtonAssocKey);
    if (existing && item.rightBarButtonItem == existing)
        return;

    UIImage *icon = [UIImage systemImageNamed:@"sparkles"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19.0
                                                                                            weight:UIImageSymbolWeightRegular]];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:icon
                                                               style:UIBarButtonItemStylePlain
                                                              target:[SPKNativeSettingsEntryTarget sharedTarget]
                                                              action:@selector(openSparkleSettings:)];
    button.accessibilityLabel = @"Sparkle";
    item.rightBarButtonItem = button;
    objc_setAssociatedObject(controller, kSPKNativeSettingsButtonAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SPKNativeSettingsEntryDidInstall = YES;
}

%end
%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class hostingController = SPKSettingsHostingControllerClass();
        if (!hostingController) {
            SPKWarnLog(@"Settings", @"Native settings screen not found: keeping the long-press shortcuts armed.");
            return;
        }
        %init(SPKNativeSettingsEntryHooks, SPKSettingsHostingController = hostingController);
    });
}
