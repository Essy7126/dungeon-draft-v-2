# Catabase — références de gameplay et axes d'amélioration

Audit de conception du 23 septembre 2026. Base Git : `ad1f4c58`, avec modifications de salles et de sondes déjà présentes dans l'arbre de travail. Recherche web et lecture du code ; aucun changement de gameplay, import, test Godot ou playtest exécuté pour ce document. Les valeurs proposées sont des hypothèses de prototype.

## 1. Décision proposée

**Faire de Catabase un jeu où le placement transforme le deck et où le deck transforme le plateau.**

Le catalogue actuel propose beaucoup de techniques utiles. Ce qui manque surtout à la variante Cartes, ce sont des moteurs qui donnent envie de raconter une combinaison : « j'ai attiré le porteur, sa collision m'a rendu mon déplacement, puis j'ai traversé ma braise pour préparer le prochain tour ». Aujourd'hui, une part importante des constructions raconte plutôt « j'ai rempli une condition pour augmenter mes dégâts ».

Priorités : rendre les interactions fiables ; faire essayer une combinaison très tôt ; transformer les spécialisations ; adapter les meilleurs mécanismes déjà présents en Classique ; confronter chaque construction à des rencontres qui lui posent plusieurs problèmes.

Conserver les quatre classes et le héros solo pour la première itération. Ajouter tout de suite plusieurs nouvelles classes disperserait les cartes et les occasions de construire un moteur cohérent dans une run courte.

## 2. Méthode et limites

« Meilleurs » désigne ici un corpus de références reconnues et surtout complémentaires, pas un classement mondial mesuré. Étude centrale : Slay the Spire **1**, Monster Train **1**, Balatro, Wildfrost, Fights in Tight Spaces, Into the Breach, Dofus, Wakfu, Waven, Baldur's Gate 3 et Divinity: Original Sin 2. Les premiers volets sont choisis explicitement pour leurs systèmes établis ; leurs règles ne sont pas confondues avec celles des suites.

Trois niveaux de preuves : descriptions officielles pour la promesse des systèmes ; wikis/guides pour les interactions ; discussions de joueurs pour les raisons d'aimer ou d'abandonner un style. Les témoignages sont qualitatifs et auto-sélectionnés : aucune fréquence d'opinion ou popularité générale n'en est déduite. Les conclusions sur le plaisir sont des interprétations de conception, pas des résultats de sondage.

Les jeux Ankama ont connu des refontes. Je retiens leurs principes et donne les versions/dates des guides quand elles comptent, sans importer leurs coefficients ou prétendre présenter la méta actuelle. Les anciens guides Dofus servent à expliquer des mécanismes historiques, pas à conseiller un build 2026.

Audit local approfondi de Cartes et comparaison ciblée avec Classique ; pas un audit exhaustif de toutes les mutations Classique ni de l'ergonomie en partie réelle. Les apparences d'Achille restent cosmétiques selon le contrat produit.

## 3. Deckbuilders : ce qu'il faut retenir

