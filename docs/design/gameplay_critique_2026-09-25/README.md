# Critique des dernières idées de gameplay

25 septembre 2026 — dépôt examiné à `c6ab5a72`, avec les modifications locales déjà présentes. Audit des propositions des 24–25 septembre, sans modification du gameplay public. Les calculs et expériences ajoutés ici sont indépendants des rapports antérieurs.

## Avis de conception

**La direction la plus forte est un tactique de préparation et d'adaptation : des copies consommables, une identité persistante, et des salles qui permettent d'économiser des ressources par de bonnes décisions.** Le risque principal est de promettre des builds précis tout en distribuant leurs composants comme des munitions largement interchangeables.

Je conserverais les sacs par monstre, les normales utiles, l'investissement par famille et les outils spatiaux. Je travaillerais d'abord l'accès au plan et le coût des conversions. Ajouter immédiatement des classes, des raretés ou les six nouvelles cartes proposées disperserait cet effort.

Trois distinctions changent le diagnostic :

- Le produit Godot joue encore avec dix copies initiales et une main de quatre ; `consume()` renvoie la carte en défausse, sous réserve des limites d'usage. La V1 consommable est un modèle séparé.
- La V1 contient des règles exécutables ; les nouvelles applications StS/Wakfu proposent des transformations qui ne sont pas encore dans ce modèle.
- Les calculs de probabilité, les combats du contrôleur automatique et le plaisir d'un joueur sont trois preuves différentes. Les résultats ci-dessous les distinguent.

Sources prioritaires : [règles V1](../consumable_v1/REGLES_V1.md), [catalogue exécutable](../consumable_v1/content.mjs), [audit des sorts](../spell_comparison_2026-09-25/AUDIT_ET_PRIORITES.md), [six propositions StS](../slay_the_spire_complete_2026-09-25/APPLICATION_CATABASE.md), [application des builds Wakfu](../wakfu_character_builds_2026-09-25/APPLICATION_CATABASE.md). Pour le produit : [référence courante](../../current/product.md), [gestion des cartes](../../../core/expedition/catabase_cards.gd), [classe Cartes](../../../core/expedition/class_cards.gd).

## 1. Le ravitaillement finance l'improvisation bien mieux qu'un combo fixe

Le groupe « classe + communes » reçoit 70 % des normales, mais comprend **quatre familles natives et huit communes**. Une famille native précise reçoit donc `0,70 / 12 = 5,833 %` de chaque tirage normal. Le taux de 70 % n'est pas un taux de cartes de la classe.

Sur les 32 morts éligibles pré-boss du modèle, les **108,1 normales attendues** se répartissent ainsi :

| Destination | Copies attendues |
|---|---:|
| Quatre familles de la classe | 25,22 |
| Huit familles communes | 50,45 |
| Familles des autres classes | 32,43 |
| Une famille normale précise | 6,31 |

Après les trois premiers combats, **34,27 %** des parcours n'ont reçu aucun nouvel exemplaire d'une famille normale précise. Pour deux familles données, **57,30 %** n'ont pas renouvelé au moins l'une des deux. Les copies de départ peuvent encore exister : ce ne sont pas des taux de mains mortes ni de défaite.

J'ai calculé un test volontairement exigeant de continuité : trois exemplaires initiaux d'une famille, puis **un usage de cette famille dans chacun des douze combats**. Les drops arrivent après victoire, pas avant le combat qui les produit. La distribution est calculée exactement, en conservant les stocks possibles à chaque étape.

| Approvisionnement de la famille | Probabilité de pouvoir payer les douze usages |
|---|---:|
| Sacs seuls | **8,46 %** |
| Sacs + une copie achetée à chacun des cinq marchands | **59,97 %** |
| Sacs + un achat et un troc ciblés à chaque marchand | **99,22 %**, sous conditions |

La deuxième ligne coûte 40 or. La troisième coûte 40 or et **quinze normales sacrifiées au troc**, supposées disponibles aux bonnes dates ; leur disponibilité et les autres dépenses ne sont pas simulées ici. Ce n'est pas une garantie gratuite. Les deux services existent déjà dans les règles V1.

Un calcul seulement global donne 18,14 % de chances de recevoir les neuf copies supplémentaires nécessaires ; le calendrier ramène l'accès effectif à 8,46 %. C'est un exemple concret de l'erreur « le total suffit, donc le build fonctionne ».

