#import "SPKInterfaceSettingsProvider.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Utils.h"
#import "../SPKPreferenceAvailability.h"
#import "../SPKPreferences.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"
#import "SPKNotificationSettingsProvider.h"

// The navigable tab keys. The create "+" is a composer launcher rather than a
// destination, so it is excluded — hiding it can never leave the app tab-less.
static NSArray<NSString *> *SPKDestinationTabHideKeys(void) {
    return @[
        @"interface_hide_feed_tab",
        @"interface_hide_explore_tab",
        @"interface_hide_reels_tab",
        @"interface_hide_msgs_tab",
        @"interface_hide_profile_tab",
    ];
}

// YES if turning on `keyToEnable` would leave every navigable tab hidden.
static BOOL SPKEnablingKeyHidesEveryTab(NSString *keyToEnable) {
    for (NSString *key in SPKDestinationTabHideKeys()) {
        if ([key isEqualToString:keyToEnable])
            continue;
        if (![SPKUtils getBoolPref:key])
            return NO;
    }
    return YES;
}

static BOOL SPKIsMessagesOnlyMode(void) {
    BOOL msgsVisible = ![SPKUtils getBoolPref:@"interface_hide_msgs_tab"];
    BOOL feedHidden = [SPKUtils getBoolPref:@"interface_hide_feed_tab"];
    BOOL exploreHidden = [SPKUtils getBoolPref:@"interface_hide_explore_tab"];
    BOOL reelsHidden = [SPKUtils getBoolPref:@"interface_hide_reels_tab"];
    BOOL profileHidden = [SPKUtils getBoolPref:@"interface_hide_profile_tab"];
    
    BOOL usesClassic = [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
    BOOL createHidden = !usesClassic || [SPKUtils getBoolPref:@"interface_hide_create_tab"];
    
    return msgsVisible && feedHidden && exploreHidden && reelsHidden && profileHidden && createHidden;
}

// A "Hide … Tab" switch that can't hide the last remaining navigable tab: when
// this is the only tab still visible its switch is greyed out and can't be
// turned on, while any already-hidden tab can always be turned back on.
@implementation SPKInterfaceSettingsProvider

+ (SPKSetting *)rootSetting {
    // ---- Tabs ----------------------------------------------------------
    // The order glossary used to live in the section footer; it moves onto the
    // two rows it explains.

    SPKSetting *tabIconOrder = [SPKSetting menuCellWithTitle:@"Tab Order"
                                                        icon:SPKSettingsIcon(@"sort")
                                                        menu:SPKNavigationIconOrderingMenu()];
    tabIconOrder.helpText = @"Standard: Home, Reels, Messages, Explore, Profile. Classic puts Messages top-right; Alternate swaps Home and Reels.";
    tabIconOrder.searchKeywords = @"standard classic alternate layout order tab icon order";

    SPKSetting *swipeBetweenTabs = [SPKSetting menuCellWithTitle:@"Swipe Between Tabs"
                                                            icon:SPKSettingsIcon(@"left_right")
                                                            menu:SPKSwipeBetweenTabsMenu()];
    swipeBetweenTabs.helpText = @"For Instagram's old layout, pick the Classic order and turn swiping off.";
    swipeBetweenTabs.searchKeywords = @"old layout gesture disable recent searches";

    // Everything that shapes the tab bar, one section. The iOS 26 rows
    // (pill shape, scroll behavior) join it below when available.
    // Everything about how the screen renders. The iOS 26 glass rows join it
    // below when available — same pattern as the tab bar.
    NSMutableArray *screenRows = [@[
        ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide UI on Capture"
                                                           icon:SPKSettingsIcon(@"eye_off")
                                                    defaultsKey:@"interface_hide_ui_on_capture"];
                s.switchChangeHandler = ^(BOOL isOn) {
                    [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:@"interface_hide_ui_on_capture"];
                    [[NSNotificationCenter defaultCenter] postNotificationName:SPKHideUIOnCapturePreferenceDidChangeNotification object:nil];
                };
                s.helpText = @"Sparkle's interface vanishes from screenshots, screen recordings and mirroring.";
                s.searchKeywords = @"screenshot recording mirror redact";
                s;
            }),
    ] mutableCopy];

    NSMutableArray *tabBarRows = [@[
        [SPKSetting menuCellWithTitle:@"Launch Tab"
                                 icon:SPKSettingsIcon(@"home")
                                 menu:SPKLaunchTabMenu()],
        tabIconOrder,
        swipeBetweenTabs,
    ] mutableCopy];

    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        // Was the untitled section — six homogeneous rows deserve their name.
        // No gate here (doctrine R4): Create requires a restart and two rows
        // have conditional visibility.
        SPKTopicSection(@"Explore & Search", @[
            ({
                // Shortened from "Hide Explore Posts Grid" — the section header
                // already carries "Explore"; the old title stays searchable.
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide Posts Grid"
                                                           icon:SPKSettingsIcon(@"explore_grid")
                                                    defaultsKey:@"interface_hide_explore_grid"];
                s.searchKeywords = @"explore suggested grid";
                s;
            }),
            [SPKSetting switchCellWithTitle:@"Hide Trending Searches"
                                       icon:SPKSettingsIcon(@"trending")
                                defaultsKey:@"interface_hide_trending_searches"],
            ({
                // Moved from General (was "No Recent Searches") — it belongs
                // with the rest of the search screen. The hook gates logging,
                // hence "Disable"; the key is unchanged, so nothing migrates.
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide Recent Searches"
                                                           icon:SPKSettingsIcon(@"search")
                                                    defaultsKey:@"general_no_recent_searches"];
                s.searchKeywords = @"no history log recent";
                s;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Open Clipboard Link"
                                                           icon:SPKSettingsIcon(@"link")
                                                    defaultsKey:@"interface_open_clipboard_link"];
                s.helpText = @"Long-press the Explore tab to open the Instagram link in your clipboard.";
                s.searchKeywords = @"url paste long press";
                s;
            })
        ],
                        nil),
    ]];

    {
        // Tab Bar Behavior is shared by both presentations: it configures the
        // scroll behavior of the (pill/glass) tab bar and is enabled whenever
        // the Liquid Glass pref is on.
        SPKSetting *(^tabBarBehaviorCell)(void) = ^SPKSetting * {
            SPKSetting *tabBarBehavior = [SPKSetting menuCellWithTitle:@"Hide on Scroll"
                                                                  icon:SPKSettingsIcon(@"arrow_down")
                                                                  menu:SPKLiquidGlassTabBarStateMenu()];
    tabBarBehavior.searchKeywords = @"tab bar behavior";
            tabBarBehavior.defaultsKey = kSPKPrefInterfaceLiquidGlassTabBarMode;
            tabBarBehavior.enabledProvider = ^BOOL {
                return [SPKUtils getBoolPref:kSPKPrefInterfaceLiquidGlass];
            };
            return tabBarBehavior;
        };

        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"26.0")) {
            // Full Liquid Glass: real glass material, progressive blur, tab bar.
            SPKSetting *liquidGlass = [SPKSetting switchCellWithTitle:@"Liquid Glass"
                                                     icon:SPKSettingsIcon(@"aura")
                                                          defaultsKey:kSPKPrefInterfaceLiquidGlass
                                                      requiresRestart:YES];
            liquidGlass.switchValueProvider = ^BOOL {
                return [SPKUtils getBoolPref:kSPKPrefInterfaceLiquidGlass];
            };
            liquidGlass.switchChangeHandler = ^(BOOL isOn) {
                [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:kSPKPrefInterfaceLiquidGlass];
                [SPKUtils showRestartConfirmation];
            };
            liquidGlass.helpText = @"Turns on Instagram's native Liquid Glass interface even where it hasn't rolled out yet.";

            SPKSetting *progressiveBlur = [SPKSetting switchCellWithTitle:@"Progressive Blur"
                                                        icon:SPKSettingsIcon(@"blend")
                                                             defaultsKey:kSPKPrefInterfaceProgressiveBlur
                                                          requiresRestart:YES];
            progressiveBlur.helpText = @"Restores the navigation bar's gradual blur as you scroll.";

            [screenRows addObjectsFromArray:@[ liquidGlass, progressiveBlur ]];
            // The bar's scroll behavior belongs to the tab bar on every iOS.
            [tabBarRows addObject:tabBarBehaviorCell()];
        } else {
            // Pre-iOS 26 can't render the glass material, but the same tab bar
            // experiment gates still reshape the bar into the floating pill.
            // Expose that as a focused toggle sharing the Liquid Glass pref.
            SPKSetting *pillTabBar = [SPKSetting switchCellWithTitle:@"Pill-Shaped Tab Bar"
                                                   icon:SPKSettingsIcon(@"circle")
                                                        defaultsKey:kSPKPrefInterfaceLiquidGlass
                                                    requiresRestart:YES];
            pillTabBar.switchValueProvider = ^BOOL {
                return [SPKUtils getBoolPref:kSPKPrefInterfaceLiquidGlass];
            };
            pillTabBar.switchChangeHandler = ^(BOOL isOn) {
                [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:kSPKPrefInterfaceLiquidGlass];
                [SPKUtils showRestartConfirmation];
            };
            pillTabBar.helpText = @"Reshapes the bar into the iOS 26 floating pill. The glass material itself needs iOS 26, so only the shape applies on this device.";
            pillTabBar.searchKeywords = @"liquid glass floating";

            [tabBarRows addObject:pillTabBar];
            [tabBarRows addObject:tabBarBehaviorCell()];
        }
    }

    // The gate and the Messages-Only rows join the bar they shape.
    [tabBarRows addObjectsFromArray:@[
            // D5: the six tab toggles become one gate. Each item replicates what
            // SPKHideTabSwitch did per row — the last-visible-tab guard, the
            // restart prompt, and the effective-key write that actually hides
            // the tab. Two items are conditional on the Classic tab order.
            ({
                SPKToggleMenuItem * (^tabItem)(NSString *, NSString *, NSString *) =
                    ^SPKToggleMenuItem *(NSString *title, NSString *iconName, NSString *key) {
                        SPKToggleMenuItem *item = [SPKToggleMenuItem itemWithTitle:title
                                                                          iconName:iconName
                                                                       defaultsKey:key];
                        item.enabledProvider = ^BOOL {
                            if ([SPKUtils getBoolPref:key])
                                return YES;
                            return !SPKEnablingKeyHidesEveryTab(key);
                        };
                        item.requiresRestart = YES;
                        item.changeHandler = ^(BOOL isOn) {
                            [[NSUserDefaults standardUserDefaults] setBool:isOn
                                                                    forKey:SPKEffectivePreferenceKey(key)];
                        };
                        return item;
                    };

                SPKToggleMenuItem *messagesItem = tabItem(@"Messages", @"messages", @"interface_hide_msgs_tab");
                // Classic puts Messages back in the top-right corner instead of the
                // bottom bar (that layout is where the Create "+" becomes a tab), so
                // the "tab" toggle doesn't apply — hide it whenever Create's does show.
                messagesItem.hiddenProvider = ^BOOL {
                    return [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
                };

                SPKToggleMenuItem *createItem = tabItem(@"Create", @"plus", @"interface_hide_create_tab");
                // The create button is only a dedicated tab in the Classic tab
                // order; the other layouts fold it into the composer.
                createItem.hiddenProvider = ^BOOL {
                    return ![[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
                };

                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide Tabs", @"eye_off", @[
                    tabItem(@"Feed", @"home", @"interface_hide_feed_tab"),
                    tabItem(@"Explore", @"search", @"interface_hide_explore_tab"),
                    messagesItem,
                    tabItem(@"Reels", @"reels", @"interface_hide_reels_tab"),
                    createItem,
                    tabItem(@"Profile", @"user_circle", @"interface_hide_profile_tab"),
                ]);
                g.searchKeywords = @"hide tab bar feed explore messages reels create profile";
                g;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide Tab Bar"
                                                           icon:SPKSettingsIcon(@"eye_off")
                                                    defaultsKey:@"interface_hide_tab_bar_in_messages_only"];
                s.enabledProvider = ^BOOL {
                    return SPKIsMessagesOnlyMode();
                };
                s.helpText = @"Available once Messages is the only visible tab. Sparkle Settings then opens by long-pressing the right navigation button.";
                s.searchKeywords = @"long press settings access space";
                s;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Header Shortcut Button"
                                                           icon:SPKSettingsIcon(@"action")
                                                    defaultsKey:@"interface_show_header_button_in_messages_only"];
                s.enabledProvider = ^BOOL {
                    return SPKIsMessagesOnlyMode();
                };
                s.helpText = @"Available once Messages is the only visible tab. Puts the feed header shortcut on the left of the navigation bar.";
                s;
            })
    ]];

    [sections addObject:SPKTopicSection(@"Screen", screenRows, nil)];
    // A single navigation row needs no header of its own — it closes the page.
    [sections addObject:SPKTopicSection(@"", @[
        [SPKSetting navigationCellWithTitle:@"Notifications"
                                       subtitle:nil
                                           icon:SPKSettingsIcon(@"notification")
                                    navSections:[SPKNotificationSettingsProvider sections]]
    ],
                                        nil)];

    [sections insertObject:SPKTopicSection(@"Tab Bar", tabBarRows, nil) atIndex:0];

    return SPKTopicNavigationSetting(@"Interface", @"interface", 24.0, sections);
}

@end
