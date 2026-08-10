#import "SPKToggleMenu.h"

#import "../Utils.h"
#import "SPKTopicSettingsSupport.h"

@interface SPKToggleMenuItem ()
- (BOOL)isEnabled;
@end

// Convention v1.2 metrics — see SPKToggleMenu.h.
static CGFloat const kSPKToggleMenuWidth = 262.0;
static CGFloat const kSPKToggleMenuItemHeight = 44.0;  // = SPKUI_RowHeight
static CGFloat const kSPKToggleMenuCornerRadius = 13.0;
static CGFloat const kSPKToggleMenuIconSize = 22.0;
static CGFloat const kSPKToggleMenuHPad = 14.0;
static CGFloat const kSPKToggleMenuMargin = 20.0;
static CGFloat const kSPKToggleMenuContentPadding = 6.0;   // v1.4: breathing room above/below items
static CGFloat const kSPKToggleMenuFooterGap = 6.0;        // v1.4.1: sectioned gap before Done (lighter, slimmer)
static CGFloat const kSPKToggleMenuAnchorGap = 6.0;

#pragma mark - Item

@implementation SPKToggleMenuItem

+ (instancetype)itemWithTitle:(NSString *)title
                     iconName:(NSString *)iconName
                  defaultsKey:(NSString *)defaultsKey {
    SPKToggleMenuItem *item = [self new];
    item->_title = [title copy];
    item->_iconName = [iconName copy];
    item->_defaultsKey = [defaultsKey copy];
    return item;
}

- (BOOL)isEnabled {
    return self.enabledProvider == nil || self.enabledProvider();
}

@end

#pragma mark - Item control (manual frame layout — fully deterministic)

@interface SPKToggleMenuItemControl : UIControl
@property (nonatomic, strong) SPKToggleMenuItem *item;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *checkView;
@end

@implementation SPKToggleMenuItemControl

- (instancetype)initWithItem:(SPKToggleMenuItem *)item {
    if ((self = [super initWithFrame:CGRectZero])) {
        _item = item;

        _iconView = [[UIImageView alloc] initWithImage:
            [SPKSettingsIcon(item.iconName) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        _iconView.tintColor = UIColor.labelColor;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];

        _titleLabel = [UILabel new];
        _titleLabel.text = item.title;
        _titleLabel.font = [UIFont systemFontOfSize:16.0];
        _titleLabel.textColor = UIColor.labelColor;
        [self addSubview:_titleLabel];

        _checkView = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"checkmark"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                      weight:UIImageSymbolWeightSemibold]]];
        _checkView.tintColor = UIColor.labelColor;
        _checkView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_checkView];

        [self refreshAnimated:NO];
        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = item.title;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    CGFloat w = self.bounds.size.width;
    self.iconView.frame = CGRectMake(kSPKToggleMenuHPad,
                                     (h - kSPKToggleMenuIconSize) / 2.0,
                                     kSPKToggleMenuIconSize, kSPKToggleMenuIconSize);
    CGFloat checkW = 18.0;
    self.checkView.frame = CGRectMake(w - kSPKToggleMenuHPad - checkW,
                                      (h - checkW) / 2.0, checkW, checkW);
    CGFloat titleX = CGRectGetMaxX(self.iconView.frame) + 12.0;
    self.titleLabel.frame = CGRectMake(titleX, 0,
                                       CGRectGetMinX(self.checkView.frame) - 8.0 - titleX, h);
}

- (void)refreshAnimated:(BOOL)animated {
    BOOL enabled = [self.item isEnabled];
    BOOL on = enabled ? [SPKUtils getBoolPref:self.item.defaultsKey] : NO;
    self.alpha = enabled ? 1.0 : 0.35;
    self.accessibilityValue = on ? @"On" : @"Off";

    void (^apply)(void) = ^{
        self.checkView.alpha = on ? 1.0 : 0.0;
        self.checkView.transform = on ? CGAffineTransformIdentity
                                      : CGAffineTransformMakeScale(0.6, 0.6);
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:apply];
    } else {
        apply();
    }
}

