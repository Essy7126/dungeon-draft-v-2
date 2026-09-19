# Classes : puissance mesurée et lisibilité

## Ce qui a été exécuté

18 runs automatiques en difficulté normale, graines 2401, 2402 et 2403 : les quatre départs de classes actuels et les deux anciens départs Cartes, marteau et arc. Les combats utilisent réellement `GridData`, `SpellCaster`, l'IA ennemie, le terrain et les effets. Les victoires ne sont pas injectées dans cette sonde.

Source complète : `artifacts/dev/class-balance-baseline/report.json` ; aucune erreur signalée par la sonde. Scénario reproductible : `tools/build_system_lab/class_balance_probe.tscn`, arguments `label=class-balance-baseline seeds=2401,2402,2403`.

La politique commune choisit gloutonnement les actions notées « balanced ». Pour les nouvelles classes : deck conseillé, caractéristiques en puissance, première spécialisation, maîtrise native prioritaire, amélioration des copies, équipement du butin et soin au refuge si possible. Aucune adaptation du deck aux drops. Le but de la comparaison est de détecter des écarts, pas de prédire le taux de victoire des joueurs.

## Résultats observés

| Départ | Profondeur finale par graine | Runs terminées par le programme | Tours moyens, combats 1–3 | PV perdus moyens par combat, profondeurs 2–3 |
|---|---|---:|---:|---:|
| Assassin | 6 / 6 / 6 | 0 sur 3 | 3,78 | 37,00 |
| Gardien | 15 / 6 / 20 | 1 sur 3 | 4,67 | 40,50 |
| Arpenteur | 20 / 20 / 20 | 2 sur 3 | 2,78 | 18,50 |
| Thaumaturge | 20 / 20 / 20 | 2 sur 3 | 3,22 | 30,33 |
| Ancien Cartes : marteau | 15 / 20 / 6 | 0 sur 3 | 4,33 | 54,50 |
| Ancien Cartes : arc | 20 / 20 / 20 | 3 sur 3 | 2,89 | 30,83 |

La profondeur finale inclut le combat perdu : atteindre 20 ne signifie pas gagner le boss. Les moyennes d'ouverture reposent sur 9 combats par départ ; les dégâts des profondeurs 2–3 sur 6 combats. Tous commencent avec 110 PV. Le premier combat a été gagné sans perte de PV dans les 18 cas, y compris les anciens départs.

## Décision d'équilibrage

Le ressenti de puissance supérieure a une base dans l'ouverture : l'Arpenteur perd environ 40 % de PV en moins aux profondeurs 2–3 que l'ancien arc, à vitesse de résolution proche. Le nouvel Assassin encaisse également moins que le marteau dans ces salles. Cela ne se traduit pourtant pas par une run globalement triviale : les trois Assassins meurent à la profondeur 6 et deux Gardiens échouent avant la fin.

**Aucune baisse générale des statistiques n'est appliquée dans cette correction d'interface.** Elle aggraverait le problème du corps à corps. L'équilibre n'est pas déclaré validé : il existe un signal d'avantage de la distance, déjà présent auparavant, et une ouverture qui enseigne peu le coût d'une erreur sous cette politique.

Les anciennes progressions et récompenses diffèrent des nouvelles : ce n'est pas une expérience isolant un unique coefficient. Les pertes totales sur toute la run sont volontairement absentes du tableau, car elles mélangeraient nombre de combats, soins, niveaux et combats perdus. Trois graines, un deck conseillé par classe et une IA gloutonne ne couvrent ni les quinze cartes de chaque classe ni les combinaisons hybrides. L'IA peut notamment sous-exploiter l'isolement, le placement préparatoire et la conservation d'une carte.

## Conséquences concrètes

- Distinguer la puissance de base, les conditions de classe et les effets d'équipement dans les fiches. Les dégâts affichés sont avant défense et bonus conditionnels ; le ciblage réel reste l'autorité de résolution.
- Exposer coût, portée et effet dans la main, rendre le deck consultable pendant le combat. Cela permet au joueur d'expliquer un succès ou un échec avant toute nouvelle modification des coefficients.
- Garder des reçus séparés de l'inventaire pour attribuer précisément les gains au combat qui les a produits.
- Pour une prochaine itération de chiffres : comparer plusieurs decks de contact sur le même combat de profondeur 6, puis des mains préparées contre pression à distance. Ne pas renforcer indistinctement les ennemis sur la base du seul premier combat.

Le contrôle visuel exerce, séparément, le parcours réel de ciblage et d'alternance des tours ; il utilise ensuite une frontière de victoire contrôlée pour tester les fenêtres de progression. Il ne sert pas de preuve d'équilibrage.
