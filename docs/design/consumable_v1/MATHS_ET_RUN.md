# Tables de run et zones de calcul

Ces valeurs sont celles de la proposition ; elles ne sont pas les statistiques actuellement chargées par Godot. Les 336 répartitions de six points sont calculées dans [stat_allocations.csv](stat_allocations.csv). Avant le niveau 12, ces répartitions sont des stress tests, car les six points ne sont pas encore tous acquis.

## Courbe de personnage

| Niveau | XP cumulée minimale | PV base | P base | Points de caractéristique cumulés | Familles améliorables cumulées |
|---|---|---|---|---|---|
| 1 | 0 | 110 | 18 | 0 | 0 |
| 2 | 100 | 135 | 22 | 1 | 0 |
| 3 | 220 | 165 | 27 | 1 | 0 |
| 4 | 360 | 200 | 33 | 2 | 1 |
| 5 | 520 | 240 | 40 | 2 | 1 |
| 6 | 700 | 290 | 48 | 3 | 1 |
| 7 | 900 | 350 | 57 | 3 | 1 |
| 8 | 1120 | 420 | 68 | 4 | 2 |
| 9 | 1360 | 500 | 82 | 4 | 2 |
| 10 | 1700 | 600 | 100 | 5 | 2 |
| 11 | 1990 | 635 | 106 | 5 | 2 |
| 12 | 2300 | 675 | 112 | 6 | 3 |

Formules : PV = arrondi(PVbase × [1 + 0,06 × vitalité + bonus équipement PV]) ; P = Pbase × (1 + 0,05 × puissance). Résistance physique = min(0,40 ; 0,02 × résolution + équipement). Garde produite = coefficient × P × (1 + 0,05 × résolution + équipement). Résistance magique séparée. Les pourcentages d’équipement d’une même étape s’ajoutent ; les étapes distinctes se multiplient.

À niveau 12 et sans équipement, six points de puissance donnent P = 145,6 ; six points de vitalité donnent 918 PV ; six points de résolution donnent 12 % de résistance et +30 % de garde. EHP physique du troisième cas = 675 / 0,88 = 767,05. Ce n’est pas une équivalence : vitalité aide contre la magie, puissance raccourcit le combat et économise des exemplaires, résolution favorise les gardes répétées.

## Les douze rencontres

Le niveau ennemi est attaché à la rencontre. Répartition des PV du groupe : arrondi(Pbase du niveau × budget × poids du monstre / somme des poids). Attaque : arrondi(PVbase du niveau × coefficient du monstre). Aucun scaling avec l’équipement du héros.

| Combat / profondeur | Niveau | Salle | Groupe (PV ; dégâts par attaque) | Budget PV/P | XP après victoire |
|---|---|---|---|---|---|
| 1 / 1 | 1 | plain | Brute (25 ; 11) | 1,4 | 100 |
| 2 / 2 | 2 | pillars | Brute (47 ; 14) ; Archer (19 ; 11) | 3 | 125 |
| 3 / 3 | 3 | plain | Archer (19 ; 13) ; Brute (47 ; 17) ; Brute (47 ; 17) | 4,2 | 145 |
| 4 / 5 | 4 | forge | Lamie (50 ; 16) ; Brute (83 ; 20) ; Molosse (66 ; 16) | 6 | 175 |
| 5 / 6 | 5 | hourglass | Brute (124 ; 24) ; Archer (50 ; 19) ; Molosse (100 ; 19) ; Officiant (62 ; 13) | 8,4 | 195 |
| 6 / 8 | 6 | garden | Officiant (69 ; 16) ; Molosse (110 ; 23) ; Brute (138 ; 29) | 6,6 | 215 |
| 7 / 10 | 7 | pillars | Porte-égide (176 ; 32) ; Brute (211 ; 35) | 6,8 | 245 |
| 8 / 12 | 8 | convoy | Officiant (98 ; 23) ; Archer (78 ; 34) ; Archer (78 ; 34) ; Brute (195 ; 42) | 6,6 | 265 |
| 9 / 13 | 9 | reservoir | Lamie (132 ; 40) ; Molosse (176 ; 40) ; Porte-égide (184 ; 45) | 6 | 295 |
| 10 / 15 | 10 | pillars | Porte-égide (300 ; 54) ; Archer (144 ; 48) ; Lamie (216 ; 48) ; Officiant (180 ; 33) | 8,4 | 325 |
| 11 / 17 | 11 | garden | Archer (127 ; 51) ; Molosse (254 ; 51) ; Lamie (191 ; 51) | 5,4 | 355 |
| 12 / 20 | 12 | pillars | Pâris — prototype (840 ; 95) ; Lamie (216 ; 54) ; Molosse (288 ; 54) | 12 | fin de run |

## Coût de dilution

Probabilité de voir au moins un exemplaire d’une famille présente en trois exemplaires dans la main initiale de cinq : 1 − C(N−3,5)/C(N,5).

| Deck | Probabilité |
|---|---|
| 15 | 73,626 % |
| 20 | 60,088 % |
| 30 | 43,35 % |

Le maximum de trente est une capacité, pas un objectif automatique. La préparation automatique utilise vingt ; les expériences comparent quinze et trente. La réserve n’entre jamais dans la pioche en cours de combat.

## Budget de monnaie

Sans ventes ni Obole : 40 initiaux + 8 × 35 + 3 × 65 = **515 or** avant le boss. Cinq marchands, deux sacs de six chacun : plafond 60 cartes achetables pour 360 or. Cinq soins à 25 = 125 or. Six équipements valent environ 350–400 or selon le build. Tout acheter est impossible ; l’alternative cartes / santé / équipement existe avant même les reliques. Le sac coûte 6 or par carte aléatoire ; une normale choisie coûte 8 ; la revente vaut 1. Le troc 3 pour 1 détruit deux exemplaires contre de la précision.

## Quantité de butin et rareté

E[cartes] = somme n × p × taille du sac ; Var = somme n × p × (1−p) × taille² pour des jets indépendants. Probabilité d’au moins un sac = 1 − produit (1−p)^n. Les tables [drop_expectations.csv](drop_expectations.csv) et [drop_probabilities.csv](drop_probabilities.csv) donnent les valeurs recalculées. Elles supposent 32 morts éligibles avant le boss ; les porteurs sacrifiés au convoi réduisent ce total. Les taux sont par **mob et canal**, pas par combat ni par carte individuelle.

## Borne contre une victoire sans jouer de cartes

Sur le boss V1, la pression seule enlève 2,5 % × (1+…+9) = 112,5 % des PV max au terme du tour 17. Sans jouer de carte, les équipements/reliques ne fournissent aucun soin déclenchable dans cette rencontre. Même en ignorant tous les dégâts ennemis et les contraintes de déplacement, le meilleur plafond offensif prend dix-sept attaques de secours, dix-sept renvois de Gardien et un Miroir : [17 × (0,28+0,25) +0,40] × Pmax = **1370,096 dégâts physiques avant résistance**. Pmax = 145,6 avec six points de puissance.

Les PV physiques effectifs du groupe valent 840/0,9 +216 +288 = **1437,333**. Le plafond de dégâts reste inférieur : le boss ne peut pas être gagné avec ces seuls gestes, même sous des hypothèses très favorables. Cette borne dépend du catalogue actuel (pas de soin passif sans impact de carte, pas de bonus d’équipement sur le secours) ; le générateur la revérifie et échoue si elle cesse d’être vraie. Cela complète le témoin automatique à zéro carte, au lieu de traiter son échec comme une preuve universelle.
