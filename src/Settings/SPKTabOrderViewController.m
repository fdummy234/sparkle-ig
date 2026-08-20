#import "SPKTabOrderViewController.h"
#import "../Utils.h"
#import "../AssetUtils.h"
#import "SPKPreferences.h"

// A page for the tab layout, in place of a menu of four words.
//
// Each layout is drawn as the bar it produces, in the order it produces. The
// names alone said nothing: "Alternate" is only meaningful once the two swapped
// icons are in front of you, and Classic is recognisable by what left its bar.
//
// Instagram exposes three orderings as an integer, not a list of tabs, so this
// is a choice between four cards and not a reorderable list. Anything more
// would mean rearranging the bar's own views, which Instagram rebuilds often.

static NSString *const kSPKTabOrderPrefKey = @"interface_nav_order";

static CGFloat const kSPKTabOrderCardRadius = 14.0;
static CGFloat const kSPKTabOrderCardInset = 16.0;
static CGFloat const kSPKTabOrderCardGap = 12.0;
// Just enough room above the bar to read as a screen, no more: the empty
// area used to be taller than the bar it framed.
static CGFloat const kSPKTabOrderPreviewHeight = 62.0;
static CGFloat const kSPKTabOrderBarHeight = 34.0;
static CGFloat const kSPKTabOrderGlyph = 19.0;

#pragma mark - Layout description

@interface SPKTabLayout : NSObject
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<NSString *> *icons;
@end

@implementation SPKTabLayout
@end

static NSArray<SPKTabLayout *> *SPKTabOrderLayouts(void) {
    SPKTabLayout * (^layout)(NSString *, NSString *, NSArray *) =
        ^(NSString *value, NSString *title, NSArray *icons) {
            SPKTabLayout *entry = [SPKTabLayout new];
            entry.value = value;
            entry.title = title;
            entry.icons = icons;
            return entry;
        };

    return @[
        layout(@"default", @"Default", @[ @"home", @"search", @"reels", @"messages", @"user_circle" ]),
        layout(@"classic", @"Classic", @[ @"home", @"search", @"plus", @"reels", @"user_circle" ]),
        layout(@"standard", @"Standard", @[ @"home", @"reels", @"messages", @"search", @"user_circle" ]),
        layout(@"alternate", @"Alternate", @[ @"reels", @"home", @"messages", @"search", @"user_circle" ]),
    ];
}

#pragma mark - Card

@interface SPKTabOrderCard : UIControl
@property (nonatomic, strong) SPKTabLayout *layout;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *tickView;
@property (nonatomic, strong) UIView *preview;
@property (nonatomic, assign) BOOL selectedLayout;
@end

@implementation SPKTabOrderCard

- (instancetype)initWithLayout:(SPKTabLayout *)layout {
    self = [super initWithFrame:CGRectZero];
    if (!self)
        return nil;

    _layout = layout;
    self.layer.cornerRadius = kSPKTabOrderCardRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.borderWidth = 1.5;

    _titleLabel = [UILabel new];
    _titleLabel.text = layout.title;
    _titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
    [self addSubview:_titleLabel];

    _tickView = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"checkmark"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                  weight:UIImageSymbolWeightSemibold]]];
    _tickView.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    [self addSubview:_tickView];

    _preview = [self buildPreview];
    [self addSubview:_preview];

    self.selectedLayout = NO;
    return self;
}

// The bar this layout produces, drawn rather than described.
- (UIView *)buildPreview {
    UIView *frame = [UIView new];
    frame.layer.cornerRadius = 10.0;
    frame.layer.cornerCurve = kCACornerCurveContinuous;
    frame.layer.borderWidth = 1.0;
    frame.layer.borderColor = [SPKUtils SPKColor_InstagramSeparator].CGColor;
    frame.clipsToBounds = YES;
    frame.backgroundColor = [SPKUtils SPKColor_InstagramBackground];

    UIView *bar = [UIView new];
    bar.tag = 4;
    bar.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    [frame addSubview:bar];

    for (NSString *name in self.layout.icons) {
        UIImageView *glyph = [[UIImageView alloc] initWithImage:
            [SPKAssetUtils instagramIconNamed:name pointSize:kSPKTabOrderGlyph]];
        glyph.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
        glyph.contentMode = UIViewContentModeScaleAspectFit;
        [bar addSubview:glyph];
    }
    return frame;
}

