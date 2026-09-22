# Recherche comparative — monstres, champions et cartes pour la run Cartes

Complément chiffré : [fiches techniques — statistiques, sorts, coûts, seuils et calculs tactiques](run_cartes_boss_fiches_techniques_2026-09-22.md). Il précise les valeurs finales de notre code et signale les divergences de versions des références.

Recherche du 22 septembre 2026. Complément de `run_cartes_game_design_2026-09-22.md`, fondé sur le même état local initial, Git `9af4a96a`. Périmètre exclusif : run publique Catabase Cartes. Aucune modification du gameplay.

**Conclusion de conception : notre meilleur axe est de faire circuler la valeur entre placement, cartes et équipement.** Un déplacement peut produire une ouverture ; une carte peut convertir cette ouverture en ressource ; une relique peut modifier cette conversion. Le bestiaire doit donner des raisons différentes d'utiliser ces possibilités. Augmenter séparément le nombre de sorts, de monstres et de bonus ne garantit pas cette profondeur.

Les observations externes ci-dessous sont documentées ; les adaptations à Catabase sont des propositions. Les guides communautaires décrivent parfois une version historique. Leurs chiffres ne servent pas d'étalon d'équilibrage. « Baldur » désigne Baldur's Gate 3 ; les cartes Slay the Spire et Monster Train concernent les premiers jeux. Les annonces de refonte de Waven sont séparées des mécaniques déjà documentées. Cet échantillon vise des mécanismes contrastés, pas un inventaire exhaustif des bestiaires.

**1. Les contraintes de notre hybride changent la comparaison**

Notre personnage solo dispose de 6 PA et 3 PM de base, d'un deck fixe de dix copies et d'une main de quatre cartes, avec une conservation et une recomposition limitée. Il rencontre douze combats sur vingt profondeurs. La run combine quatre classes, cartes étrangères, équipements, reliques, maîtrise et améliorations.

Cela rend trois transpositions dangereuses : importer une énigme de boss prévue pour plusieurs personnages et leurs sorts permanents ; importer la quantité de pioche d'un deckbuilder sans grille ; importer une progression d'équipement pensée pour des dizaines d'heures de préparation. Une bonne règle pour nous doit fonctionner dans la durée d'une run et avec des outils partiellement aléatoires.

La valeur d'une carte se mesure au changement de situation qu'elle permet : dégâts, menace évitée, position obtenue, protection supprimée, tempo gagné, main préparée. Ces avantages peuvent se recouvrir : une poussée qui évite une attaque ne doit pas être comptée deux fois comme déplacement et défense. Il faut comparer des séquences sur une même rencontre, avec leurs coûts en PA, PM et cartes.

**2. Dofus : des monstres qui changent les priorités et la géométrie**

