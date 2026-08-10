#import "SPKMessagesSettingsProvider.h"

#import "../../Features/Messages/DeletedMessagesLog/SPKDeletedMessagesStorage.h"
#import "../../Features/Messages/DeletedMessagesLog/SPKDeletedMessagesViewController.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Shared/Messages/SPKDirectSeenContext.h"
#import "../../Utils.h"
#import "../SPKSettingsViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKMessagesActionButtonEnabledKey = @"msgs_action_btn";
static NSString *const kSPKMessagesActionButtonChatMediaKey = @"msgs_action_btn_chat_media";
static NSString *const kSPKMessagesAudioCallConfirmKey = @"msgs_confirm_audio_call";
static NSString *const kSPKMessagesVideoCallConfirmKey = @"msgs_confirm_video_call";

static NSArray *SPKMessagesSettingsSections(void);

// A switch cell that stays visible but is disabled while the "Audio Downloads"
// master toggle is off (keeping its stored value).
static SPKSetting *SPKAudioGatedSwitch(NSString *title, UIImage *icon, NSString *defaultsKey) {
    SPKSetting *setting = [SPKSetting switchCellWithTitle:title icon:icon defaultsKey:defaultsKey];
    setting.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:@"downloads_audio_enabled"];
    };
    return setting;
}

@interface SPKMessagesSettingsViewController : SPKSettingsViewController
@end

@implementation SPKMessagesSettingsViewController
- (instancetype)init {
    return [super initWithTitle:@"Messages" sections:SPKMessagesSettingsSections() reduceMargin:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKMessagesSettingsSections()];
}

- (void)switchChanged:(UISwitch *)sender {
    SPKSetting *row = [self settingForSender:sender];
    [super switchChanged:sender];
    if ([row.defaultsKey isEqualToString:@"msgs_manual_seen"] ||
        [row.defaultsKey isEqualToString:@"msgs_manual_visual_seen"]) {
        [self replaceSections:SPKMessagesSettingsSections()];
    }
}
@end

