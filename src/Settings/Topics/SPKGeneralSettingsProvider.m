#import "SPKGeneralSettingsProvider.h"

#import "../../AssetUtils.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/UI/SPKIGAlertPresenter.h"
#import "../../Utils.h"
#import "../SPKActionSectionIconPickerViewController.h"
#import "../SPKAppIconCatalog.h"
#import "../SPKAppIconPickerViewController.h"
#import "../SPKTopicSettingsSupport.h"

#pragma mark - Toggle groups behind a navigation row

// The accessory count and the rows are built from the same list, so a toggle
// added here can never fall out of the count shown on the parent row. Same
// principle as hanging `helpText` on the row instead of listing it in a footer:
// one source of truth, no second list to keep in sync.
//
// Spec keys: @"title" (required), @"key" (required), @"help" (optional).

static NSArray<NSDictionary<NSString *, NSString *> *> *SPKGeneralAdsToggles(void) {
    return @[
        @{@"title" : @"Hide Feed Ads", @"key" : @"general_hide_ads_feed"},
        @{@"title" : @"Hide Story Ads", @"key" : @"general_hide_ads_stories"},
        @{@"title" : @"Hide Reels Ads", @"key" : @"general_hide_ads_reels"},
        @{@"title" : @"Hide Explore Ads", @"key" : @"general_hide_ads_explore"},
        @{@"title" : @"Hide Reels Shopping CTA", @"key" : @"general_hide_reels_shopping_cta"}
    ];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *SPKGeneralMetaAIToggles(void) {
    return @[
        @{@"title" : @"Hide in Direct",
          @"key" : @"general_hide_meta_ai_msgs",
          @"help" : @"Includes inbox, composer, recipients, themes and message menus."},
        @{@"title" : @"Hide in Explore & Search", @"key" : @"general_hide_meta_ai_explore"},
        @{@"title" : @"Hide in Comments", @"key" : @"general_hide_meta_ai_comments"},
        @{@"title" : @"Hide in Creation Tools", @"key" : @"general_hide_meta_ai_creation"},
        @{@"title" : @"Hide Global AI Chrome",
          @"key" : @"general_hide_meta_ai_global",
          @"help" : @"Generic Meta AI buttons, placeholders and branded entry points."}
    ];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *SPKGeneralSuggestedUserToggles(void) {
    return @[
        @{@"title" : @"Hide Feed Suggestions", @"key" : @"general_hide_suggested_users_feed"},
        @{@"title" : @"Hide Reels Suggestions", @"key" : @"general_hide_suggested_users_reels"},
        @{@"title" : @"Hide Direct Suggestions", @"key" : @"general_hide_suggested_users_msgs"},
        @{@"title" : @"Hide Search Suggestions", @"key" : @"general_hide_suggested_users_search"},
        @{@"title" : @"Hide Profile Suggestions", @"key" : @"general_hide_suggested_users_profile"},
        @{@"title" : @"Hide Activity Suggestions", @"key" : @"general_hide_suggested_users_activity"},
        @{@"title" : @"Hide Follow-List Suggestions", @"key" : @"general_hide_suggested_users_follow_lists"},
        @{@"title" : @"Hide Subscription Suggestions", @"key" : @"general_hide_suggested_users_subscriptions"}
    ];
}

static NSArray<SPKSetting *> *SPKGeneralSwitchRowsFromSpecs(NSArray<NSDictionary<NSString *, NSString *> *> *specs) {
    NSMutableArray<SPKSetting *> *rows = [NSMutableArray arrayWithCapacity:specs.count];
    for (NSDictionary<NSString *, NSString *> *spec in specs) {
        SPKSetting *row = [SPKSetting switchCellWithTitle:spec[@"title"]
                                              defaultsKey:spec[@"key"]];
        row.helpText = spec[@"help"];
        [rows addObject:row];
    }
    return [rows copy];
}

/// State for a page of "Hide …" toggles, shown on the row that leads to it:
/// `Off`, `N hidden`, or `All hidden`. Re-read on every `viewWillAppear`, so it
/// refreshes on the way back from the sub-page with no extra plumbing.
static NSString *SPKGeneralHiddenCountAccessory(NSArray<NSDictionary<NSString *, NSString *> *> *specs) {
    NSUInteger on = 0;
    for (NSDictionary<NSString *, NSString *> *spec in specs) {
        if ([SPKUtils getBoolPref:spec[@"key"]]) {
            on++;
        }
    }

    if (on == 0)
        return @"Off";
    if (on == specs.count)
        return @"All hidden";
    return [NSString stringWithFormat:@"%lu hidden", (unsigned long)on];
}

static SPKSetting *SPKGeneralToggleGroupNavigationSetting(NSString *title,
                                                          NSString *iconName,
                                                          NSString *sectionHeader,
                                                          NSString *_Nullable sectionFooter,
                                                          NSArray<NSDictionary<NSString *, NSString *> *> *specs,
                                                          NSString *_Nullable searchKeywords) {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:title
                                                     subtitle:@""
                                                         icon:SPKSettingsIcon(iconName)
                                                  navSections:@[
                                                      SPKTopicSection(sectionHeader,
                                                                      SPKGeneralSwitchRowsFromSpecs(specs),
                                                                      sectionFooter)
                                                  ]];
    setting.accessoryTextProvider = ^NSString * {
        return SPKGeneralHiddenCountAccessory(specs);
    };
    setting.searchKeywords = searchKeywords;
    return setting;
}

#pragma mark -

@implementation SPKGeneralSettingsProvider

+ (SPKSetting *)defaultMenuIconSetting {
    SPKActionSectionIconPickerViewController *controller =
        [[SPKActionSectionIconPickerViewController alloc] initWithSelectedIconName:SPKActionButtonOpenMenuIconName()
                                                                          onSelect:^(NSString *iconName) {
                                                                              SPKPreferenceSetObject(iconName.length > 0 ? iconName : @"action", @"general_action_btn_default_menu_icon");
                                                                              [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
                                                                          }];
    controller.title = @"Open Menu Icon";

    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Open Menu Icon"
                                                     subtitle:@""
                                                         icon:SPKSettingsIcon(@"action")
                                               viewController:controller];
    // The row's icon mirrors the chosen glyph, so the (cryptic) catalog name is
    // redundant as accessory text — let the adaptive icon convey the selection.
    setting.iconProvider = ^UIImage * {
        return SPKSettingsIcon(SPKActionButtonOpenMenuIconName());
    };
    setting.helpText = @"Changes the icon on every action button set to Open Menu.";
    setting.searchKeywords = @"glyph action button open menu";
    return setting;
}

+ (SPKSetting *)appIconSetting {
    SPKAppIconPickerViewController *controller = [[SPKAppIconPickerViewController alloc] initWithSelectedIdentifier:[SPKAppIconCatalog currentAppIconIdentifier]
                                                                                                           onSelect:nil];
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"App Icon"
                                                     subtitle:@""
                                                         icon:SPKSettingsIcon(@"app")
                                               viewController:controller];
    setting.accessoryTextProvider = ^NSString * {
        SPKAppIconItem *currentIcon = [SPKAppIconCatalog currentAppIcon];
        return currentIcon.displayName.length > 0 ? currentIcon.displayName : @"Default";
    };
    setting.helpText = @"Only icons that ship inside the installed Instagram app can be used.";
    setting.searchKeywords = @"alternate icons bundle";
    return setting;
}

