# Lecture des 48 familles et des builds actuels

Audit du code à `6e8d2605`. Complément du [rapport](RAPPORT.md). P désigne la Prouesse ; les coefficients ci-dessous précèdent résistance, équipement, bonus de classe et arrondi. Ce tableau décrit une valeur tactique, pas un classement de puissance obtenu en jouant. Les descriptions finales sont assemblées par `consumable_card_description.gd` : les textes intermédiaires « Même effet » du JSON ne sont pas, à eux seuls, un défaut de l'interface.

## Communes : les outils qui permettent de dépenser les derniers PA

| Famille | Coût et fonction | Décision apportée, risque à surveiller |
|---|---|---|
| n01 Estoc | 1 PA, 0,55 P au contact ; amélioré 0,70 | Finir sans consommer une grosse carte. Seulement une utilisation de la famille par tour : trois copies ne permettent pas trois Estocs. |
| n02 Garde brève | 1 PA, 0,45 P de garde ; améliorée, rétention d'une autre copie | Une des meilleures améliorations qualitatives : achète une transition de combo. Le coût comprend une copie de Garde, renouvelable mais non garantie. |
| n03 Pas latéral | 1 PA, déplacement 2 puis 3 cases | Convertit PA en accès, libère des PM pour l'Ancre. Très transversal ; vérifier si la pression en fait un choix systématique. |
| n04 Heurt | 1 PA, 0,25 P, pousse 1 puis 2 | Levier à bas coût pour salles et collisions ; ce n'est pas un Estoc inférieur lorsque le terrain est utile. |
| n05 Trait court | 1 PA, 0,45 puis 0,60 P à distance | Complète un tour à 3 PA, termine une cible. Mesurer sa concurrence avec les attaques de classe à 2 PA. |
| n06 Repérage | 1 PA, 0,20 P + marque 0,35 P | Préparation universelle, transfère une partie du rendement au prochain impact. Remplit un rôle voisin de a01/t03, avec moins de puissance. |
| n07 Entrave légère | 1 PA, 0,20 P et −1 PM | Achète une fenêtre de sécurité si elle franchit un seuil d'accès. Inutile de l'évaluer comme « −1 PM = X dégâts » sur toutes les cartes. |
| n08 Recentrage | 1 PA, pioche 2 puis 3, limitée par la capacité de main | Jouée immédiatement dans une main pleine, la consommation libère une seule place : on ne pioche qu'une carte. L'amélioration demande de vider davantage sa main avant. Afficher la pioche effective serait utile. |

## Assassin : bonne combinaison de base, disponibilité à protéger

| Famille | Coût et fonction | Décision / limite |
|---|---|---|
| a01 Ouvrir la garde | 1 PA, 0,35 P + marque 0,45 P ; durée améliorée | Prépare a02, a09 et les coups alliés au build. La durée supplémentaire ne sert pas lorsque la marque est consommée tout de suite. |
| a02 Frapper la faille | 2 PA, 0,95 P + 0,55 P si marqué ; amélioration portée 2 | L'impact consomme aussi le bonus de marque : avec a01, gain de condition et charge de marque s'ajoutent. L'amélioration élargit l'accès plutôt que le chiffre. |
| a03 Entaille tenace | 2 PA, 0,70 P + 0,15 P × 2 ; amélioré 0,20 × 2 | Dégâts différés, plus pertinents sur cible durable. Un décès périodique ne donne pas les récompenses d'élimination directe. |
| a04 Attaque oblique | 2 PA, 1,05 P + 0,35 P après 2 cases ; amélioré après 1 | Rend le déplacement offensif ; concurrence a02 sans préparation de marque. Une vraie alternative de rythme. |
| a05 Bond spectral | 2 PA, téléportation 3 puis 4 | Franchit les obstacles ; concurrence Pas latéral, moins cher mais dépendant du chemin. Juger le terrain franchi, pas uniquement les cases. |
| a06 Dernier verdict | 3 PA, 1,30 P + 0,70 P sous 35 % PV | Gros finisseur, mais bonus souvent perdu en sur-dégâts sur les petites unités. Rendement à mesurer en PV réellement retirés. |
| a07 Pointe franche | 2 PA, 0,90 puis 1,05 P, ignore l'armure | Outil de contre. Son intérêt dépend de la résistance des rôles effectivement adaptés, pas du bestiaire historique. |
| a08 Couper le souffle | 2 PA, 0,70 puis 0,85 P et prochaine attaque −50 % | Défense offensive ciblée. Boss à −25 % : différence explicite, pas immunité totale au contrôle. |
| a09 Sommeil marqué | 3 PA, consomme une marque, saute une activation, immunité suivante | Contrôle exigeant deux ressources ; marque à 1 PA + Stase remplit le tour. Sur le boss, devient un affaiblissement : rôle très différent, à anticiper. |

