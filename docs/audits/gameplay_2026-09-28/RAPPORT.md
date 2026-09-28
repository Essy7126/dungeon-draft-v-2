# Audit du gameplay après la refonte — 28 septembre 2026

**Référence : `6e8d2605`. Périmètre : nouvelle partie Cartes, règles consommables V2, aventure intégrée dans ExpeditionSession et Battle.** Les anciennes études et le simulateur sur petites arènes ne décrivent plus à eux seuls le jeu public. Aucun changement de gameplay n'a été appliqué pendant cet audit.

**Verdict : la refonte apporte de vraies décisions tactiques et des fondations techniques nettement plus cohérentes. Le principal problème n'est plus l'absence de mécaniques : c'est la cohérence entre ce qui est annoncé, ce qui est disponible dans la run et ce que les ennemis obligent réellement à jouer.** Deux défauts sont démontrés sans dépendre d'une appréciation de difficulté : l'aperçu des rencontres montre encore l'ancien profil, et une relique économique vendue ne peut pas rembourser son prix. Plusieurs risques de design demandent ensuite des parties complètes instrumentées.

## 1. Ce qui a été vérifié

- Lecture des 48 familles dans leurs deux formes, quatre classes, huit spécialisations, 18 équipements, huit reliques ; parcours des résolveurs de dégâts, déplacement, statut, surface, pioche, progression, économie et checkpoint.
- Exécution de **130 tests, 5 953 assertions, zéro échec et zéro erreur**, suite `consumable-v2` du dépôt actuel.
- Montage des **12 rencontres réelles** du chemin choisi par le harnais, seed 33, difficulté normale ; comparaison avec leur manifeste. Énumération supplémentaire des **32 profils de rencontre** des trois branches, par la fabrique utilisée dans le jeu.
- Captures des six salles à mécanisme, plus une prévision de pression, à **1280×720** ; inspection visuelle des sept images.
- Calculs exacts des espérances de loot, probabilités d'accès aux familles, mains d'ouverture, progression, pression et borne de rentabilité. Les nombres ne sont pas des simulations de victoires.

Les [observations](observations.json), les [calculs](calculs.json), la [lecture carte par carte](CARTES_ET_BUILDS.md) et les [outils reproductibles](../../../tools/gameplay_audit_2026_09_28/) accompagnent ce rapport.

**Limite importante : aucune campagne complète à statistiques intactes, jouée par un humain ou un agent tactique représentatif, n'a été effectuée ici.** Le harnais traverse les scènes en déclarant les victoires ; certaines sondes arrangent positions et PV pour vérifier un contrat. Le test `test_consumable_cards_campaign.gd` met les ennemis à 1 PV et restaure les PV du héros. C'est utile pour les transitions, pas pour annoncer un taux de victoire ou un équilibrage réussi. Les 96 formes de cartes ont un test de lancement légal et consommation ; cela ne mesure pas 96 rendements en conditions de run.

## 2. Les progrès réels à conserver

La boucle demandée est présente : **15 copies normales choisies au départ, consommation définitive à l'usage, butin par ennemi, réserve séparée, préparation de 0 à 30 copies, trois copies maximum par famille, achats ciblés, sacs, vente et troc**. Les gestes de secours restent disponibles, ce qui évite une impossibilité mécanique absolue de jouer lorsque le stock baisse. Leur faible rendement n'assure cependant pas qu'un deck vide puisse gagner.

L'ouverture choisie, la rétention de Garde brève améliorée, l'Ancre de l'Arpenteur, le Relais de l'Assassin, le sacrifice choisi de Répercussion et les transformations eau/glace/vapeur ajoutent des décisions distinctes. Les effets ne sont plus seulement des variantes de dégâts. Seulement **11 améliorations sur 48** modifient exclusivement le champ `damage` ; les 37 autres incluent également des hausses numériques de garde ou de durée, donc « non limité aux dégâts directs » ne signifie pas automatiquement « nouveau gameplay ».

