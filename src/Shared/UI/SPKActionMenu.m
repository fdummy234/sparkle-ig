#import "SPKActionMenu.h"

// Convention v1.2 metrics, the same numbers SPKToggleMenu draws with — kept
// here rather than imported so this menu never depends on the settings tree.
static CGFloat const kSPKActionMenuMinWidth = 262.0;
static CGFloat const kSPKActionMenuRowHeight = 44.0;
static CGFloat const kSPKActionMenuCornerRadius = 13.0;
static CGFloat const kSPKActionMenuIconSize = 22.0;
static CGFloat const kSPKActionMenuHPad = 14.0;
static CGFloat const kSPKActionMenuIconGap = 12.0;
static CGFloat const kSPKActionMenuScreenMargin = 20.0;
static CGFloat const kSPKActionMenuContentPadding = 6.0;
static CGFloat const kSPKActionMenuAnchorGap = 6.0;
static CGFloat const kSPKActionMenuTitleSize = 16.0;
static CGFloat const kSPKActionMenuChevronWidth = 18.0;

#pragma mark - Node

@interface SPKActionMenuNode ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, strong, readwrite, nullable) UIImage *image;
@property (nonatomic, copy, readwrite, nullable) dispatch_block_t handler;
@property (nonatomic, copy, readwrite, nullable) NSArray<SPKActionMenuNode *> *children;
@end

@implementation SPKActionMenuNode

+ (instancetype)leafWithTitle:(NSString *)title
                        image:(UIImage *)image
                      handler:(dispatch_block_t)handler {
    SPKActionMenuNode *node = [self new];
    node.title = title ?: @"";
    node.image = image;
    node.handler = handler;
    return node;
}

+ (instancetype)branchWithTitle:(NSString *)title
                          image:(UIImage *)image
                       children:(NSArray<SPKActionMenuNode *> *)children {
    SPKActionMenuNode *node = [self new];
    node.title = title ?: @"";
    node.image = image;
    node.children = [children copy];
    return node;
}

@end

#pragma mark - Row

typedef NS_ENUM(NSInteger, SPKActionMenuRowKind) {
    SPKActionMenuRowKindLeaf = 0,
    SPKActionMenuRowKindBranch,
    SPKActionMenuRowKindHeader   // the submenu's own row, tapped to go back
};

@interface SPKActionMenuRow : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, assign) SPKActionMenuRowKind kind;
/// Same shape as SPKToggleMenu's controls: a block set by the presenter, fired
/// through addTarget:action: — the only control pattern this project uses.
@property (nonatomic, copy, nullable) dispatch_block_t tapHandler;
@end

@implementation SPKActionMenuRow

- (instancetype)initWithNode:(SPKActionMenuNode *)node kind:(SPKActionMenuRowKind)kind {
    if ((self = [super initWithFrame:CGRectZero])) {
        _kind = kind;

        _iconView = [[UIImageView alloc] initWithImage:node.image];
        _iconView.tintColor = UIColor.labelColor;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];

        _titleLabel = [UILabel new];
        _titleLabel.text = node.title;
        _titleLabel.textColor = UIColor.labelColor;
        // The header names the level you are in, so it carries the weight.
        _titleLabel.font = (kind == SPKActionMenuRowKindHeader)
            ? [UIFont systemFontOfSize:kSPKActionMenuTitleSize weight:UIFontWeightSemibold]
            : [UIFont systemFontOfSize:kSPKActionMenuTitleSize];
        [self addSubview:_titleLabel];

        if (kind != SPKActionMenuRowKindLeaf) {
            NSString *symbol = (kind == SPKActionMenuRowKindHeader) ? @"chevron.down" : @"chevron.right";
            UIImageSymbolConfiguration *config =
                [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
            _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol
                                                                      withConfiguration:config]];
            _chevronView.tintColor = UIColor.labelColor;
            _chevronView.contentMode = UIViewContentModeScaleAspectFit;
            [self addSubview:_chevronView];
        }

        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];

        // A leaf with no handler is information, not a control.
        if (kind == SPKActionMenuRowKindLeaf && node.handler == nil) {
            self.userInteractionEnabled = NO;
            self.alpha = 0.45;
        }

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = node.title;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)didTap {
    if (self.tapHandler)
        self.tapHandler();
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    CGFloat w = self.bounds.size.width;

    // A row without a glyph reserves no column — same rule as the settings menu.
    BOOL hasIcon = (self.iconView.image != nil);
    self.iconView.hidden = !hasIcon;
    self.iconView.frame = hasIcon
        ? CGRectMake(kSPKActionMenuHPad, (h - kSPKActionMenuIconSize) / 2.0,
                     kSPKActionMenuIconSize, kSPKActionMenuIconSize)
        : CGRectZero;

    CGFloat titleX = hasIcon ? kSPKActionMenuHPad + kSPKActionMenuIconSize + kSPKActionMenuIconGap
                             : kSPKActionMenuHPad;
    CGFloat titleRight = kSPKActionMenuHPad;
    if (self.chevronView) {
        self.chevronView.frame = CGRectMake(w - kSPKActionMenuHPad - kSPKActionMenuChevronWidth,
                                            (h - kSPKActionMenuChevronWidth) / 2.0,
                                            kSPKActionMenuChevronWidth, kSPKActionMenuChevronWidth);
        titleRight = kSPKActionMenuHPad + kSPKActionMenuChevronWidth + 8.0;
    }
    self.titleLabel.frame = CGRectMake(titleX, 0, MAX(0.0, w - titleX - titleRight), h);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [UIColor.labelColor colorWithAlphaComponent:0.08]
                                       : UIColor.clearColor;
}

