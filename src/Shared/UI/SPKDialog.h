#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKDialogActionStyle) {
    SPKDialogActionStyleDefault,
    SPKDialogActionStyleCancel,
    SPKDialogActionStyleDestructive,
};

@interface SPKDialogAction : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, readonly) SPKDialogActionStyle style;
@property (nonatomic, copy, readonly, nullable) dispatch_block_t handler;

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(SPKDialogActionStyle)style
                        handler:(nullable dispatch_block_t)handler;
@end

// Sparkle's own dialog, in the tweak's material rather than Instagram's.
//
// The card is laid over the window, so it survives a controller being swapped
// underneath it, and it cannot be dismissed by tapping outside: a dialog asks a
// question and one of its buttons has to answer.
@interface SPKDialog : NSObject

+ (void)presentInWindow:(UIWindow *)window
                  title:(NSString *)title
                message:(nullable NSString *)message
                actions:(NSArray<SPKDialogAction *> *)actions;

@end

NS_ASSUME_NONNULL_END
