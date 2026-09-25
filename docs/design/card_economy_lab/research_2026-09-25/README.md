# Audit systémique — cartes consommables et butin de mobs

**25 septembre 2026. Point d'entrée pour reprendre sur un autre ordinateur.**

Le concept peut produire un jeu intéressant : chaque action engage une ressource de run, et les combats alimentent de nouvelles possibilités. Sa difficulté principale est de conserver une identité de build, des décisions tactiques et un approvisionnement praticable lorsque chaque exemplaire disparaît à l'usage.

Cette étude confronte **21 références commentées**, l'état du dépôt et **320 000 nouveaux parcours de budget**. Elle contient un audit statique, des calculs et des propositions. Aucun système du jeu n'a changé ; aucun résultat ne constitue une validation de plaisir ou de victoire tactique.

## Couverture et lecture

| Parties demandées | Sous-parties traitées | Document |
|---|---|---|
| Drop et taux | Éligibilité des mobs, sacs, reçus, invocations, espérance, variance, monotonie, pénurie | [1 — Drops et économie](01_DROPS_RARITY_ECONOMY.md) |
| Rareté | Six rangs, probabilité par run, doublons, accès aux builds | [1](01_DROPS_RARITY_ECONOMY.md) |
| Économie et deck | Sources/dépenses, troc, prix, conversions, réserve, dilution de pioche | [1](01_DROPS_RARITY_ECONOMY.md) |
| Reliques et équipements | Déclenchements, plafonds, interactions, 72 objets actuels, comparaison | [2 — Build et progression](02_BUILD_STATS_PROGRESSION.md) |
| Statistiques et caractéristiques | Cumuls, seuils PA/dégâts, rendement marginal, bonus plats | [2](02_BUILD_STATS_PROGRESSION.md) |
| Évolution et niveaux | XP, maîtrise, spécialisation, investissement consommé, persistance | [2](02_BUILD_STATS_PROGRESSION.md) |
| Classes et sorts | Redondances, verbes communs, quatre boucles proposées, contrôle | [2](02_BUILD_STATS_PROGRESSION.md) et [3](03_RUN_TACTICS_BALANCE.md) |
| Run et combat tactique | Rythme, branches, informations, géométrie, cinq salles existantes, boss, secours | [3 — Run et tactique](03_RUN_TACTICS_BALANCE.md) |
| Équilibrage et joueurs | Segmentation, biais, télémétrie, abus, observation, critères | [3](03_RUN_TACTICS_BALANCE.md) |
| Évolution des références | Problèmes, décisions des studios, mises à jour et limites des transferts | [Sources](SOURCES.md), cas détaillés dans les trois chapitres |

## Conclusions principales

1. **Une table généreuse ne suffit pas.** La candidate croissante finance 98,845 % du profil central si tout le butin est utile, mais laisse une médiane de cinquante cartes aux parcours financés. En stress à 70 % d'utilité, elle tombe à 65,670 %. Travailler composition des sacs, troc et dépenses réelles avant d'augmenter encore les taux. Ce sont des résultats de financement, jamais de victoire.
2. **L'acquisition actuelle vise des cartes durables.** Jets par victoire, cartes unitaires, starters exclus : passer aux sacs par mob et à la consommation implique inventaire, reçus, améliorations et sauvegardes.
3. **L'identité doit survivre aux copies.** Les points de perfection améliorent actuellement un exemplaire précis. Tester un investissement par famille pour la durée de la run, avec consommation normale des copies. Réserver éventuellement l'amélioration ponctuelle d'exemplaire à une préparation en or.
4. **Les couches de puissance se ressemblent.** Passifs, spécialisations et affinités d'équipement renforcent souvent les mêmes conditions. Six groupes de signatures identiques apparaissent dans les 84 lignes examinées, sans prouver une équivalence complète. Garder un socle partagé et différencier les situations recherchées par chaque classe.
5. **Le calendrier XP doit servir la run.** Avec les récompenses fixes examinées, le boss arrive au niveau 12 ; le niveau 13 vient après sa défaite, le 14 n'est pas atteint. Vérifier les autres sources éventuelles avant d'en faire un invariant runtime.
6. **Les rangs extrêmes ne peuvent pas porter les builds standards.** Le canal Immortel donne environ 0,1399 % de chances de découverte avant le boss sur une route complète. Les normales doivent faire fonctionner la boucle de classe.
7. **Les outils tactiques existent déjà.** Forge, Jardin, Convoi, Sablier, Réservoirs et protections de stase sont de bons points d'appui. Les éprouver avec la nouvelle économie avant d'ajouter des systèmes redondants.

## Enseignements des références

Le corpus comprend DOFUS, WAKFU, WAVEN, Magic, Slay the Spire, Monster Train, Balatro, Hades, Into the Breach, Diablo IV, Path of Exile 2, Last Epoch, Hearthstone et les réflexions de Larian sur Baldur's Gate 3 / Divinity. Les cas sont datés et sourcés dans les chapitres.

Les leviers étudiés sont concrets : quantité et qualité séparées ; objets comparables ; cumuls bornés ; contraintes temporelles ; accès à une synergie distinct de sa puissance ; fonction propre à chaque couche. Une annonce de refonte n'est pas une solution déjà validée. Les témoignages joueurs servent à identifier des situations de test, pas à fabriquer un consensus. Aucun entretien de joueur Catabase n'a été réalisé ici.

