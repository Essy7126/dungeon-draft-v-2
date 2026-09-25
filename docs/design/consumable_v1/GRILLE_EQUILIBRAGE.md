# Comment comparer les cartes, objets et statistiques

## Quatre budgets simultanés

Le coût d’une action est au moins un vecteur : **PA, exemplaires, exposition, préparation**. Ramener tout à « dégâts par PA » favoriserait les cartes qui brûlent le plus vite la réserve. Ramener tout à « dégâts par exemplaire » favoriserait des cartes lentes et rigides. Les deux ont besoin d’une place.

Exemple sans résistance, passif ni équipement : Ouvrir la garde + Frapper la faille produit 0,35 + 0,95 + 0,55 + 0,45 = **2,30 P**, pour 3 PA et deux copies. Dernier verdict sur une cible déjà sous 35 % produit **2 P**, pour 3 PA et une copie. Le premier ensemble est meilleur en dégâts immédiats ; le second est meilleur en consommation et dépend d’un autre moment du combat. Ce sont deux valeurs pertinentes, pas une incohérence de rareté.

Repousser et Choc de masse, ainsi que Volée croisée et Pluie de pointes, conservent volontairement une proximité de rôle. La version élite améliore le rendement ou la portée, et fournit une autre famille jouable dans le même tour. C’est une redondance assumée de ravitaillement, pas une nouvelle mécanique à faire apprendre. Si les joueurs ne perçoivent que des copies recolorées, ces deux paires sont les premières candidates à une différenciation future ; ne pas multiplier cinquante statuts pour la cacher.

## Cartes : protocole complet et lecture

Chaque famille est calculée dans 48 combinaisons : quatre niveaux (1,4,8,12), six situations (préparée, sans préparation, armure, cible isolée, coup létal, mur), deux états (base/améliorée). Total **2 304 cas**. Le comparateur applique la carte quand elle est légale et déroule deux phases ennemies face à un état témoin sans la carte.

Mesures : dégâts immédiats, dégâts supplémentaires après deux phases, PV du héros préservés, garde produite, cases parcourues/déplacées, pioche supplémentaire et activations supprimées. Les résultats illégaux restent dans le tableau : une stase sans marque ou un tir bloqué par un mur doit échouer proprement. Une carte de déplacement ne doit pas être déclarée mauvaise parce qu’elle n’inflige aucun dégât.

Dans `card_summary.csv`, les coefficients résument le scénario préparé au niveau 12 et les dégâts sur **toutes** les cibles touchées, après deux phases. Ils ne sont pas des coefficients bruts à recopier dans Godot. Le catalogue/manifeste donne les coefficients bruts. Les données détaillées régénérées permettent d’isoler les autres scénarios. Les améliorations de portée/déplacement ont en plus des témoins de légalité propres dans les tests : leur bénéfice ne se voit pas nécessairement dans une cible déjà accessible.

Le contrôleur n’optimise pas l’usage futur d’une rare très coûteuse. Il faut donc maintenir les cas forcés pour les cartes dieu/immortel : attendre un nombre réaliste de drops ne donnerait aucune couverture suffisante de ces effets.

## Équipements, reliques et spécialisations

Pour chaque classe : trois rencontres (sablier, élite aux colonnes, second groupe élite), deux graines, un deck fourni contenant des normales et des élites. Chacun des 18 équipements et chacune des 8 reliques sont comparés séparément au même personnage sans cet ajout. Chaque spécialisation est comparée sur sa classe. Total **672 comparaisons appariées**, plus 24 combats témoins.

Les équipements et reliques ont donc 24 comparaisons chacun, les spécialisations six. On mesure variation des copies dépensées, PV restants rapportés au maximum, tours, victoire et or. Une amulette de vol de vie peut sauver de la santé sans changer les copies ; une Obole peut améliorer uniquement la monnaie. Le tableau distingue ces cas. On ne conclut pas qu’un objet a été « neutre » en regardant seulement les victoires.