**Critique :** l'amélioration par famille conserve l'investissement, mais pas l'accès à la famille. Un build normal peut changer de langage entre deux combats. Cela peut être plaisant si l'adaptation est la promesse ; cela devient frustrant si la sélection vend une rotation stable.

**Décision recommandée :** rendre visible un plan de réapprovisionnement d'une ou deux normales : exemplaires possédés, marchands restants, achats et trocs possibles. Le contrôleur actuel n'achète jamais de cartes à l'unité et ne troque vers une famille que lorsqu'il n'en possède plus. Ses runs évaluent mal un joueur qui entretient volontairement son moteur. Corriger cette politique de laboratoire avant d'augmenter tous les taux.

Une variante purement distributive « 45 % natives, 25 % communes, 30 % étrangères » monte le même test sans marchand à 61,47 %, mais réduit le ravitaillement commun. C'est une autre direction de design, pas un correctif nécessaire ni un réglage adopté. Préférer d'abord le levier marchand déjà disponible.

## 2. Séparer accès en main et capacité à jouer le combo

Hypothèse : trois copies de A, trois copies de B, main initiale uniforme. « Ouverture préparée » garantit une copie A **normale déjà possédée**, qui occupe un des cinq emplacements ; les quatre autres sont aléatoires.

| Deck | A et B en main de 5 | Une normale A préparée | Main de 6 sans préparation |
|---|---:|---:|---:|
| 15 | 51,45 % | 67,03 % | 64,76 % |
| 20 | 33,09 % | **53,04 %** | 43,89 % |
| 30 | 16,53 % | **37,06 %** | 22,96 % |

La carte préparée produit un gain important sans ajouter de PA ni de copie. Elle ne répare pas une réserve vide. La restriction aux normales est ma proposition : garantir une rare de sauvetage ou une attaque exceptionnelle pourrait rendre l'ouverture trop systématique.

En revanche, une carte de sélection à 1 PA laisse trois PA :

- elle peut encore précéder un duo à 1 + 2 PA ;
- elle empêche un duo à 2 + 2 PA pendant ce même tour, sauf réduction explicite ;
- une rétention peut préparer le tour suivant, mais paie en délai et en place occupée dans la prochaine main.

**Conséquence :** la sélection payante n'aide pas symétriquement l'Assassin et le Gardien. Mesurer les combinaisons effectivement jouables, pas seulement celles visibles en main.

### Recentrage est moins généreux que son nombre imprimé

Témoins exécutés dans le résolveur V1, réserve de pioche suffisante :

| Cartes avant de jouer Recentrage | Base « pioche 2 » | Améliorée « pioche 3 » |
|---|---:|---:|
| 5 | 1 nouvelle carte | 1 nouvelle carte |
| 4 | 2 nouvelles cartes | 2 nouvelles cartes |
| 3 | 2 nouvelles cartes | 3 nouvelles cartes |

La copie jouée est retirée **avant** la pioche. À main pleine, Recentrage se remplace donc par une carte nouvelle ; il n'est pas sans effet. Mais son amélioration ne sert qu'après avoir libéré assez de places. Le futur texte de Lecture du danger devra distinguer « pas d'augmentation de taille de main » et « pas de nouvelle option ».

**Priorité :** comparer une ouverture normale préparée à la référence, puis la rétention, séparément. Ajouter simultanément préparation, filtrage, main élargie et rétention empêcherait de savoir ce qui a réellement amélioré le jeu.

## 3. Critique des propositions récentes, une par une