+ (SPKSetting *)perAccountSetting {
    SPKSetting *setting = [SPKSetting switchCellWithTitle:@"Per-Account Settings"
                                                     icon:SPKSettingsIcon(@"user_circle")
                                              defaultsKey:kSPKPrefPerAccountSettings];
    // Changes which key namespace every feature reads, and most enabled-state is
    // captured at hook install, so a restart applies it cleanly.
    setting.requiresRestart = YES;
    return setting;
}

+ (SPKSetting *)perAccountInfoSetting {
    return [SPKSetting buttonCellWithTitle:@"How It Works"
                                  subtitle:nil
                                      icon:SPKSettingsIcon(@"info")
                                    action:^{
                                        NSString *message =
                                            @"Each logged-in account gets its own Sparkle settings. A newly seen "
                                            @"account starts from your current settings until you change something.\n\n"
                                            @"These stay shared across all accounts:\n"
                                            @"•  App icon\n"
                                            @"•  Appearance & Liquid Glass\n"
                                            @"•  Tab bar order & visibility\n"
                                            @"•  Quick access shortcuts (Settings & Gallery)\n"
                                            @"•  Main feed mode (For You / Following)\n"
                                            @"•  Disable video autoplay\n"
                                            @"•  Reels doom scroll & limits\n"
                                            @"•  Hide UI on capture\n"
                                            @"•  Download encoding settings\n"
                                            @"•  Gallery view, sort & lock\n"
                                            @"•  Fix duplicate notifications\n"
                                            @"•  Disable All (master switch)\n\n"
                                            @"Gallery media ownership is controlled separately in Gallery settings.";

                                        [SPKIGAlertPresenter presentAlertFromViewController:topMostController()
                                                                                      title:@"Per-Account Settings"
                                                                                    message:message
                                                                                    actions:@[ [SPKIGAlertAction actionWithTitle:@"OK" style:SPKIGAlertActionStyleCancel handler:nil] ]];
                                    }];
}

