# Investigation WAVEN et améliorations Catabase — 26 septembre 2026

- Demande : poursuivre l'investigation des améliorations, comparer aux jeux de référence, approfondir WAVEN et calculer leurs conséquences pour Catabase.
- Base Git relue : `c6ab5a72`. Travaux de sélection et de sprites en cours préservés.
- Le premier audit reste dans `docs/design/gameplay_critique_2026-09-25/` ; ne pas présenter ses résultats comme de nouvelles preuves.

## Plan et décisions

1. Distinguer les kits historiques de WAVEN, les annonces d'avril/août 2025 et les informations plus récentes vérifiables. Ne pas déclarer une refonte livrée à partir d'une annonce.
2. Étudier accès au deck, économie d'action, maintien/conversion des ressources, passifs spatiaux, compagnons et couches de progression.
3. Confronter aux sources Godot et à la V1 consommable séparée.
4. Tester séparément ouverture préparée et politique de réapprovisionnement sur de nouvelles graines ; ne pas modifier le gameplay public.
5. Livrer calculs, expériences, sources datées et recommandations priorisées dans un nouveau dossier.

## Livraison

- Dossier : `docs/design/waven_investigation_2026-09-26/` : README critique, SOURCES, protocole/résultats EXPERIENCES, quatre PROTOTYPES, scripts et JSON complets. `.gdignore` isole le laboratoire de l'import Godot.
- Sources WAVEN : diagnostic d'avril et Community Update d'août 2025 lus dans le flux officiel Steam ; note 0.13.1 d'Ankama lue via sa reproduction SteamDB. Annonces distinguées des règles livrées. Actualité officielle 2026 retrouvée mais corps bloqué : pas de prétention à certifier la refonte actuelle.
- 120 runs comparatifs terminés, graines 27001–27010, quatre classes/première spécialisation : 29/40 référence, 32/40 ouverture normale garantie, 38/40 politique achats/trocs ciblés. Celle-ci sauve neuf runs sans perte appariée ici ; politique composée, petit échantillon, pas validation humaine.
- Deux relectures diagnostiques : Thaumaturge 27001/27005 meurt au combat 3/tour 17, avant boutique ; >97 % des dégâts aux PV viennent de la pression. Offensive préparée épuisée, bot défensif, absence d'anticipation explicite de la pression dans son évaluateur. Pas de buff de classe justifié par ces seuls échecs.
- Décision : traiter continuité fonctionnelle, information marchande et biais du bot avant d'empiler réserve PA/compagnons/raretés. Normal préparée prometteuse mais hétérogène ; arbitrer les deux refontes concurrentes de Répercussion ; petites maîtrises spatiales à tester séparément.

## Vérifications terminées

- Sources V1 inchangées, quatre SHA-256 concordants. HEAD relu en fin de tâche : `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`.
- 132 contrats d'ouverture ; baseline instrumentée identique au module original sur une graine.
- 120 exécutions / 1 359 combats observés / 330 achats-trocs ciblés vérifiés ; budgets non négatifs, accès, préfixe avant première boutique identique. Service de transactions V1 réutilisé.
- Calculs `--check` réussis, formule d'accès contrôlée aussi par énumération.
- Suites `model.test.mjs` et `contracts.test.mjs` : 199 tests réussis, zéro échec/annulation/ignoré.
- Journaux, variantes générées et résultats complets : `artifacts/dev/waven-investigation-2026-09-26/`.
- Aucun gameplay Godot ni manifeste V1 modifié. Aucun test runtime revendiqué ; sprites/sélection et autres fichiers de recherche d'autres tâches préservés.

## Suite possible, hors livraison

- Isoler achats unitaires, trocs et protection du stock dans une prochaine expérience ; les trois contribuent au bras ciblé actuel.
- Évaluer une politique qui anticipe la pression avant de reclasser la difficulté des classes.
- Observer quelques parties humaines pour la compréhension des copies, de la boutique et des aperçus.

## Suite 02 livrée — demande « Continue »

- HEAD et sources relus, toujours `c6ab5a72` ; protocole fixé dans `waven_investigation_2026-09-26/suite_02/PROTOCOLE.md`.
- Plan : 320 runs factoriels A/T/P sur nouvelles graines 28001–28010, puis 120 runs de politiques de pilotage (urgence, phase ennemie simulée, urgence+A/T/P). Baselines partagées, aucune retouche du gameplay public ni de la V1.
- Les résultats et limites de la première étude restent conservés ; cette suite peut confirmer ou contredire ses recommandations.
- 440 runs terminés : référence 34/40 ; achats seuls 39 ; trocs seuls 37 ; achat+troc 39 ; protection sans effet sur les 160 paires complètes. Urgence seule 39 ; simulation de phase 21 ; urgence+achat/troc/protection 40.
- Le 40/40 reste local : ancienne graine Thaumaturge 27005 toujours perdue au combat 3 avec urgence (et boutiques inaccessibles avant). Phase simulée : Assassin 28001 reste inactif face à un ennemi à 19 PV, mort par pression seule.
- 440 conservations d'inventaire, 5 111 combats et 2 127 transactions ciblées contrôlés, SHA-256 concordants. Pas d'ajustement des poids après lecture des résultats.
- Six micro-scénarios corrigent l'idée Faille transmissible : durée de marque, verrou de famille, geste de secours, dégâts excédentaires et seuils de kill. Calculs marchands : 30,28 % d'une normale précise dans un sac de six à 36 or, contre une certaine à 8 or si disponible.
- Rapport, sources exécutables et JSON : `docs/design/waven_investigation_2026-09-26/suite_02/`. Nouvelle priorité : achat unitaire lisible, pression en PV, audit à plusieurs politiques ; pas de hausse arbitraire des prix ni de buff global.
