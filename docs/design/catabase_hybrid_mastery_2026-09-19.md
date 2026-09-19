# Catabase — disciplines, maîtrise et hybrides de run

Proposition du 19 septembre 2026, suite du [dossier classes et butin](catabase_classes_loot_research_2026-09-19.md). Aucun changement du jeu dans cette passe. Les seuils et valeurs ci-dessous sont des hypothèses ; les probabilités sont calculées exactement dans un modèle simplifié, pas dans des combats.

## Décision proposée

L'XP mesure l'expérience du personnage ; la maîtrise mesure sa spécialisation ; le butin fournit de nouvelles possibilités. Une carte étrangère utilise le niveau général du héros, mais pas les avantages avancés du spécialiste. Le joueur peut investir pour mieux l'utiliser, au prix d'autres améliorations.

On commence Assassin, puis on peut devenir exécuteur, assassin d'usure, assassin–gardien ou assassin–thaumaturge. Le hasard fournit les pièces ; le joueur choisit si leur synergie mérite des emplacements, des points et un changement d'équipement. Trouver deux cartes étrangères ne donne pas automatiquement une deuxième classe complète.

## Ce qu'apportent les deck builders consultés

- **Slay the Spire 1** : les personnages possèdent des catalogues distincts ; Prismatic Shard permet d'obtenir des cartes d'autres couleurs dans les récompenses. Cela montre l'intérêt d'une ouverture exceptionnelle du catalogue. Notre inférence : agrandir le catalogue augmente aussi le risque de ne plus rencontrer les pièces recherchées. L'effet de la relique est documenté par le [wiki communautaire](https://www.slaythespire.gg/relics/prismatic_shard), pas par une télémétrie de réussite des hybrides.
- **Monster Train** : le jeu permet de choisir un clan principal et un clan de soutien, puis d'accéder à leurs cartes et de les améliorer. Notre adaptation serait de découvrir le soutien pendant la run, plutôt que de le décider obligatoirement au départ. [Présentation officielle](https://store.steampowered.com/app/1102190/Monster_Train/).
- **Griftlands** : les cartes peuvent gagner de l'expérience et évoluer ; le [guide communautaire historique](https://griftlands.fandom.com/wiki/How_to_play_guide_of_Griftlands) décrit la progression par utilisation, et les [notes de Klei](https://forums.kleientertainment.com/game-updates/griftlands/398603-r1054/) documentent les contrôles d'XP et d'amélioration. Notre risque de conception : récompenser chaque lancer peut encourager à prolonger un combat gagné. Ce risque n'est pas présenté ici comme un taux de problème mesuré chez Klei.
- **La méthode Mega Crit** : Anthony Giovannetti explique vouloir donner une place à chaque carte, éviter celles qui déforment excessivement le jeu, itérer et confronter les métriques aux retours des joueurs. Les données constituent des éléments de preuve, pas une conclusion automatique. [Support GDC 2019, notamment pages 7 et 13](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

Ne pas reprendre une carte célèbre hors de son contexte en pensant avoir récupéré son équilibre : une contrepartie liée aux orbes, aux invocations ou à une ressource propre à une classe peut ne plus coûter quoi que ce soit chez un autre personnage. Nos cartes étrangères doivent conserver leurs coûts et avoir des effets de base autonomes, ou afficher clairement leur dépendance.

## Les catégories : quatre disciplines, trois patrons, trois cultes

Les **disciplines** correspondent aux classes jouables. Chacune offre plusieurs plans, sans ajouter une sélection de sous-classe obligatoire à chaque plan.

| Discipline | Mécanisme identitaire proposé | Trois directions internes | Emprunts intéressants |
|---|---|---|---|
| **Assassin** | Exploiter une proie isolée et les fenêtres d'exposition | Exécution immédiate ; saignement et usure ; embuscade et mobilité | Garde pour survivre à une entrée ; surface pour séparer les cibles |
| **Gardien** | Intercepter une menace et convertir une défense réellement consommée en riposte | Bastion ; duelliste ; contrôle de passage | Mobilité d'assassin ; traction ; dégâts de surface pour défendre une zone |
| **Arpenteur** | Tirer parti des distances, lignes et trajectoires | Tireur ; chasseur de pièges ; géomètre des retours | Marque d'assassin ; protection ponctuelle ; déplacement de surface |
| **Thaumaturge** | Préparer puis transformer des surfaces et états | Braises et propagation ; entrave ; conversion entre protection et dégâts | Déplacement d'assassin ; interception ; attaque de finition |

Un mécanisme identitaire n'est pas automatiquement une nouvelle jauge. Pour le premier catalogue, prévoir huit cartes de base par discipline, couvrant plusieurs décisions. Garder les quinze cartes accessibles par identité avec quatre cartes de patron et trois de culte.

Les **patrons** ajoutent une matière commune aux disciplines :

| Patron | Règle proposée | Contrepartie / limite |
|---|---|---|
| **Hadès** | Créer et consommer des vestiges au sol | Peu de vestiges, durée courte, position à construire ; fonctionnement possible sans tuer de cible |
| **Perséphone** | Faire germer une case, puis choisir croissance défensive ou consommation offensive | Effet retardé et case à conserver ; aucune boucle de soin hors danger |
| **Hécate** | Laisser une trace sur une case et résoudre plus tard une version atténuée d'une action éligible | Préparation et position visibles ; l'écho ne génère ni nouvel écho ni ressource supplémentaire |

Les **cultes**, inventions pour notre fiction, transforment la temporalité :

| Culte | Transformation proposée | Sacrifice |
|---|---|---|
| **Styx — le passage** | La consommation d'un vestige, germe ou trace laisse un passage ralentissant | Les supports expirent plus vite ; un passage actif au départ |
| **Léthé — l'oubli** | Renoncer à l'effet d'un support permet de préparer le sommet de sa pioche avec une carte déjà défaussée | Aucun effet immédiat du support, aucun PA rendu, une fois par tour |
| **Phlégéthon — la combustion** | Consommer le support pour amplifier une action directe éligible | Sacrifier le bénéfice défensif ou différé du support ; aucune multiplication récursive |

Quatre × trois × trois = 36 associations théoriques. La compatibilité narrative et les interactions doivent être validées. Ce ne sont pas 36 constructions déjà équilibrées. Passe-rive reste l'identité incarnée ; ces choix ne nécessitent pas de nouveaux personnages graphiques.

## Séparer l'origine d'une carte de son rôle

Une carte possède une seule discipline de maîtrise — ou le type Rite / Commune — et plusieurs tags de gameplay. Par exemple : Gardien / protection / contact. Ces tags disent ce qu'elle fait ; la discipline dit quels bonus de spécialisation s'appliquent.

Une poussée ne devient pas une carte Assassin parce qu'un assassin l'a jouée. En revanche, si elle isole un adversaire, elle peut préparer le passif de l'assassin. C'est une synergie, pas un changement automatique de classe.

Les cartes de patron et de culte utilisent le niveau du héros pour leur effet de base et les règles de l'affiliation choisie pour leurs synergies. **Aucune troisième progression d'XP par divinité ou par culte.** Un rite étranger reste utilisable pour son effet autonome ; il n'octroie pas à lui seul la règle complète de son patron. Une relique peut donner une interaction limitée avec ce mécanisme, avec un coût explicite.

## XP : un seul niveau du personnage

Conserver une XP de rencontre, attribuée une fois à la victoire. Pas d'XP supplémentaire pour le dernier coup, pour chaque carte jouée ou pour les tours passés à attendre. Les défis modifient des récompenses annoncées, sans obliger le défenseur à finir aussi vite que l'exécuteur pour progresser.

Le niveau général et les caractéristiques déterminent la base des dégâts, soins et protections. Une carte trouvée au combat 9 utilise immédiatement la base correspondant au personnage. Elle ne repart pas niveau 1 et ne demande pas cinq combats d'entraînement pour devenir pertinente.

La rareté détermine la disponibilité et éventuellement la particularité de l'effet. Elle ne multiplie pas simultanément le niveau, la maîtrise et les caractéristiques. Le niveau de l'équipement reste une progression matérielle distincte, acquise pendant la run.

Aux fenêtres de niveau, attribuer un **budget limité de points de perfectionnement**. Ils financent soit une maîtrise, soit une transformation de carte. Les points non dépensés sont conservés pour investir après une découverte tardive. Ne pas ajouter ce budget par-dessus les 24 points historiques sans remplacer leur ancienne fonction en mode Cartes.

Hypothèse pour un laboratoire à douze combats : six paliers de progression accordant deux points, soit douze points avant le dernier combat. Les seuils d'XP devront placer ces paliers sur le parcours réel ; ce document ne modifie pas la courbe existante. Comparer les budgets entre carrefours pour les chemins ayant des longueurs différentes.

## Maîtrise : distinguer usage, apprentissage et spécialisation

| Rang | Nom proposé | Qui peut l'atteindre ? | Effet de référence sur les valeurs continues |
|---|---|---|---|
| 0 | Emprunt | Toute carte possédée et matériellement jouable | Effet de base |
| 1 | Initiation | Toute discipline dans laquelle on investit | Base +10 % |
| 2 | Pratique | Rang initial de la classe choisie ; plafond ordinaire des autres | Base +20 % |
| 3 | Expertise | Classe de départ uniquement | Base +30 %, accès à des transformations spécialisées |
| 4 | Accomplissement | Classe de départ uniquement | Base +40 %, un effet de spécialisation supplémentaire |

Ces coefficients sont des **paramètres de comparaison**, pas des bonus à ajouter immédiatement aux dégâts actuels. Il faut recalibrer les bases pour conserver la difficulté. Chaque carte précise les champs affectés : dégâts, soin ou garde. Les PA, cartes piochées, distances, durée de contrôle et nombre de cibles ne sont pas multipliés par ces pourcentages.

Le spécialiste conserve aussi son mécanisme de classe. L'assassin empruntant une carte de garde ne reçoit pas le système complet d'interception et de riposte du Gardien. Une carte peut être meilleure dans une combinaison étrangère particulière ; l'objectif n'est pas que tout emprunt soit inférieur dans toutes les situations. L'objectif est que l'emprunteur n'obtienne pas gratuitement tout le rendement et la continuité du spécialiste.

**Exemple à même niveau, mêmes caractéristiques et même version de carte**, après calcul d'une base de 30 garde :

| Utilisateur | Garde | Autres avantages |
|---|---:|---|
| Assassin sans maîtrise Gardien | 30 | Peut utiliser la protection pour préparer son attaque |
| Assassin, Gardien rang 1 | 33 | A payé son initiation |
| Assassin, Gardien rang 2 | 36 | A investi davantage, reste sans passif natif Gardien |
| Gardien rang 4 | 42 | Bénéficie aussi de sa mécanique de classe et de ses options expertes |

La carte empruntée atteint ici 71,4 % à 85,7 % de la valeur brute du spécialiste accompli. La différence totale dépend du combat et des synergies. On ne peut pas convertir un déplacement ou une interruption en ce même pourcentage d'efficacité.

## Un coût réel de construction, sans taxe de PA sur les cartes étrangères

Budget candidat : classe initiale rang 2 gratuite ; passage 2→3 coûte 3 points et 3→4 coûte 4 points. Une discipline étrangère coûte 2 points pour le rang 1 puis 3 supplémentaires pour le rang 2. Transformer une famille de cartes coûte 2 points, une fois par famille dans le premier prototype.

| Allocation sur 12 points | Résultat | Ce qu'on abandonne |
|---|---|---|
| 7 maîtrise native + 4 transformations + 1 conservé | Spécialiste accompli, deux familles transformées | Pas de maîtrise étrangère |
| 3 maîtrise native + 5 maîtrise secondaire + 4 transformations | Expertise native, secondaire pratiquée, deux transformations | Accomplissement natif |
| 7 maîtrise native + 5 maîtrise secondaire | Deux disciplines bien exploitées | Transformations de cartes payantes |
| 3 maîtrise native + 2 initiation + 6 transformations + 1 conservé | Petit emprunt et trois cartes transformées | Puissance maximale des deux disciplines |

Une maîtrise améliore la famille de savoir, donc les futurs drops de cette discipline en profitent. Une transformation de carte porte sur une famille maîtrisée, pas sur chaque copie, pour ne pas forcer le farm de doublons ; elle ne crée aucune copie ni monnaie. Une transformation ordinaire est accessible pour une carte étrangère possédée, mais les options marquées Expertise restent natives.

Ne pas ajouter par défaut +1 PA aux cartes étrangères : une carte de 1 PA doublerait de coût, une carte de 4 PA n'augmenterait que de 25 %. Cette taxe pénaliserait surtout les petits outils qui font fonctionner les hybrides.

La première initiation étrangère doit rester une décision, pas une taxe évidente que tous les builds paient. Si les tests montrent que tous prennent Gardien rang 1, corriger le rendement des cartes et les besoins des salles avant de multiplier les interdictions. Éviter les avantages de classe entiers accordés au premier point.

## Le noyau du départ doit rester pertinent, pas figé

Le rang natif initial, les améliorations choisies, le passif et les synergies d'équipement favorisent le noyau de départ. De nouvelles cartes de la même classe peuvent le remplacer ou le compléter. Aucune obligation de conserver exactement les dix copies initiales.

Pas de quota obligatoire de cartes natives ni de bonus calculé sur « 60 % de cartes de classe » : cela pourrait encourager le remplissage et punir les remplacements intéressants. Observer plutôt si les cartes natives restent décisives. Un assassin–gardien peut jouer une carte de défense à plusieurs tours tout en gagnant grâce à ses fenêtres d'assassinat.

Avec une main de quatre, ajouter deux cartes à un deck de dix réduit la probabilité d'ouvrir avec au moins une des deux copies d'une carte centrale de **66,7 % à 57,6 %**. À quatorze cartes : **50,5 %**. Une paire de cartes distinctes présentes chacune une fois n'arrive ensemble que dans **9,1 %** des mains initiales d'un deck de douze. Les hybrides doivent donc reposer sur plusieurs liens possibles, ou sur des préparations persistantes, pas sur une paire unique obligatoire.

## Drop : découvrir une école, puis pouvoir décider d'y investir

Le butin reste acquis dans l'inventaire, vendable et limité à la run. Aucune insertion automatique au deck. « Droper pendant les combats » est interprété ici comme des récompenses issues des combats, disponibles après victoire ; autoriser une carte ramassée à entrer dans la main pendant l'affrontement constituerait une autre règle à étudier.

Proposition en deux étapes : décider d'abord si la carte est native ou étrangère ; choisir ensuite sa discipline et son contenu avec le thème du biome. Les poids de biome du dossier précédent ne doivent pas être additionnés une seconde fois à ces probabilités. Ce tirage remplace cette première proposition de tables pour les cartes de classe.

| Combats résolus | Carte native | Carte étrangère | Intention |
|---|---:|---:|---|
| 1–3 | 85 % | 15 % | Consolider et commencer à découvrir |
| 4–8 | 65 % | 35 % | Ouvrir des bifurcations |
| 9–11 | 55 % | 45 % | Permettre ajustements et derniers paris |

Le modèle prend une carte par victoire, quatre disciplines et onze récompenses utiles avant le douzième combat final. Il exclut rites, bonus d'élite, choix de chemin et marchands afin d'isoler la fréquence des emprunts. Les taux définitifs devront tenir compte de ces contenus.

| Moment | Cartes étrangères moyennes | Chance d'en avoir trouvé au moins une | Chance d'en avoir trouvé deux d'une même discipline étrangère |
|---|---:|---:|---:|
| Après 3 combats | 0,45 | 38,6 % | 2,2 % |
| Après 6 combats | 1,50 | 83,1 % | 23,6 % |
| Après 8 combats | 2,20 | 92,9 % | 43,6 % |
| Avant le combat final | 3,55 | 98,8 % | 75,2 % |

**Deux cartes d'une même discipline ne garantissent pas une synergie.** Ce résultat indique seulement que des pièces peuvent se rencontrer. Une carte peut suffire pour un emprunt ponctuel ; un vrai hybride demande souvent aussi une règle native exploitable ou un objet adapté.

Variante de découverte à comparer : si les deux premières victoires n'ont fourni aucune carte étrangère, la troisième en fournit une. Elle garantit de découvrir le principe, pas de recevoir une combinaison. Le calcul donne alors 61,7 % de chances d'avoir deux cartes de la même discipline étrangère après huit combats, contre 43,6 % sans cette protection. Les modèles et leurs limites sont reproductibles dans [le script de calcul](calculations/hybrid_build_model_2026_09_19.py).

Ne pas faire dépendre les tirages du deck équipé ou des points dépensés à la dernière seconde. Utiliser la classe de départ et le monde ; enregistrer les récompenses. Sinon le joueur peut manipuler le butin et chaque investissement devient un moyen de garantir sa combinaison.

## Comment rendre les embranchements exploitables sans garantir le jackpot

- Prévoir des cartes étrangères autonomes : garde, traction, attaque de finition, purification. Une carte exclusivement consommatrice d'une ressource introuvable doit être rare ou accompagnée d'un effet de base utile.
- Répartir les familles entre ennemis et biomes. Le joueur peut chercher de la garde à la porte ou des surfaces dans le puits, sans savoir quel objet précis tombera.
- Certaines pièces font le lien entre mécaniques : une rune transforme la première garde ennemie absorbée en poussée ; elle relie naturellement Gardien et Assassin sans donner le passif complet de l'un à l'autre.
- Donner la possibilité de conserver des points et du butin. Au premier refuge, autoriser un réajustement limité d'une allocation de perfectionnement ; ensuite un service payé en oboles. Les statistiques de base et la classe restent distinctes de ce service.
- Une carte tardive a une base adaptée au niveau, et les maîtrises déjà apprises s'appliquent immédiatement. Il reste possible de s'en servir sans réentraînement.
- Un objet exceptionnel peut contourner une règle précise, avec une contrepartie : par exemple permettre le rang 3 d'une seule carte étrangère en neutralisant l'effet d'accomplissement natif. À réserver à une itération ultérieure, une fois l'écart normal compris.

## Six formes d'assassin à éprouver

| Forme | Noyau | Découverte éventuelle | Nouvelle décision | Faiblesse conservée |
|---|---|---|---|---|
| **Exécuteur** | Isolement, accès et finition | Aucune obligatoire | Éliminer une menace avant sa prochaine activation | Gestion des groupes |
| **Assassin d'usure** | Saignement, retrait et esquive | Rune prolongeant une première blessure | Répartir les blessures ou sécuriser une mort | Pression immédiate faible |
| **Spectre du Styx** | Vestiges, déplacement, passage | Cartes de son patron et culte | Préparer son retour ou consommer son appui | Espace et timing |
| **Assassin–Gardien** | Isolement et riposte | Garde + poussée après absorption | Prendre une attaque calculée pour séparer sa cible | Moins résistant qu'un Gardien natif |
| **Assassin–Thaumaturge** | Accès aux cibles et finition | Surface + carte de traction | Faire sortir une cible de son groupe ou l'amener dans une zone | Préparation coûteuse, amplification magique limitée |
| **Assassin–Arpenteur** | Marque et exécution | Attaque à distance + manipulation de ligne | Choisir entre entrée au contact et élimination éloignée | Moins de portée/continuité que le spécialiste |

Exemple d'une bifurcation : combat 4, carte de garde obtenue et conservée ; combat 6, ceinture qui pousse après absorption ; le joueur investit deux points dans Gardien et remplace une carte de mobilité redondante. Il garde ses cartes de séparation et de finition. Au combat 8, il choisit entre améliorer sa garde ou atteindre l'expertise d'Assassin. L'hybride se construit par deux trouvailles et une décision, pas par une transformation automatique du personnage.

## Contrôles contre les faux choix et les abus

Pas d'XP de lancer : la victoire accorde le même budget, qu'on ait lancé une carte une ou dix fois. Pas de gain de maîtrise par auto-dégât ou alternance de soins. Les actions annulées, cartes générées et copies temporaires ne créent ni XP ni acquisition permanente.

Les effets de pioche, réduction de coût, copie et contrôle méritent un examen distinct des dégâts. Une carte de pioche universelle à coût nul peut devenir obligatoire même avec zéro maîtrise. Une copie ne copie pas son propre déclencheur ; les remboursements ont un plafond. Une attaque de zone ou plusieurs impacts ne multiplient pas un effet annoncé « une fois par tour ».

La maîtrise n'accorde pas la ressource native complète. Les consommateurs étrangers doivent préciser comment obtenir leur ressource, et ne pas devenir des cartes mortes faute de générateur. Les marques ou germes ne nécessitent pas l'apparition de nouveaux personnages.

## Mesurer la réussite

Les calculs effectués portent sur la disponibilité des cartes et la pioche, pas sur la puissance des builds ou le plaisir. Aucun taux de victoire n'est inventé.

Premier passage : quatre noyaux de classe ; pour chacun, version native, emprunt ponctuel et hybride investi, sur des rencontres et graines comparables. Conserver les ennemis existants et leurs intentions pour isoler l'effet du système. Tester aussi un drop étranger tardif, des doublons peu utiles et une run qui ne trouve pas de vraie combinaison.

Relever : cartes trouvées versus équipées versus jouées ; points investis avant et après une découverte ; part de la victoire liée au mécanisme natif ; fréquence des mains sans décision utile ; temps passé à trier ; raison des ventes ; abandon d'un hybride ; valeur des objets faisant le lien. Comparer défense, préparation, déplacement et dégâts, pas seulement le DPS.

Ne pas conclure qu'une carte fait gagner parce que les runs qui la possèdent gagnent davantage : elle peut surtout apparaître tard dans des runs déjà fortes. Comparer la profondeur d'acquisition, les rencontres, l'état du héros, l'expérience du joueur et l'équipement. Mesurer aussi les situations où la carte a été proposée ou trouvée puis refusée.

Signaux d'échec : tous les builds prennent la même petite initiation ; l'hybride rend le spécialiste inutile ; les cartes étrangères sont presque toujours vendues ; le noyau initial devient du remplissage ; l'XP oblige à jouer contre le bon sens ; le joueur doit lire quatre arbres pour comprendre une carte. Revoir alors les cartes et les besoins des rencontres avant d'empiler de nouveaux verrous.

L'objectif n'est pas de forcer une répartition fixe de spécialistes et d'hybrides. Un bon système doit permettre de reconnaître une occasion, de la refuser ou d'y investir, avec un résultat qui conserve l'identité du personnage et change réellement sa manière de jouer.
