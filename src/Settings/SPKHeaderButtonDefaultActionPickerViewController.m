#import "SPKHeaderButtonDefaultActionPickerViewController.h"

#import "../AssetUtils.h"
#import "../Features/Feed/HeaderActionButton.h"
#import "../Utils.h"

static NSString *const kSPKHeaderPickerCellIdentifier = @"SPKHeaderDefaultPickerCell";

// A picker row: an identifier ("menu" or a destination id), a display title, and
// an IG-bundle icon name.
@interface SPKHeaderPickerRow : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@end

@implementation SPKHeaderPickerRow
@end

@interface SPKHeaderButtonDefaultActionPickerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<SPKHeaderPickerRow *> *rows;
@end

@implementation SPKHeaderButtonDefaultActionPickerViewController

- (NSArray<SPKHeaderPickerRow *> *)buildRows {
    NSMutableArray<SPKHeaderPickerRow *> *rows = [NSMutableArray array];

    SPKHeaderPickerRow *menuRow = [SPKHeaderPickerRow new];
    menuRow.identifier = @"menu";
    menuRow.title = @"Open Menu";
    menuRow.iconName = @"action";
    [rows addObject:menuRow];

    for (SPKHeaderDestination *destination in SPKHeaderButtonEnabledDestinations()) {
        SPKHeaderPickerRow *row = [SPKHeaderPickerRow new];
        row.identifier = destination.identifier;
        row.title = destination.title;
        row.iconName = destination.iconName;
        [rows addObject:row];
    }
    return rows;
}

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];
    return view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Default Tap Action";
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];
    self.rows = [self buildRows];

    // Convention v1.2, alignée sur le sélecteur jumeau du bouton d'action :
    // Grouped et cellules blanches, pas la carte grise arrondie d'InsetGrouped.
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    // Aucun filet entre les rangées : les bandes de 6 pt séparent les groupes.
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    self.tableView.tintColor = [SPKUtils SPKColor_InstagramBlue];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kSPKHeaderPickerCellIdentifier];
    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Rebuild each time: the enabled-destination set can change between opens, and
    // this VC instance is reused by the settings row.
    self.rows = [self buildRows];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

// La bande de 6 pt que le reste de Sparkle pose entre les groupes. #EFEFF1 en
// dur : SPKColor_InstagramGroupedBackground renvoie du blanc dans cette palette.
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 6.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *band = [UIView new];
    band.backgroundColor = [UIColor colorWithRed:0.937 green:0.937 blue:0.945 alpha:1.0];
    return band;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSPKHeaderPickerCellIdentifier forIndexPath:indexPath];
    SPKHeaderPickerRow *row = self.rows[indexPath.row];

    UIListContentConfiguration *config = cell.defaultContentConfiguration;
    config.text = row.title;
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.image = [[SPKAssetUtils instagramIconNamed:row.iconName pointSize:24.0] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    cell.contentConfiguration = config;

    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.tintColor = [SPKUtils SPKColor_InstagramBlue];
    cell.selectedBackgroundView = [self selectionBackgroundView];

    if ([row.identifier isEqualToString:SPKHeaderButtonResolvedDefaultActionIdentifier()]) {
        // Le disque bleu était le dernier contrôle de sélection bleu du tweak.
        UIImageSymbolConfiguration *symbol =
            [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightSemibold];
        UIImageView *checkmark = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"
                                                                            withConfiguration:symbol]];
        checkmark.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
        checkmark.contentMode = UIViewContentModeScaleAspectFit;
        [checkmark sizeToFit];
        cell.accessoryView = checkmark;
    } else {
        cell.accessoryView = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SPKHeaderPickerRow *row = self.rows[indexPath.row];
    SPKPreferenceSetObject(row.identifier, kSPKHeaderButtonDefaultActionKey);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
