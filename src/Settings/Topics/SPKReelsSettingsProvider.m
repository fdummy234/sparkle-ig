#import "SPKReelsSettingsProvider.h"

#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKReelsActionButtonEnabledKey = @"reels_action_btn";

@implementation SPKReelsSettingsProvider

+ (SPKSetting *)rootSetting {
    return SPKTopicNavigationSetting(@"Reels", @"reels", 24.0, @[
        SPKTopicSection(@"Action Button", @[
            [SPKSetting switchCellWithTitle:@"Reels Action Button"
                                       icon:SPKSettingsIcon(@"action")
                                defaultsKey:kSPKReelsActionButtonEnabledKey],
            SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceReels),
            SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceReels, @"Reels", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceReels), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceReels))
        ],
                        @"Choose what tapping the action button does. Long press opens the full menu."),
        SPKTopicSection(@"Behavior", @[
            [SPKSetting menuCellWithTitle:@"Tap Controls"
                                     icon:SPKSettingsIcon(@"play")
                                     menu:SPKReelsTapControlMenu()],
            [SPKSetting switchCellWithTitle:@"Show Progress Scrubber"
                                       icon:SPKSettingsIcon(@"clock")
                                defaultsKey:@"reels_show_scrubber"],
            [SPKSetting switchCellWithTitle:@"Disable Auto-Unmuting Reels"
                                       icon:SPKSettingsIcon(@"volume_off")
                                defaultsKey:@"reels_disable_auto_unmute"
                            requiresRestart:YES],
            [SPKSetting switchCellWithTitle:@"Disable Reels Tab Refresh"
                                       icon:SPKSettingsIcon(@"arrow_cw")
                                defaultsKey:@"reels_disable_tab_refresh"]
        ],
                        @"Tap Controls changes what happens when you tap on a reel. Auto-unmuting controls prevent reels from unmuting when volume or silent mode changes."),
        SPKTopicSection(@"Limits", @[
            [SPKSetting switchCellWithTitle:@"Disable Scrolling Reels"
                                       icon:SPKSettingsIcon(@"autoscroll")
                                defaultsKey:@"reels_disable_scrolling"
                            requiresRestart:YES],
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Prevent Doom Scrolling"
                                                           icon:SPKSettingsIcon(@"arrow_down")
                                                    defaultsKey:@"reels_prevent_doom_scroll"];
                // The limit below only matters while this is on — grey it live.
                s.reloadsTableOnSwitchChange = YES;
                s;
            }),
            ({
                SPKSetting *s = [SPKSetting stepperCellWithTitle:@"Doom Scrolling Limit"
                                    subtitle:@"Only loads %@ %@"
                                 defaultsKey:@"reels_doom_scroll_limit"
                                         min:1
                                         max:100
                                        step:1
                                       label:@"reels"
                               singularLabel:@"reel"];
                s.enabledProvider = ^BOOL {
                    return [SPKUtils getBoolPref:@"reels_prevent_doom_scroll"];
                };
                s;
            }),
        ],
                        @"1. Stop vertical swiping between reels so the current reel stays put.\n"
                        @"2. Stop loading more reels once the limit below is reached.\n"
                        @"3. How many reels load before Prevent Doom Scrolling kicks in."),
        SPKTopicSection(@"Layout", @[
            [SPKSetting switchCellWithTitle:@"Hide Reels Header"
                                       icon:SPKSettingsIcon(@"reels")
                                defaultsKey:@"reels_hide_header"],
            [SPKSetting switchCellWithTitle:@"Hide Repost Button"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"reels_hide_repost_btn"
                            requiresRestart:YES],
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide Counts", @"heart", @[
                    [SPKToggleMenuItem itemWithTitle:@"Likes"
                                            iconName:@"heart"
                                         defaultsKey:@"reels_hide_like_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Comments"
                                            iconName:@"comment"
                                         defaultsKey:@"reels_hide_comment_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reposts"
                                            iconName:@"repost"
                                         defaultsKey:@"reels_hide_repost_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reshares"
                                            iconName:@"messages"
                                         defaultsKey:@"reels_hide_reshare_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Saves"
                                            iconName:@"save"
                                         defaultsKey:@"reels_hide_save_count"],
                ]);
                g.searchKeywords = @"hide like comment repost reshare save count metrics";
                g;
            }),
        ],
                        nil),
        // Convention v1.2 gate row — see SPKToggleMenu.h. "Reel Refresh" keeps
        // its qualifier: the page also has Disable Reels Tab Refresh.
        SPKTopicSection(@"", @[
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"reels_confirm_like"],
                [SPKToggleMenuItem itemWithTitle:@"Double Tap"
                                        iconName:@"heart"
                                     defaultsKey:@"reels_confirm_double_tap_like"],
                [SPKToggleMenuItem itemWithTitle:@"Reel Refresh"
                                        iconName:@"arrow_cw"
                                     defaultsKey:@"reels_confirm_refresh"],
                [SPKToggleMenuItem itemWithTitle:@"Repost"
                                        iconName:@"repost"
                                     defaultsKey:@"reels_confirm_repost"],
            ])
        ],
                        nil)
    ]);
}

@end