@end

#pragma mark - Overlay

@interface SPKActionMenuOverlay : UIControl
@property (nonatomic, strong, nullable) UIView *menuContainer;
@property (nonatomic, copy, nullable) void (^onDismiss)(void);
@property (nonatomic, copy, nullable) dispatch_block_t pendingAction;
/// Kept so the header row can walk back up without rebuilding the tree.
@property (nonatomic, copy, nullable) NSArray<SPKActionMenuNode *> *rootNodes;
- (void)dismiss;
@end

@implementation SPKActionMenuOverlay

- (void)dismiss {
    UIView *container = self.menuContainer;
    void (^finished)(BOOL) = ^(BOOL done) {
        (void)done;
        [self removeFromSuperview];
        if (self.onDismiss)
            self.onDismiss();
        // The action runs after the menu is gone, so anything it presents does
        // not fight this overlay for the window.
        if (self.pendingAction)
            self.pendingAction();
    };
    [UIView animateWithDuration:0.16
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.backgroundColor = UIColor.clearColor;
                         container.alpha = 0.0;
                         container.transform = CGAffineTransformMakeScale(0.94, 0.94);
                     }
                     completion:finished];
}

@end

#pragma mark - Presenter

@implementation SPKActionMenu

+ (CGFloat)widthForNodes:(NSArray<SPKActionMenuNode *> *)nodes available:(CGFloat)available {
    UIFont *font = [UIFont systemFontOfSize:kSPKActionMenuTitleSize];
    UIFont *bold = [UIFont systemFontOfSize:kSPKActionMenuTitleSize weight:UIFontWeightSemibold];
    CGFloat widest = 0.0;
    for (SPKActionMenuNode *node in nodes) {
        CGFloat text = [node.title sizeWithAttributes:@{NSFontAttributeName : font}].width;
        CGFloat boldText = [node.title sizeWithAttributes:@{NSFontAttributeName : bold}].width;
        CGFloat row = kSPKActionMenuHPad + kSPKActionMenuIconSize + kSPKActionMenuIconGap
            + MAX(text, boldText) + 8.0 + kSPKActionMenuChevronWidth + kSPKActionMenuHPad;
        widest = MAX(widest, row);
        if (node.children.count > 0)
            widest = MAX(widest, [self widthForNodes:node.children available:available]);
    }
    return MIN(MAX(ceil(widest), kSPKActionMenuMinWidth), available);
}

