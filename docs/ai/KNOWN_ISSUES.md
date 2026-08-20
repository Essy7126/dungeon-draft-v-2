# Problèmes connus et suivis

## Arena authoring — réserves du candidat 2026-08-12

- Le bundle gelé `data/arenas/produced/room_01_forest` possède un UID de profil
  invalide ; les shards GUT qui interdisent les warnings inattendus le comptent
  comme échec. La mission ne le réécrit pas.
- `data/runs/profiles/test_content_profile.tres` comporte aussi des UID
  historiques résolus par chemin texte.
- Le renderer headless de Godot 4.7.1 a subi un crash natif avant `_ready` pour
  le runner de captures. Le renderer Windows D3D12 direct est vert à 88/88.
- La revue humaine interactive des nouveaux assistants reste à faire ; les
  captures vérifient néanmoins la lisibilité en 1280x720.

## Catalogue complet des terrains — avertissements candidat

- Le bundle non suivi `data/arenas/produced/room_01_forest` reste gelé et n’est
  ni une production canonique ni une source de Tester.
- La baseline globale conserve ses échecs historiques ; aucune carte de
  production n’est réécrite par ce candidat.
- Les chiffres Poison sont provisoires et doivent être réévalués par playtest.
- Les runners Godot peuvent encore rapporter les fuites renderer/ObjectDB et le
  doublon `output/validation-feedback-candidate/.../ItemDefinition` historiques.

## L’Odyssée — limites du candidat Achille solo

- Seule une source visuelle sud-est explicite est disponible pour Achille. Les
  autres directions utilisent un fallback volontaire avec avertissement unique ;
  les quatre capacités partagent provisoirement l’animation d’attaque. La mort
  utilise un fade simple et non une animation finale.
- Les ennemis réutilisent des squelettes visuels existants et les trois salles
  partagent leurs layouts et profils de présentation peints avec le catalogue
  canonique. Les wrappers visuels, rencontres et progressions restent propres à
  L’Odyssée.
- Le runner graphique forcé est PASS et ses quatorze captures ont été inspectées,
  mais aucune partie humaine non forcée de la salle 1 n’a été effectuée. Le HUD
  1280×720 est lisible mais proche du bord inférieur et doit être revu en jeu.
- Les runners graphiques peuvent encore signaler des ressources renderer ou
  `ObjectDB` à la fermeture ; le rapport fonctionnel et le code de sortie restent
  PASS/0.
- La suite globale est à 935/949, contre 13 échecs historiques documentés. Le
  quatorzième concerne `test_dungeon_draft_studio_v12` et la parité de signature
  structurelle affectée par le travail Arena/VFX concurrent ; aucun fichier
  Odyssey n’est impliqué.
- La cible de durée 18–25 minutes n’a pas été validée par un playtest humain. Le
  statut reste `WORKTREE_CANDIDATE`.
- La progression comporte quatre disciplines minimales et aucun arbre final ;
  les récompenses d’équipement sont volontairement désactivées pour cette slice.
- Ce candidat ne formule aucun verdict en faveur d’un remplacement du trio :
  L’Odyssée demeure un laboratoire expérimental parallèle.

État vérifié le 2026-08-06 sur `main`, HEAD
`bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`, Godot 4.7, GUT 9.7.1.

## Run content isolation

- Aucun partage mutable interdit n’est connu entre les deux profils officiels ;
  l’audit mesure `progression_shared_count = 0`.
- Les `hero_sources` de `LanternboundArchivistData` et les constantes de trio de
  `GameManager` restent volontairement comme compatibilité legacy. Les runs
  officielles ne les utilisent pas comme autorité.
- Le Studio Skill Tree 2.0 candidat ouvre désormais le profil de progression de
  la run. La voie `open(UnitData)` reste conservée pour les tests et documents
  legacy, mais elle n’est pas l’autorité d’une session run-aware.
- Le runner de migration direct peut afficher, après son rapport `ok: true`, des
  diagnostics CLI historiques liés à l’ordre de chargement de `DebugLogger`.
  Le scan éditeur et les suites GUT compilent les services correctement.