Le passif d'isolement ajoute 0,25 P au premier impact direct éligible du tour. **Exécution** accélère la finition ; **Relais** exige une élimination directe d'une cible marquée et une seconde cible proche. Le Relais plafonne la marque à 0,20 P, interdit sa retransmission et impose une échéance : bonne protection contre une chaîne infinie. Il faut toutefois des ennemis assez nombreux, proches, et assez résistants pour qu'une marque ne soit pas gaspillée en sur-dégâts.

Exemple sans défenses, équipement ni spécialisation : a01 sur cible isolée, puis a02 sur cette même cible produit `(0,35 + 0,25) + (0,95 + 0,55 + 0,45) = 2,55 P` pour 3 PA et deux copies. C'est une interaction réelle. Cela ne prouve pas qu'elle soit régulièrement disponible ni qu'elle soit supérieure sur toutes les salles.

## Gardien : identité solide, boucle de conversion trop rare

| Famille | Coût et fonction | Décision / limite |
|---|---|---|
| g01 Garde ferme | 2 PA, 1,15 puis 1,40 P de garde | Protège et amorce g02/g09. La garde excédentaire ou non absorbée n'est pas une valeur acquise. |
| g02 Heurt du rempart | 2 PA, 1 P + 0,50 si garde ; amélioré base 1,15 | Combo direct g01→g02 à 4 PA, mais peut être activé avec une garde moins coûteuse. |
| g03 Repousser | 2 PA, 0,80 P et poussée 2 puis 3 | Déplace la menace et exploite les salles. La poussée du boss est bornée à une case. |
| g04 Ramener au front | 1 PA, 0,20 P et attraction 1 puis 2 | Accès au contact, regroupement ; offre une autre façon de résoudre les 2 PA de g01/g02. |
| g05 Contre préparé | 2 PA, garde 0,90 puis 1,15 P et contre 0,50 P | Nécessite de se faire attaquer au contact. À distinguer du renvoi du passif et du Miroir : déclenchements bornés séparément. |
| g06 Choc de masse | 2 PA, 0,65 P, pousse 1 ; garde 0,30 puis 0,45 si collision fixe | Bon test du positionnement. Une unité, un bord ou une case vide ne doivent pas tous devenir artificiellement un mur profitable. |
| g07 Dette du bronze | 3 PA, 1,20 P + 0,50 si absorption au tour précédent | Paie la défense passée. Plus exigeant que g02, et son coût limite les combinaisons dans le même tour. |
| g08 Bastion vivant | 3 PA, garde 1,90 puis 2,15 P | Réponse à une salve, pas protection contre la pression. Plafond de garde 2,50 P : certains cumuls gaspilleront une partie du gain. |
| g09 Répercussion | 2 PA, 0,70 P + 1,50 S ; sacrifie S ≤ 0,80 P | Vraie décision entre attaque et survie. Maximum intrinsèque 1,90 P, contre 0,80 P de garde perdue. **Rare** : trop peu fiable pour être la boucle centrale promise au Gardien. |

Le renvoi du passif fonctionne aussi avec la garde de secours. **Bastion** renforce la première création de garde admissible ; **Briseur** récompense la première poussée effective. Préserver cette distinction entre déplacement demandé et réellement effectué. La pression traverse la garde : elle évite l'attente infinie, mais réduit volontairement la valeur des builds très défensifs.

## Arpenteur : mobilité enfin distinctive, tension de main à expliquer