+ (void)presentNodes:(NSArray<SPKActionMenuNode *> *)nodes
            fromView:(UIView *)anchorView
           onDismiss:(void (^)(void))onDismiss {
    UIWindow *window = anchorView.window;
    if (window == nil || nodes.count == 0)
        return;

    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat available = window.bounds.size.width - safe.left - safe.right - 2.0 * kSPKActionMenuScreenMargin;
    CGFloat width = [self widthForNodes:nodes available:available];

    SPKActionMenuOverlay *overlay = [[SPKActionMenuOverlay alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.onDismiss = onDismiss;
    overlay.rootNodes = nodes;
    [overlay addTarget:overlay action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    UIView *container = [UIView new];
    container.layer.cornerRadius = kSPKActionMenuCornerRadius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowColor = UIColor.blackColor.CGColor;
    container.layer.shadowOpacity = 0.22;
    container.layer.shadowRadius = 24.0;
    container.layer.shadowOffset = CGSizeMake(0, 10);
    overlay.menuContainer = container;

    // Same material as the system's menus: glass on iOS 26+, system material
    // before that.
    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    UIVisualEffect *effect = glassEffectClass
        ? [[glassEffectClass alloc] init]
        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.layer.cornerRadius = kSPKActionMenuCornerRadius;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.clipsToBounds = YES;
    [container addSubview:blurView];

    [overlay addSubview:container];
    [window addSubview:overlay];

    [self fillMenu:blurView
          overlay:overlay
        container:container
            width:width
           anchor:anchorView
           window:window
            nodes:nodes
           header:nil
         animated:NO];

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

// Draws one level. `header` is nil at the top; inside a submenu it is that
// submenu's own node, drawn as the first row and tapped to come back.
+ (void)fillMenu:(UIVisualEffectView *)blurView
         overlay:(SPKActionMenuOverlay *)overlay
       container:(UIView *)container
           width:(CGFloat)width
          anchor:(UIView *)anchorView
          window:(UIWindow *)window
           nodes:(NSArray<SPKActionMenuNode *> *)nodes
          header:(SPKActionMenuNode *)header
        animated:(BOOL)animated {
    for (UIView *old in [blurView.contentView.subviews copy])
        [old removeFromSuperview];

    CGFloat hairline = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
    NSUInteger rowCount = nodes.count + (header ? 1 : 0);
    CGFloat height = 2.0 * kSPKActionMenuContentPadding
        + rowCount * kSPKActionMenuRowHeight
        + (rowCount > 0 ? (rowCount - 1) * hairline : 0.0);

    CGFloat y = kSPKActionMenuContentPadding;
    __weak SPKActionMenuOverlay *weakOverlay = overlay;

    void (^addSeparator)(void) = ^{
        UIView *separator = [UIView new];
        separator.backgroundColor = UIColor.separatorColor;
        separator.frame = CGRectMake(0, y, width, hairline);
        [blurView.contentView addSubview:separator];
    };

    if (header) {
        SPKActionMenuRow *headerRow = [[SPKActionMenuRow alloc] initWithNode:header
                                                                       kind:SPKActionMenuRowKindHeader];
        headerRow.frame = CGRectMake(0, y, width, kSPKActionMenuRowHeight);
        [blurView.contentView addSubview:headerRow];
        y += kSPKActionMenuRowHeight;
        headerRow.tapHandler = ^{
            SPKActionMenuOverlay *strongOverlay = weakOverlay;
            if (!strongOverlay)
                return;
            [self fillMenu:blurView overlay:strongOverlay container:container width:width
                    anchor:anchorView window:window nodes:strongOverlay.rootNodes
                    header:nil animated:YES];
        };
        addSeparator();
        y += hairline;
    }

    for (NSUInteger i = 0; i < nodes.count; i++) {
        if (i > 0) {
            addSeparator();
            y += hairline;
        }
        SPKActionMenuNode *node = nodes[i];
        BOOL isBranch = (node.children.count > 0);
        SPKActionMenuRow *row = [[SPKActionMenuRow alloc]
            initWithNode:node
                    kind:isBranch ? SPKActionMenuRowKindBranch : SPKActionMenuRowKindLeaf];
        row.frame = CGRectMake(0, y, width, kSPKActionMenuRowHeight);
        [blurView.contentView addSubview:row];
        y += kSPKActionMenuRowHeight;

        if (isBranch) {
            row.tapHandler = ^{
                SPKActionMenuOverlay *strongOverlay = weakOverlay;
                if (!strongOverlay)
                    return;
                [self fillMenu:blurView overlay:strongOverlay container:container width:width
                        anchor:anchorView window:window nodes:node.children
                        header:node animated:YES];
            };
        } else {
            row.tapHandler = ^{
                SPKActionMenuOverlay *strongOverlay = weakOverlay;
                if (!strongOverlay)
                    return;
                strongOverlay.pendingAction = node.handler;
                [strongOverlay dismiss];
            };
        }
    }

    blurView.frame = CGRectMake(0, 0, width, height);

    // Placement: below the anchor when it fits, above otherwise, then clamped
    // into the safe area on both axes.
    CGRect anchorFrame = [anchorView convertRect:anchorView.bounds toView:overlay];
    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat minX = safe.left + kSPKActionMenuScreenMargin;
    CGFloat maxX = window.bounds.size.width - safe.right - kSPKActionMenuScreenMargin - width;
    CGFloat minY = safe.top + kSPKActionMenuScreenMargin;
    CGFloat maxY = window.bounds.size.height - safe.bottom - kSPKActionMenuScreenMargin - height;

    CGFloat x = CGRectGetMaxX(anchorFrame) - width;
    x = MAX(minX, MIN(x, MAX(minX, maxX)));

    CGFloat belowY = CGRectGetMaxY(anchorFrame) + kSPKActionMenuAnchorGap;
    CGFloat menuY = (belowY <= maxY) ? belowY
                                     : CGRectGetMinY(anchorFrame) - kSPKActionMenuAnchorGap - height;
    menuY = MAX(minY, MIN(menuY, MAX(minY, maxY)));

    CGRect target = CGRectMake(x, menuY, width, height);
    if (animated) {
        [UIView animateWithDuration:0.18
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{ container.frame = target; }
                         completion:nil];
    } else {
        container.frame = target;
    }
}


@end
