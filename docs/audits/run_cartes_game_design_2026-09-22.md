# Audit de conception — run Cartes, 22 septembre 2026

Complément chiffré : [fiches techniques — statistiques, sorts, coûts, seuils et calculs tactiques](run_cartes_boss_fiches_techniques_2026-09-22.md). Il précise les valeurs finales de notre code et signale les divergences de versions des références.

Complément : [recherche comparative sur les monstres, champions et cartes](run_cartes_references_combat_deckbuilding_2026-09-22.md), avec sources externes, adaptations à notre hybride et prototypes proposés.

Approfondissement : [boss, salles, méthodes de victoire et profondeur systémique](run_cartes_boss_profondeur_2026-09-22.md), couvrant les boss demandés de Dofus, BG3 et DOS2, puis leur transposition à la run Cartes.

Périmètre : nouvelle partie publique Catabase **Cartes** ; Achille solo, quatre classes, route révision 6, règles de classes révision 3 et écosystème révision 2. Référence Git initiale : `9af4a96a`, espace de travail propre. Aucun changement de gameplay réalisé. Les anciennes sauvegardes, la variante Classique et les laboratoires ne sont pas évalués comme contenu courant. « Baldur » est interprété ici comme Baldur’s Gate 3 ; la comparaison Slay the Spire concerne le premier jeu.

Méthode : lecture des règles réellement branchées, catalogues, cycle de main, effets, progression, rencontres et interface ; recherche documentaire externe ; tentative de vérification Godot. Cet audit établit des propriétés de conception et des risques. Il ne mesure ni plaisir humain, ni durée réelle des parties, ni taux de victoire actuel. Les propositions ci-dessous ne sont pas des fonctionnalités existantes.

**Diagnostic général.** Catabase possède déjà une bonne base de tactique sur grille : portée, déplacement, poussée, attraction, surfaces et groupes ennemis interdépendants. La couche deck crée de l'incertitude et des arbitrages, mais transforme encore peu le fonctionnement du personnage. Le principal risque est une progression où l'on remplace des techniques faibles par des techniques plus efficaces, sans découvrir assez souvent une nouvelle manière de jouer. La priorité est de renforcer les interactions entre les cartes et l'identité des classes, puis de mesurer leur accessibilité pendant une run.

| Dimension | Appréciation issue de la lecture | Limite de cette appréciation |
|---|---|---|
| Décisions de placement | Base riche et exploitable | Valeur réelle dépend des maps, de l'IA et des intentions lisibles |
| Construction du deck | Accessible, contrôlable, encore peu transformatrice | Fréquence des combinaisons réussies non mesurée |
| Classes | Promesses claires, débuts trop semblables | Aucun test humain comparatif réalisé |
| Sorts avancés | Vrais changements tactiques : stase, surfaces, téléportation | Rareté et arrivée tardive peuvent empêcher leur découverte |
| Progression | Nombreux investissements et corrections possibles | Risque de surcharge de gestion et de choix numériques évidents |
| Rejouabilité | Branches et butin variables, parcours lisible | Rythme des combats et élites largement fixé |
| Équilibrage | À établir sur la version courante | Les anciens résultats ne valident pas cette révision |

**Ce que contient réellement la version actuelle.** Le catalogue expose 112 familles : 60 techniques de base, 24 avancées et 28 cartes d'initiation, soit 28 par classe. Ce nombre n'est pas celui de 112 mécaniques différentes : les sept initiations sont largement communes et beaucoup de techniques réutilisent les mêmes effets. Une nouvelle partie choisit cinq familles parmi sept initiations, en deux exemplaires. Le deck reste exactement à dix copies, avec deux copies au maximum par famille.

La main contient quatre cartes. Une carte peut être gardée ; le tour suivant complète la main à quatre, sans donner quatre cartes supplémentaires. Une recomposition coûte 1 PA, une fois par activation. Les cartes jouées vont à la défausse sans remplacement immédiat automatique. Deux gestes de secours restent disponibles hors pioche. Achille a une base de 6 PA et 3 PM. Ce système borne bien la complexité d'un tour et réduit les mains totalement inutiles.

