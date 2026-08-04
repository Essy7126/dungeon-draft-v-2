# Refonte du choix d’équipement post-combat

Date de validation : 4 août 2026  
Branche : `main`  
HEAD de départ et de fin : `12cff061992c0db99633e4203687b17efdc39e0a`

## Verdict

Le flux post-combat actif présente désormais exactement deux grandes cartes d’équipement en plein écran, au-dessus d’une image figée du champ de bataille. Le choix est explicite, doit être confirmé, ajoute une seule instance dans l’inventaire partagé et n’équipe jamais automatiquement l’objet. Les anciennes récompenses génériques restent définies pour compatibilité, mais ne sont plus instanciées ni affichées dans le flux normal.

Le socle est fonctionnel et validé aux résolutions 1280 × 720, 1920 × 1080 et 2560 × 1440. Il reste un blocage de contenu avant une validation « production » complète : plusieurs images de cartes contiennent des textes de gameplay différents des définitions `.tres`. Le runtime utilise bien les `.tres` comme autorité ; les visuels devront toutefois être régénérés sans texte de règles, ou réalignés avec les données, afin de ne pas induire le joueur en erreur.

## 1. État Git et protection du travail existant

Le dépôt était déjà sale avant l’intervention. Les changements préexistants liés à l’arène dynamique ont été laissés intacts :

- `core/grid_data.gd` ;
- `core/pathfinder.gd` ;
- `test/unit/test_dynamic_arena.gd` ;
- `tools/labs/dynamic_arena/` ;
- `battle/dynamic_terrain/` ;
- `tools/labs/forest_dynamic_grid/` ;
- les images normalisées et brutes de murs dynamiques.

Aucun changement de branche, stage, commit ou push n’a été effectué. L’index Git est resté vide. Les captures se trouvent sous `artifacts/`, répertoire volontairement ignoré par `.gitignore`.

## 2. Audit de l’existant

### Flux avant la refonte

`PostCombatScreen` possédait déjà une séquence sûre : victoire, statistiques, progression, récompense, transition. Le service `FirstRunEquipmentRewardService` savait déjà construire une offre de deux équipements, mais l’écran conservait les structures de l’ancienne présentation et l’attribution équipait automatiquement l’objet sur un héros choisi.

Les trois anciennes récompenses génériques — soin d’équipe, bonus de PV maximum et bouclier différé — sont toujours portées par `PostCombatRewardService` et ses tests historiques. Elles ne sont plus appelées par l’étape `REWARD_SELECTION` du flux actif.

### Inventaire et équipement

L’architecture réelle utilise :

- un `RunInventory` partagé de 24 emplacements ;
- un `EquipmentLoadout` propre à chaque héros ;
- des `ItemDefinition` et `ItemInstance` existants ;
- un `EquipmentService` qui reste l’unique autorité d’équipement ;
- des snapshots inventaire/équipement et une sauvegarde JSON partielle existante dans `GameManager`.

La récompense suit donc l’architecture réelle : elle entre dans l’inventaire partagé. Le premier héros compatible n’est conservé que comme métadonnée d’attribution ; aucun loadout n’est modifié.

### Salle finale

Le comportement existant est conservé : la dernière salle ne génère aucune offre d’équipement et route vers `RunResultScreen`. Cette règle est appliquée à la fois lors de la construction de l’offre et lors de la confirmation.

## 3. Architecture finale

```text
GameManager
├── capture du dernier rendu du combat
├── FirstRunEquipmentRewardService
│   ├── deck déterministe par seed
│   ├── offre de 2 ItemDefinition
│   ├── sélection mémorisée
│   ├── attribution transactionnelle à RunInventory
│   └── snapshot/restauration de l’état de récompense
└── PostCombatScreen
    ├── victoire
    ├── statistiques
    ├── progression et nœuds acquis
    ├── EquipmentRewardOverlay
    │   ├── post-traitement du fond
    │   ├── RewardCardChoice gauche
    │   ├── RewardCardChoice droite
    │   ├── confirmation
    │   └── erreur contrôlée
    └── transition unique vers la salle suivante
```