+ (SPKSetting *)rootSetting {
    SPKSetting *clearCacheSetting = [SPKSetting buttonCellWithTitle:@"Clear Cache"
                                                           subtitle:@""
                                                               icon:SPKSettingsIcon(@"trash")
                                                             action:^(void) {
                                                                 unsigned long long freedBytes = [SPKUtils cleanCacheReturningFreedBytes];
                                                                 NSString *subtitle = freedBytes > 0
                                                                                          ? [NSString stringWithFormat:@"Freed %@", [NSByteCountFormatter stringFromByteCount:(long long)freedBytes countStyle:NSByteCountFormatterCountStyleFile]]
                                                                                          : @"Cache was already empty";
                                                                 SPKNotify(kSPKNotificationSettingsClearCache, @"Cache cleared", subtitle, @"circle_check_filled", SPKNotificationToneForIconResource(@"circle_check_filled"));
                                                             }];
    clearCacheSetting.tintColor = [SPKUtils SPKColor_InstagramDestructive];
    clearCacheSetting.iconTintColor = [SPKUtils SPKColor_InstagramDestructive];
    clearCacheSetting.accessoryTextProvider = ^NSString * {
        return [SPKUtils formattedCacheSize];
    };

    // ---- Behavior ------------------------------------------------------

    SPKSetting *copyText = [SPKSetting switchCellWithTitle:@"Copy Text"
                                                      icon:SPKSettingsIcon(@"text")
                                               defaultsKey:@"general_copy_text"];
    copyText.helpText = @"Long-press any text field in the app.";
    copyText.searchKeywords = @"long press clipboard select";

    // No footer line: "Search bars will no longer save recent searches" only
    // restates the title, and the sheet shows the title above the text.
    SPKSetting *noRecentSearches = [SPKSetting switchCellWithTitle:@"No Recent Searches"
                                                              icon:SPKSettingsIcon(@"search")
                                                       defaultsKey:@"general_no_recent_searches"];
    noRecentSearches.searchKeywords = @"history recents search bar";

    SPKSetting *stripTracking = [SPKSetting switchCellWithTitle:@"Copy Links Without Tracking"
                                                           icon:SPKSettingsIcon(@"user_unfollow")
                                                    defaultsKey:@"general_strip_share_link_tracking"];
    stripTracking.helpText = @"The copied link loses the IDs Instagram uses to track who shared it.";
    stripTracking.searchKeywords = @"igshid utm referrer identifiers url";

    SPKSetting *holdSendCopyLink = [SPKSetting switchCellWithTitle:@"Hold Send to Copy Link"
                                                              icon:SPKSettingsIcon(@"link")
                                                       defaultsKey:@"general_hold_send_copy_link"];
    holdSendCopyLink.helpText = @"Long-press the send or share button to get the post link.";
    holdSendCopyLink.searchKeywords = @"long press share button post link";

    // ---- Sharing -------------------------------------------------------

    SPKSetting *hideCreateGroup = [SPKSetting switchCellWithTitle:@"Hide Create Group Button"
                                                             icon:SPKSettingsIcon(@"group")
                                                      defaultsKey:@"general_hide_create_group"];
    hideCreateGroup.searchKeywords = @"send share sheet";

    // Both "Confirm …" rows had footer lines that only said "Show a confirmation
    // alert when …" — the title already says it.
    SPKSetting *confirmCreateGroup = [SPKSetting switchCellWithTitle:@"Confirm Create Group"
                                                                icon:SPKSettingsIcon(@"group")
                                                         defaultsKey:@"general_confirm_create_group"];
    SPKSetting *confirmSendingPost = [SPKSetting switchCellWithTitle:@"Confirm Sending Post"
                                                                icon:SPKSettingsIcon(@"messages")
                                                         defaultsKey:@"general_confirm_send"];

    // ---- Media Preview & Menu ------------------------------------------

    SPKSetting *showMediaInfo = [SPKSetting switchCellWithTitle:@"Show Media Info"
                                                           icon:SPKSettingsIcon(@"info")
                                                    defaultsKey:@"general_preview_show_metadata"];
    showMediaInfo.searchKeywords = @"author date overlay metadata";

    SPKSetting *showDateInMenu = [SPKSetting switchCellWithTitle:@"Show Date in Menu"
                                                            icon:SPKSettingsIcon(@"calendar")
                                                     defaultsKey:@"general_action_btn_show_date"];
    showDateInMenu.searchKeywords = @"timestamp posted exact time";

    // ---- Comments (one section, was three) -----------------------------
    //
    // The split into three cards — one titled, two anonymous — encoded exactly
    // one real fact: Swipe Direction depends on Swipe to Close Comments. That's
    // `enabledProvider`'s job, not a silent card break, so the eight rows are
    // one card now and the dependency is visible as a greyed row.

    SPKSetting *copyComment = [SPKSetting switchCellWithTitle:@"Copy Comment"
                                                         icon:SPKSettingsIcon(@"copy")
                                                  defaultsKey:@"general_comments_copy_text"];
    copyComment.searchKeywords = @"clipboard comment menu";

    SPKSetting *commentMediaActions = [SPKSetting switchCellWithTitle:@"Comment Media Actions"
                                                                 icon:SPKSettingsIcon(@"action")
                                                          defaultsKey:@"general_comments_media_actions"];
    commentMediaActions.helpText = @"Adds Photos, Share, Gallery and link actions to GIF and photo comments.";
    commentMediaActions.searchKeywords = @"gif photos share gallery link";

    SPKSetting *commentGalleryUpload = [SPKSetting switchCellWithTitle:@"Upload Photo from Gallery"
                                                                  icon:SPKSettingsIcon(@"photo")
                                                           defaultsKey:@"general_comments_gallery_upload"];
    commentGalleryUpload.helpText = @"Long-press the composer's photo button to attach from your Sparkle Gallery.";
    commentGalleryUpload.searchKeywords = @"attach composer sparkle gallery";

    SPKSetting *swipeCloseComments = [SPKSetting switchCellWithTitle:@"Swipe to Close Comments"
                                                                icon:SPKSettingsIcon(@"left_right")
                                                         defaultsKey:@"general_comments_swipe_close"];
    swipeCloseComments.searchKeywords = @"gesture horizontal dismiss";
    // Greys Swipe Direction out immediately instead of after leaving the page.
    swipeCloseComments.reloadsTableOnSwitchChange = YES;

    SPKSetting *swipeDirection = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Swipe Direction"
                                                                                          icon:SPKSettingsIcon(@"left_right")
                                                                                          menu:SPKSwipeCloseCommentsDirectionMenu()],
                                                                 SPKSettingsIcon(@"left_right"));
    swipeDirection.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:@"general_comments_swipe_close"];
    };

    SPKSetting *confirmCommentLike = [SPKSetting switchCellWithTitle:@"Confirm Comment Like"
                                                                icon:SPKSettingsIcon(@"heart")
                                                         defaultsKey:@"general_comments_confirm_like"];

    SPKSetting *hideCommentShopping = [SPKSetting switchCellWithTitle:@"Hide Comment Shopping"
                                                                 icon:SPKSettingsIcon(@"shopping_bag")
                                                          defaultsKey:@"general_comments_hide_shopping"];
    hideCommentShopping.helpText = @"Removes commerce carousels from comment threads.";
    hideCommentShopping.searchKeywords = @"commerce carousel shop";

    SPKSetting *hideGiftsButton = [SPKSetting switchCellWithTitle:@"Hide Gifts Button"
                                                             icon:SPKSettingsIcon(@"gift")
                                                      defaultsKey:@"general_comments_hide_gifts_button"];
    hideGiftsButton.helpText = @"Removes the gift shortcut from the composer.";
    hideGiftsButton.searchKeywords = @"gift composer shortcut";

    // ---- Storage -------------------------------------------------------

    SPKSetting *autoClearCache = [SPKSetting menuCellWithTitle:@"Auto Clear Cache"
                                                          icon:SPKSettingsIcon(@"clock")
                                                          menu:SPKCacheAutoClearMenu()];
    autoClearCache.helpText = @"Runs each time you open Instagram — not on a timer.";
    autoClearCache.searchKeywords = @"foreground launch active schedule";

    // ---- App -----------------------------------------------------------

    // The footer line only restated the title; "vibrations" was the one word
    // worth keeping, so it moves to the search keywords.
    SPKSetting *disableHaptics = [SPKSetting switchCellWithTitle:@"Disable App Haptics"
                                                            icon:SPKSettingsIcon(@"haptics")
                                                     defaultsKey:@"general_disable_haptics"];
    disableHaptics.searchKeywords = @"vibration vibrations taptic feedback";

    return SPKTopicNavigationSetting(@"General", @"settings", 24.0, @[
        SPKTopicSection(@"Behavior", @[
            copyText,
            noRecentSearches,
            stripTracking,
            holdSendCopyLink
        ],
                        nil),
        SPKTopicSection(@"Sharing", @[
            hideCreateGroup,
            confirmCreateGroup,
            confirmSendingPost
        ],
                        nil),
        // Kept as a footer: it describes the section, not any one row, so it has
        // no row to hang off and no ⓘ to open.
        SPKTopicSection(@"Recommendations", @[
            SPKGeneralToggleGroupNavigationSetting(@"Ads", @"ads", @"Ads", nil,
                                                   SPKGeneralAdsToggles(),
                                                   @"advertising sponsored promoted"),
            SPKGeneralToggleGroupNavigationSetting(@"Meta AI", @"meta_ai", @"", nil,
                                                   SPKGeneralMetaAIToggles(),
                                                   @"ai assistant llama"),
            SPKGeneralToggleGroupNavigationSetting(@"Suggested Users", @"users", @"Suggested Users", nil,
                                                   SPKGeneralSuggestedUserToggles(),
                                                   @"suggestions recommended accounts")
        ],
                        nil),
        SPKTopicSection(@"Media Preview & Menu", @[
            showMediaInfo,
            showDateInMenu
        ],
                        nil),
        SPKTopicSection(@"Comments", @[
            copyComment,
            commentMediaActions,
            commentGalleryUpload,
            swipeCloseComments,
            swipeDirection,
            confirmCommentLike,
            hideCommentShopping,
            hideGiftsButton
        ],
                        nil),
        SPKTopicSection(@"Accounts", @[
            [self perAccountSetting],
            [self perAccountInfoSetting]
        ],
                        nil),
        SPKTopicSection(@"Storage", @[
            clearCacheSetting,
            autoClearCache
        ],
                        nil),
        SPKTopicSection(@"App", @[
            [self appIconSetting],
            [self defaultMenuIconSetting],
            disableHaptics
        ],
                        nil),
    ]);
}

@end
