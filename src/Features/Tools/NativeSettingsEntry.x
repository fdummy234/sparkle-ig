#import "../../Utils.h"
#import <objc/runtime.h>

// L'entrée ✦ de Sparkle dans l'écran « Settings and activity » d'Instagram.
//
// CE QUI A ÉCHOUÉ, ET QU'IL NE FAUT PAS REFAIRE : la version précédente
// crochetait -[UINavigationBar layoutSubviews] pour poser un UIButton en
// sous-vue et l'aligner sur le libellé du titre. Deux coûts, à CHAQUE passe de
// layout : un parcours complet de la hiérarchie SwiftUI de la barre pour
// trouver ce libellé, et un bringSubviewToFront: qui resalissait le layout donc
// redéclenchait la passe. L'écran des réglages en devenait très lent à ouvrir.
// Trois tentatives d'alléger ce parcours ont toutes échoué : le borner par
// nombre de nœuds ratait le titre, le borner par profondeur aussi — il est plus
// profond que cinq niveaux.
//
// CETTE VERSION NE FAIT RIEN PAR IMAGE. Le bouton redevient un UIBarButtonItem,
// posé sur le navigationItem quand l'écran apparaît. UIKit le place lui-même :
// aucun parcours, aucun calcul de hauteur, aucun crochet sur le layout.
//
// Le commentaire d'origine écartait cette approche en supposant que SwiftUI
// possède sa barre et la reconstruit. MESURÉ SUR L'APPAREIL, c'est faux pour cet
// écran : l'item posé survit (« survived: YES »), la barre est une
// IGNavigationBar et le contrôleur n'a aucun autre bouton à droite. Une seule
// pose par apparition suffit donc, contre soixante par seconde auparavant.
//
// Le contrôleur est une générique Swift —
// _TtGC14Settings2Views27IGSettingsHostingControllerVS_19IGSettingScreenView_ —
// dont le nom varie selon la spécialisation. On ne la crochète donc pas
// directement : le strstr sur « IGSettingsHostingController » traverse le nom
// mangé et coûte quelques nanosecondes.

static const void *kSPKSettingsEntryItemAssocKey = &kSPKSettingsEntryItemAssocKey;

@interface SPKNativeSettingsEntryTarget : NSObject
+ (instancetype)sharedTarget;
- (void)openSparkleSettings:(id)sender;
@end

@implementation SPKNativeSettingsEntryTarget

+ (instancetype)sharedTarget {
    static SPKNativeSettingsEntryTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [SPKNativeSettingsEntryTarget new];
    });
    return target;
}

- (void)openSparkleSettings:(id)sender {
    [SPKUtils showSettingsVC:UIApplication.sharedApplication.keyWindow];
}

@end

// Reconnu par deux signaux indépendants, pour qu'un renommage d'un côté ne
// suffise pas à tout casser : le nom de classe Swift, ou le titre de l'écran.
static BOOL SPKIsNativeSettingsController(UIViewController *controller) {
    if (!controller)
        return NO;
    const char *name = class_getName(object_getClass(controller));
    if (name && strstr(name, "IGSettingsHostingController"))
        return YES;
    return [controller.title isEqualToString:@"Settings and activity"];
}

static void SPKSeatSettingsEntryItem(UIViewController *controller) {
    if (!SPKIsNativeSettingsController(controller))
        return;

    UIBarButtonItem *existing = objc_getAssociatedObject(controller, kSPKSettingsEntryItemAssocKey);
    NSArray<UIBarButtonItem *> *right = controller.navigationItem.rightBarButtonItems;
    if (existing && [right containsObject:existing])
        return;   // déjà en place : rien à faire

    UIImage *icon = [UIImage systemImageNamed:@"sparkles"
                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                              weight:UIImageSymbolWeightRegular]];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:icon
                                                            style:UIBarButtonItemStylePlain
                                                           target:[SPKNativeSettingsEntryTarget sharedTarget]
                                                           action:@selector(openSparkleSettings:)];
    item.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    item.accessibilityLabel = @"Sparkle";
    objc_setAssociatedObject(controller, kSPKSettingsEntryItemAssocKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSMutableArray<UIBarButtonItem *> *items = right ? [right mutableCopy] : [NSMutableArray array];
    [items insertObject:item atIndex:0];
    controller.navigationItem.rightBarButtonItems = items;

    // Trois faits que seul l'appareil peut donner : sur QUELLE classe on a posé
    // l'item, s'il y avait déjà des boutons à droite, et — au tour suivant — si
    // le nôtre a SURVÉCU à la reconstruction de SwiftUI.
    SPKLog(@"Settings", @"[Sparkle] entry seated on %@ · existing right items: %lu · nav bar: %@",
           NSStringFromClass([controller class]),
           (unsigned long)right.count,
           NSStringFromClass([controller.navigationController.navigationBar class] ?: [NSNull class]));
}

%group SPKNativeSettingsEntryHooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!SPKIsNativeSettingsController(self))
        return;

    SPKSeatSettingsEntryItem(self);

    // Pas de reprise différée : mesuré sur l'appareil, « survived: YES » — la
    // barre SwiftUI de cet écran n'écrase PAS le navigationItem. Une seule pose
    // par apparition suffit.
}

%end

%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    // Cet installeur fait partie des « essentiels » (SPKStartupHooks.m:117), donc
    // « Turn Off All Features » ne le saute PAS. Sans sa propre préférence, il
    // n'existait aucun moyen de le retirer pour mesurer ce qu'il coûte.
    if (![SPKUtils getBoolPref:@"tools_settings_entry"])
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNativeSettingsEntryHooks);
    });
}
