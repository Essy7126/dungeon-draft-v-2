# Affinités et transformations tactiques — proposition pour Catabase

> **Orientation révisée après le recadrage du 28 septembre 2026.** Les transformations
> décrites ici sont des exemples historiques et ne constituent plus la fondation recommandée du jeu.
> La proposition actuelle porte sur des axes de statistiques et de classification
> ouverts : [Fondations des statistiques et des cartes](../fondations_stats_cartes_2026-09-28.md).
> Les calculs restent valides dans leurs hypothèses ; un sort isolé ne suffit pas
> à juger l'intérêt d'un kit hybride entier.

28 septembre 2026. **Proposition de conception, pas fonctionnalité implémentée ni
équilibrage validé.** Elle remplace la direction Force/Finesse/Esprit/Ténacité rejetée.
Le travail porte sur la run Cartes existante, avec Battle, son parcours et ses sauvegardes.

- [Enquête comparative et sources](RECHERCHE.md)
- [Audit des 48 sorts](CATALOGUE.md)
- [Calculs et hypothèses](CALCULS.json), reproductibles avec [calculs.py](calculs.py)
- [Intégration, contenu manquant et critères de validation](INTEGRATION.md)

## 1. La proposition

La classe fournit une manière permanente d'agir. Les maîtrises déterminent les
effets que l'on développe. Les sorts permettent de **préparer, exploiter ou transformer
une situation**. Une hybridation réussie doit ouvrir une autre utilisation de cette
situation, avec une contrepartie visible.

Exemple central : je peux dépenser une marque pour achever sa cible, la garder
pour un contrôle, ou la transporter sur une case d'eau afin de préparer un autre
ennemi. La maîtrise Nuit rend la marque plus forte ; l'investissement Eau/Nuit
ouvre le transport. Le placement, le délai, les autres cartes disponibles et le
stock restant déterminent si cette transformation vaut le sacrifice.

Ce choix a quatre dimensions : quels domaines développer, quelles fonctions
emporter, quelle variante jouer maintenant, combien de copies engager dans ce combat.
L'élément seul ne doit répondre à aucune de ces quatre questions à la place du joueur.

## 2. Pourquoi les pourcentages ne suffisent pas

Supposons deux lignes de 8 dégâts, Eau et Terre, chacune augmentée de 1 % par point.
Avec un budget de 200 points :

| Répartition | Eau | Terre | Total |
|---|---:|---:|---:|
| 200 Eau / 0 Terre | 24 | 8 | 32 |
| 100 Eau / 100 Terre | 16 | 16 | 32 |
| 0 Eau / 200 Terre | 8 | 24 | 32 |

Les deux lignes permettent bien d'intégrer ce sort à plusieurs builds, mais **ce
sort isolé n'incite pas à partager les points**. Une palette entière, les coûts
d'investissement, les résistances, les équipements ou les effets annexes peuvent
changer ce résultat. Ce calcul n'est pas un jugement sur l'équilibrage de Dofus.

Avec un sort de base 40, réparti 80 % Eau / 20 % Nuit, six points et un bonus fictif
de 8 % par point : tout Eau donne 55,36 ; 3/3 donne 49,60 ; tout Nuit donne 43,84.
Une pente linéaire pousse ici à choisir le domaine dominant. Une moyenne de deux
statistiques n'est donc pas notre principale mécanique d'hybridation.

## 3. Architecture retenue et alternatives écartées

| Architecture | Ce qu'elle apporte | Limite pour notre run | Décision |
|---|---|---|---|
| Coefficients élémentaires seuls | Lecture simple, spécialisation des nombres | Ne garantit ni hybridation ni enchaînements | Garder comme base quantitative seulement |
| Maîtrises + variantes conditionnelles + fonctions redondantes | Investissement, situations de plateau, alternatives entre effets | Demande du contenu conçu et une prévisualisation exacte | Direction recommandée |
| Chaque carte consommée produit une rune ou une monnaie élémentaire | Planification de séquences, valorisation de l'ordre | Nouvelle barre ; risque d'alternance imposée ; proche de Wakfu/Gloomhaven | Ne pas ajouter au premier prototype |

Le système recommandé ne crée pas un tableau universel où toutes les paires
d'éléments réagissent automatiquement. Chaque transformation est une règle d'un
sort ou d'une petite famille, inscrite sur ses fiches. Feu sur Eau produit déjà
de la vapeur dans notre moteur ; cela ne devient pas artificiellement une nouveauté.

### Trois notions indépendantes

1. **Classe** : attaque permanente, passif, spécialisation. Elle ne correspond
   pas à une couleur unique. Un Gardien Eau/Nuit et un Assassin Eau/Nuit utilisent
   des outils communs avec des positions et prises de risque différentes.