| Proposition | Avis | Ajustement ou critère décisif |
|---|---|---|
| Lecture du danger | Intéressante, priorité secondaire | Le filtrage doit justifier un PA et une copie. D'abord mesurer si le plan trouvé peut encore être joué. Elle peut remplacer une fonction de Recentrage plutôt qu'élargir le pool. |
| Réserve de geste | Bonne piste | Défense moindre contre accès différé fiable : un compromis lisible. Tester comme amélioration d'une garde normale pour éviter une nouvelle famille supplémentaire. |
| Transfert de faille à 1 PA | Trop conditionnelle pour une normale essentielle | Deux ennemis, une marque vivante, une destination utile, une copie supplémentaire. À portée comparable, remettre une marque avec une attaque peut produire davantage de valeur. Un transfert gratuit mais borné dans un passif est plus convaincant ; il doit remplacer un bonus existant. |
| Répercussion à sacrifice choisi | Bonne intention, rémunération à revoir | Choisir combien perdre ne suffit pas si la conversion reste moins rentable que garder sa défense. Deux formules incompatibles circulent dans les dossiers : les comparer explicitement. |
| Tir de relais | Une des meilleures pistes | Le tir produit une option après le déplacement ; il ne demande pas une carte de préparation supplémentaire. Garder le sacrifice de dégâts/portée et vérifier qu'un simple aller-retour ne devient pas la meilleure routine partout. |
| Condensation | À revoir fortement | Son échange actuel fait perdre du feu, une copie et 2 PA pour moins de garde qu'une commune à 1 PA. L'extinction d'un danger allié peut la sauver, mais c'est alors son véritable rôle. |
| Choc de masse lié aux obstacles | Bonne différenciation | Il doit être meilleur près d'un mur et moins bon en espace ouvert. La case d'arrivée et la catégorie d'obstacle doivent être lisibles. |
| Pluie de pointes en ligne | Bonne différenciation | La géométrie peut remplacer la supériorité numérique. Tester des formations qui avantagent tour à tour la ligne et la croix. |
| Ancre de repli de l'Arpenteur | Prometteuse, essai isolé | Retour limité à une fois, destination libre, trajet/franchissement explicite. Comparer au PM actuel et aux spécialisations, sans addition automatique. |
| Eau et réactions de terrain | Prometteuses après les bases | Réemployer le système Godot existant ; commencer avec deux réactions compréhensibles et un accès normal, pas une nouvelle chimie complète. |

### Répercussion : le sacrifice doit payer une vraie décision

À P = 40, au contact, sans équipement, résistance ou riposte ennemie, valeurs exécutées :

| Séquence | PA | Copies | Dégâts | Garde restante |
|---|---:|---:|---:|---:|
| Garde ferme → Heurt du rempart | 4 | 2 | 60 | 46 |
| Garde ferme → Répercussion actuelle | 4 | 2 | 47,6 | 0 |
| Même Répercussion, avec Bastion | 4 | 2 | 54,5 | 0 |
| **Garde de secours → Heurt du rempart** | **3** | **1** | **60** | **10** |

La dernière ligne est un comparateur important : le bonus du Heurt demande une garde positive, sans seuil ni consommation. Le joueur dispose déjà d'un combo économe, au prix d'une protection plus faible. La grosse garde reste utile face à une vraie menace ; elle n'est pas nécessaire pour armer le Heurt.

L'audit des sorts propose `0,70 P + 1,50 × garde sacrifiée`, sacrifice limité à `0,80 P`. Avec Garde ferme, cela donne **76 dégâts et 14 garde**. Par rapport au Heurt avec Garde ferme, on échange **32 garde contre 16 dégâts**. C'est un choix plausible si ces dégâts suppriment une activation ou terminent le combat.

L'autre dossier propose de choisir le sacrifice tout en conservant l'ancien coefficient `0,60` et l'attaque `0,50 P`. Tout convertir donne encore 47,6 dégâts. Ce réglage ne résout pas le mauvais rendement au contact. La portée 1–3 peut toujours le justifier : ne pas déclarer la carte dominée dans toutes les situations.

Enfin, Répercussion est **rare**. La probabilité de trouver cette famille native précise avant le boss n'est que **32,22 %**, même avec les 32 morts éligibles. Le Gardien ne devrait donc pas être présenté comme une classe dont la conversion centrale exige cette carte. Une amélioration normale peut proposer le premier choix garde/attaque ; la rare en étend la portée ou l'échelle.

### Condensation : une conversion n'est pas intéressante par définition

Le feu de base produit un tic à `0,35 P`. Condensation, telle que proposée, en donne un seul tic de garde, plafonné à `0,60 P`.

À P40 : **14 garde pour 2 PA**, une copie consommée et une zone retirée, face à **18 garde pour 1 PA** avec Garde brève. Même feu amélioré + Mèche n'atteint que `0,55 P` avant bonus de garde : le plafond à `0,60 P` n'est pas le vrai frein dans ce catalogue.

La garde commune ne supprime pas un feu dangereux : Condensation garde donc un usage d'extinction. Mais son texte doit vendre ce choix. Deux expériences possibles, séparées :

1. **Extinction de secours :** 1 PA, enlève une zone alliée et protège modestement ; outil de sortie, pas moteur de tanking.
2. **Conversion de chaleur restante :** retire la zone, convertit ses tics restants en une garde totale plafonnée. La puissance dépend alors du dommage futur abandonné. Ne pas multiplier par le nombre hypothétique de cibles.

Ces variantes restent à simuler. Aucune n'est adoptée ici.

