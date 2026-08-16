#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/ActionButton/ActionButtonLookupUtils.h"
#import <objc/runtime.h>

// Adds the account's age next to posts / followers / following.
//
// Instagram does not publish a creation date on the user object: the value shown
// in "About this account" is fetched by a separate call. Several plausible
// accessors are read, and when none answers the column is left out entirely
// rather than shown empty — a blank stat draws the eye for nothing.

static NSString *const kSPKProfileAccountAgeKey = @"profile_show_account_age";
static const void *kSPKAccountAgeLabelAssocKey = &kSPKAccountAgeLabelAssocKey;

static BOOL SPKProfileAccountAgeEnabled(void) {
    return [SPKUtils getBoolPref:kSPKProfileAccountAgeKey];
}

static NSDate *SPKAccountCreationDate(id user) {
    if (!user)
        return nil;
    for (NSString *name in @[ @"accountCreationDate", @"dateJoined", @"joinedDate",
                              @"createdAt", @"accountCreatedAt", @"signupDate" ]) {
        SEL selector = NSSelectorFromString(name);
        if (![user respondsToSelector:selector])
            continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(user, selector);
        if ([value isKindOfClass:[NSDate class]])
            return (NSDate *)value;
        if ([value isKindOfClass:[NSNumber class]])
            return [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
    }
    return nil;
}

// Compact enough to sit under a stat number: 3 w, 5 mo, 2 y.
static NSString *SPKAccountAgeText(NSDate *created) {
    if (!created)
        return nil;
    NSTimeInterval seconds = [[NSDate date] timeIntervalSinceDate:created];
    if (seconds < 0)
        return nil;
    NSInteger days = (NSInteger)(seconds / 86400.0);
    if (days < 14)
        return [NSString stringWithFormat:@"%ld d", (long)MAX(days, 1)];
    if (days < 60)
        return [NSString stringWithFormat:@"%ld w", (long)(days / 7)];
    if (days < 730)
        return [NSString stringWithFormat:@"%ld mo", (long)(days / 30)];
    return [NSString stringWithFormat:@"%ld y", (long)(days / 365)];
}

// The stat container lays its children out itself, so the label is parented to
// it and positioned after the last existing stat on every pass.
static void SPKPlaceAccountAgeLabel(UIView *container, NSString *text) {
    UILabel *label = objc_getAssociatedObject(container, kSPKAccountAgeLabelAssocKey);
    if (!text.length) {
        [label removeFromSuperview];
        objc_setAssociatedObject(container, kSPKAccountAgeLabelAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!label) {
        label = [UILabel new];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        label.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
        objc_setAssociatedObject(container, kSPKAccountAgeLabelAssocKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (label.superview != container)
        [container addSubview:label];

    NSMutableParagraphStyle *centred = [NSMutableParagraphStyle new];
    centred.alignment = NSTextAlignmentCenter;
    NSMutableAttributedString *stacked = [[NSMutableAttributedString alloc] initWithString:text
        attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold],
                      NSForegroundColorAttributeName : [SPKUtils SPKColor_InstagramPrimaryText],
                      NSParagraphStyleAttributeName : centred }];
    [stacked appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nage"
        attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular],
                      NSForegroundColorAttributeName : [SPKUtils SPKColor_InstagramSecondaryText],
                      NSParagraphStyleAttributeName : centred }]];
    label.attributedText = stacked;

    CGFloat rightMost = 0.0;
    for (UIView *sub in container.subviews) {
        if (sub != label)
            rightMost = MAX(rightMost, CGRectGetMaxX(sub.frame));
    }
    CGFloat width = 62.0;
    CGFloat x = MIN(rightMost + 10.0, CGRectGetWidth(container.bounds) - width);
    label.frame = CGRectMake(MAX(x, 0.0), 0.0, width, CGRectGetHeight(container.bounds));
    [container bringSubviewToFront:label];
}

%group SPKAccountAgeHooks

%hook _TtC23IGProfileHeaderIdentity38IGProfileHeaderStatButtonContainerView

- (void)layoutSubviews {
    %orig;
    if (!SPKProfileAccountAgeEnabled())
        return;
    UIViewController *controller = [SPKUtils nearestViewControllerForView:(UIView *)self];
    if (![controller isKindOfClass:%c(IGProfileViewController)])
        return;
    id user = SPKObjectForSelector(controller, @"user");
    SPKPlaceAccountAgeLabel((UIView *)self, SPKAccountAgeText(SPKAccountCreationDate(user)));
}

%end

%end

void SPKInstallProfileAccountAgeHooksIfEnabled(void) {
    if (!SPKProfileAccountAgeEnabled())
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKAccountAgeHooks);
    });
}