2. **Maîtrise** : renforce des composantes identifiées et donne accès à certaines
   variantes. La Puissance de niveau reste une échelle automatique commune ;
   investir dans « tous les dégâts » n'est plus le principal choix d'attribut.
3. **Sort** : coût, cible, effet normal et au plus une transformation avancée dans
   le premier prototype. La carte reste la copie consommable de ce sort.

Une carte hors maîtrise reste jouable sous sa forme normale. Le Pas latéral reste
neutre : déplacer son personnage n'oblige pas à investir dans le Vent. Une attaque
à plusieurs composantes peut avoir des valeurs dépendant de maîtrises différentes,
mais ces composantes doivent avoir un sens jouable : dégâts Eau et manipulation
d'une marque Nuit, par exemple, plutôt qu'un arbitraire 80/20 partout.

### Domaines candidats, pas rôles exclusifs

| Domaine | Situations qu'il travaille | Offense et utilité possibles |
|---|---|---|
| Nuit | Marques, blessures, effets attachés à une cible | Exécution, contrôle en consommant une marque, transfert conditionnel |
| Eau | Surfaces et circulation des effets | Impact de zone, ralentissement, acheminement d'une marque |
| Feu | Effets différés et leur déclenchement | Brûlure, conversion en zone, menace qui fait quitter une position |
| Terre | Protection accumulée et engagements de position | Garde, contre, sacrifice de protection pour attaquer |
| Vent | Géométrie, accès, déplacement réussi | Tir après mouvement, attraction, déplacement d'une cible dans un piège |

Ce sont des territoires de conception qui se recoupent. Feu ne signifie pas
« tous les dégâts », Terre ne signifie pas « aucun sort offensif ». Les appellations
peuvent évoluer avec l'univers. **Le Soleil est réservé** : le catalogue ne démontre
pas encore une sixième identité ni les sorts normaux nécessaires pour la jouer.
Passer de cinq à six domaines porte les paires possibles de dix à quinze ; il
n'est pas nécessaire de toutes les remplir, mais chacune promise demande du contenu.

### Investissement proposé pour les essais

Budget de départ de six points : 6/0, 3/3 ou 4/2 donnent immédiatement des
orientations différentes. Bonus laboratoire : `1 + 0,04 × maîtrise` pour chaque
composante concernée. Une transformation hybride de base demande 3 dans chaque
domaine ; les cartes restent utilisables sans cette transformation.

Ce seuil évite qu'un unique point acheté pour l'accès soit suffisant. Il ne prouve
pas à lui seul que l'hybride est équilibré. Un second essai à 8 % mesure la sensibilité
des exemples. Les valeurs 4 % et 8 % ne sont pas des recommandations de balance finale.

Pour la progression, une hypothèse est six points supplémentaires aux niveaux
2/4/6/8/10/12, plafond huit par domaine, variantes approfondies à 6 dans un domaine
ou 5/5. À douze points, 8/4, 6/6 et 4/4/4 produiraient des accès différents. Cette
progression reste à simuler : le tricouleur pourrait gagner trop de polyvalence.
Elle remplace un budget existant, elle ne doit pas empiler gratuitement six nouveaux
bonus par-dessus Power/Vitality/Resolve. PV de niveau et équipements restent à
rééquilibrer si ce remplacement est retenu.

Une seule variante est choisie par lancement. Pas de nouveau quota global de
« réaction par tour » à ce stade : quatre PA, le coût des copies et la limite d'une
famille par tour existent déjà. Nous n'ajouterons une limite qu'après avoir identifié
une boucle concrète. Une valeur transférée garde sa puissance initiale : elle ne
repasse pas dans un multiplicateur à chaque changement de support.

## 4. Trois lignées concrètes

Toutes les règles ci-dessous sont **proposées**, sauf les effets normaux des sorts
et les interactions de terrain explicitement identifiées comme existantes.

### Eau/Nuit : déplacer une menace déjà préparée

**Préparer** avec Ouvrir la garde, Sceau ombreux ou Repérage. **Exploiter** avec
Frapper la faille, Résonance du sceau ou, pour le contrôle, Sommeil marqué.
**Transformer** avec une variante d'Onde du Léthé.

Onde normale garde ses dégâts Eau et son eau. À Eau 3 / Nuit 3, sa variante permet
de sélectionner une cible marquée touchée par l'onde et une case d'eau vide de sa
zone. Elle retire la marque **avant les dégâts**, renonçant donc au bonus sur cette
cible, et dépose sa valeur sur cette case après résolution de l'onde. Le premier
ennemi sans marque qui entre sur la case ou y commence une activation reçoit cette marque.

