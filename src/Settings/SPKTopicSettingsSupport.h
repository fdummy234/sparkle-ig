#import <UIKit/UIKit.h>

#import "../Shared/ActionButton/ActionButtonCore.h"
#import "../Shared/ActionButton/SPKActionMenuSection.h"
#import "SPKSetting.h"

// ─────────────────────────────────────────────────────────────────────────────
//  CONVENTION D'ORDRE DES RANGÉES (v2.1)
//
//  Une rangée se place selon la distance que le geste fait parcourir :
//
//     1. interrupteur ......... rien ne s'ouvre, effet immédiat
//     2. porte ................ un paquet d'interrupteurs répondant à UNE même
//                               question ; le menu s'ouvre sur la rangée
//     3. sélecteur de valeur .. menu ou compteur, une seule réponse
//     4. sous-page ............ on quitte l'écran et on y revient
//     5. action ............... quelque chose se produit ; destructif en dernier
//
//  R1 (prioritaire) Ce qui commande précède ce qui obéit. Une rangée dépendante
//                   suit immédiatement son maître, quel que soit son type.
//  R2               À niveau égal, l'échelle ci-dessus.
//  R3 (exception)   La rangée qui EST le sujet de sa section l'ouvre
//                   (Open FLEX Now, Default Feed). Bornée à ce cas.
//  R4 (invariant)   Le bloc final — Action Button puis Confirmations, sans titre
//                   — ne bouge jamais : il s'apprend par répétition.
//  R5               Ce qui ne s'applique pas ne s'affiche pas : une rangée
//                   dépendante porte un `hiddenProvider` qui la retire tant que
//                   son maître est éteint, et son maître porte
//                   `reloadsTableOnSwitchChange` pour qu'elle se déplie en place.
//
//  Une porte n'existe que si l'on peut nommer sa question (« confirmer quoi ? »,
//  « masquer où ? »). Sinon c'est une section, pas un menu.
// ─────────────────────────────────────────────────────────────────────────────

NS_ASSUME_NONNULL_BEGIN

NSDictionary *SPKTopicSection(NSString *header, NSArray *rows, NSString *_Nullable footer);
FOUNDATION_EXPORT CGFloat const SPKSettingsCellIconPointSize;
UIImage *SPKSettingsIcon(NSString *name);
UIImage *SPKSettingsSystemIcon(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight);
SPKSetting *SPKSettingApplyIconTint(SPKSetting *setting, UIColor *_Nullable tintColor);
SPKSetting *SPKSettingApplySelectedMenuIcon(SPKSetting *setting, UIImage *_Nullable fallbackIcon);
SPKSetting *SPKTopicNavigationSetting(NSString *title, NSString *iconName, CGFloat iconSize, NSArray *sections);
/// Wraps a screen's Action Button controls into one navigation row that carries
/// the state in its accessory ("On" / "Off"). Six screens shipped the same
/// three-row section at the top; this puts it behind one row at the bottom.
/// `rows` is whatever that screen had — nothing about the controls changes.
SPKSetting *SPKActionButtonRowSetting(NSString *enabledKey, NSString *_Nullable footer, NSArray<SPKSetting *> *rows);

SPKSetting *SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSource source);
SPKSetting *SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSource source, NSString *topicTitle, NSArray<NSString *> *supportedActions, NSArray<SPKActionMenuSection *> *defaultSections);
UIMenu *SPKReelsTapControlMenu(void);
UIMenu *SPKMainFeedModeMenu(void);
UIMenu *SPKSeenButtonPositionMenu(void);
UIMenu *SPKLastActiveFormatMenu(void);
UIMenu *SPKNavigationIconOrderingMenu(void);
UIMenu *SPKLaunchTabMenu(void);
UIMenu *SPKSwipeBetweenTabsMenu(void);
UIMenu *SPKLiquidGlassTabBarStateMenu(void);
UIMenu *SPKSwipeCloseCommentsDirectionMenu(void);
UIMenu *SPKCacheAutoClearMenu(void);
UIMenu *SPKNotificationProgressSubtitleStyleMenu(void);
UIMenu *SPKNotificationPillPositionMenu(void);
UIMenu *SPKMediaVideoQualityMenu(void);
UIMenu *SPKMediaPhotoQualityMenu(void);
UIMenu *SPKAutoSaveDestinationMenu(void);
UIMenu *SPKAutoSaveVideoQualityMenu(void);
UIMenu *SPKAutoSavePhotoQualityMenu(void);
UIMenu *SPKAutoSaveFilterModeMenu(NSString *filterModeKey, NSString *subjectPlural);
UIMenu *SPKStoryAutoSaveFilterModeMenu(void);
UIMenu *SPKGalleryShortcutTargetMenu(void);
SPKSetting *SPKFeedHeaderButtonDefaultActionNavigationSetting(void);

NS_ASSUME_NONNULL_END
