#import "../Shared/UI/SPKDialog.h"
#import "SPKStorageUsageViewController.h"

#import "../Shared/Avatars/SPKAvatarCache.h"
#import "../Shared/SPKStoragePaths.h"
#import "../Utils.h"
#import "SPKTopicSettingsSupport.h"

@interface SPKStorageUsageViewController ()
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *breakdown;
@end

@implementation SPKStorageUsageViewController

- (instancetype)init {
    return [super initWithTitle:@"Storage" sections:@[] reduceMargin:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self reloadStatsAndRebuild];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadStatsAndRebuild];
}

- (void)reloadStatsAndRebuild {
    self.breakdown = [SPKStoragePaths storageBreakdown];
    [self rebuildSections];
}

// A dash reads as "nothing"; "Zero KB" reads as a measurement that happens to
// be zero.
- (unsigned long long)bytesForKey:(NSString *)key {
    return [self.breakdown[key] unsignedLongLongValue];
}

- (NSString *)formattedKey:(NSString *)key {
    unsigned long long bytes = [self bytesForKey:key];
    if (bytes == 0)
        return @"—";
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes countStyle:NSByteCountFormatterCountStyleFile];
}

- (void)rebuildSections {
    NSMutableArray *sections = [NSMutableArray array];

    // The total is read, not set: a proportional bar in place of a section, the
    // same component the Gallery page uses.
    [sections addObject:SPKTopicSection(@"", @[
                  [SPKSetting storageBarCellWithFractions:@[ @([self bytesForKey:@"gallery"]),
                                                            @([self bytesForKey:@"avatars"]),
                                                            @([self bytesForKey:@"downloads"] +
                                                              [self bytesForKey:@"deletedMessages"] +
                                                              [self bytesForKey:@"profileAnalyzer"]) ]
                                                    value:[self formattedKey:@"total"]
                                                   legend:@"Gallery · Profile Pictures · everything else"]
              ],
                                        nil)];

    [sections addObject:SPKTopicSection(@"Breakdown", @[
                  [SPKSetting valueCellWithTitle:@"Gallery"
                    subtitle:[self formattedKey:@"gallery"]
                        icon:SPKSettingsIcon(@"sparkle_gallery")],
                  [SPKSetting valueCellWithTitle:@"Downloads"
                    subtitle:[self formattedKey:@"downloads"]
                        icon:SPKSettingsIcon(@"download")],
                  [SPKSetting valueCellWithTitle:@"Deleted messages"
                    subtitle:[self formattedKey:@"deletedMessages"]
                        icon:SPKSettingsIcon(@"channels")],
                  [SPKSetting valueCellWithTitle:@"Profile analyzer"
                    subtitle:[self formattedKey:@"profileAnalyzer"]
                        icon:SPKSettingsIcon(@"profile_analyzer")],
                  [SPKSetting valueCellWithTitle:@"Profile pictures"
                    subtitle:[self formattedKey:@"avatars"]
                        icon:SPKSettingsIcon(@"user_circle")],
              ],
                                        nil)];

    SPKSetting *clearAvatars = [SPKSetting buttonCellWithTitle:@"Clear stored profile pictures"
                                                      subtitle:nil
                                                          icon:SPKSettingsIcon(@"trash")
                                                        action:^{
                                                            [self confirmClearAvatars];
                                                        }];
    clearAvatars.tintColor = [SPKUtils SPKColor_InstagramDestructive];
    clearAvatars.iconTintColor = [SPKUtils SPKColor_InstagramDestructive];

    // A header, because the ⓘ lives in one: without a title it floats over an
    // empty band.
    clearAvatars.helpText = @"Profile pictures are a shared cache reused across Sparkle. Clearing them frees space; they re-download as needed.";
    [sections addObject:SPKTopicSection(@"Cache", @[ clearAvatars ], nil)];

    [self replaceSections:sections];
}

- (void)confirmClearAvatars {
    [SPKDialog presentFromController:self
                                                  title:@"Clear stored profile pictures"
                                                message:@"The log and the captured files for this account are removed."
                                                actions:@[
                                                    [SPKDialogAction actionWithTitle:@"Cancel"
                                                                                style:SPKDialogActionStyleCancel
                                                                              handler:nil],
                                                    [SPKDialogAction actionWithTitle:@"Clear"
                                                                                style:SPKDialogActionStyleDestructive
                                                                              handler:^{
                                                                                  [[SPKAvatarCache shared] purge];
                                                                                  [self reloadStatsAndRebuild];
                                                                              }],
                                                ]];
}

@end
