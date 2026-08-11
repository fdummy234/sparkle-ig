#import "SPKToolsSettingsProvider.h"
#include <UIKit/UIKit.h>

#import "../../App/SPKFlexLoader.h"
#import "../../App/SPKStabilityGuard.h"
#import "../../AssetUtils.h"
#import "../../Shared/Gallery/SPKGalleryLockViewController.h"
#import "../../Shared/Settings/SPKSettingsLockManager.h"
#import "../../Shared/UI/SPKIGAlertPresenter.h"
#import "../../Utils.h"
#import "../SPKOnboardingViewController.h"
#import "../SPKWhatsNewViewController.h"
#import "../SPKSettingsViewController.h"
#import "../SPKTopicSettingsSupport.h"
#if SPK_DEV
#import "SPKHookBisectSettingsProvider.h"
#endif
#import "SPKInterfaceSettingsProvider.h"

static UIViewController *SPKSettingsLockPresenter(void) {
    UIViewController *presenter = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;
    return presenter;
}

static void SPKSettingsLockReloadPresenter(UIViewController *presenter) {
    // `presenter` is the topmost presented VC, which is usually the navigation
    // controller wrapping the settings page rather than the page itself. Reload
    // whichever SPKSettingsViewController is actually on screen so the Change
    // Passcode row greys/ungreys with the lock toggle.
    SPKSettingsViewController *settingsVC = nil;
    if ([presenter isKindOfClass:SPKSettingsViewController.class]) {
        settingsVC = (SPKSettingsViewController *)presenter;
    } else if ([presenter isKindOfClass:UINavigationController.class]) {
        UIViewController *top = ((UINavigationController *)presenter).topViewController;
        if ([top isKindOfClass:SPKSettingsViewController.class])
            settingsVC = (SPKSettingsViewController *)top;
    }
    [settingsVC.tableView reloadData];
}

static NSDictionary *SPKSettingsLockSection(void) {
    SPKSetting *lockSwitch = [SPKSetting switchCellWithTitle:@"Passcode Lock"
                                                        icon:SPKSettingsIcon(@"lock")
                                                 defaultsKey:@""];
    lockSwitch.switchValueProvider = ^BOOL {
        return [SPKSettingsLockManager sharedManager].isLockEnabled;
    };
    lockSwitch.switchChangeHandler = ^(BOOL enabled) {
        SPKSettingsLockManager *currentManager = [SPKSettingsLockManager sharedManager];
        UIViewController *presenter = SPKSettingsLockPresenter();
        if (enabled && !currentManager.isLockEnabled) {
            [SPKGalleryLockViewController presentMode:SPKGalleryLockModeSetPasscode
                                           forManager:currentManager
                                   fromViewController:presenter
                                           completion:^(__unused BOOL success) {
                                               SPKSettingsLockReloadPresenter(presenter);
                                           }];
            return;
        }
        if (!enabled && currentManager.isLockEnabled) {
            [SPKIGAlertPresenter presentAlertFromViewController:presenter
                                                          title:@"Disable Settings Passcode"
                                                        message:@"Sparkle Settings will no longer require authentication to open."
                                                        actions:@[
                                                            [SPKIGAlertAction actionWithTitle:@"Cancel"
                                                                                        style:SPKIGAlertActionStyleCancel
                                                                                      handler:^{
                                                                                          SPKSettingsLockReloadPresenter(presenter);
                                                                                      }],
                                                            [SPKIGAlertAction actionWithTitle:@"Disable"
                                                                                        style:SPKIGAlertActionStyleDestructive
                                                                                      handler:^{
                                                                                          [currentManager removePasscode];
                                                                                          SPKSettingsLockReloadPresenter(presenter);
                                                                                      }],
                                                        ]];
        }
    };

    SPKSetting *changePasscode = [SPKSetting buttonCellWithTitle:@"Change Passcode"
                                                        subtitle:nil
                                                            icon:SPKSettingsIcon(@"key")
                                                          action:^{
                                                              [SPKGalleryLockViewController presentMode:SPKGalleryLockModeChangePasscode
                                                                                             forManager:[SPKSettingsLockManager sharedManager]
                                                                                     fromViewController:SPKSettingsLockPresenter()
                                                                                             completion:^(__unused BOOL success){
                                                                                             }];
                                                          }];
    changePasscode.enabledProvider = ^BOOL {
        return [SPKSettingsLockManager sharedManager].isLockEnabled;
    };

    return SPKTopicSection(@"Settings Lock", @[ lockSwitch, changePasscode ], @"Require the independent Settings passcode or biometrics when opening Sparkle Settings, including topic sheets.");
}

@implementation SPKToolsSettingsProvider

