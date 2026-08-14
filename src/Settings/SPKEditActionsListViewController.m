#import "SPKEditActionsListViewController.h"
#import "SPKToggleMenu.h"
#include <UIKit/UIKit.h>

#import "../AssetUtils.h"
#import "../Shared/ActionButton/SPKActionDescriptor.h"
#import "../Shared/UI/SPKMediaChrome.h"
#import "../Utils.h"
#import "SPKActionSectionEditViewController.h"
#import "SPKBulkActionMenuEditViewController.h"
#import "SPKPreferences.h"
#import "SPKSettingsTransferManager.h"
#import "SPKTopicSettingsSupport.h"


@interface SPKEditActionsListViewController () <UITableViewDataSource, UITableViewDelegate>
// Where each action came from, so "Add" can put it back without asking.
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *lastGroupForAction;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SPKActionButtonConfiguration *configuration;
@property (nonatomic, assign) SPKActionButtonSource source;

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
        self.title = @"Configure Actions";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.lastGroupForAction = [NSMutableDictionary dictionary];
    // Always in editing mode so the reorder grip is there without a long press
    // first — the swipes keep working alongside it.
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];
    SPKMediaChromeSetTrailingTopBarItems(self.navigationItem, @[ SPKMediaChromeTopBarButtonItem(@"plus", self, @selector(addSectionTapped)) ]);
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    // No hairline between rows: the bands do the separating, like every other
    // Sparkle screen (SPKSettingsViewController.m:553).
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    self.tableView.tintColor = [SPKUtils SPKColor_InstagramBlue];
    [self.view addSubview:self.tableView];
}

- (NSArray<NSString *> *)bulkEditorKinds {
    // Download All / Copy All are derived from the single-item action config and
    // are no longer separately configurable. Only the profile Copy Info submenu
    // remains editable here.
    NSMutableArray<NSString *> *kinds = [NSMutableArray array];
    if (self.source == SPKActionButtonSourceProfile) {
        [kinds addObject:@"copy_info"];
    }
    return kinds;
}

- (BOOL)hasBulkEditorSection {
    return [self bulkEditorKinds].count > 0;
}

// CA1: what exists comes before how it is grouped. Section 0 is the action
// list, section 1 the menu groups, then the optional bulk editor and reset.
// The screen mirrors the menu: one table section per group, in the user's order,
// then everything that is not in the menu. An action has a single state now —
// filed in a group, or not — so the disabled set is kept in step with the
// assignment instead of living its own life.
- (NSArray<SPKActionMenuSection *> *)groups {
    return self.configuration.sections;
}

- (NSArray<NSString *> *)actionsInGroupAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.groups.count)
        return @[];
    return self.groups[index].actions;
}

// Supported, but filed nowhere: the single "not in the menu" bucket.
- (NSArray<NSString *> *)actionsOutsideMenu {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (NSString *identifier in self.configuration.supportedActions) {
        if (![self.configuration sectionIdentifierForAction:identifier])
            [out addObject:identifier];
    }
    return out;
}

- (NSInteger)outsideSectionIndex {
    return (NSInteger)self.groups.count;
}

- (NSInteger)bulkEditorSectionIndex {
    return [self hasBulkEditorSection] ? [self outsideSectionIndex] + 1 : NSNotFound;
}

- (NSInteger)availableSectionIndex {
    return [self hasBulkEditorSection] ? 3 : 2;
}

- (NSInteger)resetSectionIndex {
    return [self outsideSectionIndex] + ([self hasBulkEditorSection] ? 2 : 1);
}

- (NSString *)bulkEditorKindForRow:(NSInteger)row {
    NSArray<NSString *> *kinds = [self bulkEditorKinds];
    if (row < 0 || row >= (NSInteger)kinds.count) {
        return nil;
    }
    return kinds[row];
}

- (NSString *)bulkEditorTitleForKind:(NSString *)kind {
    if ([kind isEqualToString:@"copy_info"]) {
        return @"Configure Copy Info Menu";
    }
    return @"Configure Menu";
}