Les salles apportent de vraies règles : presse, croix différée, anneau mobile, convoi dont le sacrifice supprime le butin, réservoirs de PA. Le soutien dépendant de la ligne de vue, la formation, la parade finie et l'exécution annoncée sont effectivement liés aux rencontres prévues. Pâris change de phase sous 50 % PV, y compris sur dégâts périodiques. Le relevé retrouve tous ces contrats ; il n'y a pas de mécanisme manquant parmi ceux attendus sur le chemin observé.

Enfin, plusieurs protections économiques et techniques sont explicites : butin engagé avant le combat, reçus idempotents, aucune duplication en rechargeant, effets indirects distingués des éliminations directes, soin de vol de vie borné, deux reliques distinctes, garde plafonnée, persistance des choix et des ressources. Ces fondations permettent de régler les valeurs sans réinventer le système.

## 3. Constats prioritaires

Les priorités désignent l'ordre de travail proposé, pas la gravité d'un crash : **P1** compromet la décision ou un système central ; **P2** affaiblit la diversité, la progression ou la compréhension.

### A — P1, défaut confirmé : l'inspection avant combat présente le mauvais ennemi

`ExpeditionEncounterPreview.describe()` reconstruit les monstres natifs via `ExpeditionRunFactory.make_room()`. `ExpeditionRouteView` en affiche les PV, PA, PM et sorts. Or `consumable_cards_runtime.setup()` remplace ensuite ces statistiques et ces sorts, uniquement dans Battle.

Exemple exécuté, deuxième combat du chemin observé :

| Tireur du passeur | Aperçu de route | Combat Cartes réel |
|---|---:|---:|
| PV | 26 | 19 |
| PM | 3 | 1 |
| PA | 4 | 1 |
| Portée | 2–5 | 1–4 |
| Attaque brute | 14 | 11 |
| Sort | Flèche du passeur | Attaque générique |

Au même combat, la Brute est annoncée à 66 PV, contre 47 dans Battle. Plus loin, les détails annoncent des sorts de marque, saignement, déplacement et terrain qui sont retirés par l'adaptateur. Le joueur prépare donc son deck contre une information incorrecte.

Le texte court de la route a bien été adapté : l'annonce de Pâris à 50 % est correcte. Ce sont **les détails et certaines pistes tactiques de l'inspection** qui restent issus du profil natif ; il ne faut pas corriger aveuglément tous les textes historiques.

**Action :** une projection commune du profil Cartes doit alimenter l'aperçu et Battle. Tester l'égalité des stats, portées, sorts et comportements annoncés sur les 32 profils et les deux difficultés. Priorité avant toute retouche fine de dégâts : une information fausse empêche de juger si une défaite est comprise et méritée.

Preuves : `ui/expedition/expedition_encounter_preview.gd`, `expedition_route_view.gd::_update_encounter_preview`, `battle/consumable_cards_runtime.gd::setup`, `observations.json → probes.route_previews` et `encounters`.

### B — P1 de design : le bestiaire perd une partie des problèmes qu'il faisait résoudre

Le relevé des profils natifs contient **30 identifiants de sorts différents**. Dans Cartes, tous les ennemis reçoivent la même définition de sort `cc2_enemy_attack`, paramétrée par sept archétypes. Le profil IA, la transformation native, l'armure de proximité et la réduction de poussée sont notamment retirés. Des règles spéciales V2 sont ajoutées séparément : il serait faux de conclure qu'il ne reste qu'un seul comportement.

Mais la perte reste importante :

- **Brute aux deux frappes** : une seule attaque autorisée par activation dans l'adaptateur.
- **Conducteur de la chasse** : devient un archer ; sa chaîne native de marque et de meute disparaît.
- **Rabatteur du Styx** : devient une brute ; son déplacement offensif natif disparaît.
- **Tisseuse du Léthé** : devient un archer physique ; ses actions d'ombre/givre ne constituent plus son kit.
- Pâris garde un nouveau contrat explicite en deux phases, mais ses accompagnateurs observés sont deux brutes, alors que le manifeste de référence prévoyait mage et molosse.

