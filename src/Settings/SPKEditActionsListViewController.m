#import "SPKEditActionsListViewController.h"
#include <UIKit/UIKit.h>

#import "../AssetUtils.h"
#import "../Shared/ActionButton/SPKActionDescriptor.h"
#import "../Shared/UI/SPKMediaChrome.h"
#import "../Utils.h"
#import "SPKActionCatalogViewController.h"
#import "SPKActionSectionEditViewController.h"
#import "SPKBulkActionMenuEditViewController.h"
#import "SPKPreferences.h"
#import "SPKSettingsTransferManager.h"
#import "SPKTopicSettingsSupport.h"

// The rows of the Submenus zone are not homogeneous: a parent row, its actions
// under it, and the row that makes a new one. They are flattened into a single
// table section so a drag can cross from one submenu to another.
typedef NS_ENUM(NSInteger, SPKSubmenuRowKind) {
    SPKSubmenuRowKindParent = 0,
    SPKSubmenuRowKindAction,
    SPKSubmenuRowKindNew
};

static NSString *const kSPKSubmenuRowKindKey = @"kind";
static NSString *const kSPKSubmenuRowSubmenuKey = @"submenu";
static NSString *const kSPKSubmenuRowActionKey = @"action";

@interface SPKEditActionsListViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SPKActionButtonConfiguration *configuration;
@property (nonatomic, assign) SPKActionButtonSource source;
@property (nonatomic, assign) BOOL dragStartedInBulk;

@end

@implementation SPKEditActionsListViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithSource:(SPKActionButtonSource)source topicTitle:(NSString *)topicTitle {
    self = [super init];
    if (self) {
        _source = source;
        _configuration = [SPKActionButtonConfiguration configurationForSource:source
                                                                   topicTitle:topicTitle
                                                             supportedActions:SPKActionButtonSupportedActionsForSource(source)
                                                              defaultSections:SPKActionButtonDefaultSectionsForSource(source)];
        self.title = @"Configure Menu";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];
    SPKMediaChromeSetTrailingTopBarItems(self.navigationItem, @[ SPKMediaChromeTopBarButtonItem(@"plus", self, @selector(catalogTapped)) ]);

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    // No hairline between rows: the bands do the separating, like every other
    // Sparkle screen (SPKSettingsViewController.m:553).
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    // Long press and drag, the way the other two editors in this project do it.
    // NOT tableView.editing: UIKit refuses swipe actions while a table is in
    // editing mode, so the always-visible grips would cost both swipes.
    self.tableView.dragInteractionEnabled = YES;
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - The four zones

- (NSInteger)menuSectionIndex {
    return 0;
}

- (NSInteger)submenusSectionIndex {
    return 1;
}

- (BOOL)hasBulkZone {
    return [self.configuration bulkSection] != nil;
}

- (NSInteger)bulkSectionIndex {
    return [self hasBulkZone] ? 2 : NSNotFound;
}

- (NSInteger)outsideSectionIndex {
    return [self hasBulkZone] ? 3 : 2;
}

- (NSInteger)resetSectionIndex {
    return [self outsideSectionIndex] + 1;
}

// Profile's "Copy Info" opens a list of its own, which is not one of the four
// zones. Its editor rides in the final block rather than disappearing with the
// old "All Menus" section.
- (BOOL)hasCopyInfoEditorRow {
    return self.source == SPKActionButtonSourceProfile;
}

- (NSArray<NSString *> *)menuActions {
    return [[self.configuration topLevelSection].actions copy];
}

- (NSArray<NSString *> *)outsideActions {
    return [self.configuration.unassignedActions copy];
}

// Bulk is his own ordered list now: these rows ARE the carousel menu, in this
// order, one for one.
- (NSArray<NSString *> *)bulkActions {
    return [self.configuration bulkActionsInOrder];
}

- (NSArray<NSDictionary *> *)submenuRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    for (SPKActionMenuSection *submenu in [self.configuration submenuSections]) {
        [rows addObject:@{kSPKSubmenuRowKindKey : @(SPKSubmenuRowKindParent),
                          kSPKSubmenuRowSubmenuKey : submenu.identifier}];
        for (NSString *identifier in submenu.actions) {
            [rows addObject:@{kSPKSubmenuRowKindKey : @(SPKSubmenuRowKindAction),
                              kSPKSubmenuRowSubmenuKey : submenu.identifier,
                              kSPKSubmenuRowActionKey : identifier}];
        }
    }
    [rows addObject:@{kSPKSubmenuRowKindKey : @(SPKSubmenuRowKindNew)}];
    return rows;
}

