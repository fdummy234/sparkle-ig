#import "../../Utils.h"
#import <objc/runtime.h>

// Sparkle's single visible entry point: a ✦ button in the navigation bar of
// Instagram's own "Settings and activity" screen.
//
// That screen is Settings.Views.IGSettingsHostingController<IGSettingScreenView>,
// a Swift class the runtime does not register at launch — resolving it once
// during startup finds nothing. So nothing is resolved ahead of time:
// IGNavigationController is a plain ObjC class that is always present, and every
// controller it pushes is checked as it appears.
//
// Two independent signals identify the screen, so a rename on either side still
// lands: the class name contains "IGSettingsHostingController", or the title
// reads "Settings and activity".

static const void *kSPKNativeSettingsButtonAssocKey = &kSPKNativeSettingsButtonAssocKey;
static BOOL SPKNativeSettingsEntryDidInstall = NO;

BOOL SPKNativeSettingsEntryInstalled(void) {
    return SPKNativeSettingsEntryDidInstall;
}

static BOOL SPKIsNativeSettingsScreen(UIViewController *controller) {
    if (!controller)
        return NO;
    const char *name = class_getName(object_getClass(controller));
    if (name && strstr(name, "IGSettingsHostingController"))
        return YES;
    return [controller.title isEqualToString:@"Settings and activity"];
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
    [SPKUtils showSettingsVC:[UIApplication sharedApplication].keyWindow];
}

@end

static void SPKSeatNativeSettingsButton(UIViewController *controller) {
    if (!SPKIsNativeSettingsScreen(controller))
        return;

    UINavigationItem *item = controller.navigationItem;
    if (!item)
        return;

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
    SPKLog(@"Settings", @"[Sparkle] Settings entry seated on %@", NSStringFromClass(object_getClass(controller)));
}

// The screen is SwiftUI-hosted and rebuilds its bar as it settles, so the button
// is seated on push and again on the next runloop turns.
static void SPKSeatNativeSettingsButtonRepeatedly(UIViewController *controller) {
    if (!SPKIsNativeSettingsScreen(controller))
        return;
    SPKSeatNativeSettingsButton(controller);
    dispatch_async(dispatch_get_main_queue(), ^{
        SPKSeatNativeSettingsButton(controller);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SPKSeatNativeSettingsButton(controller);
    });
}

%group SPKNativeSettingsEntryHooks
%hook IGNavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    SPKSeatNativeSettingsButtonRepeatedly(viewController);
}

- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers animated:(BOOL)animated {
    %orig;
    SPKSeatNativeSettingsButtonRepeatedly(viewControllers.lastObject);
}

%end
%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNativeSettingsEntryHooks);
    });
}
