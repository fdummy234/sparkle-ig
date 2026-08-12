#import "../../Utils.h"
#import <objc/runtime.h>

// Sparkle's single visible entry point: a ✦ button in the navigation bar of
// Instagram's own "Settings and activity" screen.
//
// Two things make that screen hostile to a plain rightBarButtonItem: it is
// hosted by SwiftUI, which owns its toolbar and rebuilds it as the view
// settles, and its controller is a Swift generic the runtime only registers
// once its module loads. So the button is not a bar button item at all — it is
// a view parented to the navigation bar and re-seated on every layout pass,
// the same approach the inbox header button already uses against this app.
//
// The hook sits on UINavigationBar rather than on any Instagram class: UIKit is
// always present, and the bar is walked back to its owning controller to decide
// whether this is the settings screen.

static const void *kSPKSettingsEntryButtonAssocKey = &kSPKSettingsEntryButtonAssocKey;
static CGFloat const kSPKSettingsEntryButtonSize = 40.0;
static CGFloat const kSPKSettingsEntryButtonInset = 8.0;
static BOOL SPKNativeSettingsEntryDidInstall = NO;

BOOL SPKNativeSettingsEntryInstalled(void) {
    return SPKNativeSettingsEntryDidInstall;
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
    UIWindow *window = [sender isKindOfClass:[UIView class]] ? ((UIView *)sender).window : nil;
    [SPKUtils showSettingsVC:window ?: [UIApplication sharedApplication].keyWindow];
}

@end

// Identified by two independent signals so a rename on either side still lands:
// the Swift class name, or the title Instagram gives the screen.
static BOOL SPKIsNativeSettingsController(UIViewController *controller) {
    if (!controller)
        return NO;
    const char *name = class_getName(object_getClass(controller));
    if (name && strstr(name, "IGSettingsHostingController"))
        return YES;
    return [controller.title isEqualToString:@"Settings and activity"];
}

static UIViewController *SPKControllerForNavigationBar(UINavigationBar *bar) {
    UIResponder *responder = bar.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:[UINavigationController class]])
            return ((UINavigationController *)responder).topViewController;
        responder = responder.nextResponder;
    }
    return nil;
}

%group SPKNativeSettingsEntryHooks
%hook UINavigationBar

- (void)layoutSubviews {
    %orig;

    UIButton *button = objc_getAssociatedObject(self, kSPKSettingsEntryButtonAssocKey);
    if (!SPKIsNativeSettingsController(SPKControllerForNavigationBar(self))) {
        button.hidden = YES;
        return;
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *icon = [UIImage systemImageNamed:@"sparkles"
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                                                  weight:UIImageSymbolWeightRegular]];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
        button.accessibilityLabel = @"Sparkle";
        [button addTarget:[SPKNativeSettingsEntryTarget sharedTarget]
                   action:@selector(openSparkleSettings:)
         forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(self, kSPKSettingsEntryButtonAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SPKNativeSettingsEntryDidInstall = YES;
        SPKLog(@"Settings", @"[Sparkle] Settings entry seated in the navigation bar");
    }

    // SwiftUI re-adds its own content on each pass, so the button is brought
    // back to the front rather than added once.
    if (button.superview != self)
        [self addSubview:button];
    [self bringSubviewToFront:button];
    button.hidden = NO;

    CGFloat size = kSPKSettingsEntryButtonSize;
    CGRect bounds = self.bounds;
    button.frame = CGRectMake(CGRectGetMaxX(bounds) - size - kSPKSettingsEntryButtonInset,
                              CGRectGetMaxY(bounds) - size - (CGRectGetHeight(bounds) > 60.0 ? 6.0 : 2.0),
                              size,
                              size);
}

%end
%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNativeSettingsEntryHooks);
    });
}