| Famille | Coût et fonction | Décision / limite |
|---|---|---|
| r01 Tir de relais | 2 PA, 0,80 P et pioche après 2 cases ; amélioration autorise contact | Boucle bouger/tirer/recharger. Première action dans une main pleine : une seule place libérée, donc le cumul avec la pioche d'Escarmouche peut être écrêté. |
| r02 Trait de recul | 2 PA, 0,70 P et pousse 1 ; amélioré autorise contact | Crée une séparation, mais pas toujours assez pour empêcher la prochaine approche. |
| r03 Flèche entravante | 2 PA, 0,60 P et −2 PM | Très différente de −1 PM contre un poursuivant à 2 PM. Vérifier par rôle et chemin, pas par moyenne de dégâts. |
| r04 Volée croisée | 3 PA, 0,60 puis 0,75 P par cible | Rentabilise le regroupement. Faible sur une seule cible, bonne si la carte et l'IA offrent des croisements. |
| r05 Au-delà du front | 2 PA, téléportation 4 puis 5 | Même fonction de base que a05 avec davantage de portée ; différenciation mécanique limitée. |
| r06 Pluie de pointes | 3 PA, 0,70 P sur ligne de trois | Géométrie différente de la croix, mais peut se réduire à une variation d'AoE si les formations ne la sollicitent pas. |
| r07 Trait harpon | 2 PA, 0,55 P, attire 2 ; amélioré choisit 1 ou 2 | Choix discret utile pour conserver une distance de tir ou aligner une cible. |
| r08 Permutation | 2 PA, échange avec un ennemi, boss exclu | Un des outils de placement les plus expressifs ; rareté et exclusion du boss limitent sa fréquence d'expression. |
| r09 La longue vue | 3 PA, 1,75 puis 1,90 P, portée minimale 3 | Carte rare surtout numérique : moins structurante que Permutation. Attention au rôle que la rareté est censée communiquer. |

L'**Ancre** exige un impact de carte à distance ≥3, une case de départ libre et à distance ≤3, ainsi qu'un PM restant. Avec 3 PM, avancer de trois cases puis revenir n'est pas possible sans une autre source de mobilité. Cette contrainte crée un arbitrage intéressant. **Tireur** récompense la distance 4 ; **Escarmouche** le mouvement préalable. Leur valeur change avec les couloirs, les retraits possibles et la capacité de main.

## Thaumaturge : les réactions existent, l'accès à leur préparation reste fragile

| Famille | Coût et fonction | Décision / limite |
|---|---|---|
| t01 Trait de givre | 2 PA, 0,65 P, −1 PM ; eau→glace 2 puis 3 phases | L'amélioration n'augmente ni dégâts ni entrave directe. Sans eau dynamique, elle n'apporte rien à ce lancer. |
| t02 Braise tenace | 2 PA, 0,55 P + brûlure 0,18 P × 2 ; eau→vapeur | L'amélioration prolonge uniquement la vapeur, pas la brûlure. Éviter que le joueur la choisisse pour un build feu sans eau. |
| t03 Sceau ombreux | 1 PA, 0,25 P + marque 0,40 puis 0,60 P | Prépare le burst ; analogue magique de a01/n06. Très compatible avec des cartes d'autres classes. |
| t04 Onde du Léthé | 3 PA, croix 0,45 P, eau 2 puis 3 phases | Préparateur des réactions. Eau + givre/feu coûte 5 PA : deux tours ordinaires, ou une réduction. Absent du preset par défaut, présent dans le preset alternatif. |
| t05 Bûcher des ombres | 2 PA, zone 0,35 puis 0,45 P × 2, deux camps | Bonne interaction avec regroupement, entrave et Mèche ; exige de prévoir les activations et sa propre sortie. |
| t06 Jardin de givre | 2 PA, zone −1 PM sur deux puis trois phases | Contrôle territorial autonome, moins dépendant de t04. Attention au rendement contre archers déjà en portée. |
| t07 Prélèvement | 2 PA, 0,75 puis 0,90 P ; soin 50 % des PV retirés | Sustain avec coût de copie ; sur-dégâts exclus. Bonne protection contre le soin artificiel sur cibles presque mortes. |
| t08 Convergence | 3 PA, attraction puis croix 0,80 P | Géométrie expressive ; ordre de résolution important. Rare : outil ponctuel, non fondation fiable d'un build de zone. |
| t09 Résonance du sceau | 3 PA, 0,90 P + 0,80 puis 1,05 si marqué | Sceau à 1 PA + Résonance remplit le tour. Plus proche d'un burst de marque que d'une réaction élémentaire. |

Le passif donne une garde de 0,20 P sur la première application directe admissible **ou** la première transformation du tour, avec compteur partagé. Transformer une seconde fois n'empile pas le passif. **Brasier** renforce la brûlure ; **Givre** récompense l'entrave. Le kit de statuts fonctionne sans eau ; c'est spécifiquement la promesse de *réactions élémentaires* qui demande une meilleure amorce.