Les 135 paires d’équipement occupant des emplacements différents et les **729 ensembles complets** (3 choix dans 6 emplacements) font également l’objet de vérifications des bornes de statistiques. Les 28 paires de reliques résolvent cinq familles représentatives chacune, avec vérification des limites et de la consommation. Ce n’est pas l’exploration exhaustive de tous les tours possibles avec les 729 ensembles : cette nuance évite une fausse preuve de complétude.

## Seuils et valeurs dérivées

| Effet | Calcul utile | Conséquence |
|---|---|---|
| +5 % de Pbase | À points de puissance x, gain relatif = 0,05 / (1+0,05x) | Gain additif constant, gain relatif décroissant ; pas de multiplicateurs empilés par point |
| +6 % PVbase | PV supplémentaires = 0,06 × PVbase, avant arrondi | Écart de niveau, soins proportionnels et pression doivent être étudiés ensemble |
| +2 points de résistance | EHP = PV / (1−résistance) | Le gain marginal relatif augmente ; plafond 40 % indispensable |
| Une carte offensive en plus | Impact/P et PA nécessaires ; dépend aussi de sa famille déjà jouée ce tour | Deux copies identiques ne permettent pas un double lancement immédiat |
| Main +1 | Une option initiale de plus, pas une action ou un PA | L’objet peut réduire la pénurie de choix, sans créer de ressources consommables |
| Portée +1 | Franchissement d’un seuil de case, pas un bonus linéaire de DPS | Tester obstacles, portée minimale et déplacement économisé |
| 0,25 P de renvoi défensif | Au plus une attaque absorbée par tour ; physique ; aucun proc direct | Contribution offensive conditionnelle du Gardien, pas boucle de coups gratuits |
| 0,60 P de bouclier initial | Protection d’un seul premier tour ; expire même inutilisée | Le Casque n’équivaut pas à 0,60 P tous les tours |
| Soin +30 % | Multiplie le soin, ensuite plafonné aux PV manquants | Une trousse n’a pas de valeur si les soins sont déjà en excès |

Les 336 répartitions de caractéristiques dans le tableau de calcul couvrent les extrêmes, mais la politique de run n’en choisit qu’une par classe. Pour éviter une interprétation trompeuse, l’effet exact des répartitions est démontré par formules ; leur efficacité de run n’est pas déclarée comparée exhaustivement.

## Économie des raretés extrêmes

Avec 32 morts éligibles avant le boss, l’espérance est 108,1 normales, 9,76 élites, 1,1 rare, 0,116 légendaire, 0,0132 dieu et 0,0014 immortel. La probabilité d’au moins une immortelle est proche de 0,14 % par run entièrement parcourue avec ces morts : ce n’est pas un contenu sur lequel construire un tutoriel ou une progression obligatoire.

Cela ouvre deux décisions distinctes. **Socle retenu :** garder ces catégories comme surprises exceptionnelles, avec effets forcés dans les tests. **Hypothèse future, hors V1 :** une longue méta-collection pourrait offrir une voie de découverte horizontale ou un défi explicitement récompensé. Il faudrait alors reconsidérer la persistance et la fréquence ; on ne glisse pas subrepticement cette garantie dans les sacs de base.

## Ce qui ne doit pas entrer dans un score unique

Une poussée peut sauver un tour, produire des dégâts de presse et supprimer un drop en laissant passer un porteur. Une garde peut protéger les PV et maintenant contribuer à l’attrition offensive du Gardien. Une augmentation de dégâts peut économiser une copie et financer indirectement un achat. Ces interactions expliquent pourquoi le rapport conserve plusieurs colonnes et plusieurs niveaux de preuve.

La priorité de réglage est : erreur de règle, impossibilité structurelle, économie de run, écart entre classes sous plusieurs contrôleurs, puis confort et variété observés chez les joueurs. Une égalité exacte de victoire entre classes n’est ni atteinte ni annoncée comme l’objectif suffisant du jeu.
