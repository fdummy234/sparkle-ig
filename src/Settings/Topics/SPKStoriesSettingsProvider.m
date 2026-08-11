#import "SPKStoriesSettingsProvider.h"

#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Shared/Stories/SPKStoryContext.h"
#import "../../Utils.h"
#import "../SPKSettingsViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"
static NSString *const kSPKStoriesActionButtonEnabledKey = @"stories_action_btn";

static NSDictionary *SPKStoriesSeenReceiptsSection(void);
static NSArray *SPKStoriesSettingsSections(void);

@interface SPKStoriesSettingsViewController : SPKSettingsViewController
@end

@implementation SPKStoriesSettingsViewController
- (instancetype)init {
    return [super initWithTitle:@"Stories" sections:SPKStoriesSettingsSections() reduceMargin:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKStoriesSettingsSections()];
}

- (void)switchChanged:(UISwitch *)sender {
    SPKSetting *row = [self settingForSender:sender];
    [super switchChanged:sender];
    if ([row.defaultsKey isEqualToString:@"stories_manual_seen"]) {
        [self replaceSections:SPKStoriesSettingsSections()];
    }
}
@end

static NSDictionary *SPKStoriesSeenReceiptsSection(void) {
    BOOL manualSeen = [SPKUtils getBoolPref:@"stories_manual_seen"];
    NSString *footer = manualSeen
                           ? @"1. Stories are not marked seen automatically, except users in Excluded Users.\n"
                             @"2. Mark the story as seen when you press like.\n"
                             @"3. Mark the story as seen when you send a reply.\n"
                             @"4. Excluded Users use Instagram's normal seen behavior and do not need the eye button."
                           : @"1. Stories use Instagram's normal seen behavior, except users in Included Users.\n"
                             @"2. Mark the story as seen when you press like.\n"
                             @"3. Mark the story as seen when you send a reply.\n"
                             @"4. Included Users require the eye button, story like, or story reply to mark seen.";
    SPKSetting *manualSeenList = [SPKSetting navigationCellWithTitle:SPKStoryManualSeenListTitle(manualSeen)
                                                            subtitle:nil
                                                                icon:SPKSettingsIcon(@"users")
                                                      viewController:SPKStoryManualSeenListViewController()];
    manualSeenList.userInfo = @{@"accessoryText" : [NSString stringWithFormat:@"%lu", (unsigned long)SPKStoryManualSeenUserList(manualSeen).count]};

    // The auto-seen triggers only do anything while manual seen is on. Keep their
    // stored value but lock the cells when manual seen is off.
    // Convention v1.3 gate — two items only, but the family is already gated
    // in Messages: transversal uniformity wins over the size threshold. The
    // shared guard moves onto the gate.
    SPKSetting *markSeenGate = ({
        SPKSetting *g = SPKToggleMenuRowSetting(@"Mark Seen On…", @"eye", @[
            [SPKToggleMenuItem itemWithTitle:@"Like"
                                    iconName:@"heart"
                                 defaultsKey:@"stories_mark_seen_on_like"],
            [SPKToggleMenuItem itemWithTitle:@"Reply"
                                    iconName:@"reply"
                                 defaultsKey:@"stories_mark_seen_on_reply"],
        ]);
        g.enabledProvider = ^BOOL {
            return [SPKUtils getBoolPref:@"stories_manual_seen"];
        };
        g.searchKeywords = @"mark seen like reply auto";
        g;
    });

    return SPKTopicSection(@"Seen Receipts", @[
        [SPKSetting switchCellWithTitle:@"Manually Mark Seen"
                                   icon:SPKSettingsIcon(@"eye")
                            defaultsKey:@"stories_manual_seen"],
        markSeenGate,
        manualSeenList,
    ],
                           footer);
}

