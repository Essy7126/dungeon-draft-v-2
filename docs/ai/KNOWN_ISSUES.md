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

## L’Odyssée — limites du candidat Meshy V3

- Le candidat courant utilise directement le modèle Meshy, son rig de 24 os et
  ses 20 animations natives. Aucun clip n’est retargeté et les V1/V2 restent
  conservées uniquement comme assets historiques.
- Le repos est explicitement lié à `Idle_11`, la marche à `Walking` et la
  course rapide à `run_fast_3_inplace`. Le seuil reste 1–5 cases = marche et
  6+ = course ; avec 3 PM de base, la course automatique demande normalement
  un bonus de déplacement ou une future règle. La marche est ralentie à 75 %
  et 0,40 s par case ; la course garde 0,20 s par case.
- Le profil peint utilise une base et un minimum de 1,0, avec un maximum de
  1,15. Les valeurs finales attendues sont 1,05 / 1,08 / 1,10 dans les trois
  cartes ; l’ancien calibrage proche de 2,0 n’est plus courant.
- Les quatre capacités possèdent des affectations distinctes dans le pool V3.
  Les clips d’action conçus autour d’une arme restent cependant sans contact
  d’équipement : le modèle Meshy n’embarque ni arme, ni bouclier, ni arc.
- La source ne fournit aucune animation de mort. Le fondu de l’adaptateur reste
  le rendu de mort prévu.
- Le corps de grille et l’aperçu 3D utilisent la V3. Le portrait du HUD reste
  l’illustration 2D historique ; il n’est pas un rendu animé du GLB.
- Les clips avec forte translation de hanche sont neutralisés localement afin
  de conserver la grille comme autorité. Les 13 captures finales valident le
  cadrage général ; une future passe artistique pourra encore polir les appuis
  et les transitions.
- Validation actuelle : tests ciblés taille/locomotion 23/23 (350 assertions),
  Studio 19/19 (208 assertions) et binding SHA-exact 34/34 (643 assertions).
  Le full-flow trois salles et ses 13 captures passent sur `37c6f5f846fa` ;
  les hauteurs réelles sont 65,1 / 66,2 / 68,2 px et la revue des proportions,
  du repos et des quatre poses d'action conclut GO.
- Les runners graphiques peuvent encore signaler des ressources renderer ou
  `ObjectDB` à la fermeture, après le marqueur PASS et avec un code de sortie
  nul. Cette dette de teardown n'est pas attribuée au gameplay Meshy.
- Lorsqu'il est sélectionné, le modèle Meshy apparaît sombre/bleuté et ses
  détails de matière sont peu perceptibles. C'est la prochaine priorité
  cosmétique.
- Les captures fixes prouvent le choix `Walking` / `run_fast_3_inplace`, mais
  une future revue vidéo restera utile pour affiner la cadence au-delà du
  réglage actuel validé mécaniquement.
- `Percée` conserve la grille comme autorité et se recale sur la case finale ;
  sa transition visuelle entre les deux cases reste sans tween de finition.
- La cible de durée 18–25 minutes et une partie humaine non forcée n’ont pas
  encore été validées. Les récompenses d’équipement restent désactivées.
- La modification concerne L’Odyssée, run solo officielle. Les runs au trio et
  leurs contenus historiques restent inchangés.

État courant vérifié le 2026-08-23 avec Godot 4.7.1 et GUT 9.7.1 ;
validation graphique finale : PASS / GO.

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