Principaux points d’entrée :

- capture et snapshot : `core/game_manager.gd` ;
- offre, validation, persistance et attribution : `data/post_combat/first_run_equipment_reward_service.gd` ;
- orchestration des phases : `ui/post_combat/post_combat_screen.gd` ;
- présentation plein écran : `ui/post_combat/equipment_reward_overlay.gd` ;
- comportement visuel d’une carte : `ui/post_combat/reward_card_choice.gd`.

## 4. Flux après la refonte

```text
Victoire
→ statistiques du combat
→ progression récapitulative
→ nœuds acquis
→ deux cartes d’équipement
→ sélection sans attribution
→ confirmation explicite
→ ajout d’une instance à l’inventaire partagé
→ animation courte
→ salle suivante
```

Pendant `REWARD_SELECTION`, l’ancien panneau est toujours présent dans la scène pour limiter le risque de régression, mais il est systématiquement caché et aucun ancien bouton de récompense n’est construit. `SafeMargin` et le panneau principal sont masqués ; l’overlay plein écran est le seul consommateur des entrées.

Le combat est déjà finalisé avant l’ouverture. La scène de combat est remplacée par l’écran post-combat, tandis que sa dernière image est capturée et affichée derrière l’overlay. Le HUD courant n’est plus interactif. `Échap` est consommé et ne peut pas abandonner la récompense.

## 5. Données et tirage

Les quatorze définitions marquées `first_run_equipment_reward` restent l’unique source de vérité :

- Anneau de la faille ;
- Arc maudit ;
- Broche ;
- Caillou ;
- Cape de brume ;
- Collier des sages ;
- Couronne ;
- Excalibur ;
- Hache de l’exécuteur ;
- Harnois ;
- Manteau de givre ;
- Matraque de troll ;
- Prisme élémentaire ;
- Sceau.

`ItemDefinition` expose désormais :

- `inventory_icon`, avec repli sur `icon` ;
- `card_texture`, avec repli sur `icon` ;
- `reward_fx_profile` ;
- `reward_audio_profile`.

Le tirage :

- est déterministe à partir de la seed de run ;
- produit exactement deux `item_id` distincts ;
- filtre tout objet incompatible avec l’ensemble du trio ;
- écarte les objets déjà possédés ou déjà proposés ;
- évite, lorsque le pool le permet, deux objets visant la même audience et le même slot ;
- conserve l’ordre de l’offre pour le rapport de combat concerné ;
- ne produit aucune offre pour la dernière salle.

## 6. Persistance et idempotence

Le snapshot inventaire/équipement est passé en version 2 et inclut désormais `equipment_reward`. Cet état contient :

- le deck restant ;
- les identifiants éligibles, proposés et écartés ;
- `options_by_report`, donc les deux cartes dans leur ordre exact ;
- `selected_by_report`, y compris avant confirmation ;
- `reward_states_by_report` avec `offered`, `selected` ou `confirmed` ;
- les rapports déjà appliqués.

La restauration reconstruit d’abord un service candidat, revalide chaque définition et chaque compatibilité, puis remplace l’état actif seulement si l’ensemble du snapshot est cohérent. Une récompense confirmée doit posséder une sélection valide. Une seconde application du même rapport est refusée.

La sélection non confirmée est également restaurée visuellement lorsque l’écran est rouvert. Le projet possède déjà `save_inventory_equipment_state()` et `load_inventory_equipment_state()` pour écrire ce snapshot en JSON.

Limite : il ne s’agit pas encore d’une sauvegarde complète de run. Le fichier partiel ne restaure ni la scène courante ni l’intégralité du combat. Le nouvel état est sérialisable et prêt à être inclus dans la future sauvegarde globale, mais cette refonte n’invente pas un second système de checkpoint parallèle.