- (NSDictionary *)submenuRowAtIndex:(NSInteger)index {
    NSArray<NSDictionary *> *rows = [self submenuRows];
    if (index < 0 || index >= (NSInteger)rows.count)
        return @{};
    return rows[(NSUInteger)index];
}

#pragma mark - Table shape

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self resetSectionIndex] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == [self menuSectionIndex])
        return MAX(1, (NSInteger)[self menuActions].count);   // a hint row when empty
    if (section == [self submenusSectionIndex])
        return (NSInteger)[self submenuRows].count;
    if (section == [self bulkSectionIndex])
        return MAX(1, (NSInteger)[self bulkActions].count);
    if (section == [self outsideSectionIndex])
        return MAX(1, (NSInteger)[self outsideActions].count);
    return [self hasCopyInfoEditorRow] ? 2 : 1;   // resetSectionIndex
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == [self menuSectionIndex])
        return @"Menu";
    if (section == [self submenusSectionIndex])
        return @"Submenus";
    if (section == [self bulkSectionIndex])
        return @"Bulk";
    if (section == [self outsideSectionIndex])
        return @"Not in the Menu";
    return nil;
}

// The count sits at the right of the header, like the mock: "Menu 3".
- (NSString *)countTextForSection:(NSInteger)section {
    NSUInteger count = 0;
    if (section == [self menuSectionIndex])
        count = [self menuActions].count;
    else if (section == [self bulkSectionIndex])
        count = [self bulkActions].count;
    else if (section == [self outsideSectionIndex])
        count = [self outsideActions].count;
    else
        return nil;
    return count > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)count] : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if (title.length == 0)
        return nil;

    UIView *header = [UIView new];
    UILabel *label = [UILabel new];
    label.text = title;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    label.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:label];

    UILabel *count = [UILabel new];
    count.text = [self countTextForSection:section];
    count.font = [UIFont systemFontOfSize:14.0];
    count.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    count.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:count];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.5],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8.0],
        [count.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [count.centerYAnchor constraintEqualToAnchor:label.centerYAnchor]
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    return title.length > 0 ? 36.0 : 0.0;
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

// The 44 pt pitch of the rest of the tweak.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

#pragma mark - Rows

- (UIListContentConfiguration *)baseContentConfiguration {
    UIListContentConfiguration *config = [UIListContentConfiguration cellConfiguration];
    config.textProperties.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:17.0]];
    config.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(9.0, 15.0, 9.0, 16.0);
    config.imageToTextPadding = 14.0;
    config.imageProperties.maximumSize = CGSizeMake(26.0, 26.0);
    return config;
}

- (UITableViewCell *)hintCellWithText:(NSString *)text {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UIListContentConfiguration *config = [self baseContentConfiguration];
    config.text = text;
    config.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
    cell.contentConfiguration = config;
    return cell;
}

// The trailing label of a submenu's parent row: the count, then the chevron —
// except at one action, where the runtime hands the action straight to the first
// level (SPKSubmenuOrSingleElement) and the row says so.
- (UIView *)parentAccessoryViewForSubmenu:(SPKActionMenuSection *)submenu {
    NSUInteger count = submenu.actions.count;
    NSString *text = count == 1 ? @"1 · direct" : [NSString stringWithFormat:@"%lu", (unsigned long)count];

    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:14.0];
    label.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    [label sizeToFit];

    UIImageSymbolConfiguration *symbol = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                          weight:UIImageSymbolWeightSemibold];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"
                                                                     withConfiguration:symbol]];
    chevron.tintColor = [SPKUtils SPKColor_InstagramTertiaryText];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [chevron sizeToFit];

    CGFloat gap = 6.0;
    CGFloat labelWidth = CGRectGetWidth(label.frame);
    CGFloat labelHeight = CGRectGetHeight(label.frame);
    CGFloat chevronWidth = CGRectGetWidth(chevron.frame);
    CGFloat chevronHeight = CGRectGetHeight(chevron.frame);
    CGFloat height = MAX(labelHeight, chevronHeight);

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, labelWidth + gap + chevronWidth, height)];
    label.frame = CGRectMake(0.0, (height - labelHeight) / 2.0, labelWidth, labelHeight);
    chevron.frame = CGRectMake(labelWidth + gap, (height - chevronHeight) / 2.0, chevronWidth, chevronHeight);
    [container addSubview:label];
    [container addSubview:chevron];
    return container;
}

