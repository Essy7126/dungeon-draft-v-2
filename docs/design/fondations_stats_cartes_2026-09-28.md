# Fondations des statistiques et des cartes

28 septembre 2026 — proposition révisée après le recadrage de l'utilisateur.
Conception uniquement : aucun changement de combat ni de sauvegarde.

Suite de la conception : [montée du personnage, enquête et prototype chiffré du 29 septembre](progression_personnage_2026-09-29/README.md).

## Direction corrigée

Construire un vocabulaire commun de statistiques et de cartes, extensible au fil
du contenu. Les builds résultent des sorts disponibles, de leurs coûts, de la
classe, des investissements et de l'équipement. Ils ne sont pas définis à l'avance
par une liste de combinaisons ou de transformations autorisées.

La précédente proposition de variantes conditionnelles est conservée comme
recherche historique, pas comme fondation recommandée. Des réactions particulières
pourront exister sur certains sorts, sans devenir une condition générale de
l'hybridation. Le calcul d'un sort hybride isolé restait correct sous ses hypothèses,
mais ne permettait pas de juger les possibilités d'un répertoire entier.

## 1. Des dimensions distinctes sur les cartes

| Dimension | Question | Valeurs ou représentation | Ce qu'elle ne décide pas |
|---|---|---|---|
| Origine de classe | À quel répertoire appartient le sort ? | Assassin, Gardien, Arpenteur, Thaumaturge, Universelle | Son élément ou sa rareté |
| Affinités élémentaires | Quelles maîtrises renforcent ses composantes ? | Terre, Eau, Feu, Vent, Nuit, Soleil, palette à confirmer | Un rôle ou une rotation obligatoire |
| Fonctions | Quels effets produit-il ? | Attaque, Protection, Soin, Déplacement, Contrôle, Terrain, Pioche | Une catégorie unique pour tout le sort |
| Propriétés d'exécution | Dans quelles conditions ses effets s'appliquent-ils ? | Direct/périodique, cible unique/zone, contact/distance | Une nouvelle statistique pour chaque étiquette |
| Rareté | Quel budget de puissance et quelle disponibilité lui donne-t-on ? | Raretés existantes, de normale à immortelle | Son élément, sa classe ou sa complexité obligatoire |
| Amélioration du sort | Quel perfectionnement a été acquis dans la run ? | Améliorations de famille existantes | Une promotion automatique de rareté |

Le nom « Universelle » évite de confondre origine commune et rareté normale.
La famille technique continue de désigner un même sort et toutes ses copies ;
elle ne devient pas un synonyme de catégorie « Attaque ».

Les fonctions sont multiples : un drain est Attaque **et** Soin ; une frappe qui
repousse est Attaque **et** Contrôle. Les propriétés portent sur les composantes :
une attaque peut comporter un impact direct et des dégâts périodiques.

Contact/distance dépend de la position réelle, pas uniquement de la portée maximale
écrite sur la carte. Cible unique/zone dépend de la géométrie de l'effet, pas du
nombre d'ennemis qu'il a finalement touchés. Ces règles sont définies une fois.

## 2. Un classement des statistiques du personnage

| Groupe affiché | Contenu | Rôle dans la progression |
|---|---|---|
| Ressources | PV, PA, PM, taille de main | Fixer les moyens disponibles ; les gains de PA/PM/main sont peu fréquents |
| Maîtrises élémentaires | Maîtrise Terre, Eau, Feu, Vent, Nuit, Soleil selon la palette retenue | Principal investissement dans un répertoire de sorts |
| Spécialisations | Bonus de contact, distance, protection, soin ; autres dimensions si le contenu les justifie | Différencier équipement et préférences à élément égal |
| Défenses | Garde actuelle, résistances actuellement physique/magique, autres protections définies | Exposer la survie réelle et ses sources |
| Affinité de classe | Éventuel avantage permanent sur les sorts d'origine native | Renforcer la continuité de classe sans verrouiller les emprunts |

La garde actuelle est un état de combat, pas un point d'attribut investi. Les PV
maximaux, les PA, les maîtrises élémentaires et les bonus d'équipement n'ont donc
pas besoin d'être regroupés dans un même compteur de progression.

Les spécialisations ne doivent pas toutes devenir immédiatement des attributs
distribuables. Le contact, la distance, le soin et la protection ont déjà des bases
dans nos équipements. D'autres bonus pourront arriver sur des objets ou passifs
quand il existera assez de sorts concernés. Une étiquette peut servir uniquement
à filtrer ou décrire les cartes, sans créer une jauge supplémentaire.

