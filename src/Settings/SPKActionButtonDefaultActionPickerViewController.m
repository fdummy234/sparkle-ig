#import "SPKActionButtonDefaultActionPickerViewController.h"

#import "../AssetUtils.h"
#import "../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../Shared/ActionButton/SPKActionDescriptor.h"
#import "../Utils.h"
#import "SPKPreferences.h"
#import "SPKTopicSettingsSupport.h"

static NSString *const kSPKActionDefaultPickerCellIdentifier = @"SPKActionDefaultPickerCell";

static NSString *SPKActionButtonDefaultActionKeyForSource(SPKActionButtonSource source) {
    return SPKPrefActionButtonDefaultActionKey(SPKActionButtonTopicKeyForSource(source));
}

static NSDictionary<NSString *, NSString *> *SPKProfileLegacyDefaultActionMap(void) {
    return @{
        @"copy_info" : kSPKActionProfileCopyInfo,
        @"view_picture" : kSPKActionExpand,
        @"share_picture" : kSPKActionDownloadShare,
        @"save_picture_gallery" : kSPKActionDownloadGallery,
        @"profile_settings" : kSPKActionOpenTopicSettings
    };
}

NSString *SPKActionButtonDefaultActionIdentifierForSource(SPKActionButtonSource source) {
    NSArray<NSString *> *supportedActions = SPKActionButtonSupportedActionsForSource(source);
    id savedValue = SPKPreferenceObjectForKey(SPKActionButtonDefaultActionKeyForSource(source));
    NSString *saved = [savedValue isKindOfClass:[NSString class]] ? savedValue : nil;
    if (source == SPKActionButtonSourceProfile && saved.length > 0) {
        saved = SPKProfileLegacyDefaultActionMap()[saved] ?: saved;
    }

    if ([saved isEqualToString:kSPKActionNone])
        return kSPKActionNone;
    if ([supportedActions containsObject:saved])
        return saved;
    if (saved.length > 0 || source == SPKActionButtonSourceProfile)
        return kSPKActionNone;
    if ([supportedActions containsObject:kSPKActionDownloadLibrary])
        return kSPKActionDownloadLibrary;
    return supportedActions.firstObject ?: kSPKActionNone;
}

NSString *SPKActionButtonDefaultActionTitleForSource(SPKActionButtonSource source) {
    NSString *identifier = SPKActionButtonDefaultActionIdentifierForSource(source);
    if ([identifier isEqualToString:kSPKActionNone])
        return @"Open Menu";
    return SPKActionDescriptorDisplayTitle(identifier, SPKActionButtonTopicTitleForSource(source));
}

NSString *SPKActionButtonDefaultActionIconNameForSource(SPKActionButtonSource source) {
    NSString *identifier = SPKActionButtonDefaultActionIdentifierForSource(source);
    return [identifier isEqualToString:kSPKActionNone] ? @"action" : SPKActionDescriptorIconName(identifier);
}

// D1: the sections are HIS zones, in his order — the first level, then each
// submenu by its own name. "Open Menu" opens the list on its own, without a
// header, because it is the only choice that does not perform an action.
// D3 follows from the model: an action filed under "Not in the Menu" cannot be
// the tap action, since it is not in the menu at all.
static NSArray<NSDictionary *> *SPKActionButtonDefaultActionSections(SPKActionButtonSource source) {
    NSArray<NSString *> *supportedActions = SPKActionButtonSupportedActionsForSource(source);
    SPKActionButtonConfiguration *configuration =
        [SPKActionButtonConfiguration configurationForSource:source
                                                  topicTitle:SPKActionButtonTopicTitleForSource(source)
                                            supportedActions:supportedActions
                                             defaultSections:SPKActionButtonDefaultSectionsForSource(source)];

    NSMutableArray<NSDictionary *> *sections = [NSMutableArray array];
    [sections addObject:@{@"title" : @"", @"actions" : @[ kSPKActionNone ]}];

    NSMutableArray<SPKActionMenuSection *> *zones = [NSMutableArray array];
    [zones addObject:[configuration topLevelSection]];
    [zones addObjectsFromArray:[configuration submenuSections]];

    for (SPKActionMenuSection *zone in zones) {
        NSMutableArray<NSString *> *actions = [NSMutableArray array];
        for (NSString *identifier in zone.actions) {
            if ([supportedActions containsObject:identifier])
                [actions addObject:identifier];
        }
        if (actions.count == 0)
            continue;
        [sections addObject:@{@"title" : zone.title ?: @"", @"actions" : [actions copy]}];
    }
    return [sections copy];
}

@interface SPKActionButtonDefaultActionPickerViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) SPKActionButtonSource source;
@property (nonatomic, copy) NSArray<NSDictionary *> *sections;

@end

@implementation SPKActionButtonDefaultActionPickerViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithSource:(SPKActionButtonSource)source {
    self = [super init];
    if (self) {
        _source = source;
        _sections = SPKActionButtonDefaultActionSections(source);
        self.title = @"On Tap";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    // No hairline between rows: the bands do the separating, like every other
    // Sparkle screen (SPKSettingsViewController.m:553).
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kSPKActionDefaultPickerCellIdentifier];
    [self.view addSubview:self.tableView];
}

// The 6 pt band the rest of Sparkle puts between groups. #EFEFF1 in hard code:
// SPKColor_InstagramGroupedBackground returns white in this palette.
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 6.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *band = [UIView new];
    band.backgroundColor = [UIColor colorWithRed:0.937 green:0.937 blue:0.945 alpha:1.0];
    return band;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = self.sections[(NSUInteger)section][@"title"];
    if (title.length == 0)
        return nil;

    UIView *header = [UIView new];
    UILabel *label = [UILabel new];
    label.text = title;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    label.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.5],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8.0]
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *title = self.sections[(NSUInteger)section][@"title"];
    return title.length > 0 ? 36.0 : 0.0;
}

// The 44 pt pitch of the rest of the tweak.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.sections = SPKActionButtonDefaultActionSections(self.source);
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"actions"] count];
}

- (NSString *)identifierAtIndexPath:(NSIndexPath *)indexPath {
    return self.sections[indexPath.section][@"actions"][indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSPKActionDefaultPickerCellIdentifier forIndexPath:indexPath];
    UIListContentConfiguration *config = [UIListContentConfiguration cellConfiguration];
    NSString *identifier = [self identifierAtIndexPath:indexPath];
    BOOL isNone = [identifier isEqualToString:kSPKActionNone];

    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    config.textProperties.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:17.0]];
    config.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(9.0, 15.0, 9.0, 16.0);
    config.imageToTextPadding = 14.0;
    config.imageProperties.maximumSize = CGSizeMake(26.0, 26.0);
    config.text = isNone ? @"Open Menu" : SPKActionDescriptorDisplayTitle(identifier, SPKActionButtonTopicTitleForSource(self.source));
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.image = SPKSettingsIcon(isNone ? @"action" : SPKActionDescriptorIconName(identifier));
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];

    // Convention v1.2: the same ink checkmark as the unified menus. The filled
    // blue disc was the only blue selection control left in the tweak.
    if ([identifier isEqualToString:SPKActionButtonDefaultActionIdentifierForSource(self.source)]) {
        UIImageSymbolConfiguration *symbol = [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                              weight:UIImageSymbolWeightSemibold];
        UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"
                                                                               withConfiguration:symbol]];
        checkmarkView.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
        checkmarkView.contentMode = UIViewContentModeScaleAspectFit;
        [checkmarkView sizeToFit];
        cell.accessoryView = checkmarkView;
    } else {
        cell.accessoryView = nil;
    }

    cell.contentConfiguration = config;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [self identifierAtIndexPath:indexPath];
    SPKPreferenceSetObject(identifier, SPKActionButtonDefaultActionKeyForSource(self.source));
    [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
