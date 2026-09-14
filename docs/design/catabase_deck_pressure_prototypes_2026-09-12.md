# Catabase : prototypes de deck, de menace et de conséquences

Proposition du 12 septembre 2026, après retour de playtest : combats trop faciles et décisions trop pauvres. Ce document décrit des expériences à réaliser, pas des fonctionnalités déjà implémentées ni des chiffres validés en jeu. Aucun nouveau personnage nécessaire.

## Diagnostic de la passe précédente

Les 108 victoires automatisées prouvaient que les salles étaient traversables. Elles ne validaient pas leur intérêt. La réduction simultanée de la mobilité, des dégâts, du nombre d'attaques et des effets persistants a trop réduit la menace.

Au niveau 2, les valeurs canoniques sont 135 PV et 22 de Prouesse. Garde coûte 2 PA et donne, avant arrondi et modificateurs, `135 × 0,05 + 22 × 0,25 = 12,25` de bouclier. Le rapport contient des ennemis à 21 PV et 6 d'attaque. Deux petites attaques peuvent donc être absorbées par la seule Garde, et les ennemis risquent de mourir avant d'exprimer leur rôle. L'accès à un tir réutilisable et la différence de mobilité rendent le problème plus marqué.

Sources locales : `data/spells/achilles/bronze_guard.tres`, `data/runs/progression/odyssey/achilles_champion_progression_v0.tres`, `core/expedition/expedition_run_factory.gd`, `artifacts/dev/early_run_playtest/tuned_v2/report.json`. Les gains de PV liés à la progression et aux récompenses doivent être séparés des dégâts reçus dans les prochaines mesures.

**Nouvelle cible : un joueur qui choisit bien doit pouvoir éviter les dégâts ; un joueur qui répète toujours la même séquence doit laisser une menace se réaliser ou perdre une opportunité significative.** Ne pas rendre les dégâts inévitables pour améliorer artificiellement une statistique de difficulté.

## Expérience A : des menaces que le kit actuel oblige à arbitrer

Avant toute pioche, construire trois combats au niveau 2 avec les mêmes ressources du héros. Chiffres de départ à tester, exprimés en PV et dégâts finaux attendus ; la valeur `attack_power` ne suffit pas si le sort applique un coefficient.

| Rôle existant | PV proposés | Menace à tester | Fragilité exploitable |
|---|---:|---|---|
| Archer | 36–44 | Tir 12–15 ; salve préparée 22–26 | Faible armure, ligne de vue nécessaire |
| Molosse | 44–54 | Morsure 13–16 ; 4 PM dans cette variante | S'expose en poursuivant, protection faible |
| Fondeur | 48–60 | Trait 12–15 ; Fournaise préparée 26–32 | Préparation interrompue par changement de portée/ligne |
| Conducteur | 40–48 | Trait 10–12 et préparation d'un terrain gênant | Peu résistant, effet supprimable en atteignant sa source |
| Officiant | 38–46 | Soin 12–16, deux charges ; attaque 10–12 | Ne se soigne pas ; partage ses actions entre soutien et attaque |
| Garde | 78–96 | Frappe 16–20 ; protection tactique ponctuelle | 2 PM, protection contournable, déplacement forcé efficace |

Ne pas combiner tous les maxima : commencer au bas des intervalles avec deux adversaires, puis tester une troisième menace moins puissante. Une fenêtre de burst correctement préparée doit pouvoir éliminer un support ; une frappe ordinaire isolée ne doit pas supprimer systématiquement le problème avant son premier tour utile.

Comparer 3 PM et 4 PM pour le molosse. Tester des archers qui maintiennent un angle et préparent une salve au contact au lieu d'y devenir définitivement inutiles. Leur réponse de contact doit être annoncée et coûter leur attaque, sans esquive gratuite permanente.

Au-delà de II, calibrer la résistance en nombre d'actions pertinentes et la menace en dégâts après mitigation face à un profil de référence fixe de la profondeur. Ne pas ajuster secrètement les ennemis aux PV ou au deck actuel du joueur : les gains de build doivent rester réels.

## Expérience B : Achille construit son deck avant la descente

Conserver les cases, la portée, la ligne de vue, les 6 PA et les 3 PM. Les PA deviennent le budget de jeu des cartes : ne pas ajouter une jauge d'énergie qui ferait doublon.

### Règles initiales

