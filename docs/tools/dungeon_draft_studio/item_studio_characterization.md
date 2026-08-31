# Item Studio V1 — rapport de caractérisation

- Date : 2026-08-23
- Branche : `main`
- HEAD de base : `77799ec945071bf91b1bc4996da2b3bd7b6a81e1`
- Statut : **WORKTREE_CANDIDATE**
- Artefact : `artifacts/item_studio/characterization.json`
- Tests exécutés : runner de caractérisation valide ; GUT Item Studio et reliques ciblés.

## Autorités observées

`ItemDefinition` est l’autorité actuelle. Le catalogue de production est
`res://data/items/catalogs/default_item_catalog.tres`. Il contient des références
explicites et auto-découvre `res://data/items/definitions`. La collecte conserve
l’ordre explicite, trie les chemins découverts, déduplique les chemins déjà
explicites, puis refuse les doublons d’`item_id` au rebuild.

Au HEAD de base, 27 définitions valides sont résolues. Ce nombre est observé dans
l’artefact ; ni le service ni l’interface ne le codent en dur. Les catégories
réelles sont arme, armure, accessoire, consommable, parchemin et relique. Les
huit reliques de la première partie portent le tag autoritatif
`first_run_equipment_reward` ; les équipements historiques n’appartiennent plus
à ce pool.

Les identifiants d’inventaire initial observés sont `warrior_training_sword`,
`reinforced_vest`, `runic_charm`, `minor_healing_potion` et
`minor_action_scroll`. Ils sont exposés en lecture seule et n’ont pas été modifiés.

## Runtime parcouru

La caractérisation indexe `ItemDefinition`, `ItemCatalog`,
`ItemStatModifierData`, `ItemSpellModifierData`, `ItemInstance`, `RunInventory`,
`EquipmentLoadout`, `EquipmentService`, `EquipmentStatService`, `ItemUseService`,
`ItemReactiveEffectData`, `RelicEffectRegistry`, `RelicRuntimeService`,
`FirstRunEquipmentRewardService`, `InventoryScreen` et `EquipmentRewardOverlay`.

Les tests existants caractérisent empilement atomique, snapshot/restauration,
équipement, remplacement, déséquipement, application/retrait des statistiques,
soin, restauration de PA, sauvegarde et accès UI depuis HUD/pause.

## Effets et sous-ressources mutables

Les effets atteignables sont `ItemStatModifierData` fixe/pourcentage,
`ItemSpellModifierData`, `HEAL_FLAT`, `RESTORE_AP_FLAT` et les déclencheurs
réactifs/manuels de `ItemReactiveEffectData`. Le descripteur de sort
couvre les filtres hérités, dégâts, type, élément, seuil de PV, portée, poussée,
soin et bouclier. Le registre possède cinq descripteurs explicites et sa
couverture est valide.

L’audit ne détecte aucune sous-ressource mutable partagée entre définitions de
production. Textures, scripts, scènes et assets de rendu sont immuables et
partageables.

## Brouillons, legacy et références

Le brouillon personnel courant est
`user://dungeon_draft_studio/item_studio/drafts`, hors dépôt et hors découverte
de production. `res://data/items/drafts` reste lu comme emplacement historique
de migration, mais n’est plus la destination par défaut. Les chemins
`data/equipment/**` et l’ancien format `data/relics/**` sont **HISTORIQUE**.
Il n’existe pas de seconde autorité `RelicDefinition` : les reliques actives sont
des `ItemDefinition` exécutées par `RelicRuntimeService`.

Les références entrantes sont recherchées dans les `.gd`, `.tres` et `.tscn`, en
excluant `.godot`, les artefacts, `output` et GUT. L’artefact fournit la liste par
`item_id`, chaque empreinte et l’empreinte agrégée du catalogue :
`dd0cf8b05e550b97924319b92d65378c7f0450c53bb0d4b5630a2e3a537883e3`.

## Divergences documentaires

**DIVERGENCE** — `docs/ai/PROJECT_CONTRACT.md`, demandé par la mission, est absent.
Le contrat actif le plus proche, `RUN_CONTENT_ISOLATION_CONTRACT.md`, a été lu ;
le code, les ressources et les tests du HEAD restent l’autorité technique.

**HISTORIQUE** — l’audit inventaire du 3 août décrit un état antérieur. Il n’a
pas été utilisé comme preuve sans relecture du code et exécution des tests.
