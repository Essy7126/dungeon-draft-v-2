# Problèmes connus et suivis

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
