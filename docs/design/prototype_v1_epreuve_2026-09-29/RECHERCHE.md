# Recherche : décisions vérifiables et transfert à Dungeon Draft

Sources consultées le 29 septembre 2026. On distingue les intentions historiques
des développeurs, les règles documentées et nos propositions. Aucun client externe
n'a été piloté pour cette étude ; les combats exécutés sont ceux de Dungeon Draft.

## Waven : vérifier l'utilité de chaque couche de progression

Dans la communication du 5 août 2025, les développeurs annoncent quatre sorts
propres au héros, un passif et un ensemble de sorts partagés. Ils expliquent aussi
vouloir retirer des couches d'investissement dont les choix convergent trop vers
des solutions dominantes, ainsi que réduire les effets minuscules sensibles à
l'ordre de déclenchement. Le billet présente une refonte projetée : il ne prouve
pas que toutes ses règles sont celles du client actuel.
[Communication officielle Waven, « Community Update #2 »](https://steamcommunity.com/app/2343650/allnews/?l=english).

Notre décision : garder classe et catalogue partagé, mais demander une fonction
mesurable à chaque axe ajouté. Un attribut « tous effets +X % » ne segmente pas
les choix. Une couleur ne suffit pas non plus : elle doit rencontrer suffisamment
de cartes disponibles. Le test se fait sur le personnage entier, copies épuisées
comprises, et non sur une rotation idéale avec tous les objets réunis.

## Dofus : ouvrir les éléments implique de revoir les bases

Le devblog Ankama de 2015 justifie l'uniformisation des paliers par l'accès plus
équitable aux voies élémentaires entre classes. Il associe cette modification à
des retouches de dégâts : changer les caractéristiques sans vérifier les bases
ne conserve pas l'équilibre. Texte de développeurs reproduit par JeuxOnLine,
l'ancienne page officielle n'ayant pas livré son corps à l'outil de consultation.
[Devblog 2.30 reproduit](https://dofus.jeuxonline.info/actualite/48710/mise-jour-230-uniformisation-paliers-caracteristiques).

Notre décision : une même maîtrise est accessible aux quatre classes ; leurs
portées, conditions, passifs et cartes les distinguent. Le calcul exact des paliers
montre que 80/20 favorise actuellement 26/0. Nous ne renommons pas ce résultat
« hybride équilibré » et ne prétendons pas reproduire les paliers du Dofus actuel.

## Wakfu : un budget d'objet et des plafonds explicites

Le devblog de Zeorus du 30 septembre 2013 expose des budgets selon type, niveau et
rareté, ainsi que des caps de caractéristiques. Il explique comment des bonus de
panoplie hors budget pouvaient rendre des ensembles incontournables. Pour le
multiélément, il distingue également plafond de bonus et coût de couverture.
C'est une méthode de conception historique, pas une table de valeurs actuelle.
[Devblog Wakfu reproduit intégralement](https://wakfu.jeuxonline.info/actualite/41761/devblog-refonte-objets-65).

Notre décision : comparer d'abord les sceaux dans le même emplacement. Les candidats
+8/+8 élargissent la couverture sans battre le +12 mono sur sa spécialité. Les
bonus déclenchés de reliques doivent aussi avoir un budget et une limite ; les
donner gratuitement hors comparaison fausserait tous les prix d'équipement.

## Divinity: Original Sin 2 : résistance au contrôle et barrière de dégâts

Le manuel officiel décrit deux réserves d'armure protégeant les PV et empêchant
les statuts physiques ou magiques correspondants tant qu'elles subsistent. Il
présente aussi les interactions avec les surfaces et l'environnement.
[Manuel officiel hébergé par Xbox](https://dlassets-ssl.xboxlive.com/public/content/6778dff3-8d6c-4615-a8a3-1f1770057d09/GameManual/9e540603-b9bb-44a0-83cd-bb98f1d40b32/nb-NO/index.html).

Notre décision : reprendre l'idée d'une protection lisible avant de dépenser une
action, mais pas ajouter deux réserves qui bloqueraient entièrement nos cartes
consommables. Appui stable et Peau ventilée sont des résistances déterministes,
limitées et annoncées. Elles ne suppriment pas silencieusement un investissement.

## Grim Dawn : provenance, conversions et ordre du calcul

Le guide officiel distingue dégâts ajoutés et bonus en pourcentage, décrit les
dégâts périodiques et précise les règles de certains renvois convertis en attaque.
Il expose également l'ordre de plusieurs défenses. Cela illustre pourquoi une
valeur dérivée ne doit pas subir arbitrairement tous les multiplicateurs d'une
attaque ordinaire.
[Guide officiel du combat](https://www.grimdawn.com/guide/gameplay/combat/).

Notre décision : identifier les composantes originales, capturées et dérivées.
La garde convertie et la Marque déjà calculée ne reprennent pas une deuxième fois
les maîtrises. Il faut tester leur provenance autant que leur chiffre. Nous ne
copions ni l'ensemble des types de dégâts ni les nombreux étages défensifs d'un ARPG.

## Matrice des choix du prototype

Les nombres ci-dessous sont les nôtres. Les références précédentes éclairent les
compromis ; elles ne valident pas expérimentalement nos coefficients.

| Choix actuel | Ce que l'audit peut établir | Décision proposée |
|---|---|---|
| 12 niveaux, victoire = niveau | Cadence fixe, pas de farming d'invocations | Conserver pour isoler les autres changements |
| Courbe P spécifique au héros | Croissance irrégulière, notamment 66→82 puis 82→86 | Examiner ces paliers sur leurs rencontres ; pas de lissage aveugle |
| 26 points, six éléments | 80/20 a pour optimum 26/0 ; 50/50 a plusieurs optima | Conserver provisoirement, mieux décrire et fournir les répertoires |
| Toutes classes/tous éléments | Le catalogue et l'attaque permanente restent des contraintes | Compléter les voies puis tester l'inflexion explicite |
| Aptitudes séparées | Évite de payer PV avec le même budget que l'élément | Conserver ; comparer survie réelle et dégâts, pas leurs seuls % |
| Contact à 1, Distance à ≥3 | Distance 2 exclue des deux | L'afficher dans l'aperçu, tester cette zone tactique |
| Spécialisation au niveau 4 | Arrive avant la salle élite testée | Conserver ; ne pas confondre ses bonus avec la maîtrise |
| Perfectionnements 4/8/12 | Affectent aussi les copies futures | Conserver ; mesurer valeur attendue selon stock et butin |
| Corrections aux haltes | Autorise adaptation sans changement avant chaque coup | Conserver ; instrumenter les corrections réellement utilisées |
| PA/PM/main sans croissance automatique | Préserve le coût d'action | Conserver ; soumettre toute relique de PA à un test de boucle |
| Cartes consommées pour la run | Le ratio dégâts/PA ne mesure pas leur prix réel | Ajouter systématiquement dégâts/copie et délai |
| Une famille par tour | Deux copies ne doublent pas instantanément le rendement | Garder dans tous les simulateurs et comparaisons |
| Rareté | Accès et stock changent le nombre d'usages | Pas de multiplicateur universel de rareté |
| Pondérations par composante | Peuvent différencier attaque et garde sur une même carte | Favoriser quelques cartes à composantes distinctes |
| Butin 70 % natif/commun | Ignore les maîtrises investies | Tester une offre ciblée de trois choix, pas un butin automatique parfait |
| Équipement tiré parmi les définitions | 6/14 équipements précoces sont des amulettes élémentaires | Donner des poids aux slots/familles avant d'ajouter des objets |
| Défense physique/magique | Ne représente pas les six maîtrises | Tester une petite extension additive à plafond commun |
| Résistance aux effets | Les règles sont aujourd'hui propres à certains ennemis/boss | Codifier familles et règles visibles, sans jets d'échec cachés |
| Rafraîchissement des statuts | Maximum de puissance et maximum de durée combinés | Tester la conservation d'une application entière |
| Reliques et dérivés | Risque de double calcul ou récursion lors des ajouts | Provenance, ordre, limite et exclusions obligatoires |
| Pression après le tour 8 | Rend coûteuse une stratégie de sauvegarde illimitée | Garder comme contrainte de test, ne pas conclure sur des combats tronqués |

## Recherche encore nécessaire avant un rééquilibrage global

La campagne jointe n'est ni une mesure de taux de victoire humain, ni une traversée
continue de douze combats. Il reste à tester les choix de préparation, les achats,
la continuité des stocks et les rencontres tardives sur plusieurs graines. Un
nombre de messages de forum, une build optimisée ou une intention de développeur
ne remplaceraient pas ces observations propres à notre jeu.
