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
// Read from the 441 binary, and the reason nothing here guesses a value:
//   IGCommentThreadViewController  -didTapSortingView:            v24@0:8@16
//   IGCommentThreadViewController  ivar _threadManager, _commentSortingMenuController
//   IGCommentSortingMenuController -presentMenuFromOriginView:    v24@0:8@16
//   IGCommentThread                -sortOrder (NSString), ivar _sortOptions
//
// The menu entries arrive from the backend through the GraphQL fragment
// IGCommentSortingMenuControllerMenuItemsForMediaFragment, attached to the
// media, and no sort value exists as a literal anywhere in the binary. An
// account the backend does not serve therefore gets an empty menu. That case
// reports itself instead of leaving a dead control, and the reading is kept so
// what the backend served can be inspected afterwards.

static NSString *const kSPKCommentSortMenuKey = @"feed_comments_sort_menu";
static NSString *const kSPKCommentSortReadingKey = @"spk_diag_comment_sort";

static const void *kSPKCommentSortEntryAssocKey = &kSPKCommentSortEntryAssocKey;
static const void *kSPKCommentSortTargetAssocKey = &kSPKCommentSortTargetAssocKey;

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
// that is at least readable in the log.
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

// Keeps the last three readings rather than one: reaching the settings goes
// through other screens, and a single slot is overwritten before it can be read.
static void SPKCommentSortRecordReading(NSArray *options, NSString *current, id menuController) {
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (id option in options) {
        [labels addObject:SPKCommentSortOptionLabel(option)];
        if (labels.count >= 4)
            break;
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";

    NSString *line = [NSString stringWithFormat:@"%@ · options %lu [%@] · current %@ · menu %@",
                                                [formatter stringFromDate:[NSDate date]],
                                                (unsigned long)options.count,
                                                labels.count ? [labels componentsJoinedByString:@", "] : @"—",
                                                current.length ? current : @"—",
                                                menuController ? NSStringFromClass([menuController class]) : @"nil"];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *history = [([defaults arrayForKey:kSPKCommentSortReadingKey] ?: @[]) mutableCopy];
    [history insertObject:line atIndex:0];
    while (history.count > 3)
        [history removeLastObject];
    [defaults setObject:history forKey:kSPKCommentSortReadingKey];
}

#pragma mark - Entry target

@interface SPKCommentSortMenuTarget : NSObject
@property (nonatomic, weak) UIViewController *controller;
- (void)presentSortMenu:(UIButton *)sender;
@end

@implementation SPKCommentSortMenuTarget

- (void)presentSortMenu:(UIButton *)sender {
    UIViewController *controller = self.controller;
    if (!controller)
        return;

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

    SPKCommentSortRecordReading(options,
                                [current isKindOfClass:[NSString class]] ? current : nil,
                                menuController);

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
                                 ? [NSString stringWithFormat:@"%lu sort options were served, but the menu did not open.",
                                                              (unsigned long)servedCount]
                                 : @"Instagram served no sorting options for this post.";
        SPKNotify(kSPKNotificationCommentSortUnavailable, @"Comment Sorting", subtitle, @"sort",
                  servedCount > 0 ? SPKNotificationToneInfo : SPKNotificationToneError);
    });
}

@end

#pragma mark - Entry control

static void SPKSeatCommentSortEntry(UIViewController *controller) {
    if (![controller isViewLoaded])
        return;
    if (objc_getAssociatedObject(controller, kSPKCommentSortEntryAssocKey))
        return;
    // The thread carries the delegate method on every path that can sort; a
    // controller without it gets no control rather than a control that fails.
    if (![controller respondsToSelector:NSSelectorFromString(@"didTapSortingView:")])
        return;

    SPKCommentSortMenuTarget *target = [SPKCommentSortMenuTarget new];
    target.controller = controller;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.labelColor;
    button.accessibilityLabel = @"Sort comments";
    [button setImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                            weight:UIImageSymbolWeightSemibold]]
            forState:UIControlStateNormal];
    [button addTarget:target action:@selector(presentSortMenu:) forControlEvents:UIControlEventTouchUpInside];

    // Glass on iOS 26, the tweak's own capsule fill everywhere else.
    if (!SPKChipApplyGlass(button, NO, 17.0, nil)) {
        button.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.92];
        button.layer.cornerRadius = 17.0;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.clipsToBounds = YES;
    }

    [controller.view addSubview:button];

    UILayoutGuide *guide = controller.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0],
        [button.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-12.0],
        [button.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12.0],
    ]];

    objc_setAssociatedObject(controller, kSPKCommentSortTargetAssocKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kSPKCommentSortEntryAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Hook

%group SPKCommentSortMenuHooks

%hook IGCommentThreadViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKSeatCommentSortEntry(self);
}

%end

%end

void SPKInstallCommentSortMenuHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:kSPKCommentSortMenuKey])
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCommentSortMenuHooks);
    });
}
