#import "SPKGallerySettingsProvider.h"
#import "../SPKSetting.h"
#import "../SPKTopicSettingsSupport.h"

#import "../../Shared/Gallery/SPKGallerySettingsViewController.h"
#import "../../Shared/Gallery/SPKGalleryViewController.h"
#import "../../Utils.h"

@implementation SPKGallerySettingsProvider

+ (SPKSetting *)rootSetting {
    SPKSetting *gallerySettings = [SPKSetting navigationCellWithTitle:@"Settings"
                                                             subtitle:nil
                                                                 icon:SPKSettingsIcon(@"settings")
                                                       viewController:[[SPKGallerySettingsViewController alloc] init]];
    gallerySettings.searchSectionsProvider = ^NSArray * {
        return [SPKGallerySettingsViewController searchSections];
    };

    // One section, no header: three rows do not need two headers and a
    // "Gallery › Settings › Gallery Settings" triple. Both footer facts merge.
    return SPKTopicNavigationSetting(@"Gallery", @"sparkle_gallery", 24.0, @[
        SPKTopicSection(@"", @[
            [SPKSetting buttonCellWithTitle:@"Open Gallery"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"sparkle_gallery")
                                     action:^(void) {
                                         [SPKGalleryViewController presentGallery];
                                     }],
            SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Quick Gallery Access" icon:SPKSettingsIcon(@"circle_off") menu:SPKGalleryShortcutTargetMenu()], SPKSettingsIcon(@"circle_off")),
            gallerySettings
        ],
                        @"Quick Gallery Access chooses the tab that opens Gallery on long press — None disables it. "
                        @"Settings is the same screen you reach from inside Gallery.")
    ]);
}

@end