- (void)setSelectedLayout:(BOOL)selectedLayout {
    _selectedLayout = selectedLayout;
    self.layer.borderColor = selectedLayout
        ? [SPKUtils SPKColor_InstagramPrimaryText].CGColor
        : [SPKUtils SPKColor_InstagramSeparator].CGColor;
    self.backgroundColor = selectedLayout
        ? [SPKUtils SPKColor_InstagramSecondaryBackground]
        : [SPKUtils SPKColor_InstagramBackground];
    self.tickView.hidden = !selectedLayout;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.62 : 1.0;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat inner = width - 2.0 * 14.0;

    [self.titleLabel sizeToFit];
    self.titleLabel.frame = CGRectMake(14.0, 13.0, inner - 26.0, CGRectGetHeight(self.titleLabel.bounds));
    self.tickView.frame = CGRectMake(width - 14.0 - 18.0,
                                     13.0 + (CGRectGetHeight(self.titleLabel.bounds) - 18.0) / 2.0,
                                     18.0, 18.0);

    CGFloat previewTop = CGRectGetMaxY(self.titleLabel.frame) + 11.0;
    self.preview.frame = CGRectMake(14.0, previewTop, inner, kSPKTabOrderPreviewHeight);

    UIView *bar = [self.preview viewWithTag:4];
    CGFloat previewWidth = CGRectGetWidth(self.preview.bounds);

    bar.frame = CGRectMake(0.0,
                           kSPKTabOrderPreviewHeight - kSPKTabOrderBarHeight,
                           previewWidth,
                           kSPKTabOrderBarHeight);

    NSArray<UIView *> *glyphs = bar.subviews;
    if (glyphs.count == 0)
        return;
    CGFloat slot = previewWidth / (CGFloat)glyphs.count;
    [glyphs enumerateObjectsUsingBlock:^(UIView *glyph, NSUInteger index, __unused BOOL *stop) {
        glyph.frame = CGRectMake(slot * (CGFloat)index + (slot - kSPKTabOrderGlyph) / 2.0,
                                 (kSPKTabOrderBarHeight - kSPKTabOrderGlyph) / 2.0,
                                 kSPKTabOrderGlyph,
                                 kSPKTabOrderGlyph);
    }];
}

+ (CGFloat)heightForWidth:(CGFloat)width {
    return 13.0 + 20.0 + 11.0 + kSPKTabOrderPreviewHeight + 14.0;
}

@end

#pragma mark - Controller

@interface SPKTabOrderViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray<SPKTabOrderCard *> *cards;
@end

@implementation SPKTabOrderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tab order";
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramBackground];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    NSMutableArray<SPKTabOrderCard *> *cards = [NSMutableArray array];
    for (SPKTabLayout *layout in SPKTabOrderLayouts()) {
        SPKTabOrderCard *card = [[SPKTabOrderCard alloc] initWithLayout:layout];
        [card addTarget:self action:@selector(cardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_scrollView addSubview:card];
        [cards addObject:card];
    }
    _cards = [cards copy];
    [self refreshSelection];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat width = CGRectGetWidth(self.view.bounds) - safe.left - safe.right - 2.0 * kSPKTabOrderCardInset;
    CGFloat height = [SPKTabOrderCard heightForWidth:width];
    CGFloat y = kSPKTabOrderCardInset;

    for (SPKTabOrderCard *card in self.cards) {
        card.frame = CGRectMake(safe.left + kSPKTabOrderCardInset, y, width, height);
        y += height + kSPKTabOrderCardGap;
    }
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.view.bounds), y + safe.bottom);
}

- (void)refreshSelection {
    NSString *current = [SPKUtils getStringPref:kSPKTabOrderPrefKey] ?: @"default";
    for (SPKTabOrderCard *card in self.cards)
        card.selectedLayout = [card.layout.value isEqualToString:current];
}

- (void)cardTapped:(SPKTabOrderCard *)card {
    if (card.selectedLayout)
        return;

    SPKPreferenceSetObject(card.layout.value, kSPKTabOrderPrefKey);
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self refreshSelection];
    [SPKUtils showRestartConfirmation];
}

@end