La route comporte douze combats dont trois élites, sur vingt profondeurs ; les refuges sont aux profondeurs 7, 11 et 16, et la profondeur 19 est une préparation finale. Les récompenses courantes sont des drops automatiques en réserve, éventuellement aucun, avec 70 % de classe principale par carte et 30 % de classe étrangère. Les rares deviennent éligibles à la profondeur 4 et les épiques à 10. Les boutiques actuelles proposent six cartes. L'ancienne règle de choix parmi trois récompenses existe pour compatibilité, mais ne décrit pas la nouvelle partie.

Sources locales principales : `core/expedition/class_card_catalog.gd`, `card_ecosystem_catalog.gd`, `class_cards.gd`, `catabase_cards.gd`, `card_drop_catalog.gd`, `catabase_route_v6.gd`. Le document `docs/design/class_run_rules_v3.md` conserve plusieurs chiffres historiques : quinze cartes de départ, soixante techniques, drops garantis et trois cartes en boutique. Pour cet audit, le code courant prime sur ces passages.

**Face à Slay the Spire : mieux transformer le deck.** Dans Slay the Spire, une carte peut changer la valeur d'un ensemble d'autres cartes. Body Slam convertit le blocage courant en dégâts ; Catalyst multiplie le poison déjà posé ; Dark Embrace fait de l'épuisement une source de pioche. Leur intérêt vient des relations entre ressources et actions. Références : [Body Slam](https://slay-the-spire.fandom.com/wiki/Body_Slam), [Catalyst](https://www.slaythespire.gg/cards/silent/Catalyst), [Dark Embrace](https://slay-the-spire.fandom.com/wiki/Dark_Embrace).

Dans notre catalogue, les interactions sont surtout « condition remplie → bonus de Prouesse ». Heurt d'airain et Sentence du rempart demandent de posséder de la garde ; la quantité de garde ne détermine pas le bonus. Une petite garde suffit donc à activer la condition. Cela produit un bon ordre de jeu, mais pas encore un moteur de deck dont plusieurs cartes font croître le potentiel.

| Carte ou système actuel | Enseignement de la comparaison | Application proposée |
|---|---|---|
| Heurt d'airain / Sentence du rempart | Une condition binaire récompense peu l'investissement supplémentaire en défense | Tester une conversion partielle et plafonnée de garde en dégâts, éventuellement en consommant cette garde |
| Saignement / brûlure | Les dégâts différés non cumulables offrent de l'usure mais peu de croissance | Tester une carte qui consomme les dégâts restants pour une exécution immédiate, avec un coût réel |
| Marque → frappe conditionnelle | Le couple préparation/récompense est lisible | Rendre la récompense suffisamment forte et ajouter un choix : consommer la marque ou la préserver |
| Conservation / recomposition | Le joueur maîtrise déjà une partie du hasard | Ajouter quelques interactions conditionnelles avec la main, limitées par activation |
| Épiques | Plusieurs sont principalement de meilleures valeurs ou zones | Introduire une ou deux épiques par classe qui changent une règle plutôt que seulement un coefficient |

Le deck fixe à dix cartes est un choix défendable : il facilite la lecture et permet d'essayer des drops sans diluer définitivement sa pioche. Il déplace toutefois la décision vers « quelle copie remplacer ? ». Il ne faut donc pas reproduire sans adaptation l'économie d'ajout et de suppression de cartes d'un deck de taille variable.