- Bibliothèque de prototype : 24 techniques, réparties en six familles de quatre. Les familles sont des combinaisons possibles, pas des classes exclusives.
- Au départ, deux familles choisies donnent huit techniques, complétées par quatre fondamentaux : deck de 12 cartes. Le premier prototype offre tout son catalogue sans grind de déblocage.
- Main de cinq cartes. Au début du tour d'Achille, piocher jusqu'à cinq. En fin de tour, conserver au maximum une carte au choix et défausser les autres.
- Une carte jouée va en défausse. Quand la pioche est vide, mélanger la défausse. Une carte « épuisée » reste indisponible jusqu'au combat suivant.
- Les déplacements ordinaires dépensent des PM et restent toujours accessibles. Une faible frappe de secours, 3 PA pour 0,35 Prouesse au contact, reste disponible une fois par activation hors deck. Aucun tir gratuit permanent hors deck.
- Un échange des cartes de la main initiale est permis : les cartes échangées reviennent dans la pioche après leur remplacement. Pas d'échange gratuit chaque tour.
- Entre les salles : choisir une carte parmi trois ou passer. Possibilité de remplacer une carte du deck au lieu de le grossir ; augmenter volontairement sa taille jusqu'à 16 pour plus d'outils, au prix d'une moindre régularité. Cartes retirées rangées dans la collection de run, reconfiguration complète aux haltes.
- Les deux familles de départ orientent les premières offres, sans interdire les autres. Les trois doctrines existantes peuvent devenir des passifs de départ ; elles cessent d'être l'unique accès à la richesse du kit.

### Une ressource de préparation : la Ferveur

Jauge 0–3, remise à zéro au début de chaque combat. Au plus une génération par activation d'Achille, même si plusieurs conditions sont remplies : infliger un déplacement forcé effectif, consommer un état élémentaire pour une réaction, ou bloquer intégralement une attaque ennemie réellement infligée. La dernière condition crédite la prochaine activation d'Achille. Aucun gain en frappant une cible morte ou en lançant Garde sans attaque à absorber.

Des cartes spécialisées dépensent un à trois points pour un effet explicite. Elles possèdent toujours un effet de base jouable sans Ferveur : éviter les mains inutiles parce que la ressource n'est pas encore construite. Pas de mana de feu, de givre et de foudre supplémentaire dans cette première version.

### Catalogue de 24 cartes à éprouver

P = Prouesse. Dégâts indiqués avant mitigation. Coûts et coefficients sont des hypothèses. Les coûts de Ferveur sont optionnels et choisis au lancement.

| Famille / carte | PA | Effet de prototype |
|---|---:|---|
| Bronze — Crochet | 2 | Portée 2–3, 0,35 P, attire d'une case si le trajet le permet |
| Bronze — Heurt | 2 | Contact, 0,45 P, repousse d'une case ; collision : +0,25 P une fois |
| Bronze — Brèche | 2 | Contact, 0,55 P ; la prochaine attaque sur cette cible ignore 50 % de son armure, jusqu'à la prochaine activation d'Achille |
| Bronze — Percussion | 4 | Contact, 1,10 P ; dépenser 2 Ferveur pour une onde à 0,45 P sur les autres ennemis adjacents |
| Chasse — Marque | 1 | Portée 5 avec ligne de vue ; +0,30 P à la prochaine attaque contre la cible, expiration à la fin du prochain tour d'Achille |
| Chasse — Tir tendu | 3 | Portée 2–5, 0,70 P ; 1 P si Achille n'a pas encore bougé ce tour, puis termine ses PM |
| Chasse — Repli | 1 | Déplacement de deux cases maximum, sans traverser les obstacles ; impossible de traverser une zone ennemie d'arrêt annoncée |
| Chasse — Tir de traverse | 3 | Ligne de portée 4, 0,60 P au premier adversaire et 0,40 P au suivant |
| Garde — Rempart | 2 | Bouclier 0,70 P jusqu'à la prochaine activation |
| Garde — Contre préparé | 2 | Bouclier 0,35 P ; après la première attaque bloquée, prochaine frappe au contact : +0,45 P, avant fin du prochain tour |
| Garde — Ancrage | 1 | Jusqu'à la prochaine activation : ignore le prochain déplacement forcé, mais termine les PM restants |
| Garde — Conversion | 2 | Contact, consomme le bouclier restant pour infliger autant de dégâts, plafonnés à 1 P ; dépense 1 Ferveur pour repousser d'une case |
| Braise — Étincelle | 2 | Portée 4, 0,45 P feu et Chauffé pendant deux activations de la cible |
| Braise — Fournaise | 3 | Marque une case et ses quatre voisines : impact 0,80 P au début du prochain tour d'Achille, touche aussi Achille s'il y reste |
| Braise — Attiser | 1 | Portée 4, consomme Chauffé : 0,65 P feu immédiat ; sinon applique Chauffé sans dégâts |
| Braise — Cendre fertile | 2 | Crée deux cases adjacentes de cendre pendant deux tours ; les traverser coûte un PM supplémentaire, pour tous |
| Courant — Aspersion | 1 | Portée 4, applique Mouillé pendant deux activations ; retire Chauffé |
| Courant — Rappel des eaux | 2 | Portée 3, attire d'une case ; si Mouillé, peut déplacer latéralement vers une case libre adjacente à la cible initiale |
| Courant — Arc conducteur | 3 | Portée 4, 0,70 P foudre ; consomme Mouillé pour un rebond de 0,45 P sur un autre ennemi à deux cases maximum |
| Courant — Vapeur | 2 | Une zone de deux cases coupe les lignes de vue dans les deux sens jusqu'au prochain tour ; ne supprime pas une attaque de zone déjà fixée |
| Serment — Dette de sang | 0 | Perd 6 % des PV max en ignorant le bouclier, gagne 2 PA ; épuisée ; inutilisable si le paiement tuerait Achille |
| Serment — Prévoir | 1 | Regarde les trois prochaines cartes, en prend une et remet les deux autres dans l'ordre choisi |
| Serment — Retenir le nom | 1 | Conserve une carte supplémentaire en fin de tour ; dépenser 1 Ferveur pour réduire son prochain coût de 1 PA, minimum 1 |
| Serment — Dernier mot | 4 | Contact, 0,95 P ; dépenser 3 Ferveur pour 1,65 P et une poussée de deux cases ; épuisée |