- (NSString *)bulkEditorSubtitleForKind:(NSString *)kind {
    (void)kind;
    return nil;
}

- (SPKBulkActionMenuEditViewController *)bulkEditorControllerForKind:(NSString *)kind {
    if ([kind isEqualToString:@"copy_info"]) {
        return [[SPKBulkActionMenuEditViewController alloc] initWithTitle:@"Copy Info Menu"
                                                                   source:self.source
                                                         supportedActions:SPKProfileCopyInfoSupportedActions()
                                                        configuredActions:SPKProfileConfiguredCopyInfoActions()
                                                                   onSave:^(NSArray<NSString *> *actions) {
                                                                       SPKProfileSetConfiguredCopyInfoActions(actions);
                                                                   }];
    }

    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self resetSectionIndex] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < (NSInteger)self.groups.count)
        return [self actionsInGroupAtIndex:section].count;
    if (section == [self outsideSectionIndex])
        return [self actionsOutsideMenu].count;
    if (section == [self bulkEditorSectionIndex])
        return [self bulkEditorKinds].count;
    return 1;   // resetSectionIndex
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < (NSInteger)self.groups.count)
        return self.groups[section].title;
    if (section == [self outsideSectionIndex])
        return @"Not in the Menu";
    if (section == [self bulkEditorSectionIndex])
        return @"All Menus";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    // The band view below covers these, so they are kept short and factual for
    // the day this controller grows an ⓘ of its own.
    if (section == [self outsideSectionIndex])
        return @"These actions are supported but do not appear in the menu. Swipe right to put one back.";
    if (section == [self resetSectionIndex])
        return @"Restores this surface's menu groups, tap action, and bulk menus to their defaults. Other surfaces are unaffected.";
    return nil;
}

// YES when the section still holds an action whose enable switch is off — that action
// stays assigned but is hidden from the runtime menu, so we flag the section row.

// The 44 pt pitch of the rest of the tweak.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    UIListContentConfiguration *config = [UIListContentConfiguration cellConfiguration];
    config.textProperties.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:17.0]];
    config.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(9.0, 15.0, 9.0, 16.0);
    config.imageToTextPadding = 14.0;
    config.imageProperties.maximumSize = CGSizeMake(26.0, 26.0);

    if (indexPath.section == [self resetSectionIndex]) {
        config.text = @"Reset to Default";
        config.textProperties.color = [SPKUtils SPKColor_InstagramDestructive];
        config.image = SPKSettingsIcon(@"arrow_ccw");
        config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramDestructive];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.contentConfiguration = config;
        return cell;
    }

    if (indexPath.section == [self bulkEditorSectionIndex]) {
        NSString *kind = [self bulkEditorKindForRow:indexPath.row];
        config.text = [self bulkEditorTitleForKind:kind];
        config.secondaryText = [self bulkEditorSubtitleForKind:kind];
        config.image = SPKSettingsIcon(@"stack");
        config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.contentConfiguration = config;
        return cell;
    }

    BOOL outsideMenu = (indexPath.section == [self outsideSectionIndex]);
    NSArray<NSString *> *rows = outsideMenu ? [self actionsOutsideMenu]
                                            : [self actionsInGroupAtIndex:indexPath.section];
    if (indexPath.row >= (NSInteger)rows.count)
        return cell;

    NSString *identifier = rows[indexPath.row];
    config.text = SPKActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
    config.image = SPKSettingsIcon(SPKActionDescriptorIconName(identifier));
    // Outside the menu, the row is dimmed rather than switched off: there is no
    // switch left to explain, only a place.
    config.textProperties.color = outsideMenu ? [SPKUtils SPKColor_InstagramSecondaryText]
                                              : [SPKUtils SPKColor_InstagramPrimaryText];
    config.imageProperties.tintColor = config.textProperties.color;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.showsReorderControl = YES;
    cell.contentConfiguration = config;
    return cell;
}