Règles de conservation : un seul dépôt par héros ; aucune duplication ; valeur
inchangée. Le **dépôt non récupéré** expire à la fin de la prochaine phase ennemie,
ou avant si la marque initiale expire ; il disparaît si l'eau disparaît. Une fois
reçue, la **marque reprend l'échéance initiale**, sans prolongation : une marque
fraîche de deux phases peut donc encore servir au tour suivant. Une marque
ainsi transportée ne peut être déposée une deuxième fois ni activer le Relais de
spécialisation. Le système ne crée aucune copie de sort et ne rend aucun PA.

**Choix tactique :** achever l'ennemi marqué maintenant, ou préserver une marque
qui partirait en surdégâts sur un ennemi presque mort, en espérant en atteindre un
autre. Harpon, permutation et intentions de déplacement changent la fiabilité de
ce pari. Le Relais actuel après une élimination est différent : ce transport n'exige
pas une mort, passe par une case et peut échouer.

Ouvrir coûte 1 PA, Onde 3 : préparation et transport tiennent dans un tour, mais
consomment deux copies. Le finisseur viendra plus tard. Dans un état déjà préparé,
avec P40, maîtrise 3/3, un ennemi A à 6 PV, une marque de 20,16 et un ennemi B
hors de l'onde : tuer A puis frapper B pour 20 enlève 26 PV utiles. Si B récupère
la marque avant cette frappe, le total passe à 46. S'il évite la case, on reste
à 26. C'est une comparaison depuis cet état, pas un rendement de rotation complète.

Contre-exemple : Frapper la faille sur une cible marquée vaut 97 avec Nuit 6,
contre 87 avec Nuit 3 / Eau 3, sans équipement ni passif. À 90 PV, le mono termine
la cible et l'hybride ne la termine pas. Le transport n'est pas un bonus obligatoire
à activer sur toute marque : sur une cible qui survit, on sacrifie de vrais dégâts
immédiats et potentiellement une élimination.

### Feu/Eau : échanger la durée contre une attaque de groupe

L'eau puis Braise tenace produisent **déjà** de la vapeur. La transformation nouvelle,
« Ébullition », conserve l'impact principal mais **supprime la brûlure**. Si la cible
est sur l'eau, elle touche au plus deux autres ennemis adjacents pour 0,30 P Feu
chacun. Les cibles secondaires sont choisies dans l'aperçu avant validation ; la
zone ne choisit pas aléatoirement. Elle exige Feu 3 / Eau 3. Sans eau, la variante
est indisponible, mais Braise normale reste utilisable.

À P40 et 4 % par point, les valeurs sont :

| Utilisation de Braise | Impact principal | Suite | Total brut |
|---|---:|---:|---:|
| Feu 6, normale | 27 | Deux brûlures de 9 | 45 |
| Feu 3 / Eau 3, normale | 25 | Deux brûlures de 8 | 41 |
| Hybride, Ébullition, aucun voisin | 25 | Rien | 25 |
| Hybride, Ébullition, un voisin | 25 | 13 sur le voisin | 38 |
| Hybride, Ébullition, deux voisins | 25 | 13 sur chacun | 51 |

L'hybride peut gagner en groupe et perdre nettement sur une cible isolée. Il obtient
les dégâts secondaires immédiatement, mais abandonne la durée. Le Feu pur pourrait
aussi choisir une variante propre : remplacer les deux brûlures de 0,18 P par une
seule de 0,32 P. Ici, 16 au prochain déclenchement contre 18 sur deux : moins de
dégâts totaux, résolution plus rapide. La profondeur qualitative ne doit pas être
réservée aux seuls hybrides.

**Le coût de l'eau compte.** Avec Onde actuelle puis Braise, il faut cinq PA,
deux copies et au moins deux tours. Sur trois ennemis qui restent dans les bonnes
positions et survivent à l'onde, le mono Feu fait 99 au total et l'hybride Ébullition
111. Ce cas favorable suppose que les trois ennemis prennent l'onde et que deux
restent adjacents à la cible de Braise. Si les ennemis se dispersent, si l'eau
disparaît ou si les dégâts sont des surdégâts, ce gain théorique ne suffit plus.
Ce n'est pas une preuve de supériorité sur deux attaques choisies autrement.

### Terre/Feu : transformer une protection en menace évitable

Lignée proposée autour de Garde ferme, Heurt du rempart, Braise et Bûcher, avec
Répercussion comme option rare, jamais comme pièce obligatoire du moteur.

À Terre 3 / Feu 3, une variante de **Heurt du rempart** garde son coût de 2 PA,
remplace son impact normal avec garde (`1,0 + 0,5 P`) par `0,6 P Terre` et permet de
sacrifier une quantité entière de garde S. Le plafond est `arrondi(0,5 P × (1 +
0,04 × rang Feu))` dans le premier essai, sans dépasser la garde réellement disponible. L'effet place une explosion
télégraphiée en croix sur la case ciblée, déclenchée à la fin de la prochaine phase
ennemie, pour `arrondi(1,5 S)` par occupant, **héros compris**.