## 7. Attribution à l’inventaire

L’attribution passe exclusivement par `RunInventory.try_add()` :

1. l’offre et l’`item_id` sont revalidés ;
2. la compatibilité avec au moins un héros est revalidée ;
3. l’inventaire vérifie sa capacité avant toute mutation ;
4. une seule instance est ajoutée ;
5. le rapport est marqué comme appliqué uniquement après le succès ;
6. `equipped` vaut explicitement `false`.

En cas d’inventaire plein, la confirmation reste sur l’écran, affiche l’erreur renvoyée par l’inventaire et ne marque pas la récompense comme appliquée. Après libération d’un emplacement, le même choix peut être confirmé avec succès. Aucun mécanisme d’overflow n’existe actuellement ; le blocage contrôlé est donc la politique retenue.

## 8. Présentation et interactions

### État neutre

- deux cartes centrées ;
- angles de repos de −1,5° et +1,5° ;
- flottement maximal de 3 px ;
- bouton de confirmation désactivé.

### Hover ou focus

- échelle 1,048 ;
- remontée de 14 px ;
- rotation ramenée à 0° ;
- halo et ombre renforcés ;
- carte sœur légèrement atténuée ;
- aucune sélection automatique.

### Sélection

- échelle 1,085 ;
- remontée de 24 px ;
- badge textuel « sélectionné » ;
- contour lumineux suivant l’alpha ;
- halo, poussières et light sweep ;
- carte sœur à 0,96, luminosité 0,64 et saturation 0,44.

### Confirmation

- verrouillage immédiat des deux cartes et du bouton ;
- carte choisie portée vers 1,11 ;
- carte rejetée réduite à 0,91 et écartée latéralement ;
- durée normale de 0,62 s, réduite à 0,22 s en mouvement réduit ;
- signal de transition émis une seule fois.

La souris, les actions `ui_left`, `ui_right`, `ui_accept` et le focus Godot couvrent clavier et manette. `ui_cancel` est absorbé. Un double clic sur une carte ne confirme jamais : il faut utiliser le bouton de validation.

## 9. Shaders et responsive

`reward_card.gdshader` expose saturation, luminosité, contraste, teinte, intensité/couleur du contour, progression/intensité du sweep et niveau de sélection. Il ne déforme pas la texture et préserve donc la lisibilité du texte intégré.

`post_combat_background.gdshader` lit la texture d’écran et applique assombrissement, désaturation, teinte froide et vignette. Aucun blur coûteux n’a été ajouté.

La hauteur de carte est calculée à partir de la hauteur du viewport, bornée entre 410 et 735 px, puis limitée horizontalement. Le ratio visuel 0,535 est conservé. L’espacement varie entre 56 et 110 px. À 720p, les cartes et le titre sont réduits ; à 1440p, la hauteur maximale empêche une croissance disproportionnée.

## 10. Mode `reduced_motion`

Le mode est disponible par propriété et dans le laboratoire. Il désactive le flottement et les particules, coupe le light sweep et remplace les animations longues par des transitions immédiates ou courtes. La sélection reste reconnaissable par l’échelle, la position, le contour, le badge et l’état du bouton ; la couleur n’est pas le seul signal.

## 11. Audio et profils VFX

Les événements d’apparition, de sélection et de confirmation utilisent `AudioManager`, avec un son feutré existant à des niveaux distincts. Aucun fichier audio factice n’a été créé. Aucun son de dissolution convenable n’ayant été identifié, le point de rejet reste visuel.

Les définitions acceptent déjà des profils `generic`, `steel`, `ice`, `nature`, `arcane` et `necrotic`. La première version conserve un langage commun ambre/cyan et évite quatorze effets spécifiques prématurés.