| Référence | Cartes, classes ou mécanisme | Plaisir recherché — interprétation | Transposition à Catabase |
|---|---|---|---|
| Slay the Spire — Ironclad | Corruption, Dark Embrace, Feel No Pain ; Barricade/Body Slam | Transformer l'épuisement en pioche/défense ; convertir une réserve défensive en attaque | Épuiser une carte pour reprendre une action ; dépenser une réserve plutôt qu'avoir simplement un bonus « si garde > 0 » |
| Slay the Spire — Silent | Poison, dagues ; Acrobatics, Reflex, Tactician pour le cycle | Trouver l'ordre des cartes et rendre une défausse productive | Défausse volontaire déclenchée par une esquive ou une exécution, avec récompense limitée |
| Slay the Spire — Defect | Orbes de glace, foudre et ténèbres ; évocation | Choisir entre conserver une production et la consommer pour une urgence | Un sceau persistant que l'on peut entretenir, déplacer ou dépenser |
| Slay the Spire — Watcher | Colère/Calme, anticipation et rétention | Choisir précisément quand s'exposer et quand sortir de sa phase offensive | Une posture offensive avec vulnérabilité visible, une sortie fiable et un coût d'opportunité |
| Monster Train | Identités de clans ; échos chargés associés à un étage | Investir dans un lieu et combiner deux systèmes | Une zone préparée qui change la valeur des cartes ; quelques cartes de liaison entre classes |
| Balatro | Jokers qui changent les règles de valorisation du deck | Découvrir qu'un objet rend soudain utiles des cartes auparavant ordinaires | Reliques qui changent une règle : déplacement → rétention, collision → récupération ; éviter seulement « +4 % » |
| Wildfrost | Compagnons, compteurs d'activation, charms | Construire puis synchroniser un moment fort ; arbitrer protection et tempo | Sceaux retardés avec compte à rebours lisible et possibilité d'accélérer ou déplacer l'effet |
| Fights in Tight Spaces | Agent 11, déplacement, attaques et ressources dans une petite arène | Chaque case participe à la combinaison ; la scène raconte une action cohérente | Attaques avec déplacement, permutations et redirection d'attaques annoncées |

