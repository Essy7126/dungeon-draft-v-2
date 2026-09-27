# Investigation WAVEN et critique de Catabase

26 septembre 2026 — lecture du dépôt à `c6ab5a72`, avec travaux locaux préservés. Suite de l'[audit du 25 septembre](../gameplay_critique_2026-09-25/README.md). Les conclusions ci-dessous croisent sources, calculs nouveaux et **120 runs du modèle consommable V1** ; elles ne constituent pas un playtest du jeu Godot.

**Suite disponible : [440 runs supplémentaires, facteurs marchands isolés et politiques de pilotage](suite_02/README.md).** Sur d'autres graines, l'achat unitaire explique l'essentiel du gain marchand ; le bot d'urgence aide, la variante simulant une phase ennemie régresse. Le contrat de Faille transmissible est aussi réexaminé. Les chiffres ci-dessous restent ceux du premier lot.

**Ma recommandation est de consolider la continuité des builds et leurs interactions avec le plateau avant d'ajouter une nouvelle couche de ressources.** Le résultat le plus net vient de la politique marchande : utiliser les achats ciblés déjà autorisés fait passer notre bot de 29 à 38 victoires sur 40. Préparer une normale en ouverture atteint 32/40. Il faut donc réviser le diagnostic du modèle avant de renforcer globalement les classes.

## 1. Quel WAVEN compare-t-on ?

Dans son bilan d'avril 2025, Ankama reconnaît des systèmes empilés, un apprentissage abrupt, une rétention décevante et des objectifs peu lisibles. En août, l'équipe annonce quatre sorts propres et un passif par héros, environ 150 sorts communs, un deck de 16 cartes réunissant sorts et compagnons, et une main allant jusqu'à neuf cartes. La réserve manuelle de PA cède la place à des bonus automatiques au tour suivant. Les compagnons rejoués peuvent évoluer. L'équipement et la fiche de compétences sont retirés dans cette proposition, alors qu'avril prévoyait encore quatre objets. **Ces textes décrivent des intentions de refonte, pas une version actuelle certifiée.** [Bilan officiel et Community Update #2](https://steamcommunity.com/app/2343650/announcements/?l=french).

J'en tire une mise en garde de conception, pas une preuve que toute simplification réussit : rendre les règles plus lisibles doit laisser des choix de position, de cible et de moment. Retirer les équipements de Catabase par imitation ne serait pas justifié. Une run où l'on perd des copies et où l'on cherche du matériel n'a pas les mêmes besoins qu'une progression persistante.

La recherche a retrouvé une actualité officielle liée à la Convention 2026, mais son corps est inaccessible au lecteur. Les coefficients de certains guides de héros se contredisent. Cette étude utilise donc des annonces datées et des correctifs historiques, et distingue explicitement ses propres hypothèses. [Sources et limites](SOURCES.md).

## 2. Les mécanismes de WAVEN qui méritent notre attention