## Reclassifié par RUN_FLOW_ISOLATION_V1

- **Vagues dans la run principale** : résolu dans le diff local par la politique
  sérialisée `SINGLE_ENCOUNTER`, le nettoyage des six salles de production et les
  gardes runtime/UI. La clôture définitive attend une suite complète verte.

## Dette technique préexistante observée

- `data/units/alliés/Guerrier.tres` contient l’UID invalide
  `uid://0flkpto1jkby` pour `frappe_lourde.tres`. Le fallback par chemin fonctionne,
  mais GUT peut comptabiliser l’avertissement comme erreur inattendue lors de
  lancements ciblés historiques.
- Le scan final charge aussi quatre assets GLB (trois ennemis et l’Elfe) dont un
  UID de texture est résolu par le chemin texte. Les sources et imports existent ;
  Godot termine le scan avec le code 0.
- `output/validation-feedback-candidate/data/items/item_definition.gd` redéclare
  la classe globale `ItemDefinition` et provoque une erreur de parsing à l’import.
- La suite complète finale est stable à 787/800. Les 13 échecs sont inventoriés
  dans `RUN_CONTENT_ISOLATION_VALIDATION.md` : captures absentes, textures pause
  nulles, contrats Elfe déjà incompatibles avec `eagle_eye.tres`, et comparaison
  flottante. Aucun de ces fichiers n’est modifié par la mission.
- Les runners graphiques existants laissent des ressources renderer signalées à
  la fermeture ; le smoke termine néanmoins avec le code 0 et son contrat PASS.

## Studio 2.0 candidat

- Les barres et graphes restent denses en 1280×720 ; les contrôles utilisent
  maintenant des lignes repliables, des scrolls et des tooltips. Le grand
  viewport 1920×1080 demeure la vue de production recommandée.
- Le réimport conserve `occlusion.png` dans `ArenaDefinition.occlusion_mask_path`.
  Le runtime actuel continue cependant d’utiliser le foreground et le polygone
  d’occlusion canoniques pour le Y-sort ; le masque importé reste une couche de
  livraison tant qu’un renderer bitmap dédié n’est pas adopté.
- Les runners Studio 2.0 signalent des fuites `ObjectDB` à la fermeture, comme
  les runners graphiques de baseline. Aucun échec fonctionnel ciblé n’en résulte.
- Le statut reste `WORKTREE_CANDIDATE` : aucune activation `CURRENT`, aucun
  commit et aucune publication ne font partie de cette mission.

## Conséquences de design à mesurer

- recalibrage futur de la durée de la principale ;
- cadence XP après réduction du nombre de combats ;
- validation de l’attrition sur les six rencontres ;
- distinction future entre rencontre, renfort et phase persistante.

Ces suivis sont des conséquences attendues de la décision de design, pas des
régressions introduites par la migration.

## Item Studio V1 — limites WORKTREE_CANDIDATE

- Date : 2026-08-07 ; branche `main` ; HEAD de base
  `29f307b5ff61822f266bbd2d14636ca8dcea2d95`.
- Statut : **WORKTREE_CANDIDATE**.
- Tests : Item Studio 30/30 (190 assertions), smoke PASS, captures inspectées ; activation à un
  commit et revue humaine interactive non vérifiées.
- Il n’existe aucun runtime de reliques au HEAD. Les chemins historiques
  `data/relics/**` et `data/equipment/**` ne sont pas importés.
- Il n’existe aucun catalogue d’objets spécifique par run ; la publication
  `RUN_SPECIFIC` est bloquée explicitement.
- Les nouvelles familles déclenchées nécessitant des hooks inédits doivent être
  implémentées et enregistrées avant d’être éditables.
- Les effets dépendant d’une grille de bataille sont signalés lorsque la sandbox
  pure ne peut pas les exécuter intégralement.
- Le scan d’éditeur rencontre toujours la copie historique
  `output/validation-feedback-candidate/data/items/item_definition.gd`, qui
  masque la classe globale. Ce fichier préexistant n’est pas modifié.