static NSArray *SPKMessagesSettingsSections(void) {
    BOOL manualSeen = [SPKUtils getBoolPref:@"msgs_manual_seen"];
    SPKSetting *manualSeenList = [SPKSetting navigationCellWithTitle:SPKDirectManualSeenListTitle(manualSeen)
                                                            subtitle:nil
                                                                icon:SPKSettingsIcon(@"users")
                                                      viewController:SPKDirectManualSeenListViewController()];
    manualSeenList.userInfo = @{@"accessoryText" : [NSString stringWithFormat:@"%lu", (unsigned long)SPKDirectManualSeenThreadCount(manualSeen)]};
    manualSeenList.helpText = @"Excluded chats keep Instagram's normal read receipts; in Included mode only the listed chats are held. Also manageable from the eye button or a long-press in the inbox.";

    // ---- Action Button -------------------------------------------------

    SPKSetting *masterActionButton = [SPKSetting switchCellWithTitle:@"Messages Action Button"
                                                                icon:SPKSettingsIcon(@"action")
                                                         defaultsKey:kSPKMessagesActionButtonEnabledKey];
    // Same wording as the Feed master toggle — the six action-button pages share
    // one gesture template, so the sheets must read identically everywhere.
    masterActionButton.helpText = @"Tap runs the default action. Long-press opens the full action menu.";

    // Extends the action button to the full-screen viewer for permanent chat media
    // (camera-roll photos/videos, chat-menu media), replacing IG's native Save.
    // Only meaningful while the master action button toggle is on.
    SPKSetting *chatMediaActionButton = [SPKSetting switchCellWithTitle:@"Also Show on Chat Media"
                                                                  icon:SPKSettingsIcon(@"photo")
                                                           defaultsKey:kSPKMessagesActionButtonChatMediaKey];
    chatMediaActionButton.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:kSPKMessagesActionButtonEnabledKey];
    };
    chatMediaActionButton.helpText = @"Also covers camera-roll photos and videos opened full screen in a chat, where it replaces Instagram's Save button.";

    // ---- Messaging -----------------------------------------------------

    SPKSetting *unlockPreview = [SPKSetting switchCellWithTitle:@"Unlock Message Preview"
                                                           icon:SPKSettingsIcon(@"story_preview")
                                                    defaultsKey:@"msgs_unlock_preview"];
    unlockPreview.helpText = @"The chat long-press menu shows the real messages without marking them seen.";

    SPKSetting *manualSeenSwitch = [SPKSetting switchCellWithTitle:@"Manually Mark Seen"
                                                              icon:SPKSettingsIcon(@"eye")
                                                       defaultsKey:@"msgs_manual_seen"];
    manualSeenSwitch.helpText = @"Chats stop sending read receipts until you tap the eye button. The list below picks which chats are excluded or included.";

    // Auto-seen triggers only act while manual seen is on. Keep their stored value
    // but lock the cells when manual seen is off.
    // Convention v1.3 gate: the four auto-seen triggers, one row. Their shared
    // guard moves onto the gate itself — the family greys out together when
    // Manually Mark Seen is off.
    SPKSetting *markSeenGate = ({
        SPKSetting *g = SPKToggleMenuRowSetting(@"Mark Seen On…", @"eye", @[
            [SPKToggleMenuItem itemWithTitle:@"Message Send"
                                    iconName:@"messages"
                                 defaultsKey:@"msgs_seen_on_send"],
            [SPKToggleMenuItem itemWithTitle:@"Message Reply"
                                    iconName:@"reply"
                                 defaultsKey:@"msgs_seen_on_reply"],
            [SPKToggleMenuItem itemWithTitle:@"Reaction"
                                    iconName:@"reactions"
                                 defaultsKey:@"msgs_seen_on_reaction"],
            [SPKToggleMenuItem itemWithTitle:@"Typing"
                                    iconName:@"keyboard"
                                 defaultsKey:@"msgs_seen_on_typing"],
        ]);
        g.enabledProvider = ^BOOL {
            return [SPKUtils getBoolPref:@"msgs_manual_seen"];
        };
        g.searchKeywords = @"mark seen send reply reaction typing auto";
        g;
    });

    // Chooses where the manual-seen eye button lives: the top nav bar, or a
    // draggable bubble above the composer. Only meaningful while manual seen is on.
    // Up/Down arrows mirror the placement on both the menu items and the cell.
    SPKSetting *seenButtonPosition = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Seen Button Position"
                                                                                              icon:SPKSettingsIcon(@"arrow_up")
                                                                                              menu:SPKSeenButtonPositionMenu()],
                                                                     SPKSettingsIcon(@"arrow_up"));
    seenButtonPosition.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:@"msgs_manual_seen"];
    };
    seenButtonPosition.helpText = @"The eye button lives in the top bar, or as a draggable bubble above the composer — scroll to snap the bubble back.";

    // ---- Deleted Messages ----------------------------------------------

    SPKSetting *keepDeleted = [SPKSetting switchCellWithTitle:@"Keep Deleted Messages"
                                                         icon:SPKSettingsIcon(@"undo_circle")
                                                  defaultsKey:@"msgs_keep_deleted"];
    keepDeleted.helpText = @"Unsent messages stay in the chat with an undo marker until the inbox reloads.";

    SPKSetting *confirmRefresh = [SPKSetting switchCellWithTitle:@"Confirm Inbox Refresh"
                                                            icon:SPKSettingsIcon(@"arrow_cw")
                                                     defaultsKey:@"msgs_confirm_refresh"];
    confirmRefresh.helpText = @"Refreshing reloads every thread and drops the messages kept above.";

    SPKSetting *logDeleted = [SPKSetting switchCellWithTitle:@"Log Deleted Messages"
                                                        icon:SPKSettingsIcon(@"logs")
                                                 defaultsKey:@"msgs_deleted_log"];
    logDeleted.helpText = @"Saves each message before it disappears, including view-once media, until you clear the log.";

    SPKSetting *respectSeenList = [SPKSetting switchCellWithTitle:@"Respect Seen Chat List"
                                                             icon:SPKSettingsIcon(@"eye")
                                                      defaultsKey:@"msgs_deleted_log_respect_seen_list"];
    respectSeenList.helpText = @"Chats in your seen exclude/include list are left out of the log and its notifications.";

    // Counted once per page appearance (the sections are rebuilt in
    // viewWillAppear), like the manual-seen thread count above — never from an
    // accessoryTextProvider, which would re-read the log JSON on every cell pass.
    NSString *ownerPK = SPKAccountManager.currentAccountPK;
    NSUInteger deletedLogCount = ownerPK.length > 0 ? [SPKDeletedMessagesStorage allMessagesForOwnerPK:ownerPK].count : 0;
    SPKSetting *viewDeletedLog = [SPKSetting navigationCellWithTitle:@"View Deleted Messages"
                                                            subtitle:nil
                                                                icon:SPKSettingsIcon(@"channels")
                                                      viewController:[SPKDeletedMessagesViewController new]];
    viewDeletedLog.userInfo = @{@"accessoryText" : [NSString stringWithFormat:@"%lu", (unsigned long)deletedLogCount]};

    // ---- Interface -----------------------------------------------------

    // Tri-state control for reformatting the chat-header last-active presence
    // label: Off / Smart / Date & Time.
    SPKSetting *lastActiveFormat = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Last Active"
                                                                                            icon:SPKSettingsIcon(@"clock")
                                                                                            menu:SPKLastActiveFormatMenu()],
                                                                   SPKSettingsIcon(@"clock"));
    lastActiveFormat.searchKeywords = @"presence status smart date time exact";

    // Lexicon rename ("No …" → "Hide …"); old phrasing kept searchable.

    // ---- Visual Messages -----------------------------------------------

    // Advancing after a manual seen only applies while visual manual seen is on.
    SPKSetting *advanceVisual = [SPKSetting switchCellWithTitle:@"Advance After Manual Seen" icon:SPKSettingsIcon(@"autoscroll") defaultsKey:@"msgs_advance_visual_on_seen"];
    advanceVisual.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:@"msgs_manual_visual_seen"];
    };

    // Lexicon rename ("Stop …" → "Disable …"); old phrasing kept searchable.
    SPKSetting *disableAutoAdvance = [SPKSetting switchCellWithTitle:@"Disable Auto Advance"
                                                                icon:SPKSettingsIcon(@"autoscroll")
                                                         defaultsKey:@"msgs_stop_visual_auto_advance"];
    disableAutoAdvance.searchKeywords = @"stop next replay end";

    SPKSetting *disableViewOnce = [SPKSetting switchCellWithTitle:@"Disable View-Once Limitations"
                                                             icon:SPKSettingsIcon(@"view_once")
                                                      defaultsKey:@"msgs_disable_view_once"];
    disableViewOnce.searchKeywords = @"replay view twice limit";

    // ---- Audio & Media -------------------------------------------------
    // The composer entry points used to live in the section footers; they stay
    // findable through the search keywords below.

    SPKSetting *downloadVoice = SPKAudioGatedSwitch(@"Download Voice Messages", SPKSettingsIcon(@"audio_download"), @"msgs_download_audio_messages");
    downloadVoice.searchKeywords = @"voice message audio save";

    SPKSetting *uploadAudio = [SPKSetting switchCellWithTitle:@"Upload Audio"
                                                         icon:SPKSettingsIcon(@"audio_upload")
                                                  defaultsKey:@"msgs_upload_audio_messages"];
    uploadAudio.searchKeywords = @"composer plus menu voice video send";

    SPKSetting *trimAudio = [SPKSetting switchCellWithTitle:@"Trim Before Sending"
                                                       icon:SPKSettingsIcon(@"trim")
                                                defaultsKey:@"msgs_audio_upload_trim"];
    trimAudio.searchKeywords = @"cut editor length";

    SPKSetting *uploadGalleryPhoto = [SPKSetting switchCellWithTitle:@"Upload Photo from Gallery"
                                                                icon:SPKSettingsIcon(@"photo")
                                                         defaultsKey:@"msgs_upload_gallery_media"];
    uploadGalleryPhoto.searchKeywords = @"composer plus menu picture send";

    // ---- Notes ---------------------------------------------------------

    SPKSetting *downloadNotesAudio = SPKAudioGatedSwitch(@"Download Notes Audio", SPKSettingsIcon(@"audio"), @"msgs_download_notes_audio");
    downloadNotesAudio.helpText = @"Long-press a note in the tray — the option appears when the note has audio.";

    SPKSetting *copyNoteText = [SPKSetting switchCellWithTitle:@"Copy Note Text"
                                                          icon:SPKSettingsIcon(@"copy")
                                                   defaultsKey:@"msgs_copy_note_text"];
    copyNoteText.helpText = @"Long-press a note in the tray — the option appears when the note has text.";

    return @[
        SPKTopicSection(@"Action Button", @[
            masterActionButton,
            chatMediaActionButton,
            SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceDirect),
            SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceDirect, @"Messages", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceDirect), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceDirect))
        ],
                        nil),
        SPKTopicSection(@"Messaging", @[
            unlockPreview,
            manualSeenSwitch,
            seenButtonPosition,
            markSeenGate,
            manualSeenList,
        ],
                        nil),
        SPKTopicSection(@"Deleted Messages", @[
            keepDeleted,
            confirmRefresh,
            logDeleted,
            [SPKSetting switchCellWithTitle:@"Log Removed Reactions"
                                       icon:SPKSettingsIcon(@"reactions")
                                defaultsKey:@"msgs_deleted_log_reactions"],
            respectSeenList,
            viewDeletedLog,
        ],
                        nil),
        SPKTopicSection(@"Interface", @[
            lastActiveFormat,
            // Six hides of the same screen, one gate — the verb lives on the
            // row; Typing Status keeps its noun (it is not a button).
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide Chat Elements", @"eye", @[
                    [SPKToggleMenuItem itemWithTitle:@"Typing Status"
                                            iconName:@"keyboard"
                                         defaultsKey:@"msgs_disable_typing"],
                    [SPKToggleMenuItem itemWithTitle:@"Reels Blend"
                                            iconName:@"blend"
                                         defaultsKey:@"msgs_hide_reels_blend"],
                    [SPKToggleMenuItem itemWithTitle:@"Audio Call"
                                            iconName:@"call"
                                         defaultsKey:@"msgs_hide_audio_call_btn"],
                    [SPKToggleMenuItem itemWithTitle:@"Video Call"
                                            iconName:@"video"
                                         defaultsKey:@"msgs_hide_video_call_btn"],
                    [SPKToggleMenuItem itemWithTitle:@"Flag"
                                            iconName:@"flag"
                                         defaultsKey:@"msgs_hide_flag_btn"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Chats"
                                            iconName:@"question"
                                         defaultsKey:@"msgs_hide_suggested_chats"],
                ]);
                g.searchKeywords = @"hide typing status reels blend audio video call flag suggested chats button no suggestions inbox";
                g;
            }),
        ],
                        nil),
        // Visual Messages ∪ Vanish Mode: same territory (messages that
        // disappear) — and it resolves the duplicated "Disable Screenshot
        // Detection" row: one gate, two context-named items.
        SPKTopicSection(@"Ephemeral Messages", @[
            [SPKSetting switchCellWithTitle:@"Manually Mark Seen"
                                       icon:SPKSettingsIcon(@"eye")
                                defaultsKey:@"msgs_manual_visual_seen"],
            advanceVisual,
            disableAutoAdvance,
            disableViewOnce,
            ({
                // Renamed from "Disable Swipe-Up Gesture" — the word "vanish"
                // no longer comes from a section header.
                SPKSetting *sw = [SPKSetting switchCellWithTitle:@"Disable Vanish Swipe-Up"
                                                            icon:SPKSettingsIcon(@"arrow_up")
                                                     defaultsKey:@"msgs_disable_vanish_swipe_up"];
                sw.searchKeywords = @"gesture vanish mode";
                sw;
            }),
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Disable Screenshot Detection", @"warning", @[
                    [SPKToggleMenuItem itemWithTitle:@"View-Once Media"
                                            iconName:@"view_once"
                                         defaultsKey:@"msgs_disable_screenshot_detection"],
                    [SPKToggleMenuItem itemWithTitle:@"Vanish Mode"
                                            iconName:@"warning"
                                         defaultsKey:@"msgs_hide_vanish_screenshot"],
                ]);
                g.searchKeywords = @"screenshot detection vanish view once";
                g;
            }),
        ],
                        nil),
        SPKTopicSection(@"Notes", @[
            [SPKSetting switchCellWithTitle:@"Hide Notes Tray"
                                       icon:SPKSettingsIcon(@"notes")
                                defaultsKey:@"msgs_hide_notes_tray"],
            [SPKSetting switchCellWithTitle:@"Hide Friends Map"
                                       icon:SPKSettingsIcon(@"map")
                                defaultsKey:@"msgs_hide_friends_map"],
            downloadNotesAudio,
            copyNoteText,
        ],
                        nil),
        SPKTopicSection(@"Audio & Media", @[
            downloadVoice,
            uploadAudio,
            trimAudio,
            uploadGalleryPhoto,
        ],
                        nil),
        // Convention v1.2: the "Confirmations" gate row closes every page — one
        // tap opens the multi-toggle menu (icon left, checkmark right, stays
        // open while toggling). Items keep the old switches' keys and icons.
        SPKTopicSection(@"", @[
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Audio Call"
                                        iconName:@"call"
                                     defaultsKey:kSPKMessagesAudioCallConfirmKey],
                [SPKToggleMenuItem itemWithTitle:@"Video Call"
                                        iconName:@"video"
                                     defaultsKey:kSPKMessagesVideoCallConfirmKey],
                [SPKToggleMenuItem itemWithTitle:@"Double Tap"
                                        iconName:@"heart"
                                     defaultsKey:@"msgs_confirm_double_tap"],
                [SPKToggleMenuItem itemWithTitle:@"Reactions"
                                        iconName:@"reactions"
                                     defaultsKey:@"msgs_confirm_reaction"],
                [SPKToggleMenuItem itemWithTitle:@"Voice Messages"
                                        iconName:@"voice"
                                     defaultsKey:@"msgs_confirm_voice_msg"],
                [SPKToggleMenuItem itemWithTitle:@"Follow Requests"
                                        iconName:@"user_request"
                                     defaultsKey:@"msgs_confirm_follow_request"],
                [SPKToggleMenuItem itemWithTitle:@"Vanish Mode"
                                        iconName:@"vanish"
                                     defaultsKey:@"msgs_confirm_vanish_mode"],
                [SPKToggleMenuItem itemWithTitle:@"Changing Theme"
                                        iconName:@"palette"
                                     defaultsKey:@"msgs_confirm_theme_change"],
            ])
        ],
                        nil)
    ];
}

@implementation SPKMessagesSettingsProvider

+ (SPKSetting *)rootSetting {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Messages"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"messages")
                                               viewController:[[SPKMessagesSettingsViewController alloc] init]];
    setting.searchSectionsProvider = ^NSArray * {
        return SPKMessagesSettingsSections();
    };
    return SPKSettingApplyIconTint(setting, [SPKUtils SPKColor_InstagramPrimaryText]);
}

@end
