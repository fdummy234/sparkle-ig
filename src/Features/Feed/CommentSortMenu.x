#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/UI/SPKChipGlass.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Surfaces Instagram's own comment sorting menu inside a comment thread.
//
// Instagram 441 ships the whole sorting stack — IGCommentSortingMenuController,
// IGCommentSortingSectionController, the "Top comments" and "Most recent"
// labels, a sticky preference and an analytics event — but the entry point is
// never drawn. A control on the thread calls the controller's own delegate
// method, so the app builds the menu, applies the choice and remembers it.
//
// Measured in the 441 binary:
//   IGCommentThreadViewController  -didTapSortingView:            v24@0:8@16
//   IGCommentThreadViewController  -viewDidAppear: is implemented on the class
//   IGCommentThreadViewController  ivar _threadManager, _commentSortingMenuController
//   IGCommentSortingMenuController -presentMenuFromOriginView:    v24@0:8@16
//   IGCommentThread                -sortOrder (NSString), ivar _sortOptions
//   Exactly one class in the whole binary carries -didTapSortingView:.
//
// Measured on device with FLEX, on the open comments sheet:
//   Nearest View Controller = IGCommentThreadViewController
//   Its view is an IGDSShimmeringGroupView 440x1005 — taller than the visible
//   sheet, so its top edge lies behind the sheet's own "Comments" header.
//
// That last measurement is why the control is attached to the window rather
// than to the controller's view: the controller's top is not a reliable place
// to put anything visible. The window's safe area is.
//
// Each stage writes what it did, and Feed → Comments → Sort Menu Report shows
// it. Reading that row says whether the installer ran, whether the hooks were
// installed, whether the hook fired and on which class — the one thing three
// earlier attempts could not establish.

static NSString *const kSPKCommentSortMenuKey = @"feed_comments_sort_menu";
static NSString *const kSPKCommentSortStateKey = @"spk_diag_comment_sort";

static const void *kSPKCommentSortEntryAssocKey = &kSPKCommentSortEntryAssocKey;
static const void *kSPKCommentSortTargetAssocKey = &kSPKCommentSortTargetAssocKey;

#pragma mark - Reading kept where the settings can show it

// A short history rather than one slot: reaching the settings crosses other
// screens, and a single value is overwritten before it can be read.
static void SPKCommentSortNote(NSString *line) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *history = [([defaults arrayForKey:kSPKCommentSortStateKey] ?: @[]) mutableCopy];
    [history insertObject:[NSString stringWithFormat:@"%@ %@", [formatter stringFromDate:[NSDate date]], line]
                  atIndex:0];
    while (history.count > 5)
        [history removeLastObject];
    [defaults setObject:history forKey:kSPKCommentSortStateKey];
    [defaults synchronize];
}

#pragma mark - Runtime reading

// Reads an object ivar directly: KVC raises on a key the class does not carry,
// and the ivars read here have no published accessors.
static id SPKCommentSortIvarValue(id object, const char *name) {
    if (!object || !name)
        return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    if (!ivar)
        return nil;
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding || (encoding[0] != '@' && encoding[0] != '#'))
        return nil;
    return object_getIvar(object, ivar);
}

static id SPKCommentSortSend(id target, SEL selector) {
    if (!target || !selector || ![target respondsToSelector:selector])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

// A served sort option carries its own wire value. Its shape is decided by the
// backend, so several published names are tried before falling back to a label
// that is at least readable in the report.
static NSString *SPKCommentSortOptionLabel(id option) {
    if (!option)
        return @"nil";
    if ([option isKindOfClass:[NSString class]])
        return (NSString *)option;

    for (NSString *name in @[ @"sortOrderString", @"sortOrder", @"value", @"identifier" ]) {
        id value = SPKCommentSortSend(option, NSSelectorFromString(name));
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0)
            return (NSString *)value;
    }

    id ivarValue = SPKCommentSortIvarValue(option, "_sortOrder_sortOrderString");
    if ([ivarValue isKindOfClass:[NSString class]])
        return (NSString *)ivarValue;

    return NSStringFromClass([option class]);
}

#pragma mark - Entry target

@interface SPKCommentSortMenuTarget : NSObject
@property (nonatomic, weak) UIViewController *controller;
- (void)presentSortMenu:(UIButton *)sender;
@end

@implementation SPKCommentSortMenuTarget

