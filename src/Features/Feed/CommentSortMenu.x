#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/UI/SPKChipGlass.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

// Reorders a comment thread by the date each comment was posted.
//
// Instagram 441 ships a comment sorting stack of its own — a menu controller,
// a section controller, "Top comments" and "Most recent" labels, a sticky
// preference and an analytics event — but the entries that fill that menu are
// served by the backend, and an account the backend does not serve gets an
// empty list. Measured on device: IGCommentThread._sortOptions comes back as an
// empty array and sortOrder as nil, so asking Instagram to sort is a dead end.
//
// Sorting locally does not need any of that. Every comment already carries its
// own posting date, so the order can be rebuilt from what is on screen.
//
// Measured in the 441 binary and on a live thread:
//   IGCommentThreadViewController  -objectsForListAdapter:   @24@0:8@16
//                                  ivar _listAdapter -> IGListAdapter
//   IGListAdapter                  -performUpdatesAnimated:completion:
//   IGCommentGroup                 ivar _parentComment -> IGCommentModel
//                                  (no published accessor; read the ivar)
//   IGCommentModel                 -createdAt -> IGDate, -pk -> NSString
//   IGDate                         -timeIntervalSince1970 (double)
//
// IGCommentModel lives in FBSharedFramework rather than the main executable,
// which is why a dump of the app binary alone does not list it.
//
// The list objects are handed back untouched except for their order: comment
// groups are lifted out, sorted, and dropped back into the very positions they
// occupied. Anything that is not a comment — the caption, separators, the
// "view more" row, the typing indicator — keeps its index, so the thread keeps
// its shape whatever the chosen order.

#pragma mark - Preferences

// Master switch. Read once at launch, so it carries requiresRestart.
static NSString *const kSPKCommentSortEnabledKey = @"feed_comments_sort_menu";

// Current order. Read on every pass, so it takes effect without a restart.
static NSString *const kSPKCommentSortModeKey = @"feed_comments_sort_mode";

static NSString *const kSPKCommentSortModeDefault = @"default";
static NSString *const kSPKCommentSortModeNewest = @"newest";
static NSString *const kSPKCommentSortModeOldest = @"oldest";

// Rolling record of what each stage did, surfaced by the Sort Report row in
// Feed → Comments. Kept because a thread that refuses to reorder gives no other
// signal on a device without a console.
static NSString *const kSPKCommentSortReportKey = @"spk_diag_comment_sort";

static const void *kSPKCommentSortEntryAssocKey = &kSPKCommentSortEntryAssocKey;
static const void *kSPKCommentSortTargetAssocKey = &kSPKCommentSortTargetAssocKey;

static NSString *SPKCommentSortMode(void) {
    NSString *mode = [SPKUtils getStringPref:kSPKCommentSortModeKey];
    if ([mode isEqualToString:kSPKCommentSortModeNewest] ||
        [mode isEqualToString:kSPKCommentSortModeOldest]) {
        return mode;
    }
    return kSPKCommentSortModeDefault;
}

static NSString *SPKCommentSortModeTitle(NSString *mode) {
    if ([mode isEqualToString:kSPKCommentSortModeNewest])
        return @"Newest first";
    if ([mode isEqualToString:kSPKCommentSortModeOldest])
        return @"Oldest first";
    return @"Instagram's order";
}

#pragma mark - Report

// Five entries rather than one: reaching the settings crosses other screens, and
// a single slot is overwritten before it can be read.
static void SPKCommentSortNote(NSString *line) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *history = [([defaults arrayForKey:kSPKCommentSortReportKey] ?: @[]) mutableCopy];
    [history insertObject:[NSString stringWithFormat:@"%@ %@", [formatter stringFromDate:[NSDate date]], line]
                  atIndex:0];
    while (history.count > 5)
        [history removeLastObject];
    [defaults setObject:history forKey:kSPKCommentSortReportKey];
}

#pragma mark - Runtime reading

// Reads an object ivar directly. KVC raises on a key the class does not carry,
// and IGCommentGroup publishes no accessor for the comment it holds.
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

