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
// Le commentaire d'origine écartait cette approche parce que SwiftUI possède sa
// barre d'outils et la reconstruit pendant que la vue se pose. La parade n'est
// pas de lutter à chaque image : c'est de reposer l'item UNE fois à
// l'apparition, puis une seule fois de plus une fraction de seconde après, le
// temps que SwiftUI ait fini. Deux poses bornées, contre soixante par seconde.

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

    // Une seule reprise, le temps que SwiftUI ait fini de reconstruire sa barre.
    // Bornée à une fois par apparition : ce n'est pas une boucle.
    __weak UIViewController *weakController = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (!strongController)
            return;
        UIBarButtonItem *ours = objc_getAssociatedObject(strongController, kSPKSettingsEntryItemAssocKey);
        BOOL survived = ours && [strongController.navigationItem.rightBarButtonItems containsObject:ours];
        SPKLog(@"Settings", @"[Sparkle] entry survived SwiftUI rebuild: %@", survived ? @"YES" : @"NO");
        SPKSeatSettingsEntryItem(strongController);
    });
}

%end

%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNativeSettingsEntryHooks);
    });
}
