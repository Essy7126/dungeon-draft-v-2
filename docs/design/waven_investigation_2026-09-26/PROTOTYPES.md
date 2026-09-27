# Propositions limitées après l'étude WAVEN

Ces idées sont des contrats d'essai, **non implémentés et non validés par les 120 runs**. Les coefficients sont des hypothèses de départ. Une seule modification à la fois ; pas de nouvelle rareté ni de nouveau système d'équipement pour les faire fonctionner.

## 1. Plan de renouvellement : une aide de lecture du build

À la préparation, le joueur peut marquer jusqu'à deux familles comme importantes. Pour chacune, montrer « réserve / préparées », coût de l'exemplaire chez le prochain marchand s'il est disponible et ingrédients du troc. Dans la boutique, une entrée « restaurer mes deux pièces » présente les transactions possibles séparément, sans achat ni vente automatique.

Ce système n'augmente pas les drops et ne rend pas les cartes gratuites. Il rend utilisable une possibilité que le bot ignorait. Exemple V1 : une normale à 8 or ; deux familles à renouveler coûtent jusqu'à 16 or par visite si une seule copie de chaque manque. Sur cinq visites, au plus 80 or pour ce cas précis, contre trois normales par sortie de troc. Ces moyens ne sont pas interchangeables : le troc réduit le volume du stock de deux.

**Décision préservée :** renouveler une combo connue ou garder la monnaie et adapter le build au butin. Ne pas afficher une « meilleure carte » universelle qui encourage à rejouer éternellement le même duo.

**Critère :** dans des parties observées, le joueur trouve l'achat ciblé et peut expliquer ce qu'il sacrifie. Contrôler aussi l'utilisation des cartes hors favoris, pour éviter que cette aide fige les decks. La victoire seule n'est pas le critère.

## 2. Repli balisé : une maîtrise spatiale de l'Arpenteur

Variante d'amélioration de `r02`, à comparer à son amélioration existante : conserver coût et dégâts de base ; après l'impact, choisir **soit la poussée d'une case actuelle, soit un pas du héros d'une case vers une case libre**. Pas de téléportation à travers un obstacle, pas de PM généré, aucun déplacement si la résolution tue le héros. La destination est sélectionnée et prévisualisée avant engagement de la carte.

Une case est peu spectaculaire, mais change le destinataire du déplacement. Le joueur peut expulser l'ennemi d'une zone, ou sortir lui-même d'une menace. Le choix remplace la poussée : il ne donne pas les deux. À P40, le tir reste à `0,70 P = 28` dégâts bruts, contre `0,85 P = 34` pour l'amélioration générique actuelle : le prix de la flexibilité est six dégâts.

**Points à décider avant codage :** le pas contribue-t-il aux compteurs de distance parcourue ? Proposition : oui, exactement une case ; il peut ouvrir une condition « deux cases parcourues » mais aucun impact supplémentaire n'est créé. Déclenche-t-il les surfaces d'arrivée ? Proposition : oui, selon les règles ordinaires de déplacement, et cet effet apparaît dans l'aperçu.

**Scénarios :** terrain ouvert, dos au mur, coin occupé, zone de feu derrière le héros, garde ennemie poussable, cible immobile. Si le pas est toujours choisi, la poussée ou les rencontres ne donnent plus assez de valeur au placement adverse.

## 3. Relais de braise : amortir une préparation sans créer de compagnie

Essai de remplacement d'une amélioration du Thaumaturge, sur une famille de terrain existante : une copie pose un relais allié sur une case libre à portée 1–3 ; durée de trois tours du héros, trois charges au maximum, un relais actif. Au premier impact magique direct du tour à deux cases ou moins du relais, une charge inflige `0,30 P` à **un autre ennemi** également à deux cases ou moins du relais. « Magique » correspond ici au type de dégâts V1, pas à une nouvelle liste d'éléments. Le joueur choisit ce second destinataire dans la prévisualisation de l'action déclenchante.

Pas de cible secondaire valide : aucune charge dépensée. Pas de réaction aux dégâts du relais lui-même, aux brûlures ou aux autres déclencheurs. Pas d'activation immédiate à la pose. Détruire, remplacer ou quitter le relais fait perdre son potentiel restant. Aucun butin, occupation bloquante ou tour autonome pour cette première version.