- (UITableViewCell *)actionCellForIdentifier:(NSString *)identifier
                                    indented:(BOOL)indented
                                      dimmed:(BOOL)dimmed {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];

    UIListContentConfiguration *config = [self baseContentConfiguration];
    if (indented)
        config.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(9.0, 35.0, 9.0, 16.0);
    config.text = SPKActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
    config.image = SPKSettingsIcon(SPKActionDescriptorIconName(identifier));
    config.textProperties.color = dimmed ? [SPKUtils SPKColor_InstagramSecondaryText]
                                         : [SPKUtils SPKColor_InstagramPrimaryText];
    config.imageProperties.tintColor = config.textProperties.color;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.showsReorderControl = YES;
    cell.contentConfiguration = config;
    return cell;
}

- (UITableViewCell *)submenuParentCellForIdentifier:(NSString *)submenuIdentifier {
    SPKActionMenuSection *submenu = [self.configuration sectionWithIdentifier:submenuIdentifier];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];

    UIListContentConfiguration *config = [self baseContentConfiguration];
    config.text = submenu.title;
    config.image = SPKSettingsIcon(submenu.iconName);
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    cell.accessoryView = [self parentAccessoryViewForSubmenu:submenu];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.showsReorderControl = YES;
    cell.contentConfiguration = config;
    return cell;
}

- (UITableViewCell *)newSubmenuCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    UIListContentConfiguration *config = [self baseContentConfiguration];
    config.text = @"New Submenu";
    config.image = SPKSettingsIcon(@"plus");
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.contentConfiguration = config;
    return cell;
}

- (UITableViewCell *)copyInfoEditorCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    UIListContentConfiguration *config = [self baseContentConfiguration];
    config.text = @"Configure Copy Info Menu";
    config.image = SPKSettingsIcon(@"stack");
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.contentConfiguration = config;
    return cell;
}

- (UITableViewCell *)resetCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    UIListContentConfiguration *config = [self baseContentConfiguration];
    config.text = @"Reset to Default";
    config.textProperties.color = [SPKUtils SPKColor_InstagramDestructive];
    config.image = SPKSettingsIcon(@"arrow_ccw");
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramDestructive];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.contentConfiguration = config;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;

    if (section == [self menuSectionIndex]) {
        NSArray<NSString *> *actions = [self menuActions];
        if (actions.count == 0)
            return [self hintCellWithText:@"Drag an action here for the first level."];
        return [self actionCellForIdentifier:actions[(NSUInteger)indexPath.row] indented:NO dimmed:NO];
    }

    if (section == [self submenusSectionIndex]) {
        NSDictionary *row = [self submenuRowAtIndex:indexPath.row];
        SPKSubmenuRowKind kind = (SPKSubmenuRowKind)[row[kSPKSubmenuRowKindKey] integerValue];
        if (kind == SPKSubmenuRowKindNew)
            return [self newSubmenuCell];
        if (kind == SPKSubmenuRowKindAction)
            return [self actionCellForIdentifier:row[kSPKSubmenuRowActionKey] indented:YES dimmed:NO];
        return [self submenuParentCellForIdentifier:row[kSPKSubmenuRowSubmenuKey]];
    }

    if (section == [self bulkSectionIndex]) {
        NSArray<NSString *> *actions = [self bulkActions];
        if (actions.count == 0)
            return [self hintCellWithText:@"Follows your Download and Copy actions."];
        return [self actionCellForIdentifier:actions[(NSUInteger)indexPath.row] indented:NO dimmed:NO];
    }

    if (section == [self outsideSectionIndex]) {
        NSArray<NSString *> *actions = [self outsideActions];
        if (actions.count == 0)
            return [self hintCellWithText:@"Nothing set aside."];
        // Full ink: these rows are draggable and swipe back into the menu. Grey
        // read as "disabled", which they are not — only Bulk is.
        return [self actionCellForIdentifier:actions[(NSUInteger)indexPath.row] indented:NO dimmed:NO];
    }

    if ([self hasCopyInfoEditorRow] && indexPath.row == 0)
        return [self copyInfoEditorCell];
    return [self resetCell];
}

