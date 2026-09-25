# Recherche guidée par les problèmes du prototype

Consultation : 25 septembre 2026. Ce document prolonge les [21 références de l’audit systémique](../card_economy_lab/research_2026-09-25/SOURCES.md) et ses analyses de DOFUS, WAKFU, WAVEN, Slay the Spire, Monster Train, Balatro, Into the Breach, Divinity et Baldur’s Gate 3. Le catalogue proposé ici est original ; il ne prétend pas reproduire leurs sorts ou leurs valeurs contemporaines.

## Question 1 — Une politique automatique qui perd prouve-t-elle qu’une classe est mauvaise ?

Terry Cavanagh décrit comment l’IA de **Dicey Dungeons** a dépassé une collection de règles locales : les cas spéciaux finissaient par se contredire, tandis qu’une bonne combinaison pouvait exiger une première action peu attractive. Il explique ensuite sa recherche dans un modèle abstrait du combat et le choix d’une évaluation de l’état. Source primaire : [How enemy AI works in Dicey Dungeons, 5 décembre 2018](https://www.gamedeveloper.com/design/how-enemy-ai-works-in-dicey-dungeons).

**Notre expérience :** le premier contrôleur reculait parfois jusqu’à mourir sous la pression alors qu’un déplacement suivi d’une attaque suffisait. Nous avons conservé ce contrôleur comme témoin et ajouté une recherche de deux actions. Ce n’est ni un MCTS ni un solveur optimal. L’écart entre contrôleurs mesure en partie la limite du banc d’essai ; on ne doit pas nerfer une classe seulement parce que l’automate la comprend moins bien.

**Décision V1 :** séparer trois preuves : correction d’un effet, utilité dans des situations comparables, performance sur une run. Un effet peut réussir la première et échouer la troisième. Le Gardien justifie précisément cette séparation : on doit examiner les cartes dépensées et la défense réellement absorbée, pas uniquement son pourcentage de victoires.

## Question 2 — Comment garder une décision intéressante malgré des ressources inutilisables ?

Dans son entretien avec Alex Wiltshire, Cavanagh revient sur plusieurs prototypes de la Sorcière : des dés inutilisables, puis des cascades d’effets difficiles à comprendre. La solution retenue lui rendait la possibilité de préparer volontairement ses options. Source primaire par entretien : [Witch-craft: How Dicey Dungeons balances chance and predictability, 19 septembre 2018](https://www.gamedeveloper.com/design/witch-craft-how-i-dicey-dungeons-i-balances-chance-and-predictability).

**Transposition proposée :** notre réserve garde les ressources, le deck choisit les options et le tour décide leur dépense. Les normales étrangères restent jouables. Un sac peut être utile sans appartenir au build initial. Les gestes de secours évitent une interface sans action, mais sont bornés pour que les consommables restent le moteur de la run.

**Question suivante :** si le secours permet de gagner lentement sans carte, le joueur rationnel attend. D’où une pression annoncée et calculable ; puis une comparaison explicite de la politique « aucun consommable ». Cette pression est notre choix, pas une règle attribuée à Dicey Dungeons. Son coût de confort est un sujet de test humain.

## Question 3 — Les mêmes taux moyens donnent-ils la même économie ?

Le laboratoire initial raisonnait beaucoup sur l’espérance du stock. Le modèle tactique montre pourquoi cela manque une partie du problème : les cartes arrivent après une victoire, leur rôle varie, et une rupture avant le premier marchand est irréversible. Un surplus tardif ne répare pas une pénurie au deuxième combat.

Le socle initial testé avait deux sacs normaux de trois cartes avec des jets parfois manqués ensemble. La proposition finale utilise un petit sac garanti et un second sac plus fréquent. Le principe est proche des protections de butin discutées dans les sources officielles Path of Exile 2 et de la disponibilité des builds évoquée dans les anciens textes WAKFU, déjà documentés dans le corpus précédent. **Les coefficients ici viennent de nos calculs, pas de ces jeux.**

**Décision :** mesurer moyenne, variance, probabilité de zéro, moments d’arrivée, rôle des cartes et consommation. Pas de « correction intelligente » cachée donnant une meilleure récompense au joueur qui joue mal. Une règle de base visible est plus vérifiable qu’un algorithme opaque de rattrapage.

## Question 4 — Faut-il multiplier les couches parce que les grands jeux en possèdent ?

Le 22 mai 2026, Mega Crit explique notamment avoir remplacé un boss jugé trop complexe malgré ses micro-décisions intéressantes, et espacer ses patchs bêta pour laisser davantage de temps à l’évaluation. La même publication distingue taux globaux et taux par difficulté. Source primaire : [The Neowsletter — May 2026](https://www.megacrit.com/news/2026-5-22-neowsletter-issue-22/).

**Décision V1 :** aucun critique aléatoire, aucune esquive aléatoire, une seule amélioration par famille, trois choix par emplacement d’équipement et deux reliques actives. Ajouter prospection, fabrication aléatoire et arbres de maîtrise maintenant rendrait les causes d’échec indissociables. Ce n’est pas un rejet de la profondeur : les interactions de placement, le coût des exemplaires et la préparation remplissent déjà cette fonction.

Une carte normale porte principalement un verbe ; les conditions plus rares modifient une décision identifiable. Cette règle prolonge la distinction de Mark Rosewater entre complexité de lecture, de plateau et profondeur stratégique, étudiée dans le précédent corpus. Une normale n’est pas obligée d’être inutile après le niveau 5 : son échelle en P lui garde un usage, son rendement et ses possibilités restent plus simples.

## Question 5 — Que faut-il enregistrer pour décider d’un changement ?

Mega Crit rappelle en avril 2026 l’utilité des retours accompagnés des données de partie et décrit sa branche bêta comme un lieu d’expérimentation avant stabilisation. Source primaire : [The Neowsletter — April 2026](https://www.megacrit.com/news/2026-4-17-neowsletter-issue-21/).

**Décision :** conserver graine, version, classe/spécialisation, rencontre, stock, cartes consommées, dépenses, tours et cause d’échec. Pour un test humain, ajouter la raison verbalisée d’un choix. « Carte peu jouée » peut signifier carte faible, carte trop rare, carte gardée par peur, texte peu clair ou mauvais contexte. Ces causes appellent cinq corrections différentes.

Nos graines de vérification sont distinctes des premières graines de réglage. Les comparaisons partagent les mêmes graines, mais une modification de stock peut modifier l’ordre de pioche : l’appariement réduit une partie du bruit, sans rendre les combats identiques. Les intervalles statistiques du rapport concernent ces tirages sous ces automates, pas la population des joueurs.

## Question 6 — Un jeu équilibré par formule est-il agréable ?

Rupp, Puddu, Becker-Asano et Eckert ont comparé des niveaux avant/après équilibrage automatique dans quatre scénarios et avec des participants humains. Leur résumé rapporte des améliorations de perception pour la plupart des scénarios, avec des différences entre aspects et scénarios. Source primaire : [It might be balanced, but is it actually good?, IEEE CoG 2024, résumé des auteurs](https://arxiv.org/abs/2407.11396).

**Limite documentaire :** cette note s’appuie sur leur résumé, pas sur une reproduction de leur protocole ou de leurs données. Elle ne prouve rien sur les cartes consommables de Catabase.

**Décision :** ne pas déclarer le jeu « équilibré » après réussite de tests de règles. La V1 doit fermer les paramètres et fournir un scénario de test humain : découverte des consommables, premier manque, premier troc, première amélioration, première perte d’une rare, boss. On mesure compréhension, durée, regret utile et regret paralysant. Une mécanique que les gens évitent parce qu’ils ne comprennent pas son renouvellement ne se corrige pas nécessairement par +10 % de dégâts.

## Chaîne de conception retenue

| Observation ou risque | Question approfondie | Réponse V1 | Preuve disponible |
|---|---|---|---|
| Carte jouée détruite | L’amélioration disparaît-elle avec elle ? | Amélioration de famille, appliquée aux futures copies | Tests de règles et manifeste |
| Sac de normales abondant | Le stock est-il utilisable au bon moment ? | Plancher par mob, réserve et préparation séparées | Variantes de drop et runs |
| Mobilité gratuite | Peut-on attendre pour économiser toutes les cartes ? | Secours plafonné, pression de combat | Témoin sans consommables |
| Rareté extrême | Un build dépend-il d’un événement quasi absent ? | Aucun composant obligatoire au-dessus d’élite | Ablation des rares et plus |
| Équipement offensif | Économise-t-il des copies et donc de l’or ? | Mesurer copies, PV, tours simultanément | Comparaisons d’objets |
| Défense coûteuse | Le défenseur peut-il payer toute une run ? | Examiner l’absorption et l’attrition, pas seulement le duel | Comparaison des classes et itérations |
| Plus de cartes préparées | Dilue-t-on les familles investies ? | Plafond 30, préparation conseillée 20, pas de minimum obligatoire | Hypergéométrie et variantes 15/30 |
| Contrôle puissant | Peut-il supprimer l’ennemi en boucle ? | Immunité partagée, boss affaibli plutôt que privé de tour | Cas limites stase/boss |
| Recharge d’une partie | Peut-elle dupliquer ou relancer les drops ? | UID, graines séparées et reçus atomiques | Reprise et transactions |

Les chiffres restent révisables ; chaque révision doit désigner le problème, la donnée qui l’appuie et la contrepartie attendue. L’intérêt des piliers du genre n’est pas de nous fournir une liste de coefficients universels, mais des façons de rendre les décisions lisibles, de limiter les abus et de vérifier les conséquences d’un changement.
