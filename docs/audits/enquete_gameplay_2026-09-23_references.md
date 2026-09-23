# Enquête gameplay — mécaniques, développeurs et joueurs

Consultation : 23 septembre 2026. Ce dossier remplace la partie benchmark du premier rapport. Les propositions pour Dungeon Draft sont des analyses de conception, pas des intentions attribuées aux studios.

## Méthode et portée

Le corpus compare des systèmes complémentaires plutôt que de prétendre établir un classement mondial : Slay the Spire, Monster Train, Balatro, Wildfrost, Fights in Tight Spaces, Into the Breach, DOFUS, WAKFU, WAVEN, Baldur's Gate 3 et Divinity: Original Sin 2. Les suites et refontes sont distinguées de leurs prédécesseurs. Les personnages d'origine de Larian ne sont pas assimilés à des classes verrouillées.

Trois preuves différentes sont nécessaires : la règle décrit ce qui arrive ; le développeur explique un problème ou une intention ; le joueur décrit une expérience située. Une discussion Reddit ne mesure ni la popularité d'une classe ni son taux de victoire. Un guide de build sélectionne déjà des joueurs et un niveau d'optimisation. Une annonce de refonte ne prouve pas son déploiement.

Les nombres ci-dessous appartiennent aux versions indiquées. Les anciennes refontes servent à comprendre les arbitrages ; elles ne constituent pas une encyclopédie des valeurs live de septembre 2026. Des pages officielles Ankama et plusieurs wikis bloquent l'accès : les relais sont identifiés, et les coefficients non recoupés ne deviennent pas des références d'équilibrage. Les conférences sont étudiées à travers leurs documents accessibles ; aucune vidéo complète n'est présentée comme visionnée.

## 1. Slay the Spire : apprendre à convertir un coût en avantage

### Ironclad — épuisement

**Règle documentée, premier jeu.** Corruption coûte 3 énergies, 2 améliorée : les compétences deviennent gratuites et sont épuisées après utilisation. Feel No Pain fournit 3 blocs, 4 améliorée, par carte épuisée. Dark Embrace ajoute la pioche à cette chaîne. La réserve de compétences diminue réellement : la boucle n'est pas infinie par nature. [Corruption](https://slay-the-spire.fandom.com/wiki/Corruption), [Dark Embrace](https://slay-the-spire.fandom.com/wiki/Dark_Embrace), [Feel No Pain](https://slay-the-spire.fandom.com/wiki/Feel_No_Pain).

**Décomposition.** Sans les autres pièces, Corruption échange la répétabilité future contre du tempo immédiat. Avec protection et pioche, une défense devient aussi une avance dans le deck. Le joueur n'optimise plus seulement « dégâts par énergie » : il choisit quand sacrifier son autonomie future. Une compétence médiocre peut gagner une fonction parce qu'elle devient un combustible.

**Expériences opposées.** Un joueur rapporte le plaisir de réunir le trio après 135 heures ; un autre, après environ 300 heures déclarées, explique perdre parce qu'il épuise ses compétences trop tôt. Les réponses recommandent de raisonner sur la durée du combat. Ce sont deux témoignages, pas deux cohortes statistiques. [Découverte du trio](https://www.reddit.com/r/slaythespire/comments/sfxmwb/), [Difficulté à utiliser Corruption](https://www.reddit.com/r/slaythespire/comments/t1ceya/).

**Transfert à Catabase.** Une pile épuisée technique ne suffit pas. Il faut des cartes qui la paient, des effets qui la récompensent, et des combats qui rendent son timing discutable. Introduire toute la chaîne simultanément empêcherait de savoir quelle partie apporte du plaisir. Commencer par un sacrifice volontaire ponctuel, sans remboursement récursif.

### Silent — la main est un objet de construction

