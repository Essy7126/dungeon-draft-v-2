# Reprendre la V1 sur l’autre ordinateur

## Ce qui est livré

Le manifeste, le résolveur, l’économie, les tests, les générateurs de tables et les rapports sont dans ce dossier. Aucune dépendance npm ni installation Godot n’est requise pour refaire les calculs : Node 24 suffit. Les résultats portables sont des instantanés CSV/JSON ; les sorties détaillées se régénèrent dans `artifacts/dev/consumable-v1/`.

Les fichiers sont locaux dans l’arbre de travail. Aucun commit, push ou transfert vers l’autre ordinateur n’est implicite. Transférer le dossier ou l’inclure dans une livraison Git explicite ; conserver aussi `docs/design/card_economy_lab/` pour les recherches et le contexte antérieurs.

Ordre de lecture : [README](README.md), [règles](REGLES_V1.md), [catalogue](CATALOGUE.md), [maths et route](MATHS_ET_RUN.md), [bilan](BILAN.md), [recherche](RECHERCHE_ET_DECISIONS.md). Le [journal](ITERATIONS.md) explique pourquoi les premiers réglages ont été abandonnés.

## Rejouer les preuves

Depuis la racine du dépôt :

```powershell
node --test --test-isolation=none docs/design/consumable_v1/model.test.mjs docs/design/consumable_v1/contracts.test.mjs
node docs/design/consumable_v1/analyze.mjs
node docs/design/consumable_v1/export_tables.mjs
node docs/design/consumable_v1/summarize_runs.mjs
node docs/design/consumable_v1/verify_delivery.mjs
```

La campagne complète prend plusieurs minutes. Elle écrit progressivement son résumé, mais elle n’est terminée qu’après le message `Complete` et la création de `metadata.json`. Ce fichier donne les empreintes des entrées, la version de Node, la taille des expériences et les politiques utilisées. Un fichier partiel ou un arrêt anticipé n’est pas un résultat complet.

Le dossier de détails contient `card_scenarios.csv` (toutes les cartes, quatre niveaux, six situations, base/améliorée), `item_comparisons.csv` (effets avec/sans objet), `runs.json` (chaque graine, trajectoire, dépenses et usage des familles). Le rapport portable garde les synthèses correspondantes. On peut retrouver une mort par classe, spécialisation et graine, puis appeler `simulateRun({classId, specIndex, seed, trace:true})` pour obtenir ses actions.

## Écart avec le produit audité

Base Git inspectée : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Lire d’abord le [README produit](../../../README.md) et la [référence produit](../../current/product.md) si cette base a changé.

| Sujet | Produit audité | V1 proposée | Travail d’intégration |
|---|---|---|---|
| Préparation | Dix copies initiales, cinq familles ×2 dans Cartes | Quinze, maximum trente préparées, réserve distincte | Adaptation du profil Cartes et de la préparation, sans modifier Classique par accident |
| Cartes et progression | Catalogues de base, avancé et starters ; maîtrise et perfectionnement existants | 48 familles fermées, trois améliorations de famille | Choisir une migration explicite ; ne pas superposer les deux budgets |
| Drop | Jets par victoire, une carte par succès dans le catalogue actuel | Sept canaux par mort éligible, sacs de plusieurs exemplaires | Brancher les morts éligibles, UID et reçus sur le système existant |
| Équipement | Catalogue actuel de 72 objets par affinité, emplacement et palier | 18 choix horizontaux dans six emplacements | Profil indépendant ; ne pas écraser le catalogue partagé |
| Classes | Identités et spécialisations existantes | Identités calculées dans cette proposition | Adapter les passifs à la consommation réelle et aux déclenchements |
| Terrain | Les salles tactiques existent déjà dans le contenu | Sept petits plateaux, dont cinq mécanismes de salle simulés | Réemployer les services Studio et vérifier les géométries réelles |
| Run | Aventure publique, variantes et sauvegardes séparées | Route de test fermée de vingt profondeurs | Profil expérimental versionné avant toute bascule publique |
| Validation | Contrats et scénarios Godot du dépôt | Résolveur JavaScript autonome | Comparer les traces des deux moteurs sur les mêmes cas |

Points d’entrée inspectés : [class_cards.gd](../../../core/expedition/class_cards.gd), [class_card_catalog.gd](../../../core/expedition/class_card_catalog.gd), [card_ecosystem_catalog.gd](../../../core/expedition/card_ecosystem_catalog.gd), [card_drop_catalog.gd](../../../core/expedition/card_drop_catalog.gd), [class_equipment_catalog.gd](../../../core/expedition/class_equipment_catalog.gd). Ce dossier ne les modifie pas.

## Séquence d’implémentation recommandée

1. Créer un profil expérimental isolé, avec sa version de sauvegarde. Importer les 48 familles et leurs effets par les services de contenu existants ; ne pas rendre ce profil public avant concordance.
2. Porter consommation/UID, zones de pioche, limites de familles, préparation et réserve. Vérifier une reprise après chaque transition et une annulation de ciblage.
3. Porter progression, caractéristiques et passifs ; comparer des traces unitaires de dégâts, garde, marque, contrôle, déplacement, soins et mort simultanée.
4. Porter les tables de butin par mob et les marchands à reçus. Vérifier réouverture, sauvegarde au milieu d’un sac, doublons et porteur sacrifié.
5. Adapter les cinq salles avec les outils Studio, puis rejouer les rencontres à géométrie réelle. Les résultats du plateau 7 × 7 ne remplacent pas cette étape.
6. Exécuter les contrôles requis par [la validation actuelle](../../current/validation.md), l’import moteur et des runs complètes. Les tests `smoke` seuls ne couvrent pas ce changement.
7. Faire une session humaine observée avant de régler de nouveaux multiplicateurs. Conserver les valeurs initiales et les commentaires liés à chaque changement.

## Contrat de test humain préparé

Douze participants exploratoires, répartis selon expérience du tactique/deckbuilding, chacun deux essais : premier contact puis deuxième classe. Ce nombre sert à repérer des problèmes, pas à estimer précisément la rétention. Contrebalancer l’ordre des classes ; proposer les mêmes graines pour comparer sans forcer les mêmes décisions.

Observations requises : compréhension de la consommation, première hésitation à jouer une rare, usage du secours, préparation après un sac étranger, première dépense au marchand, soin contre équipement, gestion des deux premiers contrôles de terrain. Après défaite : demander ce que la personne changerait, puis vérifier si les données confirment son explication.

Indicateurs : durée des combats et de préparation, tours sans option comprise, proportion de réserve inutilisée, cartes rares gardées jusqu’à la mort, raisons de troc, compréhension des portées minimales, plaisir/contrariété attribués à la perte d’une carte. Il n’y a **pas encore de résultat humain** dans ce dossier.

Critères avant publication : aucune duplication/reroll ; aucune carte à effet incompris dans son scénario dédié ; accès à une stratégie viable sans rare ; absence de classe systématiquement économiquement condamnée après contrôle de l’expérience ; cause des morts compréhensible ; durée de préparation acceptable. Les seuils chiffrés de confort seront fixés à partir de ces sessions, pas inventés par le simulateur.
