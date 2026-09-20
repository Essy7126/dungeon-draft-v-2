# Écosystème Cartes — travail du 20 septembre 2026

**Historique de la première itération.** Le choix parmi trois cartes et les
raretés garanties décrits ci-dessous sont remplacés par les drops aléatoires
de la [révision 2, Résonance des échos](CARD_DROPS_2026-09-20.md).
Les mesures et captures ci-dessous concernent l'ancien mécanisme de récompense.

Demande : deck évolutif, départ modeste, choix de butin et boutique, cartes
reconnaissables (classe/rôle/rareté), ennemis exploitant le terrain avec contre-jeu.

Base : modifications préexistantes conservées. Diff avant intervention :
artifacts/dev/cards_ecosystem_baseline_20260920/worktree-before.patch.
Pas de délégation, de commit/push ni de modification des sauvegardes joueur.

Décisions : extension du système Classes (rules_revision 3) avec un champ
écosystème versionné. Les sauvegardes sans ce champ conservent leur économie.
Cartes d'initiation distinctes ; récompense parmi trois propositions, possibilité
de refuser ; remplacements explicites, boutique élargie et paliers de profondeur.
Les nouveaux effets passent par SpellCaster, StatusData et TerrainEffects.
Contrôles forts bornés et attaques ennemies annoncées ; aucune chaîne infinie de
passages de tour. Visuels réutilisent les illustrations disponibles.

Implémenté :

- 28 cartes d'initiation (7 par classe, 5 familles choisies en deux exemplaires),
  sans bonus de puissance des maîtrises. Le départ conseillé contient frappe,
  marque, garde, saignement et exploitation de marque.
- 84 techniques acquérables, dont 24 nouvelles. Aucun starter dans les drops
  ou boutiques. Trois propositions persistantes par victoire hors boss final ;
  deux de la classe principale et une ouverte. La première garantit le meilleur
  palier disponible : usuel, rare dès profondeur 4, épique dès profondeur 10.
- Choisir puis remplacer une copie, prendre en réserve ou passer. La carte
  remplacée reste possédée. Dix cartes actives, deux exemplaires maximum.
  Pas de deuxième attribution au rechargement ou après double clic.
- Six achats distincts par halte, prix existants 50/75/110 selon palier,
  stock et achats persistants. Achat en réserve, équipement explicite du deck.
- Cartes visibles en main, récompense, boutique et collection : titre, art,
  coût, portée, valeurs et effet. Couleur de cadre par classe, bandeau de rareté,
  couleur de rôle et libellés textuels ; fiches détaillées conservées.
