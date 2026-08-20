#import "../../Utils.h"
#import "../../Shared/UI/SPKChrome.h"
#import <objc/runtime.h>

// A floating way into Sparkle for the one configuration that has no other.
//
// Hiding the tab bar takes the tab bar's long-press with it, and the profile
// tab that leads to Instagram's own settings screen — where the sparkle button
// lives — is hidden too by then. The row that hides the bar promises "Sparkle
// then opens from the sparkle button in the Messages header", but that header
// button installs only under conditions of its own, so the promise can go
// unkept. This button keeps it.
//
// It exists only while the bar is hidden. Nothing to switch on, nothing to
// discover: the door appears exactly when the other doors close.
//
// The drag behaviour mirrors the seen bubble in Messages — move it out of the
// way, it stays where you put it, and it returns on its own after a while.

static const void *kSPKFloatingButtonAssocKey = &kSPKFloatingButtonAssocKey;

static const CGFloat kSPKFloatingButtonDiameter = 44.0;
static const CGFloat kSPKFloatingButtonMargin = 16.0;
// Long enough to use the screen underneath, short enough that the button is
// back in its corner before you look for it again.
static const NSTimeInterval kSPKFloatingButtonReturnDelay = 4.0;

#pragma mark - Condition

// Mirrors SPKIsMessagesOnlyMode() in AppBootstrap.xm, which is static there.
static BOOL SPKFloatingButtonMessagesOnlyMode(void) {
    BOOL messagesVisible = ![SPKUtils getBoolPref:@"interface_hide_msgs_tab"];
    BOOL feedHidden = [SPKUtils getBoolPref:@"interface_hide_feed_tab"];
    BOOL exploreHidden = [SPKUtils getBoolPref:@"interface_hide_explore_tab"];
    BOOL reelsHidden = [SPKUtils getBoolPref:@"interface_hide_reels_tab"];
    BOOL profileHidden = [SPKUtils getBoolPref:@"interface_hide_profile_tab"];

    BOOL usesClassic = [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
    BOOL createHidden = !usesClassic || [SPKUtils getBoolPref:@"interface_hide_create_tab"];

    return messagesVisible && feedHidden && exploreHidden && reelsHidden && profileHidden && createHidden;
}

// The single preference that actually removes the bar. The six per-tab keys
// hide tabs one by one; the bar itself stays.
static BOOL SPKFloatingButtonShouldShow(void) {
    return [SPKUtils getBoolPref:@"interface_hide_tab_bar_in_messages_only"] &&
           SPKFloatingButtonMessagesOnlyMode();
}

#pragma mark - Placement

static UIWindow *SPKFloatingButtonHostWindow(void) {
    UIWindow *best = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isHidden || window.alpha <= 0.01)
                continue;
            if (window.isKeyWindow)
                return window;
            if (!best)
                best = window;
        }
    }
    return best;
}

// Bottom trailing corner: the tab bar's own footprint, now free, and the one
// place a thumb reaches without covering content.
static CGPoint SPKFloatingButtonHomeCenter(UIView *host) {
    UIEdgeInsets safe = host.safeAreaInsets;
    CGFloat half = kSPKFloatingButtonDiameter / 2.0;
    return CGPointMake(CGRectGetWidth(host.bounds) - safe.right - kSPKFloatingButtonMargin - half,
                       CGRectGetHeight(host.bounds) - safe.bottom - kSPKFloatingButtonMargin - half);
}

static void SPKFloatingButtonSendHome(UIView *button, BOOL animated) {
    UIView *host = button.superview;
    if (!host)
        return;

    CGPoint home = SPKFloatingButtonHomeCenter(host);
    if (!animated) {
        button.center = home;
        return;
    }
    [UIView animateWithDuration:0.32
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ button.center = home; }
                     completion:nil];
}

#pragma mark - Target

@interface SPKFloatingSettingsButtonTarget : NSObject
+ (instancetype)sharedTarget;
- (void)tapped:(id)sender;
- (void)panned:(UIPanGestureRecognizer *)pan;
@end

@implementation SPKFloatingSettingsButtonTarget

+ (instancetype)sharedTarget {
    static SPKFloatingSettingsButtonTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ target = [SPKFloatingSettingsButtonTarget new]; });
    return target;
}

- (void)tapped:(id)sender {
    UIView *button = [sender isKindOfClass:[UIView class]] ? (UIView *)sender : nil;
    UIWindow *window = (UIWindow *)button.window ?: SPKFloatingButtonHostWindow();
    if (window)
        [SPKUtils showSettingsVC:window];
}