## 4. Les améliorations numériques ne sont pas automatiquement mauvaises

Le comptage **33/48 améliorations limitées aux dégâts** est confirmé. Mais je ne ferais pas de « réduire ce pourcentage » un objectif de conception.

Sur une cible sans résistance à 62 PV et P40, Heurt sous garde inflige 60 : il laisse 2 PV. Son amélioration purement numérique porte le potentiel à 66 et tue. Ce témoin a été exécuté. Une amélioration numérique peut donc supprimer une activation, économiser une copie et changer le plan.

À l'inverse, Transfert de faille ajoute une nouvelle règle sans garantir un meilleur choix. **La bonne mesure est le changement de décision dans des situations utiles**, pas le nombre de verbes sur la carte.

Je garderais des améliorations simples sur les attaques de référence, et des transformations de règle sur quelques familles identitaires. Trois choix d'amélioration par run suffisent à rendre quelques transformations importantes ; il n'est pas nécessaire de complexifier les 48 familles.

## 5. Statistiques : puissance rémunérée en dégâts, défense et copies

Niveau 12, six points dans une seule caractéristique, sans objet :

| Investissement | PV | P | Résistance physique | Garde ferme produite |
|---|---:|---:|---:|---:|
| Puissance | 675 | 145,6 | 0 % | **167,44** |
| Vitalité | 918 | 112 | 0 % | 128,80 |
| Résolution | 675 | 112 | 12 % | **167,44** |

La puissance et la résolution donnent ici la même garde produite. La puissance augmente aussi attaques, marques, renvoi et effets proportionnels à P. La résolution conserve sa résistance physique ; elle n'est pas strictement dominée. Mais les caractéristiques ne correspondent pas clairement à « attaque », « vie », « bouclier ».

### Nouvelle expérience : 40 runs, 20 graines appariées

Gardien/Bastion, graines **26001–26020**, contrôleur et achats inchangés, préparation maximale vingt. Une seule expression du contrôleur de progression a été remplacée dans une copie isolée : au niveau 12, **4 résolution + 2 vitalité** deviennent **4 puissance + 2 vitalité**.

| Mesure | Répartition de référence | Variante puissance |
|---|---:|---:|
| Victoires | **19/20** | **18/20** |
| Copies consommées moyennes, sur les 18 graines gagnées par les deux | **98,39** | **87,22** |
| Stock final moyen, mêmes 18 paires | 25,06 | 33,22 |

Une graine n'est gagnée que par la référence ; une échoue avec les deux. L'écart de victoire ne permet pas un classement fiable. La puissance économise ici **11,17 copies** sur le sous-groupe des doubles victoires, tout en abandonnant de la résistance. Ces moyennes sont conditionnées à la réussite des deux variantes ; ne pas les généraliser aux tentatives perdues.

**Ce que cela change :** mon inquiétude sur la polyvalence de P ne justifie pas de supprimer la résolution. Le compromis observé mérite d'être conservé, exposé au joueur et réévalué sur plusieurs types de dégâts. Ne pas régler les caractéristiques à partir d'un taux de victoire isolé.

## 6. La pression arbitre déjà contre les plans lents

La pression cumulée vaut `2,5 % × k(k+1)/2` des PV max, avec `k = tour − 8` : **25 % au tour 12**, **52,5 % au tour 14**, **90 % au tour 16**, **112,5 % au tour 17**, si le combat continue jusque-là. Elle traverse garde et résistance.

Cela protège contre la temporisation, mais toute nouvelle mécanique de maturation, rétention ou terrain doit payer ce calendrier. La vitalité n'accorde pas de tours supplémentaires contre cette seule pression à ratio de santé égal, puisque la taxe croît avec les PV max. Les dégâts gagnent en comparaison en avançant la fin du combat.

Je garderais la pression comme témoin au premier prototype. Pour tester un Gardien patient, essayer ensuite une variante annoncée : délai lié au type de rencontre ou objectif de salle permettant d'éviter une phase, avec limite stricte. Retirer la pression et augmenter les soins en même temps effacerait la mesure du coût d'attendre.

## 7. Deux raretés presque invisibles : coût de production à assumer

Probabilités exactes, runs théoriques parcourant les 32 morts éligibles, indépendantes entre elles :

| Rang | Présence avant boss | Au moins une découverte en 20 runs complètes | Nombre de runs pour dépasser 50 % de chance de découverte |
|---|---:|---:|---:|
| Légendaire | 10,99 % | 90,26 % | 6 |
| Dieu | 1,31 % | 23,22 % | 53 |
| Immortel | 0,1399 % | **2,76 %** | **496** |