Fondamentaux : frappe 3 PA/0,55 P, garde 2 PA/0,45 P bouclier, pas tactique 1 PA/déplacement d'une case, préparation 1 PA/pioche une puis défausse une. Les fondamentaux appartiennent au deck ; seule la faible frappe de secours est permanente.

Une réaction supplémentaire à tester ensuite : frapper une cible Chauffée avec Aspersion consomme les deux états et crée une case de vapeur. Pour la première version, chaque attaque déclenche au plus une réaction ; pas de réaction qui se déclenche récursivement elle-même. Le feu ne reçoit pas automatiquement une résistance obligatoire dans le puits : une voie doit enseigner un usage, pas invalider un deck au premier choix.

## Expérience C : cartes de défi et conséquences entre les combats

Deux formes de carte distinctes : les techniques sont piochées pendant le combat ; les défis sont des contrats lisibles avant la rencontre. Un défi ne remplace pas aléatoirement une carte de la main.

### Variante tempo : l'Alerte de la prochaine rencontre

L'idée « plus je tarde, plus la prochaine salle est forte » crée une décision, mais favorise aussi les decks de burst et peut punir deux fois un joueur déjà blessé. Tester une conséquence courte et récupérable :

`Alerte suivante = clamp(ceil((T − B) / 2) − O, 0, 2)`

- T : nombre d'activations d'Achille depuis l'entrée dans la phase de menace, jusqu'à la victoire incluse. La phase commence au premier tour où une attaque ennemie peut atteindre Achille depuis la position de l'ennemi, déplacements disponibles inclus, ou à une activation limite fixée dans la salle. Elle devient irréversible : impossible de repousser l'horloge en reculant.
- B : budget fixé par la rencontre, annoncé à l'entrée, par exemple cinq tours pour un duo et six pour un trio. Ce sont des valeurs à calibrer pour chaque géométrie, pas pour chaque build.
- O : 1 si un objectif de sabotage unique a été accompli, sinon 0.
- Alerte 0 : composition normale. Alerte 1 : un ennemi désigné reçoit un bouclier temporaire égal à 10 % de ses PV. Alerte 2 : ce bouclier et une préparation spéciale supplémentaire annoncée, qui remplace une action normale et ne se résout pas avant qu'Achille ait joué.
- L'Alerte s'applique au prochain combat, puis disparaît. Pas de multiplication permanente des PV/dégâts, pas d'addition des durées de toutes les salles. Une halte peut proposer d'annuler cette Alerte au prix de son autre service.

Exemple : budget cinq, victoire en huit tours = Alerte 2 ; sabotage accompli = Alerte 1. Le joueur peut accepter deux tours supplémentaires pour réussir un sabotage ou obtenir un meilleur butin : le plus rapide n'est plus toujours le seul choix valable.