Le rôle est inféré depuis le nom, l'identifiant et la portée. Un monstre à distance est d'abord un archer ; seuls certains fragments de nom le font ensuite passer mage/prêtre/garde. Cela rend les résultats dépendants de la nomenclature. Exemple observé : Fondeur des Enfers et Gardien des derniers voiles sont des archers, Artilleur de braise devient mage.

**Conséquence :** le héros dispose de plus de réponses, mais beaucoup de cibles lui posent moins de questions. La diversité visible du bestiaire surestime la diversité des contraintes tactiques. Les salles compensent en partie ce recul, pas intégralement.

**Action :** remplacer l'heuristique par des profils explicites. Garder le budget simplifié V2, mais attribuer une signature limitée à chaque rôle important : poussée annoncée au Rabatteur, marque interrompable au Conducteur, zone de givre au Tisseur, double frappe télégraphiée à la Brute concernée. Répartir ces signatures dans les rencontres et mettre à jour leur coût offensif. Ne pas simplement réactiver tous les anciens sorts : leurs anciens PA et dégâts appartiennent à un autre équilibrage.

Preuves : `battle/consumable_cards_runtime.gd:setup/run_enemy`, `core/expedition/consumable_enemy_rules.gd`, inventaire `probes.all_native_rosters`.

### C — P1 économique, défaut confirmé : Obole fendue est un achat perdant

Prix : **90**. Effet : **4 or par élimination directe, maximum 20/combat**. Les reliques arrivent dans le stock au palier 3. Le premier marchand possible à ce palier est à la profondeur 9, après six combats.

| Achat | Combats rémunérateurs restants avant le boss | Ennemis maximum correspondants | Retour maximum | Solde net maximum |
|---|---|---:|---:|---:|
| Profondeur 9 | 7, 8, 9, 10, 11 | 16 | 64 | **−26** |
| Profondeur 14 | 10, 11 | 7 | 28 | **−62** |
| Profondeur 18 | aucun | 0 | 0 | **−90** |

Cette borne suppose que **tous** meurent directement, aucun porteur ne se sacrifie, aucun dégât de terrain/périodique ne vole une finition. Elle prend les effectifs maximums des branches. L'or gagné au boss n'a plus d'achat utile après la victoire. En pratique, une partie des gains du combat 11 peut même être inutilisable si la branche ne finit pas sur un marchand.

Ce n'est pas un pari risqué : **l'achat ne peut pas s'amortir**, et occupe en plus un slot de relique. Un drop gratuit précoce reste exploitable ; le défaut concerne la vente et sa temporalité.

**Action :** retirer cet achat des stocks tardifs ou transformer l'effet en avantage utilisable immédiatement. Alternative à tester : prix précoce 35–40, puis indisponibilité après la fenêtre d'amortissement ; cela n'est qu'une valeur de départ, pas un réglage validé. La faire apparaître plus tôt est une autre solution, à confronter au budget total du marchand.

Preuves : `consumable_card_economy.gd::market`, `consumable_card_modifier.gd` (éliminations directes), `catabase_route_v6.gd`, `calculs.json → obole`.

### D — P1 de design : l'abondance totale cache une faible stabilité des familles utiles

Hypothèses des calculs : 11 combats avec loot, tous les ennemis éligibles vaincus, aucun porteur sacrifié, aucun achat/troc ; chemin observé de 32 ennemis rémunérateurs. Les tirages des sacs sont respectés, y compris deux cartes dans un même sac.

| Palier | Combats | Normales attendues / ennemi | Élites attendues / ennemi | Probabilité d'une carte rare / ennemi |
|---|---|---:|---:|---:|
| 1 | 1–3 | 3,00 | 0,10 | 0,5 % |
| 2 | 4–6 | 3,20 | 0,20 | 1,5 % |
| 3 | 7–9 | 3,50 | 0,36 | 4 % |
| 4 | 10–11 | 3,80 | 0,56 | 8 % |