## Priorités de reprise

| Priorité | Décision / expérience | Preuve attendue |
|---|---|---|
| P0 | Durée de vie d'une copie : jouée, non jouée, fuite, reprise | Contrat sans duplication ni perte involontaire |
| P0 | Socle de normales et jackpots séparés | Quatre classes fonctionnelles sans rare obligatoire |
| P0 | Dépenses réelles avec gestes de secours | Distributions par classe, rencontre et politique de dépense |
| P0 | Base, candidate croissante et troc | Pénurie par combat, surplus, pertinence et temps de tri |
| P0 | Amélioration de copie ou de famille | Jouer sa meilleure carte ne détruit pas l'identité construite |
| P1 | Rôles de classe, équipement, relique | Trois arbitrages distincts et explicables |
| P1 | Contrôles et PA cumulés | Pas de boucle entre familles, copies et objets |
| P1 | Salles existantes avec le nouveau stock | Placement utile et économies de cartes mesurées |
| P1 | Decks 15/20/30 et mains 4/5 | Réponses disponibles et durée de réflexion |
| P1 | Tous les usages de l'or | Soins, équipements et ravitaillement réellement concurrents |
| P2 | Persistance entre runs | Budget de départ et surplus recalculés |
| P2 | Prospection/reliques de drop/performance | Base stable, impact marginal documenté |
| P2 | Davantage de contenus Dieu/Immortel | Fréquence assumée, aucun accès obligatoire |

La demande actuelle porte sur la recherche et le rapport. Ces recommandations ne remplacent pas le mode public. Un prototype isolé pourra éprouver les premières décisions lorsqu'une implémentation sera demandée.

## Base et points d'entrée

Commit inspecté : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.

| Sujet | Source |
|---|---|
| Contrat public | [Produit courant](../../../current/product.md) |
| Acquisition / copies | [card_drop_catalog.gd](../../../../core/expedition/card_drop_catalog.gd), [class_cards.gd](../../../../core/expedition/class_cards.gd) |
| Cartes | [class_card_catalog.gd](../../../../core/expedition/class_card_catalog.gd), [card_ecosystem_catalog.gd](../../../../core/expedition/card_ecosystem_catalog.gd) |
| Équipements / reliques | [class_equipment_catalog.gd](../../../../core/expedition/class_equipment_catalog.gd), [catabase_preparation_catalog.gd](../../../../core/expedition/catabase_preparation_catalog.gd) |
| Route / ennemis | [catabase_route_v6.gd](../../../../core/expedition/catabase_route_v6.gd), [catabase_monster_encounter_catalog.gd](../../../../core/expedition/catabase_monster_encounter_catalog.gd) |
| Salles | [card_tactical_room_catalog.gd](../../../../core/expedition/card_tactical_room_catalog.gd) |
| Progression | [Profil Achille](../../../../data/runs/progression/odyssey/achilles_champion_progression_v0.tres), [champion_progression_state.gd](../../../../characters/progression/champion_progression_state.gd) |

Le script extrait XP et signatures directement ; les effectifs restent une transcription datée du laboratoire parent. La lecture des définitions n'est pas une vérification de tous les chemins d'exécution. Le calcul ne couvre pas tout le catalogue ni toutes les anciennes sauvegardes.

## Fichiers et validation

* [SOURCES.md](SOURCES.md) : 21 références, dates et limites.
* [MATH_RESULTS.md](MATH_RESULTS.md) : hypothèses, résultats et commandes.
* [RESULTS.csv](RESULTS.csv) : seize cas avec intervalles et quantiles.
* [systems_math.mjs](systems_math.mjs) et [tests](systems_math.test.mjs) : outils sans dépendance externe.
* [WORKLOG.md](WORKLOG.md) : fiche courte et validations exécutées.
* [Laboratoire initial](../README.md) : modèle parent, sources complémentaires et vingt cartes proposées.

Les sorties brutes se régénèrent dans `artifacts/dev/`. Ce dossier, son parent et les sources du dépôt suffisent pour reprendre l'étude. Aucun commit ou push n'a été réalisé ; les fichiers locaux ne sont pas automatiquement disponibles sur l'autre ordinateur.

## Message de reprise

> Lis docs/design/card_economy_lab/research_2026-09-25/README.md, les trois chapitres et MATH_RESULTS.md. Vérifie la fraîcheur du code depuis le commit indiqué et préserve les changements en cours. Relance les treize tests du laboratoire et les seize cas de calcul. Garde les contraintes : exemplaires consommés à l'usage, sacs sur les mobs, normales fréquentes, progression standard avant modificateurs. La variante historique early_supply n'est pas monotone ; la candidate croissante n'est pas un équilibrage retenu. Le stress 70 % représente une utilité supposée, pas une restriction de classe. Prochaine étape : contrat de consommation, socle normal, investissement par famille, puis mesure des dépenses et des gestes de secours sur les salles existantes. Ne confonds jamais financement et victoire. Toute implémentation doit préserver reçus, migrations, services Studio et validations habituelles du projet.