- Les runners graphiques signalent encore des ressources renderer et ObjectDB à
  la fermeture, sans échec fonctionnel des marqueurs ciblés.
# Réserves Arena Studio 2.0 — candidat local 2026-08-10

- La suite globale possède une allowlist de 13 échecs historiques ; aucun nouvel échec n’est accepté.
- `output/validation-feedback-candidate/data/items/item_definition.gd` masque une classe globale pendant le scan ; anomalie historique hors périmètre.
- Godot signale des fuites RID/ObjectDB de fermeture déjà observées.
- `res://data/arenas/produced/room_01_forest/` est un bundle incomplet gelé, non canonique et non utilisable pour Tester.
- Les 187 fichiers Achilles/VFX/outillage non trackés et 10 suppressions Achilles sont un travail externe à préserver.
- Deux répétitions globales Windows post-correction responsive ont été instables au niveau du processus (timeout en progression puis sortie native `-1`) sans nouvel échec d’assertion observé. Le dernier global complet conserve exactement les 13 historiques ; les suites UI/visuelles affectées sont vertes séparément.

## Achilles 3D character-only / theorycraft — réserves du checkpoint salle II

- **Blocage hérité** : le fallback 2D conservé contient des pixels d’épée et de
  bouclier déjà incrustés (`LEGACY_2D_BAKED_WEAPON_PIXELS_OBSERVED`). Le backend
  canonique 3D reste sans équipement séparé, avec `equipment_enabled = false`
  et `weapon_profile = null`, mais l’exigence visuelle globale sans arme demeure
  `BLOCKED_LEGACY_2D_FALLBACK_WEAPON_VISUAL_DIVERGENCE`.
- L’intégration runtime d’une arme n’est pas commencée et reste différée au
  laboratoire dédié. Les templates épée-bouclier et arc sont des concepts non
  runtime ; le laboratoire de theorycraft isolé n’active aucun build.
- Le root motion des actions sources reste `ROOT_MOTION_UNCLASSIFIED`. La
  neutralisation locale X/Z stabilise la présentation, mais ne constitue pas
  une classification ou une correction des actions sources.
- La mesure GPU est `NOT_MEASURED`. La rétention mémoire observée puis stable au
  second cycle 512 ressemble à un plateau de cache de rendu, sans attribution
  causale isolée. Les warnings de teardown renderer/RID/ObjectDB restent à
  surveiller.
- Seule la salle II a été exercée dans ce checkpoint. Salle I, salle III,
  transitions normales, retour menu, résultat et smoke complet trois salles
  restent en pause derrière la gate propriétaire, et ne doivent pas être
  présentés comme vérifiés.
- Le choix de présentation reste humain : A = 256, B = 384, C = 512, D = rejet
  du `SubViewport` pour des sprites prérendus. La recommandation technique 384
  n’est pas une décision d’activation.
- Le statut demeure **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.

## Achilles 3D — réserves après promotion Odyssée B/384

Les deux blocages du checkpoint précédent sont clos sur la branche locale : le
choix B/384 est explicite et l’ancien fallback 2D armé est devenu inatteignable
depuis le runtime Odyssée. Ils ne doivent plus être présentés comme actifs pour
le corps de combat.

Restent ouverts :

- la branche n’est ni fusionnée dans `main` ni poussée ;
- les interactions du runner appellent les vrais handlers programmatiquement,
  sans certifier une session complète à la souris ni trois victoires jouées ;
- les transitions/résultat sont synthétiques et clairement étiquetés ;
- le root motion source reste non classifié et les temps GPU non mesurés ;
- les diagnostics RID/ObjectDB/resources persistent au teardown OpenGL malgré
  la libération des `WeakRef` ciblés ;
- l’UID historique invalide de `Guerrier.tres` garde cinq tests de la suite
  Odyssée historique en échec inattendu ;
- le portrait HUD/post-combat d’Achille reste une icône 2D volontaire, distincte
  du corps de combat désormais exclusivement 3D.
