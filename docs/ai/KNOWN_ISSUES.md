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

## L’Odyssée — limites après promotion d’Achille

- Le contenu joueur et le routage d’Achille sont en **PRODUCTION_RUNTIME** sans
  changement de valeurs gameplay. Les trois salles et les quatre sorts sont
  couverts par le smoke graphique dédié.

- Le corps 3D tourne désormais sur quatre orientations et un pool de 24 clips
  (20 Meshy retargetés + 4 natifs). Les quatre capacités ont des affectations
  distinctes, mais les contacts d'arme, les mains, certains appuis et les
  coutures de boucle restent à polir artistiquement.
- Le corps de grille et l’aperçu 3D utilisent la V2. Le portrait du HUD reste
  l’illustration 2D historique ; il n’est pas un rendu animé du GLB.
- Le seuil automatique actuel est 1–5 cases = marche, 6+ = course rapide.
  Achille n'a que 3 PM de base : la course ne se déclenche donc normalement
  qu'avec un bonus ou une future règle. La source ne fournit aucune animation
  de mort ; le fondu simple reste le fallback.
- Les ennemis réutilisent des squelettes visuels existants et les trois salles
  partagent leurs layouts et profils de présentation peints avec le catalogue
  canonique. Les wrappers visuels, rencontres et progressions restent propres à
  L’Odyssée.
- Le runner graphique forcé est PASS et ses treize captures ont été inspectées,
  mais aucune partie humaine non forcée de la salle 1 n’a été effectuée. Le HUD
  du smoke 1600×1000 est lisible ; les résolutions plus basses doivent encore
  être revues lors d’un playtest humain.
- Les runners graphiques peuvent encore signaler des ressources renderer ou
  `ObjectDB` à la fermeture ; le rapport fonctionnel et le code de sortie restent
  PASS/0.
- Le fallback 2D paresseux réservé aux erreurs 3D vérifiées conserve les pixels
  historiques d’épée et de bouclier. Il n’est pas instancié dans le parcours
  nominal V2, dont le corps 3D reste sans équipement.
- Le root motion source reste non classifié ; la neutralisation locale X/Z
  maintient la grille comme autorité sans réécrire les clips importés.
- La cible de durée 18–25 minutes n’a pas été validée par un playtest humain. Le
  smoke automatise les handlers de production mais ne remplace pas ce playtest.
- `Percée` résout correctement la grille et resynchronise la vue sur la case
  finale ; la transition visuelle entre les deux cases reste instantanée et
  pourra recevoir un tween de finition.
- La progression comporte quatre disciplines de combat immédiatement
  disponibles. Chacune reste limitée au rang initial et n’ouvre pas encore
  d’arbre d’évolution ; les récompenses d’équipement restent désactivées.
- La promotion concerne L’Odyssée, run solo officielle. Les runs au trio et
  leurs contenus historiques restent inchangés.

État revalidé le 2026-08-23 avec Godot 4.7.1 et GUT 9.7.1.

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
