#import "../../Utils.h"
#import <objc/message.h>
#import <objc/runtime.h>

static id SPKValueForSelectorOrKey(id object, NSString *name) {
    if (!object || name.length == 0)
        return nil;

    SEL selector = NSSelectorFromString(name);
    if ([object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }

    @try {
        return [object valueForKey:name];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static Class SPKFriendMapSectionControllerClass(void) {
    return NSClassFromString(@"_TtC24IGDirectNotesTrayUISwift43IGDirectNotesTrayFriendMapSectionController");
}

// The Instants entry of the same tray — the "+" that opens the camera. Read from
// the 441.0.0 binary: IGDirectNotesTrayInstantsSectionController lives in the
// IGDirectNotesTrayUISwift module, right beside the friend map above.
static Class SPKInstantsSectionControllerClass(void) {
    return NSClassFromString(@"_TtC24IGDirectNotesTrayUISwift42IGDirectNotesTrayInstantsSectionController");
}

// "Disable Instants Creation" blocks the shutter; it should take the door away
// too, instead of opening a camera that cannot capture.
static BOOL SPKHideInstantsEntry(void) {
    return [SPKUtils getBoolPref:@"instants_disable_creation"];
}

// The entry is recognisable by its own view model — IGDirectNotesTrayInstantsViewModel
// in the 441.0.0 binary. Testing the object works on both filtering paths,
// including the one that has no list adapter to ask for a section controller.
static BOOL SPKShouldHideInstantsObject(id obj) {
    if (!SPKHideInstantsEntry() || !obj)
        return NO;
    const char *name = class_getName(object_getClass(obj));
    return name && strstr(name, "IGDirectNotesTrayInstants") != NULL;
}

static BOOL SPKShouldHideFriendsMapObject(id object) {
    if (![SPKUtils getBoolPref:@"msgs_hide_friends_map"])
        return NO;

    NSString *className = NSStringFromClass([object class]);
    if ([className containsString:@"FriendMap"])
        return YES;

    // IG 436+ : the friend-map entry is an opaque IGDirectNotesTrayUserViewModel
    // (IGDevirtualizedValueObject), so the class name no longer says "FriendMap".
    // The notePk heuristic is kept as a fallback for builds that still expose it.
    id notePk = SPKValueForSelectorOrKey(object, @"notePk");
    if ([notePk isKindOfClass:[NSString class]] &&
        ([notePk isEqualToString:@"friends_map"] || [notePk isEqualToString:@"friend_map"])) {
        return YES;
    }
    return NO;
}

static NSArray *SPKFilterFriendsMapObjects(NSArray *originalObjs) {
    if (![originalObjs isKindOfClass:[NSArray class]])
        return originalObjs;

    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];
    for (id obj in originalObjs) {
        if (SPKShouldHideFriendsMapObject(obj)) {
            SPKLog(@"General", @"[Sparkle] Hiding friends map");
            continue;
        }
        if (SPKShouldHideInstantsObject(obj)) {
            SPKLog(@"General", @"[Sparkle] Hiding the Instants entry");
            continue;
        }
        [filteredObjs addObject:obj];
    }

    return [filteredObjs copy];
}

// Model-independent friend-map removal: IGListKit picks the section controller
// for each object via -listAdapter:sectionControllerForObject:. The friend-map
// entry is the object whose section controller is an
// IGDirectNotesTrayFriendMapSectionController — true regardless of the (now
// opaque) view-model's class or note PK. Filter those out of the objects array.
static NSArray *SPKFilterFriendsMapObjectsForDataSource(id dataSource, id adapter, NSArray *originalObjs) {
    BOOL hideFriendMap = [SPKUtils getBoolPref:@"msgs_hide_friends_map"];
    BOOL hideInstants = SPKHideInstantsEntry();
    if (!hideFriendMap && !hideInstants)
        return originalObjs;
    if (![originalObjs isKindOfClass:[NSArray class]])
        return originalObjs;

    Class instantsSection = SPKInstantsSectionControllerClass();
    Class friendMapSection = SPKFriendMapSectionControllerClass();
    SEL scSelector = @selector(listAdapter:sectionControllerForObject:);

    BOOL canResolveSection = (friendMapSection || instantsSection) && adapter &&
                             [dataSource respondsToSelector:scSelector];

    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];
    for (id obj in originalObjs) {
        if (hideFriendMap && SPKShouldHideFriendsMapObject(obj)) {
            SPKLog(@"General", @"[Sparkle] Hiding friends map");
            continue;
        }
        if (SPKShouldHideInstantsObject(obj)) {
            SPKLog(@"General", @"[Sparkle] Hiding the Instants entry (model match)");
            continue;
        }
        if (canResolveSection) {
            @try {
                id sectionController = ((id (*)(id, SEL, id, id))objc_msgSend)(dataSource, scSelector, adapter, obj);
                if (hideInstants && instantsSection && [sectionController isKindOfClass:instantsSection]) {
                    SPKLog(@"General", @"[Sparkle] Hiding the Instants entry");
                    continue;
                }
                if (hideFriendMap && friendMapSection && [sectionController isKindOfClass:friendMapSection]) {
                    SPKLog(@"General", @"[Sparkle] Hiding friends map (section match)");
                    continue;
                }
            } @catch (__unused NSException *exception) {
            }
        }
        [filteredObjs addObject:obj];
    }

    return [filteredObjs copy];
}

%group SPKHideFriendsMapHooks

%hook IGDirectNotesTrayRowCell
- (id)listAdapterObjects {
    return SPKFilterFriendsMapObjects(%orig());
}
%end

%hook _TtC24IGDirectNotesTrayUISwift42IGDirectNotesTrayCellListAdapterDataSource
- (id)objectsForListAdapter:(id)adapter {
    return SPKFilterFriendsMapObjectsForDataSource(self, adapter, %orig());
}
%end

%hook _TtC24IGDirectNotesTrayUISwift43IGDirectNotesTrayFriendMapSectionController
- (long long)numberOfItems {
    if ([SPKUtils getBoolPref:@"msgs_hide_friends_map"]) {
        SPKLog(@"General", @"[Sparkle] Hiding friends map section");
        return 0;
    }
    return %orig();
}
%end

// Same technique for the Instants entry: a section that reports zero items is
// laid out as if it did not exist. This is what actually removes the friend map
// above — the object filters are the belt, this is the braces.
// Last lock, and the one that cannot be routed around: the cell itself. Whatever
// section controller or data source produced it, a hidden cell of zero height
// draws nothing. Read from the 441.0.0 binary: IGDirectNotesTrayInstantsCell.
%hook _TtC24IGDirectNotesTrayUISwift29IGDirectNotesTrayInstantsCell

- (void)layoutSubviews {
    %orig;
    if (SPKHideInstantsEntry()) {
        // The class is only forward-declared here, so reach its UIView side
        // through a cast rather than through the unknown interface.
        UIView *cell = (UIView *)self;
        cell.hidden = YES;
        cell.alpha = 0.0;
        cell.userInteractionEnabled = NO;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (SPKHideInstantsEntry()) {
        // The class is only forward-declared here, so reach its UIView side
        // through a cast rather than through the unknown interface.
        UIView *cell = (UIView *)self;
        cell.hidden = YES;
        cell.alpha = 0.0;
        cell.userInteractionEnabled = NO;
    }
}

%end

%hook _TtC24IGDirectNotesTrayUISwift42IGDirectNotesTrayInstantsSectionController
- (long long)numberOfItems {
    if (SPKHideInstantsEntry()) {
        SPKLog(@"General", @"[Sparkle] Hiding the Instants section");
        return 0;
    }
    return %orig();
}
%end

%end

void SPKInstallHideFriendsMapHooksIfEnabled(void) {
    // Installed unconditionally, like the other tray surfaces: every hook below
    // re-reads its own pref at call time, so both toggles take effect without a
    // restart. Gating installation on one pref is what kept the Instants entry
    // visible whenever "Hide Friends Map" happened to be off.

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideFriendsMapHooks,
                       IGDirectNotesTrayRowCell = SPKResolveIGClass(@"IGDirectNotesTrayUISwift.IGDirectNotesTrayRowCell", @"IGDirectNotesTrayRowCell"));
    });
}
