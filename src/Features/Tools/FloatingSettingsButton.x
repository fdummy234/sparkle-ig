#import "../../Utils.h"
#import "../../Shared/UI/SPKChrome.h"
#import <objc/message.h>
#import <objc/runtime.h>

// A floating way back to Instagram's settings once the profile tab is hidden.
//
// That screen is reached from your own profile, and the sparkle button that
// opens Sparkle lives inside it — so hiding the profile tab closes both doors
// at once. From that toggle on, this button rides every tab and reopens them.
//
// Nothing to switch on and nothing to find: it appears exactly when the other
// route disappears, and goes away again when the tab comes back.
//
// The drag behaviour mirrors the seen bubble in Messages — move it out of the
// way, it stays where you put it, and it returns to its corner on its own.

static const void *kSPKFloatingButtonAssocKey = &kSPKFloatingButtonAssocKey;

static const CGFloat kSPKFloatingButtonDiameter = 44.0;
static const CGFloat kSPKFloatingButtonMargin = 16.0;
// Long enough to use the screen underneath, short enough that the button is
// back in its corner before you look for it again.
static const NSTimeInterval kSPKFloatingButtonReturnDelay = 4.0;

#pragma mark - Condition

// Hiding the profile tab is what cuts the route to Instagram's own settings
// screen: that screen is reached from your profile, and the sparkle button
// that opens Sparkle lives inside it. From that toggle on, this button is the
// way back — on every tab, not only in Messages.
static BOOL SPKFloatingButtonShouldShow(void) {
    return [SPKUtils getBoolPref:@"interface_hide_profile_tab"];
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

// Where the tab bar's top edge sits, in host coordinates.
//
// Only the profile tab is hidden here, so the bar is still on screen and the
// safe area alone would drop the button straight onto it. The bar is found by
// walking the tree for a view whose class carries "TabBar" — asked of the live
// hierarchy rather than assumed from a class name, since Instagram renames
// these between versions. Returns CGFLOAT_MAX when there is no bar to clear.
static CGFloat SPKFloatingButtonTabBarTop(UIView *host, NSInteger depth) {
    if (!host || depth > 6)
        return CGFLOAT_MAX;

    CGFloat top = CGFLOAT_MAX;
    for (UIView *view in host.subviews) {
        if (view.isHidden || view.alpha <= 0.05)
            continue;

        const char *name = class_getName([view class]);
        if (name && strstr(name, "TabBar") && CGRectGetHeight(view.bounds) > 1.0)
            top = MIN(top, CGRectGetMinY([view convertRect:view.bounds toView:nil]));

        top = MIN(top, SPKFloatingButtonTabBarTop(view, depth + 1));
    }
    return top;
}

// Bottom trailing corner, clear of whatever chrome is down there.
static CGPoint SPKFloatingButtonHomeCenter(UIView *host) {
    UIEdgeInsets safe = host.safeAreaInsets;
    CGFloat half = kSPKFloatingButtonDiameter / 2.0;

    CGFloat floor = CGRectGetHeight(host.bounds) - safe.bottom;
    CGFloat tabBarTop = SPKFloatingButtonTabBarTop(host, 0);
    if (tabBarTop < CGFLOAT_MAX)
        floor = MIN(floor, tabBarTop);

    return CGPointMake(CGRectGetWidth(host.bounds) - safe.right - kSPKFloatingButtonMargin - half,
                       floor - kSPKFloatingButtonMargin - half);
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

// Instagram's own "Settings and activity" screen, which is what the hidden
// profile tab took away. Its controller cannot be built from here — the tweak
// only ever recognises it by class name at runtime — so the app is asked to
// route to it the way it routes any internal link, which is the same engine
// SPKUtils already uses to open a profile.
//
// instagram://settings is a link the app itself carries; it is read out of the
// binary, not invented. If the route is refused, Sparkle's own settings open
// instead, so the button always leads somewhere.
static BOOL SPKFloatingButtonOpenInstagramSettings(void) {
    Class urlHandlerClass = objc_getClass("IGURLHandler");
    NSURL *settingsURL = [NSURL URLWithString:@"instagram://settings"];
    if (!urlHandlerClass || !settingsURL)
        return NO;

    id session = [SPKUtils activeUserSession];
    if (!session)
        return NO;

    UIViewController *presenter = SPKFloatingButtonHostWindow().rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;

    SEL internalRoute = @selector(openInternalURL:presentationConfig:controller:animated:userSession:annotation:);
    if ([urlHandlerClass respondsToSelector:internalRoute]) {
        typedef BOOL (*OpenInternalFunc)(Class, SEL, id, id, id, BOOL, id, id);
        OpenInternalFunc route = (OpenInternalFunc)objc_msgSend;
        if (route(urlHandlerClass, internalRoute, settingsURL, nil, presenter, YES, session, nil))
            return YES;
    }

    SEL plainRoute = @selector(openURL:userSession:completionHandler:);
    if ([urlHandlerClass respondsToSelector:plainRoute]) {
        typedef void (*OpenURLFunc)(Class, SEL, id, id, id);
        OpenURLFunc route = (OpenURLFunc)objc_msgSend;
        route(urlHandlerClass, plainRoute, settingsURL, session, nil);
        return YES;
    }
    return NO;
}

- (void)tapped:(id)sender {
    if (SPKFloatingButtonOpenInstagramSettings())
        return;

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
                                           pointSize:24.0
                                            diameter:kSPKFloatingButtonDiameter];
    // The same glyph the header button already draws for Sparkle, so the two
    // read as the same door rather than two unrelated buttons.
    // Measured against the tab bar's own glyphs, which are 22 pt: at 20 pt this
    // one read as the smaller of the two.
    [button setIconResource:@"action" pointSize:24.0];
    button.iconTint = UIColor.labelColor;
    // The same material the tab bar underneath is made of, so the button reads
    // as part of the chrome rather than pasted over it. Glass on iOS 26, system
    // material before — the fallback SPKActionMenu already uses.
    button.bubbleColor = UIColor.clearColor;
    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    UIVisualEffect *material = glassEffectClass
        ? [[glassEffectClass alloc] init]
        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    // Interactive glass deforms under a finger instead of sitting flat. Set by
    // key so it is a no-op, not a crash, where the property does not exist.
    if ([material respondsToSelector:NSSelectorFromString(@"setInteractive:")])
        [material setValue:@YES forKey:@"interactive"];
    button.bubbleEffect = material;
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
