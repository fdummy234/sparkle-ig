#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/ActionButton/ActionButtonLookupUtils.h"
#import <objc/runtime.h>

// Adds the account's age next to posts / followers / following.
//
// The date is read through whichever accessor the user object answers. It is
// present on some profiles and not others — Instagram loads a full user for the
// signed-in account and a lighter one for people you visit — so the column is
// left out rather than shown empty when the date is missing.

static NSString *const kSPKProfileAccountAgeKey = @"profile_show_account_age";
static const void *kSPKAccountAgeLabelAssocKey = &kSPKAccountAgeLabelAssocKey;

static BOOL SPKProfileAccountAgeEnabled(void) {
    return [SPKUtils getBoolPref:kSPKProfileAccountAgeKey];
}

static NSArray<NSString *> *SPKAccountDateSelectorNames(void) {
    return @[ @"accountCreationDate", @"dateJoined", @"joinedDate", @"createdAt",
              @"accountCreatedAt", @"signupDate", @"creationDate", @"dateCreated",
              @"registrationDate", @"memberSince" ];
}

// Records what the object actually answers. Methods, not @property declarations:
// a plain method never appears in class_copyPropertyList, which is what made an
// earlier probe report "no date available" on a profile that had one.
static void SPKRecordAccountDateProbe(id user, NSString *hit) {
    NSMutableArray *answered = [NSMutableArray array];
    for (NSString *name in SPKAccountDateSelectorNames()) {
        if ([user respondsToSelector:NSSelectorFromString(name)])
            [answered addObject:name];
    }
    NSString *summary = [NSString stringWithFormat:@"%@ · answers: %@ · used: %@",
                         NSStringFromClass([user class]),
                         answered.count ? [answered componentsJoinedByString:@", "] : @"none",
                         hit ?: @"none"];
    [[NSUserDefaults standardUserDefaults] setObject:summary forKey:@"spk_diag_account_probe"];
}

static NSDate *SPKAccountCreationDate(id user) {
    if (!user)
        return nil;
    for (NSString *name in SPKAccountDateSelectorNames()) {
        SEL selector = NSSelectorFromString(name);
        if (![user respondsToSelector:selector])
            continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(user, selector);
        NSDate *date = nil;
        if ([value isKindOfClass:[NSDate class]])
            date = (NSDate *)value;
        else if ([value isKindOfClass:[NSNumber class]])
            date = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
        if (date) {
            SPKRecordAccountDateProbe(user, name);
            return date;
        }
    }
    SPKRecordAccountDateProbe(user, nil);
    return nil;
}

// Compact enough to sit under a stat number: 3 d, 5 w, 8 mo, 2 y.
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