- Entrave PM, perturbation PA, attraction/charme (ne change pas d'équipe),
  traversée, zones de braises et givre, stase conditionnelle sur marque.
  Stase : recharge 4, une activation perdue, protection 3 activations ; Paris
  perd seulement 1 PA. Les surfaces durent 2 tours et affectent les deux camps.
- À partir de profondeur 5, kits ennemis différenciés par rôle. Officiants et
  guérisseurs invoquent un serviteur sur une dalle annoncée à la prochaine
  activation ; occupation de la dalle bloque l'appel. Recharge 4, plafond
  de 6 ennemis vivants, pas d'invocation récursive. L'IA sait choisir une dalle
  libre d'invocation et valorise le retrait de PA. Résistance +15 % et attaque
  +8 % à partir de profondeur 7. Ouverture et Paris gardent leurs données.

Fichiers principaux : `core/expedition/card_ecosystem_catalog.gd`,
`card_ecosystem_effects.gd`, `card_enemy_ecosystem.gd`, `class_cards.gd`,
`class_card_catalog.gd`, `expedition_flow.gd`, `expedition_run_factory.gd`,
`core/ai/catabase_monster_decision.gd`, `ui/expedition/class_card_reward.gd`,
`class_card_tile.gd`, `class_workshop.gd`, `catabase_card_hand.gd` et les
raccordements Session/GameManager/ExpeditionScreen.

## Vérifications terminées

- `./dev.ps1 test test/unit/test_catabase_class_run.gd` : **22/22**, 2451
  assertions, import et analyse stricte réussis. Rapport :
  `artifacts/dev/20260920-183319-test-test_unit_test_catabase_class_run.gd-ec459706/`.
  Comprend les 112 casts, sauvegardes JSON, routes des quatre classes,
  récompense/refus/remplacement, achat unique, ancienne économie, stase et
  dégâts alliés/ennemis puis expiration des braises.
- `./dev.ps1 test monsters` : **77/77**, 17789 assertions. Rapport :
  `artifacts/dev/20260920-183725-test-monsters-91856f7a/`.
  Inclut le choix réel d'une dalle d'invocation, sa résolution et les kits par rôle.
- Sonde UI complète : **370 contrôles réussis, 54 captures**, 1280×720 et
  1920×1080 ; processus terminé à 0, aucun diagnostic moteur. Rapport et images :
  `artifacts/dev/cards_ecosystem_ui_shop_20260920/`. Inspection visuelle des
  cartes en combat, de la récompense, du remplacement et de la boutique.
  Clic d'achat vérifie débit exact, copie en réserve et rupture du stock.
  Le combat d'ouverture est réel ; les frontières de victoire suivantes sont
  injectées pour contrôler l'interface, pas pour prétendre prouver l'équilibrage.
- `./dev.ps1 test catabase` : **494/510**, donc validation globale **en échec**.
  Rapport : `artifacts/dev/20260920-182300-test-catabase-59eace69/`.
  Les 16 échecs portent sur les anciens contrats d'art/icônes, sélection,
  seuil, formations historiques, objets de départ et présentation des reliques.
  Ne pas les masquer ni considérer ce résultat comme une CI verte. Cette suite
  précède les derniers ajustements, recouverts par les tests ciblés ci-dessus.
- `git diff --check` : aucun défaut d'espacement. Le formateur GDQuest refuse
  `card_ecosystem_effects.gd` avec son contrôle « structurally different » ;
  aucun contournement du vérificateur. Le script est accepté et exercé par Godot.

## Mesure de difficulté et limites

18 simulations terminées, graines 2401/2402/2403 : 12 classes et 6 anciens decks
de comparaison. Rapport `artifacts/dev/cards_ecosystem_adaptive_20260920/report.json`,
aucune erreur technique, sortie 0. Politique gloutonne en puissance, choix de
récompense par valeur immédiate/PA, remplacement de la plus faible valeur,
un achat possible par halte et équipement automatique du butin.

| Classe | Dernière profondeur par graine | Boss vaincu |
|---|---|---|
| Assassin | 3 / 10 / 5 | 0/3 |
| Gardien | 3 / 6 / 6 | 0/3 |
| Arpenteur | 20 / 10 / 8 | 1/3 |
| Thaumaturge | 6 / 15 / 8 | 0/3 |

Ces résultats signalent une difficulté encore élevée au contact, pas un taux
de victoire humain. Le bot valorise mal les synergies, le contrôle différé et
la conservation de cartes. L'équilibrage n'est donc pas déclaré définitif.
Les premiers essais remplaçaient aveuglément le premier starter par la première
proposition : ils restent archivés et ne sont pas utilisés comme validation finale.

Les sauvegardes sans `ecosystem_revision` conservent l'attribution automatique,
le stock de trois et les anciens ennemis. Les nouveaux départs utilisent la
révision 1. Essayer avec **Nouvelle partie → Cartes**.

Historique local relu : HEAD `6542c427`, précédents `6ffcf4c8`, merge `4e6c0201`.
Aucune suppression trouvée dans l'historique interrogé de `core/expedition`
et `ui/expedition`. Cela ne prouve pas l'état d'une branche distante non récupérée.