Avec deux copies d'une famille dans dix cartes, la probabilité de la voir dans une main initiale de quatre est de 66,7 %. Pour deux familles distinctes à deux copies chacune, la probabilité d'avoir au moins une de chaque est de 40,5 % : `(C(10,4) − 2×C(8,4) + C(6,4)) / C(10,4)`. Hypothèses : mélange uniforme, aucune conservation ni recomposition et aucune carte imposée en ouverture, ce qui correspond au principe du départ courant. Un duo conditionnel doit donc être utile séparément, ou disposer d'un moyen raisonnable d'être assemblé.

Le moteur commun connaît l'épuisement, mais les définitions de ces 112 familles ne constituent pas actuellement un écosystème de pioche, défausse rémunérée, génération de cartes ou pouvoirs persistants comparable à celui de Slay the Spire. Ajouter tout cela serait excessif ; deux interactions bien choisies suffiraient à tester la direction.

**Un problème établi : l'initiation récompense mal certaines bonnes idées.** Comparaisons de coefficients avant arrondi, défenses, passifs et équipement ; P désigne la Prouesse. Elles évaluent la rémunération intrinsèque des cartes, pas tous les contextes tactiques.

| Séquence d'initiation | Coût | Rendement intrinsèque |
|---|---:|---:|
| Frappe / Trait novice | 2 PA, une carte | 0,65 P immédiat |
| Repérer une faille puis Saisir la faille | 3 PA, deux cartes | 0,10 P + 0,35 P + 0,20 P = 0,65 P |
| Éraflure, si les deux ticks aboutissent | 2 PA, une carte | 0,25 P + 2 × 0,10 P = 0,45 P |
| Frappe de secours | 2 PA, hors main | 0,55 P au contact |

La combinaison de marque coûte davantage pour les mêmes dégâts bruts qu'une attaque novice. Elle peut encore alimenter d'autres effets ou un passif, mais le premier enseignement risque d'être « ne prépare pas ». Éraflure demande du temps pour un coefficient total inférieur ; ses conditions de résolution peuvent modifier le résultat effectif, mais sa fiche mérite une revue immédiate. Le preset prend justement attaque, marque, garde, saignement et frappe conditionnelle, sans mobilité ni poussée.

Recommandation : tester d'abord une initiation où préparer une cible crée un gain visible et où l'usure a un avantage identifiable. Éviter une hausse générale des dégâts : elle pourrait masquer le problème sans rendre les décisions meilleures.

**Face à Dofus : donner une grammaire aux classes et aux effets.** Le Pandawa illustre une identité fondée sur le placement et le portage, qui modifie la façon d'aborder le terrain. La leçon utile pour Catabase est de donner à chaque classe une opération centrale reconnaissable, plutôt que de multiplier des variantes chiffrées des mêmes actions. Référence descriptive communautaire : [Pandawa](https://dofus-portals.fr/classes/pandawa/). Le devblog Ankama recherché était bloqué par sa protection anti-robot ; aucun chiffre d'équilibrage Dofus n'est repris ici.

Pousser, attirer, immobiliser, retirer des PA et occuper une dalle existent déjà chez nous. La valeur d'un retrait de PA dépend toutefois d'un seuil : retirer 1 PA à un ennemi peut lui supprimer un sort entier, ou ne rien changer à son prochain tour. Montrer seulement « −1 PA » ne suffit pas à expliquer sa valeur tactique. Les cartes de contrôle gagneraient à montrer l'action ennemie qu'elles empêchent lorsque cette information est calculable.

Autre rupture concrète : `class_card_modifier.gd` reconnaît le ralentissement via `class_slow`, alors que les surfaces de givre appliquent `ecosystem_ice` et les entraves `class_root`. `Unit.has_status()` compare exactement l'identifiant. Une cible uniquement ralentie par le givre au sol ne satisfait donc pas la condition du Thaumaturge, du Cryomancien ou du Chasseur. C'est soit une règle trop étroite et mal nommée, soit un défaut de synergie à corriger. Une propriété commune « mobilité réduite » ou des conditions explicitement distinctes rendraient les cartes plus prévisibles.

