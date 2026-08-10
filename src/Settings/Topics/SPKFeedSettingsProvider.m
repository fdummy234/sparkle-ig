#import "SPKFeedSettingsProvider.h"

#import "../../Features/Feed/HeaderActionButton.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKFeedActionButtonEnabledKey = @"feed_action_btn";

@implementation SPKFeedSettingsProvider

+ (SPKSetting *)rootSetting {
    // ---- Action Button -------------------------------------------------

    SPKSetting *masterActionButton = [SPKSetting switchCellWithTitle:@"Feed Action Button"
                                                                icon:SPKSettingsIcon(@"action")
                                                         defaultsKey:kSPKFeedActionButtonEnabledKey];
    // Same wording as the Messages master toggle — the six action-button pages
    // share one gesture template, so the sheets must read identically everywhere.
    masterActionButton.helpText = @"Tap runs the default action. Long-press opens the full action menu.";

    // ---- Header Shortcut -----------------------------------------------

    SPKSetting *headerButton = [SPKSetting switchCellWithTitle:@"Feed Header Button"
                                                          icon:SPKSettingsIcon(@"action")
                                                   defaultsKey:kSPKHeaderButtonEnabledKey];
    headerButton.helpText = @"Adds a Sparkle button to the feed header. Tap opens your default destination; long-press lists every enabled one.";

    SPKSetting *configureDestinations = [SPKSetting navigationCellWithTitle:@"Configure Destinations"
                                                                   subtitle:nil
                                                                       icon:SPKSettingsIcon(@"sliders")
                                                                navSections:@[
                                                                    SPKTopicSection(@"Destinations", @[
                                                                        [SPKSetting switchCellWithTitle:@"Gallery"
                                                                                                   icon:SPKSettingsIcon(@"sparkle_gallery")
                                                                                            defaultsKey:@"feed_header_button_dest_gallery"],
                                                                        [SPKSetting switchCellWithTitle:@"Profile Analyzer"
                                                                                                   icon:SPKSettingsIcon(@"profile_analyzer")
                                                                                            defaultsKey:@"feed_header_button_dest_analyzer"],
                                                                        [SPKSetting switchCellWithTitle:@"Deleted Messages"
                                                                                                   icon:SPKSettingsIcon(@"channels")
                                                                                            defaultsKey:@"feed_header_button_dest_deleted"],
                                                                        [SPKSetting switchCellWithTitle:@"Downloads"
                                                                                                   icon:SPKSettingsIcon(@"download")
                                                                                            defaultsKey:@"feed_header_button_dest_downloads"],
                                                                        [SPKSetting switchCellWithTitle:@"Sparkle Settings"
                                                                                                   icon:SPKSettingsIcon(@"settings")
                                                                                            defaultsKey:@"feed_header_button_dest_settings"],
                                                                    ],
                                                                                    nil)
                                                                ]];
    configureDestinations.helpText = @"Enable one destination for a direct tap, or several to pick from the long-press menu.";

    // ---- Layout --------------------------------------------------------

    SPKSetting *mainFeedMode = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Main Feed" icon:SPKSettingsIcon(@"feed") menu:SPKMainFeedModeMenu()], SPKSettingsIcon(@"feed"));
    mainFeedMode.helpText = @"Following is the chronological feed of accounts you follow — Instagram keeps labelling the tab \"For you\".";
    mainFeedMode.searchKeywords = @"following chronological algorithm for you";

    SPKSetting *disableAppIconGesture = [SPKSetting switchCellWithTitle:@"Disable App Icon Gesture"
                                                                   icon:SPKSettingsIcon(@"app")
                                                            defaultsKey:@"feed_disable_appicon_gesture"];
    disableAppIconGesture.helpText = @"Stops the header-logo long-press from opening Instagram's icon picker. Sparkle's own picker lives in General → App.";
    disableAppIconGesture.searchKeywords = @"logo long press picker";

    SPKSetting *hideEntireFeed = [SPKSetting switchCellWithTitle:@"Hide Entire Feed"
                                                            icon:SPKSettingsIcon(@"feed")
                                                     defaultsKey:@"feed_hide_entire_feed"];
    hideEntireFeed.helpText = @"Hides every post and leaves only the feed header.";

    // ---- Media ---------------------------------------------------------

    SPKSetting *longPressExpand = [SPKSetting switchCellWithTitle:@"Long Press to Expand"
                                                             icon:SPKSettingsIcon(@"expand")
                                                      defaultsKey:@"feed_long_press_expand"];
    longPressExpand.helpText = @"Long-press any feed photo or video to open it full screen.";
    longPressExpand.searchKeywords = @"full screen viewer";

    // ---- Refresh -------------------------------------------------------

    SPKSetting *disableHomeRefresh = [SPKSetting switchCellWithTitle:@"Disable Home Tab Refresh"
                                                                icon:SPKSettingsIcon(@"home")
                                                         defaultsKey:@"feed_disable_home_refresh"];
    disableHomeRefresh.helpText = @"Re-tapping the Home tab scrolls back to top without reloading the feed.";

    return SPKTopicNavigationSetting(@"Feed", @"feed", 24.0, @[
        SPKTopicSection(@"Action Button", @[
            masterActionButton,
            SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceFeed),
            SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceFeed, @"Feed", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceFeed), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceFeed))
        ],
                        nil),
        SPKTopicSection(@"Header Shortcut", @[
            headerButton,
            SPKFeedHeaderButtonDefaultActionNavigationSetting(),
            configureDestinations,
        ],
                        nil),
        SPKTopicSection(@"Layout", @[
            mainFeedMode,
            disableAppIconGesture,
            [SPKSetting switchCellWithTitle:@"Hide Stories Tray"
                                       icon:SPKSettingsIcon(@"story")
                                defaultsKey:@"feed_hide_stories_tray"],
            hideEntireFeed,
            [SPKSetting switchCellWithTitle:@"Hide Suggested Posts"
                                       icon:SPKSettingsIcon(@"carousel")
                                defaultsKey:@"feed_hide_suggested_posts"],
            [SPKSetting switchCellWithTitle:@"Hide Suggested Reels"
                                       icon:SPKSettingsIcon(@"reels_gallery")
                                defaultsKey:@"feed_hide_suggested_reels"],
            [SPKSetting switchCellWithTitle:@"Hide Suggested Threads"
                                       icon:SPKSettingsIcon(@"threads")
                                defaultsKey:@"feed_hide_suggested_threads"],
            [SPKSetting switchCellWithTitle:@"Hide Repost Button"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"feed_hide_repost_btn"
                            requiresRestart:YES]
        ],
                        nil),
        SPKTopicSection(@"Metrics", @[
            [SPKSetting switchCellWithTitle:@"Hide Like Count"
                                       icon:SPKSettingsIcon(@"heart")
                                defaultsKey:@"feed_hide_like_count"],
            [SPKSetting switchCellWithTitle:@"Hide Comment Count"
                                       icon:SPKSettingsIcon(@"comment")
                                defaultsKey:@"feed_hide_comment_count"],
            [SPKSetting switchCellWithTitle:@"Hide Repost Count"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"feed_hide_repost_count"],
            [SPKSetting switchCellWithTitle:@"Hide Reshare Count"
                                       icon:SPKSettingsIcon(@"messages")
                                defaultsKey:@"feed_hide_reshare_count"]
        ],
                        nil),
        SPKTopicSection(@"Media", @[
            longPressExpand,
            [SPKSetting switchCellWithTitle:@"Disable Video Autoplay"
                                       icon:SPKSettingsIcon(@"autoplay_off")
                                defaultsKey:@"feed_disable_autoplay"
                            requiresRestart:YES],
            [SPKSetting switchCellWithTitle:@"Start Expanded Videos Muted"
                                       icon:SPKSettingsIcon(@"volume_off")
                                defaultsKey:@"feed_expanded_vid_start_muted"],
        ],
                        nil),
        SPKTopicSection(@"Refresh", @[
            disableHomeRefresh,
            [SPKSetting switchCellWithTitle:@"Disable Background Refresh"
                                       icon:SPKSettingsIcon(@"arrow_cw")
                                defaultsKey:@"feed_disable_bg_refresh"]
        ],
                        nil),
        SPKTopicSection(@"Confirmation", @[
            [SPKSetting switchCellWithTitle:@"Confirm Like"
                                       icon:SPKSettingsIcon(@"heart")
                                defaultsKey:@"feed_confirm_post_like"],
            [SPKSetting switchCellWithTitle:@"Confirm Double Tap"
                                       icon:SPKSettingsIcon(@"heart")
                                defaultsKey:@"feed_confirm_double_tap_like"],
            [SPKSetting switchCellWithTitle:@"Confirm Repost"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"feed_confirm_repost"],
            [SPKSetting switchCellWithTitle:@"Confirm Posting Comment"
                                       icon:SPKSettingsIcon(@"comment")
                                defaultsKey:@"feed_confirm_post_comment"]
        ],
                        nil)
    ]);
}

@end
