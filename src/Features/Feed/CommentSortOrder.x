#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// Forces the comment thread's sort order.
//
// Instagram ranks comments by engagement, which scatters a conversation. The
// thread configuration object is the same one HideMetaAI writes to, so the order
// is set the same way: by key, on the configuration Instagram hands the config
// initialiser.
//
// The key name is not published. Several spellings are attempted and the first
// one the object accepts wins; when none is present the thread keeps Instagram's
// own order and nothing else changes.

static NSString *const kSPKCommentSortKey = @"feed_comments_sort_order";

static NSString *SPKCommentSortMode(void) {
    NSString *mode = [SPKUtils getStringPref:kSPKCommentSortKey];
    return mode.length > 0 ? mode : @"default";
}

// Instagram's own ordering, expressed as the values its configuration uses:
// 0 ranked, 1 newest first, 2 oldest first.
static NSNumber *SPKCommentSortValue(NSString *mode) {
    if ([mode isEqualToString:@"newest"])
        return @(1);
    if ([mode isEqualToString:@"oldest"])
        return @(2);
    return nil;
}

static void SPKApplyCommentSortOrder(id threadConfig) {
    NSNumber *value = SPKCommentSortValue(SPKCommentSortMode());
    if (!threadConfig || !value)
        return;

    for (NSString *key in @[ @"sortOrder", @"commentSortOrder", @"sortType", @"commentSortType", @"ordering" ]) {
        @try {
            // valueForKey raises when the key is absent, which is how an
            // unsupported spelling is skipped without touching the object.
            [threadConfig valueForKey:key];
        } @catch (__unused NSException *absent) {
            continue;
        }
        @try {
            [threadConfig setValue:value forKey:key];
            SPKLog(@"Feed", @"[Sparkle] Comment sort order applied through %@", key);
            return;
        } @catch (__unused NSException *readOnly) {
            continue;
        }
    }
    SPKLog(@"Feed", @"[Sparkle] Comment sort order: no writable key on %@",
           NSStringFromClass([threadConfig class]));
}

%group SPKCommentSortHooks

%hook IGCommentConfig

- (id)initWithUserSession:(id)session
       commentThreadConfiguration:(IGCommentThreadConfiguration *)threadConfig
    sponsoredSupportConfiguration:(id)supportConfig
              CTAPresenterContext:(id)context
                        replyText:(id)text
                  loggingDelegate:(id)loggingDelegate
         presentingViewController:(id)vc
       childCommentThreadDelegate:(id)threadDelegate {
    SPKApplyCommentSortOrder(threadConfig);
    return %orig;
}

%end

%end

void SPKInstallCommentSortHooksIfEnabled(void) {
    if ([SPKCommentSortMode() isEqualToString:@"default"])
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCommentSortHooks);
    });
}
