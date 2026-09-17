# Validation continue Catabase — stage 1, seed 2401

Date d'exécution : 14 septembre 2026. Branche : `main`. HEAD de base :
`055584c37f60d99b2f87bdbb4d670895bf8ef2b2`, avec la révision R6 présente
dans le worktree non commité coordonné par les autres chantiers. Moteur : Godot
4.7.1 stable. Source chiffrée :
`artifacts/catabase_run_balance_validation/stage1_seed2401_v2/report.json`.

## Verdict borné

**OBSERVÉ.** Les 12 cas attendus ont été exécutés sans erreur moteur ni erreur
structurelle. Les 18 sauvegardes/reprises effectivement atteintes ont toutes
réussi. Le même état de héros, l'inventaire, l'XP, les attributs, l'arbre, les
récompenses et les refuges ont été conservés entre les combats.

**GARDE D'INTERPRÉTATION.** Ce résultat décrit un bot heuristique déterministe
sur une seule graine. Les trois routes qu'il termine ne constituent pas un taux
de victoire de 25 %, et les durées headless ne mesurent pas la durée humaine
cible de 30–45 minutes.

| Difficulté | Arme | Issue observée | Combats atteints | Profondeur finale | Tours cumulés |
|---|---|---:|---:|---:|---:|
| Normal | Arc | route terminée | 12 | XX | 44 |
| Normal | Disque | défaite | 5 | VI | 22 |
| Normal | Hampe | défaite | 4 | V | 19 |
| Normal | Lame | boucle du bot puis défaite | 6 | VIII | 76 |
| Normal | Marteau | défaite au boss | 12 | XX | 60 |
| Normal | Xiphos | boucle du bot puis défaite | 6 | VIII | 91 |
| Facile | Arc | route terminée | 12 | XX | 43 |
| Facile | Disque | défaite au boss | 12 | XX | 57 |
| Facile | Hampe | défaite | 9 | XIII | 56 |
| Facile | Lame | défaite au boss | 12 | XX | 78 |
| Facile | Marteau | route terminée | 12 | XX | 59 |
| Facile | Xiphos | plafond du bot | 6 | VIII | 110 |

## Ce que la matrice permet réellement de dire

- **OBSERVÉ — Facile agit dans le bon sens sur les paires interprétables.** Au
  seuil, les 52 PV ennemis de Normal deviennent 47 PV en Facile, cohérent avec
  l'arrondi de ×0,9. Sur des impacts comparables à la profondeur II, les dégâts
  résolus baissent également : par exemple Massue contre Marteau passe de 14 à
  11 et quatre Flèches totalisent 42 contre 33. Le Disque va de VI à XX, la
  Hampe de V à XIII et le Marteau transforme une défaite au boss en victoire.
  L'Arc termine les deux variantes. Lame et Xiphos sont contaminés par la limite
  de navigation décrite ci-dessous.
- **OBSERVÉ — les secours changent la continuité.** Le pilote emploie le service
  réel de relique/fourniture puis les deux potions mineures réelles lorsqu'il
  passe sous son seuil. Dans le sanity Marteau Normal, cela transforme le point
  critique VI en victoire, puis les trois refuges permettent d'atteindre XX.
  Tous les repos atteints dans la matrice réussissent ; les différences 30 % / 
  40 % sont exercées par la session réelle, avec plafonnement aux PV maximum.
- **OBSERVÉ — le signal multi-armes reste très dispersé.** Arc et Marteau
  donnent au pilote une progression courte et stable, tandis que Disque et
  Hampe accumulent davantage de mouvements et de dégâts avant leur défaite.
  Une seule graine ne sépare toutefois pas la faiblesse d'un preset, un mauvais
  choix de route ou une politique de bot mal adaptée.
- **RECOMMANDATION.** Utiliser ces résultats pour sélectionner des replays
  humains ciblés (VI Disque, V/XIII Hampe, XX Marteau/Disque), pas pour modifier
  automatiquement les PV ou dégâts ennemis.

## Cause Lame / Xiphos à VIII

**OBSERVÉ — limitation du pilote, pas preuve d'un défaut de kit.** Aucun tour
n'est déclaré inactif, mais les actions ne font plus progresser le combat :

