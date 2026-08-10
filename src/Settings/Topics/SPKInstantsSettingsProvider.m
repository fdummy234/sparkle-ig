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
        SPKTopicSection(@"Action Button", @[
            [SPKSetting switchCellWithTitle:@"Instants Action Button"
                                       icon:SPKSettingsIcon(@"action")
                                defaultsKey:kSPKInstantsActionButtonEnabledKey],
            SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceInstants),
            SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceInstants, @"Instants", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceInstants), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceInstants))
        ],
                        @"Choose what tapping the action button does. Long press opens the full menu."),
        SPKTopicSection(@"Privacy", @[
            [SPKSetting switchCellWithTitle:@"Allow Screenshots"
                                       icon:SPKSettingsIcon(@"warning")
                                defaultsKey:@"instants_allow_screenshot"],
        ],
                        @"Bypass screenshot and screen recording detection in the Instants viewer."),
        SPKTopicSection(@"Creation", @[
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Disable Instants Creation" icon:SPKSettingsIcon(@"instants") defaultsKey:@"instants_disable_creation"];
                s.switchChangeHandler = ^(BOOL isOn) {
                    SPKPreferenceSetObject(@(isOn), @"instants_disable_creation");
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"SPKQuickSnapCreationPrefChangedNotification" object:nil];
                };
                s;
            }),
            [SPKSetting switchCellWithTitle:@"Skip Camera After Instants"
                                       icon:SPKSettingsIcon(@"camera")
                                defaultsKey:@"instants_skip_camera_after_viewing"],
            ({
                BOOL cameraControlAvailable = SPKPrefIsAvailable(@"instants_disable_camera_control");
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Disable Camera Control"
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
                                defaultsKey:@"instants_camera_btn"],
        ],
                        @"1. Blocks Instant capture (photo and video) without disabling received Instants. The shutter is darkened.\n"
                        @"2. Skips the camera page Instagram opens after viewing the last Instant.\n"
                        @"3. Stops the hardware Camera Control button (iPhone 16/17) from taking an Instant.\n"
                        @"4. Adds a Sparkle button to the Instants camera view to upload a photo from Photos, Files, or Gallery, and to browse the Instants you have saved."),
        // Convention v1.2 gate row — see SPKToggleMenu.h. "Instants ›
        // Confirmations › Capture": both dropped words sit right above.
        // Capture keeps its disabled state (feature suspended).
        SPKTopicSection(@"", @[
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check_filled", @[
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
