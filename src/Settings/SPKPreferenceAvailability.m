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

    // The Liquid Glass pref and its tab bar mode also back the pre-iOS 26
    // "Pill-shaped Tab Bar" toggle — the tab bar experiment gates reshape the
    // bar into the floating pill on any iOS, only the glass material is 26+.
    if ([key isEqualToString:kSPKPrefInterfaceLiquidGlass] ||
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
