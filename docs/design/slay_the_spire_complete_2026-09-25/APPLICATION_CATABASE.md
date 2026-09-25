# Transposition à Catabase et au projet de cartes consommables

Comparaison documentaire au commit `6a500c545f04d3e4c53a99d3643d0c4d844e303f`, le 25 septembre 2026. Il faut distinguer le **catalogue Godot actuel** et la **V1 théorique consommable** du dossier de recherche : les règles de cette dernière ne sont pas toutes intégrées au jeu. Les propositions ci-dessous ne modifient aucun des deux.

Références : [règles de la V1](../consumable_v1/REGLES_V1.md), [ses 48 familles et améliorations](../consumable_v1/content.mjs), [inventaire statique des 112 cartes Godot](../spell_comparison_2026-09-25/INVENTAIRE_LOCAL.md), [catalogue de classe](../../../core/expedition/class_card_catalog.gd), [cartes avancées](../../../core/expedition/card_ecosystem_catalog.gd).

## 1. Les différences qui changent la valeur d’une carte

| Axe | Slay the Spire 1 | Notre socle consommable V1 | Conséquence |
|---|---|---|---|
| Vie d’un exemplaire | Une carte ordinaire revient après remélange ; Épuisement ne dure qu’un combat. | Une résolution valide consomme définitivement la copie ; les cartes non jouées recirculent. | Rampage, Claw, Streamline, Headbutt et Hologram ne sont pas transposables à l’identique. |
| Pioche | 5 par tour, main normalement limitée à 10. | Remplissage jusqu’à 5, modifié par équipement, plafond 7. | Si nous ajoutons la rétention sans changer ce remplissage, conserver 3 laisse seulement 2 nouvelles places. Ce n’est pas la même accélération que 3 retenues + 5 piochées. |
| Répétition | Plusieurs copies d’une même carte peuvent être jouées dans le tour. | Une carte par famille par tour ; préparation limitée à 3 copies par famille. | Un paquet de trois jetons d’une même famille devient inutilisable tel quel. Il faut spécifier leur statut ou choisir un effet à plusieurs impacts. |
| Espace | Combat sans grille ni déplacement tactique. | Grille 7 × 7, 4 PA, 3 PM de base, portées et lignes de vue. | Un déplacement et une poussée peuvent supprimer une intention ou déclencher un danger : le rendement ne se mesure pas uniquement en dégâts / PA. |
| Progression | Exemplaires améliorés, pouvoirs de combat, reliques et croissance de certaines cartes. | Classe, statistiques, équipement, reliques et trois améliorations de famille stabilisent le build. | La famille ou le personnage doit porter les investissements qui doivent survivre à une consommation. |
| Butin | Les cartes sont principalement des acquisitions durables pour le deck. | Sacs sur les monstres éligibles, plusieurs cartes normales, canaux de rareté, réserve et troc. | L’accès aux fonctions de base doit rester assuré par des drops abondants ; copier le choix de récompense de StS changerait le concept demandé. |

Le point principal est donc de reprendre **les relations entre effets** : produire une condition, la déplacer, la convertir, préparer une fenêtre, choisir un sacrifice. Un moteur qui demande de rejouer indéfiniment le même exemplaire contredit directement notre ressource consommable.

## 2. Ce qui existe déjà et qu’il faut renforcer

Le jeu Godot possède déjà des différences spatiales significatives : `a_open` / `a_finish` associent marque et finition au contact ; `g_guard` / `g_hit` relient garde et attaque ; `r_shot` impose une plage de distance ; les cartes du Thaumaturge utilisent éléments et surfaces. Les familles techniques communes ne prouvent pas, seules, que les cartes ont le même usage.

