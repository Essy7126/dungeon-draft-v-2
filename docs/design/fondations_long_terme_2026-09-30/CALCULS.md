# Expériences : échelle, fiabilité et stock

[Script reproductible](laboratoire.py) et
[rapport exact](../../../artifacts/dev/20260930-fondations-long-terme-final/resultats.json).
164 contrôles analytiques réussis. Aucun combat nouveau ni campagne Monte-Carlo
n'est exécuté par ce script. Les fractions sont conservées avant affichage.

## 1. Prolonger les maîtrises n'est pas prolonger la profondeur

La formule active est +3 points de pourcentage par point investi sur les quatre
premiers, +2 sur les quatre suivants, puis +1. Le niveau actif est borné à 12.
Les budgets 38/50 sont des extrapolations, avec +2 points par niveau après 12.

| Budget | Allocations dans six éléments | Monoélément | Gain de dégâts mono par rapport à 26 points, à P fixe | Optima d'une composante 50/50 |
|---|---:|---:|---:|---:|
| 26, niveau 12 actif | 169 911 | +38 % | — | 11 |
| 38, niveau 18 hypothétique | 962 598 | +50 % | +8,70 % | 23 |
| 50, niveau 24 hypothétique | 3 478 761 | +62 % | +17,39 % | 35 |

Gain réel : `(1 + 0,50) / (1 + 0,38) − 1`, pas « +12 % de dégâts ».
Avec un poids 80/20, l'optimum numérique isolé reste tous les points dans la
composante majoritaire, aux trois budgets. Avec 65/35 : 18/8, 30/8 puis 42/8.
Ce sont des contributions de même nature à un effet, pas des builds de combat.

Les allocations sont comptées par `C(B+5,5)` ; les optima biélémentaires sont
énumérés exhaustivement et vérifiés indépendamment par les rendements marginaux.
L'étude précédente avait déjà énuméré les 169 911 allocations dans six
dimensions pour cinq répertoires. Nous ne présentons pas ce travail comme une
nouvelle campagne de jeu.

Un changement vers une courbe strictement concave départagerait certains
plateaux. Il ne créerait pas à lui seul des tours, objets ou routes intéressants.
Choix recommandé : conserver la courbe v1 pendant les premières expériences
de contenu, puis tester son prolongement sur des horizons définis. Le segment
+1 devient linéaire ; il ne faut pas présumer qu'il convient à une progression
illimitée.

## 2. L'extrapolation automatique de l'acte I coûte très cher

Puissance joueur actuelle : 16 au niveau 1, 93 au niveau 12 ; PV : 110 puis 675.
La puissance de référence historique des ennemis vient d'une **autre** courbe
du catalogue, 18 puis 112. Ces deux échelles ne doivent pas être confondues.

Trois expériences pour la fin d'un acte II hypothétique au niveau 18 :

| Hypothèse | P joueur | PV de base | Points | Gain d'un impact mono par rapport au niveau 12 |
|---|---:|---:|---:|---:|
| Niveau 12 conservé, contenu horizontal | 93 | 675 | 26 | 0 % |
| +4 % d'échelle par niveau, arrondi ; +2 points | 118 | 854 | 38 | +37,91 % |
| Taux géométrique moyen de l'acte I prolongé ; +2 points | 243 | 1 816 | 38 | +184,01 % |

Les gains excluent équipement, aptitudes, passifs, défense et arrondi de l'impact.
La deuxième courbe est un **candidat de banc d'essai**, pas un équilibre établi.
La troisième montre le risque d'utiliser le taux moyen de tout l'acte I : elle
n'est pas une prolongation des deux derniers gains, beaucoup plus faibles.

Commencer l'acte II sur un banc au niveau 12 permet de vérifier que les nouveaux
ennemis et choix apportent quelque chose à build constant. Tester ensuite
13–18 sur une courbe modérée. Les anciens coefficients en P peuvent rester
utiles ; on ajoute des comportements plutôt que des versions rendues obsolètes
uniquement par des dégâts fixes ou des conditions de niveau.

## 3. La fiabilité fait partie de la puissance

A et B sont deux fonctions disjointes ; une main de cinq doit contenir au moins
une copie de chacune. Tirage uniforme sans remise, cartes physiques distinctes.
Six copies d'une fonction nécessitent au moins deux familles si le plafond de
trois copies par famille reste actif.

| Deck préparé | Copies A / B | Ouverture garantie A | Probabilité |
|---|---:|---|---:|
| 15 | 3 / 3 | Non | 51,45 % |
| 15 | 3 / 3 | Oui | 67,03 % |
| 30 | 3 / 3 | Non | 16,53 % |
| 30 | 6 / 6 | Non | 46,36 % |
| 15 | 6 / 6 | Non | 91,61 % |

292 019 mains physiques sont énumérées sur les cinq scénarios et concordent
avec les formules hypergéométriques. Il ne s'agit ni de la probabilité de lancer
le combo (PA, ordre, cibles et copies peuvent manquer), ni d'un taux de victoire.

Conséquence : le plafond de 30 est une capacité de préparation, pas un objectif
obligatoire. Le stock de réserve porte l'endurance de run ; le deck préparé
porte la fiabilité dans la prochaine salle. Avant de créer une nouvelle stat
« pioche », tester préparation, ouverture, remplacement et redondance de fonctions.

