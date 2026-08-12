#import <objc/runtime.h>
#import <substrate.h>

#import "../../InstagramHeaders.h"
#import "../../Settings/SPKSettingsViewController.h"
#import "../../Shared/Gallery/SPKGalleryViewController.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

static const void *kSPKHomeTabSettingsLongPressAssocKey = &kSPKHomeTabSettingsLongPressAssocKey;
static const void *kSPKGalleryTabLongPressAssocKey = &kSPKGalleryTabLongPressAssocKey;
static const void *kSPKProfileMoreSettingsLongPressAssocKey = &kSPKProfileMoreSettingsLongPressAssocKey;
static const NSTimeInterval kSPKHomeTabLongPressDuration = 0.5;
static const NSTimeInterval kSPKGalleryTabLongPressDuration = 0.65;
static NSString *const kSPKGalleryQuickAccessDisabledValue = @"none";

@interface IGTabBarButton (SPKQuickActions)
- (void)spk_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration;
- (void)spk_removeProfileAccountPickerLongPressIfNeeded;
- (void)spk_removeGalleryLongPressIfNeeded;
- (void)spk_removeSettingsLongPressIfNeeded;
- (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender;
- (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender;
@end

// Light confirmation tap fired when a tab-bar shortcut activates. The global
// UIImpactFeedbackGenerator hook (DisableHaptics.x) already respects
// general_disable_haptics, so this stays silent when the user disabled haptics.
static void SPKFireShortcutHaptic(void) {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator prepare];
    [generator impactOccurred];
}

static NSString *SPKGalleryShortcutTabIdentifier(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [defaults stringForKey:@"gallery_quick_access_tab"];
    if (identifier.length == 0) {
        identifier = kSPKGalleryQuickAccessDisabledValue;
    }
    if ([identifier isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return identifier;

    NSString *target = identifier;
    BOOL usesClassicTabOrdering = [[[NSUserDefaults standardUserDefaults] stringForKey:@"interface_nav_order"] isEqualToString:@"classic"];
    if (usesClassicTabOrdering && [target isEqualToString:@"direct-inbox-tab"])
        return @"camera-tab";
    if (!usesClassicTabOrdering && [target isEqualToString:@"camera-tab"])
        return @"direct-inbox-tab";
    return target;
}

static BOOL SPKTabButtonMatchesTarget(NSString *identifier, NSString *label, NSString *target) {
    if (target.length == 0 || [target isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return NO;

    NSString *candidate = [NSString stringWithFormat:@"%@ %@", identifier ?: @"", label ?: @""].lowercaseString;
    if ([identifier isEqualToString:target])
        return YES;
    if ([target isEqualToString:@"mainfeed-tab"] && ([candidate containsString:@"mainfeed"] || [candidate containsString:@"home"]))
        return YES;
    if ([target isEqualToString:@"reels-tab"] && ([candidate containsString:@"clips"] || [candidate containsString:@"reels"]))
        return YES;
    if ([target isEqualToString:@"camera-tab"] && [candidate containsString:@"create"])
        return YES;
    if ([target isEqualToString:@"explore-tab"] && ([candidate containsString:@"explore"] || [candidate containsString:@"search"]))
        return YES;
    if ([target isEqualToString:@"direct-inbox-tab"] && ([candidate containsString:@"direct"] ||
                                                         [candidate containsString:@"inbox"] ||
                                                         [candidate containsString:@"message"]))
        return YES;
    if ([target isEqualToString:@"profile-tab"] && ([candidate containsString:@"profile"] ||
                                                    [candidate containsString:@"tab_avatar"]))
        return YES;
    return NO;
}


static BOOL SPKTabHiddenForIdentifier(NSString *identifier) {
    BOOL usesClassic = [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];

    if ([identifier isEqualToString:@"mainfeed-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_feed_tab"];
    if ([identifier isEqualToString:@"reels-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_reels_tab"];
    if ([identifier isEqualToString:@"direct-inbox-tab"])
        return usesClassic || [SPKUtils getBoolPref:@"interface_hide_msgs_tab"];
    if ([identifier isEqualToString:@"camera-tab"])
        return !usesClassic || [SPKUtils getBoolPref:@"interface_hide_create_tab"];
    if ([identifier isEqualToString:@"explore-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_explore_tab"];
    if ([identifier isEqualToString:@"profile-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_profile_tab"];
    return NO;
}

// Settings now open from the ✦ in Instagram's own settings screen, so no tab
// hosts a settings long-press. The gallery shortcut still asks, to make sure it
// never lands on a tab that already carries one.
static NSString *SPKResolvedSettingsShortcutTabIdentifier(void) {
    return nil;
}

static NSString *SPKResolvedGalleryShortcutTabIdentifier(void) {
    NSString *preferred = SPKGalleryShortcutTabIdentifier();
    if (preferred.length == 0 || [preferred isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return nil;

    NSString *settingsHost = SPKResolvedSettingsShortcutTabIdentifier();
    if (![preferred isEqualToString:settingsHost]) {
        return preferred;
    }

    // Clash! Settings wins on the preferred tab.
    // Gallery falls back to the next available visible tab that isn't settingsHost.
    NSArray<NSString *> *priority = @[ @"mainfeed-tab", @"reels-tab", @"direct-inbox-tab", @"camera-tab", @"explore-tab", @"profile-tab" ];
    for (NSString *identifier in priority) {
        if (SPKTabHiddenForIdentifier(identifier))
            continue;
        if ([identifier isEqualToString:settingsHost])
            continue;
        return identifier;
    }

    return nil;
}

static BOOL SPKTabIdentifierMatchesGalleryShortcut(NSString *identifier, NSString *label) {
    return SPKTabButtonMatchesTarget(identifier, label, SPKResolvedGalleryShortcutTabIdentifier());
}

static BOOL SPKShouldReplaceProfileTabLongPress(NSString *identifier, NSString *label) {
    return [SPKGalleryShortcutTabIdentifier() isEqualToString:@"profile-tab"] &&
           [identifier isEqualToString:@"profile-tab"] &&
           [(label ?: @"") isEqualToString:@"Profile"];
}

// Show Sparkle tweak settings by holding on the settings/more icon under profile for ~1 second
%group SPKSettingsShortcutsHooks

// Quick access to tweak settings by holding on home tab button
%hook IGTabBarButton

- (void)setAccessibilityIdentifier:(NSString *)identifier {
    %orig;
    [self setNeedsLayout];
}

- (void)setAccessibilityLabel:(NSString *)label {
    %orig;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"SettingsShortcuts.layoutSubviews");

    NSString *identifier = self.accessibilityIdentifier ?: @"";
    NSString *label = self.accessibilityLabel ?: @"";

    NSString *settingsHost = SPKResolvedSettingsShortcutTabIdentifier();
    BOOL hostsSettings = settingsHost && SPKTabButtonMatchesTarget(identifier, label, settingsHost);
    BOOL matchesGallery = SPKTabIdentifierMatchesGalleryShortcut(identifier, label);

    SPKLog(@"TabBar", @"[Sparkle] IGTabBarButton layoutSubviews: ID='%@', label='%@', settingsHost='%@', hostsSettings=%d, matchesGallery=%d",
           identifier, label, settingsHost, hostsSettings, matchesGallery);

    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
            SPKLog(@"TabBar", @"[Sparkle] Existing gesture before changes: %@, hasGalleryAssoc=%d, hasSettingsAssoc=%d, duration=%f",
                   NSStringFromClass(g.class),
                   objc_getAssociatedObject(g, kSPKGalleryTabLongPressAssocKey) != nil,
                   objc_getAssociatedObject(g, kSPKHomeTabSettingsLongPressAssocKey) != nil,
                   ((UILongPressGestureRecognizer *)g).minimumPressDuration);
        }
    }

    if (hostsSettings) {
        [self spk_removeGalleryLongPressIfNeeded];
        [self spk_addLongPressWithAction:@selector(handleHomeTabLongPress:) marker:kSPKHomeTabSettingsLongPressAssocKey minimumDuration:kSPKHomeTabLongPressDuration];

        // Remove Instagram's native long press(es) that compete with ours.
        // Both have 0.5s duration, and requireGestureRecognizerToFail is
        // unreliable when durations match — sometimes IG's fires instead.
        for (UIGestureRecognizer *g in [self.gestureRecognizers copy]) {
            if (![g isKindOfClass:[UILongPressGestureRecognizer class]])
                continue;
            if (objc_getAssociatedObject(g, kSPKHomeTabSettingsLongPressAssocKey))
                continue;
            if (objc_getAssociatedObject(g, kSPKGalleryTabLongPressAssocKey))
                continue;
            [self removeGestureRecognizer:g];
        }
    } else {
        [self spk_removeSettingsLongPressIfNeeded];
    }

    if (matchesGallery && !hostsSettings) {
        if (SPKShouldReplaceProfileTabLongPress(identifier, label)) {
            [self spk_removeProfileAccountPickerLongPressIfNeeded];
        }
        [self spk_addLongPressWithAction:@selector(handleDirectInboxTabLongPress:) marker:kSPKGalleryTabLongPressAssocKey minimumDuration:kSPKGalleryTabLongPressDuration];
    } else {
        [self spk_removeGalleryLongPressIfNeeded];
    }
}

%new - (void)spk_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration {
for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, marker)) {
        return;
    }
}

UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:action];
longPress.minimumPressDuration = minimumDuration;
BOOL shouldCancel = (marker == kSPKGalleryTabLongPressAssocKey || marker == kSPKHomeTabSettingsLongPressAssocKey);
longPress.cancelsTouchesInView = shouldCancel;
longPress.delaysTouchesBegan = shouldCancel;
longPress.delaysTouchesEnded = shouldCancel;

for (UIGestureRecognizer *existing in self.gestureRecognizers) {
    [existing requireGestureRecognizerToFail:longPress];
}

[self addGestureRecognizer:longPress];
objc_setAssociatedObject(longPress, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new - (void)spk_removeProfileAccountPickerLongPressIfNeeded {
for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, kSPKGalleryTabLongPressAssocKey))
        continue;

    UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)gesture;
    if (fabs(longPress.minimumPressDuration - 0.5) > 0.01)
        continue;

    [self removeGestureRecognizer:gesture];
}
}

%new - (void)spk_removeGalleryLongPressIfNeeded {
for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, kSPKGalleryTabLongPressAssocKey)) {
        [self removeGestureRecognizer:gesture];
    }
}
}

%new - (void)spk_removeSettingsLongPressIfNeeded {
for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, kSPKHomeTabSettingsLongPressAssocKey)) {
        [self removeGestureRecognizer:gesture];
    }
}
}

%new - (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender {
SPKLog(@"TabBar", @"[Sparkle] handleHomeTabLongPress: state=%ld, view=%@, window=%@",
       (long)sender.state, NSStringFromClass([sender.view class]),
       sender.view.window ? @"YES" : @"NO");
if (sender.state != UIGestureRecognizerStateBegan)
    return;

SPKFireShortcutHaptic();
[SPKUtils showSettingsVC:[self window]];
}

%new - (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender {
if (sender.state != UIGestureRecognizerStateBegan)
    return;

SPKFireShortcutHaptic();
[SPKGalleryViewController presentGallery];
}
%end


%end

void SPKInstallSettingsShortcutsHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKSettingsShortcutsHooks);
    });
}