### Variante contrats : choisir le problème que l'on accepte

Avant chaque combat, voir deux contrats proposés et pouvoir refuser. Un seul actif. Une modification de la rencontre suivante est annoncée immédiatement, qu'elle soit positive ou négative ; elle n'est pas un effet surprise.

| Contrat | Défi actuel | Réussite au prochain combat | Échec au prochain combat |
|---|---|---|---|
| Briser la ligne | Déplacer le garde et tuer un archer avant lui | Le garde suivant commence sans sa première égide | Un garde reçoit un bouclier temporaire de 10 % PV |
| Éteindre la forge | Occuper une case de sceau indiquée et dépenser 2 PA avant T4 | La première fournaise ennemie est retardée d'une activation | Une préparation supplémentaire annoncée |
| Couper le secours | Tuer l'officiant avant son deuxième soin | Un ennemi de soutien a une charge de soin en moins | Son premier soin est renforcé de 25 %, une seule fois |
| Dette assumée | Accepter immédiatement 6 % de PV max de dette et gagner | Choisir une carte de sa main initiale parmi le deck | Aucun malus supplémentaire : la dette est déjà payée |
| Prendre son temps | Survivre à une salve annoncée et gagner avant T7 | Conserver deux cartes lors de la première fin de tour | Une case de déploiement secondaire est condamnée, aperçu avant placement |

Ne proposer que des contrats compatibles avec la salle actuelle et le prochain ennemi réellement rencontré. Si une bifurcation ne contient aucun garde, le contrat de garde n'est pas proposé. Si un contrat exige une mécanique, assurer au moins une réponse dans le kit ou dans l'arène. Le refus n'abaisse pas la difficulté de base.

Dans la variante combinée, Alerte et échec de contrat partagent un budget maximal de deux points. Ne pas superposer aveuglément leurs malus. Le choix affiché doit présenter les conséquences finales combinées.

## Six scénarios tactiques avec les adversaires existants

1. **Porte — la salve croisée.** Garde et deux archers. Deux lignes sont visées, puis restent fixes jusqu'à résolution. Une position sûre permet d'éviter les tirs mais éloigne d'un sceau donnant une récompense. Déplacer le garde peut ouvrir une sortie ou l'amener dans la salve : tir ami annoncé et activé dans ce scénario. Teste le contrôle utile sans dégâts.
2. **Porte — la relève.** Plusieurs petits combattants, avec un renfort unique au tour 4. Saboter son point d'entrée coûte 2 PA ; le bloquer physiquement retarde le renfort sans le supprimer. Finir avant son arrivée est une autre réponse. Aucun ennemi supplémentaire ne donne d'XP ou de monnaie permettant de farmer.
3. **Puits — le foyer instable.** Fondeur et conducteur. Une zone s'allume, le conducteur ralentit son accès. Choix entre interrompre le lanceur, pousser un adversaire dans la zone, ou laisser exploser et investir dans une défense. L'explosion endommage aussi les monstres. Le terrain annonce clairement les cases concernées.
4. **Puits — le rituel des trois temps.** À T3 puis T6, un effet de salle s'intensifie. Achille peut dépenser 2 PA sur un sceau pour supprimer la prochaine montée, ou investir ces PA dans l'élimination. Deux montées maximum. La source tuée arrête le rituel.
5. **Barque — le courant.** Une poussée d'une case touche une bande annoncée à la fin de chaque deuxième tour. Elle concerne les deux camps. Une collision inflige des dégâts bornés ; aucune mort instantanée au bord. Préparer sa position, ancrer Achille ou utiliser le courant contre un molosse deviennent des décisions différentes.
6. **Barque — le passage du convoi.** Un officiant rejoint un point de sortie en quatre activations s'il n'est pas gêné. Son départ augmente l'Alerte de un, sans faire perdre immédiatement le combat. Les molosses empêchent de le poursuivre tranquillement. Il reste le même personnage existant avec un objectif d'IA différent.

Chaque salle doit posséder au moins deux réponses crédibles, dont une ne dépend pas d'une carte rare. Une attaque annoncée sur une case doit rester sur cette case ; une attaque qui suit Achille doit être présentée comme telle. Modifier l'intention après le choix du joueur détruirait le contrat de lecture.

## Exemple d'arbitrage dans une main