| Référence et mécanisme documenté | Décision produite | Adaptation proposée pour Catabase |
|---|---|---|
| Royalmouth : une poussée retire temporairement l'invulnérabilité et lui donne de la mobilité. Les collisions comportent une sanction mortelle dans la mécanique décrite. [Guide](https://www.dofuspourlesnoobs.com/serre-du-royalmouth.html) | Déplacer devient une préparation offensive ; ouvrir une fenêtre peut rendre le boss plus dangereux. | Un élite perd sa protection lorsqu'il est déplacé, puis annonce une charge. Fournir aussi un mécanisme d'arène pour provoquer cette ouverture. Éviter la mort instantanée comme sanction d'apprentissage. |
| Ben le Ripate : le Hamrack invoqué doit atteindre le boss pour retirer sa protection ; le boss peut être déplacé alors que le Hamrack ne le peut pas. [Guide historique](https://www.dofuspourlesnoobs.com/epave-du-grolandais-violent.html) | Une invocation hostile est également un outil. Il faut organiser une rencontre entre deux entités. | Un porteur transporte une charge destinée au boss. L'intercepter neutralise le renfort ; l'orienter vers le boss ouvre une autre récompense. Ne pas imposer une carte de poussée précise. |
| Granduk : un état peut échanger sa place avec celle d'un attaquant à distance. [Guide du Comte](https://www.tofus.fr/donjons/comte) | Une attaque a un coût spatial ; l'ordre des frappes change la sécurité de la case finale. | Variante de monstre qui échange les positions à la première attaque directe du tour, avec prévisualisation. Prévoir une désactivation ou un délai ; éviter une réaction à chaque tick de saignement. |
| Comte Harebourg : confusion géométrique du ciblage et règles de position complexes. [Même guide](https://www.tofus.fr/donjons/comte) | La maîtrise passe aussi par l'apprentissage d'une grammaire spatiale exigeante. | Retenir la transformation de l'arène, mais afficher la vraie cible et la case d'arrivée. Une règle qui exige surtout de mémoriser un manuel est un mauvais premier boss de notre run. |

Enseignement : le déplacement n'a pas besoin d'infliger autant qu'une attaque pour être précieux. Il faut cependant que les rencontres lui donnent une utilité régulière, et que cette utilité soit lisible avant de jouer la carte. Si une poussée est médiocre pendant onze combats et obligatoire au douzième, le problème reste entier.

**3. Wakfu : familles cohérentes, ressources et objectifs intermédiaires**

| Référence et mécanisme documenté | Décision produite | Adaptation proposée |
|---|---|---|
| Crocodailles : la proximité entre monstres à leur fin de tour leur procure une forte protection. [Guide](https://methodwakfu.com/pvm/donjon-des-crocodailles/) | Les séparer concurrence les dégâts immédiats ; les zones d'attaque ne sont pas toujours la bonne réponse à un groupe. | Développer nos liens porte-égide/protecteur : rendre visibles les bénéficiaires et le résultat d'une séparation. La protection doit pouvoir être traversée à coût accru, pas nécessairement rendre toute attaque inutile. |
| Roi Dunîl : les morts de ses alliés le renforcent ; une phase demande une collision contre lui alors qu'il est indéplaçable. [Même guide](https://methodwakfu.com/pvm/donjon-des-crocodailles/) | Tuer les petites cibles simplifie l'arène mais renforce la menace principale. Le boss transforme un effet familier. | Donner un prix à la destruction de soutiens, clairement annoncé. Préférer un renfort temporaire ou plafonné, afin de conserver une stratégie de nettoyage viable. |
| Grozépine : un réseau de racines conditionne la protection du boss et revient avec les phases. [Guide](https://methodwakfu.com/pvm/donjon-des-kannivores/) | Répartir les actions entre infrastructure et boss ; préparer une fenêtre de dégâts. | Deux points d'ancrage suffisent dans notre format solo. Chacun détruit doit améliorer la situation immédiatement ; ne pas exiger plusieurs tours de nettoyage sans retour perceptible. |
| Noxine : les coups alimentent son déplacement ; elle peut contribuer à affaiblir le Protozortemps, tandis que sa destruction apporte un autre bénéfice. [Guide](https://methodwakfu.com/pvm/donjons/donjon-machines-de-nox/) | Choisir entre exploiter un ennemi vivant et encaisser une récompense en le tuant. Une petite attaque devient une commande de déplacement. | Un automate avance d'une case sur le premier impact direct reçu, trajectoire affichée. On peut le conduire sur un relais ou le détruire pour une ressource. Limiter les déclenchements afin que les attaques multiples ne dominent pas automatiquement. |
| Protozortemps : le guide décrit aussi des sanctions anti-abus pouvant mener à l'invulnérabilité. [Même guide](https://methodwakfu.com/pvm/donjons/donjon-machines-de-nox/) | La rencontre impose certaines manières de jouer. | Point de vigilance : un système qui interdit de trop bien contrôler un ennemi doit être explicite. Une résistance progressive annoncée est plus adaptée à notre roguelike qu'une punition cachée annulant le build. |

Les versions du Corbeau Noir trouvées pendant la recherche ne concordent pas suffisamment sur les phases et la vulnérabilité. Elles ne sont pas utilisées pour spécifier un comportement précis. Cela évite de mélanger plusieurs refontes en un boss fictif.

**4. Baldur's Gate 3 : exploiter le décor et distribuer la puissance d'un boss**

| Référence et mécanisme documenté | Décision produite | Adaptation proposée |
|---|---|---|
| Méphite de magma : explosion à la mort touchant les créatures proches. [Fiche](https://bg3.wiki/wiki/Magma_Mephit) | Où et quand tuer devient aussi important que qui tuer. | Petit ennemi explosif à déplacer près d'un groupe. Montrer l'explosion dans l'aperçu létal. Une mort par effet différé doit conserver la même règle et la même lisibilité. |
| Grym : la lave rend le boss vulnérable ; il poursuit sa cible prioritaire liée à la dernière attaque, et le marteau de forge fournit une solution environnementale. [Fiche](https://bg3.wiki/wiki/Grym) | Organiser température, poursuite et position plutôt que seulement maximiser les dégâts. | Réutiliser le fondeur et les surfaces : attirer une menace dans une zone qui fragilise son armure. En solo, la manipulation passe par Achille, un leurre ou un dispositif ; l'alternance d'aggro entre quatre héros n'est pas transposable directement. |
| Apôtre de Myrkul, fin de l'acte II : aura empêchant les soins à proximité ; nécromites consommés pour alimenter une attaque majeure. Des bénéfices supplémentaires dépendent de la difficulté. [Fiche](https://bg3.wiki/wiki/Apostle_of_Myrkul) | Arbitrer entre rester au contact, reculer pour récupérer et intercepter les renforts. | Notre collecteur dépend déjà de porteurs proches. Faire de cette dépendance un rituel visible et interruptible approfondit un système existant. Éviter de cumuler anti-soin permanent, arène minuscule et poursuite inévitable. |
| Raphaël : les piliers d'âmes alimentent sa puissance et ses ressources ; les détruire change le combat. [Guide](https://bg3.wiki/wiki/Raphael/Combat) | Choisir entre attaquer le boss et démanteler son dispositif. | Un boss dont deux soutiens alimentent deux capacités différentes. Détruire un soutien supprime précisément une menace, au lieu de seulement retirer un bonus opaque. |
| Réactions légendaires : certaines capacités supplémentaires dépendent du mode Honneur, notamment chez Raphaël. [Réaction documentée](https://bg3.wiki/wiki/Legendary_Action%3A_Beguiling_Rebuke) | Le boss agit aussi en réponse au joueur ; il faut provoquer ou contourner une réaction. | Une réaction visible et bornée par activation suffit pour un premier essai. Son déclencheur doit préciser attaque, carte, déplacement ou dégâts différés. Une riposte à chaque carte pénaliserait arbitrairement les decks de petites actions. |

Une phase de boss réussie change la question posée. « Frappe maintenant plus fort et possède davantage de PV » prolonge le combat ; « les soutiens changent de rôle et une nouvelle ligne de tir s'ouvre » renouvelle la décision. Pour Paris, la transition doit être cohérente avec les dégâts létaux si la seconde phase est censée faire partie du combat garanti.

**5. Waven : la proximité avec notre projet, et la prudence sur les versions**

Waven est une référence utile pour la relation héros, sorts, placement et progression. Les sources accessibles sont moins homogènes pour les scripts complets de boss. Il serait trompeur de présenter les scripts actuels de Toross ou de Cire Momore comme vérifiés ici, ou de leur attribuer leurs mécaniques de Wakfu ou de Dofus.

Les notes officielles documentent des briques exploitables : le sort des Taures « Au centre de l'Arène » déclenche l'attaque d'un Taure adjacent ; le donjon Cochon associe « Gaz Mystérieux » et bulles d'oxygène ; des Araknes du livre II attaquent des mécanismes. Cela atteste respectivement coopération ennemie, ressources d'arène et objectifs attaquables, sans fournir leurs scripts exhaustifs. [Notes officielles Waven, correctifs 0.23.0](https://steamcommunity.com/app/2343650/announcements/?l=french).

Applications proposées : séparer deux monstres pour casser leur attaque combinée ; utiliser une zone sûre limitée pendant une attaque environnementale ; défendre temporairement un dispositif dont dépend une ouverture. Pour un chapitre, ces règles peuvent être introduites séparément puis réunies lors du boss, sans exiger un nouveau tutoriel complet.

Un exemple historique moins solidement documenté mérite d'être conservé comme piste : des joueurs de l'événement Cire Momore de 2023 décrivent l'exploitation des potions produites pendant le combat, avec des séquences répétées de dégâts et un boss dont les PV augmentent. Ce sont des témoignages, pas un script actuel vérifié. [Témoignage sur les potions](https://www.reddit.com/r/Waven/comments/17hj482), [témoignage sur les répétitions et les PV](https://www.reddit.com/r/Waven/comments/17hxqhu). Mon enseignement est de borner une ressource générée par le boss : elle peut enrichir le puzzle, mais une boucle rentable indéfiniment risque de transformer la rencontre en exécution répétitive. Cette piste ne sert pas à définir les règles exactes du prototype.

La **Community Update #2 du 5 août 2025** annonce une refonte visant à clarifier les builds : sorts propres aux héros et pool partagé, nouvelle organisation du deck, suppression annoncée de l'équipement et de l'arbre de compétences. Ce sont des intentions de développement, pas une vérification de leur déploiement actuel. [Annonce officielle](https://steamcommunity.com/app/2343650/announcements/?l=french).

Mon enseignement pour Catabase est de conserver notre équipement et nos niveaux en leur assignant des décisions distinctes. L'annonce de Waven ne démontre pas que l'hybridation est mauvaise ; elle montre pourquoi il faut examiner les interactions et la lisibilité de chaque couche.

**6. Champions et classes : une identité doit changer le tour du joueur**

J'emploie ici « champion » à la fois pour le personnage jouable qui structure un build et, plus bas, pour une variante d'ennemi élite.

| Référence | Ce qui fait l'identité | Enseignement pour nos quatre classes |
|---|---|---|
| Pandawa de Dofus | Porter et jeter font de la position d'une entité un matériau de jeu. [Présentation](https://dofus-portals.fr/classes/pandawa/) | Une classe de placement doit modifier les options disponibles, pas seulement recevoir un bonus après déplacement. Un déplacement précis peut distinguer l'Arpenteur. |
| Xélor de Wakfu | Le cadran et les effets délayés relient espace, temps et ressources ; certains passifs modifient le moment de résolution. [Guide daté janvier 2026](https://methodwakfu.com/bien-debuter/classes/la-classe-xelor/) | Le Thaumaturge pourrait choisir entre laisser mûrir un effet et le résoudre maintenant. Commencer par un seul mécanisme temporel, sans importer toute la comptabilité du Xélor. |
| Pikuxala de Waven | Les versions documentées articulent téléportation et déclenchement offensif ; ciblage et valeurs ont évolué. [Guide](https://mobi.gg/en/tips/waven-xelor-piku-build/) | Un verbe caractéristique peut relier cartes, passif et équipement. Pour l'Arpenteur, le premier repositionnement utile pourrait préparer un tir ou une carte, avec une limite explicite. |
| Maître de guerre de BG3 | Les dés de supériorité alimentent des manœuvres ayant des usages différents. [Fiche](https://bg3.wiki/wiki/Battle_Master) | Le Gardien peut arbitrer une même réserve entre protection, poussée et riposte. Une dépense transforme le tour davantage qu'un bonus permanent de garde. |
| Ensorceleur de BG3 | La métamagie dépense une ressource pour modifier l'usage d'un sort. [Fiche](https://bg3.wiki/wiki/Sorcerer) | Une spécialisation peut changer zone, timing ou cible d'une carte. Préserver une contrepartie : une amélioration qui retire toutes les contraintes de portée et de visibilité appauvrit la grille. |
| Rector Flicker de Monster Train | Les voies d'amélioration incluent notamment la remise en circulation d'unités mortes via Reform. [Champions](https://www.neoseeker.com/monster-train/walkthrough/Champions) | La spécialisation peut changer ce qu'on veut obtenir du deck. Pour notre héros solo, traduire ce principe en récupération limitée de cartes ou d'effets, sans ajouter nécessairement une armée d'invocations. |

Dans Catabase, les sept initiations sont largement partagées et les passifs initiaux récompensent surtout une première action répondant à une condition. Les douze spécialisations restent fréquemment des modificateurs conditionnels. C'est lisible, mais la différence de jeu doit apparaître avant l'arrivée d'une rare ou d'une épique.

Propositions de signatures dès le départ : Assassin — poser puis choisir quand consommer une marque ; Gardien — répartir une réserve de garde ; Arpenteur — organiser un axe de tir par déplacement ; Thaumaturge — préparer puis déclencher un effet de terrain ou différé. Chaque signature doit fonctionner avec les cartes initiales, et recevoir ensuite au moins deux évolutions divergentes.

**7. Slay the Spire : ce que les cartes font au reste du deck**

| Carte | Fonction documentée | Ce qu'elle enseigne ; adaptation proposée |
|---|---|---|
| [Body Slam](https://slay-the-spire.fandom.com/wiki/Body_Slam) | Dégâts fondés sur le blocage actuel. | Une défense devient une ressource offensive. Tester une conversion partielle et plafonnée de garde, avec consommation, pour que protéger et frapper restent deux choix. |
| [Catalyst](https://www.slaythespire.gg/cards/silent/Catalyst) | Multiplie le poison puis s'épuise. | Un multiplicateur donne une destination à la préparation. Chez nous, convertir les ticks restants de saignement en impact immédiat serait plus contrôlable qu'une multiplication répétable. |
| [Acrobatics](https://slay-the-spire.fandom.com/wiki/Acrobatics) | Pioche puis défausse une carte. | La sélection trouve une combinaison et peut alimenter d'autres effets. Avec quatre cartes, tester d'abord une sélection modeste ; trois pioches changeraient fortement la quantité d'actions possibles. |
| [Well-Laid Plans](https://slaythespire.wiki.gg/wiki/Well-Laid_Plans) | Permet de conserver des cartes. | La préparation réduit le besoin d'obtenir toutes les pièces simultanément. Nous avons déjà une conservation native : en faire une décision de build plutôt que présenter cette fonction comme manquante. |
| [Dark Embrace](https://slay-the-spire.fandom.com/wiki/Dark_Embrace) | L'épuisement déclenche de la pioche. | Une perte devient un moteur. Le moteur existe techniquement chez nous, mais l'épuisement répété d'un deck de dix cartes exige un garde-fou et des combats courts. |
| [Corruption](https://slay-the-spire.fandom.com/wiki/Corruption) | Rend les compétences gratuites et leur fait subir l'épuisement. | La puissance immédiate se paie en endurance. Tester une posture temporaire limitée plutôt que rendre toutes nos compétences gratuites. |
| [Biased Cognition](https://slaythespire.wiki.gg/wiki/Biased_Cognition) | Gain immédiat de Focus contre perte répétée ensuite. | Une carte pose une échéance : profiter de la fenêtre ou attendre. Un Thaumaturge pourrait amplifier deux résolutions puis subir un coût annoncé, sans bonus permanent automatique. |

Le contraste avec notre initiation est concret : marque puis frappe conditionnelle coûtent trois PA et deux cartes pour un coefficient brut total de 0,65 Prouesse, égal à l'attaque novice à deux PA et une carte. Les passifs peuvent changer le résultat, mais la combinaison doit justifier son investissement dans les situations où elle est enseignée. Le saignement novice totalise 0,45 Prouesse si ses deux ticks aboutissent, contre 0,65 immédiat pour l'attaque ; il faut identifier et rendre accessible son avantage propre.

La solution n'est pas nécessairement d'augmenter ces dégâts : une marque peut permettre une attraction, une récupération ou une interruption. Mais tant que ces usages ne sont pas disponibles, leur promesse future ne compense pas le coût présent.

Les boss de Slay the Spire enseignent aussi les limites des moteurs. Le [Time Eater](https://slay-the-spire.fandom.com/wiki/Time_Eater) compte les cartes jouées et interrompt le tour au seuil ; l'[Awakened One](https://slay-the-spire.fandom.com/wiki/Awakened_One) gagne en puissance en réponse aux pouvoirs pendant sa première phase. Ils changent l'évaluation des cartes. Pour Catabase, concevoir des contrepoids souples et annoncés : une réaction consommable ou une protection temporaire, plutôt qu'une immunité totale au saignement qui invalide une spécialisation.

**8. Autres deckbuilders : les comparaisons les plus directement utiles**

| Référence | Observation sourcée | Application proposée |
|---|---|---|
| Monster Train — [Hidden Passage](https://monster-train.fandom.com/wiki/Hidden_Passage) | Déplace une unité vers l'étage supérieur. | Déplacer change les confrontations futures. Une carte tactique mérite d'être évaluée sur les attaques qu'elle rend possibles ou évite, même sans dégâts. |
| Monster Train — [Offering Token](https://monster-train.fandom.com/wiki/Offering_Token) | Pioche et défausse ; interagit avec Offering. | Le filtrage seul n'est pas un gain gratuit de main ; sa valeur dépend de l'écosystème. Une carte qui récompense la recomposition pourrait donner une identité à notre mécanisme existant. |
| Monster Train — March of Shields, Imp-portant Work, Inferno | Déplacement en tête avec armure ; sacrifice contre ressources ; gros dégâts touchant aussi les alliés. [Catalogue](https://monster-train.fandom.com/wiki/Cards) | Trois fonctions différentes : position défensive, conversion d'une pièce en ressource, puissance avec dommage collatéral. Chez nous : protéger une case, consommer une surface, accepter de détruire un dispositif utile. |
| Fights in Tight Spaces — [Quick Kick](https://fights-in-tight-spaces.fandom.com/wiki/Quick_Kick) | Associe attaque et poussée. | La position finale fait partie de la carte. Notre aperçu doit montrer déplacement, collision, danger au sol et modification des menaces pertinentes. |
| Alina of the Arena | Le jeu revendique cartes, grille, esquives, poussées, attaques ennemies retournées et équipements dans les deux mains. [Présentation officielle](https://store.steampowered.com/app/1668690/Alina_of_the_Arena/) | Référence particulièrement proche : l'équipement peut renforcer les usages des cartes dans une arène. Évaluer ensemble arme, carte et case d'arrivée, au lieu d'équilibrer trois catalogues indépendants. |
| Vault of the Void | Personnalisation du deck et pierres ajoutant des capacités aux cartes. [Présentation officielle](https://store.steampowered.com/app/1135810/Vault_of_the_Void/) | Une amélioration peut personnaliser un outil conservé. Notre deck fixe valorise le remplacement et la préparation ; il n'a pas besoin de reproduire toute l'économie d'un deck qui grossit. |

**9. Ce que notre bestiaire possède déjà et ce qu'il lui manque**

Les catalogues actuels contiennent de vrais rapports entre ennemis : conducteur et molosses, rabatteur et exécuteur, collecteur et porteurs, fondeur et déplacement, porte-égide et soutiens. Le collecteur exige déjà un porteur vivant à deux cases pour ses soins. Les surfaces et certaines réactions de terrain existent aussi. Ces acquis rapprochent déjà notre jeu des principes étudiés ; ajouter simplement feu, glace ou monstres soigneurs ne constituerait pas une réponse nouvelle.

La priorité est de rendre ces relations exploitables de plusieurs façons et de vérifier que le joueur les comprend. Pour chaque famille : une phrase de menace, une interaction de position, deux réponses viables et une évolution en élite. Exemple : le conducteur renforce les molosses ; tuer le conducteur, interrompre la relation ou organiser une trajectoire défavorable doivent constituer de vraies alternatives, avec des coûts distincts.

Pour les champions ennemis, proposer un changement comportemental identifiable : un protecteur ancre sa protection à un objet ; un exécuteur peut être amené à frapper une autre cible ; un porteur abandonne une ressource utilisable. Les PV et dégâts supplémentaires ajustent la difficulté, mais ne suffisent pas à créer une rencontre mémorable. Éviter les combinaisons aléatoires de propriétés qui retirent toutes les réponses disponibles.

**10. Quatre prototypes cohérents avec la longueur de notre run**

Ces propositions ne décrivent pas les rencontres actuelles. Les trois élites existants, aux profondeurs 6, 10 et 15, offrent des emplacements d'essai ; aucune extension de la route n'est nécessaire.

| Proposition | Question tactique et déroulement | Réponses garanties ; avantage des builds |
|---|---|---|
| Élite 6 — Gardien aux deux ancrages | Deux relais alimentent protection et riposte. En supprimer un retire l'effet correspondant ; le boss reste attaquable avec une réduction de dégâts. | Détruire un relais avec des attaques ordinaires ou actionner un dispositif accessible. Placement : éloigner le boss du lien. Défense : absorber la riposte. Burst : accepter la réduction. |
| Élite 10 — Maître de la forge | Une charge annoncée traverse une ligne ; une zone chauffée fragilise son armure. Le placement décide de la fenêtre offensive. | La commande de l'arène crée la zone ; le joueur peut attirer la charge en se plaçant puis sortir avec ses PM. Poussée et leurre facilitent l'opération. Vérifier chaque map pour qu'une case de sortie soit réellement accessible. |
| Élite 15 — Collecteur du Styx | Des porteurs alimentent un rituel visible. Les arrêter coupe l'alimentation ; les détourner permet une récompense tactique supplémentaire. | Tuer ou bloquer temporairement le convoi avec un dispositif. Contrôle : retarder ; dégâts : supprimer ; mobilité : atteindre une cible prioritaire. Ne pas conditionner l'interruption à un seul statut. |
| Paris — synthèse finale | Première phase : une menace de placement familière. Transition explicite. Seconde phase : réutilisation transformée de cette règle et une réaction limitée. | Les outils appris pendant la run restent valables. Le boss demande une meilleure combinaison, pas un contre inédit introuvable. Décider explicitement si un coup létal peut sauter la transition. |

Chaque mécanisme obligatoire doit avoir au moins une réponse qui ne dépend pas de la pioche, et idéalement deux voies de résolution. L'alternative peut être plus coûteuse que la carte spécialisée ; elle doit néanmoins éviter le verrou complet. En solo, perdre toute une activation est particulièrement brutal : commencer par une entrave partielle plutôt que copier les étourdissements d'un combat de groupe.

**11. Huit cartes prototypes qui relient deck et terrain**

Noms et effets proposés, sans équilibrage chiffré validé. Tester un petit ensemble avant de l'étendre aux 112 familles.

| Classe | Carte proposée | Décision et limite à tester |
|---|---|---|
| Assassin | Encaisser la sentence | Consommer les dégâts de saignement restants pour les résoudre maintenant. Accélérer un kill au prix de perdre une condition utile sur la cible. |
| Assassin | Issue préparée | Consommer une marque pour se replacer après une attaque. Renoncer à un futur bonus offensif pour sortir d'une menace. |
| Gardien | Percussion | Consommer une fraction de garde pour renforcer une attaque ou sa poussée. Plafonner la conversion et conserver la dépense réelle de défense. |
| Gardien | Tenir le passage | Protéger une case jusqu'à la prochaine activation ; obtenir une riposte limitée si un ennemi y entre. Ne pas déclencher indéfiniment sur les mêmes allers-retours. |
| Arpenteur | Angle neuf | Après un déplacement répondant à une condition spatiale claire, filtrer une carte. Un déclenchement par activation ; pas de remboursement en chaîne. |
| Arpenteur | Tir de rabattement | Dégâts modestes et déplacement latéral choisi. La valeur vient du placement précis, avec arrivée légale et immunités prévisualisées. |
| Thaumaturge | Résolution anticipée | Déclencher puis consommer un effet différé admissible. Accélérer une fenêtre de boss au prix de la durée restante. |
| Thaumaturge | Front mouvant | Déplacer ou transformer une surface existante. Préserver sa durée restante pour éviter de créer une permanence gratuite. |

Il faut définir une grammaire commune des effets avant de développer ces interactions. Exemple déjà identifié : un passif qui reconnaît `class_slow` ne reconnaît pas automatiquement `ecosystem_ice`, même si le joueur comprend les deux comme un ralentissement. Les catégories « ralenti », « déplacé », « dégâts directs », « consommé » doivent avoir une signification stable pour cartes, passifs, monstres et objets.

**12. Équipements, reliques, drops et niveaux : attribuer une décision à chaque couche**

| Couche | Rôle proposé dans notre hybride | Risque à surveiller |
|---|---|---|
| Classe | Fournir un verbe et un moteur de départ fiables | Attendre une épique pour sentir son identité |
| Deck | Choisir les outils, les proportions et les conversions | Collection de meilleures attaques sans changement de plan |
| Équipement | Modifier l'efficacité ou la manière d'employer certains outils | Six slots qui additionnent seulement les mêmes multiplicateurs |
| Relique | Changer une règle de construction ou offrir une nouvelle conversion | Proc automatique invisible et boucle auto-entretenue |
| Maîtrise et niveau | Donner un rythme de progression et des choix structurants | Faire du sur-niveau la solution normale à une énigme tactique |
| Drops et boutique | Permettre adaptation, bifurcation et complétion de synergies | Un moteur proposé mais statistiquement inaccessible avant la fin |
| Route | Permettre de rechercher une ressource ou d'accepter un risque connu | Branches différentes en apparence mais même décision économique |

Exemples d'équipement proposés : bottes qui facilitent le repositionnement après une interruption réussie ; bouclier qui conserve une petite part de garde mais réduit une autre efficacité ; catalyseur qui modifie une réaction de surface. Exemples de reliques : première consommation de marque qui filtre la main ; première destruction d'une protection qui prépare une carte. Chaque déclencheur doit être explicable dans le journal et limité si plusieurs systèmes peuvent se rappeler mutuellement.

Les trois reliques d'élite actuelles privilégient les dégâts physiques ou directs. Ajouter des voies pour dégâts différés, contrôle et surfaces rendrait la progression plus cohérente avec les quatre classes. Il faut aussi regarder les récompenses en contexte : le drop automatique en réserve peut fournir zéro carte, les rares arrivent à partir de la profondeur 4, les épiques à 10. Une identité de départ ne doit pas dépendre de cette loterie.

Proposition à comparer au fonctionnement actuel : récompenser certains jalons par un choix orienté entre une pièce de moteur, un outil de contre et un objet. Conserver l'aléatoire dans les candidats et le reste du butin ; garantir une occasion de décision structurante. Le but est que les drops influencent la direction du build, avec assez de contrôle pour rendre cette direction jouable.

Approfondissement complémentaire : [boss, salles et méthodes de victoire](run_cartes_boss_profondeur_2026-09-22.md). Ce dossier développe les boss nommés, leurs variantes et les interactions à construire dans notre run ; les prototypes ci-dessus sont des étapes de validation, pas une limite à l’ambition du bestiaire.

**13. Priorités et critères de vérification**

1. **Rendre les règles fiables.** Clarifier les catégories de statuts, les transitions de boss, les déclencheurs et les aperçus. Une synergie plausible qui ne fonctionne pas abîme l'apprentissage.
2. **Différencier les départs.** Une interaction complète et visible par classe ; corriger les séquences d'initiation dont le surcoût n'a pas de bénéfice accessible.
3. **Approfondir une famille existante.** Commencer par collecteur/porteurs ou protection/placement, avec réponses indépendantes de la pioche et réaction lisible.
4. **Tester deux moteurs de deck.** Par exemple garde consommée et effets différés consommés. Évaluer ensuite filtrage et conservation ; ne pas importer tous les moteurs de Slay the Spire simultanément.
5. **Relier les récompenses à ces moteurs.** Une carte, un équipement et une relique doivent offrir trois décisions complémentaires. Élargir le contenu après validation de cette boucle.

Les essais utiles comparent les quatre classes sur les mêmes rencontres et plusieurs ordres de pioche. Mesurer : tours sans action utile ; compréhension des intentions ; accès réel à la réponse de boss ; place de la mobilité dans les choix ; nombre de fois où le moteur du build se déclenche ; pièces de build reçues mais inutilisables ; durée et répétitivité des phases ; dégâts provenant de chaque système. Tester aussi une main sans déplacement, sans dégâts à distance et sans contre spécialisé.

Un critère qualitatif central : après la partie, le joueur peut-il expliquer ce que son build cherchait à faire, quel ennemi l'a obligé à s'adapter et quel drop a changé son plan ? Sans cela, des dizaines d'effets peuvent encore produire une expérience uniforme. Aucun seuil de victoire ou de durée n'est déclaré validé dans cette étude.

**Traçabilité locale et limites**

Les constats sur notre jeu reposent sur les fichiers déjà examinés dans l'audit initial : `core/expedition/class_card_catalog.gd`, `card_ecosystem_catalog.gd`, `class_cards.gd`, `class_card_modifier.gd`, `card_ecosystem_effects.gd`, `card_drop_catalog.gd`, `catabase_route_v6.gd`, `catabase_monster_encounter_catalog.gd`, `catabase_monster_evolution_catalog.gd`, `core/ai/catabase_monster_decision.gd`, `battle/dynamic_terrain/terrain_surface_runtime_service.gd` et `units/unit.gd`.

La recherche actuelle ajoute une analyse documentaire, pas une validation runtime. Aucun test moteur supplémentaire n'a été exécuté pour ce document. Le bilan technique de l'audit précédent reste séparé : suite `cards` à 76 tests réussis sur 77, avec échec du contrôle d'unicité d'icônes ; cela ne mesure pas l'équilibrage ni le plaisir de jeu. Les guides historiques et annonces sont des références de conception, pas une certification de toutes les versions actuelles des jeux cités.
