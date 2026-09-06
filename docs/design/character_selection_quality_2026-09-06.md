# Sélection des personnages : passe de qualité du 6 septembre 2026

Cette passe remplace la composition et les illustrations de la sélection existante. Elle prolonge la [première version](character_selection_2026-09-05.md), qui décrit les références réellement observées : accueil et choix de serveur de Dofus. Aucun code interne de Dofus n’a été inspecté ; ses captures ne constituent pas les assets du jeu.

## Résultat

- Un sanctuaire peint original, plus lumineux au centre, encadre un aperçu animé plus grand. Le cadrage s’appuie sur une référence stable entre les poses ; les pieds restent ancrés au socle pendant le zoom.
- Quatre portraits illustrés harmonisent le roster. La bordure de sélection, le liseré de couleur et le focus restent lisibles sur les cinq cartes.
- La fiche associe des tuiles ivoire pour les trois statistiques principales à un panneau bleu vert pour les valeurs secondaires, les quatre techniques, leur coût, leurs effets et leurs restrictions. Les descriptions longues défilent ; les jetons du glossaire sont transformés en noms lisibles.
- La hiérarchie typographique sépare clairement marque, héros, aventure et données. Les ornements, cadres et ombres sont dessinés par Godot et restent indépendants des textes.
- L’action de lancement est isolée en bas à droite. Le nom du récit et la composition réelle du groupe restent visibles en bas à gauche.

Le canevas passe à **1600 × 900**, uniformément redimensionné et centré. Les résolutions 1280 × 720 et 1920 × 1080 remplissent le même format 16:9 ; 1440 × 900 conserve des bandes horizontales. Les contrôles ne sont pas étirés indépendamment.

## Données et parcours conservés

Les cinq entrées présentes au moment de cette passe sont : Achille dans Catabase, Elfe/Mage/Guerrier dans l’Odyssée du trio, puis Achille dans l’Épreuve du dialecticien. Les deux cartes d’Achille partagent le portrait mais conservent leurs ressources de run distinctes. Choisir un membre du trio conserve le groupe défini par sa run.

Les statistiques et techniques proviennent des unités résolues par le catalogue. Cette passe ne change ni l’équilibrage d’Achille, ni la progression, ni le contenu des salles. L’aperçu utilise les assets réellement disponibles en jeu. Les commandes Repos, Marche, Attaque et rotation n’annoncent que les animations disponibles ; le zoom reste entre 85 % et 110 %.

Le codex reste consultatif. Son ouverture suspend l’aperçu et bloque rotation, pose, zoom, changement de héros et double ouverture. À sa fermeture, l’animation reprend et le focus retourne à la technique sélectionnée, ou au bouton visible de l’onglet Histoire si l’ouverture vient de cet onglet. La navigation supérieure du bouton de lancement suit également l’onglet affiché.

## Fichiers

- `ui/selection/character_selection_screen.gd` : composition, raccords de données et interactions.
- `ui/selection/selection_backdrop.gd` : décor v2, éclairage et repli dessiné.
- `ui/selection/selection_ornament.gd` : sceaux, ombre au sol, coins, séparateurs et cadre du bouton principal.
- `ui/characters/character_preview_3d.gd` : mode de présentation facultatif, cadrage stable et zoom. Les usages existants du widget conservent leur cadrage par défaut.
- `asset/ui/character_selection/` : sanctuaire et portraits v2. [Provenance et direction artistique](../../art/source/character_selection/selection_v2_art_direction.md).
- `tools/character_selection/selection_quality_review.gd` : revue rendue avec clics injectés, contrôle des limites des panneaux et vérification de l’absence de mutation de la run pendant la consultation.

## Validation effectuée

La suite ciblée finale passe : **33 tests, 1 367 assertions**, répartis entre `test_character_selection_screen.gd`, `test_philosopher_selection_layout.gd`, `test_selection_quality_v2.gd`, `test_character_preview_showcase.gd` et `test_achilles_sprite_preview.gd`. Elle couvre notamment les cinq aventures, les portraits réellement branchés, les vingt descriptions de techniques, le défilement des descriptions longues, le focus dans les deux onglets, la modalité du codex et le cadrage des aperçus 2D/3D.

La revue avec le moteur de rendu Compatibility produit **9 captures et 265 vérifications réussies** : Achille en 720p, 1440 × 900 et 1080p ; Mage ; l’Épreuve ; Garde ; Histoire ; codex ouvert puis fermé. Les rendus Achille 720p et Mage 1440 × 900 ont été inspectés visuellement après ajout des portraits. Les captures supplémentaires documentent les autres états du parcours.

Rapports locaux : `artifacts/character_selection_v2/final_tests.log`, `after_review.json`, `review.log` et `review.err`. L’import, les tests et le rendu se terminent avec succès, sans erreur de script. Godot signale encore des ressources et instances ObjectDB retenues à la fermeture ; cette passe ne certifie pas la suite globale ni l’absence de fuites dans les systèmes partagés.

```powershell
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://test/unit/test_character_selection_screen.gd,res://test/unit/test_philosopher_selection_layout.gd,res://test/unit/test_selection_quality_v2.gd,res://test/unit/test_character_preview_showcase.gd,res://test/unit/test_achilles_sprite_preview.gd -gexit
godot --path . --rendering-method gl_compatibility --resolution 1440x900 --script res://tools/character_selection/selection_quality_review.gd
```

## Prochain gain de qualité artistique

La composition est désormais plus cohérente, mais l’aperçu central révèle encore la différence entre le sprite dessiné d’Achille et les modèles 3D historiques du trio. Un futur lot de production devrait harmoniser leurs silhouettes, matériaux, éclairages et animations avec une même direction artistique. Les icônes de techniques viennent également de plusieurs générations d’assets ; une collection cohérente apporterait un gain visible. Ces chantiers concernent les visuels réellement utilisés par les personnages et les sorts, au-delà de cette refonte de sélection.
