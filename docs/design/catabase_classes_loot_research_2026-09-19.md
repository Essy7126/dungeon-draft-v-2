# Catabase — identité, cartes et butin de run

Étude et propositions du 19 septembre 2026. Aucun changement de gameplay dans cette passe. Les règles, cartes, objets et chiffres proposés ne sont pas équilibrés ni implémentés. Les comparaisons portent sur des principes de conception documentés, avec leur version précisée, pas sur la méta actuelle de chaque jeu.

## Le changement de direction

Le joueur choisit une manière de commencer, puis découvre ce qu'il peut devenir. Il possède un personnage fonctionnel et un deck choisi au départ, mais aucun équipement. Les combats fournissent un butin acquis : équipements, cartes, runes et consommables. Tout rejoint l'inventaire de la run, sans devoir sélectionner une récompense unique. On décide ensuite quoi équiper, jouer, conserver et vendre.

Le problème actuel est visible dans `core/expedition/catabase_cards.gd` : les six départs partagent beaucoup de familles ; `eligible_pool()` consulte encore `session.build.catalog.card_spell_ids()`, filtre les branches découvertes et certains prérequis comme l'Urne. `upgrade_offers()` consulte les offres de l'ancien build. `grant_loot()` utilise ce même univers filtré. La collection, les copies, la défausse, les reçus de butin et la revente sont des fondations utiles ; **le catalogue et les règles d'accès ne correspondent plus à la direction demandée**.

L'état consulté comprend déjà les modifications locales du parcours progressif du 19 septembre. Elles sont conservées. Le README indique désormais vingt profondeurs, douze combats et trois refuges : les anciens calculs fondés sur quinze combats ne doivent plus servir de budget implicite.

## Ce que les jeux cités nous apprennent

