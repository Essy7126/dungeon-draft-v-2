# Observatory Run Data V1.2

## Contrat exporté

Le manifeste 3.0 déclare deux racines autoritaires et indépendantes :

- `primary_run` charge `res://data/runs/first_run.tres`, classée
  `production`, primaire et `single_encounter` ;
- `test_wave_run` charge `res://data/runs/fixed_trio_prototype_run.tres`,
  classée `test`, non primaire et `wave_chain`.

`primary_run_id` référence la première. Le validateur exige qu'elle existe,
qu'elle soit l'unique cible primaire et qu'elle soit classée `production`.
Les identités de salle et de vague restent dérivées de leur ordre sous
l'alias du manifeste ; elles sont donc informationnelles, pas une nouvelle
autorité de gameplay.

## Rencontre unique

Une salle `single_encounter` expose directement
`RoomData.encounter_definition`. Elle produit au plus un combat effectif, ne
produit aucun objet wave et ne passe jamais par `RunWaveCountResolver`.
`resolved_default_seed_wave_count` vaut `null`, `wave_ids` est vide et
`wave_resolution_status` vaut `not_applicable`.

## Chaîne de vagues

Une run `wave_chain` utilise `RunWaveCountResolver` avec la seed réellement
déclarée. Seuls les éléments de `RoomData.waves` deviennent des profils
exportés. Les salles historiques sans `RoomWaveData` contribuent encore au
nombre de combats effectifs du résolveur, mais ne sont pas transformées en
pseudo-profils ; elles restent visibles par un audit de test non bloquant.

Les multiplicateurs, totaux mis à l'échelle et avertissements `WAVE.*` sont
ainsi confinés à la run de test. Une fuite de profil vers la production ou un
partage de `RoomData` entre production et test est bloquant.

## Compteurs

Les compteurs de production et de test sont calculés depuis les entités
exportées. Aucun nombre de salle, combat ou profil n'est codé en dur. Les
champs historiques génériques restent présents pour compatibilité, tandis que
`production_effective_combat_count`, `test_authored_wave_profile_count` et
`test_selected_wave_profile_count` donnent la lecture non ambiguë.
