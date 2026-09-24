# Flux des runs Observatory V1.2

La V1.2 modélise deux usages sans les confondre :

| Alias | Classe | Mode | Autorité des combats |
| --- | --- | --- | --- |
| `primary_run` | `production` | `single_encounter` | une rencontre par `RoomData.encounter_definition` |
| `test_wave_run` | `test` | `wave_chain` | vrais profils `RoomData.waves`, résolus avec la seed |

La run primaire ne crée aucune pseudo-vague : `wave_ids` est vide, le résolveur
est `not_applicable` et les multiplicateurs n’existent pas dans sa lecture. La
run de test expose profils rédigés, profils sélectionnés, bornes et
multiplicateurs sous une signalétique « outil de test ».

Le manifeste interdit le partage de `RoomData` entre ces racines. Les audits
`WAVE.*` portent uniquement sur les profils de test ; une fuite dans la
production ou un partage de salle est bloquant. Les comptes exacts sont
calculés au moment de l’export, jamais inscrits dans le frontend.

Voir `run_data_v1_2.md` pour les champs JSON et `frontend_v1_2.md` pour leur
présentation.