## Cartes exceptionnelles

| Famille | Fonction | Lecture de design |
|---|---|---|
| l01 Orage du passage | 3 PA, 1,10 puis 1,25 P, rayon 2 autour du héros | Explosion de situation ; récompense l'encerclement mais demande de s'y exposer. |
| l02 Grâce du bronze | 2 PA, soin 1,50 puis 1,75 P et garde 0,50 P | Outil exceptionnel de survie. Ne pas équilibrer les soins courants en supposant sa présence. |
| d01 Décret du dernier souffle | 3 PA, survit au premier impact létal à 1 PV ; exclut pression | Sauvetage limité, pas invulnérabilité à toute une phase. Une deuxième attaque peut encore tuer. |
| i01 Seconde aurore | 4 PA, soin 60 puis 75 % HP et garde 1 P ; termine l'activation | Redresse une situation, mais abandonne l'offensive du tour. Sa rareté en fait un événement, pas un chemin de build. |

## Équipement, reliques et attributs

Les 18 équipements couvrent six slots. L'essentiel de leur différenciation reste statistique, ce qui est acceptable si les cartes portent les changements de comportement. Les choix de portée, de PM, de capacité de main et les malus de mouvement changent directement l'accès aux actions ; leur valeur n'est pas comparable à +8 % dégâts sans tenir compte de la carte.

| Slot / options | Audit du choix |
|---|---|
| Arme : lame, arc, bâton | Orientation contact, distance, magie. L'arc gagne portée et dégâts mais perd un PM : coût très concret pour l'Ancre. |
| Corps : cuir, plates, robe | PV contre résistances spécialisées ; plates coûtent aussi un PM. Le cuir absorbe davantage de types de menace, mais n'allonge pas proportionnellement le délai de pression. |
| Tête : veilleur, bronze, sage | Main +1 contre garde d'ouverture ou garde renforcée. La main augmente l'accès aux combos, la garde d'ouverture est finie : mesurer les tours effectivement économisés. |
| Pieds : rapides, ancrés, flux | +1 PM transversal contre contact/résistance ; flux combine PM et dégâts à distance contre garde réduite. Surveiller le taux de sélection de la mobilité. |
| Ceinture : vie, soins, garde | Multiplicateurs de styles de survie ; valeur du soin conditionnée à des sources réellement acquises. |
| Amulette : coupe, éclat, œil | Vol de vie borné à 10 % des PV max/combat ; dégâts contre PV ; portée et réduction du premier coup. Bornes explicites utiles contre les boucles de soin. |

| Relique | Audit du rôle |
|---|---|
| Fil du détour | Fait communiquer déplacement par carte et PM ; particulièrement pertinent pour l'Ancre. |
| Urne patiente | Reporte une partie de la valeur défensive au tour suivant, sous condition d'absorption réelle. |
| Mèche obstinée | Change le rendement du feu ; dépend de la disponibilité et de la durée effective des tics. |
| Obole fendue | Économie pure ; vérifier sa rentabilité selon le moment d'achat, et non seulement son plafond par combat. Voir calcul du rapport. |
| Agrafe des archives | Réduit une seule carte à ≥3 PA par combat. Permet notamment Onde 3→2 + réaction 2 dans le même tour ; bon changement de séquence mais non permanent. |
| Miroir du bronze | Rendement fini, premier coup reçu du combat ; sa condition est très différente d'un contre répété. |
| Coupe des blessures | Deux éliminations directes soignantes par combat ; favorise finition et ordre des cibles, moins les dégâts périodiques. |
| Sceau du chasseur | Renforce les marques ; pas de dépendance à une unique carte puisque trois familles de marque existent. |

Deux slots de reliques distinctes créent une sélection réelle. Deux drops garantis tirés indépendamment parmi huit peuvent donner le même objet (12,5 % entre ces deux tirages) ; la deuxième copie n'est pas équipable en parallèle. C'est un risque de récompense décevante, pas un bug de duplication de sauvegarde.

Les attributs donnent +5 % P, +6 % PV ou +2 points de résistance physique et +5 % de garde par point. La Résolution ne donne pas de résistance magique ; l'équipement la porte. Les plafonds de résistance, garde et soin rendent les valeurs calculables. Les caractéristiques de drop ou de maîtrise évoquées dans l'ancienne recherche ne sont pas des systèmes actifs de cette V2.