**Face à Baldur's Gate 3 : rendre les contraintes productives.** La concentration de BG3 oblige à choisir un effet durable par lanceur et permet d'interrompre cet investissement. La profondeur vient de la décision de maintenir, protéger ou remplacer un effet. Référence : [Concentration](https://bg3.wiki/wiki/Concentration). Il n'est pas nécessaire d'importer ses jets de dés, ses emplacements de sorts et son économie de repos dans une run solo courte.

Nos surfaces constituent déjà un investissement dans le terrain : les braises frappent au début du tour, le givre déclenche son statut à l'entrée ; les deux camps sont concernés. Pousser un ennemi dans les braises n'est donc pas nécessairement un dégât immédiat. C'est une bonne distinction si le joueur voit quand l'effet se résout. Les limites par famille, recharges et immunité temporaire à la stase préviennent aussi des verrouillages trop faciles.

La stase est intéressante : marque préalable, 3 PA, recharge de quatre activations et protection de la cible contre une nouvelle stase. Mais Pâris ne perd que 1 PA. Cette exception doit être visible avant l'investissement dans la carte et au ciblage du boss. Proposition : tester une alternative utile sur boss, avec un effet lisible et borné, plutôt que supposer qu'un contrôle d'ennemi ordinaire garde sa valeur partout.

Le meilleur emprunt à BG3 serait un petit nombre d'effets persistants exclusifs et de combinaisons environnementales très lisibles. Le moteur commun possède déjà un résolveur de réactions, notamment des branches de choc et de vapeur dans `battle/dynamic_terrain/terrain_surface_runtime_service.gd` : leur présence ne prouve pas leur fréquence ni leur compréhension dans une run Cartes. Ne pas ajouter un catalogue de réactions élémentaires avant de vérifier que les interactions accessibles sont comprises et réellement utilisées.

**Les personnages : quatre intentions, encore trop peu de façons distinctes de jouer.** Les trois Achille sont des apparences du même héros, pas trois personnages mécaniques. Les spécialisations remplacent le passif initial et restent des bonus conditionnels une fois par activation. Elles orientent le tour, mais changent rarement sa structure.

| Classe | Force actuelle | Faiblesse ou risque | Prototype d'identité à essayer |
|---|---|---|---|
| Assassin | Isolement, déplacement préparatoire, marque et exécution | Il paie l'approche au contact ; ses initiations démontrent mal sa promesse | Une exécution préparée donne une sortie courte, une fois par activation |
| Gardien | Garde, déplacement adverse, riposte | En solo, protéger se résume souvent à soi-même ; de nombreux bonus sont binaires | Convertir une partie de la garde en contrôle ou en riposte, avec sacrifice défensif |
| Arpenteur | Portée et maîtrise de la distance | Risque que reculer et tirer soit la réponse dominante | Choix entre visée stationnaire et mobilité, avec des bénéfices exclusifs |
| Thaumaturge | États, zones et surfaces | Dépendance à la préparation et incohérences de reconnaissance des états | Consommer ou transformer un état existant pour changer la zone ou l'effet |

Ce sont des propositions à prototyper, pas des promesses d'équilibrage. Le bénéfice recherché est que deux classes prennent des décisions différentes devant la même salle dès les premiers combats. Conserver des outils génériques est utile au multiclassage, mais au moins une carte initiale devrait enseigner le comportement distinctif de chaque classe.

**Rencontres et jouabilité : les ennemis offrent déjà un bon matériau.** La route courante annonce des problèmes tactiques précis : conducteur et chasseurs, collecteur dépendant de ses porteurs, rabatteur et exécuteur, feu associé aux déplacements. Ces associations créent des cibles prioritaires et donnent une fonction aux contrôles, au-delà des dégâts. Les avertissements différés sont branchés à la grille ; le code de présentation sépare même nom de menace et réponse conseillée.

Into the Breach constitue ici une référence complémentaire particulièrement pertinente : son postmortem explique comment les attaques annoncées et la lisibilité contraignent toute la conception. Application à Catabase : renforcer la prévision des conséquences d'une poussée, d'une rupture de ligne de vue ou d'un retrait de PA. La présence de télégraphes sur des sorts différés ne prouve pas que toutes les intentions ennemies sont annoncées ou figées. Référence primaire : [Matthew Davis, postmortem GDC](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf).

Le combat contre Pâris contient un seuil très structurant : un coup non fatal le laissant sous 20 % déclenche sa métamorphose avec restauration des PV et 30 de bouclier ; un coup fatal le tue. Cela peut valoriser une belle préparation d'exécution. Cela peut aussi avantager disproportionnellement l'explosion de dégâts face à l'usure. Vérifier séparément le comportement des dégâts périodiques et la compréhension de cette règle, sans supprimer automatiquement le seuil.

Le risque corps à corps/distance reste une hypothèse prioritaire. Un audit du 19 septembre observait des difficultés de l'Assassin et un meilleur confort à distance sur trois graines, mais il utilisait une autre configuration de départ et une politique automatique limitée. Il ne permet pas d'attribuer un taux de victoire aux classes actuelles. Mesurer maintenant le coût d'approche, les tours sans cible accessible et les dégâts évités par retrait est plus instructif que comparer seulement les dégâts affichés.

La reconnaissance visuelle mérite aussi un contrôle : `card_ecosystem_catalog.gd::icon_alias()` réutilise des illustrations pour les initiations et cartes avancées. La suite exécutée confirme 52 assertions d'unicité en échec dans le test des illustrations. Ce test conserve un contrat historique de 64 régions distinctes ; il faut décider explicitement quelles cartes partagent une illustration et lesquelles doivent se distinguer. La réutilisation est établie ; son impact sur la confusion des joueurs reste à vérifier visuellement et en partie.

**Progression et rejouabilité.** Le système de réserve est une force : le joueur peut adapter son deck entre les combats et essayer une nouvelle carte sans détruire sa construction. Les maîtrises partagent un budget avec les améliorations individuelles, ce qui peut produire un arbitrage réel. En revanche, les cartes d'initiation ne reçoivent pas de bonus de maîtrise : investir alors que le deck reste très novice peut sembler sans effet. Les améliorations qui ignorent la ligne de vue ou franchissent les obstacles sont qualitatives et précieuses, mais peuvent aussi effacer les contraintes qui rendaient certaines cartes intéressantes.

Les 72 équipements sont six emplacements × quatre affinités × trois paliers. Leur progression est surtout statistique. Ils offrent du butin, mais il ne faut pas compter cette quantité comme autant de décisions nouvelles. Les trois reliques permanentes tirées sur les élites méritent attention : le Clou favorise les impacts physiques après déplacement, la Coupe soigne sur les dégâts physiques directs et l'Obole récompense les éliminations directes payées. Ce tirage peut moins bien soutenir les sorts magiques et les dégâts différés ; c'est un biais structurel à mesurer, pas encore une conclusion sur leur puissance globale.

La Résonance augmente les chances de drop et la mémoire réduit les périodes sans cartes, sans demander au joueur d'aller vite ou d'éviter tout dégât : bon choix pour préserver les styles défensifs. Mais elle ne garantit pas une carte après plusieurs échecs. Au premier combat, sans sécheresse, les deux tirages valent 49 % et 16 % ; la probabilité théorique de zéro carte est donc `0,51 × 0,84 = 42,84 %`. L'espérance est 0,65 carte. Cela peut retarder la première transformation du deck, particulièrement quand l'ouverture contient volontairement des cartes faibles.

Recommandation : comparer le modèle actuel à une première acquisition garantie et à un choix ciblé occasionnel. Conserver ensuite une part de découverte aléatoire. L'objectif est de permettre au joueur de construire une intention, sans assurer systématiquement toutes les pièces d'un combo.

Les élites sont imposées aux profondeurs 6, 10 et 15. Les branches changent rencontres, accès et services, mais pas le nombre d'élites traversées. La rejouabilité porte donc davantage sur l'adaptation tactique et le butin que sur la prise de risque de parcours. Cette identité est viable ; pour approfondir la route, tester un arbitrage local facultatif et clairement récompensé avant d'ajouter des profondeurs.

**Ordre d'action recommandé.**

1. Corriger ou clarifier la reconnaissance des ralentissements ; rendre la préparation d'initiation avantageuse dans son cas d'usage ; donner un rôle convaincant à Éraflure. Vérifier des scénarios isolés, puis les premiers combats.
2. Introduire une carte initiale distinctive par classe et mesurer si les joueurs changent réellement de plan entre classes. Garder le deck de dix et la main de quatre pendant cette expérience.
3. Tester une interaction transformatrice par classe, avec garde-fous explicites : conversion de garde, consommation d'état, mobilité sur exécution, choix visée/mouvement. Éviter les chaînes de PA ou de pioche illimitées.
4. Mesurer l'arrivée des cartes utiles et comparer une première récompense garantie au système actuel. Examiner aussi l'utilité des reliques pour le Thaumaturge et les builds d'usure.
5. Améliorer la lecture des effets : résultat conditionnel, moment des ticks, interruption d'une action ennemie, immunités du boss et limites communes aux copies.
6. Ajuster les coefficients après ces mesures ; diversifier davantage cartes et rencontres seulement si les nouveaux comportements fonctionnent.

**Protocole de validation proposé.** Comparer les quatre classes sur les mêmes graines et branches, avec au moins deux orientations de deck par classe. Inclure un scénario contact sous pression, un groupe dispersé, un couloir, une salle ouverte, les trois élites et le boss. L'automate doit savoir conserver, recomposer, réviser son deck et utiliser les consommables ; documenter ses limites, puis compléter par des joueurs novices et expérimentés.

Relever : fréquence des familles jouées et remplacées, mains sans action pertinente, PA et PM inutilisés, coût d'approche, dégâts reçus, tours par combat, contribution des contrôles, première carte intégrée au deck, temps passé dans les menus, déclenchement des passifs, compréhension des pertes et décisions de branche. Comparer des distributions par salle et par classe ; ne pas confondre profondeur atteinte et victoire. Un volume initial de trente graines peut détecter de gros écarts, sans constituer à lui seul une preuve d'équilibre.

**Vérifications de cette intervention.** Lecture du code et des sources ci-dessus réalisée. Comptage des définitions et recalcul des probabilités effectués en PowerShell. Première exécution de `./dev.ps1 test cards` : échec à l'import, zéro test et zéro assertion ; erreurs de lecture du magasin de certificats et d'accès à cinq sous-dossiers temporaires. Rapport : `artifacts/dev/20260922-100457-test-cards-1e62dc26/summary.json`.

Relance de la même commande hors sandbox : import terminé avec code 0 ; 77 tests exécutés, 76 réussis et un échec, `test_class_painted_icons.gd::test_every_live_card_and_crest_has_distinct_painted_art`. GUT indique 6 886 assertions réussies sur 6 938, soit 52 échecs d'unicité d'illustration dans ce test. Les suites `test_catabase_cards.gd` et `test_catabase_class_run.gd` passent respectivement 24/24 et 25/25. Verdict global **FAIL**, à conserver tel quel. Rapport : `artifacts/dev/20260922-100644-test-cards-25d4f5e5/summary.json` ; détails : `gut.engine.log` et `gut.junit.xml` dans le même dossier. Le test de progression des quatre classes injecte les victoires via `combat_won()` : il valide des transitions et sauvegardes, pas la capacité à gagner ces combats.

Aucune partie humaine, capture inspectée ni campagne d'équilibrage actuelle n'a été exécutée dans cet audit. Seul ce document a été ajouté ; aucun code, contenu ou réglage n'a été modifié.
