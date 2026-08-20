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

// The "N on" accessory each destination carries: the keys of its sub-pages,
// counted at viewWillAppear, since accessoryTextProvider is read again on
// every reloadData. Same principle as the Ads and Meta AI counters in
// General — one source of truth, the rows themselves.
static void SPKCountRowsInSections(NSArray *sections, NSUInteger *on, NSUInteger *total);

static void SPKCountRows(NSArray *rows, NSUInteger *on, NSUInteger *total) {
    for (SPKSetting *row in rows) {
        if (![row isKindOfClass:[SPKSetting class]])
            continue;
        if (row.navSections.count > 0 || row.searchSectionsProvider != nil) {
            // Deliberately not recursive: the accessory counts the page itself.
            // Recursing made Interface add up its generated sub-pages and show 138.
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
    // Stories, Messages and Instants carry no navSections: their sections live
    // behind searchSectionsProvider, the same block that feeds search. The count
    // reads from that source, lazily, on every display.
    NSArray *eagerSections = topic.navSections;
    NSArray * (^lazySections)(void) = topic.searchSectionsProvider;
    if (eagerSections.count == 0 && lazySections == nil)
        return topic;
    topic.accessoryTextProvider = ^NSString * {
        NSArray *sections = eagerSections.count > 0 ? eagerSections : lazySections();
        NSUInteger on = 0, total = 0;
        SPKCountRowsInSections(sections, &on, &total);
        if (total == 0)
            return nil;  // page informative (About) : pas d'accessoire
        return on == 0 ? @"Off" : [NSString stringWithFormat:@"%lu active", (unsigned long)on];
    };
    return topic;
}

+ (NSArray *)sections {
    return @[
        @{
            @"header" : @"Your Sparkle",
            @"rows" : @[
                SPKRootRow([SPKGeneralSettingsProvider rootSetting]),
                // D6: "Appearance" held Interface alone. Both are settings that
                // apply to the whole app, so they share one group.
                SPKRootRow([SPKInterfaceSettingsProvider rootSetting])
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
            @"header" : @"People",
            @"rows" : @[
                SPKRootRow([SPKMessagesSettingsProvider rootSetting]),
                SPKRootRow([SPKProfileSettingsProvider rootSetting])
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