Achille a 6 PA. Une salve de 24 dégâts vise sa ligne, le garde gêne sa sortie, et un archer à 18 PV peut être tué. Main : Crochet 2, Tir tendu 3, Rempart 2, Prévoir 1, Fournaise 3.

- Crochet ouvre la sortie, les PM servent à quitter la ligne, Tir tendu inflige alors sa version normale : priorité à la sécurité et à l'accès, sans bonus d'immobilité.
- Tir tendu depuis la position initiale bénéficie de son bonus et peut éliminer l'archer, mais termine les PM : la seconde menace et la ligne de vue réelle déterminent si ce choix est acceptable.
- Rempart + Fournaise + Prévoir prépare le tour suivant et absorbe une partie de la salve, mais peut laisser passer des dégâts. Cette ligne n'est intéressante que si l'impact différé menace plusieurs ennemis ou sécurise un objectif.

Ce n'est pas une solution universelle : les cases, la ligne de vue, l'ordre d'initiative et les intentions exactes doivent être précisés dans la fixture jouable. L'exemple illustre les ressources concurrentes à créer.

## Protocole pour choisir une direction

1. A : kit fixe, statistiques et intentions améliorées, aucune pioche ni Alerte.
2. B : mêmes salles et statistiques, deck à pioche, aucune Alerte.
3. C : meilleur socle A ou B, contrats seuls.
4. D : même socle, Alerte tempo seule ; puis combinaison avec contrats si les deux sont intéressants séparément.

Pour chaque variante : mêmes graines, mêmes niveaux, et chaque build sur chacune des trois entrées. Comparer aussi deux politiques automatisées, l'une répétitive et l'autre sensible aux intentions/objectifs. Ne pas confondre différences de voie et différences de build comme dans les trois parcours initiaux.

Mesures : dégâts reçus avant XP/soins ; attaques dangereuses effectivement résolues ou annulées ; tours avant première menace ; cartes mortes en main ; fréquence des mêmes séquences ; réussite des objectifs ; pertes de PV et défaites sur le segment complet. Ajouter un plafond anti-boucle au banc mais ne pas le compter comme victoire.

Critères provisoires de rejet : une séquence identique neutralise trois salles différentes ; un support meurt toujours avant sa première décision ; plus d'un tour sur dix n'offre aucune carte utile hors secours ; les dégâts viennent principalement d'une intention illisible ; ou le système de tempo rend tous les builds défensifs inférieurs à difficulté égale. Ce sont des seuils de travail à réviser par essai humain, pas des garanties statistiques.

## Appuis techniques et références

Déjà présents : SpellCaster, coûts PA/PM, portées, terrains, statuts, boucliers, préparations, déplacements forcés, variantes de sorts et compositions par destination. `ExpeditionBuildCatalog` possède déjà des axes secondaires, éléments et serments : le chantier porte aussi sur leur disponibilité et leur combinaison, pas uniquement sur le nombre brut de ressources.

À construire pour ce prototype : état de deck avec identifiants d'instances, pioche/main/défausse/épuisement et RNG sauvegardés ; HUD de main et rétention ; ressource Ferveur ; intentions ennemies engagées et lisibles ; contrats et Alerte persistés ; métriques avant récompenses. Une référence de sort n'est pas une instance de carte. Les coûts, usages et modificateurs des doublons devront avoir une portée explicite. Réutiliser la résolution de SpellCaster ; ne pas créer un second moteur de dégâts dans les cartes.

Inspirations vérifiées, à adapter :

- [Into the Breach — Subset Games](https://www.subsetgames.com/itb.html) : attaques annoncées et possibilité de les contrer. Application ici : menaces lisibles avant d'investir les ressources.
- [Slay the Spire — Mega Crit](https://www.megacrit.com/games/) : construction de deck au sein d'une run. Application ici : pioche au service de la grille et des combinaisons, plutôt qu'une barre de sorts toujours identique.
- [Hades — FAQ de Supergiant](https://www.supergiantgames.com/blog/hades-faq/) et [notes officielles du Pacte](https://www.supergiantgames.com/blog/hades-welcome-to-hell-update-patch-notes/) : conditions de difficulté. Application proposée : contrats ponctuels, choisis et annoncés. Notre Alerte liée au combat précédent est une proposition propre au prototype, pas une règle attribuée à Hades.

Priorité recommandée : A pour établir une menace crédible, puis B pour construire l'identité du jeu, puis C pour donner du poids aux chemins. D est une expérience optionnelle, à garder seulement si le temps devient un arbitrage intéressant plutôt qu'une taxe sur les builds lents.