| Jeu et source | Organisation documentée | Application proposée | Limite à respecter |
|---|---|---|---|
| **Baldur's Gate 3**, [Larian, juillet 2023](https://baldursgate3.game/news/community-update-21-forging-your-legacy_77) | Classes, sous-classes, multiclassage lors des niveaux, possibilité de reconstruire son personnage | Donner une identité reconnaissable, puis des occasions explicites de bifurquer | Une run courte ne peut pas attendre plusieurs heures avant que la spécialisation fonctionne |
| **Dofus**, [devblog 2.9 de Seyroth reproduit par JeuxOnline, décembre 2012](https://dofus.jeuxonline.info/actualite/38150/devblog-nouveaux-objets-29) | Objets spécialisés avec malus ; petites panoplies laissant des emplacements libres ; attention aux cumuls de PA | Des objets adaptés à un plan de jeu, de petits ensembles et des sacrifices visibles | « Meilleur niveau » ne doit pas signifier « meilleur pour tous les personnages » |
| **Dofus Temporis VII**, [règles Ankama](https://support.ankama.com/hc/fr/articles/6328612328721--DOFUS-Temporis-VII-Osatopia) | Cette édition distribue des équipements et trophées sur les monstres ; équipements et kamas ne sont pas transférables à la fin | Référence pertinente pour une richesse limitée à une aventure | C'est une édition temporaire spécifique, pas une description générale du drop de Dofus classique |
| **Waven**, [présentation Ankama sur Steam](https://store.steampowered.com/app/2343650/) | Combinaison de héros, sorts, équipements et compagnons ; gains de sorts et d'équipements en jouant | Faire interagir plusieurs systèmes de construction au lieu de faire monter seulement les nombres | La collection persistante d'un jeu de longue durée ne donne pas le bon rythme pour notre run |
| **Wakfu**, [notes de bêta 1.64 relayées par MethodWakfu](https://methodwakfu.com/accueil/actualites/serveur-beta/beta-1-64/) | Châsses, enchantements, destruction d'équipement en éclats, combinaisons ouvrant des sublimations | Séparer l'objet trouvé et sa transformation par une rune | Ne pas importer toute une économie de recyclage et de rerolls dans douze combats |
| **Divinity: Original Sin 2**, [éditeur de la Definitive Edition](https://en.bandainamcoent.eu/divinity-original-sin-2/divinity-original-sin-2-definitive-edition) | Construction sans classes imposées, synergies de capacités et interactions entre surfaces élémentaires | Une découverte extérieure peut enrichir le personnage grâce à des règles partagées | Une liberté totale peut diluer la lecture de la classe si elle n'a aucun mécanisme propre |
| **The Last Spell**, [Matthieu Richez, directeur créatif, décembre 2022](https://blog.playstation.com/2022/12/13/tactical-roguelite-the-last-spell-is-coming-to-playstation/) | Héros sans classes, compétences déterminées par les armes, choix de perks variables, préparation entre les nuits | Une arme ou un passif trouvé peut ouvrir une nouvelle construction ; séparer bataille et gestion | Ses déblocages entre runs et son équipe de héros ne sont pas notre contrat de progression |

Les sites directs de Dofus et Wakfu ont refusé certaines consultations. Les deux relais indiqués sont donc identifiés comme tels ; ils documentent des versions historiques, sans certifier les chiffres de 2026.

Un retour de conception particulièrement utile vient des **annonces de refonte de Waven** : en août 2025, Ankama explique vouloir réduire les descriptions opaques et la redondance des catalogues de classes, en conservant un noyau propre aux héros et davantage de sorts communs. C'est une intention de refonte publiée, pas une preuve de son déploiement actuel. Notre enseignement : conserver l'identité sans fabriquer des dizaines de catalogues hermétiques. [Community Update #2, annonces officielles](https://steamcommunity.com/app/2343650/announcements/?l=french).

## Une identité à plusieurs niveaux, avec une fonction pour chaque choix

L'exemple du joueur devient : **Passe-rive → Assassin → Hadès → culte du Styx**.

| Choix | Question | Fonction recommandée |
|---|---|---|
| Personnage / apparence : Passe-rive | Qui est-ce que j'incarne ? | Identité visuelle et narrative. Passe-rive est actuellement une apparence : ne pas lui attribuer silencieusement une classe obligatoire |
| Classe : Assassin | Comment est-ce que je gagne mes combats ? | Mécanisme principal, forces/faiblesses, huit cartes accessibles au départ |
| Patron : Hadès | Quel pouvoir transforme ma façon de combattre ? | Une règle active sur le plateau, quatre cartes supplémentaires |
| Culte : Styx | Quelle variante de ce pouvoir ai-je choisie ? | Une transformation avec contrepartie, trois cartes supplémentaires |
| Deck initial | Quelles réponses est-ce que je prépare ? | Choix dans ces quinze cartes distinctes ; pas de suite rang I → II → III obligatoire |

Les cultes sont ici des créations pour notre fiction. Ils peuvent être proposés dans un ordre hiérarchique à l'écran tout en restant des modules réutilisables dans les données. On peut garder certaines associations exclusives si elles portent un sens narratif ; il faut les nommer, pas les multiplier automatiquement.

**Je déconseille trois jauges différentes et trois lignes de +10 %.** Une classe fournit un mécanisme ; la divinité ajoute une interaction ; le culte transforme cette interaction. Les contreparties peuvent porter sur le temps, les cibles ou les possibilités, pas forcément sur une baisse supplémentaire de statistiques.

Exemple expérimental :

- **Assassin — proie isolée** : la première attaque directe de son tour contre un ennemi sans allié ennemi sur une case orthogonalement adjacente gagne 25 % de dégâts. Contrepartie candidate : 10 % de PV maximum en moins. L'aperçu indique si la cible est isolée.
- **Hadès — vestiges** : le premier impact direct du tour dépose un vestige sur une case libre adjacente à la cible. Emplacement prévisualisé, maximum deux vestiges, durée deux activations. Certaines cartes les déplacent ou les consomment ; les cartes doivent conserver un usage sans vestige. Pas besoin d'une élimination pour fonctionner contre un boss.
- **Styx — sillage** : consommer un vestige laisse un sillage sur cette case jusqu'au prochain tour. Le premier ennemi qui y entre perd 1 PM, une fois par sillage. Contrepartie : les vestiges ne durent plus qu'une activation. On joue un placement plus immédiat. Ce culte ne reçoit aucun avantage automatique parce qu'on a choisi la barque.

L'assassin d'Hadès peut ainsi devenir un exécuteur qui dépense ses vestiges, un contrôleur des passages, ou un harceleur qui les utilise pour se déplacer. Le culte ne suffit pas à déterminer tout le deck.

## Quinze vraies cartes candidates pour cet exemple

Coûts et effets de prototype. Toutes sont utilisables sans équipement ; les attaques sont des techniques de classe, sans prérequis « posséder une dague ». Les effets de placement respectent le terrain, les unités et les immunités affichées. Un déplacement réussi n'interrompt pas implicitement n'importe quel sort ennemi.

| Origine | Carte | PA | Fonction dès sa version de base |
|---|---|---:|---|
| Assassin | **Frappe dérobée** | 2 | Attaque de contact, puis déplacement facultatif d'une case libre ; choisir de s'exposer ou de repartir |
| Assassin | **Détour** | 1 | Se déplacer de deux cases maximum par un chemin praticable ; pas de dégâts ni de téléportation à travers un mur |
| Assassin | **Séparer la proie** | 2 | Pousser une cible adjacente d'une case ; dégâts modestes, mais possibilité de créer son isolement |
| Assassin | **Entaille persistante** | 2 | Dégâts réduits et saignement pendant deux activations de la cible ; ne se cumule pas avec lui-même |
| Assassin | **Achever** | 3 | Attaque directe renforcée sous 35 % de vie ; reste une attaque normale au-dessus du seuil |
| Assassin | **Poudre d'ombre** | 2 | Une case de brume bloque les lignes de vue jusqu'au prochain tour, y compris celles du joueur |
| Assassin | **Attendre le passage** | 2 | Préparer une frappe : le premier ennemi entrant au contact avant le prochain tour la déclenche, une fois |
| Assassin | **Rupture de rythme** | 2 | Attaque faible ; retire 1 PA à la prochaine activation de la cible, une seule application par cible |
| Hadès | **Rappel des traces** | 1 | Déplacement personnel d'une case ; si un vestige libre est à portée 3, possibilité de le rejoindre et le consommer |
| Hadès | **Sépulture provisoire** | 2 | Petite garde ; consommer un vestige adjacent renforce la garde, jusqu'au prochain tour |
| Hadès | **Dîme funèbre** | 2 | Attaque à courte portée ; consommer un vestige adjacent à la cible applique une vulnérabilité d'un tour, non cumulative |
| Hadès | **Déplacer les restes** | 1 | Tirer un ennemi d'une case ; déplacer aussi un vestige d'une case libre permet de préparer un passage |
| Styx | **Courant contrarié** | 2 | Pousser ou attirer d'une case au choix ; si la cible traverse un sillage, prolonger celui-ci jusqu'au prochain tour, une fois |
| Styx | **Ancre de serment** | 1 | Résister au prochain déplacement forcé jusqu'au prochain tour ; empêche aussi le prochain déplacement personnel volontaire tant que l'ancrage est actif |
| Styx | **Traversée interdite** | 3 | Une ligne de trois cases maximum ralentit d'1 PM le premier adversaire qui la traverse ; le joueur perd également 1 PM s'il la franchit. Une ligne active maximum |

Chaque carte doit changer une décision identifiable : cible, position, moment, protection, priorité ennemie. Si deux cartes produisent toujours le même choix avec seulement deux nombres différents, une seule famille suffit.

Les améliorations viennent ensuite modifier le contrat : Frappe dérobée gagne une portée de déplacement **ou** un bonus si l'on reste au contact ; Poudre d'ombre dure plus longtemps **ou** peut être dissipée par le joueur. Les deux options ne doivent pas être une étape obligatoire pour que la carte soit intéressante.

Trois compositions initiales possibles, dix cartes chacune en conservant la règle actuelle de deux exemplaires maximum :

| Plan | Cinq cartes en deux exemplaires | Fragilité à montrer avant départ |
|---|---|---|
| Exécuteur mobile | Frappe dérobée, Séparer la proie, Achever, Détour, Sépulture provisoire | Peu de portée et de contrôle à distance |
| Assassin d'usure | Entaille persistante, Poudre d'ombre, Rupture de rythme, Détour, Sépulture provisoire | Éliminations lentes ; vulnérable à une pression qui oblige à bouger |
| Gardien du sillage | Attendre le passage, Déplacer les restes, Courant contrarié, Dîme funèbre, Rappel des traces | Dépend du placement ; les ennemis à distance peuvent refuser les passages préparés |

Le joueur avancé peut composer dix cartes avec un mélange de simples et de doublons. Les cinq paires sont des exemples lisibles, pas une obligation de construction. Afficher coût moyen, réponses à distance, mobilité et défense comme informations, jamais comme interdictions arbitraires.

## Comment créer beaucoup de choix sans fabriquer du remplissage

Quatre classes candidates : Assassin (isolement), Gardien (interception et riposte), Arpenteur (distance et trajectoires), Thaumaturge (surfaces et préparation). Trois patrons candidats : Hadès, Perséphone et Hécate ; trois cultes candidats : Styx, Léthé, Phlégéthon. Leurs règles restent à concevoir en dehors de l'exemple détaillé ci-dessus.

Si toutes les associations sont compatibles : quatre classes × trois patrons × trois cultes = **36 identités de départ**. Quinze cartes écrites séparément pour chaque identité exigeraient 540 cartes. Avec huit cartes par classe, quatre par patron et trois par culte : `4×8 + 3×4 + 3×3 = 53` cartes pour offrir quinze choix par association. Ce calcul mesure un volume de contenu, pas 36 builds équilibrés. Les interactions entre modules devront être testées.

Choisir cinq cartes distinctes parmi quinze donne 3 003 ensembles avant même les doublons et l'équipement. Ce nombre n'a de valeur que si les cartes posent des problèmes différents. Commencer par une classe avec trois cultes et plusieurs decks réellement distincts permet de vérifier cette richesse avant d'étendre le catalogue.

## Départ sans objets : conséquence sur le combat et l'arme

Le départ proposé donne **zéro équipement, zéro rune, zéro relique, zéro consommable**. Les connaissances de départ et le deck constituent le personnage. La première salle doit être équilibrée pour cet état.

Il faut donc abandonner la dépendance actuelle à une arme sélectionnée pour obtenir ses deux gestes indispensables. Deux actions de secours de classe, modestes et fixes, restent disponibles sans arme. Une arme trouvée modifie le geste offensif et apporte un profil statistique ou une interaction. Elle n'efface ni la classe ni les cartes acquises.

Les premiers sorts doivent tous fonctionner sans objet particulier. Plus tard, un tir exclusivement lié à l'arc peut demander un arc, à condition que ce prérequis soit visible avant de l'ajouter au deck. La fiche doit distinguer « équipable », « carte jouable » et « synergie active ».

Six emplacements d'équipement pour commencer : **arme, tête, torse, ceinture, pieds, bijou**. Les reliques possèdent leurs emplacements distincts, obtenus pendant la run. Éviter d'ouvrir immédiatement douze cases vides et six nouveaux types de monnaies.

## Des objets conçus pour des stratégies, pas seulement pour des étiquettes

Tous les effets ci-dessous sont candidats. Au niveau 1, un objet comporte une base simple et au plus un effet distinctif ; les malus accompagnent les bénéfices significatifs. Les déclenchements ont une limite explicite et ne se réactivent pas sur leurs propres effets secondaires.

| Objet, emplacement | Effet proposé | Intérêt au-delà de la classe annoncée |
|---|---|---|
| Dague d'os, arme niv. 1 | Premier impact contre une cible isolée : +20 % dégâts ; dégâts du geste de base plus faibles qu'une épée | Assassin ; aussi un Gardien capable d'écarter une cible |
| Épée du veilleur, arme niv. 1 | Première frappe après une absorption ennemie de garde : +4 dégâts | Gardien ; assassin défensif possédant Sépulture provisoire |
| Arc de roseau, arme niv. 1 | Geste de base à distance, inutilisable au contact ; pas de changement imposé au deck | Arpenteur ; assassin qui élimine ses cibles depuis la brume |
| Sandales de traverse, pieds niv. 1 | Premier déplacement volontaire après une élimination : une case ne coûte pas de PM | Mobilité, exécution ; ne se cumule pas à chaque victime d'une zone |
| Bottes lestées, pieds niv. 1 | Réduit d'une case le premier déplacement forcé subi par tour ; −1 PM au premier tour | Utile sur la barque pour plusieurs classes ; coût réel sur terrain ouvert |
| Ceinture des restes, ceinture niv. 1 | Un vestige supplémentaire peut rester au sol ; aucun allongement de durée | Forte synergie Hadès, bonus dormant sur d'autres personnages, toujours vendable |
| Coiffe du guetteur, tête niv. 1 | Première attaque sur une cible n'ayant aucun allié adjacent : ignore 8 armure | Toute classe pouvant fabriquer une cible isolée |
| Tunique du reclus, torse niv. 1 | +12 PV maximum ; −5 % dégâts directs | Solution provisoire pour survivre, à remplacer ou conserver selon le plan |
| Anneau des retours, bijou niv. 2 | Après avoir consommé un vestige, déplacer une carte de la défausse au sommet ; une fois par combat | Prépare un prochain tour, sans boucle de pioche immédiate |

Ne pas convertir automatiquement un drop extérieur en monnaie. Voir un objet incompris, le conserver, puis trouver la carte qui l'exploite fait partie de la découverte. Les objets ordinaires restent généralement équipables ; quelques effets spécifiques peuvent être dormants. Éviter que la majorité du butin affiche « mauvaise classe ».

Les panoplies peuvent avoir un bonus à **deux pièces**, puis un troisième effet optionnel. Pas de bonus de six pièces nécessaire pour rendre la mécanique jouable. Une bonne pièce étrangère doit pouvoir rivaliser avec la pièce qui termine un ensemble. Le total de PA/PM et ses seuils doit rester sous contrôle : +1 PA peut ouvrir un enchaînement entier, pas seulement représenter un petit pourcentage de dégâts.

## Runes, reliques et cartes étrangères : trois fonctions distinctes

**Rune** : modifie un objet équipé. Première version : une châsse universelle par objet éligible, coût de déplacement faible ou nul entre combats. Trois exemples : première application de saignement prolongée d'un tour ; première poussée après une garde +1 case ; premier vestige consommé donne 6 garde. Pas de couleurs, rerolls aléatoires et qualité de châsse à optimiser simultanément. On peut vendre une rune non utilisée. Une rune sertie reste récupérable avant vente ; l'interface chiffre précisément le contenu vendu.

**Relique** : transforme une règle de la construction. Exemple « Pacte du retour » : la première carte consommant un vestige revient au sommet de la pioche, mais s'épuise à sa seconde utilisation. Même ici, pas de récompense qui dépend de dizaines de dégâts sans lecture possible. Une relique peut ouvrir une spécialisation, mais aucune relique précise ne doit être nécessaire pour faire fonctionner le départ.

**Carte étrangère** : arrive en réserve et conserve son identité. Proposition : effet de base utilisable par tous, effet spécialisé exigeant un mécanisme ou un équipement clairement indiqué. « Rempart de pétales » fournit de la garde à l'assassin ; sa conversion des soins excédentaires en protection n'agit que s'il possède cette autre mécanique. Quelques rites exclusifs peuvent rester inutilisables, avec leur condition affichée et un prix de vente ; ils ne doivent pas remplir la majorité du butin.

Trois politiques sont possibles : accès strict par classe, très lisible mais produisant beaucoup de butin destiné uniquement à la vente ; accès totalement libre, excellent pour les hybrides mais risquant d'effacer les classes ; accès aux effets de base avec synergies conditionnelles, recommandé ici. Il faut comparer cette dernière politique à quelques restrictions fortes et explicites, plutôt que transformer chaque carte en une description à cinq exceptions.

Exemple de pivot : l'assassin trouve une carte de soins et un bijou transformant une partie du soin excédentaire en garde. Garder sa spécialité d'isolement devient compatible avec une stratégie de riposte. Il n'a pas besoin de racheter un arbre entier ni de changer de classe pour essayer deux cartes.

## Fin de combat et inventaire

Le résultat du combat doit d'abord être un **reçu de tout ce qui est gagné** : XP, oboles, équipements, runes, cartes, consommables. Illustration, quantité, niveau et rareté visibles. Survol ou focus clavier/manette : description, conditions, effet réel sur le personnage, comparaison avec l'objet porté et prix de vente.

Le gain est acquis et sauvegardé une seule fois à la victoire. Fermer la fenêtre ne détruit rien et rouvrir le reçu ne redonne rien. Les cartes vont en réserve ; aucun ajout automatique au deck. Un sac plein ne doit pas jeter du butin : réserve de run suffisante ou débordement consultable.

Si le combat donne un niveau : reçu → bouton « Niveau gagné : répartir mes points » → caractéristiques et spécialisation → retour au reçu ou à l'inventaire → Seuil / salle / carte. Le niveau ne fabrique plus une nouvelle carte gratuite hors de ce butin. Une amélioration de carte éventuellement accordée au niveau doit être un budget explicite, distinct de l'acquisition d'une copie.

Dans l'inventaire : onglets Équipements / Cartes / Runes / Consommables / Reliques ; filtres Nouveaux / Équipables / Synergies / Favoris / À vendre. Le filtre « synergie » explique ce qui s'active ; il ne décide pas de la valeur de l'objet à la place du joueur.

Les choix « équiper », « ajouter au deck » et « vendre » sont explicites. Aucun objet n'est équipé automatiquement parce que son score est supérieur. Le menu Caractéristiques rassemble classe, patron, culte, statistiques détaillées, déclenchements, équipement et deck.

## Une économie limitée à la run

Tout le butin matériel vient des combats pour cette proposition. Les marchands achètent les trouvailles et proposent des services — soin, déplacement de rune, amélioration ciblée — mais pas de catalogue permettant de reconstituer automatiquement son build idéal. Une variante avec un stock marchand limité pourra être comparée plus tard ; elle modifierait le principe « tout se drop ».

« Toujours vendable » signifie que tous les drops ont une valeur et qu'un marchand les accepte, même hors classe. La vente peut être préparée depuis l'inventaire, puis réalisée à la halte. Les cartes de départ, accordées gratuitement à chaque tentative, n'ont pas de valeur de revente ; les copies trouvées en ont une. Une copie active ou un objet porté peut être déséquipé puis vendu ; favoris protégés, montant total annoncé.

Trois refuges sur la route rendent la distance au premier acheteur importante. Proposition : **un acheteur garanti au premier carrefour**, avant une longue section sans halte, puis les services des refuges existants. Aucune vente forcée dès la fin du combat. Si le stockage devient le principal temps de jeu, réduire le nombre d'objets et améliorer le tri avant d'ajouter des systèmes de recyclage.

Fin de run : objets, cartes trouvées, runes et oboles disparaissent. Le codex peut mémoriser les découvertes et les anciennes constructions sans donner un avantage statistique à la tentative suivante. Les cartes du catalogue de départ sont des choix initiaux, pas un coffre d'équipement persistant.

## Combien de butin dans notre run ?

Hypothèse de travail avec **douze combats**, à confirmer sur chaque chemin réel. Début : deux équipements par combat sur les trois premiers combats ; ensuite un par combat. Total : quinze équipements. Ajouter environ douze cartes, quatre runes et quatre consommables répartis sur la run donne **35 objets examinables**, avant d'éventuelles reliques qui devraient remplacer certains tirages plutôt que gonfler indéfiniment le volume.

Ne pas confondre profondeur de la carte, rang du combat et niveau du personnage. Le niveau du butin dépend de la difficulté et du budget du segment. Les premiers combats donnent principalement du niveau 1 ; les suivants ouvrent des paliers plus puissants. Un objet rare peut aussi apporter une règle, pas uniquement davantage de statistiques. Éviter quinze obsolescences successives où chaque nouvelle paire de bottes remplace mécaniquement la précédente.

Calcul exact pour des équipements indépendants et six emplacements équiprobables :

- Après six drops, il reste **33,49 %** de chances de n'avoir reçu aucune arme.
- Après quinze drops, la probabilité d'avoir trouvé au moins un objet dans chacun des six emplacements est seulement **64,42 %**.
- En moyenne, quinze drops remplissent **5,61 types d'emplacements**, sans garantie sur les synergies.

Calcul Python avec `math.comb` : absence d'un type `(5/6)^k` ; présence des six `Σ[j=0..6] (−1)^j C(6,j)((6−j)/6)^k`. Ce modèle uniforme n'est pas un simulateur de combat. Il démontre pourquoi « beaucoup de loot aléatoire » ne garantit pas une progression agréable.

Proposition de protection du départ : première victoire = une arme garantie, de type aléatoire, plus un équipement ; les deux rencontres suivantes favorisent les emplacements encore vides, sans garantir le meilleur objet pour la classe. Toutes les armes ordinaires peuvent fournir un geste utilisable. Le reste du butin accepte doublons et objets décalés.

Pour les cartes, un tirage expérimental peut mélanger **50 % de contenu du biome, 35 % de synergies avec l'identité de départ, 15 % de découvertes globales**. Ce sont des poids de sélection de tables, pas une garantie de compatibilité finale : les tables peuvent se recouper. Aucune exclusion automatique d'une famille étrangère. L'offre d'un combat se fige indépendamment de l'ouverture de l'inventaire, sans reroll en changeant d'objet.

## La carte de run devient aussi une carte des occasions de construction

| Chemin | Menaces envisagées | Objets / cartes qu'on peut espérer | Choix stratégique |
|---|---|---|---|
| Porte, brume et ossements | Écran de mêlée, archers, salves | Armure, arc, interruption, isolement | Chercher une protection physique ou les moyens d'atteindre l'arrière |
| Puits, profondeurs | Magie, surfaces, malus | Résistance magique, purification, amplification de surfaces | Chercher une correction à sa fragilité ou pousser une construction élémentaire |
| Barque et eaux | Passages étroits, déplacement forcé, menaces latérales | Ancrage, trajectoires, traction, objets liés aux vestiges | Préparer le contrôle spatial ou risquer un chemin défavorable pour son butin |

Ce sont des poids et des familles annoncés, jamais un objet exact promis à chaque salle. Un assassin du Styx doit pouvoir choisir la porte pour obtenir une arme ou vendre du matériel ; il ne doit pas être condamné à prendre la barque.

Le chemin le plus long offre plus de combats et donc plus de tirages. Il faut comparer les budgets **entre deux carrefours**, incluant XP, objets, or, usure et services accessibles. Davantage de tirages peut augmenter les chances de trouver une synergie même à valeur marchande égale : suivre aussi ce bénéfice, pas seulement la somme des prix.

## Trois histoires possibles pour un même départ

1. **Spécialisation** : bottes de déplacement, dague et carte d'exécution. Le joueur conserve un deck court, vend les objets défensifs et cherche un chemin donnant davantage d'accès aux cibles isolées.
2. **Hybridation** : épée du veilleur, garde et rune de poussée. Il conserve son bonus d'assassin mais construit l'isolement par la défense et les déplacements ennemis. La carte Attendre le passage prend de la valeur.
3. **Adaptation contrariée** : aucune synergie offensive immédiate, mais une protection magique et un consommable. Il choisit le puits, conserve ses cartes de base, vend un bijou dormant et investit dans un soin. La run reste jouable sans prétendre que ce départ est aussi favorable que les deux autres.

La difficulté doit faire payer les erreurs de préparation ou de combat, tout en rendant lisible le rôle du hasard. Une absence d'objet indispensable n'est pas une décision ratée par le joueur. Les défis peuvent améliorer un tirage ou imposer une menace annoncée à la prochaine salle ; pas de hausse exponentielle de difficulté punissant systématiquement les builds lents.

## Ce qu'il faudrait changer si cette direction est retenue

**Catalogue** : cartes autonomes avec effet de base, tags de gameplay, origine et conditions ; séparer origine narrative, admissibilité au départ, présence dans le butin et conditions d'utilisation. Une carte peut être absente du départ et trouvable pendant la run.

**Identité** : classe / patron / culte enregistrés indépendamment des anciens axes de sorts. Les arbres historiques restent une archive du mode classique ; réutiliser leurs effets techniques utiles, pas leurs prérequis pour définir tout le contenu Cartes.

**Butin** : tables par rencontre / biome / palier, instances d'objets avec niveau, effets et rune ; reçu commun et transaction unique vers l'inventaire. Distinguer définition, copie possédée, carte équipée et effet appris. Trouver une carte n'enseigne plus implicitement toute une famille d'arbre.

**Interface** : sélection d'identité et catalogue des quinze cartes, départ sans équipement, résultat de combat acquis, comparaison au survol, inventaire et vente. Conserver les accès de reprise de progression et le retour physique au Seuil.

**Combat** : réutiliser PA/PM, déplacement, `SpellCaster`, surfaces et effets. Les gestes initiaux deviennent indépendants de l'équipement. Ne pas créer un second calculateur de dégâts pour les cartes.

Premier prototype proposé : une classe, un patron, trois cultes ; 21 cartes de départ au total si l'on garde huit cartes de classe, quatre du patron et neuf des cultes ; quelques cartes étrangères dédiées au test des hybrides ; dix-huit équipements couvrant les six emplacements ; six runes ; trois segments courts avec les monstres existants. Vérifier trois plans de jeu distincts avant d'étendre aux quatre classes.

Comparer les mêmes graines et rencontres avec le système actuel. Mesurer les cartes réellement jouées, objets équipés/vendus/conservés, pivots réalisés, temps passé dans l'inventaire, morts avant premier équipement, cartes sans cible utile et fréquence de répétition du même enchaînement. Les comptes de combinaisons ou de cartes ne constituent pas une preuve de profondeur. Le critère décisif : une trouvaille doit parfois faire changer un plan, et plusieurs plans issus du même départ doivent rester satisfaisants.
