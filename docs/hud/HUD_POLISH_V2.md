# HUD Achille — matière et lisibilité v2

Livraison du 6 septembre 2026. Implémentation dans Dungeon Draft, sans commit ni modification des règles de combat. Les travaux parallèles sur les personnages, cartes, IA et VFX ne font pas partie de cette intervention.

## Direction et résultat

Le thème garde le langage bronze / mythologie grecque et les trois groupes stables : identité et ressources, actions, fin de tour et outils. La leçon transférée de l'observation de DOFUS est la hiérarchie fonctionnelle et la lisibilité des états, pas la reproduction de ses assets ni une hypothèse sur son code interne.

- Nouvelle matière sombre originale, avec grain discret, biseau et filet intérieur calculés en pixels. Le fond est séparé du contenu et des zones de clic.
- Quatre nouvelles peintures : estoc, balayage, avance, garde. Le sujet et le mouvement restent distincts même sans lire le nom.
- Correction du shader d'icône : la texture était multipliée deux fois. La couleur et l'alpha ne sont désormais appliqués qu'une fois, sans perdre la modulation.
- Suppression des panneaux opaques au-dessus des illustrations. Le nouveau cadre SVG conserve ses bords mais possède un centre réellement transparent.
- Badges de raccourci et de coût plus compacts et proportionnels. Les états cooldown / indisponible / verrouillé conservent davantage l'identité de l'illustration, avec leurs indices non colorés existants.
- Onglets SORTS / OBJETS explicites. L'onglet actif est sélectionné, pas désactivé. Les touches numériques restent liées à la seule barre affichée. Déplacement et Fin de tour ne bougent pas lors de la bascule.
- Sacoche pour l'inventaire et grimoire pour les compétences ; les signaux des boutons restent inchangés.
- Cases d'objets vides harmonisées avec le cadre du personnage : inactives mais sans croix ni barre rouge d'erreur. Un objet réellement indisponible conserve ses indices d'état.
- Titre du tour ajusté à l'espace réellement disponible (13–18 px), sans déplacer le bandeau. Les noms exceptionnellement longs restent consultables au tooltip.
- Description accessible des objets corrigée : leur nom et leur état, sans annonce parasite « Sort, 0 PA ».
- Runner de captures corrigé : une fixture invalide ou un problème de disposition fait désormais échouer la validation.

## Réglages sans repeindre le HUD

Les chemins sont relatifs à la racine du projet. Modifier une ressource puis relancer la scène pour contrôler son rendu.

| Besoin | Ressource / propriété |
|---|---|
| Activer la nouvelle matière ou revenir au châssis précédent | data/ui/hud_visual_skin_achilles_v1.tres → material_enabled |
| Changer la texture et sa présence | material_texture, material_texture_strength (0.38), material_tile_size (256) |
| Ajuster le métal, les chanfreins et les filets | material_edge_highlight, material_rim_width (3), material_corner_cut (13), border_strong_color |
| Réviser palette, contraste, typographies et états | même ressource HudVisualSkinData |
| Largeur / hauteur totale et taille de l'identité | data/ui/combat_hud_layout_run_v1_compact.tres → overall_width (1444), overall_height (140), character_identity_width (486) |
| Déplacer les groupes actions / fin de tour | premium_action_offset (504), premium_turn_offset (1072), en pixels de conception |
| Recaler et élargir la zone des sorts / objets | premium_ability_offset (110), premium_ability_width (430) |
| Taille des portraits, PV, PA/PM, sorts, espacements | portrait_size, health_bar_size, action_resource_badge_size, action_slot_size, action_icon_size, action_slot_spacing |
| Changer seulement l'art d'un personnage | data/ui/achilles_hud_theme_refined.tres → spell_icon_mapping et textures des cadres / outils |

Les paramètres premium sont déclarés dans CombatHUDLayoutData ; les valeurs par défaut restent compatibles avec le châssis Achille compact. Les trois modules décoratifs et les contrôles partagent les mêmes offsets pour limiter la dérive. Ce n'est pas un éditeur libre de contraintes : après une modification importante, relancer la matrice de captures pour détecter collisions et débordements.

Le nom de fichier et le skin_id « v1 » sont conservés pour ne pas casser les références existantes ; la revision de la ressource active est 2. Le mode neutre ne reçoit pas cette matière.

## Assets et provenance

- Peintures actives : asset/ui/recraft_hud_v1/icons/achilles_painted_v2/.
- Matière : asset/ui/recraft_hud_v1/materials/obsidian_bronze_v2/obsidian_bronze_tile.png.
- Cadre : asset/ui/recraft_hud_v1/frames/achilles_v2/spell_slot_frame.svg.
- [Prompts des quatre icônes et originaux](../../asset/ui/recraft_hud_v1/icons/achilles_painted_v2/PROVENANCE.md).
- [Prompt de matière](../../asset/ui/recraft_hud_v1/materials/obsidian_bronze_v2/PROVENANCE.md).

Peintures et matière produites avec image_gen intégré, sans image DOFUS en entrée. Les deux pictogrammes d'outil sont des SVG originaux ; le cadre dérive du cadre Dungeon Draft précédent. Les fichiers v1 sont conservés. Les PNG maîtres ne sont pas réduits ni écrasés ; la réduction de taille se fait par l'import Godot.

Les quatre peintures et la matière maîtres mesurent 1254² px. Les imports de jeu sont respectivement 256² et 512² avec mipmaps, vérifiés dans les caches réellement chargés. Après comparaison visuelle, les slots utilisent le filtrage linéaire sans mipmaps pour préserver le piqué des illustrations ; le matériau de fond utilise ses mipmaps. Estimation RGBA8 des cinq textures stockées : 29,99 → 2,67 Mio (−91,1 %, chaînes mip comprises), hors surcoûts moteur/pilote. Ce n'est ni une mesure VRAM ni un gain de FPS mesuré.