- Lame Normal : 45 tours dans VIII, 45 déplacements et 33 positions répétées.
  Le bot lance `exp_posture` 43 fois mais seulement six attaques. Il alterne
  principalement entre `(2,5)` et `(4,5)` pendant que le Conducteur lance Trait
  de braise 42 fois. Lame Facile franchit la même salle en 11 tours : la
  différence d'ordre de mort et de position suffit à éviter la boucle.
- Xiphos Normal : 38 tours, 69 déplacements, 27 positions répétées, Garde de
  salve 38 fois et Taille seulement cinq fois. Xiphos Facile atteint le plafond
  de 60 tours avec 113 déplacements, 49 répétitions, 60 Salves et toujours cinq
  Tailles. Les tirages de Reflux repoussent régulièrement le pilote dans son
  détour autour de l'obstacle.

Un correctif unique et borné a été ajouté après cette matrice : après au moins
deux tours sans cast offensif, une alternance ABAB ou une troisième visite de la
même position remplace uniquement le prochain déplacement volontaire glouton
par le préfixe du chemin de détour déjà calculé. Les buffs légaux restent
autorisés. Toute boucle résiduelle avec au moins 35 % de positions répétées sur
huit tours est classée `bot_limitation_suspected`. Il ne change aucune donnée de
production.

### Rejeu causal borné après correctif

**OBSERVÉ.** Seuls les trois cas convenus ont été rejoués :

- Lame Normal franchit désormais VIII en 38 tours, avec huit répétitions et
  quatre détours forcés, contre une mort en 45 tours et 33 répétitions avant le
  correctif. La run atteint XIII et s'y termine après neuf combats, 94 tours
  cumulés.
- Xiphos Normal meurt toujours à VIII après 38 tours, mais passe de 27 à six
  répétitions et de 32 à 11 mouvements de fallback. Il ne lance pourtant Taille
  que six fois contre 38 Salves : la boucle géométrique est réduite, pas le biais
  ultra-défensif de cette politique.
- Xiphos Facile franchit VIII en 44 tours et termine la route, au lieu d'atteindre
  le plafond de 60 tours à VIII. Il totalise cependant 155 tours sur la run.

**CONCLUSION.** Le correctif causal réduit bien l'oscillation. Ces durées restent
dominées par les choix du bot et ne certifient ni la cible humaine de 30–45
minutes, ni une faiblesse intrinsèque de la Lame ou du Xiphos. Aucun autre
ajustement ou rejeu du pilote n'est justifié avant un playtest humain ciblé.

## Limites restantes

- Le chemin dépend de la graine et de la profondeur, jamais de l'arme ou des PV.
  Le lore réel peut révéler une branche et donc modifier ensuite la liste des
  destinations disponibles.
- La politique équipe seulement des sorts réellement connus et achète une
  séquence déterministe liée à l'axe de l'arme. Elle n'est ni optimale ni une
  recherche exhaustive de builds.
- Lore, secours et refuges sont exercés. Le pilote sait choisir une branche
  compatible et une mémoire tardive, mais la route de cette graine n'a présenté
  aucun de ces deux choix ; ils restent donc non vérifiés par cette matrice. Les
  marchands et paris sont volontairement ignorés : l'économie n'est pas couverte
  complètement.
- Aucun HUD, télégraphe visuel, animation, temps de réflexion ou qualité de
  compréhension n'est simulé.
- La couverture `raw_damage_received_known` porte sur les impacts directs qui
  exposent un `DamageResult`; les faits résolus de l'EventBus couvrent en plus
  les effets automatiques et périodiques.

## Preuves

- Matrice : `artifacts/catabase_run_balance_validation/stage1_seed2401_v2/report.json`
- Résumé process : `artifacts/catabase_run_balance_validation/stage1_seed2401_v2/summary.json`
- Contrat GUT avant matrice :
  `artifacts/dev/20260914-162142-test-test_unit_test_catabase_run_balance_harness.gd-1fcc1b58/gut-strict-report.json`
- Comparaison avant fallback :
  `artifacts/catabase_run_balance_validation/first_case_2401_normal_marteau/report.json`
- Sanity continu V2 (12 combats atteints, deux reprises) :
  `artifacts/catabase_run_balance_validation/v2_sanity_2401_normal_marteau/report.json`
- Rejeu causal Lame Normal :
  `artifacts/catabase_run_balance_validation/loop_recheck_lame_normal/report.json`
- Rejeu causal Xiphos Normal/Facile :
  `artifacts/catabase_run_balance_validation/loop_recheck_xiphos_both/report.json`