+ (SPKSetting *)rootSetting {
    BOOL flexInstalled = SPKFlexIsBundled();
    NSString *flexFooter = flexInstalled
                               ? @"The first time FLEX is opened in a session it can take a moment to initialize."
                               : @"FLEX is not installed. Rebuild with \"--flex\" flag or install \"libFLEX.dylib\" to enable these options.";
                                                                              icon:SPKSettingsIcon(@"pinch")
    SPKSetting *flexGesture = [SPKSetting switchCellWithTitle:@"Three-finger Hold" defaultsKey:@"tools_flex_instagram"];
                                                                              icon:SPKSettingsIcon(@"play")
    SPKSetting *flexLaunch = [SPKSetting switchCellWithTitle:@"Open on App Launch" defaultsKey:@"tools_flex_app_launch"];
                                                                            icon:SPKSettingsIcon(@"arrow_up_right")
    SPKSetting *flexFocus = [SPKSetting switchCellWithTitle:@"Open on App Focus" defaultsKey:@"tools_flex_app_start"];
    SPKSetting *flexOpen = [SPKSetting buttonCellWithTitle:@"Open FLEX Now"
                                                  subtitle:nil
                                                      icon:SPKSettingsIcon(@"toolbox")
                                                    action:^(void) {
                                                        SPKFlexShowExplorer(@"settings");
                                                    }];
    if (!flexInstalled) {
        flexGesture.userInfo = @{@"enabled" : @NO};
        flexLaunch.userInfo = @{@"enabled" : @NO};
        flexFocus.userInfo = @{@"enabled" : @NO};
        flexOpen.userInfo = @{@"enabled" : @NO};
    }
    // The TestFlight/Beta popup suppression is always active on release builds.
    // On dev builds, we keep a toggle to allow disabling it for testing.
    NSMutableArray *instagramCells = [NSMutableArray array];
#if SPK_DEV
    [instagramCells addObject:[SPKSetting switchCellWithTitle:@"[DEV] Hide TestFlight Popup"
                                                  defaultsKey:@"tools_hide_testflight_popup"
                                              requiresRestart:YES]];
#endif
    [instagramCells addObject:[SPKSetting switchCellWithTitle:@"Fix Duplicate Notifications"
                                                  defaultsKey:@"tools_fix_duplicate_notifications"]];
    [instagramCells addObject:[SPKSetting switchCellWithTitle:@"Disable Safe Mode"
                                                  defaultsKey:@"tools_disable_safe_mode"]];

#if SPK_DEV
    NSString *instagramFooter =
        @"1. Suppresses the Instagram Beta update popup.\n"
        @"2. Drops the duplicate in-app banner sideloaded Instagram posts while the notification extension is already delivering the same push. Only acts while the app is foregrounded.\n"
        @"3. Makes Instagram not reset settings after subsequent crashes. Use at your own risk.";
#else
    NSString *instagramFooter =
        @"1. Drops the duplicate in-app banner sideloaded Instagram posts while the notification extension is already delivering the same push. Only acts while the app is foregrounded.\n"
        @"2. Makes Instagram not reset settings after subsequent crashes. Use at your own risk.";
#endif

    // Section order: everyday settings first, recovery and developer tooling
    // last — FLEX often is not even installed on regular builds.
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SPKTopicSection(@"Tweak", @[
            [SPKSetting switchCellWithTitle:@"Quick Settings Access"
                           icon:SPKSettingsIcon(@"settings")
                                defaultsKey:@"tools_settings_shortcut"
                            requiresRestart:YES],
            [SPKSetting switchCellWithTitle:@"Shortcut Haptics"
                           icon:SPKSettingsIcon(@"haptics")
                                defaultsKey:@"tools_shortcut_haptics"],
            [SPKSetting switchCellWithTitle:@"Show Settings on App Launch"
                           icon:SPKSettingsIcon(@"play")
                                defaultsKey:@"tools_open_settings_on_launch"],
            [SPKSetting buttonCellWithTitle:@"Show Onboarding"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"compass")
                                     action:^(void) {
                                         [SPKOnboardingViewController presentFromViewController:nil onFinish:nil];
                                     }],
            [SPKSetting buttonCellWithTitle:@"Show What's New"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"notes")
                                     action:^(void) {
                                         [SPKWhatsNewViewController presentFromViewController:nil onFinish:nil];
                                     }],
        ],
                        @"1. Opens settings when long pressing the Home tab or the next visible tab if the Home tab is hidden.\n"
                        @"2. Haptic feedback when the settings shortcut gesture fires.\n"
                        @"3. Open Sparkle settings automatically every time Instagram launches."),
        SPKSettingsLockSection(),
        SPKTopicSection(@"Instagram", instagramCells, instagramFooter),

        // "Recovery" — was the untitled section. Disable All Settings moved in
        // from Tweak: its own footer said "Use to isolate crashes."
        SPKTopicSection(@"Recovery", @[
            [SPKSetting switchCellWithTitle:@"Turn Off All Features"
                           icon:SPKSettingsIcon(@"circle_off")
                                defaultsKey:@"tools_disable_all"
                            requiresRestart:YES],
            [SPKSetting buttonCellWithTitle:@"Clear Safe Mode"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"undo_circle")
                                     action:^(void) {
                                         SPKStabilityGuardReset();
                                         [SPKUtils showRestartConfirmation];
                                     }],
#if SPK_DEV
            // Dev builds only: wipe the intro-sheet state so the onboarding /
            // What's New gating fires from scratch on the next launch.
            [SPKSetting buttonCellWithTitle:@"[DEV] Reset Intro State"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"beaker")
                                     action:^(void) {
                                         NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                                         [defaults removeObjectForKey:@"app_first_run"];
                                         [defaults removeObjectForKey:@"app_last_whatsnew_version"];
                                         [SPKUtils showRestartConfirmation];
                                     }],
#endif
        ],
                        @"1. Suppress every Sparkle feature hook, leaving only the shortcut to reach this screen. Use to isolate crashes.\n"
                        @"2. Clears failed-launch counters and temporary hook suppression. Tap this button if it appears as if features aren't enabled."),
        SPKTopicSection(@"FLEX", @[ flexOpen, flexGesture, flexLaunch, flexFocus ], flexFooter),
#if SPK_DEV
        SPKTopicSection(@"Diagnostics",
                        @[ [SPKHookBisectSettingsProvider rootSetting] ],
                        @"Skip individual hook installers at launch to isolate a crash or a slowdown to one feature."),
#endif
    ]];

    return SPKTopicNavigationSetting(@"Tools", @"toolbox", 24.0, sections);
}

@end