## Vérification et preuves

La validation visuelle utilise un plateau déterministe de test, et non une capture d'une partie de production. Elle vérifie le HUD et ses états, pas le gameplay ni les performances d'une arène réelle.

- [Avant valide](../../artifacts/hud_polish_v2_20260906/before_valid/1672x941/hud_achilles_premium__idle__1672x941.png).
- Le dossier before/ est un diagnostic invalide : la fixture ancienne héritait de Node alors que le modèle courant attend Unit. Ne pas utiliser cette image comme preuve de l'ancien HUD.
- [Galerie finale](../../artifacts/hud_polish_v2_20260906/release/gallery.html).
- [Manifeste avec empreintes et contrôles](../../artifacts/hud_polish_v2_20260906/release/manifest.json).
- [Rectangles et métriques](../../artifacts/hud_polish_v2_20260906/release/layout_metrics.json).
- [Rapport automatique](../../artifacts/hud_polish_v2_20260906/release/validation_report.md).
- Le dossier final/ conserve le diagnostic des 16 collisions du bandeau de ciblage avec les onglets. final_verified/ valide leur correction ; release/ inclut aussi les finitions des cases vides et du titre. Ne pas confondre ces étapes.

Matrice : idle, hover, selected, unavailable, cooldown, locked, targeting_valid, targeting_invalid, resolving, enemy_turn, items. Résolutions : 1280×720, 1200×896, 1672×941, 1920×1080. L'état items contrôle aussi quatre emplacements vides. Le runner exige une fixture complète, des ancres sans chevauchement, le HUD dans le viewport, le texte de contexte ajusté et des onglets valides.

Tests ciblés : test_hud_slot_polish_v2, test_hud_material_polish_v2, test_hud_graybox_interaction_contract, test_recraft_hud_component_states ; plus les sept suites existantes Recraft HUD, skin, timeline, icônes Achille, port, HUD persistant et groupe de trois personnages.

### Résultats de livraison

- **44/44 captures validées**, aucun message stderr dans le rendu de livraison.
- **66/66 tests réussis, 1 123 assertions, 11 suites**, code de sortie 0, après le dernier réglage de filtrage : [journal du 6 septembre à 02:13](../../artifacts/hud_polish_v2_20260906/test_logs/hud_wide_20260906_021304_delivery.stdout.log).
- Les quatre suites ciblées seules : **30/30, 368 assertions**, sortie propre : [journal](../../artifacts/hud_polish_v2_20260906/test_logs/hud_polish_final_20260906_020933.stdout.log).
- Réserve du lot élargi : 417 ObjectDB, 46 ressources et cinq RID restent signalés à la fermeture du moteur. Ces avertissements ont été isolés dans le groupe des suites d'intégration existantes ; leur préexistence avant cette intervention n'est pas prouvée. Ne pas les assimiler à une sortie entièrement propre : [stderr delivery](../../artifacts/hud_polish_v2_20260906/test_logs/hud_wide_20260906_021304_delivery.stderr.log).
- Contrôle de format Git ciblé propre ; HEAD est resté ee6ec92. Aucun commit, stage, reset ou modification des règles de combat effectué.

Relecture visuelle : [repos 1672×941](../../artifacts/hud_polish_v2_20260906/release/1672x941/hud_achilles_premium__idle__1672x941.png), [objets vides 1200×896](../../artifacts/hud_polish_v2_20260906/release/1200x896/hud_achilles_premium__items__1200x896.png), [recharge 1280×720](../../artifacts/hud_polish_v2_20260906/release/1280x720/hud_achilles_premium__cooldown__1280x720.png), [résolution 1920×1080](../../artifacts/hud_polish_v2_20260906/release/1920x1080/hud_achilles_premium__resolving__1920x1080.png). Le gain de distinction des silhouettes est un jugement visuel ; aucun test de reconnaissance chronométré n'a été réalisé.

Commande de capture, avec un vrai renderer (headless seul ne produit pas de framebuffer) :

```text
Godot --path <repo> --display-driver windows --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --scene res://tools/ui_snapshots/HudGrayboxCaptureRunner.tscn -- --premium-achilles --output-root=res://artifacts/hud_polish_v2_20260906/release
```

Commande de test ciblée :

```text
Godot --headless --path <repo> --script res://addons/gut/gut_cmdln.gd -- -gconfig= -gexit -gdisable_colors -gtest res://test/unit/test_hud_material_polish_v2.gd -gtest res://test/unit/test_hud_slot_polish_v2.gd
```

## Limites et suites pertinentes

- Ce travail ne remplace pas un test utilisateur de découverte des icônes ; leur reconnaissance est une appréciation visuelle, pas un temps de réaction mesuré.
- Les états statiques sont contrôlés ; ni l'ensemble des transitions animées, ni les lecteurs d'écran, ni toutes les langues / échelles système ne sont certifiés.
- Le shader de fond respecte la modulation, ne lit pas l'écran et n'utilise pas de bruit temporel. Aucun gain de FPS n'est revendiqué sans mesure.
- La barre premium vise quatre capacités actives ; un futur personnage avec davantage de capacités nécessite sa propre calibration.
- Les nouveaux pictogrammes et peintures concernent Achille. Les corrections de composants bénéficient aux autres usages des mêmes slots, sans réécrire leurs thèmes.
- La vue Sorts / Objets conserve sa sélection entre tours, comme avant ; cette intervention ne change ni activation d'objet, ni coût, ni cooldown, ni résolution de combat.