- (void)didTap {
    if (![self.item isEnabled])
        return;
    BOOL next = ![SPKUtils getBoolPref:self.item.defaultsKey];
    SPKPreferenceSetObject(@(next), self.item.defaultsKey);
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self refreshAnimated:YES];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (![self.item isEnabled])
        return;
    self.backgroundColor = highlighted
        ? [UIColor.labelColor colorWithAlphaComponent:0.08]
        : UIColor.clearColor;
}

@end

#pragma mark - Menu

@interface SPKToggleMenuOverlay : UIControl
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, copy) void (^onDismiss)(void);
@end

@implementation SPKToggleMenuOverlay

- (void)spk_dismissFromDone {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.15
        animations:^{
            self.menuContainer.alpha = 0.0;
            self.menuContainer.transform = CGAffineTransformMakeScale(0.94, 0.94);
            self.backgroundColor = UIColor.clearColor;
        }
        completion:^(__unused BOOL finished) {
            [self removeFromSuperview];
            if (self.onDismiss)
                self.onDismiss();
        }];
}

@end

@implementation SPKToggleMenu

+ (void)presentWithItems:(NSArray<SPKToggleMenuItem *> *)items
                fromView:(UIView *)anchorView
        inViewController:(UIViewController *)viewController
               onDismiss:(void (^)(void))onDismiss {
    UIWindow *window = viewController.view.window ?: anchorView.window;
    if (window == nil || items.count == 0)
        return;

    CGFloat hairline = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
    CGFloat menuHeight = 2.0 * kSPKToggleMenuContentPadding
        + items.count * kSPKToggleMenuItemHeight + (items.count - 1) * hairline
        + kSPKToggleMenuFooterGap + kSPKToggleMenuItemHeight; // v1.4 Done footer

    SPKToggleMenuOverlay *overlay = [[SPKToggleMenuOverlay alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.onDismiss = onDismiss;
    [overlay addTarget:overlay action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    // Container: system-material blur, menu-style rounding and shadow.
    // Everything below is plain frame math — no Auto Layout in this tree.
    UIView *container = [UIView new];
    container.layer.cornerRadius = kSPKToggleMenuCornerRadius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowColor = UIColor.blackColor.CGColor;
    container.layer.shadowOpacity = 0.22;
    container.layer.shadowRadius = 24.0;
    container.layer.shadowOffset = CGSizeMake(0, 10);
    overlay.menuContainer = container;

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blurView.frame = CGRectMake(0, 0, kSPKToggleMenuWidth, menuHeight);
    blurView.layer.cornerRadius = kSPKToggleMenuCornerRadius;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.clipsToBounds = YES;
    [container addSubview:blurView];

    CGFloat y = kSPKToggleMenuContentPadding;
    for (NSUInteger i = 0; i < items.count; i++) {
        if (i > 0) {
            UIView *separator = [UIView new];
            separator.backgroundColor = UIColor.separatorColor;
            separator.frame = CGRectMake(0, y, kSPKToggleMenuWidth, hairline);
            [blurView.contentView addSubview:separator];
            y += hairline;
        }
        SPKToggleMenuItemControl *control = [[SPKToggleMenuItemControl alloc] initWithItem:items[i]];
        control.frame = CGRectMake(0, y, kSPKToggleMenuWidth, kSPKToggleMenuItemHeight);
        [blurView.contentView addSubview:control];
        y += kSPKToggleMenuItemHeight;
    }

    // v1.4 footer — sectioned gap, then an explicit way out. Same dismissal
    // path as tapping outside (animation + onDismiss), with a light tick.
    UIView *gapBand = [[UIView alloc] initWithFrame:CGRectMake(0, y, kSPKToggleMenuWidth, kSPKToggleMenuFooterGap)];
    gapBand.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.18];
    UIView *gapTop = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSPKToggleMenuWidth, hairline)];
    gapTop.backgroundColor = UIColor.separatorColor;
    UIView *gapBottom = [[UIView alloc] initWithFrame:CGRectMake(0, kSPKToggleMenuFooterGap - hairline, kSPKToggleMenuWidth, hairline)];
    gapBottom.backgroundColor = UIColor.separatorColor;
    [gapBand addSubview:gapTop];
    [gapBand addSubview:gapBottom];
    [blurView.contentView addSubview:gapBand];
    y += kSPKToggleMenuFooterGap;

    UIControl *doneControl = [[UIControl alloc] initWithFrame:CGRectMake(0, y, kSPKToggleMenuWidth, kSPKToggleMenuItemHeight)];
    UILabel *doneLabel = [[UILabel alloc] initWithFrame:doneControl.bounds];
    doneLabel.text = @"Done";
    doneLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    doneLabel.textColor = UIColor.labelColor;
    doneLabel.textAlignment = NSTextAlignmentCenter;
    doneLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [doneControl addSubview:doneLabel];
    [doneControl addTarget:overlay action:@selector(spk_dismissFromDone) forControlEvents:UIControlEventTouchUpInside];
    [blurView.contentView addSubview:doneControl];
    y += kSPKToggleMenuItemHeight;

    // Placement: below the anchor when it fits, otherwise above — then clamp
    // both axes into the safe area so the menu can never leave the screen.
    CGRect anchorFrame = [anchorView convertRect:anchorView.bounds toView:overlay];
    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat minX = safe.left + kSPKToggleMenuMargin;
    CGFloat maxX = window.bounds.size.width - safe.right - kSPKToggleMenuMargin - kSPKToggleMenuWidth;
    CGFloat minY = safe.top + kSPKToggleMenuMargin;
    CGFloat maxY = window.bounds.size.height - safe.bottom - kSPKToggleMenuMargin - menuHeight;

    CGFloat x = CGRectGetMaxX(anchorFrame) - kSPKToggleMenuWidth - kSPKToggleMenuMargin;
    x = MAX(minX, MIN(x, maxX));

    CGFloat belowY = CGRectGetMaxY(anchorFrame) + kSPKToggleMenuAnchorGap;
    BOOL fitsBelow = belowY <= maxY;
    CGFloat menuY = fitsBelow ? belowY
                              : CGRectGetMinY(anchorFrame) - kSPKToggleMenuAnchorGap - menuHeight;
    menuY = MAX(minY, MIN(menuY, maxY));

    container.frame = CGRectMake(x, menuY, kSPKToggleMenuWidth, menuHeight);
    [overlay addSubview:container];
    [window addSubview:overlay];

    container.alpha = 0.0;
    container.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         overlay.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
                         container.alpha = 1.0;
                         container.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
}

