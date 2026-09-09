# Validation réelle du polissage d’Achille v3

La scène `PolishValidation.tscn` hérite de la validation du kit v2. Elle conserve le terrain enregistré, les unités canoniques, le déploiement, les PA/PM, les maîtrises achetées légalement et les sorts réellement résolus. Les positions de départ et l’XP sont des fixtures déclarées **avant** le combat. Aucune position d’acteur, orientation, statistique ou horloge d’animation n’est assignée pendant le combat.

Le modèle principal est **Achille classique**, conformément au choix de Paolo. `--appearance=painted_g` vérifie aussi la compatibilité du modèle peint avec le backend partagé.

## Exécuter

Depuis la racine du projet, avec Godot déjà importé :

```powershell
./tools/achilles_animation_polish_v3_validation/run_matrix.ps1 -Batch matrix_final -IncludeSupplemental
```

Cette commande effectue 20 combats classiques : quatre directions, avec combo de base (dont ruée), tir de base, Ligne de mort, Volée et Fléau. Elle ajoute Tir avec Allonge/Arrêt, Perforante, puis une marche d’une case et un tir du modèle peint : **23 combats**. Chaque processus est isolé, caché, limité à deux minutes et arrêté en cas d’échec. Seul le processus créé par le lanceur peut être arrêté.

Pour un contrôle court ou une capture :

```powershell
./tools/achilles_animation_polish_v3_validation/run_matrix.ps1 -Batch smoke -Directions E -CaseIds base_shot
./tools/achilles_animation_polish_v3_validation/run_matrix.ps1 -Batch bow_visual -Directions E -CaseIds chiron_shot -Capture
```

`-WalkCells 1` vérifie une seule case, contre trois par défaut. `-Appearance painted_g` utilise le choix canonique de variante dans `RunData`. `-CaseIds aeacus_bastion` ajoute le Bastion si une modification touche les réactions d’arrivée. Ces options n’altèrent pas les ressources de production.

## Observations

- Une marche de trois vraies cases coûte trois PM et zéro PA. Le rapport conserve chaque frame/texture dessinée, sa phase liée à la distance, les index de pas, les transforms, l’ancre au sol et l’arrivée du UnitView. Les mesures alpha des dessins sont décodées avant le mouvement, puis relues en mémoire : aucune lecture GPU n’entre dans les mesures de cadence.
- La caméra de production doit être stabilisée avant chaque observation du repos. Le personnage reste surveillé pendant cette attente ; un changement de pose ou d’ancre échoue. Le repos est ensuite mesuré pendant 650 ms, avec une tolérance de 0,01 pixel.
- Les marqueurs de release/fin, coûts et usages uniques, géométrie des dommages, vrai trajet de ruée et retour idle gardent les assertions du harness v2. Une pose de charge qui cesse avant l’arrivée échoue.
- Chaque projectile doit réellement afficher des `Sprite2D` texturés dans la bonne famille, voler avant la perte de PV et recevoir son impact après la résolution. Les variantes contrôlent les dessins effectivement sélectionnés, sans accepter une retombée silencieuse sur un effet générique.
- L’origine en vol est comparée à l’origine du corps au release, augmentée du décalage canonique de `MasteryCombatAdapter.projectile_origin`. Les origines déportées légales comme Trait du destin sont respectées.

Le point bas alpha renseigne le contact du dessin ; ce n’est pas un détecteur anatomique de pied. Une inspection des captures reste nécessaire pour juger les genoux, les mains, la tension de l’arc et la cohérence du modèle.

## Captures et cadence

Les captures `-Capture` proviennent du vrai viewport après dessin. Elles sont conservées avec leurs timestamps puis compressées après les actions. Elles constituent une passe visuelle séparée des rapports `clean_timing_run` sans capture.

L’encodeur existant `tools/achilles_kit_sprite_validation/assemble_clip.cjs` accepte le `clip/clip_manifest.json` produit ici. Il conserve les durées source et vérifie les frames après décodage du GIF ; aucun ralenti ou frame de personnage reconstruite n’est ajouté.

Le lanceur conserve intégralement stdout/stderr et refuse toute erreur de script ou de moteur. Les seules exceptions sont les diagnostics de ressources/RID déjà connus à l’extinction, conservés dans les logs et non présentés comme corrigés.

## Import et régression GUT

`run_gut.ps1 -Batch gut_final` réalise l'import Godot headless, puis les 17 scripts ciblés. Les enfants sont cachés et bornés séparément (180 secondes pour l'import, 240 pour GUT). Le lanceur refuse les erreurs de parsing/runtime et exige un résumé GUT complet.

`test_achilles_polish_v3_assets.gd` instancie la scène réellement publiée dans `UnitData`, sans injecter de profil ou de fausses textures. Il vérifie les 48 clips, les 28 anciens clips conservés exactement, les 20 clips remplacés/ajoutés, les dessins transparents, les quatre releases distinctes dans chaque direction et la marche dans le backend réel.

Les tests historiques de cadence v2 conservent explicitement le profil v2 dans leur fixture. Le test du modèle peint compare sa chronologie au contrat v2 livré avec ce modèle ; la promotion du classique est couverte séparément par le contrat v3.


## Current Catabase techniques

The original matrix covers the historical mastery tree. It does not prove that a current expedition replacement identity selects the same gesture. Seven additional opt-in cases use the real ExpeditionBuildState/catalog, sequential pre-combat depth rewards, purchase prerequisites and equipped slot 2. No Spell payload or combat state is patched by the fixture. These cases are reported separately from the historical 23-case aggregate.

```powershell
./tools/achilles_animation_polish_v3_validation/run_matrix.ps1 -Batch expedition_bows -Directions E -CaseIds exp_chiron,exp_rupture,exp_traverse,exp_horizon,exp_braise,exp_givre,exp_foudre
```

- exp_chiron equips exp_tir_de_guet through chiron.root.
- exp_rupture equips Trait de rupture; the fixture leaves the push destination clear.
- exp_traverse equips Tir de traverse through the real mutation prerequisite; the aimed fifth cell produces three actual line hits.
- exp_horizon purchases the prerequisite signature and legend, then equips Horizon perce; three actual line hits use bow_death.

Each case requires the actual ranged delay, textured flight before HP loss, the matching impact art and count, native body stem, unique release, paid walk and stable return to idle. The GUT wrapper also includes test_achilles_expedition_visual_contract: all 42 current identities, exactly 12 ranged delays, preserved geometry/costs and 28 actual canonical-scene releases. Renderer simulation clocks are used only in this isolated resource test, never in the real-combat probe.

The elemental cases exp_braise, exp_givre and exp_foudre legally discover the elements branch after depth 4, then purchase elements.learn_a / learn_b / learn_c before equipping. Run them with the same launcher and their names in -CaseIds. The probe requires the real Paris fire/ice atlas or the new lightning atlas, with no source fallback. After impact it reads the fire surface (3 fire damage, duration 2), the newly applied exp_givre status on the actual target, respecting status_source_scoped=false (next-activation -1 MP), and all three foudre victims (each pending next-activation -1 AP). No enemy turn is advanced to manufacture these states.
