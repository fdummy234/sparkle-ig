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
@property (nonatomic, weak) UIViewController *owner;
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
    // Present from the screen this button lives on. Going through the key
    // window presented from its root — but Instagram's settings sit over that
    // root, and a controller already presenting refuses to present again, which
    // is why the tap did nothing at all.
    [SPKUtils showSettingsFromController:self.owner];
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

// Puts the bar in the shape the screen has when Instagram opens it itself.
//
// Colour: tinting the item alone left Done blue, because on iOS 26 a bar button
// takes the navigation bar's tint unless the item overrides it, and Instagram
// sets neither. Both are set here.
//
// Shape and side: "Done" appears nowhere in Instagram's own navigation. It is
// there because this screen was routed to as a modal rather than pushed from a
// profile. The back chevron is what the screen carries when reached the usual
// way — and a back control belongs on the leading edge, so it moves there and
// the Sparkle entry takes the trailing edge. Only the look moves; the action is
// left alone.
//
// A custom-view item ignores the image and the title, and that only shows at
// runtime — hence the guard.
static void SPKArrangeSettingsBar(UIViewController *controller,
                                  UIBarButtonItem *entry,
                                  NSArray<UIBarButtonItem *> *instagramItems) {
    UIColor *ink = [SPKUtils SPKColor_InstagramPrimaryText];
    controller.navigationController.navigationBar.tintColor = ink;
    entry.tintColor = ink;

    UIImage *chevron =
        [UIImage systemImageNamed:@"chevron.backward"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                                                  weight:UIImageSymbolWeightSemibold]];

    for (UIBarButtonItem *instagramItem in instagramItems) {
        instagramItem.tintColor = ink;
        [instagramItem setTitleTextAttributes:@{ NSForegroundColorAttributeName : ink }
                                     forState:UIControlStateNormal];

        if (instagramItem.customView || !chevron)
            continue;
        instagramItem.title = nil;
        instagramItem.image = chevron;
        instagramItem.accessibilityLabel = @"Back";
    }

    controller.navigationItem.leftBarButtonItems = instagramItems;
    controller.navigationItem.rightBarButtonItems = @[ entry ];
}

static void SPKSeatSettingsEntryItem(UIViewController *controller) {
    if (!SPKIsNativeSettingsController(controller))
        return;

    // The entry is built once and kept. The arranging runs on every appearance,
    // because Instagram restyles this bar and would otherwise take its blue Done
    // back the moment the screen is revisited.
    UIBarButtonItem *entry = objc_getAssociatedObject(controller, kSPKSettingsEntryItemAssocKey);

    NSMutableArray<UIBarButtonItem *> *instagramItems = [NSMutableArray array];
    for (UIBarButtonItem *barItem in controller.navigationItem.rightBarButtonItems) {
        if (barItem != entry)
            [instagramItems addObject:barItem];
    }
    for (UIBarButtonItem *barItem in controller.navigationItem.leftBarButtonItems) {
        if (barItem != entry && ![instagramItems containsObject:barItem])
            [instagramItems addObject:barItem];
    }

    if (!entry) {
        UIImage *icon =
            [UIImage systemImageNamed:@"sparkles"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                      weight:UIImageSymbolWeightRegular]];
        entry = [[UIBarButtonItem alloc] initWithImage:icon
                                                 style:UIBarButtonItemStylePlain
                                                target:[SPKNativeSettingsEntryTarget sharedTarget]
                                                action:@selector(openSparkleSettings:)];
        entry.accessibilityLabel = @"Sparkle";
        objc_setAssociatedObject(controller, kSPKSettingsEntryItemAssocKey, entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [SPKNativeSettingsEntryTarget sharedTarget].owner = controller;
    SPKArrangeSettingsBar(controller, entry, instagramItems);
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
