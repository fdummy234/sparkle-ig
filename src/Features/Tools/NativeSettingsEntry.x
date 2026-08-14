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
static const void *kSPKSettingsEntryRetryAssocKey = &kSPKSettingsEntryRetryAssocKey;
// Bounded so a bar that genuinely never gets a title cannot spin on layout.
static NSInteger const kSPKSettingsEntryMaxTitleRetries = 12;
static CGFloat const kSPKSettingsEntryButtonSize = 40.0;
static CGFloat const kSPKSettingsEntryButtonInset = 8.0;
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
        SPKLog(@"Settings", @"[Sparkle] Settings entry seated in the navigation bar");
    }

    // SwiftUI re-adds its own content on each pass, so the button is brought
    // back to the front rather than added once.
    if (button.superview != self)
        [self addSubview:button];
    [self bringSubviewToFront:button];
    button.hidden = NO;

    // Containers move between iOS versions; the title does not. It sits in the
    // middle of the control row by definition, so its centre is the one to
    // match — found by walking down to the deepest label with text.
    CGFloat size = kSPKSettingsEntryButtonSize;
    CGRect bounds = self.bounds;
    UILabel *titleLabel = nil;
    NSMutableArray<UIView *> *queue = [self.subviews mutableCopy];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (view == button)
            continue;
        if ([view isKindOfClass:[UILabel class]] && ((UILabel *)view).text.length > 0 &&
            (!titleLabel || CGRectGetWidth(view.bounds) > CGRectGetWidth(titleLabel.bounds)))
            titleLabel = (UILabel *)view;
        [queue addObjectsFromArray:view.subviews];
    }

    // On the first layout pass the bar has no title yet. Rather than place the
    // icon at a guessed height and let it jump when the title arrives, keep it
    // hidden until there is something to align with.
    //
    // Hiding alone was not enough: during a tab or back swipe the title leaves
    // for a pass, and if that pass is the LAST one the bar performs, the icon
    // stayed hidden until Instagram was restarted. So ask for another pass
    // rather than giving up — bounded, and only while this really is the
    // settings screen (checked at the top of this method).
    if (!titleLabel) {
        button.hidden = YES;
        NSNumber *attempts = objc_getAssociatedObject(self, kSPKSettingsEntryRetryAssocKey);
        if (attempts.integerValue < kSPKSettingsEntryMaxTitleRetries) {
            objc_setAssociatedObject(self, kSPKSettingsEntryRetryAssocKey, @(attempts.integerValue + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            __weak UINavigationBar *weakBar = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakBar setNeedsLayout];
            });
        }
        return;
    }
    // Placed successfully: the next disappearance gets a fresh set of retries.
    objc_setAssociatedObject(self, kSPKSettingsEntryRetryAssocKey, @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGFloat centreY = CGRectGetMidY([titleLabel convertRect:titleLabel.bounds toView:self]);

    // Mirror the leading inset of whatever sits on the other side of the title.
    CGFloat inset = kSPKSettingsEntryButtonInset;
    UIView *leading = nil;
    for (UIView *child in (titleLabel.superview ? titleLabel.superview.subviews : self.subviews)) {
        if (child == button || child == titleLabel || CGRectIsEmpty(child.frame))
            continue;
        CGRect f = [child convertRect:child.bounds toView:self];
        if (CGRectGetWidth(f) > CGRectGetWidth(bounds) * 0.4)
            continue;
        if (!leading || CGRectGetMinX(f) < CGRectGetMinX([leading convertRect:leading.bounds toView:self]))
            leading = child;
    }
    if (leading) {
        CGFloat x = CGRectGetMinX([leading convertRect:leading.bounds toView:self]);
        if (x < CGRectGetWidth(bounds) * 0.25)
            inset = x;
    }

    button.frame = CGRectMake(CGRectGetMaxX(bounds) - size - inset,
                              centreY - size / 2.0,
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
