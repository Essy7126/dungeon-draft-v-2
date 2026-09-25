# 3 — Run, combat tactique, équilibre et méthode d'évolution

[Sources](SOURCES.md) · [Calculs](MATH_RESULTS.md) · [Vue d'ensemble](README.md). Les principes ci-dessous sont des hypothèses argumentées à éprouver dans Catabase.

## 3.1 Pourquoi les mêmes motifs reviennent dans les jeux

Les systèmes codifiés répondent à des contraintes communes : peu de temps d'attention, besoin de comprendre une conséquence, différence entre débutant et expert, gestion de la chance, croissance de puissance et renouvellement des situations. Copier leur forme ne reproduit pas leur fonction.

| Motif | Quand il construit du jeu | Quand il se dégrade | Application à notre concept |
|---|---|---|---|
| Synergie | Plusieurs outils simples permettent de préparer une situation | Une pièce obligatoire manque et les autres deviennent mortes | Normales pour amorcer chaque boucle ; rares pour élargir ses possibilités |
| Contrepartie | Le gain change selon le terrain, le temps restant ou l'adversaire | La contrepartie n'affecte jamais le build qui la choisit | Vérifier le coût effectivement payé, pas seulement le texte |
| Hasard | Oblige à adapter une stratégie encore viable | Empêche de jouer avant une décision significative | Variance basse pour l'approvisionnement, haute pour les exceptions |
| Plafond | Empêche une règle de supprimer toutes les contraintes | Toutes les constructions deviennent identiques au plafond | Borner PA/contrôle, diversifier les usages à l'intérieur |
| Montée en puissance | Permet de résoudre différemment un problème appris | Ennemi et héros montent ensemble sans changer les décisions | Débloquer options et rencontres, pas seulement nombres |
| Rareté | Rend une découverte mémorable | Rend un build ou un travail de contenu presque inaccessible | Simuler la probabilité par run avant de produire le contenu |
| Préparation | Permet d'anticiper des menaces lisibles | Devient une corvée de tri après chaque combat | Informations de route, piles et presets avec aperçu |
| Méta-progression | Ouvre des styles et nourrit l'apprentissage | Rend les premières runs volontairement sous-équipées | Comparer nouveaux joueurs et profils expérimentés sans confondre leur puissance |

Ce tableau est une synthèse de conception, pas une affirmation qu'il existe un consensus scientifique unique sur le plaisir.

## 3.2 L'évolution d'une classe : Xélor, exemple précis

Le devblog Xélor de novembre 2014 décrit un rôle devenu trop dépendant du retrait massif de PA : répétitif pour son utilisateur, frustrant pour la cible, difficile à régler entre monstres et joueurs. La refonte annoncée renforce le placement temporel et les combos. Téléportation devient symétrique autour d'une cible ; Fuite reporte le retour à une position précédente ; Flou retire deux PA puis les rend au tour suivant. L'ambition est de garder un usage simple tout en ouvrant des séquences expertes. Ce sont des mécanismes historiques, pas les valeurs actuelles de la classe. [S21 — texte de Briss reproduit](https://dofus.jeuxonline.info/actualite/46528/refonte-classe-xelor-annoncee).

Notre inférence : une classe intéressante peut modifier **la manière de lire le plateau**, plutôt que posséder un coefficient supérieur. Une symétrie, une position mémorisée ou une dette de PA fait penser au tour suivant. Pour notre deck consommable, il faut toutefois éviter un combo obligatoire de trois cartes rares : la préparation doit pouvoir fonctionner avec un seul outil fréquent et plusieurs suites possibles.

Proposition de carte à tester, non reprise telle quelle de DOFUS : **Ancrage**, normale, 1 PA, portée 1–3. Marque une case libre ; jusqu'à la fin du prochain tour, une poussée qui y termine donne une petite garde à Achille, une seule fois. Elle récompense la planification sans supprimer l'activation ennemie ni créer de copie. Variante rare : déplacer l'ancre après sa pose au prix d'un PA. Le chiffrage de la garde dépendra de la progression réelle.

## 3.3 Contrôler sans empêcher systématiquement de jouer

La valeur d'un retrait de PA dépend du coût des attaques adverses. Retirer un PA à une cible qui en a trois et attaque pour trois peut supprimer tout son tour offensif ; à une cible qui en a six et attaque pour deux, l'effet est différent. Mesurer les **actions réellement empêchées**, pas seulement le chiffre du statut.

Le dépôt possède déjà une protection spécifique : la stase exige une cible marquée, fait passer sa prochaine activation, puis protège contre la stase pendant trois activations ; Pâris perd seulement un PA, avec une recharge annoncée de quatre activations. C'est un élément existant à préserver et tester, pas un manque à combler. [Définition des sorts](../../../../core/expedition/class_card_catalog.gd).

Le changement de modèle demande quand même de vérifier les limites entre familles, copies, reliques et terrains. Une consommation par exemplaire n'empêche pas d'alterner plusieurs sources de contrôle. Définir les protections par **catégorie d'effet sur la cible**, avec durée visible, plutôt que seulement par identifiant de carte.

Nick Pechenin annonce pour le prochain Divinity l'abandon de l'armure magique de DOS2 comme préalable à l'emploi de certains outils, tout en cherchant une autre protection contre le blocage des boss. C'est une intention, pas une solution dont nous connaissons déjà les résultats. [S17 — AMA Larian](https://www.reddit.com/r/Games/comments/1q870w5/larian_studios_divinity_ama/).

Application possible : les contrôles modestes restent utilisables immédiatement ; les interruptions complètes ont une résistance temporaire annoncée. Un boss peut subir un effet réduit mais réel. Éviter une immunité générique qui annule tout un archétype de cartes sans compensation ni préavis.

## 3.4 Lisibilité : laisser la profondeur dans les décisions

Into the Breach a construit son combat autour d'intentions ennemies visibles, de conséquences déterministes pendant l'action du joueur et d'un plateau où déplacer peut être aussi important que tuer. Son postmortem raconte aussi des couches stratégiques abandonnées car elles ajoutaient de la complexité sans assez de décisions intéressantes. [S15 — GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf).

Pour Catabase, l'information utile avant de consommer une carte est : cible et cases touchées ; dégâts après protections connues ; déplacement final ; danger de fin de tour ; durée exacte des statuts ; exceptions de boss ; exemplaire définitivement perdu. Les descriptions peuvent rester courtes si ces conséquences sont prévisualisées.

L'analyse de Magic distingue notamment compréhension du texte et complexité du plateau : une carte simple peut demander de nombreuses vérifications une fois combinée aux autres. Notre critère de normale : un verbe principal, au plus une condition immédiatement visible, pas de suivi de trois compteurs invisibles. [S10 — New World Order](https://magic.wizards.com/en/news/making-magic/new-world-order-2011-12-05).

Dans sa communication d'août 2025, WAVEN présente une refonte vers quatre sorts propres et un passif par héros, un pool partagé, seize cartes au deck et neuf en main. Le studio annonce aussi retirer équipements et fiche de compétences, jugeant l'empilement peu lisible. Il précise que ces décisions peuvent encore changer. Le point transférable est l'audit de la fonction de chaque couche ; il ne nous impose ni ces tailles ni ces suppressions. [S18 — Community Update #2](https://steamcommunity.com/app/2343650/announcements/?l=french).

Augmenter notre main de quatre à neuf serait un gros changement : plus de réponses, mais aussi plus de combinaisons à évaluer. Tester d'abord quatre puis cinq avec le même catalogue et des rencontres identiques. Ne pas « corriger » une dilution par trente cartes avec une main énorme sans mesurer le temps de décision.

## 3.5 Notre meilleur point d'appui : les salles tactiques existantes

Le [catalogue de salles](../../../../core/expedition/card_tactical_room_catalog.gd) propose déjà cinq règles qui changent l'usage des cartes :

| Salle | Règle définie dans le catalogue | Ce qu'elle permet de mesurer |
|---|---|---|
| Forge | Presse annoncée, rail modifiable pour 1 PA ; dégâts différents héros/ennemis | Une poussée peut économiser plusieurs cartes de dégâts |
| Jardin | Anneau dangereux centré sur un chef déplaçable | Position de la source, pas seulement position du joueur |
| Convoi | Porteurs qui alimentent le chef ; sceau qui change leur comportement | Cible prioritaire et choix entre urgence et économie |
| Sablier | Croix fixe retardable une fois, mais plus puissante | Une dette de danger contre un tour supplémentaire |
| Réservoirs | PA non dépensés stockés près d'un objectif ; ennemis capables de voler les charges | Transformer une main peu adaptée en préparation spatiale |

Il serait redondant de proposer « ajouter des interactions de terrain » comme si elles n'existaient pas. La vraie question est leur place dans la courbe de run, la compréhension par le joueur et leur rendement en exemplaires économisés. Les valeurs fixes des machines demandent aussi une comparaison aux PV par profondeur.

Un même budget de PV de groupe peut donner des combats très différents : quatre petites cibles, deux cibles robustes, un chef avec alimentation. Le [catalogue d'ennemis](../../../../core/expedition/catabase_monster_encounter_catalog.gd) construit déjà les PV de groupe à partir d'une Prouesse de référence et de poids par rencontre, puis les répartit selon les rôles. Ce contrat est utile pour comparer la pression, mais ne capture pas à lui seul portée, nombre d'activations, obstacles ou synergies ennemies.

Recommander une matrice de rencontres : corps à corps nombreux, tireurs derrière obstacles, protecteur à contourner, menace différée, adversaire isolé robuste. Chaque rôle de carte fréquent doit avoir au moins une occasion d'être bon sans que le jeu lui impose systématiquement son contre.

## 3.6 Éviter la domination des gestes de secours

Le produit Cartes possède deux gestes hors pioche. Leur maintien est une hypothèse raisonnable pour éviter un blocage total, mais leur rendement est central : avec des cartes consommables, le joueur peut être incité à tuer lentement avec ces gestes pour accumuler des drops.

Un bon secours autorise une réponse médiocre ; un mauvais secours rend optimal de ne pas utiliser le système principal. Un ennemi lent qu'on peut contourner indéfiniment peut devenir une source presque gratuite de sacs.

Tester trois attitudes : dépense libre ; conservation stricte ; stratégie mixte. Observer tours supplémentaires, PV perdus, stock final et plaisir déclaré. Si conserver est toujours supérieur, corriger d'abord les rencontres et le rendement des gestes. Des objectifs temporisés, des adversaires qui ferment progressivement l'espace ou une pression croissante annoncée peuvent donner un coût au délai. Ne pas ajouter un bonus de drop pour vitesse à la base : cela punirait potentiellement les classes lentes et changerait la consigne utilisateur.

## 3.7 Construction de run : préparer, dépenser, réorienter

La route publique comporte vingt profondeurs et douze combats, trois refuges plus un arrêt avant le boss. Une boutique précoce est une possibilité de branche, pas un passage garanti dans toutes les simulations. La run de référence gagne sa spécialisation après le troisième combat. [Route](../../../../core/expedition/catabase_route_v6.gd), [progression calculée](MATH_RESULTS.md).

Proposition de rythme, sans déplacer automatiquement les nœuds existants :

| Période | Apprentissage / décision | Risque à surveiller |
|---|---|---|
| Combats 1–3 | Comprendre consommation, premier sac et boucle de classe | Pénurie avant qu'un choix de build soit possible |
| Combats 4–6 | Choisir spécialisation, tester déplacement/terrain, atteindre un refuge | Premier pic ennemi et plusieurs nouveaux menus simultanés |
| Combats 7–9 | Réorienter la réserve, trouver une variante de synergie | Inflation de normales et tri trop fréquent |
| Combats 10–12 | Dépenser ce qui a été préparé, anticiper le boss | Thésauriser des rares jusqu'à la défaite ou au générique |

Prévoir une information de route : danger dominant, famille de butin, accès commercial, règle exceptionnelle. Montrer une promesse fiable, sans révéler chaque tirage. Monster Train a notamment annoncé la visibilité anticipée des boss des anneaux 3 et 6 dans Friends & Foes : une information en amont permet de préparer une réponse. [S12 — historique](https://store.steampowered.com/news/posts/?appids=1102190&enddate=1602708373&feed=steam_community_announcements).

La branche ne devrait pas avoir une valeur dominante sur tous les axes. Plus de mobs peut apporter plus de sacs mais aussi plus de dépenses et de blessures. Évaluer la richesse **nette** attendue, et pas simplement le nombre de jets.

## 3.8 Difficulté : changer la décision avant de gonfler les PV

Balatro 1.0.1f a remplacé deux contraintes de difficulté : hausse du coût des packs par des Jokers périssables, réduction de taille de main par des Jokers locatifs. Ces derniers coûtent peu au départ puis demandent un entretien ; les périssables s'éteignent après cinq manches. Le patch ajuste aussi les courbes d'ante et garantit un pack de Jokers à la première boutique. [S13 — LocalThunk](https://www.reddit.com/r/balatro/comments/1chqrqg/101f_patch_is_live_on_steam/).

Notre application : des variantes difficiles pourraient changer le moment de dépenser ou la préparation — stock marchand plus spécialisé, objectif secondaire risqué, règle de salle combinée — une fois la base stable. Ne pas copier un entretien permanent sur toutes les cartes : leur consommation constitue déjà un coût temporel.

Baldur's Gate 3 a ajouté les modes Honneur et Personnalisé dans le patch 5 ; le même changelog empêche notamment de pousser la guenaude dans un gouffre en Tacticien. Cela illustre une décision explicite de préserver une rencontre au prix d'une interaction. [S16 — patch 5](https://baldursgate3.game/news/patch-5-now-live_99).

Chez nous, réserver les exceptions nécessaires à des menaces identifiables et les expliquer avant la dépense d'une carte. Une immunité surprise peut détruire à la fois le plan tactique et une ressource irréversible.

## 3.9 Équilibrer la disponibilité et la puissance séparément

Le patch Hades du 1er décembre 2020 touche par exemple les prérequis de Sea Storm, la durée du bonus d'Eris et la progression de plusieurs bénédictions. Accès, durée et amplification sont des leviers différents. [S14 — notes officielles](https://www.supergiantgames.com/blog/hades-updates/).

Si une carte Catabase est peu jouée, suivre le chemin complet : pouvait-elle tomber ? est-elle tombée ? a-t-elle été gardée ? équipée ? piochée ? une cible adéquate existait-elle ? a-t-elle été jouée ? Chaque étape a son dénominateur. Augmenter ses dégâts parce qu'elle est rarement jouée peut créer un monstre de puissance lorsque sa condition est enfin satisfaite.

Pour une carte apparemment trop forte, distinguer rendement individuel et moteur de combinaison. Si elle est le seul pont vers un archétype sous-alimenté, la réduire sans ajouter un autre accès peut supprimer l'archétype. Si elle supprime les contraintes de toutes les classes, elle peut être trop structurante même avec un taux de victoire moyen modeste.

## 3.10 Données : mesurer sans se tromper de conclusion

La présentation de Slay the Spire insiste sur itérations, retours actifs, observation et segmentation par ascension ; les données sont des preuves à interpréter, pas une conclusion automatique. [S11 — GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

Proposition de journal minimal, sans données personnelles nécessaires :

| Événement | Champs utiles |
|---|---|
| Début de run | Version des règles, graine, classe, difficulté, profil de test |
| Préparation | Deck par famille/copies, réserve, or, équipements, maîtrises |
| Tirage | Ennemi et canal éligibles, probabilités utilisées, sac, familles, exemplaires |
| Tour | PA/PM disponibles et dépensés, main, cartes jouées, gestes de secours |
| Résolution | Dégâts réellement infligés, surdégâts, garde absorbée, déplacement, actions empêchées |
| Fin de combat | PV, stock, durée, tours, achats ultérieurs, première pénurie éventuelle |
| Fin de run | Victoire/défaite/abandon, cause, rares non jouées, solde, moment de dernière réorientation |

Ne pas déduire d'un état final que le joueur « aurait dû » jouer une rare. Il peut avoir conservé rationnellement une réponse au boss. Poser au testeur une question en contexte et conserver l'enregistrement de sa situation.

Biais à traiter :

* **Survivants :** les stocks finaux du laboratoire ne décrivent que les parcours financés. Ceux qui tombent à zéro ont disparu de cette distribution.
* **Acquisition tardive :** une carte présente surtout chez les survivants peut sembler améliorer les victoires sans les causer.
* **Choix des experts :** les bons joueurs peuvent préférer une carte difficile ; son taux de victoire brut ne suffit pas.
* **Raretés extrêmes :** vingt mille runs donnent seulement environ vingt-huit occurrences attendues d'Immortel ; ce n'est pas une validation de son équilibre.
* **Longueur de run :** rapporter aussi par combat atteint et par minute, pas seulement par run lancée.

## 3.11 Protocole concret pour la prochaine étape

**A — Règles et calculs.** Valider consommation, reçus, éligibilité des mobs, inventaire/réserve, monotonie, impossibilité de dupliquer par rechargement, absence de cycle économique positif. Fixer les tables et leur version avant de comparer.

**B — Tests de combat ciblés.** Même équipement et mêmes rencontres pour quatre classes : nombreuses cibles, tireur inaccessible, chef alimenté, boss, main sans dégâts, trois contrôles en réserve, deck de quinze puis trente. Mesurer cartes dépensées et survie ; tester aussi l'abus des gestes de secours. Utiliser les outils Studio existants si une implémentation est ensuite demandée.

**C — Runs instrumentées.** Plusieurs graines, classes et politiques de dépense ; comparer uniquement une modification de système à la fois. Les différences de tirages doivent être enregistrées : réutiliser une graine ne garantit pas un parcours identique lorsque l'ordre des appels aléatoires change.

**D — Observation humaine exploratoire.** Commencer par quelques nouveaux joueurs et quelques habitués du genre, sur plusieurs classes. Douze à vingt personnes peuvent révéler des problèmes de compréhension ; cet échantillon ne mesure pas une rétention ou un taux de victoire populationnel précis. Demander ce qu'ils anticipent avant de dépenser, pourquoi ils refusent un drop et ce qu'ils changeraient après une défaite.

**E — Révision.** Modifier d'abord la cause observée : disponibilité, lisibilité, coût, fenêtre de jeu, plafond, puis magnitude. Conserver un journal des hypothèses abandonnées et du motif. Les futures validations moteur, sauvegarde, UI et CI restent obligatoires lorsqu'on touchera au jeu.

## 3.12 Critères d'acceptation proposés

Ce sont des objectifs initiaux à discuter après les premières observations, pas des résultats obtenus :

* Aucune classe ne dépend d'une rare pour montrer sa boucle dans les trois premiers combats.
* Moins de 1 % de pénuries de normales avant le premier refuge dans le modèle avec consommations **mesurées**, puis vérification humaine de leurs causes.
* Une run standard reste terminable sans les trois rangs les plus rares ; vérifier réellement les combats, pas seulement le stock.
* Les gestes de secours ne dominent pas simultanément survie, stock et temps raisonnable de jeu.
* Au moins deux constructions par classe produisent des séquences distinctes ; ne pas compter deux allocations de +dégâts comme deux styles.
* Le joueur sait annoncer le coût définitif d'une carte et expliquer l'effet d'une relique sans lire plusieurs écrans.
* Le temps de tri et la proportion de rares jamais jouées sont suivis ; aucune cible numérique universelle n'est imposée sans observer pourquoi.

L'objectif n'est pas d'égaliser tous les résultats. Il est de faire en sorte que l'adaptation, la préparation et le placement expliquent les différences, et que le joueur puisse les comprendre.
