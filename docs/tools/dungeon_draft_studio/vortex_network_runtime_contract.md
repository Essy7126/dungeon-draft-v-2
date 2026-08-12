# Contrat runtime des réseaux de vortex

Statut : **WORKTREE_CANDIDATE**. Schéma ArenaDefinition : version 3.

`ArenaVortexNetworkDefinition` porte `network_id`, `display_name`, `cells`,
`enabled`, `allowed_teams`, `editor_color`, `single_vortex_effect_id`,
`random_destination` et `production_notes`. Les anciennes `vortex_pairs` sont
migrées explicitement en réseaux de deux cellules. Snapshots, restore,
sérialisation, preview, test direct et runtime utilisent `vortex_networks`.

- 1 cellule : Impulsion du vide, +1 PM courant, une fois/unité/round ;
- 2 cellules : destination déterministe vers l'autre cellule ;
- 3+ cellules : choix parmi les autres cellules valides ;
- aucune sortie : `Vortex bloqué`, sans bonus solitaire.

Une sortie occupée, VOID/Hole, retirée, impraticable, désactivée ou interdite à
l'équipe est exclue. Une téléportation termine le déplacement et l'arrivée ne
réactive pas le réseau.

Le RNG local mélange `combat_seed`, round, identifiant stable de résolution,
identifiant stable d'unité, `network_id` et cellule source. Aucun `instance_id`
ni RNG global n'est consommé.

Un réseau de deux expose sa transition au pathfinding. Un réseau de 3+ permet
l'accès à l'entrée sans inventer une arête de sortie. L'IA évalue utilité moyenne,
pire sortie et danger sans modifier le seed ; elle exige une moyenne positive,
aucune sortie catastrophique et au moins une sortie valide.