La note historique 0.13.1 donne quatre cas instructifs : Piven convertit une partie du bonus d'attaque en bonus d'aura ; Pramium voit sa génération par Sinistro passer de deux jauges à une ; l'anneau O'Lympic reçoit une limite de vingt jauges et un coefficient de 4 % ; Biste est limitée à deux rejouements. Elle corrige aussi une téléportation Surokan sans destination libre et la prévisualisation autour des Sinistros. [Note Ankama du 15 novembre 2023, reproduite par SteamDB](https://steamdb.info/patchnotes/12707588/).

Ces exemples m'intéressent pour les **relations entre effets**, pas pour importer leurs coefficients.

| Relation à étudier | Lecture critique pour Catabase | Décision proposée |
|---|---|---|
| Une statistique alimente un second usage | Une amélioration peut changer aussi la défense, la zone ou le soutien ; elle doit annoncer exactement ce qui est converti. | Faire porter quelques maîtrises sur un usage alternatif. Éviter un bonus global qui augmente simultanément tous les rôles. |
| Une pose produit une ressource | Le coût initial peut financer plusieurs actions futures ; la durée de vie de l'objet devient une partie de son prix. | Tester un effet persistant limité sur un outil existant avant de créer une armée de compagnons. |
| Une action spatiale déclenche un effet | Déplacement, cible voisine et case d'arrivée peuvent rendre un tour intéressant avec peu de cartes. | Préciser destination valide, nombre de cibles et nombre de déclenchements ; tester le plateau encombré. |
| Une action rejoue une action | Une récompense qui déclenche son propre générateur crée une croissance très différente d'un simple +10 %. | Plafond explicite, provenance de l'événement et exclusions de récursion. |
| La prévisualisation couvre toute la chaîne | Le joueur doit prévoir ce qu'il déclenche, y compris autour de plusieurs objets. | Afficher dégâts, garde dépensée, déplacement et ressources restantes avant confirmation. |

Le bon critère pour une carte signature est : **modifie-t-elle le choix du joueur sur une situation concrète ?** Une carte supplémentaire qui fait le même dégât avec un autre nom ne répond pas à ce critère. Un petit déplacement qui annule une intention peut y répondre.

## 3. Notre projet : séparer trois problèmes

| Niveau | Ce que les sources établissent | Implication |
|---|---|---|
| Produit Godot actuel | Dix copies initiales, quatre cartes en main ; les cartes jouées vont en défausse. Classe, spécialisation et mécanismes de salle existent. | Le problème de renouvellement permanent des copies de la V1 n'est pas une panne constatée du jeu public. |
| Proposition consommable V1 | Quinze copies initiales, remplissage à cinq, copies jouées détruites, trois exemplaires maximum par famille préparée, une utilisation par famille et tour. | Le stock à l'échelle de la run devient aussi important que les PA du tour. |
| Bot d'évaluation V1 | Deck plafonné à 20 dans ces expériences ; anticipation limitée ; achats unitaires ignorés dans sa politique de départ. | Ses résultats mélangent qualité des règles, du deck, du pilotage et des achats. |

Sources : [produit](../../current/product.md), [défausse Godot](../../../core/expedition/catabase_cards.gd), [règles V1](../consumable_v1/REGLES_V1.md), [politique de run](../consumable_v1/run.mjs).

Autre différence importante : le [modificateur Godot](../../../core/expedition/class_card_modifier.gd) choisit le passif de spécialisation à la place de celui de classe quand une spécialisation existe ; la V1 peut appliquer classe et spécialisation ensemble. Une proposition inspirée d'un « passif + moteur » doit préciser laquelle de ces architectures elle vise.

Les travaux de sélection en cours rendent la composition du deck et ses informations plus accessibles. Ils servent cette direction, mais leur existence ne prouve pas encore que le joueur comprend le coût d'une copie consommable. Ce point exige une observation humaine après intégration.

## 4. Nouveaux calculs : pourquoi agrandir la main ne suffit pas

Supposons une main uniforme, sans remise. Pour deux familles disjointes A et B :

`P(A et B) = 1 − C(N−a,h)/C(N,h) − C(N−b,h)/C(N,h) + C(N−a−b,h)/C(N,h)`.

| Deck / main observée | Copies par famille | Une famille accessible | Les deux ensemble |
|---|---:|---:|---:|
| 16 / 9 | 1 | 56,25 % | 30,00 % |
| 20 / 5 | 1 | 25,00 % | 5,26 % |
| 20 / 5 | 3 | 60,09 % | 33,09 % |
| 15 / 5 | 3 | 73,63 % | 51,45 % |
| 30 / 5 | 3 | 43,35 % | 16,53 % |

La première ligne est une comparaison mathématique inspirée des dimensions annoncées, **pas la règle d'ouverture vérifiée de WAVEN**. Une main maximale de neuf ne prouve pas que le jeu distribue neuf cartes au premier tour, ni que toutes les cartes y sont présentes en un seul exemplaire.

Le résultat utile : notre deck 20/main 5 à trois copies peut réunir deux familles légèrement plus souvent qu'un hypothétique 16/main 9 à une copie. Comparer uniquement le ratio main/deck est trompeur. Avec une copie A préparée parmi les cinq cartes et trois B dans le reste du deck de 20, le rendez-vous A+B atteint **53,04 %**, sans augmenter la main.

Une main plus grande augmente aussi les possibilités d'ordre : cinq cartes distinctes donnent 20 paires ordonnées, neuf en donnent 72, soit ×3,6. Cela ne mesure pas le temps de réflexion réel : PA, cibles, portée et effets réduisent les séquences légales. Cela suffit néanmoins à justifier un essai de préparation ciblée avant une hausse générale à neuf.

Calculs reproductibles et contrôle par énumération indépendante : [calculs.mjs](calculs.mjs), [CALCULS.json](CALCULS.json).

## 5. Ce que les 120 runs changent dans l'audit

| Classe | Référence | Normale préparée | Politique marchande ciblée |
|---|---:|---:|---:|
| Assassin | 10/10 | 10/10 | 10/10 |
| Gardien | 8/10 | 8/10 | 10/10 |
| Arpenteur | 7/10 | 7/10 | 10/10 |
| Thaumaturge | 4/10 | 7/10 | 8/10 |
| **Total** | **29/40** | **32/40** | **38/40** |

Les trois bras utilisent les mêmes graines, la première spécialisation de chaque classe et les mêmes coefficients de combat. L'ouverture améliore cinq issues et en dégrade deux ; la politique marchande en améliore neuf et n'en dégrade aucune ici. Les dix graines par classe restent un petit échantillon. [Protocole, coûts et résultats complets](EXPERIENCES.md).

**Mon diagnostic devient plus précis : la continuité fonctionnelle du build doit être évaluée avant la puissance brute.** Le bot initial gardait des centaines d'or sans acheter certaines pièces manquantes disponibles à l'unité. Une partie des échecs lui appartient donc. Cela ne prouve pas que les prix sont bons ni que les humains utiliseront spontanément le marchand.

L'essai ciblé a payé ses cartes et sacrifié des normales aux trocs. Sur les 29 paires gagnées des deux côtés, il utilise 2,03 copies de moins, dépense 44,14 or de plus en cartes et termine avec 29,52 or de moins. Les deux défaites restantes sont celles du Thaumaturge au combat 3, avant tout marchand. Il faut leur chercher une réponse précoce, pas gonfler les récompenses tardives.

Les traces de ces deux défaites précisent le problème : plus de **97 % des PV perdus proviennent de la pression**, avec seize gestes de garde et une mort au tour 17. Le bot a épuisé ses attaques préparées, continue à se protéger et n'évalue pas explicitement le coût futur de cette pression. Le diagnostic porte donc aussi sur son pilotage et l'offensive conservée pour la troisième salle. [Relecture détaillée](EXPERIENCES.md).

Je donnerais donc une place visible à « fonctions de mon build à renouveler » : exemplaires en réserve, exemplaires préparés, prochaine halte, achat unitaire et coût du troc. Le joueur garde la décision ; une recommandation ne doit pas vendre automatiquement ses cartes.

## 6. Les ressources : trois pièges de transposition

### Stocker des PA et en créer ne donnent pas le même budget

À quatre PA par tour, deux tours valent huit PA. Conserver un PA du premier pour le second produit `3 + 5 = 8`. Ajouter un bonus gratuit au prochain produit `4 + 5 = 9`, soit **+12,5 %** sur les deux tours. Le premier déplace un budget dans le temps ; le second l'augmente. Les deux ouvrent une séquence de cinq PA, mais pas au même coût.

Catabase possède déjà les réservoirs. Dans les sources Godot, six charges donnent **132 dégâts avant défense** et la décharge coûte un PA. Dans la V1, elles donnent `3 × P du héros` : **120 à P40**, **336 à P112**, **436,8 à P145,6**. Le texte V1 parle pourtant de puissance de référence de rencontre. C'est une divergence à arbitrer, déjà signalée dans le premier audit, ici confrontée aussi au Godot actuel. Ajouter une réserve globale avant de fixer ces contrats multiplierait les ambiguïtés.

### Lire une ressource et la dépenser ne sont pas équivalents

Scénario de conception, sans prétention de reproduire un héros WAVEN : 32 garde, une attaque ajoutant 50 % de la garde actuelle, trois lectures sans perte intermédiaire. Le supplément cumulé vaut **48 dégâts**, et les 32 garde sont encore disponibles. Consommer ces 32 à un taux de 150 % donne aussi **48 dégâts**, mais supprime la défense.

Les mêmes 48 dégâts cachent deux coûts différents. Pour une garde gardée, il faut préciser sa durée et ce qui la réduit ; dans la V1 actuelle elle disparaît au début du tour suivant. Ce scénario ne peut donc pas être étendu à trois tours sans changer les règles. Répercussion doit être évaluée avec les dégâts, la garde perdue, la portée et les PA, pas seulement avec un coefficient de conversion.

### Les déclencheurs se multiplient

Scénario proposé : chaque téléportation inflige `0,25 P` à trois ennemis voisins. Deux téléportations donnent **1,50 P**, soit 60 dégâts à P40, hors dégâts des cartes. Limiter à une arrivée donne encore 30 ; limiter à une cible une fois donne 10. « Une fois » est un texte insuffisant si l'on ne précise pas une fois par quoi.

Autre exemple abstrait : si une action a une probabilité constante `p` de se répéter, l'espérance sans limite vaut `1/(1−p)`. À 80 %, cela fait cinq actions ; avec deux rejouements maximum, `1+p+p² = 2,44`. Ce n'est pas le taux critique d'un compagnon de WAVEN : c'est une mesure du risque mathématique d'une boucle. Notre garde-fou devrait porter sur la chaîne entière, pas sur chaque nouvel objet créé.

## 7. Arbitrage des améliorations déjà proposées

| Proposition | Avis après cette investigation | Motif / prochain critère |
|---|---|---|
| Achats et trocs ciblés | **Priorité immédiate pour le laboratoire et l'ergonomie** | Signal mesuré fort, aucune nouvelle règle nécessaire. Séparer ensuite achat, troc et protection de cartes si l'on veut identifier leur contribution. |
| Une normale préparée en ouverture | **Bon prototype limité** | Accès amélioré ; gain de victoire hétérogène. Surveiller le choix imposé qui remplace une meilleure réponse de main. |
| Grande main générale | **Différer** | La densité des familles et leur renouvellement expliquent déjà beaucoup. Le coût de lecture et de sélection augmente. |
| Répercussion avec sacrifice choisi | **Clarifier d'abord le contrat** | Conserver le taux faible actuel et choisir la garde dépensée n'est pas la même proposition que monter à `0,70 P + 1,50 × sacrifice`, plafond `0,80 P`. Tester séparément confort de sacrifice et puissance. |
| Condensation feu → garde à 2 PA | **Reconcevoir autour de l'extinction** | Un tic de feu de base vaut 0,35 P, contre 0,45 P de garde commune à un PA. La suppression d'une zone dangereuse doit fournir l'intérêt réel ; « conversion » n'est pas une valeur en soi. |
| Maîtrises qui changent l'usage | **Oui, sur quelques familles** | Tester angle, durée, transfert ou choix de destination. Garder aussi des améliorations de dégâts lorsque leur seuil change un kill. |
| Pièces persistantes / compagnons | **Petit essai avant système complet** | Peut amortir une copie sur plusieurs tours, mais ajoute occupation, durée, ciblage, destruction, activation et parfois économie d'action. |
| Réserve globale de PA ou nouvelle jauge par classe | **Non prioritaire** | Les PA, PM, garde, marques, surfaces et salles offrent déjà plusieurs décisions ; expliciter leurs interactions avant d'ajouter une barre. |
| Réduire globalement la difficulté du Thaumaturge | **Pas démontré** | L'accès marchand corrige quatre défaites sur dix ; les deux échecs précoces sont dominés par la pression après épuisement de l'offensive. Examiner le pilotage avant un buff. |

Le premier audit montrait que Répercussion souffre au contact face à Garde ferme + Heurt. La portée 1–3 lui conserve des usages ; elle n'est pas dominée dans toutes les situations. Les expériences présentes n'ont pas changé son coefficient et ne valident donc aucune de ses refontes.

## 8. Comment cela complète les autres références

Les études locales de [Slay the Spire](../slay_the_spire_complete_2026-09-25/APPLICATION_CATABASE.md) et [Dofus/Wakfu](../dofus_wakfu_spell_identity_2026-09-25/IDENTITE_ET_EQUILIBRAGE.md) restent utiles, sans être de nouvelles validations ici.

| Question de notre conception | Référence à mobiliser | Ce qu'il faut mesurer chez nous |
|---|---|---|
| Réunir une préparation et sa conclusion | Étude StS : accès, rétention, ordre | Copies disponibles, places de main, coût PA, coût définitif des copies. |
| Exploiter la géométrie | Études Dofus/Wakfu : placement, obstacle, état | Intention annulée, cible atteinte, zone rendue sûre, nouvelle exposition. |
| Construire autour d'une règle de héros | WAVEN : déclencheur, conversion, limite | Fréquence réelle du passif, ordre des effets et lisibilité du résultat. |
| Maintenir un build pendant douze combats | Spécificité consommable de Catabase | Fonction encore jouable au prochain combat, dépenses de renouvellement, options de secours. |

La différence à défendre pour notre jeu est le choix entre dépenser une copie maintenant et exploiter position, état ou mécanisme de salle pour l'économiser. Le build doit continuer à fonctionner tout en se transformant avec les trouvailles. Une suite de cartes rares indispensables ou de jauges à remplir n'améliore pas automatiquement ce choix.

## 9. Suite concrète

Quatre propositions limitées, leurs budgets et leurs cas d'échec sont détaillés dans [PROTOTYPES.md](PROTOTYPES.md). Mon ordre : rendre visible le renouvellement, corriger l'évaluation de l'urgence du bot puis réexaminer l'ouverture Thaumaturge, clarifier Répercussion, et essayer une interaction spatiale sur une maîtrise existante. Une pièce persistante vient après ces essais.

Critères communs à un playtest : le joueur explique sa prochaine combinaison ; il voit sa pièce manquante et un moyen réaliste de la retrouver ; le placement change au moins une décision ; il comprend pourquoi un effet ne se déclenche pas ; il sait ce qu'il perd en consommant la carte. Aucun pourcentage de victoire automatique ne remplace ces observations.

Fichiers exécutables : [calculs](calculs.mjs), [expériences](experiences.mjs), [vérificateur](verifier.mjs). Résultats : [CALCULS.json](CALCULS.json), [EXPERIENCES.json](EXPERIENCES.json), [VERIFICATION.json](VERIFICATION.json). Ce dossier ne modifie ni le moteur Godot ni le manifeste V1.
