#import "SPKInstantsSettingsProvider.h"
#include <UIKit/UIKit.h>

#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKPreferenceAvailability.h"
#import "../SPKSettingsViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKInstantsActionButtonEnabledKey = @"instants_action_btn";

static NSArray *SPKInstantsSettingsSections(void);

@interface SPKInstantsSettingsViewController : SPKSettingsViewController
@end

@implementation SPKInstantsSettingsViewController
- (instancetype)init {
    return [super initWithTitle:@"Instants" sections:SPKInstantsSettingsSections() reduceMargin:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKInstantsSettingsSections()];
}
@end

static NSArray *SPKInstantsSettingsSections(void) {
    return @[
        // "Privacy" held a single row; screenshots are part of what the camera
        // does, so the two sections become one.
        SPKTopicSection(@"Camera", @[
            [SPKSetting switchCellWithTitle:@"Disable Screenshot Detection"
                                       icon:SPKSettingsIcon(@"warning")
                                defaultsKey:@"instants_allow_screenshot"],
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Disable Instants Creation" icon:SPKSettingsIcon(@"instants") defaultsKey:@"instants_disable_creation"];
    s.searchKeywords = @"disable camera control";
                s.switchChangeHandler = ^(BOOL isOn) {
                    SPKPreferenceSetObject(@(isOn), @"instants_disable_creation");
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"SPKQuickSnapCreationPrefChangedNotification" object:nil];
                };
                s;
            }),
            [SPKSetting switchCellWithTitle:@"Skip Camera After Sending"
                                       icon:SPKSettingsIcon(@"photo")
                                defaultsKey:@"instants_skip_camera_after_viewing"],
            ({
                BOOL cameraControlAvailable = SPKPrefIsAvailable(@"instants_disable_camera_control");
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Ignore Camera Button"
                                                       subtitle:cameraControlAvailable ? @"" : @"Requires an iPhone with Camera Control"
                                                           icon:SPKSettingsSystemIcon(@"button.vertical.right.press", SPKSettingsCellIconPointSize, UIImageSymbolWeightSemibold)
                                                    defaultsKey:@"instants_disable_camera_control"];
                s;
            }),
            // Same glyph the button itself wears: the global "Open Menu Icon" choice.
            // Merged in from its own untitled one-row section — it is a camera
            // setting like the three above.
            [SPKSetting switchCellWithTitle:@"Camera View Button"
                                       icon:SPKSettingsIcon(SPKActionButtonOpenMenuIconName())
                                defaultsKey:@"instants_camera_btn"]
        ],
                        @"1. Bypass screenshot and screen recording detection in the Instants viewer.\n"
                        @"2. Blocks Instant capture (photo and video) without disabling received Instants. The shutter is darkened.\n"
                        @"3. Skips the camera page Instagram opens after viewing the last Instant.\n"
                        @"4. Stops the hardware Camera Control button (iPhone 16/17) from taking an Instant.\n"
                        @"5. Adds a Sparkle button to the Instants camera view to upload a photo from Photos, Files, or Gallery, and to browse the Instants you have saved."),
        // Convention v1.2 gate row — see SPKToggleMenu.h. "Instants ›
        // Confirmations › Capture": both dropped words sit right above.
        // Capture keeps its disabled state (feature suspended).
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKInstantsActionButtonEnabledKey,
                                      @"Choose what tapping the action button does. Long press opens the full menu.",
                                      @[
                [SPKSetting switchCellWithTitle:@"Show Action Button"
                                           icon:SPKSettingsIcon(@"action")
                                    defaultsKey:kSPKInstantsActionButtonEnabledKey],
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceInstants),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceInstants, @"Instants", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceInstants), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceInstants))
        
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                ({
                    SPKToggleMenuItem *item = [SPKToggleMenuItem itemWithTitle:@"Capture"
                                                                      iconName:@"instants_burst"
                                                                   defaultsKey:@"instants_confirm_capture"];
                    item.enabledProvider = ^BOOL {
                        return NO;
                    };
                    item;
                }),
                [SPKToggleMenuItem itemWithTitle:@"Reaction"
                                        iconName:@"reactions"
                                     defaultsKey:@"instants_confirm_reaction"],
            ])
        ],
                        nil),
    ];
}

@implementation SPKInstantsSettingsProvider

+ (UIViewController *)makeSettingsViewController {
    return [[SPKInstantsSettingsViewController alloc] init];
}

+ (SPKSetting *)rootSetting {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Instants"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"instants")
                                               viewController:[[SPKInstantsSettingsViewController alloc] init]];
    setting.searchSectionsProvider = ^NSArray * {
        return SPKInstantsSettingsSections();
    };
    return SPKSettingApplyIconTint(setting, [SPKUtils SPKColor_InstagramPrimaryText]);
}

@end
