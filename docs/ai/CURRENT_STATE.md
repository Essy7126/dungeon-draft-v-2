# État vérifié du projet

> Statut : **NOT CURRENT — validation partielle**
>
> Les contrats ciblés et le smoke runtime sont verts. Ce document ne porte pas le
> statut CURRENT tant que la suite complète du dépôt reste rouge.

- Date de vérification : 2026-08-06
- Branche : `main`
- HEAD : `94fcdc700cf576a15ee4134d9f3dee680626827a`
- Godot : `4.7.stable.official.5b4e0cb0f`
- Principale canonique : `res://data/runs/first_run.tres`
- Run de test canonique : `res://data/runs/fixed_trio_prototype_run.tres`
- Alias/fixture compatible production : `res://data/runs/run_default.tres`

## Contrats observés dans le diff local

- `first_run.tres` : `SINGLE_ENCOUNTER`, six salles, six combats projetés.
- `run_default.tres` : `SINGLE_ENCOUNTER`, même liste historique de six salles ;
  il n’est pas l’autorité lancée par le hub.
- `fixed_trio_prototype_run.tres` : `WAVE_CHAIN`, quatre salles, deux enveloppes
  multi-vagues dédiées et une projection théorique de 8 à 22 combats.
- Aucune `RoomData` n’est partagée entre les deux modes canoniques.
- Les rapports, snapshots, projections et validateurs exposent le mode explicite.

## Validation

- Import Godot 4.7 : code de sortie 0 ; une erreur de classe dupliquée demeure
  sous `output/validation-feedback-candidate`, déjà observée avant la migration.
- Contrat d’isolation/post-combat : 26/26 tests, 240 assertions.
- Encounter Studio : 15/15 tests, 166 assertions.
- Smoke graphique réel : PASS ; continuation de vague, chargement de la bataille
  suivante, rapport à deux segments et retour au mode simple vérifiés.
- Suite complète : deux passages ont donné 720/734 puis 718/734 pendant des
  modifications locales concurrentes ; les suites liées à la mission restent à
  84/84 dans le dernier rapport JUnit. Le dépôt n’est pas déclaré vert.

Captures :

- `artifacts/run_flow_isolation_v1/main_single_encounter_post_combat.png`
- `artifacts/run_flow_isolation_v1/main_single_encounter_reward.png`
- `artifacts/run_flow_isolation_v1/test_wave_chain_room_decision.png`

Non vérifié manuellement : navigation complète depuis le hub avec interaction
joueur, défaite jouée à la main et recalibrage de durée/attrition.
