#import "SPKFeedSettingsProvider.h"

#import "../../Features/Feed/HeaderActionButton.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKFeedActionButtonEnabledKey = @"feed_action_btn";

@implementation SPKFeedSettingsProvider

static NSArray *SPKFeedCommentsSections(void) {
    SPKSetting *copyComment = [SPKSetting switchCellWithTitle:@"Copy Comment"
                                                         icon:SPKSettingsIcon(@"copy")
                                                  defaultsKey:@"general_comments_copy_text"];
    copyComment.searchKeywords = @"clipboard comment menu";

    SPKSetting *commentMediaActions = [SPKSetting switchCellWithTitle:@"Media Actions"
                                                                 icon:SPKSettingsIcon(@"action")
                                                          defaultsKey:@"general_comments_media_actions"];
    commentMediaActions.helpText = @"Adds Photos, Share, Gallery and link actions to GIF and photo comments.";
    commentMediaActions.searchKeywords = @"comment gif photos share gallery link";

    SPKSetting *commentGalleryUpload = [SPKSetting switchCellWithTitle:@"Upload Photo from Gallery"
                                                                  icon:SPKSettingsIcon(@"photo")
                                                           defaultsKey:@"general_comments_gallery_upload"];
    commentGalleryUpload.helpText = @"Long-press the composer's photo button to attach from your Sparkle Gallery.";
    commentGalleryUpload.searchKeywords = @"attach composer sparkle gallery";

    SPKSetting *swipeCloseComments = [SPKSetting switchCellWithTitle:@"Swipe to Close"
                                                                icon:SPKSettingsIcon(@"left_right")
                                                         defaultsKey:@"general_comments_swipe_close"];
    swipeCloseComments.searchKeywords = @"comments gesture horizontal dismiss";
    // Greys Swipe Direction out immediately instead of after leaving the page.
    swipeCloseComments.reloadsTableOnSwitchChange = YES;

    SPKSetting *swipeDirection = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Swipe Direction"
                                                                                          icon:SPKSettingsIcon(@"left_right")
                                                                                          menu:SPKSwipeCloseCommentsDirectionMenu()],
                                                                 SPKSettingsIcon(@"left_right"));
    swipeDirection.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:@"general_comments_swipe_close"];
    };

    SPKSetting *hideCommentShopping = [SPKSetting switchCellWithTitle:@"Hide Shopping"
                                                                 icon:SPKSettingsIcon(@"shopping_bag")
                                                          defaultsKey:@"general_comments_hide_shopping"];
    hideCommentShopping.helpText = @"Removes commerce carousels from comment threads.";
    hideCommentShopping.searchKeywords = @"comment commerce carousel shop";

    SPKSetting *hideGiftsButton = [SPKSetting switchCellWithTitle:@"Hide Gifts Button"
                                                             icon:SPKSettingsIcon(@"gift")
                                                      defaultsKey:@"general_comments_hide_gifts_button"];
    hideGiftsButton.helpText = @"Removes the gift shortcut from the composer.";
    hideGiftsButton.searchKeywords = @"gift composer shortcut";

    return @[
        SPKTopicSection(@"Comments", @[
            copyComment,
            commentMediaActions,
            commentGalleryUpload,
            swipeCloseComments,
            swipeDirection,
            hideCommentShopping,
            hideGiftsButton
        ],
                        nil)
    ];
}

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
            hideEntireFeed,
            // Stays a full row: requiresRestart disqualifies it from a gate
            // (doctrine R4) — the restart prompt needs the regular switch path.
            [SPKSetting switchCellWithTitle:@"Hide Repost Button"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"feed_hide_repost_btn"
                            requiresRestart:YES],
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide Feed Elements", @"eye", @[
                    [SPKToggleMenuItem itemWithTitle:@"Stories Tray"
                                            iconName:@"story"
                                         defaultsKey:@"feed_hide_stories_tray"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Posts"
                                            iconName:@"carousel"
                                         defaultsKey:@"feed_hide_suggested_posts"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Reels"
                                            iconName:@"reels_gallery"
                                         defaultsKey:@"feed_hide_suggested_reels"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Threads"
                                            iconName:@"threads"
                                         defaultsKey:@"feed_hide_suggested_threads"],
                ]);
                g.searchKeywords = @"hide stories tray suggested posts reels threads";
                g;
            }),
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide Counts", @"heart", @[
                    [SPKToggleMenuItem itemWithTitle:@"Likes"
                                            iconName:@"heart"
                                         defaultsKey:@"feed_hide_like_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Comments"
                                            iconName:@"comment"
                                         defaultsKey:@"feed_hide_comment_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reposts"
                                            iconName:@"repost"
                                         defaultsKey:@"feed_hide_repost_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reshares"
                                            iconName:@"messages"
                                         defaultsKey:@"feed_hide_reshare_count"],
                ]);
                g.searchKeywords = @"hide like comment repost reshare count metrics";
                g;
            }),
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

        // Comments moved in from General — a new user looks for comments where
        // they see them. Seven rows, keys untouched, arrives as a sub-page.
        SPKTopicSection(@"Comments", @[
            [SPKSetting navigationCellWithTitle:@"Comments"
                                       subtitle:nil
                                           icon:SPKSettingsIcon(@"comment")
                                    navSections:SPKFeedCommentsSections()]
        ],
                        nil),
        // Convention v1.2 gate row — see SPKToggleMenu.h.
        SPKTopicSection(@"", @[
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check_filled", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"feed_confirm_post_like"],
                [SPKToggleMenuItem itemWithTitle:@"Double Tap"
                                        iconName:@"heart"
                                     defaultsKey:@"feed_confirm_double_tap_like"],
                [SPKToggleMenuItem itemWithTitle:@"Repost"
                                        iconName:@"repost"
                                     defaultsKey:@"feed_confirm_repost"],
                [SPKToggleMenuItem itemWithTitle:@"Posting Comment"
                                        iconName:@"comment"
                                     defaultsKey:@"feed_confirm_post_comment"],
            ])
        ],
                        nil)
    ]);
}

@end
