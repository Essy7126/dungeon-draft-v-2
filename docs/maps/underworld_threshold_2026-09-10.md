# Le Seuil des Ombres — entrée avant la run

Mission du 10 septembre 2026. Base observée : `2473c335fc11ccb8dfe1cb8257b0a4ee406d1788` ; dépôt déjà modifié par plusieurs tâches, modifications conservées.

## Composition retenue

La seule source retenue est `art/source/halts/underworld_threshold_v1/ash/painting_original.png` (1672 × 941). Achille traverse une grande clairière de terre noire brûlée, avec de larges allées entre Hadès, Zeus et Héra, puis rejoint la porte des Ombres. La peinture suit `roots_bronze_v1`, avec le sanctuaire émeraude comme référence de traitement pictural ; le thème reste celui des Enfers, avec pierre ancienne, bronze, braises et fumées discrètes.

Les images du dossier parent — dont la plateforme suspendue — et la forêt végétalisée du sous-dossier `grounded/` sont des candidats rejetés conservés pour la provenance. Leurs plans, calques et calibrations ne décrivent pas la composition finale `ash`.

## Parcours public et sauvegarde

**Nouvelle partie → sélection de l’apparence d’Achille → cinématique, complète ou passée → Seuil des Ombres → run.** Le joueur clique pour marcher. Les trois plaques peintes des socles sont directement cliquables : Hadès (`statue_memory`), Zeus (`zeus_memory`) et Héra (`fallen_oath`). Achille rejoint d’abord un point d’approche praticable, puis le souvenir s’ouvre. La surface peinte de la porte est également cliquable : l’approche mène à `threshold_gate`, puis « Franchir le seuil » déclenche le départ.

Le chemin restant et son point d’arrivée sont visibles pendant la marche. Un clic proche du sol praticable peut être rapproché de celui-ci ; une destination trop éloignée ou sans trajet est refusée avec un message. La trajectoire contourne les obstacles et contrôle chaque segment avec la marge des pieds. Achille accélère et freine, notamment aux virages et à l’arrivée. **Clic droit** arrête la marche ; **E** active le repère proche ; **Échap** ferme un souvenir ou ouvre le menu. Le menu permet la réduction des animations et le retour à l’accueil.

Chaque repère distingue `hit_polygon` (plaque ou porte visible), `focus` (centre de clic) et `point` (position sûre des pieds). `threshold_interactions.gd` donne priorité au polygone peint et conserve le comportement `focus`/`radius` des anciennes définitions sans polygone. `threshold_navigation.gd` limite l’aide au clic à cette entrée ; les règles du moteur commun restent conservées.

La configuration choisie reste disponible pendant cette visite ; la run est créée au franchissement de la porte. L’annulation conserve la sauvegarde précédente. Le consentement au remplacement est revérifié au départ ; si le premier enregistrement échoue, la tentative suivante réenregistre la même expédition préparée. La reprise depuis l’accueil rejoint directement la sauvegarde existante, sans rejouer la cinématique ni le seuil. Ces comportements sont implémentés ; leur validation finale est en cours.

## Plan, proportions et calques

La maquette est construite dans la collection `Threshold ash generated`, dans l’instance Blender privée sur `127.0.0.1:9877`. Le corps de référence d’Achille mesure 1,80 m. Les centres des socles sont coplanaires et forment un triangle équilatéral de **8 m de côté** : Hadès (−4 ; 1,5), Zeus (4 ; 1,5), Héra (0 ; 1,5 − 4√3). `projection.json` conserve le plan et les trois distances.

La peinture est recalée par une transformation affine du sol passant par les centres des trois **empreintes de socle**, consignés dans `registration.json`. Le quatrième coin arrière est inféré par parallélogramme : incertitude visuelle estimée à **±2 pixels**. Les centres apparents des corps et les points avant-bas utilisés pour le tri d’occultation sont des repères distincts. Les 8 m sont une contrainte du plan et de ce recalage ; trois correspondances ne mesurent pas une éventuelle déformation locale de la peinture.

Le manifeste final fixe `world.width = 2600`, `world.player_height_ratio = 0.164` et `foot_clearance = 22`. H désigne la hauteur pieds → sommet de la silhouette `idle_S`, lance et plumet compris. Sur l’image de 941 pixels de haut, H vaut environ 154,3 pixels ; avec le gabarit 202/257, le corps de référence vaut environ 121,3 pixels.