Cette séparation possède un précédent utile : la documentation communautaire de
Wakfu distingue maîtrises élémentaires et maîtrises conditionnelles, notamment
mêlée et distance. On en retient la séparation des axes, pas les seuils ni l'ensemble
de ses statistiques. [Caractéristiques de Wakfu](https://wakfu.wiki.gg/wiki/Melee_Mastery).

## 3. Les éléments constituent un axe commun à toutes les classes

Une même maîtrise Terre renforce les composantes Terre d'un tir, d'une frappe et
d'une protection si ces composantes lui sont attribuées. Les différences de portée,
de coût, de rendement, de géométrie et de mécanique de classe restent celles des
sorts. Deux personnages Terre peuvent donc choisir des équipements et des cartes
différents. Rien n'impose que toute Terre soit au contact ou que tout Feu soit une
brûlure ; des tendances de contenu restent possibles.

Nuit et Soleil peuvent coexister avec les éléments naturels dans notre univers.
L'inventaire actuel ne doit pas déterminer définitivement la palette : l'absence
de sorts Soleil mesure un travail de contenu à prévoir, elle ne démontre pas que
le domaine est invalide. En revanche, une branche vide ne sera pas présentée comme
un choix complet et disponible avant son arrivée.

Le lien historique Force/Terre/pods évoqué par l'utilisateur illustre une règle
commune réutilisable. Il n'impose pas d'inventer un second effet d'expédition pour
chaque maîtrise dans une run. Les extensions hors combat peuvent être décidées
plus tard, si elles produisent réellement un choix dans nos systèmes existants.

## 4. Effets et calculs partagent un contrat simple

Chaque composante quantitative originale d'un sort déclare sa base et ses poids
élémentaires. Un effet Terre a un poids Terre de 100 %. Un effet mixte peut avoir
plusieurs poids, dont la somme vaut 100 %. Une composante sans élément n'utilise
aucune maîtrise élémentaire.

Point de départ pour la formule, avant défenses et arrondis :

`valeur = base × (1 + somme(poids × bonus élémentaire) + bonus spécialisés applicables)`

Les bonus applicables sont additionnés dans ce premier modèle. On peut ainsi
comparer les équipements sans ajouter un multiplicateur à chaque catégorie.
Dans la formule, poids et bonus sont exprimés en fractions : 40 % s'écrit 0,40.
Exemple de calcul uniquement : base 20, Terre +40 %, contact +20 % donne 32 au
contact, 28 sans le bonus de contact. Ce n'est pas une recommandation de valeurs
d'équipement ou de budget d'attributs.

Cette règle porte sur les composantes, pas sur la carte entière. Elle peut renforcer
des dégâts, un soin ou une quantité de garde lorsque ces effets possèdent une
affinité. Elle ne multiplie pas automatiquement les PA, les cartes piochées, les
cases de déplacement ou la durée d'un contrôle. Le Pas latéral peut donc rester
une action utilitaire sans élément ; « Universelle » et « sans élément » sont deux
propriétés distinctes.

Un effet dérivé d'une quantité déjà calculée conserve son autre contrat : le soin
d'un drain dépend des PV effectivement retirés, une conversion dépend de la garde
effectivement dépensée. On ne réapplique pas silencieusement la maîtrise élémentaire
à la même valeur. Les éventuels bonus de soin ou de conversion sont des politiques
explicites, distinctes du simple fait que la carte porte une icône.

Pour les dégâts différés, la valeur offensive et les bonus admissibles sont fixés
à la création de l'effet ; les défenses de la cible s'appliquent à sa résolution.
Une marque stocke sa valeur une fois. Une amélioration ultérieure d'équipement ne
multiplie pas à nouveau ce qui a déjà été préparé.

Le type physique/magique existant reste un axe de mitigation distinct pendant la
première étape. Son maintien à long terme ou son remplacement par des défenses
élémentaires reste une décision séparée. Éviter de lancer simultanément un système
complet de maîtrises **et** une multiplication des résistances à expliquer.

## 5. Classe et origine des cartes restent utiles après le départ

La classe possède son noyau permanent : attaque de base, passif, spécialisation.
Ce noyau doit donner une identité après consommation des cartes de départ. Un
pool initial différent, seul, ne remplit pas cette fonction.

L'origine de classe des cartes permet également un avantage natif permanent,
indépendant de l'élément. C'est une option recommandée à mesurer : un bonus natif
modéré sur les composantes admissibles encourage la continuité du répertoire,
tout en conservant les emprunts utiles. Sa valeur, son financement et les effets
concernés restent à équilibrer ; il ne doit pas être plus rentable partout que
l'investissement élémentaire, ni amplifier la pioche et les PA par accident.

L'identité ne doit pas reposer uniquement sur ce multiplicateur. Des coûts, portées,
effets et passifs différents font qu'un répertoire de classe utilise autrement le
même élément. La classification n'est qu'un moyen de conserver cette diversité
et d'enrichir les contenus sans changer les règles fondamentales.

## 6. Rareté et sous-catégories aident à construire le contenu

La rareté règle disponibilité et budget de puissance : efficacité, ampleur,
flexibilité ou effet exceptionnel peuvent la justifier. Elle n'est pas un bonus
élémentaire caché ni un multiplicateur ajouté après tous les autres. Une rare
peut être simple et puissante ; une normale peut avoir une bonne interaction.
Une carte de rareté supérieure n'a pas à imposer une nouvelle sous-catégorie.

Les sorts normaux constituent des répertoires jouables. Les rares peuvent les
enrichir sans que chaque orientation dépende obligatoirement d'un tirage exceptionnel.
Il n'est pas nécessaire d'exiger un nombre identique de cartes pour chaque case
Classe × Élément × Fonction × Rareté. Cette matrice sert à identifier les manques,
pas à produire un catalogue artificiellement symétrique.

Les sous-catégories décrivent des propriétés répétables : cible unique/zone,
direct/périodique, attaque/protection, etc. Elles permettent des filtres et des
équipements ciblés. Un ajout ne mérite sa place que s'il s'applique à plusieurs
cartes et reste compréhensible ; on n'ajoute pas une famille de statistiques pour
chaque nouveau sort.

## 7. Ce que l'audit du code permet déjà de réutiliser

- `catalog.json` sépare origine (`affinity`), rareté, opération, type de dégâts,
  géométrie et amélioration. Le champ `affinity` représente la classe, pas un élément.
- `consumable_card_math.gd` additionne déjà certains bonus d'équipement et différencie
  contact, distance et dégâts magiques. Actuellement contact signifie distance 1,
  distance signifie au moins 3 ; à 2, aucun de ces deux bonus. Ne pas changer ce
  seuil implicitement lors de l'ajout de labels.
- `card_player_language.gd` donne un seul rôle à partir de l'opération. Un drain
  devient « Soin » malgré ses dégâts ; un effet mixte gagnerait à conserver plusieurs
  fonctions. Ses mentions visuelles Feu/Givre/Eau ne constituent pas des maîtrises
  réellement présentes dans les règles.
- Les équipements savent déjà modifier contact, distance, soin, garde, PV,
  résistances, portée et main. Ne pas créer une deuxième couche équivalente.
- La rareté possède déjà des probabilités de distribution. Les classifications
  de contenu doivent rejoindre ces services et ceux du Studio.
- Les validateurs contiennent des listes de types et des comptes fixes, dont 48
  sorts. Ajouter des données nécessite aussi de faire évoluer ces contrats.

## 8. Construction progressive

1. Stabiliser ce vocabulaire, le contrat de calcul et les noms des maîtrises. Garder
   ouverts les chiffres de progression et les distributions du contenu.
2. Décrire les composantes des sorts existants sans changer leurs comportements.
   Séparer leurs vrais effets de ce que leur nom ou leur VFX suggère seulement.
3. Introduire les maîtrises et leurs aperçus, puis donner aux classes un noyau
   permanent distinct. Les investissements communs restent accessibles à toutes.
4. Étendre progressivement les sorts et équipements, en utilisant la matrice de
   couverture. Faire évoluer départ et récompenses avec les orientations disponibles.
5. Ajouter ensuite des interactions particulières si elles enrichissent le jeu.
   Elles ne sont ni des prérequis universels ni des rotations prédéfinies.

L'interface peut rester courte : origine, icônes élémentaires, coût, rareté et
résultat chiffré. Les fonctions servent aux filtres ; les propriétés et contributions
statistiques apparaissent dans le détail. Un même code couleur ne doit pas rendre
rareté et élément indiscernables.

Les changements futurs doivent rester dans la run Catabase et ses services,
avec migration explicite des attributs. Cette note ne valide ni la balance, ni
l'intégration : elle fournit le cadre à faire évoluer, sans imposer les builds.