#pragma mark - Moving an action

// One place where an action changes hands. A nil section identifier files it
// under "Not in the Menu"; an index of NSNotFound appends.
- (void)moveAction:(NSString *)identifier
    toSectionIdentifier:(NSString *)sectionIdentifier
                atIndex:(NSInteger)index {
    [self.configuration setAction:identifier assignedToSectionIdentifier:sectionIdentifier];

    if (sectionIdentifier.length > 0 && index != NSNotFound) {
        SPKActionMenuSection *section = [self.configuration sectionWithIdentifier:sectionIdentifier];
        NSUInteger current = [section.actions indexOfObject:identifier];
        if (current != NSNotFound) {
            NSInteger clamped = MIN(MAX(0, index), MAX(0, (NSInteger)section.actions.count - 1));
            [self.configuration moveActionInSectionIdentifier:sectionIdentifier
                                                    fromIndex:(NSInteger)current
                                                      toIndex:clamped];
        }
    }

    [self.configuration save];
    [self.tableView reloadData];
}

#pragma mark - Taps

// The parent row of a submenu is the only tap on this screen; the actions
// answer to the swipes and the grip alone.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == [self resetSectionIndex]) {
        if ([self hasCopyInfoEditorRow] && indexPath.row == 0)
            [self copyInfoEditorTapped];
        else
            [self resetConfigurationTapped];
        return;
    }
    if (indexPath.section != [self submenusSectionIndex])
        return;

    NSDictionary *row = [self submenuRowAtIndex:indexPath.row];
    SPKSubmenuRowKind kind = (SPKSubmenuRowKind)[row[kSPKSubmenuRowKindKey] integerValue];
    if (kind == SPKSubmenuRowKindNew) {
        [self newSubmenuTapped];
        return;
    }
    if (kind == SPKSubmenuRowKindParent)
        [self editSubmenuWithIdentifier:row[kSPKSubmenuRowSubmenuKey]];
}

- (void)editSubmenuWithIdentifier:(NSString *)submenuIdentifier {
    __weak typeof(self) weakSelf = self;
    SPKActionSectionEditViewController *editor =
        [[SPKActionSectionEditViewController alloc] initWithConfiguration:self.configuration
                                                       sectionIdentifier:submenuIdentifier
                                                                onChange:^{
        [weakSelf.tableView reloadData];
    }];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)newSubmenuTapped {
    SPKActionMenuSection *submenu = [self.configuration addSubmenu];
    [self.configuration save];
    [self.tableView reloadData];
    [self editSubmenuWithIdentifier:submenu.identifier];
}

- (void)copyInfoEditorTapped {
    SPKBulkActionMenuEditViewController *editor =
        [[SPKBulkActionMenuEditViewController alloc] initWithTitle:@"Copy Info Menu"
                                                            source:self.source
                                                  supportedActions:SPKProfileCopyInfoSupportedActions()
                                                 configuredActions:SPKProfileConfiguredCopyInfoActions()
                                                            onSave:^(NSArray<NSString *> *actions) {
        SPKProfileSetConfiguredCopyInfoActions(actions);
    }];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)catalogTapped {
    __weak typeof(self) weakSelf = self;
    SPKActionCatalogViewController *catalog =
        [[SPKActionCatalogViewController alloc] initWithConfiguration:self.configuration
                                                            onChange:^{
        [weakSelf.tableView reloadData];
    }];
    [self.navigationController pushViewController:catalog animated:YES];
}

#pragma mark - The two swipes

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self identifierForSwipeAtIndexPath:indexPath] != nil;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Editing mode is on for the grips; without this every row would also grow a
    // red delete badge on its left.
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

// The action a swipe would act on, or nil where no swipe applies: Bulk is
// derived, and the hint rows, parent rows and New Submenu hold no action.
- (NSString *)identifierForSwipeAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == [self bulkSectionIndex]) {
        NSArray<NSString *> *actions = [self bulkActions];
        return indexPath.row < (NSInteger)actions.count ? actions[(NSUInteger)indexPath.row] : nil;
    }
    if (indexPath.section == [self menuSectionIndex]) {
        NSArray<NSString *> *actions = [self menuActions];
        return indexPath.row < (NSInteger)actions.count ? actions[(NSUInteger)indexPath.row] : nil;
    }
    if (indexPath.section == [self submenusSectionIndex]) {
        NSDictionary *row = [self submenuRowAtIndex:indexPath.row];
        SPKSubmenuRowKind kind = (SPKSubmenuRowKind)[row[kSPKSubmenuRowKindKey] integerValue];
        return kind == SPKSubmenuRowKindAction ? row[kSPKSubmenuRowActionKey] : nil;
    }
    if (indexPath.section == [self outsideSectionIndex]) {
        NSArray<NSString *> *actions = [self outsideActions];
        return indexPath.row < (NSInteger)actions.count ? actions[(NSUInteger)indexPath.row] : nil;
    }
    return nil;
}