`threshold_ash_layers.ora` sépare les trois statues, leurs raccords de sol et le fond reconstruit localement à partir de `clean_plate_original.png`. Les pixels des objets viennent de la peinture originale. Les ombres sont des raccords RGB opaques : déplacer une statue exige de retoucher son raccord. Les guides géométriques masqués sont des références **avant peinture**, pas des masques déjà recalés. Voir `ash/LAYER_EDITING.md` et `ash/layer_selections.json` pour les contours, ancres et limites.

## Préparation et commandes

Les commandes suivantes se lancent depuis la racine, avec Python disposant de Pillow et NumPy. Le client privé vérifie la session, le PID, le fichier et le port avant l’exécution Blender. Le script de construction reconstruit uniquement sa collection générée ; la génération native de la peinture et du clean plate, puis leur revue, restent des étapes séparées.

```powershell
python tools/blender_halt_lab/client.py tools/blender_halt_lab/build_threshold_ash.py
python tools/blender_halt_lab/client.py --timeout 120 tools/blender_halt_lab/export_guides.py
# Après conservation des originaux et calibration dans ash/ :
python tools/blender_halt_lab/package_layers.py --source art/source/halts/underworld_threshold_v1/ash
python tools/blender_halt_lab/prepare_threshold.py
```

`prepare_threshold.py` vérifie les dimensions et le hash de l’original, conserve ses octets dans `asset/map/painted/halts/underworld_threshold_v1/threshold_ash.png`, reprend les silhouettes peintes et prépare `data/halts/underworld_threshold_v1.json` avec les masques de matériaux et le build canonique.

## Shaders du Seuil

`threshold_materials.gdshader` anime les deux braseros de cette map sèche : mouvement des pixels lumineux orangés, scintillement irrégulier à deux vitesses, lumière chaude locale et léger mirage de chaleur au-dessus des coupes. Il conserve le contrat de paramètres de `living_halt.gd`, sans modifier le shader des autres haltes. Réglages actuels des deux feux : `flame_strength = 0.72`, `light_strength = 0.45`.

Le masque `fog_density.png` définit **trois nappes de fumée au sol** et dégage l’allée principale ainsi que les statues. `threshold_fog.gdshader` superpose deux nappes entraînées différemment, courbe leurs filaments avec deux échelles de curl et varie leur densité. Le masque reste fixe dans l’image : les zones noires restent transparentes, indépendamment du déplacement interne de la fumée. Les bords sont fondus et aucun voile constant n’est ajouté. Réglages actuels : opacité 0,40, couleur `#969c99`, dérive `[-0.0024, -0.00006]`, échelle 1,2, `curl = 1.15`, `detail = 0.8`.

Les deux shaders reçoivent uniquement `effect_time` depuis l’horloge du monde, sans utiliser `TIME`. La pause conserve l’image. Le mouvement réduit fige et atténue la brume ; il diminue l’intensité des effets du brasero. Le mode original désactive ces effets. Les captures réelles à 0, 3 et 6 secondes confirment une évolution lisible des volutes ; inspection à 720p : chemin dégagé, architecture stable et feu localisé. La comparaison des images en pause est strictement identique.

## Commandes de validation

```powershell
./tools/catabase_threshold/verify.ps1 -Mode unit
./tools/catabase_threshold/verify.ps1 -Mode flow -Ending skip -Appearance painted_g
./tools/catabase_threshold/verify.ps1 -Mode flow -Ending natural -Appearance classic
./tools/catabase_threshold/verify.ps1 -Mode capture
```

Le lanceur sérialise l’accès au moteur, isole les données utilisateur et écrit les rapports sous `artifacts/dev/`. `unit` couvre seuil, brume, cinématique, sélection et dépendances des haltes ; `flow` traverse les vraies scènes ; `capture` produit les contrôles visuels dédiés.

## Preuves de validation