#pragma mark - Sort key

// The posting date of whatever a list object represents, or NAN when the object
// carries no date and therefore must not move.
//
// Two shapes are handled because the adapter is free to hand back either: a
// comment group wrapping its parent comment, or a comment on its own. Reading a
// missing ivar returns nil rather than raising, so an unexpected third shape
// simply falls through to NAN.
static double SPKCommentSortDateForObject(id object) {
    if (!object)
        return NAN;

    id comment = object;
    id parentComment = SPKCommentSortIvarValue(object, "_parentComment");
    if (parentComment)
        comment = parentComment;

    id createdAt = SPKCommentSortSend(comment, NSSelectorFromString(@"createdAt"));
    if (!createdAt)
        return NAN;

    SEL interval = NSSelectorFromString(@"timeIntervalSince1970");
    if (![createdAt respondsToSelector:interval])
        return NAN;

    // objc_msgSend_fpret does not exist on arm64; the plain entry point returns
    // floating point values there.
    return ((double (*)(id, SEL))objc_msgSend)(createdAt, interval);
}

// Rebuilds the list in the requested order.
//
// Only the slots already holding a datable object take part: their contents are
// sorted among themselves and written back into those same slots. Every other
// index is left exactly as the adapter produced it, which is what keeps the
// caption pinned to the top and the composer helpers where Instagram put them.
static NSArray *SPKCommentSortReorder(NSArray *objects, NSString *mode) {
    if (objects.count < 2)
        return objects;

    NSMutableArray *sortableIndexes = [NSMutableArray array];
    NSMutableArray *sortableObjects = [NSMutableArray array];

    for (NSUInteger index = 0; index < objects.count; index++) {
        id object = objects[index];
        double date = SPKCommentSortDateForObject(object);
        if (isnan(date))
            continue;
        [sortableIndexes addObject:@(index)];
        [sortableObjects addObject:object];
    }

    if (sortableObjects.count < 2)
        return objects;

    BOOL newestFirst = [mode isEqualToString:kSPKCommentSortModeNewest];
    [sortableObjects sortUsingComparator:^NSComparisonResult(id first, id second) {
        double firstDate = SPKCommentSortDateForObject(first);
        double secondDate = SPKCommentSortDateForObject(second);
        if (firstDate == secondDate)
            return NSOrderedSame;
        BOOL firstComesFirst = newestFirst ? (firstDate > secondDate) : (firstDate < secondDate);
        return firstComesFirst ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *reordered = [objects mutableCopy];
    for (NSUInteger position = 0; position < sortableIndexes.count; position++) {
        NSUInteger index = [sortableIndexes[position] unsignedIntegerValue];
        reordered[index] = sortableObjects[position];
    }
    return reordered;
}

#pragma mark - Entry control

@interface SPKCommentSortTarget : NSObject
@property (nonatomic, weak) UIViewController *controller;
- (void)cycleSortMode:(UIButton *)sender;
@end

@implementation SPKCommentSortTarget

// Cycles Instagram's order → newest → oldest → Instagram's order.
//
// A cycling control rather than a popup menu: the order has three states, the
// banner already names the one in force, and it keeps the thread free of a menu
// that would cover the comments being reordered.
- (void)cycleSortMode:(UIButton *)sender {
    NSString *current = SPKCommentSortMode();
    NSString *next = kSPKCommentSortModeNewest;
    if ([current isEqualToString:kSPKCommentSortModeNewest])
        next = kSPKCommentSortModeOldest;
    else if ([current isEqualToString:kSPKCommentSortModeOldest])
        next = kSPKCommentSortModeDefault;

    SPKPreferenceSetObject(next, kSPKCommentSortModeKey);
    SPKCommentSortNote([NSString stringWithFormat:@"mode -> %@", next]);

    UIViewController *controller = self.controller;
    if (!controller)
        return;

    // Asking the adapter to run its update makes it call the data source again,
    // which is where the new order is applied.
    id listAdapter = SPKCommentSortIvarValue(controller, "_listAdapter");
    SEL performUpdates = NSSelectorFromString(@"performUpdatesAnimated:completion:");
    if ([listAdapter respondsToSelector:performUpdates]) {
        ((void (*)(id, SEL, BOOL, id))objc_msgSend)(listAdapter, performUpdates, YES, nil);
    } else {
        SPKCommentSortNote(@"list adapter missing performUpdates");
    }

    SPKNotify(kSPKNotificationCommentSortUnavailable, @"Comment Sorting",
              SPKCommentSortModeTitle(next), @"sort", SPKNotificationToneSuccess);
}

@end

// Seats the control on the window rather than on the controller's view.
//
// Measured on device: the thread controller's view is 1005 pt tall while the
// visible sheet is shorter, so its top edge sits behind the sheet's own header
// and anything anchored there is drawn out of sight.
static void SPKSeatCommentSortEntry(UIViewController *host) {
    if (objc_getAssociatedObject(host, kSPKCommentSortEntryAssocKey))
        return;

    UIWindow *window = host.view.window;
    if (!window) {
        SPKCommentSortNote(@"seat skipped · no window");
        return;
    }

    SPKCommentSortTarget *target = [SPKCommentSortTarget new];
    target.controller = host;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.labelColor;
    button.accessibilityLabel = @"Sort comments";
    [button setImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                            weight:UIImageSymbolWeightSemibold]]
            forState:UIControlStateNormal];
    [button addTarget:target action:@selector(cycleSortMode:) forControlEvents:UIControlEventTouchUpInside];

    // Glass on iOS 26; elsewhere the tweak's own capsule fill, which also gives
    // the glyph the contrast it lacks against a white sheet.
    if (!SPKChipApplyGlass(button, NO, 17.0, nil)) {
        button.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.92];
    }
    button.layer.cornerRadius = 17.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.35].CGColor;
    button.layer.zPosition = 5000.0;

    [window addSubview:button];
    [window bringSubviewToFront:button];

    // Instagram's send button holds the trailing corner of the sheet header, so
    // the control takes the leading side at the same height.
    UILayoutGuide *guide = window.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0],
        [button.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:12.0],
        [button.centerYAnchor constraintEqualToAnchor:guide.centerYAnchor constant:-140.0],
    ]];

    objc_setAssociatedObject(host, kSPKCommentSortTargetAssocKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(host, kSPKCommentSortEntryAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    SPKCommentSortNote([NSString stringWithFormat:@"seated · mode %@", SPKCommentSortMode()]);
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

%group SPKCommentSortHooks

%hook IGCommentThreadViewController

// The data source call that decides the order of the whole thread. Returning a
// reordered copy is enough: the adapter diffs it against what is on screen and
// moves the cells itself.
- (NSArray *)objectsForListAdapter:(id)listAdapter {
    NSArray *objects = %orig;
    if (![objects isKindOfClass:[NSArray class]] || objects.count < 2)
        return objects;

    NSString *mode = SPKCommentSortMode();
    if ([mode isEqualToString:kSPKCommentSortModeDefault])
        return objects;

    NSArray *reordered = SPKCommentSortReorder(objects, mode);

    // Recorded once per thread rather than on every pass: the adapter asks for
    // its objects repeatedly, and five identical lines would bury the rest.
    static NSUInteger lastCount = 0;
    if (objects.count != lastCount) {
        lastCount = objects.count;
        SPKCommentSortNote([NSString stringWithFormat:@"sorted %@ · %lu objects",
                                                      mode, (unsigned long)objects.count]);
    }
    return reordered;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
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
    BOOL enabled = [SPKUtils getBoolPref:kSPKCommentSortEnabledKey];
    SPKCommentSortNote([NSString stringWithFormat:@"installer ran · pref %@", enabled ? @"ON" : @"OFF"]);
    if (!enabled)
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCommentSortHooks);
        SPKCommentSortNote(@"hooks installed");
    });
}
