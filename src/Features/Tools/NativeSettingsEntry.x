#import "../../Utils.h"
#import <objc/runtime.h>

// Adds a Sparkle button to the navigation bar of Instagram's own
// "Settings and activity" screen.
//
// The button is a UIBarButtonItem on the controller's navigationItem, installed
// once when the screen appears. UIKit owns its placement and its glass
// treatment; nothing here runs per frame.

static const void *kSPKSettingsEntryItemAssocKey = &kSPKSettingsEntryItemAssocKey;

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
    [SPKUtils showSettingsVC:UIApplication.sharedApplication.keyWindow];
}

@end

// Matched on either signal so a rename on one side still lands: the Swift class
// name, or the title Instagram gives the screen. The controller is a Swift
// generic, so its mangled name varies by specialisation and is matched by
// substring rather than hooked directly.
static BOOL SPKIsNativeSettingsController(UIViewController *controller) {
    if (!controller)
        return NO;
    const char *name = class_getName(object_getClass(controller));
    if (name && strstr(name, "IGSettingsHostingController"))
        return YES;
    return [controller.title isEqualToString:@"Settings and activity"];
}

static void SPKSeatSettingsEntryItem(UIViewController *controller) {
    if (!SPKIsNativeSettingsController(controller))
        return;

    UIBarButtonItem *existing = objc_getAssociatedObject(controller, kSPKSettingsEntryItemAssocKey);
    NSArray<UIBarButtonItem *> *right = controller.navigationItem.rightBarButtonItems;
    if (existing && ([right containsObject:existing] ||
                     [controller.navigationItem.leftBarButtonItems containsObject:existing]))
        return;

    UIImage *icon = [UIImage systemImageNamed:@"sparkles"
                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                              weight:UIImageSymbolWeightRegular]];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:icon
                                                            style:UIBarButtonItemStylePlain
                                                           target:[SPKNativeSettingsEntryTarget sharedTarget]
                                                           action:@selector(openSparkleSettings:)];
    item.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    item.accessibilityLabel = @"Sparkle";
    objc_setAssociatedObject(controller, kSPKSettingsEntryItemAssocKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Index 0 is the trailing edge: rightBarButtonItems is ordered right to left.
    // When the screen is presented modally Instagram puts its own Done button on
    // the right, and iOS 26 packs both into one glass pill where the two glyphs
    // touch and the second stops taking taps. The left side is empty on that
    // screen, so the entry goes there instead and keeps its own hit area.
    if (right.count > 0) {
        NSArray<UIBarButtonItem *> *left = controller.navigationItem.leftBarButtonItems;
        if ([left containsObject:item])
            return;
        NSMutableArray<UIBarButtonItem *> *items = left ? [left mutableCopy] : [NSMutableArray array];
        [items addObject:item];
        controller.navigationItem.leftBarButtonItems = items;
        return;
    }

    NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray array];
    [items addObject:item];
    controller.navigationItem.rightBarButtonItems = items;
}

%group SPKNativeSettingsEntryHooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKSeatSettingsEntryItem(self);
}

%end

%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNativeSettingsEntryHooks);
    });
}