Il existe aussi des salles à règles propres : Forge, Jardin, Convoi, Sablier et Réservoirs. Les réservoirs convertissent déjà des PA stockés en action de salle ; il serait faux de diagnostiquer une absence générale de conversion de ressources. Ce sont des supports naturels pour différencier les builds. [Catalogue de salles](../../../core/expedition/card_tactical_room_catalog.gd), [règles de ressources](../../../core/expedition/card_tactical_resource_rules.gd), [règles de salle](../../../core/expedition/card_tactical_room_rules.gd).

Dans la V1, Répercussion (`g09`) convertit une garde consommée avec plafond ; l’Obole plafonne ses gains d’or ; les invocations n’ouvrent pas de nouvelles tables de drop. Ces restrictions répondent déjà à une partie des risques observés dans les moteurs de création ou de croissance. Il faut les conserver dans les tests, pas les retirer implicitement en ajoutant des cartes inspirées de StS.

## 3. Les manques les plus concrets de la V1

### A. Des améliorations trop souvent interchangeables

Dans `content.mjs`, **33 des 48 familles, soit 68,75 %**, reçoivent uniquement `damage + 0.15` comme amélioration. Comptage réexécuté pendant cette étude. Pour `a02` Frapper la faille, le bonus sur cible marquée ne change pas ; pour `g09` Répercussion, seule l'attaque de base monte. Ce n’est pas la preuve d’un mauvais équilibre, mais cela montre que l’amélioration exprime peu la spécialisation de ces cartes.

Piste prioritaire : faire varier **une dimension de décision** sur une partie du catalogue. Par exemple, portée contrôlée, destination de poussée, choix de carte à préparer, condition plus accessible ou portion de garde préservée. Chaque changement doit garder une contrainte ; rendre toutes les attaques moins chères et plus longues supprimerait leurs différences.

### B. Peu d’outils pour réunir les pièces au bon moment

Recentrage (`n08`) fournit une pioche générale. La V1 ne décrit pas encore l’équivalent précis d’une rétention choisie, d’un tutorat limité ou d’un filtrage Scry. Or notre consommation réduit au fil du combat les exemplaires disponibles : une carte qui prépare une autre carte paie aussi une copie définitivement perdue.

Avec trois exemplaires d’une réponse dans un deck de 15, une main de 5 la contient dans **73,63 %** des cas ; dans 30 cartes, **43,35 %**. Pour avoir simultanément au moins une carte de chacune de deux familles à trois copies : **51,45 %**, puis **16,53 %**. Calculs M38/M39, tirage uniforme initial, sans sélection. Le plafond 30 doit rester un plafond, pas une obligation implicite de remplir.

Il faut donc tester la fiabilité d’accès avant de multiplier les cartes conditionnelles. Une réponse fréquente mais très précise, ou un outil commun de sélection, peut mieux aider le joueur qu’une nouvelle rare spectaculaire.

### C. Des conditions nombreuses, mais des transformations encore limitées

Marque, déplacement, garde et brûlure donnent déjà des conditions. Dans la V1, brûlures et entraves ne s’additionnent pas ; la marque est consommée au prochain impact. Ces règles limitent les explosions de puissance, mais rendent parfois un second exemplaire utile seulement après disparition du premier état.

Pour enrichir sans augmenter les cumuls, proposer des **usages alternatifs de l’état** : déplacer une marque, dépenser une brûlure pour déplacer sa zone, choisir de préserver une partie de garde. Cela produit une décision sur une ressource plafonnée. Pressure Points ou Catalyst nécessiteraient au contraire de réécrire nos règles de cumul ; leurs nombres ne sont pas transposables.

### D. La rareté doit changer les possibilités, sans privatiser les fonctions vitales

Une classe ne doit pas attendre un drop légendaire pour disposer de placement, d’une défense et d’un moyen de finir une cible. Les cartes communes peuvent préparer et exécuter une petite combinaison ; une rare en change l’étendue ou le moment. L’élite ou la légendaire peut ouvrir une conversion nouvelle, avec une solution de remplacement plus modeste.