Sources : [personnages et archétypes de Slay the Spire](https://www.slaythespire.gg/characters), [interaction Dark Embrace/Corruption](https://slay-the-spire.fandom.com/wiki/Dark_Embrace), [combinaisons emblématiques discutées par les joueurs](https://www.reddit.com/r/slaythespire/comments/1dg7ypk), [clans de Monster Train — officiel](https://www.themonstertrain.com/clans), [Balatro — officiel](https://www.playbalatro.com/), [Wildfrost — officiel](https://www.wildfrostgame.com/), [analyse de Fights in Tight Spaces](https://www.nintendolife.com/reviews/switch-eshop/fights-in-tight-spaces).

La contrepartie est essentielle : pioche, énergie, récupération et copie peuvent supprimer toute décision lorsqu'elles bouclent sans coût. Autre risque : exiger trois cartes précises avant que le personnage fonctionne. Chaque pièce doit avoir une utilité seule, puis gagner une nouvelle fonction en combinaison. Le plaisir du build comprend aussi l'adaptation aux trouvailles, pas seulement l'exécution d'une recette prévue avant la run.

## 4. Ankama : une classe reconnaissable à ses décisions

| Classe / jeu | Sorts ou possibilités à retenir | Constructions et intérêt | Friction à éviter chez nous |
|---|---|---|---|
| Pandawa — Dofus | Karcham/Chamrak : porter puis jeter ; placement précis | Soutien de placement ou combattant ; met une cible dans la zone d'un autre système | En solo, le placeur doit posséder lui-même quelque chose à exploiter après le placement |
| Eliotrope — Dofus | Portail, Neutral ; tirs et déplacements par réseau | Distance, angles indirects, préparation du plateau ; sentiment d'obtenir un tour impossible autrement | Géométrie opaque et prévisualisation insuffisante ; commencer par deux points reliés |
| Roublard — Dofus | Bombes, murs de bombes, Détonateur ; protéger et repositionner la préparation | Préparation puis explosion, ou contrôle spatial ; satisfaction de fabriquer son attaque | Trop de tours sans impact ; bombes détruites avant que le plan ait servi |
| Sram — Dofus | Pièges, réseau, Double, invisibilité | Embuscade, réseau de déplacement, pression directe ; le joueur scénarise l'approche ennemie | IA voyant tout ou ne comprenant rien ; règles explicites sur la détection et les leurres |
| Xélor — Dofus | Téléportations, symétries et Téléfrags | Ordre de résolution et manipulation des positions | Complexité préalable disproportionnée ; ne pas importer une grammaire entière dès le départ |
| Xélor — Wakfu | Cadran, Vol du temps, relation PA/PW | Mobilité autour d'un centre ; économie d'un tour à l'autre | Distinguer cette version de celle de Dofus ; garder les ressources et les prévisions visibles |
| Féca — Wakfu | Glyphes, boucliers, position défendue | Défense active et investissement dans une zone | Un protecteur solo ne doit pas attendre passivement que l'ennemi le frappe |
| Aiguille Pikuxala — Waven | Téléportation utilisée comme déclencheur offensif ; variantes de passifs | Se déplacer produit de la valeur ; sorts, passif et équipement soutiennent le même comportement | Une classe entière ne doit pas se résumer à répéter le même déplacement rentable |

Sources mécaniques : [Pandawa et synergies — guide historique](https://www.eclypsia.com/home/dofus/guides/guide-dofus-tout-savoir-sur-la-classe-pandawa-90944.html), [Eliotrope et géométrie](https://www.tofus.fr/classes/eliotrope), [Roublard — guide historique](https://dofus.jeuxonline.info/article/10534/comprendre-roublards), [Xélor Dofus](https://dofus-portals.fr/classes/xelor/), [Xélor Wakfu, janvier 2026](https://methodwakfu.com/bien-debuter/classes/la-classe-xelor/), [Féca et glyphes](https://stratfu.fr/classes/feca/), [Pikuxala, guide février 2026](https://guidactik.com/waven/guide-du-deck-xelor-aiguille-pikuxala-sur-waven/).

Les retours sur les [classes techniques Dofus](https://www.reddit.com/r/DOFUS_FRANCE/comments/1rqhogb/) associent leur attrait à la maîtrise et aux solutions inhabituelles, mais mentionnent aussi la dépendance du Roublard au placement. Des joueurs de [Waven](https://www.reddit.com/r/Waven/comments/169rx59) reprochent aux classes de préparation de payer leur délai face aux dégâts immédiats ; d'autres apprécient la liberté de construction du [Pikuxala](https://www.reddit.com/r/Waven/comments/1evg9ut). Ce désaccord est utile : préparer doit procurer un bénéfice visible avant même le grand déclenchement.

**Leçon : une classe mémorable possède un verbe distinctif, une contrainte que l'on apprend à maîtriser et plusieurs façons d'exploiter les mêmes outils.** Quatre couleurs de dégâts ne produisent pas cette identité.

## 5. Baldur's Gate et Divinity : personnages, builds et attachement

Il faut séparer personnalité, origine et classe. Dans BG3, Lae'zel n'est pas obligatoirement Maître de bataille ; Karlach n'est pas obligatoirement Berserker. Les exemples ci-dessous sont des constructions possibles. De même, Divinity 2 permet de reconstruire largement les compétences d'un compagnon ; son origine n'enferme pas tout son build.

| Personnage / construction | Action ou boucle exemplaire | Ce qui mérite d'être repris |
|---|---|---|
| Lae'zel Maître de bataille | Attaque désarmante, poussée, renversement, Riposte ; réserve de dés de supériorité | Le combattant décide quel problème résoudre avec son coup ; une ressource limitée permet l'intervention décisive |
| Karlach Berserker | Lancer enragé : objets ou créatures deviennent projectiles | Puissance physique qui change le plateau et produit une scène lisible |
| Shadowheart clerc | Esprits gardiens : aura de dégâts et ralentissement sous concentration | Le déplacement devient offensif ; garder un effet actif impose de gérer le risque |
| Astarion voleur | Attaque sournoise et, si spécialisation Voleur, action bonus supplémentaire | Les actions utilitaires et le tempo font partie du build ; ne pas réduire l'assassin à un multiplicateur |
| Ensorceleur, personnage créé ou reclassé | Métamagie : portée, durée, double cible, accélération | Transformer un sort connu au moment pertinent au lieu d'ajouter quatre copies presque identiques |
| Fane — Divinity 2 | Time Warp, tour supplémentaire ; builds pouvant articuler ressource Source et gros enchaînement | Choisir son moment décisif ; chez nous, préférer un report de ressource borné à un tour complet gratuit |
| Sebille — Divinity 2 | Flesh Sacrifice, capacité elfique : PA et sang au sol ; combinaison avec affinité élémentaire pour la nécromancie | Un coût, une surface et une économie de sorts se rencontrent dans une même action |
| Lohse — Divinity 2 | Liberté de construction et enjeu personnel | La préférence pour un héros ne vient pas seulement de son rendement ; l'identité narrative compte également |

Règles : [Maître de bataille](https://bg3.wiki/wiki/Battle_Master), [Lancer enragé](https://bg3.wiki/wiki/Enraged_Throw), [Esprits gardiens](https://bg3.wiki/wiki/Spirit_Guardians), [Fast Hands](https://bg3.wiki/wiki/Fast_Hands), [Métamagie](https://bg3.wiki/wiki/Metamagic), [Time Warp](https://divinity.fandom.com/wiki/Time_Warp). Recoupement des builds Fane/Sebille : [discussion sur leurs avantages respectifs](https://www.reddit.com/r/DivinityOriginalSin/comments/16628ll), [enchaînements de compétences rapportés par les joueurs](https://gamefaqs.gamespot.com/boards/236378-divinity-original-sin-ii-definitive-edition/77096645).

Pour l'attachement, les échanges sur la [composition préférée dans BG3](https://www.reddit.com/r/BaldursGate3/comments/1cw28m7) parlent aussi d'humour, de personnalité et de relations ; Larian place explicitement l'identité au centre de la [création du personnage](https://forums.larian.com/ubbthreads.php?Number=860776&page=all&ubb=showflat). Mon interprétation : Achille gagnerait à avoir une cohérence entre ses choix de combat, ses sacrifices et les réactions des haltes. Cela peut commencer par quelques textes et choix de run ; cela ne nécessite pas de recréer un RPG à compagnons.

## 6. Le meilleur apport des tactiques : rendre le futur manipulable

Into the Breach annonce les attaques ennemies : le joueur peut construire une réponse plutôt que deviner. L'[explication officielle](https://www.subsetgames.com/itb.html) et l'[entretien de conception avec Subset](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-subset-games-i-into-the-breach-i-) insistent sur cette structure de problème tactique.

Pour Catabase : préciser si une attaque vise **une case**, **une unité suivie**, **une ligne** ou **un voisinage**. Un déplacement devrait pouvoir sauver, rediriger, interrompre ou empirer une attaque suivant une règle annoncée. Il existe déjà des intentions et préparations dans notre jeu ; l'objectif est d'en faire une ressource pour les cartes, pas de prétendre inventer leur affichage.

Chaque rencontre devrait poser au moins deux besoins concurrents : frapper le chef ou empêcher une livraison ; conserver une ligne de tir ou tenir une réserve ; dépenser ses PA maintenant ou charger un effet différé. Une nouvelle mécanique de salle n'apporte pas autant si sa réponse optimale est systématiquement « tuer le chef immédiatement ».

## 7. Audit du jeu présent

### Ce que nous possédons déjà

- Quatre classes, départs propres, cinq familles choisies parmi sept, deux copies chacune ; dix cartes actives et quatre en main.
- **112 familles publiques, 28 par classe, 29 codes d'effet**, recomptés statiquement dans les trois catalogues. Les anciennes familles `s_*` ne sont pas comptées.
- Marque, états périodiques, défense, déplacements, poussées/attractions, surfaces, stase et réduction de ressources. Les terrains et le moteur commun savent déjà traiter des réactions.
- Conservation d'une carte, recomposition d'une carte contre 1 PA une fois par activation ; pile d'épuisement technique liée aux limites d'usage.
- Réserve de collection séparée du deck, cartes étrangères, améliorations par copie, maîtrises et choix de spécialisation.
- En Classique : disque posé/rappelé, réserve d'urne, braise déplacée, coût en oboles. Des idées distinctives sont déjà disponibles dans le projet.

Sources locales : `class_card_catalog.gd`, `class_starter_catalog.gd`, `card_ecosystem_catalog.gd`, `class_cards.gd`, `catabase_cards.gd`, `catabase_first_six_spells.gd` dans `core/expedition/` ; `battle/dynamic_terrain/terrain_surface_runtime_service.gd`.

### Manques et redondances, avec niveau de certitude

| Priorité | Constat | Preuve / portée | Direction |
|---|---|---|---|
| P0 | « Ralenti » ne compose pas de manière uniforme | `class_card_modifier.gd:38` ne reconnaît que `class_slow`. La glace de surface applique `ecosystem_ice`, l'entrave `class_root` ; `Unit.has_status` compare l'identifiant exact. Lecture statique, pas reproduction runtime | Définir un contrat sémantique : le bonus exige-t-il cet état nommé, ou toute réduction de PM ? Aligner texte et code ; tester les deux cas |
| P1 | Les 12 spécialisations restent des bonus numériques conditionnels | `SPECS` et résolution de `class_card_modifier.gd` : première garde ou premier dégât éligible | Donner à chaque voie une transformation de règle et un coût distinct |
| P1 | Le deck circule sans véritables moteurs de cartes qui manipulent cette circulation | Effets publics orientés plateau ; `start_turn`, `consume`, `recompose`, `_prune_exhausted` communs | Introduire pioche, récupération, défausse volontaire et épuisement comme décisions de build ; réutiliser l'état existant |
| P1 | Premier gain de carte non garanti dans l'écosystème actuel | `ecosystem_revision = 2` ; `CardDropCatalog.factors(1, normal, 0)` donne 49 % et 16 % | Garantir une première décision parmi des offres, puis conserver une part de découverte aléatoire |
| P1 | Une partie de la promesse de spécialisation reste éloignée du départ | Choix niveau 4 ; rares disponibles profondeur 4, épiques profondeur 10 dans `reward_pool` | Donner une petite version du verbe identitaire dès l'initiation ; garder sa transformation pour la progression |
| P2 | Des familles remplissent la même fonction sous des habillages proches | Marque → bonus marqué chez Assassin et Thaumaturge ; Embusqué et Escarmoucheur récompensent deux cases parcourues ; Chasseur et Cryomancien le même état | Différencier le résultat obtenu, pas seulement portée, dégâts physiques/magiques et coefficient |
| P2 | Certaines raretés amplifient surtout un outil connu | Garde brève / Tenir le passage / Bastion vivant ; Coup de grâce / Moisson des condamnés | Conserver les variantes utiles de coût, transformer une partie des cartes rares en changement de règle |
| P2 | Équipement largement scalaire | `class_equipment_catalog.gd` : 6 emplacements × 4 affinités × 3 paliers = 72 définitions | Quelques objets transformateurs choisis ; maintenir des équipements simples pour la lisibilité |
| P2 | Améliorations souvent uniformes | Garde prolongée, mouvement traversant, portée ou ignorance de ligne de vue, suivant une règle générique | Deux transformations exclusives pour une poignée de cartes pivots |
| P2 | Plusieurs systèmes peuvent raconter le même progrès de puissance | Maîtrise, statistiques, équipement, rune, amélioration, spécialisation | Réserver des rôles clairs : stats = puissance ; spécialisation/relique = règle ; carte = action |

Le calcul du premier gain donne **42,84 % de probabilité théorique de zéro carte** dans ce scénario : `0,51 × 0,84`. Ce n'est pas un taux mesuré sur des parties et ce n'est pas la probabilité d'une run sans progression. Le système de sécheresse augmente les chances ultérieures.

Le comptage trouve 12 effets `move`, 8 `guard`, 8 `push`, 7 `pull`, 7 `mark`, 7 `marked` et 7 `hit`. Il ne prouve pas que ces cartes sont inutiles : coût, portée, initiation et accès par classe peuvent justifier une redondance. La question de suppression est : **existe-t-il une situation où le joueur préfère cette variante pour une raison autre que son acquisition ou son coefficient ?**

### Ce que le nouvel audit ne doit pas déclarer absent

Les modifications locales déjà présentes ajoutent des destinations de salles, des chefs par rôle, une IA dédiée, des topologies modifiées et le raccordement des règles de salle à la sonde. Les reproches précédents « chef = plus gros PV », « IA ignorant toutes les salles », « sonde sans règles de salle » ne doivent donc plus être recopiés comme description de cet arbre de travail.

Ces corrections ne sont pas validées par ce document. La nouvelle couverture exacte des chemins, la parité scène/sonde et les résultats d'équilibrage doivent être vérifiés sur l'état final de l'autre travail. L'ancien minimum de zéro salle spéciale ne constitue pas une mesure du code modifié.

Les surfaces/réactions, les intentions, les cartes étrangères et l'épuisement technique existent déjà. Le manque porte sur leur exploitation comme moteurs de construction accessibles au joueur. Les gestes de secours existent également ; leur domination éventuelle doit être mesurée à nouveau, pas déduite d'un ancien rapport.

## 8. Quatre identités proposées et douze directions de build

Ces directions remplaceraient progressivement les spécialisations actuelles. Elles ne sont pas douze systèmes à produire simultanément.

| Classe | Verbe principal | Trois voies possibles | Arbitrage distinctif |
|---|---|---|---|
| Assassin | Préparer une ouverture puis disparaître | Exécuteur : consommer la marque et récupérer une mobilité ; Tisseur : leurres/pièges ; Hématurge : consommer le saignement pour un effet immédiat | Encaisser pour finir, temporiser l'usure, ou dépenser sa préparation |
| Gardien | Convertir la pression reçue | Rempart : défendre une zone ; Vengeur : absorber → charger une réserve → dépenser ; Percuteur : collisions → contrôle et cycle | Utiliser la défense maintenant ou investir dans la riposte |
| Arpenteur | Construire une trajectoire | Tireur : poser puis rappeler un projectile ; Escarmoucheur : attaques et déplacements alternés ; Chasseur : réseau de pièges simples | Préserver son angle, poursuivre sa proie ou abandonner sa préparation |
| Thaumaturge | Transformer un état du plateau | Pyromancien : déplacer/consommer les braises ; Cryomancien : contrôle et rupture du givre ; Tisseur de sceaux : préparer et déclencher une zone différée | Conserver le terrain utile ou le consommer pour agir tout de suite |

Les noms Hématurge/Tisseur sont des propositions, pas des classes existantes. L'Assassin doit garder un style de dégâts immédiats accessible ; le Thaumaturge doit pouvoir agir efficacement avant son tour de préparation complet.

Deux idées pour une extension ultérieure seulement : **Passe-seuil**, spécialiste de deux ancrages spatiaux inspiré de l'Eliotrope ; **Horloger du Léthé**, report limité de PA et échos retardés inspiré des Xélors. Ne les séparer en classes que si les prototypes prouvent qu'elles ne rentrent pas dans les quatre identités actuelles.

## 9. Petit catalogue de prototypes

Noms originaux ; coûts indicatifs à tester. Les effets sont de nouvelles propositions, sauf lorsqu'une adaptation du Classique est précisée. Une récupération respecte toujours les limites d'utilisation de la famille. Aucune génération de PA ne peut se déclencher sur elle-même.

| Proposition | Règle de prototype | Décision créée / garde-fou |
|---|---|---|
| Fil de fuite — Assassin, 1 PA | Se déplacer de 2 cases ; si une marque a été consommée ce tour, piocher 1 | Préparer une sortie ; une fois par activation |
| Ouvrir la suture — Assassin, 2 PA | Consommer le saignement posé par Achille pour avancer ses dégâts restants, sans les multiplier | Dégâts immédiats contre maintien de l'usure ; une consommation par cible/activation |
| Ombre sacrifiée — Assassin, 1 PA | Épuiser cette carte pour reprendre un déplacement de la défausse | Dépenser une ressource de combat ; ne récupère ni elle-même ni une carte épuisée |
| Urne de représailles — Gardien, 2 PA | Créer une garde ; l'absorption d'une attaque ennemie alimente une réserve plafonnée | Adaptation du Classique ; aucune charge sur dégâts auto-infligés ou sa propre riposte |
| Briser l'urne — Gardien, 2 PA | Dépenser toute la réserve pour une attaque en ligne | Choisir le moment et l'angle ; seule la réserve réellement consommée contribue |
| Heurt révélateur — Gardien, 2 PA | Pousser ; si collision effective, piocher 1 puis défausser 1 | Le plateau améliore la main ; une fois/activation, pas de gain net de cartes |
| Disque voyageur — Arpenteur, 2 PA | Poser un disque ; cette copie devient « Rappel » tant que le disque existe | Adaptation du Classique ; une seule instance, forme alternative pour éviter une moitié de combo introuvable |
| Rappel de bronze — forme du disque, 2 PA | Rappeler sur le trajet vers Achille, puis restaurer la forme de lancer | Se déplacer pour créer la ligne ; murs et victimes prévisualisés |
| Pas de lecture — Arpenteur, 1 PA | Déplacement court ; consulter deux cartes du dessus, en laisser une au-dessus et mettre l'autre dessous | Organiser le prochain tour ; pas de pioche supplémentaire immédiate |
| Tison nomade — Thaumaturge, 1 PA | Déplacer une de ses braises d'une case sans réinitialiser sa durée | Adaptation de Flux ; pas de duplication de terrain |
| Rupture du givre — Thaumaturge, 2 PA | Consommer le givre d'une case pour une petite zone de dégâts | Renoncer au contrôle pour achever ; contrat explicite entre surface et statut |
| Sceau ajourné — Thaumaturge, 2 PA | Poser une zone qui se déclenchera au début de la prochaine activation d'Achille | Attirer ou maintenir une cible ; limite d'un sceau et compteur visible |

Pour la pioche, conserver une main de départ à quatre mais prototyper un plafond temporaire de six, avec interdiction explicite de dépasser le plafond. Distinguer « jouer », « défausser », « épuiser » et « quitter la main » avant tout déclencheur : la défausse normale de fin de tour ne doit pas activer accidentellement les moteurs de défausse volontaire.

Quatre reliques candidates : première collision ennemie du tour → conserver une carte supplémentaire ; rappel du disque → première cible marquée ; consommation d'une braise → garde temporaire ; absorption d'une grosse attaque → consulter le dessus de pioche. Choisir deux prototypes maximum au départ. Ce sont des changements de comportement, pas des bonus à empiler tous ensemble.

Exemples de builds de cinq familles doublées, à tester après adaptation :

- **Gardien des retours** : Urne, Briser l'urne, Heurt révélateur, attraction existante, déplacement existant. Boucle défense → réserve → placement → dépense ; vulnérable aux ennemis qui refusent le contact.
- **Arpenteur du disque** : Disque/Rappel en une famille, Pas de lecture, marque, recul, tir simple. Boucle projectile → angle → rappel ; doit garder un plan fonctionnel quand la ligne est bloquée.
- **Thaumaturge des cendres** : braise existante, Tison nomade, attraction, protection, attaque immédiate. Boucle terrain → déplacement ennemi → maintien/consommation ; ne dépend pas uniquement du futur déclenchement.

## 10. Rencontres pour révéler ces builds

| Situation proposée | Problème posé | Solutions à soutenir |
|---|---|---|
| Artilleur à tir verrouillé sur une case | La menace est connue et une cible importante risque de rester dedans | Déplacer la cible, déplacer l'artilleur si sa règle le permet, interrompre ou absorber |
| Porteur + protecteur | Le plus dangereux n'est pas celui qui fait le plus de dégâts | Séparer, ralentir, bloquer une route, faire un détour pour le mécanisme |
| Deux réserves disputées | Un gain différé peut être volé | Défendre, décharger tôt, repousser le voleur, accepter une perte pour tuer ailleurs |
| Ennemi qui détruit la préparation au sol | Le build doit préserver son investissement | Déplacer la braise, déclencher tôt, détourner le destructeur ; ne pas immuniser tout le combat |
| Menace lente + harceleur | Préparation et défense immédiate sont simultanément nécessaires | Petit combo fiable maintenant ou gros combo risqué au tour suivant |

Ces variantes doivent réutiliser les services de salle et le moteur commun. Ne pas introduire une immunité qui annule complètement un archétype ; conserver au moins deux réponses sans exiger une carte rare déterminée.

## 11. Ordre de réalisation et critères d'acceptation

| Lot | Contenu | Critère de décision |
|---|---|---|
| A — Fiabilité | Contrat des états ; terminer et valider le travail des salles en cours ; aligner descriptions et résolutions | Givre/entrave et bonus documentés sans ambiguïté ; parité scène/sonde démontrée |
| B — Départ et preuve de plaisir | Premier choix garanti ; deux prototypes complets : Gardien réserve et Arpenteur disque | Première combinaison réalisable au plus tard au deuxième combat dans le protocole ; plusieurs choix de position réellement utiles |
| C — Circulation du deck | Pioche/défausse ciblées, récupération bornée, plafond de main et journal des déclencheurs | Aucun cycle gratuit illimité ; les cartes récupérées respectent les restrictions de famille |
| D — Identités | Une spécialisation transformative par classe ; puis une deuxième voie si la première fonctionne | Deux joueurs d'une même classe peuvent expliquer des plans différents sans citer uniquement les dégâts |
| E — Progression | Quelques reliques et améliorations alternatives ; prototypes de sceaux/pièges | Une trouvaille change au moins une décision récurrente ; pas de choix dominant évident partout |

Ne pas estimer une durée en jours avant le prototype des événements de cartes, de la persistance et des aperçus. Les portails complets, invocations multiples, tours supplémentaires, métamagie universelle et arsenal de nouvelles classes restent plus coûteux et viennent après ces preuves.

### Mesurer autre chose que les victoires

Sur mêmes graines, difficultés et chemins, comparer versions et constructions avec des runs complètes puis des essais humains. Une politique automatique simple peut sous-estimer précisément les builds de préparation recherchés.

- Moment de la première combinaison ; fréquence des mains sans action intéressante ; usage des secours et de la recomposition.
- Parts des PA investis dans préparation, défense, déplacement et dégâts ; pertes de PV entre combats.
- Déclencheurs de classe réellement utilisés, récupérations, cartes conservées, taille de main maximale et chaînes les plus longues.
- Choix de cartes proposés/acceptés/remplacés ; diversité effective des familles et dépendance à un objet précis.
- Ennemis déplacés pour annuler/rediriger une menace ; objectifs disputés ; fréquence du plan « tuer le chef d'abord ».
- Après un combat, faire expliquer au joueur le moment décisif, une alternative envisagée et pourquoi il souhaite rejouer ce build.

Un seuil de victoire ne valide pas à lui seul le plaisir. Inversement, une combinaison spectaculaire qui rend les six tours suivants automatiques ne suffit pas. Chercher des décisions répétées et compréhensibles, avec un moment fort identifiable.

## 12. Traçabilité de cet audit

Lectures : README, références courantes produit/architecture/contenu, contrats de classes et six constructions, audit du 21 septembre et audit après pull du 23 ; puis catalogues, modificateurs, état des piles, drops, équipements, services de surfaces et diff local des salles/sondes. Les documents historiques ont été recoupés avec le code et n'ont pas été considérés comme une preuve fraîche.

Contrôles exécutés : `git status --short`, `git rev-parse --short HEAD`, `git diff --stat`, lecture du diff des salles et de la sonde ; extraction PowerShell par expression régulière des lignes publiques des trois catalogues (112 entrées, 28 par classe, 29 effets). C'est une vérification statique des définitions, pas un export Godot ni une validation runtime.

Fichiers préexistants modifiés/non suivis observés : scène de bataille tactique, catalogues/règles des salles, tests des salles, sonde de run, nouvelle IA de salle et son UID, précédent audit non suivi. Des fichiers `tools/tactical_rooms/HarnessProbe.tscn` et `harness_probe.gd` sont apparus pendant la lecture, confirmant un travail simultané. Aucun de ces fichiers n'a été édité par cet audit.

Seul livrable ajouté ici : ce document. Aucun taux de victoire, équilibre de classe ou succès de tests n'est nouvellement revendiqué.