La run donne en moyenne **108,10 normales, 9,76 élites et 1,10 rare**. Le fonctionnement « sacs normaux fréquents, raretés hautes exceptionnelles » respecte donc bien l'intention initiale. Mais « 70 % natif ou commun » signifie, pour les normales : **23,33 % de sa classe, 46,67 % communes, 30 % d'autres classes**. Les huit communes prennent deux tiers du sous-pool à 70 %.

Une famille normale précise de sa classe ne revient qu'à **6,31 copies attendues sur l'ensemble de la run**, et ces arrivées peuvent être tardives. Après le premier combat, sa probabilité d'apparaître dans le loot est **16,35 %** ; après le septième, **34,16 %** ; même après le dixième, seulement **59,78 %**. Trois copies initiales plus l'espérance de réapprovisionnement ne permettent pas d'en faire une action systématique à chaque tour de douze combats.

Ce n'est pas nécessairement un défaut : le concept consommable doit pousser à adapter son deck. Le problème apparaît si la classe, son amélioration permanente ou sa spécialisation promettent une boucle dont on ne retrouve plus les pièces. Le joueur peut avoir 40 cartes et aucune combinaison qu'il avait choisi de développer.

**Action proposée :** conserver le drop par mob et les sacs abondants, mais tester une garantie de *fonction* normale dans une partie des sacs : amorce, défense, mobilité ou payoff de la classe. Autre option : sac à choix limité sur les combats charnières, toujours obtenu sur un mob. Les achats ciblés et deux trocs par marchand existent déjà ; vérifier leur disponibilité sur toutes les branches avant d'ajouter une nouvelle monnaie. Ne pas augmenter indistinctement tous les drops : le volume normal est déjà élevé.

### E — P2 de design : plusieurs outils les plus expressifs sont des rencontres occasionnelles

Sur le même chemin, sans achats :

| Événement sur toute la run | Probabilité |
|---|---:|
| Au moins une carte rare quelconque | 67,77 % |
| Au moins une famille rare précise de sa propre classe | **32,22 %** |
| Au moins une famille élite précise de sa propre classe | 87,73 % |
| Une relique précise, deux garanties comprises | 25,40 % |
| Au moins une légendaire | 10,99 % |
| Au moins une divine | 1,31 % |
| Au moins une immortelle | 0,140 % |

Répercussion, Permutation, Convergence et Sommeil marqué sont ainsi absents du loot dans environ deux runs sur trois pour la classe concernée. Ce sont d'excellentes trouvailles ponctuelles ; ils constituent une fondation fragile pour définir la classe ou orienter une amélioration dès le niveau 4. Le magasin donne accès aux reliques, pas aux rares de façon ciblée.

**Action :** distinguer l'outil d'identité de sa version spectaculaire. Une conversion de garde plus faible, une permutation limitée ou une petite convergence peuvent exister dans une famille normale/élite ; la rare amplifie ou combine ces actions. Pour les cartes divines/immortelles, garder le statut d'événement exceptionnel si c'est l'intention : il n'est pas nécessaire que toutes les runs en voient une. En revanche, leur rareté interdit de les compter comme réponses fiables aux problèmes ordinaires.

### F — P2 : plafond de 30 copies et ouverture ne suffisent pas à expliquer la fiabilité du deck

Probabilité de réunir deux familles précises, chacune en trois exemplaires, dans la première main :

| Deck | Main | Sans ouverture choisie | Avec une copie de la première famille garantie |
|---:|---:|---:|---:|
| 15 | 5 | 51,45 % | **67,03 %** |
| 15 | 6 | 64,76 % | 76,92 % |
| 30 | 5 | 16,53 % | **37,06 %** |
| 30 | 6 | 22,96 % | 44,61 % |

Ce calcul concerne uniquement la main initiale, sans Recentrage, rétention ni modification de composition. Le plafond à 30 est sain comme maximum, mais remplir tous les emplacements peut diviser fortement l'accès au combo choisi. Un gros deck donne des munitions et de la variété ; un petit deck donne de la fiabilité. L'interface doit aider à arbitrer ces objectifs.