// Swipe left, in the menu: Remove — the action drops to "Not in the Menu".
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [self identifierForSwipeAtIndexPath:indexPath];
    if (!identifier)
        return nil;

    BOOL fromBulk = (indexPath.section == [self bulkSectionIndex]);
    BOOL fromOutside = (indexPath.section == [self outsideSectionIndex]);
    __weak typeof(self) weakSelf = self;

    UIContextualAction *remove =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:@"Remove"
                                              handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
        typeof(self) strongSelf = weakSelf;
        if (fromBulk) {
            // Out of his Bulk list, back into the catalogue behind the "+".
            [strongSelf.configuration setBulkActionIdentifier:identifier included:NO];
            [strongSelf.configuration save];
            [strongSelf.tableView reloadData];
        } else if (fromOutside) {
            // Off the screen entirely, back into the catalogue behind the "+".
            [strongSelf.configuration.unassignedActions removeObject:identifier];
            [strongSelf.configuration save];
            [strongSelf.tableView reloadData];
        } else {
            [strongSelf moveAction:identifier toSectionIdentifier:nil atIndex:NSNotFound];
        }
        done(YES);
    }];
    remove.image = SPKSettingsIcon(@"arrow_right");
    return [UISwipeActionsConfiguration configurationWithActions:@[ remove ]];
}

// Swipe right, out of the menu: Add — the action goes back to the first level,
// at the end of the list.
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != [self outsideSectionIndex])
        return nil;
    NSString *identifier = [self identifierForSwipeAtIndexPath:indexPath];
    if (!identifier)
        return nil;

    __weak typeof(self) weakSelf = self;
    UIContextualAction *add =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:@"Add"
                                              handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf moveAction:identifier
            toSectionIdentifier:[strongSelf.configuration topLevelSection].identifier
                        atIndex:NSNotFound];
        done(YES);
    }];
    add.image = SPKSettingsIcon(@"arrow_left");
    add.backgroundColor = [SPKUtils SPKColor_InstagramPrimaryText];
    return [UISwipeActionsConfiguration configurationWithActions:@[ add ]];
}

#pragma mark - Dragging

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == [self menuSectionIndex])
        return [self menuActions].count > 0;
    if (indexPath.section == [self submenusSectionIndex]) {
        NSDictionary *row = [self submenuRowAtIndex:indexPath.row];
        SPKSubmenuRowKind kind = (SPKSubmenuRowKind)[row[kSPKSubmenuRowKindKey] integerValue];
        return kind != SPKSubmenuRowKindNew;
    }
    if (indexPath.section == [self outsideSectionIndex])
        return [self outsideActions].count > 0;
    if (indexPath.section == [self bulkSectionIndex])
        return [self bulkActions].count > 0;
    return NO;   // the final block does not move
}

- (BOOL)rowIsSubmenuParentAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != [self submenusSectionIndex])
        return NO;
    NSDictionary *row = [self submenuRowAtIndex:indexPath.row];
    return [row[kSPKSubmenuRowKindKey] integerValue] == SPKSubmenuRowKindParent;
}

// Keeps a drag inside the three zones that hold actions, and a submenu's parent
// row inside its own zone.
- (NSIndexPath *)tableView:(UITableView *)tableView
    targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
                         toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if ([self rowIsSubmenuParentAtIndexPath:sourceIndexPath]) {
        if (proposedDestinationIndexPath.section != [self submenusSectionIndex])
            return sourceIndexPath;
        return proposedDestinationIndexPath;
    }

    NSInteger destination = proposedDestinationIndexPath.section;
    if (destination == [self resetSectionIndex])
        return sourceIndexPath;
    // Bulk actions and single-item actions are different identifiers: a row can
    // be reordered inside Bulk, never dragged in or out of it.
    if ((destination == [self bulkSectionIndex]) != (sourceIndexPath.section == [self bulkSectionIndex]))
        return sourceIndexPath;
    // The "New Submenu" row closes the zone: an action dropped on it belongs to
    // the last submenu, not after the row.
    if (destination == [self submenusSectionIndex]) {
        NSInteger lastRow = MAX(0, (NSInteger)[self submenuRows].count - 1);
        if (proposedDestinationIndexPath.row >= lastRow)
            return [NSIndexPath indexPathForRow:lastRow inSection:destination];
    }
    return proposedDestinationIndexPath;
}

