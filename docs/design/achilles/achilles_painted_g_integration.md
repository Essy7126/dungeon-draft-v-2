# Achille peint G dans Catabase

La sélection de Catabase propose **Achille classique** et **Achille peint**. Le second reprend la version G approuvée : proportions humaines élancées, bronze, bleu marine et turquoise. Les deux choix conservent l’identité de gameplay `achilles`.

## Branchement

- `CharacterSelectionCatalog` produit deux entrées de présentation pour la même aventure. L’entrée peinte possède l’identifiant de sélection `achilles_painted_g`.
- `RunData.hero_visual_variants = {"achilles": "painted_g"}` transporte le choix à travers l’introduction, la création d’expédition et les sauvegardes.
- `RunHeroResolver` applique la variante sur une copie runtime de `UnitData`. Les statistiques, sorts, progression, équipement et données canoniques restent communs.
- `RunHeroVisualVariants` valide les variantes connues et remplace uniquement la scène, les aperçus et le portrait. Une variante absente restaure le classique ; une variante inconnue invalide la restauration avant toute mutation de la run.
- `AchillesPaintedGUnitView.tscn` utilise le même adaptateur `achilles_iso_unit_view.gd` et le même backend `achilles_sprite_2d_backend.gd` que le classique.
- `portrait_texture_override` passe de `UnitData` à `Unit`. Le catalogue HUD duplique le thème pour appliquer le portrait de l’apparence sans modifier le thème canonique. La sélection, le HUD et les autres consommateurs du thème utilisent ainsi le portrait peint. `achilles_portrait.tres` cadre la tête et le buste dans l’atlas de repos E déjà importé, sans nouvelle image.

## Animations et orientations

Le pack contient 40 clips, 208 images runtime, 40 atlas PNG transparents. Chaque image occupe un canvas de 512 × 384 pixels, ancré en `(256, 320)` et affiché à l’échelle `0.35` du backend partagé.

| Famille | Images par direction | Pilotage |
| --- | ---: | --- |
| Repos | 4 | Le backend conserve l’image 0 |
| Marche | 8 | Phase liée à la distance parcourue |
| Attaque | 4 | Impact au marqueur partagé |
| Dash | 4 | Pose aérienne maintenue jusqu’à l’arrivée réelle |
| Arc, garde, balayage, volée | 6 chacune | Pose de repos ajoutée avant et après les 4 poses d’action |
| Réaction, mort | 4 chacune | Même durée et contrat que le classique |

| Direction grille | Projection écran |
| --- | --- |
| N | Haut à droite, vue de dos |
| E | Bas à droite, vue de face |
| S | Bas à gauche, vue de face |
| W | Haut à gauche, vue de dos |

Les quatre orientations possèdent leurs propres dessins. Aucun miroir runtime ne remplace une direction. Les timings et marqueurs restent identiques au profil du kit classique ; le pack ne crée pas un second système de combat.

## Fabrication et traçabilité

Les images ont été générées avec Higgsfield, puis détourées et assemblées dans son sandbox. Les sources, requêtes, corrections, URL et paramètres figés se trouvent dans `art/source/characters/achilles/sprites_painted_g/`. Le script reproductible est `tools/achilles_painted_g_pipeline/build.py`.

La rangée de dash N a été remplacée par une correction vue de dos, en conservant les rangées d’arc et de garde validées. Le détourage traite les fonds magenta, gris et blanc. Cinq points de fond explicitement contrôlés retirent les poches blanches enfermées dans les arcs E ; une flèche isolée est attribuée à sa pose S avant suppression, les projectiles appartenant au combat.

Les 12 planches détourées ont été inspectées. Le contrôle mécanique ne détecte aucune silhouette coupée ni perte de pixels d’équipement au découpage. Les échelles et racines inspectées sont figées dans `build_config.json`. Les GIF de travail illustrent les poses mais le runtime conserve son propre pilotage de la marche, du dash et des marqueurs.

Coût du lot complet, références et corrections incluses : **61 crédits Higgsfield**. Solde vérifié après génération : **4,5 crédits**.

## Validation

Le test synthétique du pipeline a été exécuté avec succès dans le sandbox : clés couleur, poches de fond choisies, conservation des autres blancs, attribution unique des composantes, équipements traversant les cellules, transparence des franges, rejet des corps fusionnés et des véritables coupes.

Godot `4.7.1.stable.official.a13da4feb`, GUT `9.7.1` : **46 tests sur 46 passent, 3 232 assertions**, code de sortie 0 et aucun diagnostic moteur dans le dernier passage GUT. Les six suites couvrent les variantes de run, la sélection, le lancement Catabase, les interactions de sélection et les 40 animations du backend partagé. Le dernier passage a été exécuté après la correction du portrait.

Le probe graphique effectue le vrai parcours peint → classique → peint → introduction → premier combat de Catabase → déploiement. **33 contrôles sur 33 passent**. Il vérifie notamment la scène effectivement instanciée et le portrait réellement affiché dans le HUD. La sauvegarde existante du joueur conserve son empreinte ; le probe utilise un fichier temporaire isolé.

Cinq captures ont été produites par le renderer Godot et inspectées : sélection peinte en 1280 × 720 et 1920 × 1080, retour au classique en 1280 × 720, combat peint en 1280 × 720 et 1920 × 1080. Le document ne prétend pas valider une partie complète jusqu’à la fin de Catabase.

Les commandes exactes, arguments, journaux et chemins de captures sont conservés dans [summary.json](../../../artifacts/achilles_painted_g_integration/summary.json). Le résultat final est dans `gut_final/gut.junit.xml`, le contrôle graphique dans `review.json`. `git diff --check` passe.

### Diagnostics de fermeture restant ouverts

Le contrôle strict d’import reste **FAIL / UNEXPECTED_ENGINE_ERROR** malgré un import terminé et aucune erreur de syntaxe : l’éditeur signale 24 ressources encore utilisées à sa fermeture. La sortie verbose nomme des ressources d’Item Studio, VFX Studio, d’objets et de terrain, sans nommer d’asset `painted_g`. Le détail est dans `import_diagnostics.json` ; les plugins d’édition et le runner strict n’ont pas été modifiés.

Le probe graphique réussit ses contrôles fonctionnels mais signale également 275 ressources, 775 instances ObjectDB et des RID non libérés à sa fermeture. L’arrêt différé ne supprime pas ce diagnostic ; sa cause exacte n’a pas été isolée. Les journaux GUT sont propres. Ces limites de fermeture sont conservées distinctement des résultats fonctionnels, sans déclarer la validation stricte entièrement verte.