L'ouverture est attachée à un **UID de copie**. La jouer consomme cette copie et efface la sélection, même s'il reste deux exemplaires de la même famille. C'est cohérent avec l'inventaire physique, mais ajoute une reconfiguration récurrente et peut provoquer un départ sans l'amorce attendue.

**Action :** montrer la taille préparée comme un choix, pas un objectif de remplissage ; proposer un rappel d'ouverture manquante et éventuellement une préférence de famille qui sélectionne explicitement une copie restante. Ajouter à Recentrage et aux pioches conditionnelles un aperçu du nombre réellement piochable. Aucun de ces changements ne nécessite d'automatiser toutes les décisions de deck.

### G — P2 : la promesse élémentaire demande un amorçage plus accessible

Le preset Thaumaturge courant contient t01/t02/t03, Garde brève et Pas latéral. **Il ne contient pas t04**, qui crée l'eau dynamique. Le preset alternatif l'inclut : la mécanique n'est donc pas absente ni impossible à préparer.

Mais Onde coûte **3 PA** et givre/feu **2 PA**, pour un budget de **4 PA**. Le combo ordinaire se prépare sur deux tours, avec déplacement de la cible et durée de surface à gérer. L'Agrafe permet une première Onde à 2 PA puis une réaction dans le même tour : c'est une interaction intéressante, mais conditionnelle à l'acquisition d'une relique.

De plus, les améliorations de t01 et t02 ne renforcent que les transformations issues de l'eau. Les choisir dans un deck sans eau n'améliore pas leur coup, leur ralentissement direct ou leur brûlure. Le texte est explicite, mais l'interface de progression pourrait signaler la dépendance.

**Action :** faire essayer le preset eau dès la préparation, afficher les prérequis d'amélioration et mesurer la fréquence réelle des transformations. Si elles restent très rares, essayer un amorceur d'eau moins coûteux/moins offensif ou une surface de départ offerte par une spécialisation. Ne pas baisser simplement tous les coûts sans vérifier les zones et le nombre de cibles.

### H — P2 : la progression donne son dernier changement juste avant la fin

Les niveaux suivent exactement les douze combats : après les combats 3, 7 et 11, le héros atteint respectivement **4, 8 et 12**. Spécialisation au premier de ces seuils ; une amélioration de famille à chacun. La troisième amélioration sert donc au **seul boss final**.

Le cap final peut être une préparation de climax assumée, mais il offre peu de temps pour apprendre une amélioration de rétention, portée, choix d'attraction ou durée. Dans une run consommable, il faut en outre posséder des copies de la famille au moment où le point arrive.

**Action :** tester le déplacement du troisième point avant le combat 10, ou réserver le niveau 12 à une amélioration finale très lisible. Mesurer les points inutilisés, les améliorations jamais jouées et la première utilisation effective après achat. Ne pas accélérer automatiquement toute la courbe d'XP : la synchronisation héros/ennemis est actuellement cohérente.

## 4. Rencontres, pression et logique de run

Les effectifs observés sont `1,2,3,3,4,3,2,4,3,4,3,3`. Ils correspondent au manifeste en nombre sur le chemin Airain observé ; **l'hypothèse d'un gonflement général des effectifs à l'intégration n'est pas confirmée**. Les branches Styx/Léthé ont toutefois trois ennemis au deuxième combat, contre deux en Airain. Le budget de PV total restant normalisé, ces branches changent à la fois le nombre d'actions ennemies, les opportunités de zone/finition et les tirages de loot. Elles donnent alors 50 % de cartes de plus sur ce combat, sans hausse correspondante du gain d'or forfaitaire.

