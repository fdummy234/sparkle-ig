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
static CGFloat const kSPKToggleMenuIconPointSize = 22.0;
static CGFloat const kSPKToggleMenuMargin = 16.0;
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

#pragma mark - Item control

@interface SPKToggleMenuItemControl : UIControl
@property (nonatomic, strong) SPKToggleMenuItem *item;
@property (nonatomic, strong) UIImageView *checkView;
@end

@implementation SPKToggleMenuItemControl

- (instancetype)initWithItem:(SPKToggleMenuItem *)item {
    if ((self = [super initWithFrame:CGRectZero])) {
        _item = item;

        UIImageView *iconView = [[UIImageView alloc] initWithImage:
            [SPKSettingsIcon(item.iconName) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        iconView.tintColor = UIColor.labelColor;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *titleLabel = [UILabel new];
        titleLabel.text = item.title;
        titleLabel.font = [UIFont systemFontOfSize:16.0];
        titleLabel.textColor = UIColor.labelColor;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        UIImageConfiguration *checkConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightSemibold];
        UIImageView *checkView = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"checkmark" withConfiguration:checkConfig]];
        checkView.tintColor = UIColor.labelColor;
        checkView.translatesAutoresizingMaskIntoConstraints = NO;
        _checkView = checkView;

        [self addSubview:iconView];
        [self addSubview:titleLabel];
        [self addSubview:checkView];

        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:kSPKToggleMenuItemHeight],

            [iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
            [iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:kSPKToggleMenuIconPointSize],
            [iconView.heightAnchor constraintEqualToConstant:kSPKToggleMenuIconPointSize],

            [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12.0],
            [titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:checkView.leadingAnchor constant:-8.0],

            [checkView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
            [checkView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];

        [self refreshAnimated:NO];
        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = item.title;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
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
        [UIView animateWithDuration:0.2
                              delay:0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:apply
                         completion:nil];
    } else {
        apply();
    }
}

- (void)didTap {
    if (![self.item isEnabled])
        return;
    BOOL next = ![SPKUtils getBoolPref:self.item.defaultsKey];
    SPKPreferenceSetObject(@(next), self.item.defaultsKey);
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackGeneratorStyleLight] impactOccurred];
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

- (void)dismiss {
    [UIView animateWithDuration:0.15
        animations:^{
            self.menuContainer.alpha = 0.0;
            self.menuContainer.transform = CGAffineTransformMakeScale(0.96, 0.96);
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

    SPKToggleMenuOverlay *overlay = [[SPKToggleMenuOverlay alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.onDismiss = onDismiss;
    [overlay addTarget:overlay action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    // Container: system-material blur, menu-style rounding and shadow.
    CGFloat menuHeight = items.count * kSPKToggleMenuItemHeight;
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
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = kSPKToggleMenuCornerRadius;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.clipsToBounds = YES;
    [container addSubview:blurView];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [blurView.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor],
    ]];

    for (NSUInteger i = 0; i < items.count; i++) {
        if (i > 0) {
            UIView *separator = [UIView new];
            separator.backgroundColor = UIColor.separatorColor;
            [separator.heightAnchor constraintEqualToConstant:(1.0 / UIScreen.mainScreen.scale)].active = YES;
            [stack addArrangedSubview:separator];
        }
        [stack addArrangedSubview:[[SPKToggleMenuItemControl alloc] initWithItem:items[i]]];
    }

    // Placement: below the anchor when it fits, otherwise above; trailing-aligned
    // to the anchor, clamped inside the safe area.
    CGRect anchorFrame = [anchorView convertRect:anchorView.bounds toView:window];
    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat x = CGRectGetMaxX(anchorFrame) - kSPKToggleMenuWidth - kSPKToggleMenuMargin;
    x = MAX(safe.left + kSPKToggleMenuMargin,
            MIN(x, window.bounds.size.width - safe.right - kSPKToggleMenuMargin - kSPKToggleMenuWidth));

    CGFloat belowY = CGRectGetMaxY(anchorFrame) + kSPKToggleMenuAnchorGap;
    CGFloat bottomLimit = window.bounds.size.height - safe.bottom - kSPKToggleMenuMargin;
    BOOL fitsBelow = belowY + menuHeight <= bottomLimit;
    CGFloat y = fitsBelow ? belowY
                          : MAX(safe.top + kSPKToggleMenuMargin,
                                CGRectGetMinY(anchorFrame) - kSPKToggleMenuAnchorGap - menuHeight);

    container.frame = CGRectMake(x, y, kSPKToggleMenuWidth, menuHeight);
    [overlay addSubview:container];
    [window addSubview:overlay];

    // Entrance: grow from the anchor-side corner, like the system menu.
    CGPoint anchorPoint = fitsBelow ? CGPointMake(0.85, 0.0) : CGPointMake(0.85, 1.0);
    container.layer.anchorPoint = anchorPoint;
    container.frame = CGRectMake(x, y, kSPKToggleMenuWidth, menuHeight);
    container.alpha = 0.0;
    container.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [UIView animateWithDuration:0.24
                          delay:0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.3
                        options:0
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
                                               action:nil];
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
    // and togglable from search results. Never shown as a page.
    row.searchSectionsProvider = ^NSArray * {
        NSMutableArray<SPKSetting *> *rows = [NSMutableArray arrayWithCapacity:items.count];
        for (SPKToggleMenuItem *item in items) {
            SPKSetting *searchRow = [SPKSetting switchCellWithTitle:item.title
                                                               icon:SPKSettingsIcon(item.iconName)
                                                        defaultsKey:item.defaultsKey];
            searchRow.enabledProvider = item.enabledProvider;
            [rows addObject:searchRow];
        }
        return @[ SPKTopicSection(title, [rows copy], nil) ];
    };

    return row;
}
