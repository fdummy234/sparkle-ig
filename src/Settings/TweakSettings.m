#import "TweakSettings.h"

#import "Topics/SPKAboutSettingsProvider.h"
#import "Topics/SPKDataSettingsProvider.h"
#import "Topics/SPKDownloadsSettingsProvider.h"
#import "Topics/SPKFeedSettingsProvider.h"
#import "Topics/SPKGallerySettingsProvider.h"
#import "Topics/SPKGeneralSettingsProvider.h"
#import "Topics/SPKInstantsSettingsProvider.h"
#import "Topics/SPKInterfaceSettingsProvider.h"
#import "Topics/SPKMessagesSettingsProvider.h"
#import "Topics/SPKProfileAnalyzerSettingsProvider.h"
#import "Topics/SPKProfileSettingsProvider.h"
#import "Topics/SPKReelsSettingsProvider.h"
#import "Topics/SPKStoriesSettingsProvider.h"
#import "Topics/SPKToolsSettingsProvider.h"
#import "SPKSetting.h"
#import "../Utils.h"

@implementation SPKTweakSettings


#pragma mark - Root accessory (Phase 1)

// « N active » sur chaque destination : les clés des sous-pages, comptées au
// viewWillAppear (accessoryTextProvider est relu à chaque reloadData). Même
// principe que les compteurs Ads/Meta AI de General — une seule source, les
// rangées elles-mêmes.
static void SPKCountRowsInSections(NSArray *sections, NSUInteger *on, NSUInteger *total);

static void SPKCountRows(NSArray *rows, NSUInteger *on, NSUInteger *total) {
    for (SPKSetting *row in rows) {
        if (![row isKindOfClass:[SPKSetting class]])
            continue;
        if (row.navSections.count > 0) {
            SPKCountRowsInSections(row.navSections, on, total);
            continue;
        }
        if (row.defaultsKey.length == 0)
            continue;
        (*total)++;
        if ([SPKUtils getBoolPref:row.defaultsKey])
            (*on)++;
    }
}

static void SPKCountRowsInSections(NSArray *sections, NSUInteger *on, NSUInteger *total) {
    for (NSDictionary *section in sections) {
        SPKCountRows(section[@"rows"], on, total);
    }
}

static SPKSetting *SPKRootRow(SPKSetting *topic) {
    NSArray *navSections = topic.navSections;
    if (navSections.count == 0)
        return topic;
    topic.accessoryTextProvider = ^NSString * {
        NSUInteger on = 0, total = 0;
        SPKCountRowsInSections(navSections, &on, &total);
        if (total == 0)
            return nil;  // page informative (About) : pas d'accessoire
        return on == 0 ? @"Off" : [NSString stringWithFormat:@"%lu active", (unsigned long)on];
    };
    return topic;
}

+ (NSArray *)sections {
    return @[
        @{
            @"header" : @"",
            @"rows" : @[
                SPKRootRow([SPKGeneralSettingsProvider rootSetting])
            ]
        },
        @{
            @"header" : @"Content",
            @"rows" : @[
                SPKRootRow([SPKFeedSettingsProvider rootSetting]),
                SPKRootRow([SPKStoriesSettingsProvider rootSetting]),
                SPKRootRow([SPKReelsSettingsProvider rootSetting]),
                SPKRootRow([SPKInstantsSettingsProvider rootSetting])
            ]
        },
        @{
            @"header" : @"Messaging & Profile",
            @"rows" : @[
                SPKRootRow([SPKMessagesSettingsProvider rootSetting]),
                SPKRootRow([SPKProfileSettingsProvider rootSetting])
            ]
        },
        @{
            @"header" : @"Appearance",
            @"rows" : @[
                SPKRootRow([SPKInterfaceSettingsProvider rootSetting])
            ]
        },
        @{
            @"header" : @"Library",
            @"rows" : @[
                SPKRootRow([SPKGallerySettingsProvider rootSetting]),
                SPKRootRow([SPKDownloadsSettingsProvider rootSetting]),
                SPKRootRow([SPKProfileAnalyzerSettingsProvider rootSetting])
            ]
        },
        @{
            @"header" : @"System",
            @"rows" : @[
                SPKRootRow([SPKToolsSettingsProvider rootSetting]),
                SPKRootRow([SPKDataSettingsProvider rootSetting]),
                SPKRootRow([SPKAboutSettingsProvider rootSetting])
            ]
        }
    ];
}

+ (NSString *)title {
    return @"Sparkle";
}

@end