Le choix de branche a donc un intérêt potentiel. Il faut que l'aperçu soit exact et qu'une récompense prévisible accompagne le risque. Aujourd'hui le contenu des sacs dépend du palier et de l'affinité du héros, pas de l'espèce tuée. Le drop est bien attribué aux mobs ; la chasse à une espèce pour chercher une famille précise n'est pas un système actif. C'est une piste compatible avec l'intention initiale, à traiter après la stabilité de l'économie de base.

Les salles réelles vont ici de **15×13 à 19×18**, avec aussi une salle 18×19 et un boss 18×18, loin du plateau 7×7 des tests de règles. Pour le premier déploiement légal choisi par le harnais, rejoindre au contact une cible accessible immobile demande souvent **5 à 7 pas**, contre 3 PM de base. Ce n'est pas le temps réel de premier contact : l'ennemi peut avancer, un autre déploiement peut être meilleur et certaines cartes déplacent le héros. Il faut compter séparément tours d'approche, tours d'installation, tours de combat effectif et détours vers les mécanismes.

Une seconde mesure calcule le coût minimal pour atteindre **une case permettant réellement la commande**, en incluant l'adjacence autorisée. Les blocages temporaires par les unités sont distingués d'une copie de la même grille sans occupation :

| Combat / mécanisme | Coût de mouvement sans unités | Accès avec la disposition initiale observée |
|---|---:|---|
| 4, presse | 8 PM | Passage bloqué par les unités |
| 5, sablier | 10 PM | Passage bloqué par les unités |
| 6, jardin | 8 PM | 8 PM |
| 8, sceau du convoi | 8 PM | 8 PM |
| 9, réservoirs A/B | 12 / 14 PM | Passages bloqués par les unités |
| 11, jardin | 7 PM | Passage bloqué par les unités |

**Risque P2 supplémentaire :** à 3 PM, ce sont 3 à 5 budgets de déplacement avant interaction, hors cartes de mobilité. Les mécanismes sont accessibles sur le terrain dégagé, donc il ne s'agit pas d'une impossibilité permanente. En revanche, quatre de ces six dispositions imposent d'abord de déplacer ou éliminer des occupants. Leur position est calculée sur la composante de sol principale, sans budget explicite d'accès depuis le déploiement. Ils peuvent devenir des actions disponibles trop tard pour influencer le combat. Préférer des repères de salle contrôlés dans le Studio, ou contraindre le placement calculé par un coût d'accès et des chemins alternatifs. Mesurer le bénéfice obtenu avant de les rapprocher tous arbitrairement.

La pression vaut `arrondi(PVmax × 2,5 % × max(0, tour − 8))` après chaque ronde concernée. Hors arrondi, sa somme après la fin du tour 16 vaut **90 % des PV maximum**, puis **112,5 %** après le tour 17. À 675 PV : 608 puis 760 PV cumulés. Sans soin et même sans dégât ennemi, un héros plein ne survit donc pas à la pression de fin de tour 17. Augmenter les PV ne procure pratiquement pas davantage de tours contre cette seule pression.

Ce compte à rebours empêche une économie infinie de copies par les secours. En contrepartie il pénalise intrinsèquement défense, préparation lente, retrait et détours. Il ne faut pas appeler « 24 tours disponibles » la fenêtre de survie effective : la mort forcée tardive n'est pas la première limite.

**À mesurer avant réglage :** tours sans cible accessible ; coût en PM pour interagir ; proportion de combats où le mécanisme est effectivement commandé ; pression subie par classe et par équipement de mobilité ; ennemis encore vivants au premier tour de pression. Une capture qui téléporte le héros au levier prouve la présence du bouton, pas son accessibilité pendant une partie.

## 5. Économie complète : volume, choix et pertes

Le revenu forfaitaire des onze combats est **475 or**, plus les **40 initiaux** : 8 normales ×35 + 3 élites ×65. Les lieux de mémoire peuvent ajouter 20 ; vente et Obole sont des flux séparés. Les refuges offrent trois repos de 30 % en normal ou 40 % en facile ; la halte pré-boss sert à préparer et n'offre pas ce soin. Les soins marchands coûtent 25 pour 30 % des PV max, une fois par visite.