Recommandation pour la suite : créer une ressource `EquipmentRewardFxProfile` data-driven associant couleurs, texture de fumée, texture de particule, intensité du sweep et événements audio. Ajouter ensuite `fire` lorsque le catalogue contient réellement une famille feu cohérente.

## 12. Audit des assets

Les quatorze PNG de `data/items/catalogs/` mesurent 1376 × 768. Treize déclarent un format 32 bits avec alpha ; `matraque_troll.png` est un RGB 24 bits sans alpha. Les cartes portrait sont centrées dans de grandes images paysage contenant des marges noires/opaques.

Les sources n’ont pas été modifiées, conformément à la contrainte d’audit préalable. `RewardCardChoice` détecte au runtime le rectangle non noir, crée un `AtlasTexture` recadré et met le résultat en cache. Le ratio de la carte utile est ensuite préservé. Une texture absente produit un fallback sombre, lisible, sélectionnable et journalisé.

### Non-conformité de contenu critique

Certaines cartes ont du texte gameplay déjà rasterisé qui ne correspond pas aux `.tres`. Exemples observés :

- `arc_maudit.png` annonce +30 % de critique à distance, tandis que `arc_maudit.tres` définit +20 % de dégâts de sorts offensifs et −10 PV maximum ;
- `excalibur.png` annonce +30 % de vol de vie en montagne, tandis que `excalibur.tres` définit +15 % de dégâts physiques et +20 armure.

La logique ne lit jamais ces pixels et applique exclusivement les modificateurs des ressources. Néanmoins, le joueur lirait une promesse différente de l’effet réel. Avant livraison publique, il faut régénérer les cartes avec texte synchronisé ou, de préférence, générer le nom et la description par l’UI sur un visuel sans règles rasterisées. Il faut aussi produire de vraies icônes d’inventaire carrées : la version actuelle utilise le repli sur l’image de carte.

## 13. Laboratoire

`tools/labs/equipment_reward/EquipmentRewardPresentationLab.tscn` fonctionne sans combat réel et permet :

- ouverture et réouverture ;
- hover, sélection gauche/droite et confirmation ;
- navigation clavier/manette ;
- bascule 720p, 1080p et 1440p ;
- `reduced_motion` ;
- texture absente ;
- fausses marges opaques ;
- inventaire plein.

Raccourcis du laboratoire : F1/F2/F3 pour les résolutions, Q/E pour les cartes, R pour le mouvement réduit, M pour la texture absente, A pour les mauvaises marges et O pour l’inventaire plein.

## 14. Captures

Les captures ont été générées avec le renderer OpenGL réel et la validation `EQUIPMENT_REWARD_CAPTURE_VALIDATION=PASS` :

1. `artifacts/equipment_reward_presentation/captures/01_neutral.png` ;
2. `02_hover_left.png` ;
3. `03_selected_left.png` ;
4. `04_selected_right.png` ;
5. `05_confirmation.png` ;
6. `06_resolution_720p.png` ;
7. `07_resolution_1080p.png` ;
8. `08_resolution_1440p.png` ;
9. `09_reduced_motion.png` ;
10. `10_missing_texture_fallback.png`.

Ces fichiers sont locaux et ignorés par Git. Le script de capture reste versionnable et permet de les régénérer.

## 15. Tests exécutés

### Tests ciblés finaux

- `test_equipment_reward_presentation.gd` : 5/5, 36 assertions ;
- `test_post_combat_flow.gd` : 17/17, 200 assertions ;
- `test_first_run_v2_contract.gd` : 10/10, 2 163 assertions.

Total ciblé final : 32/32 tests, 2 399 assertions.

Couverture : deux objets distincts, filtrage et deck, absence de récompense finale, persistance de l’offre, persistance de la sélection non confirmée, non-duplication après application, absence d’auto-équipement, inventaire plein puis reprise, séquence statistiques/progression/nœuds, double confirmation, `Échap`, hover, focus, fallback, mouvement réduit et trois résolutions.

