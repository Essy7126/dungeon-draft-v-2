# Observatory Frontend V1.2

Le frontend consomme le contrat de snapshot 3.0 et sépare désormais la run de
production des outils de test.

## Routes

- `#/runs` liste les runs, leur nature, leur mode, leurs salles, leurs combats
  effectifs, leurs profils et leur fraîcheur ;
- `#/runs/:runId` affiche une run précise ;
- `#/run` reste compatible et redirige vers `primary_run_id` ;
- `#/rooms/:roomId` adapte son vocabulaire et ses panneaux au `flow_mode`.

Une run `single_encounter` ne montre ni seed, ni bornes, ni multiplicateurs,
ni table de profils de vague. Elle montre ses rencontres, rosters, cartes,
récompenses et champs runtime-only. Une run `wave_chain` conserve les profils,
la sélection déterministe, les bornes et les multiplicateurs, sous un
avertissement « outil de test » lorsqu'elle est classée `test`.

## Fraîcheur

La comparaison Git lit `diff --name-only -z` avec `core.quotepath=false` : les
chemins accentués restent intacts. Chaque chemin reçoit une classification
déterministe (`snapshot_affecting`, `possibly_affecting`, `non_affecting` ou
`documentation_only`) dérivée des racines du manifeste et de préfixes
explicites. Le libellé utilisateur parle de « chemins hors Observatory
modifiés » et ne prétend pas déduire leur effet fonctionnel.

## Statut LAN

Le frontend interroge l’endpoint local `__observatory/status.json` toutes les
30 secondes. Il distingue `current`, `updating`, `update_failed` et `unknown`,
montre toujours le SHA de la release encore active en cas d’échec, et n’expose
aucun chemin local. En l’absence d’endpoint (build statique, Vite ou serveur
indisponible), un fallback explicite reste non bloquant.