- (void)presentSortMenu:(UIButton *)sender {
    UIViewController *controller = self.controller;
    if (!controller) {
        SPKCommentSortNote(@"tap · controller gone");
        return;
    }

    id manager = SPKCommentSortIvarValue(controller, "_threadManager");
    id thread = SPKCommentSortSend(manager, NSSelectorFromString(@"commentThread"));
    if (!thread)
        thread = SPKCommentSortIvarValue(manager, "commentThread");

    NSArray *options = SPKCommentSortIvarValue(thread, "_sortOptions");
    if (![options isKindOfClass:[NSArray class]])
        options = nil;

    id current = SPKCommentSortSend(thread, NSSelectorFromString(@"sortOrder"));
    if (![current isKindOfClass:[NSString class]])
        current = SPKCommentSortSend(manager, NSSelectorFromString(@"sortOrder"));

    id menuController = SPKCommentSortIvarValue(controller, "_commentSortingMenuController");

    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (id option in options) {
        [labels addObject:SPKCommentSortOptionLabel(option)];
        if (labels.count >= 4)
            break;
    }
    SPKCommentSortNote([NSString stringWithFormat:@"tap · options %lu [%@] · current %@ · menu %@",
                                                  (unsigned long)options.count,
                                                  labels.count ? [labels componentsJoinedByString:@", "] : @"none",
                                                  [current isKindOfClass:[NSString class]] ? current : @"none",
                                                  menuController ? @"built" : @"nil"]);

    UIViewController *presentedBefore = controller.presentedViewController;
    UIViewController *rootPresentedBefore = controller.view.window.rootViewController.presentedViewController;

    SEL didTapSorting = NSSelectorFromString(@"didTapSortingView:");
    SEL presentMenu = NSSelectorFromString(@"presentMenuFromOriginView:");
    if ([controller respondsToSelector:didTapSorting]) {
        ((void (*)(id, SEL, id))objc_msgSend)(controller, didTapSorting, sender);
    } else if ([menuController respondsToSelector:presentMenu]) {
        ((void (*)(id, SEL, id))objc_msgSend)(menuController, presentMenu, sender);
    }

    // Nothing on screen shortly after the call means the backend served no menu
    // for this media. Saying so beats a control that appears to do nothing.
    __weak UIViewController *weakController = controller;
    NSUInteger servedCount = options.count;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (!strongController)
            return;
        if (strongController.presentedViewController != presentedBefore)
            return;
        if (strongController.view.window.rootViewController.presentedViewController != rootPresentedBefore)
            return;

        NSString *subtitle = servedCount > 0
                                 ? [NSString stringWithFormat:@"%lu options served, menu did not open.",
                                                              (unsigned long)servedCount]
                                 : @"No sorting options served for this post.";
        SPKCommentSortNote([NSString stringWithFormat:@"menu did not open · options %lu", (unsigned long)servedCount]);
        SPKNotify(kSPKNotificationCommentSortUnavailable, @"Comment Sorting", subtitle, @"sort",
                  servedCount > 0 ? SPKNotificationToneInfo : SPKNotificationToneError);
    });
}

@end

#pragma mark - Entry control

// Attached to the window, not to the controller's view: the controller's view
// measures 440x1005 with its top behind the sheet's header, so nothing placed
// at its top edge is reliably visible.
static void SPKSeatCommentSortEntry(UIViewController *host) {
    if (objc_getAssociatedObject(host, kSPKCommentSortEntryAssocKey))
        return;

    UIWindow *window = host.view.window;
    if (!window) {
        SPKCommentSortNote([NSString stringWithFormat:@"seat skipped · %@ has no window",
                                                      NSStringFromClass([host class])]);
        return;
    }

    SPKCommentSortMenuTarget *entryTarget = [SPKCommentSortMenuTarget new];
    entryTarget.controller = host;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.labelColor;
    button.accessibilityLabel = @"Sort comments";
    [button setImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                            weight:UIImageSymbolWeightSemibold]]
            forState:UIControlStateNormal];
    [button addTarget:entryTarget action:@selector(presentSortMenu:) forControlEvents:UIControlEventTouchUpInside];

    // Glass on iOS 26, the tweak's own capsule fill everywhere else.
    if (!SPKChipApplyGlass(button, NO, 17.0, nil)) {
        button.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.92];
        button.layer.cornerRadius = 17.0;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.clipsToBounds = YES;
    }
    button.layer.zPosition = 5000.0;

    [window addSubview:button];
    [window bringSubviewToFront:button];

    // The sheet's trailing corner holds Instagram's send button, so the control
    // takes the leading side, low enough to clear the status bar.
    UILayoutGuide *guide = window.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0],
        [button.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:12.0],
        [button.centerYAnchor constraintEqualToAnchor:guide.centerYAnchor constant:-140.0],
    ]];

    objc_setAssociatedObject(host, kSPKCommentSortTargetAssocKey, entryTarget, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(host, kSPKCommentSortEntryAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    SPKCommentSortNote([NSString stringWithFormat:@"SEATED on window · host %@", NSStringFromClass([host class])]);
}

static void SPKRemoveCommentSortEntry(UIViewController *host) {
    UIButton *button = objc_getAssociatedObject(host, kSPKCommentSortEntryAssocKey);
    if (!button)
        return;
    [button removeFromSuperview];
    objc_setAssociatedObject(host, kSPKCommentSortEntryAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(host, kSPKCommentSortTargetAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Hooks

%group SPKCommentSortMenuHooks

%hook IGCommentThreadViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKCommentSortNote([NSString stringWithFormat:@"HOOK FIRED · %@", NSStringFromClass([self class])]);
    SPKSeatCommentSortEntry((UIViewController *)self);

    // The window is not always attached on the first pass.
    __weak UIViewController *weakSelf = (UIViewController *)self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongSelf = weakSelf;
        if (strongSelf)
            SPKSeatCommentSortEntry(strongSelf);
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    SPKRemoveCommentSortEntry((UIViewController *)self);
    %orig;
}

%end

%end

void SPKInstallCommentSortMenuHooksIfEnabled(void) {
    BOOL enabled = [SPKUtils getBoolPref:kSPKCommentSortMenuKey];
    SPKCommentSortNote([NSString stringWithFormat:@"installer ran · pref %@", enabled ? @"ON" : @"OFF"]);
    if (!enabled)
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCommentSortMenuHooks);
        SPKCommentSortNote(@"hooks installed");
    });
}