La route publique n'offre pas les cinq marchands annoncés dans le manifeste du prototype. Des marchands existent aux profondeurs **4, 9, 14 et 18**, suivant les branches ; leur présence sur le chemin n'est pas garantie quatre fois. Les refuges 7/11/16 ne sont pas des magasins. Il faut calculer le réapprovisionnement sur ces accès réels.

Un sac marchand donne six normales pour 36, soit 6 par copie aléatoire, contre 8 pour une famille normale choisie. Deux trocs de trois normales vers une normale choisie sont autorisés par visite. Cette différence donne une valeur à la précision. Les prix de revente, plus faibles, empêchent un simple aller-retour d'achat rentable. Les équipements et reliques en double ne constituent pas ici une source équivalente de revente.

La moyenne brute de stock avant boss serait de **90,09 copies** si l'on en dépensait quatre par combat rémunérateur, **46,09** pour huit, **2,09** pour douze, sans achat/vente/troc. Ce sont des bilans comptables hypothétiques, **pas des taux de pénurie** : ils ignorent l'ordre des arrivées, les familles utilisables, la capacité préparée et la difficulté. Ils montrent pourquoi un unique réglage « davantage de drops » peut simultanément encombrer un joueur économe et laisser un autre sans son amorce.

Le drop d'équipement donne environ **2,90 objets/run** avant boss. Le drop de relique aléatoire donne 0,208, auquel s'ajoutent deux garanties : **2,208 reliques en moyenne**. Avec six slots d'équipement, le marchand reste un vecteur important de construction. Les deux reliques garanties peuvent être identiques : 12,5 % de collision entre ces deux tirages. Une protection anti-doublon serait une correction de qualité de récompense plus ciblée qu'une hausse globale de probabilité.

## 6. Lisibilité et friction observées

Les sept captures à 1280×720 montrent une main lisible, les coûts, les secours, l'intention de salle et la prévision de pression. Le contrôle automatique de bornes ne trouve pas de débordement pour les blocs ciblés. Les dangers orange se distinguent du sol. Aucun jugement n'est porté ici sur l'accessibilité à une autre résolution ou sur le jeu à la manette.

Les repères de mécanisme restent très petits à cette échelle, parfois masqués visuellement par le héros placé dessus. Les boutons nomment l'action, mais retrouver le bon L/A/B/S sur la carte demande une recherche. Une mise en évidence de la case et du trajet au survol d'une commande serait plus utile qu'un long tutoriel supplémentaire. À vérifier avec un utilisateur qui découvre la salle ; ce n'est pas une mesure de temps d'apprentissage.

La préparation demande plusieurs décisions récurrentes : remettre des copies dans le deck, refaire une ouverture consommée, équiper les trouvailles, vendre/troquer les surplus, réaffecter si une famille améliorée s'épuise. Ces décisions portent le concept, mais les opérations répétitives ne doivent pas devenir la difficulté principale. Mesurer le temps hors combat et les clics par réapprovisionnement avant d'ajouter davantage de ressources ou de raretés.

## 7. Suite recommandée et critères d'acceptation

| Ordre | Chantier | Résultat vérifiable |
|---|---|---|
| 1 | Une même définition de rencontre Cartes pour aperçu et combat | 32 profils ×2 difficultés : statistiques, sorts et comportements identiques avant/après entrée. Aucun sort supprimé annoncé. |
| 2 | Corriger la vente d'Obole et les récompenses sans usage restant | Chaque achat purement économique dispose d'une fenêtre d'amortissement atteignable ; calcul automatique par étape. |
| 3 | Profils ennemis explicites et quelques signatures V2 | Chaque ennemi important impose une réponse identifiable ; les descriptions correspondent. Recalcul des actions dangereuses, pas seulement des PV. |
| 4 | Stabiliser l'accès aux fonctions normales sans supprimer le drop | Comparer distribution actuelle et un sac partiellement orienté, à nombre total de cartes égal. Mesurer tours sans amorce et changements forcés de famille. |
| 5 | Aider préparation, ouverture et améliorations à prérequis | Aucun départ surpris sans ouverture ; taille 30 clairement présentée comme plafond ; dépendances eau/pioche visibles. |
| 6 | Campagnes à statistiques intactes | Quatre classes, huit spécialisations, deux difficultés, plusieurs branches, puis collecte de décisions humaines. Pas de PV réduits ni victoire forcée. |