- `ash/guides.json` : **193 objets maillés, 20 724 triangles**, guides 1600 × 900, profondeur 16 bits et profondeur métrique brute, normales en espace caméra, IDs et calques géométriques. Erreur de projection normalisée rapportée : environ 5,74 × 10⁻⁸.
- `ash/registration.json` : origine et hash de la peinture, recalage affine des trois empreintes, dimensions du héros et liste des candidats rejetés.
- `ash/layer_packaging_report.json` : composition RGBA et `mergedimage` OpenRaster identiques à l’original, **0 pixel différent**. `ash/krita_batch_verification.json` atteste l’import/export réel avec Krita 5.3.3, également sans différence de pixels ; exécution `artifacts/dev/20260910-174146-krita-ash-export/batch.json`.
- **Godot — intégration et régressions : PASS**, 84 tests, 1 018 assertions, aucune erreur inattendue. Rapport : `artifacts/dev/20260910-190542-threshold-unit-skip-painted_g-5942df06/gut-strict-report.json`. Couvre les quatre cibles peintes, les détours et segments, les frames variables, le focus, la brume, les transitions et la sauvegarde.
- **Haltes communes : PASS**, 41 tests, 378 assertions, aucune erreur. Rapport : `artifacts/dev/20260910-182208-test-halts-54acf471/gut-strict-report.json`.
- **Pipeline Python : PASS**, 23 tests. Journal : `artifacts/dev/20260910-180532-halt-test-0a9a9164/prepare.stderr.log`.
- **Rendu Godot : PASS**, 65 contrôles et 27 captures, zéro erreur moteur ni fuite détectée à la sortie. Rapport : `artifacts/dev/20260910-180322-threshold-capture-skip-painted_g-6c3d3695/report.json` ; contrôle strict `summary.json`. Source inchangée, dimensions 1280×720, 1920×1080 et 1200×896 ; brume 0/3/6/24 s, feu 0/0,37 s, pause pixel par pixel, mode original et réduit, occultation devant/derrière les statues, interface et checkpoint préservé. Aperçu, récit d’Hadès et trajet de porte inspectés visuellement.
- **Parcours public complets : PASS strict**, 37 contrôles et 10 captures chacun, aucune erreur moteur ni fuite à la sortie. Cinématique passée + Achille peint : `artifacts/dev/20260910-185651-threshold-flow-skip-painted_g-7cea2bb1/summary.json` ; cinématique complète + Achille classique : `artifacts/dev/20260910-185832-threshold-flow-natural-classic-5610a136/summary.json`. Les `flow-report.json` associés conservent les clics, les trajectoires, les temps réels, les états avant/après et le checkpoint `d01_0`. Le parcours entre la plaque d’Héra et la porte demande un seul clic et environ 8,5 secondes, en contournant les socles.


## Fermeture du combat : diagnostic et correctifs associés

Les deux parcours complets ont confirmé `d01_0` et le checkpoint créé après la porte : `20260910-184602-threshold-flow-skip-painted_g-56dc1811` et `20260910-184811-threshold-flow-natural-classic-439503ed`. Leur contrôle strict signalait encore des ressources retenues à la fermeture du combat.

Le second rapport mesure les références faibles : le service de terrain du combat est bien libéré, sa grille reste retenue. Les deux causes ont été isolées :

- `ArenaVisualAssembler.expected_visual_signature` créait une projection temporaire avec 205 cellules, récupérait ses seules données visuelles et abandonnait son terrain sans `dispose()`. Le calcul libère maintenant ce terrain possédé après extraction des données ; une projection fournie par l’appelant reste intacte.
- `GridData` conserve ses unités et chaque unité son `grid_context`. La sortie effective de `Battle` détache maintenant ces références vers l’ancienne grille. Les coordonnées, PV et PA persistent ; une unité transférée vers la grille suivante reste rattachée à celle-ci.

Tests de régression : `test_battle_grid_lifecycle.gd` et `test_arena_visual_signature_lifecycle.gd`. La suite du seuil inclut désormais aussi les tests de transitions asynchrones, d’issues atomiques et de déduplication des effets du combat. Les deux parcours réels après correctifs passent strictement : façade de terrain, service et grille sont tous libérés. Les premiers rapports incomplets ou en échec restent conservés comme diagnostics, sans remplacer les preuves finales ci-dessus.

Le pilote de parcours utilise une seule fenêtre Godot, convertit les coordonnées des boutons intégrés par leurs transformations écran et notifie l’entrée du pointeur avant les événements, selon le [contrat Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-notify-mouse-entered). Les zones cliquables de la map continuent à être exercées par de vrais événements de souris.

Les fixtures des tests asynchrones et de déduplication libèrent également leurs graphes artificiels en `after_each()` ; leurs scénarios et assertions restent identiques. La suite élargie se ferme sans fuite. Aucune validation globale de tout le dépôt n’est revendiquée.