@end

#pragma mark - Gate row

SPKSetting *SPKToggleMenuRowSetting(NSString *title,
                                    NSString *iconName,
                                    NSArray<SPKToggleMenuItem *> *items) {
    SPKSetting *row = [SPKSetting buttonCellWithTitle:title
                                             subtitle:nil
                                                 icon:SPKSettingsIcon(iconName)
                                               action:^{
                                                   // No-op — `action` is nonnull. The settings VC
                                                   // routes spk_toggleMenuItems before ever calling it.
                                               }];
    row.userInfo = @{@"spk_toggleMenuItems" : [items copy]};

    // "Off" / "N on" — re-read on every reloadData, like the root counters.
    row.accessoryTextProvider = ^NSString * {
        NSUInteger on = 0;
        for (SPKToggleMenuItem *item in items) {
            if ([SPKUtils getBoolPref:item.defaultsKey])
                on++;
        }
        return on == 0 ? @"Off" : [NSString stringWithFormat:@"%lu on", (unsigned long)on];
    };

    // Search index: expose each item as a real switch row so it stays findable
    // and togglable from search results. Never shown as a page. Items inherit
    // the gate's searchKeywords so family terms ("mark seen", "confirm") match.
    __weak SPKSetting *weakRow = row;
    row.searchSectionsProvider = ^NSArray * {
        NSMutableArray<SPKSetting *> *rows = [NSMutableArray arrayWithCapacity:items.count];
        for (SPKToggleMenuItem *item in items) {
            SPKSetting *searchRow = [SPKSetting switchCellWithTitle:item.title
                                                               icon:SPKSettingsIcon(item.iconName)
                                                        defaultsKey:item.defaultsKey];
            searchRow.enabledProvider = item.enabledProvider;
            searchRow.searchKeywords = weakRow.searchKeywords;
            [rows addObject:searchRow];
        }
        return @[ SPKTopicSection(title, [rows copy], nil) ];
    };

    return row;
}