Pour le dernier chantier, séparer : (a) contrats moteur déterministes, déjà bien couverts ; (b) scénarios tactiques ciblés à stats intactes ; (c) campagnes pour l'économie ; (d) tests humains pour la compréhension et le plaisir. Un agent qui joue mal ne prouve pas qu'une classe est faible, et un agent qui connaît toute la seed ne représente pas un nouveau joueur.

Journaliser au minimum par combat : stock préparé/réserve et par fonction, cartes consommées, secours utilisés, dégâts/soins/garde **effectifs**, tours d'approche, première réaction/Ancre/Relais, commandes de salle, HP perdus à la pression, loot reçu/perdu, or gagné/dépensé, amélioration choisie et nombre d'usages avant épuisement. Comparer médiane et dispersion, pas seulement une moyenne.

## 8. Reproduction et état des preuves

Depuis la racine, PowerShell 7.2+ :

```powershell
./dev.ps1 doctor
./dev.ps1 test consumable-v2
./tools/gameplay_audit_2026_09_28/probe.ps1 -Capture
node tools/gameplay_audit_2026_09_28/calculate.mjs docs/audits/gameplay_2026-09-28/observations.json docs/audits/gameplay_2026-09-28/calculs.json
```

Pour recalculer après une modification du jeu, passer le nouveau `observations.json` produit dans `artifacts/dev/…gameplay-audit-september28…/`, plutôt que l'observation archivée. Le calcul contient un hash SHA-256 du catalogue et des assertions structurelles. Les chiffres ont été arrondis uniquement pour leur présentation dans le rapport.

- `doctor` : Godot **4.7.1.stable.official.a13da4feb**, GUT **9.7.1**, outils présents. Cela ne valide pas l'import à lui seul.
- Premier lancement sandboxé : import refusé sur certificats/sous-dossiers temporaires ; **zéro test**, non compté comme succès.
- Relance avec accès nécessaires : import puis suite ciblée réussis, rapport `artifacts/dev/20260928-092313-test-consumable-v2-6ea5ffa0/gut-strict-report.json`.
- Première sonde ajoutée : construction incorrecte d'un profil d'ouverture vide ; erreur du **harnais d'audit**, corrigée pour employer `ExpeditionRunFactory.make_room()`. Ce n'était pas un échec du jeu.
- Sonde corrigée : 12 scènes, 32 profils, sept captures, aucune erreur moteur ; sondes d'intégration héritées réussies. Les positions arrangées pour les captures et les victoires déclarées sont explicitement exclues des preuves d'équilibrage.
- Mesure complémentaire d'accès aux leviers : `artifacts/dev/20260928-093851-gameplay-audit-september28-371631a2/summary.json`, verdict OK. Les sept captures de cette exécution existent ; les sept images de l'exécution précédente `…093253…14e92e2c` ont été inspectées visuellement. Le supplément de sonde ne modifie pas le placement ou l'interface.
- Format du seul GDScript ajouté vérifié ; syntaxe JavaScript vérifiée ; calculs exécutés avec assertions. Aucun fichier de production modifié.
- Aucune modification du moteur commun : suite globale et CI non exécutées dans cet audit. Les anciennes campagnes/rapports restent historiques.

Les écarts entre `docs/design/cartes_refonte_v2_2026-09-26/REGLES.md`, les métadonnées du catalogue et le parcours public doivent être nettoyés : difficulté, géométrie, marchands, soin et fichier de sauvegarde ne décrivent plus partout le même contrat. `docs/current/cards_v2.md` et le comportement exécuté priment pour cet audit.