static NSArray *SPKStoriesSettingsSections(void) {
    return @[


        // "Other" was the confession that no subject had been found — these four
        // all act while viewing a story.
        SPKTopicSection(@"While Viewing", @[
            ({
                // Renamed from "Stop Auto Advance" — aligned with the Messages
                // twin (lot 1) and the Disable lexicon; "stop" stays searchable.
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Stay on Current Story"
                                                           icon:SPKSettingsIcon(@"autoscroll")
                                                    defaultsKey:@"stories_stop_auto_advance"];
                s.searchKeywords = @"stop next skip";
                s;
            }),
            // The three "Advance on…" rows, one gate. Their three footer notes
            // become the gate's ⓘ — a numbered footer can only point at rows.
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Advance On…", @"autoscroll", @[
                    [SPKToggleMenuItem itemWithTitle:@"Eye Button"
                                            iconName:@"eye"
                                         defaultsKey:@"stories_advance_on_manual_seen"],
                    [SPKToggleMenuItem itemWithTitle:@"Like"
                                            iconName:@"heart"
                                         defaultsKey:@"stories_advance_on_like_seen"],
                    [SPKToggleMenuItem itemWithTitle:@"Reply"
                                            iconName:@"reply"
                                         defaultsKey:@"stories_advance_on_reply_seen"],
                ]);
                g.helpText = @"Move to the next story when you press the eye button.\nMove to the next story when you press like.\nMove to the next story when you reply.";
                g.searchKeywords = @"advance auto next story eye button like reply";
                g;
            }),
            [SPKSetting switchCellWithTitle:@"Search Viewer List"
                                       icon:SPKSettingsIcon(@"search")
                                defaultsKey:@"stories_search_viewer_list"],
            [SPKSetting switchCellWithTitle:@"Hide Join Trending"
                                       icon:SPKSettingsIcon(@"arrow_up_right")
                                defaultsKey:@"stories_hide_join_trending"],
            [SPKSetting switchCellWithTitle:@"Show Story Mentions"
                                       icon:SPKSettingsIcon(@"mention")
                                defaultsKey:@"stories_mentions_btn"],
            [SPKSetting switchCellWithTitle:@"Show Poll Vote Counts"
                                       icon:SPKSettingsIcon(@"poll")
                                defaultsKey:@"stories_poll_vote_counts"],
            [SPKSetting switchCellWithTitle:@"Unlock Story Preview"
                                       icon:SPKSettingsIcon(@"story_preview")
                                defaultsKey:@"stories_unlock_preview"],
            [SPKSetting switchCellWithTitle:@"Hide Instagram Plus Button"
                                       icon:SPKSettingsIcon(@"aura")
                                defaultsKey:@"stories_hide_ig_plus_button"]
        ],
                        @"1. Prevent automatically moving to the next story.\n"
                        @"2. Choose which gestures move to the next story.\n"
                        @"3. Add a search button to your story's viewer list to search and filter anyone who viewed it.\n"
                        @"4. Hide the the \"Join a trending\" / \"Add Yours\" promo cards from stories.\n"
                        @"5. Enabling this will add a button above the bottom story bar, where you can see all mentioned users.\n"
                        @"6. Display the vote counts for each option the poll has.\n"
                        @"7. Unlock \"Story Preview\": the story long-press menu shows the actual story without appearing on the viewer list.\n"
                        @"8. Hide the Instagram Plus button in your story's viewer list."),

        // Convention v1.2 gate row — see SPKToggleMenu.h. Was the "Confirmations"
        // section (mid-page, plural header); now closes the page like everywhere.
        SPKTopicSection(@"Creation", @[
            [SPKSetting switchCellWithTitle:@"Allow Videos in Photo Sticker"
                                       icon:SPKSettingsIcon(@"video")
                                defaultsKey:@"stories_allow_video_sticker"],
            [SPKSetting switchCellWithTitle:@"Show Gallery Upload Button"
                                       icon:SPKSettingsIcon(@"sparkle_gallery")
                                defaultsKey:@"stories_gallery_upload_sticker"],
            [SPKSetting switchCellWithTitle:@"Use Detailed Color Picker"
                                       icon:SPKSettingsIcon(@"eyedropper")
                                defaultsKey:@"stories_detailed_color_picker"]
        ],
                        @"1. Allow selecting videos from your library in the story photo sticker.\n"
                        @"2. Use media from Sparkle Gallery as stickers.\n"
                        @"3. Long press on the eyedropper tool in stories to customize text color more precisely."),
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKStoriesActionButtonEnabledKey,
                                      @"1. Add an action button above the bottom story bar.\n"
                                      @"2. Choose the default action. Long press opens the full menu.",
                                      @[
                [SPKSetting switchCellWithTitle:@"Stories Action Button"
                                           icon:SPKSettingsIcon(@"action")
                                    defaultsKey:kSPKStoriesActionButtonEnabledKey],
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceStories),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceStories, @"Stories", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceStories), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceStories))
        
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"stories_confirm_like"],
                [SPKToggleMenuItem itemWithTitle:@"Quick Reaction"
                                        iconName:@"reactions"
                                     defaultsKey:@"stories_confirm_quick_reaction"],
                [SPKToggleMenuItem itemWithTitle:@"Sticker Interaction"
                                        iconName:@"sticker"
                                     defaultsKey:@"stories_confirm_sticker"],
            ])
        ],
                        nil)
    ];
}

@implementation SPKStoriesSettingsProvider

+ (SPKSetting *)rootSetting {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Stories"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"story")
                                               viewController:[[SPKStoriesSettingsViewController alloc] init]];
    setting.searchSectionsProvider = ^NSArray * {
        return SPKStoriesSettingsSections();
    };
    return SPKSettingApplyIconTint(setting, [SPKUtils SPKColor_InstagramPrimaryText]);
}

@end