Les parties perdues plus tôt réduisent encore l'exposition réelle. Le chiffre 496 n'est pas une garantie ni un délai moyen.

Si ces rangs sont des surprises assumées, garder leurs taux est cohérent. **Je n'y investirais pas maintenant plusieurs systèmes, tutoriels ou grosses productions visuelles.** Pour le prototype humain, employer des graines de démonstration où ces cartes existent afin d'étudier leur usage, sans modifier silencieusement les tables publiques. Ne pas construire une identité de classe sur leur découverte.

## 8. Idées supplémentaires à mettre en concurrence

Les valeurs suivantes sont des contrats d'essai, pas une nouvelle V1 validée. Elles peuvent être testées en remplaçant une règle existante ; ne pas tout cumuler.

| Idée | Contrat de départ | Décision produite / mesure |
|---|---|---|
| **Plan de ravitaillement** | Marquer une famille normale recherchée ; au marchand, afficher achat à 8 et troc 3→1 déjà disponibles, avec validation du joueur. Pas de drop supplémentaire. | Dépenser pour maintenir son plan ou adapter le deck au stock. Mesurer les usages réellement empêchés et le coût en autres achats. |
| **Une ouverture normale préparée** | Choisir une copie normale possédée, incluse dans la main de cinq. Une seule, sans relance. | Sacrifier un peu de surprise pour lancer son moteur. Comparer aux 33,09 % / 53,04 % du deck vingt ; surveiller les ouvertures systématiques. |
| **Amélioration de Garde brève : préserver un geste** | Variante de son amélioration : garde reste à 0,45 P, conserver une autre carte pour le prochain tour, une transition seulement. Remplace le gain numérique à 0,70 P. | Défense immédiate plus forte ou meilleure préparation future. Ne grossit pas le catalogue. |
| **Garde ferme : reliquat** | Variante d'amélioration : garde initiale reste 1,15 P ; conserve au prochain tour au plus 0,35 P de son propre reliquat, transfert unique, sans nouvelle génération. Remplace l'amélioration à 1,40 P. | Défendre davantage maintenant ou préparer un Heurt demain. Ne transfère que la garde réellement non dépensée ; vérifier l'ordre avec l'Urne. |
| **Carte à deux usages pour l'Assassin** | Variante d'amélioration de Frapper la faille : sur cible marquée, choisir son bonus de dégâts habituel ou un recul d'une case libre après l'impact. La marque reste consommée une fois. | Finir une cible ou sortir d'un danger annoncé. Mesurer si le recul vaut l'abandon de 0,55 P ; pas de bonus et déplacement cumulés. |
| **Rencontres qui rémunèrent un autre verbe** | Reprendre trois situations Godot : attaque préparée à éviter, soutien à isoler, dalle à occuper. Même budget de récompense et droits de drop finis. | Donner une valeur au déplacement/contrôle autrement qu'en ajoutant du DPS. Mesurer activations évitées et copies économisées. |

La dernière piste est probablement plus rentable que dix nouvelles cartes. Le laboratoire réduit les ennemis à sept archétypes, alors que le dépôt contient déjà des préparations, soutiens et interactions de salle plus riches. Ajouter des cartes de placement pour ensuite les évaluer surtout contre des ennemis à tuer sous pression leur donne une mauvaise chance de démontrer leur rôle.

## 9. Comparaison utile avec les références

| Référence | Ce que je retiens | Ce qui doit être adapté à Catabase |
|---|---|---|
| Étude locale Wakfu | Une spécialisation change ce qu'on prépare, conserve ou convertit. | Un moteur dont les pièces disparaissent doit disposer d'un approvisionnement fonctionnel ; les coefficients d'un jeu à sorts réutilisables ne suffisent pas. |
| Slay the Spire, démarche de Mega Crit | Chercher une place pour chaque carte, combiner métriques et observations. | Un contrôleur qui ignore achats unitaires et plans différés ne peut trancher seul leur valeur. |
| Into the Breach, démarche de Subset | Intentions lisibles, conséquences déterministes pendant le tour, manipulation des menaces. | Nos sacs et copies ajoutent une économie ; l'interface doit montrer à la fois la conséquence tactique et le coût de la copie. |

