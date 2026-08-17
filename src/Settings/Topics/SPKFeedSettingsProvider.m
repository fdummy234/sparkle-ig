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

    SPKSetting *commentGalleryUpload = [SPKSetting switchCellWithTitle:@"Attach Photo to Comments"
                                                                  icon:SPKSettingsIcon(@"photo")
                                                           defaultsKey:@"general_comments_gallery_upload"];
    commentGalleryUpload.helpText = @"Long-press the composer's photo button to attach from your Sparkle Gallery.";
    commentGalleryUpload.searchKeywords = @"attach composer sparkle gallery upload photo gallery";

    SPKSetting *swipeCloseComments = [SPKSetting switchCellWithTitle:@"Swipe to Close"
                                                                icon:SPKSettingsIcon(@"left_right")
                                                         defaultsKey:@"general_comments_swipe_close"];
    swipeCloseComments.helpText = @"Close comments with a swipe. Turning this on reveals the direction picker.";
    swipeCloseComments.searchKeywords = @"comments gesture horizontal dismiss";
    // Greys Swipe Direction out immediately instead of after leaving the page.
    swipeCloseComments.reloadsTableOnSwitchChange = YES;

    SPKSetting *swipeDirection = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Swipe Direction"
                                                                                          icon:SPKSettingsIcon(@"left_right")
                                                                                          menu:SPKSwipeCloseCommentsDirectionMenu()],
                                                                 SPKSettingsIcon(@"left_right"));
    swipeDirection.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"general_comments_swipe_close"];
    };

    SPKSetting *commentSort = [SPKSetting switchCellWithTitle:@"Sort Menu"
                                                         icon:SPKSettingsIcon(@"sort")
                                                  defaultsKey:@"feed_comments_sort_menu"
                                              requiresRestart:YES];
    commentSort.helpText = @"Instagram builds a comment sorting menu but never shows the button. This puts the button back on the thread. Instagram supplies the options, so a post it sends none for says so instead of opening an empty menu.";
    commentSort.searchKeywords = @"comment sort order chronological newest oldest top recent menu";

    SPKSetting *hideCommentShopping = [SPKSetting switchCellWithTitle:@"Hide Shopping Carousel"
                                                                 icon:SPKSettingsIcon(@"shopping_bag")
                                                          defaultsKey:@"general_comments_hide_shopping"];
    hideCommentShopping.helpText = @"Removes commerce carousels from comment threads.";
    hideCommentShopping.searchKeywords = @"comment commerce carousel shop shopping";

    SPKSetting *hideGiftsButton = [SPKSetting switchCellWithTitle:@"Hide Gifts Button"
                                                             icon:SPKSettingsIcon(@"gift")
                                                      defaultsKey:@"general_comments_hide_gifts_button"];
    hideGiftsButton.helpText = @"Removes the gift shortcut from the composer.";
    hideGiftsButton.searchKeywords = @"gift composer shortcut";

    // Comment settings relocated from General; keys unchanged.
    return @[
    SPKTopicSection(@"Comments", @[
                commentSort,
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

    SPKSetting *masterActionButton = [SPKSetting switchCellWithTitle:@"Show Action Button"
                                                                icon:SPKSettingsIcon(@"action")
                                                         defaultsKey:kSPKFeedActionButtonEnabledKey];
    // Same wording as the Messages master toggle — the six action-button pages
    // share one gesture template, so the sheets must read identically everywhere.
    masterActionButton.helpText = @"Tap runs the default action. Long-press opens the full action menu.";



    // ---- Layout --------------------------------------------------------

    SPKSetting *mainFeedMode = SPKSettingApplySelectedMenuIcon(({
                                                                   SPKSetting *row = [SPKSetting menuCellWithTitle:@"Default Feed" icon:SPKSettingsIcon(@"feed") menu:SPKMainFeedModeMenu()];
                                                                   row.searchKeywords = @"main feed";
                                                                   row;
                                                               }), SPKSettingsIcon(@"feed"));
    mainFeedMode.helpText = @"Following is the chronological feed of accounts you follow — Instagram keeps labelling the tab \"For you\".";
    mainFeedMode.searchKeywords = @"following chronological algorithm for you";


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
        SPKTopicSection(@"Layout", @[
            mainFeedMode,
            hideEntireFeed,
            // Stays a full row: requiresRestart disqualifies it from a gate
            // (doctrine R4) — the restart prompt needs the regular switch path.
            [SPKSetting switchCellWithTitle:@"Hide Repost Button"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"feed_hide_repost_btn"
                            requiresRestart:YES],
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide Feed Elements", @"eye_off", @[
                    [SPKToggleMenuItem itemWithTitle:@"Stories Tray"
                                            iconName:@"story"
                                         defaultsKey:@"feed_hide_stories_tray"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Posts"
                                            iconName:@"carousel"
                                         defaultsKey:@"feed_hide_suggested_posts"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Reels"
                                            iconName:@"reels"
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
                                            iconName:@"poll"
                                         defaultsKey:@"feed_hide_like_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Comments"
                                            iconName:@"comment"
                                         defaultsKey:@"feed_hide_comment_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reposts"
                                            iconName:@"repost"
                                         defaultsKey:@"feed_hide_repost_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reshares"
                                            iconName:@"shares"
                                         defaultsKey:@"feed_hide_reshare_count"],
                ]);
                g.searchKeywords = @"hide like comment repost reshare count metrics";
                g;
            }),
        ],
                        nil),
        SPKTopicSection(@"Playback & Refresh", @[
            longPressExpand,
            [SPKSetting switchCellWithTitle:@"Tap to Play Videos"
                                       icon:SPKSettingsIcon(@"autoplay_off")
                                defaultsKey:@"feed_disable_autoplay"
                            requiresRestart:YES],
            [SPKSetting switchCellWithTitle:@"Expand Videos Muted"
                                       icon:SPKSettingsIcon(@"volume_off")
                                defaultsKey:@"feed_expanded_vid_start_muted"],
            disableHomeRefresh,
            [SPKSetting switchCellWithTitle:@"Disable Background Refresh"
                                       icon:SPKSettingsIcon(@"arrow_cw")
                                defaultsKey:@"feed_disable_bg_refresh"]
        ],
                        nil),
        // Comments is a full section again: eight rows deep enough to stand on
        // their own page were one tap away for no reason.
        SPKFeedCommentsSections().firstObject,
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKFeedActionButtonEnabledKey,
                                      nil,
                                      @[
                masterActionButton,
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceFeed),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceFeed, @"Feed", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceFeed), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceFeed))
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"feed_confirm_post_like"],
                [SPKToggleMenuItem itemWithTitle:@"Double Tap"
                                        iconName:@"heart"
                                     defaultsKey:@"feed_confirm_double_tap_like"],
                [SPKToggleMenuItem itemWithTitle:@"Repost"
                                        iconName:@"repost"
                                     defaultsKey:@"feed_confirm_repost"],
                [SPKToggleMenuItem itemWithTitle:@"Comment"
                                        iconName:@"comment"
                                     defaultsKey:@"feed_confirm_post_comment"],
            ])
        ],
                        nil)
    ]);
}

@end
