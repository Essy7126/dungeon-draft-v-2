# Baseline d’équilibrage structurelle

## Variante Cartes — WORKTREE_CANDIDATE, 2026-09-16

Base `main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + worktree.
Courbes héros/ennemis, PA/PM, armes, route et XP classiques inchangées.

- Deck 12–18 ; 6 Gestes maximum, 3 copies par autre famille ; 2 Gestes et
  2 techniques minimum. Départ 6 + 3 + 3, toutes liées et non revendables.
- Main 4, puis 5 au niveau 5 ; choix XII de capacité : 6. Ouverture 2 + 2,
  maintien d'une copie, recomposition 1 PA une fois par activation.
- Drop normale 1 + Bernoulli(0,25) ; élite 2 + Bernoulli(0,25), dont une
  Héroïque+ ; zéro après XX. 14–25 drops utiles possibles sur 11 victoires.
- Achat Usuelle/Gravée/Héroïque/Mythique/Légendaire : 50/75/110/160/230 ;
  revente 8/12/20/32/50. Stock 3 par marchand/refuge VII/XI/XVI, pas XIX.
- Mode Cartes : or de victoire 35/65 conservé ; le choix complémentaire
  « Provisions du voyage » soigne 5 % et donne **20 oboles** depuis l'itération
  après audit du 16 septembre. Auparavant : 0 obole. En Classique : toujours 40.
  Ce n'est pas un bonus automatique ajouté aux équipements/reliques choisis.
  Les reçus déjà réclamés ne sont pas compensés lors d'une reprise de sauvegarde.
- Rareté et niveau indépendants ; pas de multiplication des dégâts par rareté.
  Quotas de sort et réserves de soin communs à toutes les copies de la famille.

Poids exacts, filtrage des pools, limites et preuves :
[rapport Cartes](CARDS_RUN_IMPLEMENTATION_NOTES.md). Pas de taux de victoire
humain ni de budget de puissance neutre démontré.

Motif du réglage : dans la fixture historique à pool initial figé, la revente
moyenne de tous les drops vaut 212,53 oboles. Onze provisions à 20 ajoutent 220,
soit 432,53 contre 440 pour les anciennes onze provisions. Cette comparaison
ne représente ni une stratégie recommandée (elle revend tout), ni un budget
réel constant : garder les cartes et choisir les autres récompenses coûte
toujours cette liquidité. Prix de cartes/services et courbes de stats inchangés.
Le contre-test de protection mixte sur Disque/Hampe a des résultats contrastés ;
**aucun preset de départ n'a été changé**. Voir [preuves](CARDS_ITERATION_2026-09-16.md).

## Catabase r6 — candidat 2026-09-14, non certifié humainement

Branche `main`, base `055584c37f60d99b2f87bdbb4d670895bf8ef2b2` + worktree.

- Combats I/II/III/V/VI/VIII/X/XII/XIII/XV/XVII/XX ; élites VI/X/XV ;
  refuges VII/XI/XVI. 24 points de maîtrise avant Pâris ; capacité XII conservée.
- XP brutes : 100/125/145/175/195/215/245/265/295/325/355/345,
  soit 2 440 avant Pâris et 2 785 après, hors Sagesse. Les haltes valent 0 XP.
- Normal : refuges 30 % PV maximum une fois. Facile : 40 %, PV ennemis ×0,90,
  dégâts ennemis ×0,80, mêmes PA/PM, compositions, règles et récompenses.
- Les PV/attaques ennemis proviennent des références fixes du catalogue,
  jamais des statistiques réelles du joueur ; les packs sont normalisés par
  leur résistance totale. Voir `V1_*` dans le catalogue des rencontres.
- Pâris : 560 PV, 4 PA, 3 PM ; deux spectres à 150 PV, 2 PA, 3 PM.
  Flèche 80, feu 65, glace 55, vortex 45 ; fouet 100, balayage 75, attraction 60.
  Feu propre à Pâris : 20 par déclenchement, Brûlure 12. Seconde forme sous
  20 % après un coup non fatal : soin intégral et 30 bouclier, une fois.
- Salve : réduction max(6 ; arrondi(33 % P)) sur trois impacts ; variantes
  max(5 ; arrondi(27,5 % P)) sur cinq ou max(8 ; arrondi(44 % P)) sur trois.
  Urne : plafond max(40 ; arrondi(2,2 P)), dépense max(30 ; arrondi(1,65 P)),
  charge égale à la moitié arrondie vers le bas de la garde réellement absorbée ;
  Répercussion inflige 1,5 fois la réserve dépensée. Pas de boucle de recharge.
  Coupe : plafond max(30 ; plancher(10 % PV)), soin de 15 % des dégâts
  physiques directs réellement infligés, réserve débitée du soin réel.
  Les réserves sont figées à l'entrée ; les sorts utilisent la Prouesse du lancer.
- Braise : 0,70 P direct + max(6 ; 0,15 P) ×2 ; durable 0,50 P +
  max(6 ; 0,25 P) ×3 ; brève 0,90 P + max(10 ; 0,15 P) ×1.
  Conduction : +8 % sur la référence Prouesse des dégâts élémentaires en r6,
  sans amplifier les actions physiques neutres ; bonus global en legacy.
- Économie préservée : 60 au départ, +35/+65 par victoire normale/élite ;
  fournitures de butin +40 oboles ET soin 5 %, et non un achat de soin à 40.
  Mémoire tardive sans secret futur : une fourniture garde/mobilité au choix,
  sans oboles supplémentaires. XIX : ni soin ni objet.
- Plaque d'offrande en r6 : max(24 ; arrondi(10 % PV maximum à l'usage)),
  toujours 1 PA et une activation. L'ouverture et les anciennes runs gardent
  24. Ajustement motivé par son alternative tardive au Souffle (+2 PM), pour
  que le choix de mémoire ne soit pas automatiquement dominé par la mobilité.

Valeurs initiales à confronter aux runs : le
[suivi](CATABASE_R6_WORKLOG_2026-09-14.md) fait autorité sur les validations
réellement effectuées et sur les ajustements suivants.

## Impulsion du vide et Choc — PROVISIONAL (2026-08-12)

- Impulsion du vide : **+1 PM pendant l'activation courante**, une fois par
  unité et par round, non cumulable. Valeur provisoire à réévaluer par playtest.
- Choc d'eau électrifiée : valeur existante de 20 dégâts Foudre conservée ; au
  maximum un déclenchement par unité/round pour une région électrique.
- Entrée volontaire : actions courantes consommées, pas de skip automatique de
  l'activation suivante. Entrée forcée hors activation : prochaine activation
  sautée une fois.

## Poison de terrain — PROVISIONAL — à rééquilibrer par playtest

- statut `poison`, nom Poison ;
- 4 dégâts magiques au début du tour ;
- durée 3 activations ;
- élément NONE ; défense ignorée ; esquive interdite ;
- aucun malus PA/PM et aucun blocage de vision ;
- terrain praticable, coût 1, danger IA 2,0.

L’eau électrifiée réemploie la valeur de Choc existante (20 dégâts Foudre) et
Mouillé. La lave conserve 15 dégâts directs et ajoute la Resource Brûlure
existante sans en modifier les valeurs.

## L’Odyssée — baseline expérimentale, non production

Ces valeurs décrivent le prototype Achille solo et ne remplacent pas la baseline
de production. La slice contient trois salles, un seul héros et une rencontre
unique par salle. Achille possède 110 PV, initiative 14, 6 PA, 3 PM et attaque 18,
sans attaque générique. Ses quatre actions, limitées à une utilisation par
combat, sont Estoc (2 PA, portée 1–2, 9 dégâts), Avancée (2 PA, ligne 3,
5 dégâts puis déplacement), Balayage (3 PA, adjacent, 6 dégâts et poussée 1) et
Garde (2 PA, bouclier 10).

Les trois rencontres sont fixes : deux tirailleurs ; deux tirailleurs et un
garde ; un champion et un tirailleur. Le tirailleur vaut 45 PV / 10 initiative /
4 PA / 4 PM / 10 attaque ; le garde 70 / 8 / 4 / 3 / 12 avec 20 armure ; le
champion 115 / 9 / 4 / 3 / 16 avec 30 armure. La cible de durée reste
18–25 minutes pour trois rencontres, à mesurer lors de la revue humaine.

L’économie expérimentale accorde deux potions de soin mineures et un parchemin
d’action mineur au départ, aucun équipement et aucune récompense d’équipement.
Aucune de ces valeurs n’est transférée automatiquement à la principale.

> Statut : **candidate locale, non promue CURRENT**.

Cette migration ne modifie aucune statistique de héros, d’ennemi, de sort,
d’équipement, d’XP ou de seuil de progression.

## Run principale de production

- 6 salles.
- 1 rencontre complète par salle.
- 6 combats projetés au total, indépendamment du seed.
- Multiplicateur lié aux vagues : `1.0` (neutre).
- Chance ultime liée aux vagues : `0 %` (désactivée).
- Aucun choix de continuation dans la même salle.

## Run de test

La run `WAVE_CHAIN` est exclue de la baseline d’équilibrage de production. Elle
conserve ses profils, ses plages, ses multiplicateurs, sa chance ultime et ses
rapports cumulés afin de tester le moteur historique de vagues.

La réduction structurelle du nombre de combats de production implique une mesure
ultérieure de la durée, de la cadence XP et de l’attrition ; ces valeurs ne sont
pas recalibrées dans `RUN_FLOW_ISOLATION_V1`.

## Note Item Studio V1 — WORKTREE_CANDIDATE

- Date : 2026-08-07 ; branche `main` ; HEAD de base
  `29f307b5ff61822f266bbd2d14636ca8dcea2d95`.
- Tests : empreinte agrégée comparée par GUT ; 30/30 tests Item Studio,
  190 assertions. Suite globale finale : 836/849, sans nouvelle catégorie
  d’échec par rapport à la baseline.
- Non vérifié : aucune nouvelle baseline d’équilibrage n’est proposée.

Aucune valeur d’objet de production n’est modifiée par le candidat. Les deltas,
EHP, breakpoints et budgets affichés sont des diagnostics ou estimations
exploratoires ; ils ne constituent pas une nouvelle baseline et ne réécrivent
jamais les données.