La V1 a déjà ses sacs, canaux de rareté et accès marchand : cette étude ne remplace pas ces taux. Elle ajoute un critère de contenu : **la probabilité d’obtenir une fonction utile** doit être mesurée en plus de la probabilité d’obtenir une rareté. Dix normales redondantes ne résolvent pas l’absence de sortie tactique.

## 4. Six prototypes de règles à comparer, pas encore des cartes validées

Valeurs volontairement exprimées avec les unités actuelles. Ce sont des variantes de laboratoire à tester séparément, pas un nouveau catalogue adopté ni une balance prouvée. Chacune consomme sa propre copie selon la V1.

| Prototype | Contrat de départ proposé | Différence d’amélioration à essayer | Risque et essai indispensable |
|---|---|---|---|
| Lecture du danger — commune | 1 PA ; regarde les 3 prochaines cartes ; peut en envoyer jusqu’à 2 en défausse, puis pioche 1 dans la limite de main. Ne détruit pas les cartes écartées. | Regarde 5, sans augmenter la pioche. | En main déjà pleine, l’accès net est nul. Comparer à Recentrage et à une attaque supplémentaire dans la même graine ; vérifier les petits stocks. |
| Réserve de geste — commune | 1 PA ; gagne 0,35 P de garde ; choisit une autre carte à retenir jusqu’au prochain tour. | La carte peut être conservée pendant deux transitions de tour au maximum. | Sous remplissage jusqu’à 5, retenir remplace une future nouvelle carte. Afficher ce coût ; pas de réduction de PA gratuite ajoutée au premier essai. |
| Transfert de faille — Assassin | 1 PA, portée 1–3 ; déplace une marque existante d’un ennemi vers un autre à distance ≤2 du premier ; conserve valeur et durée restante, sans dupliquer. | Distance de transfert 3. | Il faut deux cibles et une marque : pas une normale de secours universelle. Mesurer les tours où la carte est morte ; vérifier la mort du porteur initial. |
| Répercussion maîtrisée — variante de `g09` | Conserve coût, portée et plafond de dégâts de `g09` ; choisit la quantité de garde engagée dans sa conversion. | Augmente la portée de 3 à 4 plutôt que les dégâts. | Permet de conserver une défense contre l’intention suivante. Ne pas ajouter simultanément gain de dégâts et réduction du sacrifice. |
| Tir de relais — Arpenteur | 2 PA, portée 2–4 ; 0,80 P de dégâts ; si le héros a parcouru au moins 2 cases ce tour, pioche 1. | Autorise aussi la distance 1 ; dégâts inchangés. | La pioche ne rembourse ni la copie ni les PM déjà dépensés. Comparer sur carte ouverte, couloir et zone dangereuse. |
| Condensation — Thaumaturge | 2 PA, portée 1–3 ; retire une zone de feu alliée choisie ; gagne une garde égale à un seul tic de cette zone, plafonnée à 0,60 P. | Autorise la conversion d’une zone distante de 4. | Conversion terrain → défense, sans retour terrain récursif. Définir propriété de zone, cases touchées et disparition avant d’implémenter. |

Ces propositions illustrent six axes différents : sélection, rendez-vous temporel, déplacement d’une condition, choix d’un sacrifice, pont placement/pioche, conversion de terrain. Leur intérêt doit être évalué par rapport aux cartes déjà disponibles ; elles peuvent remplacer des redondances plutôt que simplement grossir le pool.

## 5. Création de cartes : préserver l’économie des drops

Blade Dance montre l’intérêt des petites actions générées, mais notre règle par famille et notre économie imposent une décision préalable. Deux approches sont cohérentes :

- **Rafale dans une seule carte** : une copie consommée provoque trois impacts. Cela conserve la limite par famille et n’ajoute pas trois objets d’inventaire. Les déclencheurs comptant une carte voient un jeu ; ceux comptant un impact peuvent en voir trois.
- **Jetons temporaires explicites** : exemplaires de combat sans revente, troc, réserve ni drop ; budget d’utilisation propre annoncé. C’est une extension des règles, à justifier par un vrai choix de cibles ou d’ordre que la rafale n’offre pas.

