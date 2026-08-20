#import "SPKPreferenceAvailability.h"

#import <UIKit/UIKit.h>

#import "../App/SPKFlexLoader.h"
#import "SPKPreferences.h"

static BOOL SPKIsIOSVersionAtLeast(NSString *version) {
    return [[[UIDevice currentDevice] systemVersion] compare:version options:NSNumericSearch] != NSOrderedAscending;
}

BOOL SPKPrefIsAvailable(NSString *key) {
    if (key.length == 0)
        return YES;

    // Taking the glass away works on any iOS: the flags it answers reshape the
    // bar everywhere, and only the material itself is 26+.
    if ([key isEqualToString:kSPKPrefInterfaceDisableLiquidGlass] ||
        [key isEqualToString:kSPKPrefInterfaceLiquidGlassTabBarMode]) {
        return YES;
    }

    // Progressive blur relies on UIScrollEdgeEffect, which only exists on iOS 26+.
    if ([key isEqualToString:kSPKPrefInterfaceProgressiveBlur]) {
        return SPKIsIOSVersionAtLeast(@"26.0");
    }

    if ([key isEqualToString:@"notifs_pill_liquid_glass"]) {
        return SPKIsIOSVersionAtLeast(@"26.0");
    }

    if ([key isEqualToString:kSPKPrefInstantsDisableCameraControl]) {
        return SPKDeviceHasCameraControl();
    }

    if ([key hasPrefix:@"tools_flex_"]) {
        return SPKFlexIsBundled();
    }

    return YES;
}