// A submenu travelling with its actions: the zone reorders, the first level and
// bulk stay where they are.
- (void)moveSubmenuFromRow:(NSDictionary *)sourceRow toDestinationRow:(NSInteger)destinationRow {
    NSArray<NSDictionary *> *rows = [self submenuRows];
    NSString *submenuIdentifier = sourceRow[kSPKSubmenuRowSubmenuKey];
    NSArray<SPKActionMenuSection *> *submenus = [self.configuration submenuSections];

    NSInteger from = NSNotFound;
    for (NSUInteger index = 0; index < submenus.count; index++) {
        if ([submenus[index].identifier isEqualToString:submenuIdentifier]) {
            from = (NSInteger)index;
            break;
        }
    }

    NSInteger to = 0;
    for (NSInteger index = 0; index < destinationRow && index < (NSInteger)rows.count; index++) {
        NSDictionary *row = rows[(NSUInteger)index];
        if ([row[kSPKSubmenuRowKindKey] integerValue] != SPKSubmenuRowKindParent)
            continue;
        if ([row[kSPKSubmenuRowSubmenuKey] isEqualToString:submenuIdentifier])
            continue;
        to++;
    }

    if (from != NSNotFound)
        [self.configuration moveSubmenuFromIndex:from toIndex:to];
    [self.configuration save];
    [self.tableView reloadData];
}

// Inside the Submenus zone the target is the submenu whose parent row sits above
// the drop, and the position is the number of its actions passed on the way down.
- (void)dropAction:(NSString *)identifier intoSubmenusZoneAtRow:(NSInteger)destinationRow {
    NSArray<NSDictionary *> *rows = [self submenuRows];
    NSString *targetSubmenu = nil;
    NSInteger positionInSubmenu = 0;

    for (NSInteger index = 0; index < destinationRow && index < (NSInteger)rows.count; index++) {
        NSDictionary *row = rows[(NSUInteger)index];
        SPKSubmenuRowKind kind = (SPKSubmenuRowKind)[row[kSPKSubmenuRowKindKey] integerValue];
        if (kind == SPKSubmenuRowKindParent) {
            targetSubmenu = row[kSPKSubmenuRowSubmenuKey];
            positionInSubmenu = 0;
        } else if (kind == SPKSubmenuRowKindAction) {
            if (![row[kSPKSubmenuRowActionKey] isEqualToString:identifier])
                positionInSubmenu++;
        }
    }

    if (!targetSubmenu) {
        // Dropped above the first parent row: there is no submenu to land in.
        [self.tableView reloadData];
        return;
    }
    [self moveAction:identifier toSectionIdentifier:targetSubmenu atIndex:positionInSubmenu];
}

#pragma mark - Drag and drop

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView
        itemsForBeginningDragSession:(id<UIDragSession>)session
                         atIndexPath:(NSIndexPath *)indexPath {
    if (![self tableView:tableView canMoveRowAtIndexPath:indexPath])
        return @[];
    self.dragStartedInBulk = (indexPath.section == [self bulkSectionIndex]);
    NSString *carried = [self identifierForSwipeAtIndexPath:indexPath] ?: @"submenu";
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:carried]];
    item.localObject = carried;
    return @[ item ];
}