## 4. Les systèmes de défense et d'attaque ont des rendements différents

À défense constante, `PV effectifs = PV / (1 − R)` :

| Résistance | Facteur de PV effectifs contre ce canal |
|---:|---:|
| 0 % | 1,000 |
| 10 % | 1,111 |
| 20 % | 1,250 |
| 30 % | 1,429 |
| 40 %, plafond actif | 1,667 |

Passer de 30 à 40 % représente **+16,67 %** de PV effectifs contre ce canal.
Ajouter 10 points de pourcentage de dégâts représente +10 % sans bonus,
+7,25 % avec +38 % déjà présent, +5,56 % avec +80 % déjà présent.
Ces valeurs ne rendent pas la défense universellement meilleure : mélange des
canaux, percement, attaques évitées, dégâts périodiques, pression, soins et coût
d'emplacement changent la décision. Elles interdisent de fixer un même prix à
« 10 % » indépendamment de la statistique et de son contexte.

Autre discontinuité : contre 80 PV, 39 dégâts demandent trois impacts, 40 en
demandent deux. Mesurer le nombre de phases ennemies nécessaires et l'excès de
dégâts perdu est plus utile que regarder seulement le pourcentage brut gagné.

## 5. Les copies obligent à calculer l'horizon de l'acte

Identité de stock :

`stock_fin = stock_début + acquisitions_utilisables + restitutions − copies_consommées`

Expérience isolée : six nouveaux combats, six copies restantes au passage,
douze nouvelles copies utilisables, aucun achat ni autre drop.

| Copies consommées par combat | Stock de fin |
|---:|---:|
| 2 | 6 |
| 3 | 0 |
| 4 | −6 : insuffisant |
| 5 | −12 : insuffisant |

L'attaque permanente permet de continuer à agir ; elle ne prouve pas que la
construction choisie reste jouable. Le besoin doit être calculé par **fonction**
et par famille, pas seulement en total d'inventaire.

Exemple de stress du contenu actuel : r04 est la seule normale avec au moins
50 % Soleil dans ses dégâts directs. Pour Assassin, Gardien et Thaumaturge,
chaque tirage normal a 2,5 % de chance de la fournir. Sur **60 tirages normaux
indépendants supposés**, on attend 1,5 copie ; la chance d'en obtenir au moins
trois est **18,95 %**. Pour Arpenteur : 3,5 copies attendues et **68,75 %**.
60 n'est pas un nombre de drops observé sur une campagne. Le calcul exclut les
autres fonctions Soleil et les raretés supérieures. Il illustre pourquoi la
moyenne du stock ne suffit pas à garantir l'endurance d'une fonction.

## 6. Ajouter des définitions change déjà les probabilités

Le butin d'équipement choisit actuellement uniformément une définition éligible.
Au premier palier : 14 définitions, dont six amulettes de maîtrise. Chance
conditionnelle d'une amulette lors d'un drop d'équipement : **42,86 %**.
Un tirage de slot uniforme parmi les six slots donnerait **16,67 %**, puis
choisirait une définition dans ce slot. C'est une hypothèse alternative, pas la
distribution active. Elle doit aussi traiter les slots déjà remplis, le budget
de rareté et les items ajoutés. Le nombre d'objets d'un slot ne doit pas devenir
un poids de drop involontaire.

## 7. Calculer toutes les possibilités nécessite des filtres

Au catalogue actuel : 2 187 combinaisons entièrement équipées, 28 paires de
reliques distinctes, 20 répartitions de trois points dans quatre aptitudes,
huit couples classe/spécialisation. Multiplié par les 169 911 allocations :
**1 664 747 199 360 états de produit cartésien**, avant deck et perfectionnements.

Ce nombre ignore la possession, l'accessibilité, les équivalences et les
compatibilités ; ce n'est pas un nombre de builds viables. Il sert à exclure
une stratégie d'énumération aveugle. Les 80 définitions cartes/objets/reliques
produisent déjà 3 160 paires et 82 160 triplets non filtrés.

Commencer par les effets isolés, filtrer les couples compatibles et reliés par
un événement, puis les boucles et triplets à risque ou à forte promesse. Enfin
exécuter les états légaux dans le vrai moteur et les campagnes avec leurs drops.

## 8. Un contre-exemple impose de fixer le contrat de statut

Application A : intensité 17, un tic restant. Application B : intensité 5,
trois tics. Conserver séparément les maxima donne **17 × 3 = 51**, alors que
les deux sources indépendantes ne fourniraient que **17 + 15 = 32**.

Le moteur actuel conserve précisément les maxima d'intensité et de durée.
Le contre-exemple abstrait n'est pas un bug démontré sur les durées actuelles
de Braise ; il révèle le comportement que de nouvelles durées permettraient.
Décider explicitement entre applications indépendantes, remplacement intégral
et conservation d'une application intégrale. Ne pas étendre les durées avant
ce choix ; conserver source, quantité, échéance et permissions ensemble.

## Preuves et limites

Le rapport conserve HEAD et SHA-256 des entrées. Les dix empreintes de l'étude
précédente concordent toujours, y compris observations et résumé du harnais.
Ses 359 tests moteur, six essais Passe-rive et 1 728 impacts concordants restent
des preuves **antérieures** ; ils ne testent ni les cartes futures ni l'acte II.
Le nouveau rapport couvre uniquement les calculs décrits ici.
