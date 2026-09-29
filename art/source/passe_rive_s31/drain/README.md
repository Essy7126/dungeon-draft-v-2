# Prélèvement — directions S31

La carte t07 conserve son geste approuvé : viser, saisir, ramener la main au sternum et relâcher. Huit vues dessinées, aucun miroir, même horloge de 940 ms et résolution à 330 ms. SE conserve son atlas S28.

Les sources ont été générées avec imagegen intégré, à partir des repos natifs. Prompts et itérations conservés dans `sources/`. Sélection : E issu de E/W v01, W v02 repris seul, NW issu de NE/NW v01, NE v03 corrigé séparément, S/N v01, SW v03. Les premières vues NE/SW/W avaient un mauvais bras ou une ambiguïté et ont été rejetées ou corrigées. E réutilise la pose basse 1 au créneau 9, comme le SE historique ; NW maintient la pose 7 au créneau 8. Les durées des douze créneaux restent identiques.

Les outils mesurent les régions opaques, enregistrent appuis et mains, et copient les PNG sans repeindre leurs pixels. Échelle anatomique fixe par atlas, palette corrigée par matière et bref fondu vers le repos natif. Le filament conserve sa taille physique approuvée malgré les résolutions différentes des dessins. La cible mondiale et la main courante sont converties dans son espace propre à chaque pose.

Seuls des PV réellement retirés déclenchent le flux violet. Seul un soin effectif déclenche l'éclat à la main. Aucune seconde résolution au retour ; annulation et changement de mode nettoient le tout.

Outils : `tools/class_card_vfx/passe_rive_drain_directions/`. `capture_poses.ps1` produit les huit vues et un repère orange de main, uniquement pour diagnostic. `play.ps1 -Capture` prépare 33 lancers réels : normal/amélioré, PV pleins et bouclier intégral dans huit orientations, puis un coup fatal en SE. Le banc suspend l'IA et diffère la victoire pour ce dernier cas.

Les vues de dos masquent naturellement une partie de la main ramenée au torse. Les contours et les fondus restent perceptibles au ralenti ; cette V1 ne garantit pas une identité de pixels entre les dessins.