Je recommande d’essayer d’abord la rafale lorsque les trois actions seraient de toute façon identiques. Réserver les jetons aux situations où le joueur décide effectivement comment les répartir. Ne pas créer silencieusement une exception à « une famille par tour » pour obtenir le chiffre attendu.

Si les jetons sont retenus, leur provenance doit suivre toute copie : `loot`, `initial`, `combat_generated`, avec un identifiant de racine pour les limites éventuelles. Une copie de jeton ne doit pas devenir une carte revendable. Un effet « quand une carte est consommée » doit dire s’il accepte ces jetons. Sans cela, un générateur peut se nourrir de ses propres enfants ; M42 montre une croissance 1, 2, 4, 8, 16 pour deux descendants par usage.

Une carte issue de drop qui génère d’autres cartes permanentes nécessiterait un budget économique explicite et une destruction nette contrôlée. Elle n’est pas une simple variante de Blade Dance. Les sacs de monstres restent la source principale de renouvellement demandée par le concept.

## 6. Quatre identités de build à approfondir

| Classe | Verbe dominant proposé | Entrées | Conversions | Décision à préserver |
|---|---|---|---|---|
| Assassin | Préparer une victime | Marque, angle, cible affaiblie | Déplacer une faille, consommer une ouverture, exécuter | Dépenser la marque maintenant ou changer de victime ; ne pas donner toutes les récompenses au même coup automatiquement. |
| Gardien | Engager une réserve | Garde, passage occupé, menace absorbée | Riposte, protection, dégâts depuis garde | Quelle part garder pour l’ennemi suivant ? Le plafond et la consommation distinguent ce moteur de Barricade. |
| Arpenteur | Organiser les distances | PM, portée, ligne de vue, trajectoire ennemie | Déplacement vers accès aux cartes ou tir amélioré | Dépenser du mouvement pour attaquer ou garder une position sûre ; le terrain doit modifier la bonne réponse. |
| Thaumaturge | Transformer le terrain | Surfaces, placement ennemi, état élémentaire | Déplacer, condenser, activer ou consommer une zone | Quel état maintenir pour le prochain tour, quel état dépenser maintenant ? Éviter quatre versions colorées du même dégât direct. |

Ce tableau est une orientation de recherche. Il ne suppose pas qu’une classe actuelle soit dépourvue de ces propriétés. Les cartes étrangères et les communes peuvent devenir des ponts, à condition que chaque classe garde une manière distincte de rentabiliser la même condition.

## 7. Vérifications à mener après cette étude

Priorité 1 : tester accès et pioche avec stock de 15, 20 et 30, cartes utiles rares, réserve faible et adversaire imposant le placement. Mesurer la première réponse disponible, les copies consommées par fonction et les tours sans action satisfaisante.

Priorité 2 : remplacer un petit groupe d’améliorations de dégâts par des changements de règle, puis comparer les mêmes rencontres. Vérifier qu’une amélioration crée une décision ou une nouvelle utilisation sans rendre l’ancienne contrainte inexistante.

Priorité 3 : ajouter un seul moteur de conversion par classe et une épreuve adverse qui le sollicite sans l’interdire totalement. Nos dispositifs de salle peuvent fournir cette épreuve ; nul besoin de copier Time Eater et son compteur hors contexte.

Priorité 4 : si génération temporaire, dette, croissance de famille ou économie en combat sont introduites, tester leurs compositions avec les caps de reliques, les morts simultanées, les invocations, les reprises de sauvegarde et les échanges. L’équilibrage du drop et celui du combat sont alors le même problème de conservation des ressources.

Ce travail constitue une base pour ces essais. Les [calculs exécutés](CALCULS.md) n’ont pas testé ces six prototypes dans Godot, ni mesuré le plaisir de consommation ou la durée humaine d’un combat.
