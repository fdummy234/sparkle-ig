#pragma once

#import "../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// The "+" of Configure Menu: everything the surface can do that is in no zone
// yet. Multiple selection, "Add (n)" files them under "Not in the Menu".
@interface SPKActionCatalogViewController : UIViewController

- (instancetype)initWithConfiguration:(SPKActionButtonConfiguration *)configuration
                             onChange:(dispatch_block_t)onChange;

@end

NS_ASSUME_NONNULL_END