### Faisceau de non-régression ciblé

Les suites inventaire/équipement et progression déjà présentes ont été exécutées : 61/61 tests, 636 assertions.

### Suite complète

La dernière passe complète a exécuté 553 tests : 550 passent et 3 échouent hors périmètre de cette refonte :

- `test_dark_pause_menu.gd::test_theme_uses_distinct_texture_states_and_focus_style` : deux textures de focus absentes ;
- `test_mage_thunderstorm_visual_calibration.gd::test_visual_impact_stays_near_point_three_one_and_emits_exactly_once` ;
- `test_painted_unit_presence.gd::test_exports_de_validation_sont_presents_aux_trois_resolutions` : exports de validation manquants.

Les trois fichiers en échec n’ont pas été modifiés par cette intervention. La passe ciblée de la nouvelle interface est entièrement verte.

## 16. Fichiers ajoutés

- `ui/post_combat/EquipmentRewardOverlay.tscn` ;
- `ui/post_combat/equipment_reward_overlay.gd` ;
- `ui/post_combat/RewardCardChoice.tscn` ;
- `ui/post_combat/reward_card_choice.gd` ;
- `ui/post_combat/shaders/reward_card.gdshader` ;
- `ui/post_combat/shaders/post_combat_background.gdshader` ;
- `test/unit/test_equipment_reward_presentation.gd` ;
- `tools/labs/equipment_reward/EquipmentRewardPresentationLab.tscn` ;
- `tools/labs/equipment_reward/equipment_reward_presentation_lab.gd` ;
- `tools/labs/equipment_reward/CaptureEquipmentRewardPresentation.tscn` ;
- `tools/labs/equipment_reward/capture_equipment_reward_presentation.gd` ;
- ce rapport.

Les fichiers `.uid` associés ont été générés par Godot.

## 17. Fichiers modifiés

- `core/game_manager.gd` ;
- `data/items/item_definition.gd` ;
- `data/post_combat/first_run_equipment_reward_service.gd` ;
- les quatorze définitions `.tres` de la première run ;
- `ui/inventory/inventory_screen.gd` ;
- `ui/post_combat/PostCombatScreen.tscn` ;
- `ui/post_combat/post_combat_screen.gd` ;
- `test/unit/test_post_combat_flow.gd` ;
- `test/unit/test_first_run_v2_contract.gd` ;
- `tools/capture_post_combat_flow.gd`.

## 18. Limites et prochaines étapes

Priorité 1 — contenu :

1. réaligner les textes des quatorze cartes sur les `.tres`, idéalement en retirant les règles des bitmaps ;
2. générer quatorze icônes carrées d’inventaire séparées ;
3. remplacer le son temporairement partagé par quatre événements validés : apparition, hover, sélection, confirmation/rejet.

Priorité 2 — intégration :

1. intégrer `equipment_reward` à la future sauvegarde complète de run ;
2. supprimer définitivement les nœuds et méthodes mortes de l’ancien panneau après une passe de migration dédiée ;
3. masquer le HUD une frame avant la capture si l’on veut garantir qu’aucun élément du HUD ne soit rasterisé dans le fond figé ;
4. exposer `reduced_motion` dans les réglages du joueur.

Priorité 3 — finition :

1. créer des profils VFX sous forme de ressources ;
2. ajouter un véritable son de dissolution ;
3. tester la composition sur ultrawide et avec les polices/localisations finales.

## Conclusion

Le nouveau parcours est intégré sans modifier la logique de dernière salle ni l’équipement visuel des personnages. Il satisfait le contrat fonctionnel principal : deux cartes, sélection puis confirmation, attribution unique et transactionnelle à l’inventaire, persistance de l’offre et du choix, responsive, clavier/manette, fallback et mouvement réduit. La seule réserve critique porte sur la cohérence éditoriale des textes déjà incorporés aux images.