// One place where an action changes hands. The disabled set is kept in step so
// the runtime menu, which still reads it, agrees with what this screen shows.
- (void)moveAction:(NSString *)identifier toSectionIdentifier:(NSString *)sectionIdentifier {
    NSString *previous = [self.configuration sectionIdentifierForAction:identifier];
    if (previous)
        self.lastGroupForAction[identifier] = previous;

    [self.configuration setAction:identifier assignedToSectionIdentifier:sectionIdentifier];
    if (sectionIdentifier)
        [self.configuration.disabledActions removeObject:identifier];
    else if (![self.configuration.disabledActions containsObject:identifier])
        [self.configuration.disabledActions addObject:identifier];

    [self.configuration normalize];
    [self.configuration save];
    [self.tableView reloadData];
}

// The picker Sparkle uses everywhere else: the groups, then the way out.
- (void)presentGroupPickerForAction:(NSString *)identifier fromView:(UIView *)view {
    NSString *current = [self.configuration sectionIdentifierForAction:identifier];
    NSMutableArray<SPKToggleMenuItem *> *items = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    // The picker reads its checkmark from a defaults key, so the current group
    // is written to a scratch key that only exists for the duration of the menu.
    NSString *scratchKey = @"actionbtn_group_pick_scratch";
    SPKPreferenceSetObject(current ?: @"", scratchKey);

    for (SPKActionMenuSection *group in self.groups) {
        NSString *groupIdentifier = group.identifier;
        SPKToggleMenuItem *item = [SPKToggleMenuItem itemWithTitle:group.title
                                                          iconName:group.iconName
                                                       defaultsKey:scratchKey];
        item.pickValue = groupIdentifier;
        item.pickHandler = ^{
            [weakSelf moveAction:identifier toSectionIdentifier:groupIdentifier];
        };
        [items addObject:item];
    }

    SPKToggleMenuItem *none = [SPKToggleMenuItem itemWithTitle:@"Not in the Menu"
                                                      iconName:@""
                                                   defaultsKey:scratchKey];
    none.pickValue = @"";
    none.pickHandler = ^{
        [weakSelf moveAction:identifier toSectionIdentifier:nil];
    };
    [items addObject:none];

    [SPKToggleMenu presentWithChoices:items
                             fromView:view
                     inViewController:self
                            onDismiss:nil];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section <= [self outsideSectionIndex];
}

// Dragging is kept for both jobs: order inside a group, and moving between
// groups — including in and out of "Not in the Menu".
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.section > [self outsideSectionIndex] ||
        destinationIndexPath.section > [self outsideSectionIndex])
        return;

    BOOL fromOutside = (sourceIndexPath.section == [self outsideSectionIndex]);
    NSArray<NSString *> *sourceRows = fromOutside ? [self actionsOutsideMenu]
                                                  : [self actionsInGroupAtIndex:sourceIndexPath.section];
    if (sourceIndexPath.row >= (NSInteger)sourceRows.count)
        return;
    NSString *identifier = sourceRows[sourceIndexPath.row];

    if (sourceIndexPath.section == destinationIndexPath.section) {
        if (fromOutside)
            return;   // the out-of-menu bucket has no order of its own
        SPKActionMenuSection *group = self.groups[sourceIndexPath.section];
        [self.configuration moveActionInSectionIdentifier:group.identifier
                                                fromIndex:sourceIndexPath.row
                                                  toIndex:destinationIndexPath.row];
        [self.configuration save];
        [self.tableView reloadData];
        return;
    }

    BOOL toOutside = (destinationIndexPath.section == [self outsideSectionIndex]);
    [self moveAction:identifier
 toSectionIdentifier:toOutside ? nil : self.groups[destinationIndexPath.section].identifier];
}






- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == [self resetSectionIndex]) {
        [self resetConfigurationTapped];
        return;
    }
    if (indexPath.section == [self bulkEditorSectionIndex]) {
        NSString *kind = [self bulkEditorKindForRow:indexPath.row];
        [self.navigationController pushViewController:[self bulkEditorControllerForKind:kind] animated:YES];
        return;
    }

    BOOL outsideMenu = (indexPath.section == [self outsideSectionIndex]);
    NSArray<NSString *> *rows = outsideMenu ? [self actionsOutsideMenu]
                                            : [self actionsInGroupAtIndex:indexPath.section];
    if (indexPath.row >= (NSInteger)rows.count)
        return;
    [self presentGroupPickerForAction:rows[indexPath.row]
                             fromView:[tableView cellForRowAtIndexPath:indexPath] ?: tableView];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section < (NSInteger)self.groups.count;
}

