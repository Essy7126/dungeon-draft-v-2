# Atelier de sprites — suivi de livraison

Base Git examinée : `6d99bfff`, 9 septembre 2026. Cette fiche décrit les modifications
du répertoire de travail ; elle ne remplace pas les rapports datés.

## Décisions et fichiers

- Dessins image par image conservés ; aucun rig, achat ou générateur ajouté.
- Service commun : `addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd`.
- Interface, commande et captures : `tools/sprite_workshop/`.
- Deux clips sources : `art/source/sprite_workshop/` ; anciens assets intacts.
- Tests : `test/unit/test_sprite_clip_workshop.gd` ; menu ajouté au plugin Studio.
- [Guide de production](../../tools/sprite_workshop/README.md), avec les questions
  artistiques ouvertes et les conditions d'intégration en combat.

## Vérifications réalisées

- Atelier : 13 tests, 88 assertions, PASS dans
  `artifacts/dev/20260909-144703-test-test_unit_test_sprite_clip_workshop.gd-538df006/`.
- Ruée/kit existants : 6 tests, 1153 assertions, PASS dans
  `artifacts/dev/20260909-143936-test-test_unit_test_achilles_kit_sprite_runtime_v2.gd-add3b1e9/`.
- Sprites des monstres existants : 21 tests, 733 assertions, PASS dans
  `artifacts/dev/20260909-144033-test-test_unit_test_catabase_monster_sprite_runtime.gd-5de19abf/`.
- Captures inspectées : 1440 × 900 et 1280 × 900, ancre et dessins
  visibles ; attente d'Achille à 799 ms puis réception à 800 ms dans un scénario
  d'arrivée à 800 ms. Captures finales :
  `artifacts/dev/20260909-144652-sprites-capture-da09a822/`.

Les premiers passages ont signalé des défauts de formatage, la distinction
entiers/flottants après JSON, et une lecture de test avant la frame de rendu.
Ces échecs ont été corrigés ; leurs rapports sont conservés. L'accès restreint
au magasin de certificats Windows produisait aussi une erreur moteur : les
vérifications moteur réussies ont été relancées avec l'accès Windows nécessaire.

## Livraisons par les commandes publiques

- `./tools/sprite_workshop/workshop.ps1 export -Clip res://art/source/sprite_workshop/sentinelle_attack_e.json` : PASS,
  `artifacts/dev/20260909-144621-sprites-export-0ae5c3ce/`.
- `./tools/sprite_workshop/workshop.ps1 export -Clip res://art/source/sprite_workshop/achille_dash_e.json` : PASS,
  `artifacts/dev/20260909-144643-sprites-export-3c4bcad4/`.
- `new` avec les poses 000/001 et la référence issues de l'export Sentinelle : PASS,
  `artifacts/dev/20260909-144634-sprites-new-bc60eb31/`. La commande exacte figure
  dans `workshop.command.json`. Son document d'essai reste dans les artefacts.
- `./tools/sprite_workshop/workshop.ps1 capture` : PASS, quatre captures et quatre
  contrôles interactifs. Les deux formats Sentinelle et l'attente/réception
  d'Achille ont été examinés ; la sélection et l'indicateur des images voisines
  ont ensuite été corrigés et recapturés. Les captures finales 1280 × 900 ont
  été examinées de nouveau.
- Vérification du formateur sur les six nouveaux scripts GDScript : PASS ;
  `git diff --check` : PASS. Pas de reformatage global.

## Échecs signalés hors de l'atelier

`./dev.ps1 test studio` : **FAIL**, 16 tests exécutés dont trois en échec,
dans `artifacts/dev/20260909-144129-test-studio-1652e158/` :

- sélection du profil de progression d'Achille résolue vers le Mage ;
- sort attendu absent, puis accès à `exclude_caster_from_area_effects` sur Nil ;
- vérification finale d'une transaction de profil : document relu différent.

La sortie signale aussi des ressources/RID non libérés. Ces résultats concernent
les profils et transactions du Studio général ; ils n'ont pas été corrigés par
ce chantier. Ils empêchent de déclarer la suite Studio entièrement validée.
La causalité n'a pas été comparée à une exécution séparée de la révision Git de
base. Le menu ajouté ouvre la scène de l'atelier ; son entrée après rechargement
du plugin n'a pas été testée par un clic dans le menu. Le lancement direct par
scène et les commandes moteur ont été utilisés.

## Limites

Les deux exemples conservent les dessins existants, sans revue artistique
nouvellement approuvée. Aucune nouvelle attaque finale ni nouvel export intégré
en combat. La comparaison retouche des poses / poses redessinées reste à faire.
Pas de mesure du gain en tokens, pas d'évaluation Blender/Spine, pas de suite CI
globale exécutée dans cette tâche.