Budget initial à comparer : pose à un PA, une copie ; plafond de **`3 × 0,30 P = 0,90 P`**, soit 36 dégâts à P40, **en supplément d'au moins trois impacts déclenchants**. Le total des cartes et PA comprend donc aussi ces impacts ; ce n'est pas « 36 dégâts gratuits ». Le relais ne permet pas d'économiser les trois cartes d'attaque. Il amortit seulement sa propre préparation et peut être entièrement inutile contre une cible seule.

**Décision préservée :** placer pour le groupe actuel ou pour l'arrivée suivante ; se rapprocher d'une zone dangereuse pour activer le relais, ou abandonner les charges. Le plafond borne les dégâts sans imposer une nouvelle jauge globale.

**Risque majeur :** ressemble déjà à un champ de feu avec plus de texte. Si le joueur choisit les mêmes cases et le même ordre que pour le feu actuel, abandonner l'idée. Son intérêt doit venir du choix de la seconde cible et du rendez-vous spatial. Comparer d'abord une version plus simple de l'amélioration du champ existant.

## 4. Faille transmissible : un transfert après le kill, limité à une cible

**Réexamen dans la [suite 02](suite_02/README.md)** : « un tour » doit être précisé. Dans le moteur V1, `markTurns=1` expire avant le prochain tour du héros ; la famille `a02` ne peut pas être rejouée immédiatement et le geste de secours ne consomme pas la marque. Les scénarios montrent aussi que les six dégâts abandonnés peuvent être soit excédentaires, soit indispensables au kill. Le contrat ci-dessous reste une proposition à corriger, pas une amélioration validée.

Variante de maîtrise de `a02`, à comparer à l'amélioration de dégâts actuelle : garder les coefficients de base et conditionnels ; si cette attaque tue la cible marquée, transférer une marque de **valeur fixe 0,20 P**, durée un tour, à un autre ennemi adjacent à la victime. Une seule transmission ; aucun déclenchement à partir d'un effet secondaire ; ne cumule pas les marques, conserve la plus forte.

À P40, la maîtrise abandonne les **six dégâts** de l'amélioration `+0,15 P`, en échange d'une prochaine marque potentielle valant huit dégâts. Ce n'est pas un gain net assuré : il faut d'abord tuer malgré la perte de six, avoir un voisin puis réussir un autre impact avant expiration. La transmission ne rembourse ni PA ni copie. Les interactions exactes avec la consommation de marque se résolvent à partir de l'état de la victime **avant** l'attaque.

**Décision préservée :** tuer maintenant la bonne cible de relais, ou frapper une menace isolée plus urgente. En V1, le passif d'Assassin récompense une cible sans voisin vivant adjacent : une transmission vers un voisin demande donc une configuration qui renonce à ce bonus initial. C'est un vrai compromis de géométrie, à mesurer ; ne pas rajouter un bonus de dégâts pour l'effacer d'emblée.

**Scénarios :** deux ennemis voisins ; cible à six PV près ; cible isolée ; second ennemi déjà marqué plus fortement ; dégâts secondaires létaux ; boss seul ; mort simultanée du porteur et du héros. Vérifier particulièrement l'ordre marque → dégâts → mort → sélection du relais.

## Une matrice commune avant validation

| Dimension | Cas à comparer | Mesure utile |
|---|---|---|
| Accès | Carte en main, en pioche, en réserve, épuisée | La promesse du build est-elle réalisable à ce combat ? |
| Géométrie | Ouvert, couloir, obstacles, cases occupées | Le meilleur choix de destination change-t-il ? |
| Adversaires | Seul, deux voisins, groupe espacé, cible immobile | Existe-t-il un coût réel à choisir ce moteur ? |
| Économie | Première copie, dernière copie, boutique proche ou lointaine | La dépense est-elle comprise et assumée ? |
| Déclenchements | Mort, invulnérabilité, dégâts indirects, effet récursif | Un événement produit-il exactement les effets annoncés ? |
| Lecture | Aperçu puis résolution | Le joueur prédit-il le bon résultat sans mémoriser les détails internes ? |

Pour le Gardien, je préfère résoudre les deux propositions concurrentes de Répercussion avant d'ajouter une cinquième idée. Pour les compagnons complets, il faudra ultérieurement chiffrer les actions autonomes, la protection par occupation et les réactions ennemies, au-delà des seuls dégâts.