Les deux conférences de développeurs ont été relues pour cet audit : [Anthony Giovannetti, GDC 2019, notamment diapositives 6 et 12](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf) ; [Matthew Davis, GDC 2019, notamment diapositives 13, 20–21 et 30](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf). Les conséquences pour Catabase sont mon interprétation, pas des recommandations de ces studios sur ce projet. Il ne s'agit pas d'affirmations sur les versions actuelles des jeux.

## 10. Un écart de contrat à résoudre avant portage

La section salles de la V1 présente les effets avec la puissance de référence de la rencontre. Le résolveur emploie toutefois **la puissance du héros** pour la décharge du réservoir : `charges × 0,5 × h.p`.

Témoin exécuté, six charges, niveau de rencontre 12, cible sans résistance : **336 dégâts** sans puissance investie ; **436,8** avec six points de puissance. Un effet réellement basé sur P de référence resterait à 336.

Ce n'est pas nécessairement le mauvais choix de gameplay. C'est un contrat à trancher : dispositif indépendant du build ou amplificateur du personnage. Le modèle et la documentation doivent annoncer la même règle avant que l'on attribue leurs résultats à Godot. Aucun correctif n'est appliqué ici.

## 11. Ce que je prototyperais ensuite

1. **Accès au plan :** même économie, un achat/troc ciblé réellement utilisé par la politique ; comparer avant toute hausse des sacs.
2. **Ouverture :** référence contre une normale préparée, decks 15/20/30, sans ajouter d'autre outil de pioche.
3. **Un choix par classe :** une amélioration qui change l'usage d'une famille normale, avec un témoin numérique. Répercussion renforcée reste une option rare.
4. **Trois situations tactiques existantes**, puis le boss avec ses vraies transitions. Relever la disparition d'intentions, les déplacements utiles, les copies et PV dépensés.
5. **Observation humaine :** demander quel plan le joueur préparait, pourquoi il a gardé une rare et quelle consommation il a regrettée. Comparer aussi le temps de préparation et les cartes mortes en main.

Les expériences doivent conserver mêmes stocks, graines et positions au départ. Une action différente peut ensuite changer la pioche : c'est une conséquence du système, pas une raison de prétendre que toutes les trajectoires restent identiques. Pour les taux de victoire, conserver les paires et les causes d'échec ; ne pas comparer les seules moyennes des gagnants.

## Preuves, reproduction et limites

- **212/212 tests existants relancés**, zéro ignoré ; journal dans `artifacts/dev/gameplay-critique-2026-09-25/existing-tests.log`.
- Vérificateur V1 exécuté : manifeste et empreintes concordants pour la livraison antérieure de 640 runs. Ces 640 runs n'ont pas toutes été réexécutées par cet audit.
- Calculs StS et Wakfu vérifiés en mode `--check` : 47 scénarios / 50 assertions, puis 15 scénarios / 15 assertions.
- Nouveaux calculs : [script](calculs.mjs), [résultats portables](RESULTATS.json), probabilités exactes, énumération indépendante des mains de cinq, témoins exécutés et normalisations. La récurrence de stock a aussi été contrôlée par 100 000 trajectoires de ravitaillement indépendantes : 8,457 %, 59,832 % et 99,283 %, cohérents avec les trois probabilités exactes. Ces trajectoires ne sont pas des combats ; les 270 assertions internes ne sont pas 270 tests de gameplay supplémentaires.
- Nouvelle expérience Gardien : **40 runs terminées**, [script](policy_probe.mjs), [traces portables](EXPERIENCE_GARDIEN.json). La copie temporaire du contrôleur et les journaux sont dans `artifacts/dev/gameplay-critique-2026-09-25/`.
- Node utilisé : **v26.3.1** ; les anciens rapports avaient été produits sous Node v24.19.0. Aucun import/runtime Godot ni test humain réalisé ; aucun fichier de gameplay modifié.

Depuis la racine, sans dépendance npm :

```powershell
node docs/design/gameplay_critique_2026-09-25/calculs.mjs
node docs/design/gameplay_critique_2026-09-25/policy_probe.mjs
```

Ces commandes écrivent les détails dans `artifacts/dev/`, sans remplacer les instantanés portables. Pour contrôler les instantanés livrés et leurs liens :

```powershell
node docs/design/gameplay_critique_2026-09-25/verify.mjs
```

Le test de continuité ne simule ni survie, ni pioche, ni exigences spatiales. Les sacrifices au Convoi réduisent les drops réels. Les 20 graines du Gardien donnent une sensibilité exploratoire, pas une mesure précise de difficulté. Les valeurs des nouvelles idées restent des hypothèses à comparer.
