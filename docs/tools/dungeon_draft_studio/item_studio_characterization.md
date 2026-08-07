# Item Studio V1 — rapport de caractérisation

- Date : 2026-08-07
- Branche : `main`
- HEAD de base : `29f307b5ff61822f266bbd2d14636ca8dcea2d95`
- Statut : **WORKTREE_CANDIDATE**
- Artefact : `artifacts/item_studio/characterization.json`
- Tests exécutés : runner de caractérisation PASS ; GUT inventaire 10/10 ; GUT Item Studio 30/30.
- Non vérifié : anciennes familles de reliques absentes du HEAD ; aucune migration legacy tentée.

## Autorités observées

`ItemDefinition` est l’autorité actuelle. Le catalogue de production est
`res://data/items/catalogs/default_item_catalog.tres`. Il contient des références
explicites et auto-découvre `res://data/items/definitions`. La collecte conserve
l’ordre explicite, trie les chemins découverts, déduplique les chemins déjà
explicites, puis refuse les doublons d’`item_id` au rebuild.

Au HEAD de base, 19 définitions valides sont résolues. Ce nombre est observé dans
l’artefact ; ni le service ni l’interface ne le codent en dur. Les catégories
réelles sont arme, armure, accessoire, consommable et parchemin. Quatorze
équipements portent le tag autoritatif `first_run_equipment_reward`.

Les identifiants d’inventaire initial observés sont `warrior_training_sword`,
`reinforced_vest`, `runic_charm`, `minor_healing_potion` et
`minor_action_scroll`. Ils sont exposés en lecture seule et n’ont pas été modifiés.

## Runtime parcouru

La caractérisation indexe `ItemDefinition`, `ItemCatalog`,
`ItemStatModifierData`, `ItemSpellModifierData`, `ItemInstance`, `RunInventory`,
`EquipmentLoadout`, `EquipmentService`, `EquipmentStatService`, `ItemUseService`,
`FirstRunEquipmentRewardService`, `InventoryScreen` et
`EquipmentRewardOverlay`.

Les tests existants caractérisent empilement atomique, snapshot/restauration,
équipement, remplacement, déséquipement, application/retrait des statistiques,
soin, restauration de PA, sauvegarde et accès UI depuis HUD/pause.

## Effets et sous-ressources mutables

Les effets atteignables sont `ItemStatModifierData` fixe/pourcentage,
`ItemSpellModifierData`, `HEAL_FLAT` et `RESTORE_AP_FLAT`. Le descripteur de sort
couvre les filtres hérités, dégâts, type, élément, seuil de PV, portée, poussée,
soin et bouclier. Le registre possède cinq descripteurs explicites et sa
couverture est valide.

L’audit ne détecte aucune sous-ressource mutable partagée entre définitions de
production. Textures, scripts, scènes et assets de rendu sont immuables et
partageables.

## Brouillons, legacy et références

`res://data/items/drafts` n’est pas auto-découvert. Les chemins
`data/equipment/**` et `data/relics/**` n’existent comme aucune autorité runtime
au HEAD : ils sont **HISTORIQUE**. Aucun `RelicDefinition` runtime n’est présent.

Les références entrantes sont recherchées dans les `.gd`, `.tres` et `.tscn`, en
excluant `.godot`, les artefacts, `output` et GUT. L’artefact fournit la liste par
`item_id`, chaque empreinte et l’empreinte agrégée du catalogue :
`522e33ce7d1ded06819ab260cd37632c04f963cee2063cd19cd6cb07e16af277`.

## Divergences documentaires

**DIVERGENCE** — `docs/ai/PROJECT_CONTRACT.md`, demandé par la mission, est absent.
Le contrat actif le plus proche, `RUN_CONTENT_ISOLATION_CONTRACT.md`, a été lu ;
le code, les ressources et les tests du HEAD restent l’autorité technique.

**HISTORIQUE** — l’audit inventaire du 3 août décrit un état antérieur. Il n’a
pas été utilisé comme preuve sans relecture du code et exécution des tests.