- (void)panned:(UIPanGestureRecognizer *)pan {
    UIView *button = pan.view;
    UIView *host = button.superview;
    if (!host)
        return;

    switch (pan.state) {
    case UIGestureRecognizerStateBegan:
    case UIGestureRecognizerStateChanged: {
        CGPoint translation = [pan translationInView:host];
        CGPoint center = button.center;
        center.x += translation.x;
        center.y += translation.y;

        // Never off-screen and never under a notch or a home indicator.
        UIEdgeInsets safe = host.safeAreaInsets;
        CGFloat half = CGRectGetWidth(button.bounds) / 2.0;
        center.x = MAX(safe.left + half, MIN(CGRectGetWidth(host.bounds) - safe.right - half, center.x));
        center.y = MAX(safe.top + half, MIN(CGRectGetHeight(host.bounds) - safe.bottom - half, center.y));

        button.center = center;
        [pan setTranslation:CGPointZero inView:host];
        [host bringSubviewToFront:button];
        break;
    }
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed: {
        // Returns on its own, so a button dragged aside is never lost.
        __weak UIView *weakButton = button;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSPKFloatingButtonReturnDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIView *strongButton = weakButton;
            if (strongButton && strongButton.superview)
                SPKFloatingButtonSendHome(strongButton, YES);
        });
        break;
    }
    default:
        break;
    }
}

@end

#pragma mark - Install

static void SPKFloatingButtonRemove(UIWindow *window) {
    UIView *existing = objc_getAssociatedObject(window, kSPKFloatingButtonAssocKey);
    [existing removeFromSuperview];
    objc_setAssociatedObject(window, kSPKFloatingButtonAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKFloatingButtonInstallInWindow(UIWindow *window) {
    if (!window)
        return;

    if (!SPKFloatingButtonShouldShow()) {
        SPKFloatingButtonRemove(window);
        return;
    }

    SPKChromeButton *button = objc_getAssociatedObject(window, kSPKFloatingButtonAssocKey);
    if (button.superview == window) {
        // Already seated. The corner is re-read on every layout pass, and a
        // dragged button returns on its own, so there is nothing to redo here.
        [window bringSubviewToFront:button];
        return;
    }

    button = [[SPKChromeButton alloc] initWithSymbol:@""
                                           pointSize:22.0
                                            diameter:kSPKFloatingButtonDiameter];
    // The same glyph the header button already draws for Sparkle, so the two
    // read as the same door rather than two unrelated buttons.
    [button setIconResource:@"action" pointSize:22.0];
    button.iconTint = UIColor.labelColor;
    // Without a bubble the glyph floats on whatever is underneath and vanishes
    // on a light screen. The seen bubble in Messages solves this the same way.
    button.bubbleColor = UIColor.clearColor;
    button.bubbleEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.16;
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    button.clipsToBounds = NO;
    button.translatesAutoresizingMaskIntoConstraints = YES;
    button.accessibilityLabel = @"Sparkle settings";
    [button addTarget:[SPKFloatingSettingsButtonTarget sharedTarget]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    // A quick tap still opens the settings: the pan only takes over once the
    // finger actually travels.
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:[SPKFloatingSettingsButtonTarget sharedTarget]
                                                action:@selector(panned:)];
    [button addGestureRecognizer:pan];

    button.bounds = CGRectMake(0, 0, kSPKFloatingButtonDiameter, kSPKFloatingButtonDiameter);
    [window addSubview:button];
    SPKFloatingButtonSendHome(button, NO);

    objc_setAssociatedObject(window, kSPKFloatingButtonAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKRefreshFloatingSettingsButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SPKFloatingButtonInstallInWindow(SPKFloatingButtonHostWindow());
    });
}

%group SPKFloatingSettingsButtonHooks

%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    SPKFloatingButtonInstallInWindow(self);
}

- (void)layoutSubviews {
    %orig;

    // This is the path that actually seats the button. becomeKeyWindow fires
    // only when a window BECOMES key — a window that already was key when the
    // tweak loaded never calls it again, and at install time there may be no
    // window at all. Layout, on the other hand, always comes back.
    if (self.isHidden || self.alpha <= 0.01)
        return;
    if (![self isKindOfClass:[UIWindow class]] || self.windowLevel > UIWindowLevelNormal)
        return;

    SPKFloatingButtonInstallInWindow(self);
}

%end

%end

void SPKInstallFloatingSettingsButtonHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKFloatingSettingsButtonHooks);
    });

    // The window may already be key by the time this runs.
    SPKRefreshFloatingSettingsButton();
}