- (void)removeSectionAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0 || indexPath.row >= (NSInteger)self.configuration.sections.count)
        return;

    SPKActionMenuSection *section = self.configuration.sections[indexPath.row];
    for (NSString *identifier in section.actions) {
        if (![self.configuration.unassignedActions containsObject:identifier]) {
            [self.configuration.unassignedActions addObject:identifier];
        }
    }
    [self.configuration.sections removeObjectAtIndex:indexPath.row];
    [self.configuration save];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete)
        return;
    [self removeSectionAtIndexPath:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section >= (NSInteger)self.groups.count)
        return nil;
    NSArray<NSString *> *rows = [self actionsInGroupAtIndex:indexPath.section];
    if (indexPath.row >= (NSInteger)rows.count)
        return nil;
    NSString *identifier = rows[indexPath.row];
    __weak typeof(self) weakSelf = self;

    UIContextualAction *remove =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:@"Remove"
                                              handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
        [weakSelf moveAction:identifier toSectionIdentifier:nil];
        done(YES);
    }];
    remove.image = SPKSettingsIcon(@"trash");

    UIContextualAction *move =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:@"Move"
                                              handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
        [weakSelf presentGroupPickerForAction:identifier fromView:view];
        done(YES);
    }];
    move.image = SPKSettingsIcon(@"arrow_right");
    move.backgroundColor = [SPKUtils SPKColor_InstagramSecondaryText];

    return [UISwipeActionsConfiguration configurationWithActions:@[ remove, move ]];
}

// Swipe the other way on an action that is out of the menu: it goes back where
// it was, or asks where to go if it has never been filed.
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != [self outsideSectionIndex])
        return nil;
    NSArray<NSString *> *rows = [self actionsOutsideMenu];
    if (indexPath.row >= (NSInteger)rows.count)
        return nil;
    NSString *identifier = rows[indexPath.row];
    __weak typeof(self) weakSelf = self;

    UIContextualAction *add =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:@"Add"
                                              handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
        typeof(self) strongSelf = weakSelf;
        NSString *lastGroup = strongSelf.lastGroupForAction[identifier];
        if (lastGroup && [strongSelf.configuration sectionWithIdentifier:lastGroup])
            [strongSelf moveAction:identifier toSectionIdentifier:lastGroup];
        else
            [strongSelf presentGroupPickerForAction:identifier fromView:view];
        done(YES);
    }];
    add.image = SPKSettingsIcon(@"arrow_left");
    add.backgroundColor = [SPKUtils SPKColor_InstagramPrimaryText];

    return [UISwipeActionsConfiguration configurationWithActions:@[ add ]];
}

- (void)addSectionTapped {
    SPKActionMenuSection *section = [SPKActionMenuSection sectionWithIdentifier:NSUUID.UUID.UUIDString
                                                                          title:[NSString stringWithFormat:@"Section %lu", (unsigned long)(self.configuration.sections.count + 1)]
                                                                       iconName:@"more"
                                                                    collapsible:YES
                                                                        actions:@[]];
    [self.configuration.sections addObject:section];
    [self.configuration save];
    [self.tableView reloadData];

    __weak typeof(self) weakSelf = self;
    SPKActionSectionEditViewController *controller = [[SPKActionSectionEditViewController alloc] initWithConfiguration:self.configuration
                                                                                                     sectionIdentifier:section.identifier
                                                                                                              onChange:^{
                                                                                                                  [weakSelf.configuration save];
                                                                                                                  [weakSelf.tableView reloadData];
                                                                                                              }];
    [self.navigationController pushViewController:controller animated:YES];
}

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
                                      message:@"This restores this surface's menu sections, default action, and bulk menus to their defaults. The action button stays enabled and other surfaces are unaffected."
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