La garde est perdue immédiatement. Pas de second multiplicateur sur S : la Terre
améliore sa production, le Feu règle la capacité de conversion. Une seule explosion
de ce type peut être en attente par héros ; la variante est indisponible tant qu'elle
n'a pas résolu. L'ennemi peut quitter la croix, le héros peut y être repoussé. La
croix annoncée ne doit ni obstruer les autres intentions ni être confondue avec
une surface de feu continue.

À P40 et 3/3, Garde ferme fournit 52, la conversion maximale dépense 22 et laisse
30. L'impact vaut 27, puis l'explosion 33 par occupant. Avec zéro, un ou deux ennemis
encore présents, cela donne 27, 60 ou 93 dégâts bruts, contre 67 pour Heurt normal
avec le même profil. Le mono Terre 6 fait 74 avec Heurt normal et conserve sa garde.
Garde ferme puis Heurt coûtent quatre PA et deux copies. La prise de risque défensive
et le délai ne doivent pas disparaître sous un multiplicateur supplémentaire.

Cette troisième lignée a le plus grand coût de production : nouvelle intention de
terrain, comportement ennemi, ciblage et sauvegarde du délai. Elle est une hypothèse
de prototype plus incertaine que les deux autres, pas une fonctionnalité prête.

## 5. Le véritable problème des cartes consommables : disposer des fonctions

Résultats exacts, vérifiés par énumération des mains de cinq parmi quinze :

| Stock préparé | Chance d'avoir les deux fonctions en main initiale |
|---|---:|
| Une copie du préparateur, une du consommateur | 9,52 % |
| Trois copies de chaque sort | 51,45 % |
| Préparateur choisi en ouverture, trois consommateurs | 67,03 % |
| Deux préparateurs différents × 3 copies et deux consommateurs × 3 | 91,61 % |

Dans la dernière ligne, les deux fonctions sont supposées disjointes et compatibles.
Ce calcul n'assure ni la portée, ni les PA, ni la présence d'une cible convenable.
Il prouve seulement pourquoi une lignée doit proposer des outils substituables,
avec des coûts, zones et usages différents, plutôt qu'un unique couple de cartes.

Le catalogue actuel dispose de plusieurs préparateurs de marques. En revanche,
Onde est le seul normal qui pose de l'eau ; un ralentissement n'est pas une flaque.
Le Feu n'a que Braise en normal. Avant de promettre ces builds, il faut donc :

- Une deuxième préparation d'eau normale, conçue avec un autre coût ou une autre
  géométrie. La rendre moins chère changerait fortement les résultats précédents.
- Des alternatives normales de préparation et d'exploitation du Feu, notamment
  une manière d'accélérer une brûlure en renonçant à une partie de son total.
- Un second chemin Eau/Nuit qui ne dépende pas exclusivement d'Onde.
- Un départ et un réapprovisionnement permettant de choisir ces fonctions même
  lorsqu'elles appartiennent aujourd'hui à une autre classe.

Ce contenu reste à dessiner ; compter une future carte comme déjà disponible
fausserait l'audit. Les effets rares doivent enrichir la lignée, pas l'activer enfin.

## 6. Lisibilité et critères de réussite

Une fiche affiche d'abord les résultats pour le personnage : dégâts, protection,
cible et durée. Ensuite : « Normal » / « Transformer », condition exacte et effet
abandonné. Les calculs détaillés et contributions des maîtrises restent consultables.
Pour Ébullition : « 25 sur la cible ; 13 sur deux voisins ; ne brûle plus », puis
« nécessite de l'eau ». Pour un transfert : la case, la valeur stockée et l'expiration
sont visibles avant de valider.

Le même aperçu doit annoncer les morts évitées ou perdues, la garde restante et
les alliés ou le héros touchés par une zone. Pas de bonus secret déclenché après clic.

Un système mérite d'être conservé si le même joueur change rationnellement de
variante selon les intentions ennemies, s'il existe plusieurs manières accessibles
de préparer une fonction et si l'on peut expliquer pourquoi on renonce à un effet.
Il échoue si « activer la réaction » est toujours meilleur, si le mono n'a que des
chiffres, si le tricouleur remplace toutes les spécialisations ou si les bonnes
cartes restent trop rares pour qu'un build existe pendant la traversée.

L'audit et les calculs établissent des conditions de conception et quelques
contre-exemples utiles. Ils ne prouvent ni l'équilibre des classes, ni le plaisir
de jeu, ni la fiabilité d'une future intégration.