Acrobatics coûte 1 énergie : pioche 3, puis défausse 1 ; l'amélioration augmente la pioche à 4. Tactician et Reflex donnent une fonction à une défausse volontaire. La dépense devient alors sélection, déclenchement et circulation, pas seulement remplacement d'une mauvaise carte. [Acrobatics](https://slaythespire.wiki.gg/wiki/Acrobatics), [discussion de joueurs sur le moteur Acrobatics/Tactician](https://www.reddit.com/r/slaythespire/comments/1rurdou/going_infinite_w_acrobatics_tactician/).

Le bénéfice dépend du moment : payer pour voir des cartes n'aide pas si on ne peut plus payer celles qu'on découvre. Les discussions sur Acrobatics soulignent cette tension avec les faibles réserves d'énergie du début de run. [Discussion sur sa valeur](https://www.reddit.com/r/slaythespire/comments/1fq5dn1/), [Débat à trois énergies](https://www.reddit.com/r/slaythespire/comments/1d4gnd4/).

**Analyse.** Le sentiment de maîtrise vient de la réduction intentionnelle de l'incertitude. Une carte de pioche peut être mauvaise immédiatement mais essentielle à un moteur plus tard. Catabase possède recomposition et rétention, mais son catalogue ne leur donne pas encore des familles de déclencheurs comparables. La priorité est d'ouvrir ce choix sans rendre chaque tour deux fois plus long.

### Watcher — un changement d'état peut porter toute une classe

Rushdown fait piocher 2 cartes à l'entrée en Wrath. Quitter Calm rend 2 énergies. Avec une entrée en Calm à 1, une entrée en Wrath à 1 et un deck suffisamment réduit, le coût net de la paire peut être nul. Vigilance non réduite ne remplit pas cette condition. [Rushdown](https://slay-the-spire.fandom.com/wiki/Rushdown), [décomposition communautaire de la boucle](https://www.reddit.com/r/slaythespire/comments/jwup6b/).

Des joueurs apprécient la puissance et la régularité du changement de posture ; d'autres décrivent Rushdown comme une direction tellement favorisée qu'elle réduit les décisions de construction. [Discussion quotidienne, novembre 2023](https://www.reddit.com/r/slaythespire/comments/185vjtg/).

**Analyse.** Trois éléments se renforcent : ressource, accès aux cartes, dégâts. Ce triangle explique davantage la puissance que le coefficient d'une attaque. Pour une posture d'Achille, ne pas rembourser à la fois son coût et la carte utilisée à chaque transition. Préserver une sortie défensive, un coût visible et un plafond de déclenchements.

### Ce que disent les créateurs

Anthony Giovannetti présente en 2019 une pratique combinant métriques, retours actifs et tests avec des joueurs experts. Les données constituent une preuve à interpréter, pas une conclusion automatique. Le but est de donner une place aux cartes sans laisser certaines déformer tout le jeu. L'entretien IGF de 2020 décrit des années de tests, une forte sélection parmi les idées et l'importance d'adversaires qui éprouvent les decks de différentes façons. [Support GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf), [Entretien des créateurs, 2020](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-mega-crit-games-i-slay-the-spire-i-).

**Actualisation distincte.** En avril 2026, Mega Crit décrit Slay the Spire 2 comme un chantier d'accès anticipé, avec équilibrages expérimentaux en bêta avant intégration à la branche principale. Le studio explique aussi que prolonger indéfiniment une run rend la construction moins intéressante à ses yeux. Ce propos concerne leur système, pas une interdiction universelle du mode infini. [Communication officielle d'avril 2026](https://www.megacrit.com/news/2026-4-17-neowsletter-issue-21/).

**Conséquence pour l'audit.** Une carte à faible taux de sélection peut être mal présentée, trop tardive, dépendante d'une pièce rare ou réellement faible. Il faut distinguer ces cas avant de monter ses dégâts.

## 2. Monster Train : changer la valeur de la mort et de la position

Little Fade, branche Fire Light du premier Monster Train, transforme sa mort en amélioration des alliés de son étage, avec application de Burnout. Reform permet de la rejouer ; un ensemble de morts trop encombré rend le retour moins fiable. La résurrection conserve des améliorations, ce qui rend la répétition structurante. [Fiche Little Fade](https://monster-train.fandom.com/wiki/Little_Fade), [description du clan et de Reform](https://www.neoseeker.com/monster-train/walkthrough/Clans-Melting_Remnant).

**Séquence conceptuelle.** Déployer Fade en première ligne → accepter sa mort → renforcer l'arrière → la reformer → recommencer avant que Burnout n'éteigne l'étage. La place, la survie, la sélection des unités et le cycle des cartes contribuent à la même stratégie. La mort n'est plus une erreur ; une mort non récupérable le reste.

Des joueurs détaillent l'importance de la régularité de Reform et des unités qui exploitent les buffs ; d'autres racontent avoir initialement rejeté Fade avant de comprendre son intérêt. [Construction Fire Light](https://www.reddit.com/r/MonsterTrain/comments/oxkbpm/), [Changement d'appréciation](https://www.reddit.com/r/MonsterTrain/comments/16wm6yi).

**Limite de transfert.** Catabase est centré sur un héros. Importer une économie de morts alliées impose des unités supplémentaires, leurs tours, leur sélection et une interface. Une alternative plus légère serait un objet destructible du héros dont la destruction produit un effet, avec durée et quantité plafonnées. Ce serait une nouvelle règle, pas un simple sort de zone.

**Suite séparée.** Mark Cooke explique que Monster Train 2 introduit notamment équipement, cartes de salle, compétences d'unités, phase de déploiement et annulation du tour ; certaines évolutions s'accommodaient mal de l'architecture du premier jeu. [Entretien direct, 2025](https://www.gamepressure.com/newsroom/shiny-shoe-ceo-mark-cooke-explains-why-monster-train-needed-a-seq/zd8975).

**Analyse.** Une carte de salle modifie l'endroit où les autres cartes deviennent fortes. C'est une piste plus proche de notre plateau que l'ajout de trois invocations génériques. L'annulation enseigne aussi les interactions : elle autorise une exploration que la peur d'une erreur irréversible peut bloquer.

## 3. Balatro : les mises à jour révèlent ce qui doit rester agréable

Dans son annonce 1.0.1f de mai 2024, LocalThunk remplace la hausse du prix des packs d'Orange Stake par des Jokers périssables, et le malus de taille de main de Gold Stake par des Jokers à loyer. Le premier magasin garantit un pack Buffoon. Blue Seal produit la planète de la dernière main jouée ; Hanging Chad répète la première carte deux fois au lieu d'une ; Vampire gagne X0,1 au lieu de X0,2 par amélioration absorbée, sur cartes qui scorent. [Annonce du créateur et réactions](https://www.reddit.com/r/balatro/comments/1chqrqg/).

**Analyse.** Ces changements portent sur plusieurs leviers distincts : accès aux moteurs, entretien économique, temporarité et fiabilité de la croissance. Ils ne se résument pas à rendre le jeu plus facile. La main finale devient une décision de progression future. Le joueur peut choisir une action sous-optimale pour le score immédiat parce qu'elle nourrit son build.

**Application.** La récompense de notre premier combat ne devrait pas être examinée seulement en quantité moyenne. Il faut savoir si elle permet au joueur d'exprimer une direction. Une carte à entretien ou à durée limitée pourrait créer un vrai arbitrage ; ajouter un malus permanent à la main risquerait surtout de réduire les actions intéressantes disponibles.

## 4. Wildfrost : la maîtrise du calendrier et son point de rupture

Snoffel a 3 PV, un compteur de 4 et applique 1 Snow à tous les ennemis. Snow bloque la diminution du compteur. Augmenter l'application ou diminuer le compteur peut donc fermer durablement la fenêtre d'action adverse ; les résistances et les menaces qui agissent avant le premier déclenchement comptent. [Snoffel](https://wildfrostwiki.com/Snoffel), [Counter](https://wildfrostwiki.com/Counter), [Snow](https://wildfrostwiki.com/Snow).

Des joueurs célèbrent des versions à compteur 1 comme pratiquement impossibles à perdre. Cela documente une satisfaction de construction mais aussi la disparition de la réponse adverse. [Témoignages sur Snoffel](https://www.reddit.com/r/wildfrostgame/comments/1dbne2w).

La mise à jour 1.0.5 de juin 2023 ajoute notamment la consultation de l'ordre des actions, la possibilité de passer des récompenses et des explications supplémentaires sur les réactions. [Notes officielles relayées par SteamDB](https://steamdb.info/patchnotes/11396384/).

**Analyse.** La lisibilité est une mécanique de maîtrise. Si le joueur ignore ce qui se déclenche avant quoi, un échec paraît arbitraire. Pour Catabase, une case de glace, un ralentissement et une stase doivent annoncer précisément leur prochain effet, leur cible et leur échéance. Les immunités de boss ne doivent pas annuler silencieusement la promesse du build.

## 5. Into the Breach et Fights in Tight Spaces : les dégâts ne suffisent pas à décrire une action

### Into the Breach

Titan Fist inflige 2 dégâts et pousse d'une case. Ses améliorations proposent une charge pour 2 cœurs ou +2 dégâts pour 3. Les discussions opposent l'utilité immédiate des dégâts à une charge jugée chère et situationnelle. [Fiche de l'arme](https://intothebreach.fandom.com/wiki/Titan_Fist), [Discussion d'avril 2024](https://www.reddit.com/r/IntoTheBreach/comments/1bwf563).

**Analyse de situation.** Une poussée peut tuer par collision, sortir une cible de son axe d'attaque ou déplacer une menace vers une autre unité. Il faut donc mesurer « objectifs sauvés » et « attaques neutralisées », pas seulement PV retirés. Une amélioration changeant la géométrie peut rester inutile si les cartes n'offrent jamais le bon espacement. Catabase doit tester ses déplacements dans les salles réelles, pas dans une arène vide.

### Fights in Tight Spaces

Dans leur retour de production, James Parker et Paul Kilduff-Taylor décrivent l'interdépendance du deck, du momentum, des PV et du placement. Ils expliquent avoir demandé vidéos, questionnaires et échanges directs pour identifier frustration et ennui, puis avoir re-testé l'expérience avec de nouveaux joueurs avant la sortie. Les joueurs experts de l'accès anticipé ne suffisaient pas à évaluer le tutoriel. [Retour des créateurs, janvier 2022](https://www.gamedeveloper.com/game-platforms/familiarity-novelty-and-communication-how-fights-in-tight-spaces-survived-early-access).

**Analyse.** Cette référence est particulièrement proche de notre combinaison cartes/grille. Une carte n'ajoute de profondeur que si elle modifie un arbitrage entre systèmes. Une nouvelle animation pour la même frappe n'en ajoute pas. Une attaque qui impose de terminer contre un mur change la valeur des déplacements, des ennemis et de la main suivante.

## 6. Ce que ces références permettent réellement de conclure

| Observation | Inférence de conception | Ce qu'elle ne prouve pas |
|---|---|---|
| Les moteurs convertissent une ressource en une autre | Donner une utilité secondaire à défausse, position, dommage subi | Que toutes les classes doivent avoir une jauge |
| Des joueurs aiment réussir des combinaisons excessives | Préserver des tours culminants mémorables | Qu'un verrou permanent améliore la rejouabilité |
| Des développeurs corrigent l'accès et les explications | Mesurer la possibilité de comprendre et construire | Que réduire tous les coûts résout le problème |
| Les refontes changent aussi les contreparties | Comparer le risque et le temps d'installation | Qu'une ancienne valeur est transposable aujourd'hui |
| Les retours experts et débutants divergent | Segmenter les tests par expérience | Qu'un expert représente toute l'audience |

Une classe réussie permet au joueur de raconter une décision : « j'ai dépensé ma défense pour finir », « j'ai construit le retour du disque », « j'ai gardé la carte nécessaire au tour suivant ». Le nombre de sorts intervient ensuite pour renouveler ces décisions.
