#import "SPKActionCatalogViewController.h"

#import "../AssetUtils.h"
#import "../Shared/ActionButton/SPKActionDescriptor.h"
#import "../Utils.h"
#import "SPKTopicSettingsSupport.h"

@interface SPKActionCatalogViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SPKActionButtonConfiguration *configuration;
@property (nonatomic, copy) NSArray<NSString *> *catalog;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *selection;
@property (nonatomic, copy) dispatch_block_t onChange;

@end

@implementation SPKActionCatalogViewController

- (instancetype)initWithConfiguration:(SPKActionButtonConfiguration *)configuration
                             onChange:(dispatch_block_t)onChange {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _onChange = [onChange copy];
        _catalog = [configuration catalogActions];
        _selection = [NSMutableOrderedSet orderedSet];
        self.title = @"Add Actions";
    }
    return self;
}

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];
    return view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(addTapped)];
    self.navigationItem.leftBarButtonItem.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    self.navigationItem.rightBarButtonItem.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    // No hairline between rows: the bands do the separating, like every other
    // Sparkle screen (SPKSettingsViewController.m:553).
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    [self.view addSubview:self.tableView];

    [self refreshAddButton];
}

// "Add (3)" while something is picked, plain "Add" and unavailable at zero.
- (void)refreshAddButton {
    NSUInteger count = self.selection.count;
    self.navigationItem.rightBarButtonItem.title =
        count > 0 ? [NSString stringWithFormat:@"Add (%lu)", (unsigned long)count] : @"Add";
    self.navigationItem.rightBarButtonItem.enabled = (count > 0);
}

- (void)cancelTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

// The picked actions land in "Not in the Menu", where a swipe puts them in the
// menu — and they leave the catalogue, which only ever offers what is nowhere.
- (void)addTapped {
    for (NSString *identifier in self.selection) {
        if (![self.configuration.unassignedActions containsObject:identifier])
            [self.configuration.unassignedActions addObject:identifier];
    }
    [self.configuration save];
    if (self.onChange)
        self.onChange();
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.catalog.count > 0 ? (NSInteger)self.catalog.count : 1;
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

    if (self.catalog.count == 0) {
        config.text = @"Every action is already placed.";
        config.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.contentConfiguration = config;
        return cell;
    }

    NSString *identifier = self.catalog[(NSUInteger)indexPath.row];
    config.text = SPKActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.image = SPKSettingsIcon(SPKActionDescriptorIconName(identifier));
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];

    // Convention v1.2: the glyph on the left, the state on the right, in ink —
    // the tweak has no blue selection anywhere else.
    BOOL picked = [self.selection containsObject:identifier];
    UIImageView *circle = [[UIImageView alloc] initWithImage:SPKSettingsIcon(picked ? @"circle_check" : @"circle")];
    circle.tintColor = picked ? [SPKUtils SPKColor_InstagramPrimaryText]
                              : [SPKUtils SPKColor_InstagramSecondaryText];
    circle.contentMode = UIViewContentModeScaleAspectFit;
    circle.frame = CGRectMake(0.0, 0.0, 24.0, 24.0);
    cell.accessoryView = circle;

    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.contentConfiguration = config;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.catalog.count == 0)
        return;

    NSString *identifier = self.catalog[(NSUInteger)indexPath.row];
    if ([self.selection containsObject:identifier])
        [self.selection removeObject:identifier];
    else
        [self.selection addObject:identifier];

    [self refreshAddButton];
    [tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
}

@end