- (BOOL)tableView:(UITableView *)tableView dragSessionAllowsMoveOperation:(id<UIDragSession>)session {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session {
    return YES;
}

// True while the zone is empty and showing its hint line instead of actions.
- (BOOL)sectionShowsHintRow:(NSInteger)section {
    if (section == [self menuSectionIndex])
        return [self menuActions].count == 0;
    if (section == [self outsideSectionIndex])
        return [self outsideActions].count == 0;
    if (section == [self bulkSectionIndex])
        return [self bulkActions].count == 0;
    return NO;
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView
                  dropSessionDidUpdate:(id<UIDropSession>)session
              withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession == nil || destinationIndexPath == nil)
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    NSInteger destination = destinationIndexPath.section;
    if (destination == [self resetSectionIndex])
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    if ((destination == [self bulkSectionIndex]) != (session.localDragSession != nil && [self dragStartedInBulk]))
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    // An empty zone holds one hint row, and it will still hold one row once the
    // action lands — the count does not grow. Promising UIKit an insertion it
    // will not find is what crashed Instagram on a drop into an empty Menu.
    if ([self sectionShowsHintRow:destination])
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove
                                                              intent:UITableViewDropIntentUnspecified];
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove
                                                          intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    id<UITableViewDropItem> dropItem = coordinator.items.firstObject;
    NSIndexPath *source = dropItem.sourceIndexPath;
    NSIndexPath *destination = coordinator.destinationIndexPath;
    if (!source || !destination)
        return;
    // Reloading inside the coordinator puts the table's bookkeeping and the drop
    // animation on the same runloop turn. Let the session close first.
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        [strongSelf tableView:strongSelf.tableView moveRowAtIndexPath:source toIndexPath:destination];
    });
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if ([self rowIsSubmenuParentAtIndexPath:sourceIndexPath]) {
        [self moveSubmenuFromRow:[self submenuRowAtIndex:sourceIndexPath.row]
                toDestinationRow:destinationIndexPath.row];
        return;
    }

    NSString *identifier = [self identifierForSwipeAtIndexPath:sourceIndexPath];
    if (!identifier) {
        [self.tableView reloadData];
        return;
    }

    NSInteger destination = destinationIndexPath.section;
    if (destination == [self bulkSectionIndex] && sourceIndexPath.section == [self bulkSectionIndex]) {
        [self.configuration moveBulkActionFromIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
        [self.configuration save];
        [self.tableView reloadData];
        return;
    }
    if (destination == [self menuSectionIndex]) {
        [self moveAction:identifier
            toSectionIdentifier:[self.configuration topLevelSection].identifier
                        atIndex:destinationIndexPath.row];
        return;
    }
    if (destination == [self outsideSectionIndex]) {
        [self moveAction:identifier toSectionIdentifier:nil atIndex:NSNotFound];
        return;
    }
    if (destination == [self submenusSectionIndex]) {
        [self dropAction:identifier intoSubmenusZoneAtRow:destinationIndexPath.row];
        return;
    }
    [self.tableView reloadData];
}

#pragma mark - Reset

- (NSArray<NSString *> *)configurationResetKeys {
    NSString *topic = SPKActionButtonTopicKeyForSource(self.source);
    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithArray:@[
        SPKPrefActionButtonConfigKey(topic),
        SPKPrefActionButtonDefaultActionKey(topic),
        SPKPrefActionButtonBulkDownloadKey(topic),
        SPKPrefActionButtonBulkCopyKey(topic)
    ]];
    // The profile Copy Info submenu and its default copy action are edited from this
    // surface too, so fold them into the profile reset.
    if (self.source == SPKActionButtonSourceProfile) {
        [keys addObject:@"profile_action_btn_copy_info_submenu_actions"];
        [keys addObject:@"profile_action_btn_default_copy_info_action"];
    }
    return keys;
}

- (void)resetConfigurationTapped {
    __weak typeof(self) weakSelf = self;
    [[SPKSettingsTransferManager sharedManager]
        resetConfigurationGroupFromController:self
                                        title:@"Reset to Default"
                                      message:@"This restores this surface's menu, submenus, tap action, and bulk menu to their defaults. The action button stays enabled and other surfaces are unaffected."
                                 confirmTitle:@"Reset"
                                         keys:[self configurationResetKeys]
                                      onReset:^{
                                          typeof(self) strongSelf = weakSelf;
                                          if (!strongSelf)
                                              return;
                                          strongSelf.configuration = [SPKActionButtonConfiguration configurationForSource:strongSelf.source
                                                                                                               topicTitle:strongSelf.configuration.topicTitle
                                                                                                         supportedActions:SPKActionButtonSupportedActionsForSource(strongSelf.source)
                                                                                                          defaultSections:SPKActionButtonDefaultSectionsForSource(strongSelf.source)];
                                          [strongSelf.tableView reloadData];
                                      }];
}

@end
