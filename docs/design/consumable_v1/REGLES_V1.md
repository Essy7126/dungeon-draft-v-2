# V1 théorique — règles fermées

Version : `1.0.1-theory`, 25 septembre 2026. Cette proposition est un **jeu de règles exécutable indépendant**, pas le comportement actuellement livré par Godot. Les noms, identifiants et nombres font foi dans [le manifeste](manifest.json) ; les effets sont lisibles dans [le catalogue](CATALOGUE.md). Les résultats et limites sont dans [le bilan](BILAN.md).

## 1. Promesse et périmètre

Le joueur prépare des munitions tactiques, les dépense pour traverser une rencontre, récupère plusieurs sacs sur les morts éligibles et reconstruit son stock. Sa classe, ses caractéristiques, trois améliorations de famille, son équipement et ses reliques stabilisent son identité malgré le renouvellement des exemplaires.

Une run solo comporte vingt profondeurs, douze combats obligatoires et huit haltes. Le joueur commence au niveau 1, avec 40 or et quinze normales choisies parmi les huit communes et les quatre normales de sa classe, au maximum trois exemplaires de chaque famille. Les cinq familles × trois du catalogue sont des préparations conseillées, pas les seules autorisées. Le modèle automatique utilise ces préparations fixes.

Les objets, cartes, or, XP et améliorations disparaissent à la fin de la run. La collection extérieure mémorise seulement les découvertes et les résultats ; **aucune puissance permanente**, aucun achat payant de sac, aucun marché entre joueurs. Le profil de difficulté V1 est unique ; les expériences de stress ne sont pas des modes publics.

## 2. Exemplaires, réserve, préparation

Un exemplaire a un identifiant unique et une famille. La rareté et les effets viennent de la famille. Pas de durabilité, de charges multiples, d’affixes aléatoires ni de niveau propre à l’exemplaire.

La réserve contient tous les exemplaires non consommés. Le deck préparé en sélectionne de zéro à trente, avec au plus trois de la même famille. Un deck vide est légal afin de ne jamais bloquer une sauvegarde ; il est extrêmement risqué. La réserve n’alimente pas un combat commencé. Préparer, changer d’équipement ou de relique est libre hors combat. Les cartes étrangères sont jouables aux mêmes coûts ; leur utilité dépend du build, pas d’une pénalité cachée.

Une carte quittant la main après **résolution valide** est consommée définitivement. Une sélection annulée ou illégale ne coûte ni PA ni carte. Une carte non jouée passe en défausse en fin de tour et peut être repiochée. Le combat suivant récupère tous les exemplaires non consommés, quelle que soit leur dernière zone. Les améliorations appartiennent à la famille : consommer un exemplaire ne détruit pas l’investissement.

## 3. Tour et tirage

Grille carrée 7 × 7. Le héros commence, puis les ennemis agissent dans l’ordre de la liste de rencontre. Pas d’initiative variable, de critique aléatoire, d’esquive aléatoire ou de jet pour toucher dans ce socle : l’incertitude vient du stock, de la pioche et du butin.

Au début du combat, on mélange le deck ; au début de chaque tour, on remplit la main jusqu’à cinq cartes, modifiée par l’équipement, plafond sept. On **ne pioche pas seulement deux cartes par tour**. À la fin du tour, toute la main inutilisée passe en défausse. Si la pioche est vide, on mélange la défausse ; les exemplaires consommés n’y reviennent jamais. Recentrage pioche des exemplaires existants jusqu’à la limite de main.

Le héros récupère 4 PA et 3 PM de base. Les PM sont plafonnés à 5, avec plancher 1 sur le maximum de départ. Au plus une carte par famille et par tour, indépendamment du nombre de copies en main. Pas de report de PA/PM entre tours, sauf les réservoirs locaux explicitement décrits plus bas.

Deux gestes restent disponibles sans consommer de carte : attaque de secours à 1 PA, portée 1, dégâts physiques 0,28 P ; garde de secours à 1 PA, valeur 0,25 P. Chacun une fois par tour. Ils ne déclenchent pas les passifs d’impact direct de carte, les marques, l’Obole, la Coupe ou le vol de vie. Ils permettent de finir un ennemi et de sauver des copies, sans fournir un moteur offensif suffisant pour toute la run.

## 4. Déplacement et ciblage

Les distances sont de Manhattan. Marcher coûte un PM par case d’un chemin libre ; les murs, les unités vivantes et les limites du plateau bloquent ce chemin. Pas de déplacement diagonal, de tacle, d’attaque d’opportunité ni de coût en PA pour marcher.

Un déplacement par carte coûte ses PA et sa copie, sans dépenser de PM. Pas latéral exige un chemin libre ; une téléportation traverse les obstacles mais termine sur une case libre. La portée des téléportations dépend de la carte, pas d’un bonus général de portée. Les déplacements comptent pour les conditions « deux cases parcourues » ; la permutation ne compte pas comme marche.

Les attaques ciblées exigent une ligne de vue ; le modèle utilise une ligne discrète de Bresenham bloquée par les murs, pas par les unités. Le portage Godot doit reproduire cette convention ou annoncer sa révision. Le bonus de portée augmente le maximum, jamais le minimum. Les cartes en croix frappent la cible et ses quatre voisines ; la portée et la ligne de vue portent sur le centre. Les surfaces peuvent viser une case libre ; les autres attaques exigent une cible vivante. Convergence peut donc viser un centre vide.

Poussée et attraction avancent case par case selon l’axe principal vers/depuis leur origine ; en cas d’égalité, priorité à l’axe horizontal. Un obstacle arrête immédiatement le déplacement. Aucun dégât de collision dans cette V1. Les boss se déplacent d’une case maximum par effet, et ne sont pas permutables.

## 5. Ordre des dégâts et protections

Pour un impact direct : coefficient de carte + éventuel bonus conditionnel, le tout multiplié par P ; puis bonus d’équipement applicables additionnés ; puis bonus de classe/spécialisation ; puis marque existante ; puis résistance ; puis bouclier ; puis PV. Les valeurs sont des réels dans le modèle, sans arrondi intermédiaire. Seuls les PV maximums et les caractéristiques initiales des monstres sont arrondis à l’entier le plus proche. L’interface proposée affiche une décimale et une prévision précise ; elle ne décide jamais une mort à partir du texte arrondi.

Les résistances physiques et magiques sont séparées, plafonnées à 40 %. Les monstres V1 ont une résistance physique indiquée dans le manifeste et zéro résistance magique ; aucun ennemi n’est totalement immunisé à un canal. Le percement ignore la résistance physique, pas un bouclier.

La garde produite reçoit les bonus de résolution/équipement et, le cas échéant, Bastion. Elle absorbe les impacts des deux canaux. Son stock est plafonné à 2,5 P et expire au début du prochain tour du héros. « Garde absorbée » mesure la protection réellement dépensée, pas la garde produite ou perdue par expiration. Le bouclier de départ du Casque s’applique après l’initialisation du premier tour.

La marque ajoute une valeur au prochain impact direct de carte, puis disparaît. Appliquer une nouvelle marque ne l’additionne pas à l’ancienne : on conserve la plus forte et on remet sa durée à deux phases ennemies. Si la carte inflige d’abord des dégâts puis une marque, l’ancienne marque est consommée par les dégâts et la nouvelle est posée ensuite. Les impacts de zone peuvent consommer séparément les marques de chaque cible.

Les soins sont plafonnés aux PV manquants. Prélèvement et le vol de vie utilisent les **PV réellement retirés**, après bouclier et sans sur-dégâts. Le vol de vie d’équipement est plafonné à 10 % des PV max effectivement soignés par combat, après bonus de soins. Il n’existe pas de résurrection des exemplaires. La garde convertie par Répercussion est consommée une fois, avec un bonus de dégâts limité à 1,2 P.

## 6. Contrôles, dégâts différés et déclenchements

Brûlure : tic magique au début de l’activation ennemie, deux activations par défaut ; les applications ne s’additionnent pas, on conserve le tic le plus fort et la durée la plus longue. L’Entaille de l’Assassin emploie ce même statut magique pour garder un seul moteur de dégâts différés ; son texte doit le dire clairement. Entrave : réduction de PM pour la prochaine activation, maximum des effets concurrents, pas de cumul additif.

Couper le souffle réduit la prochaine attaque de 50 %, puis expire à l’issue de l’activation ; 25 % contre un boss. Il ne retire pas de PA dans ce modèle, car les ennemis disposent d’une attaque programmée par activation. Sommeil marqué exige et consomme une marque ; il annule une activation ordinaire, puis interdit une nouvelle stase pendant les trois activations suivantes. Sur un boss, il applique seulement l’affaiblissement de 25 %. La stase n’annule pas le tic de brûlure qui précède l’activation.

Deux surfaces persistantes actives au maximum ; poser une troisième retire la plus ancienne. Elles se déclenchent avant les activations ennemies, puis perdent une durée. Le feu touche les deux camps ; le givre entrave les ennemis seulement. Le coefficient du feu utilise P au moment de la pose. Les zones d’une même case peuvent se superposer dans la limite des deux surfaces ; elles ne déclenchent pas de nouvelles surfaces.

Les passifs de classe et de spécialisation sont limités à une fois par tour selon leur condition, sauf les effets permanents explicitement décrits. Une même carte de zone ne multiplie pas un passif « première cible ». Les éliminations directes de cartes déclenchent Obole et Coupe ; brûlures, terrain, secours, ripostes et miroirs ne les déclenchent pas. Le Miroir et la riposte ne peuvent pas se rappeler eux-mêmes.

Pour le Thaumaturge et Givre, « statut appliqué » signifie l’application directe par la résolution d’une carte de marque, brûlure ou entrave. Les tics suivants et l’entrave d’une surface déjà posée ne réactivent pas ces passifs. Brasier améliore la première brûlure directement posée, pas les zones de feu ; la Mèche améliore en revanche les deux effets.

Le Gardien renvoie 0,25 P physiques à l’auteur de la première attaque ennemie dont sa garde absorbe au moins une partie, une fois par tour, après résolution des dégâts reçus. La garde de secours peut l’activer ; la pression et le terrain sans attaquant ne l’activent pas. Ce renvoi ne compte pas comme impact direct de carte. Il remplace le premier prototype de passif donnant une case de poussée supplémentaire. Bastion améliore la première garde issue d’une carte, pas la garde de secours ni le bouclier d’ouverture.

Décret évite **un impact** létal, pas une phase entière : un deuxième impact peut tuer. La pression de fin de combat le traverse. Seconde aurore restaure des PV et termine les PA/PM ; elle ne rembourse aucune carte. Ces deux raretés extraordinaires ne sont requises par aucun build.

## 7. Ennemis, salles, pression

Chaque rencontre fixe son niveau, ses archétypes et son budget de PV. Ces valeurs ne suivent ni l’équipement ni les points investis par le joueur. Le tableau complet est dans [Maths et run](MATHS_ET_RUN.md). Les positions initiales sont héros (3,5), puis ennemis (3,1), (1,1), (5,1), (3,2), coordonnées à partir de zéro. Les cartes de murs sont dans le manifeste.

Un ennemi tente de rejoindre une case depuis laquelle il peut attaquer, à défaut se rapproche ; une attaque maximum si portée et ligne de vue sont valides. Le prêtre ajoute 0,25 P de référence au bouclier de l’allié ayant le plus faible ratio de PV, aux tours pairs. Les boucliers ennemis de la phase précédente sont effacés avant les soutiens de la nouvelle phase. Les porteurs du convoi ont une priorité particulière.

| Salle | Règle V1 calculable | Levier du joueur |
|---|---|---|
| Presse | Après les ennemis, ligne active 1 puis 3 puis 5 ; héros 0,60 P de référence, monstres 1,30 P. | Levier près de (0,3), 1 PA, une fois par tour : choisit la ligne de cette phase ; le cycle continue depuis ce choix. |
| Jardin | Après les ennemis, anneau autour du premier ennemi encore vivant ; rayons successifs 2,3,1 ; 0,60 P physiques aux unités sur l’anneau. | Déplacer la source ou les cibles ; sortir de l’anneau annoncé. |
| Convoi | Ennemis 2 et 3 sont porteurs ; avancent d’une case vers (3,0). À une case du but au début de leur activation, se sacrifient : chef +0,8 P PV actuels/max et +2 % PVbase en dégâts. | Les éliminer avant le sacrifice, ou sceller le relais près de (0,3), 2 PA ; ils reprennent alors leur comportement offensif normal. Un sacrifié ne donne aucun drop. |
| Sablier | Croix de portée 2, centrée initialement sur (3,5), puis sur la position du héros à la dernière explosion ; 0,70 P physiques. | Près de (0,3), 1 PA pour différer une explosion ; la suivante inflige ×1,5. Impossible de différer cette dette une seconde fois. |
| Réservoirs | Près de (0,3) ou (6,3), PA restants stockés en fin de tour, maximum 6. Un ennemi proche vole 1 charge et se soigne de 0,30 P. | Décharge à 1 PA : 0,50 P physiques par charge sur le premier ennemi vivant, sans ligne de vue ; vide le réservoir. |

P de référence désigne la puissance de base du niveau de la rencontre, pas P équipé du héros. Les effets de salle sont annoncés avant validation de fin de tour. Le prototype chiffre ces salles sur 7 × 7 : il ne valide pas leur géométrie actuelle dans Godot.

À partir du tour 9, la fin de phase inflige au héros 2,5 % PV max × (tour−8), sans résistance, garde ni Décret. La pression ne survient pas si le dernier ennemi est déjà mort. À l’issue du tour 24 encore actif : échec par expiration. Une mort simultanée du héros et du dernier ennemi est une défaite. Ce dispositif interdit de gagner de la ressource indéfiniment en temporisant ; son ressenti reste à tester humainement.

## 8. Drop sur les mobs

Le butin de chaque mort éligible est déterminé à la création de la rencontre et révélé après la victoire. Le modèle le calcule à la victoire avec des graines séparées donnant exactement cette propriété : recharger ou changer les actions ne change pas les jets. Pas de capture de technique ennemie, pas de récompense « choisir une carte parmi trois ».

Chaque mob dispose de sept canaux indépendants. Il peut donner simultanément plusieurs sacs. Le premier sac normal, de deux cartes, est garanti. Les taux des canaux suivants croissent par blocs de trois combats :

| Canal | Cartes par succès | Combats 1–3 | 4–6 | 7–9 | 10–12 |
|---|---:|---:|---:|---:|---:|
| Normal A | 2 | 100 % | 100 % | 100 % | 100 % |
| Normal B | 2 | 50 % | 60 % | 75 % | 90 % |
| Élite | 2 | 5 % | 10 % | 18 % | 28 % |
| Rare | 1 | 0,5 % | 1,5 % | 4 % | 8 % |
| Légendaire | 1 | 0 % | 0,1 % | 0,4 % | 1 % |
| Dieu | 1 | 0 % | 0 % | 0,03 % | 0,15 % |
| Immortel | 1 | 0 % | 0 % | 0 % | 0,02 % |

Chaque carte d’un sac tire indépendamment une famille : 70 % dans le groupe classe + communes, 30 % dans les autres classes, puis uniforme dans le groupe. Si le groupe choisi est vide à cette rareté, on utilise toutes les familles de cette rareté. Les doublons sont permis, y compris au sein d’un sac. **Aucun pity timer caché**, aucune correction selon le stock ou le résultat du joueur. Le plancher normal suffit à rendre visible la protection de ravitaillement.

Équipement : un jet séparé par mob à 6/8/10/12 %, puis uniforme parmi les objets accessibles au palier. Relique : 0,2/0,4/0,8/1,2 %, uniforme parmi les huit. Les victoires 5 et 10 donnent en plus une relique ; doublons autorisés, pas de relance sur rechargement. Aucune de ces récompenses ne remplace une carte. Aucun bonus de prospection, maîtrise ou performance dans le socle.

Un ennemi sacrifié au convoi ne laisse pas de sac. Les invocations, si ajoutées plus tard, ne devront jamais créer des occasions de drop nouvelles. Une défaite clôt la run sans emporter le butin. Le boss termine l’économie : pas de carte supplémentaire inutilisable à acheter ou dépenser après la victoire, seulement le résultat et les découvertes.

## 9. Progression et économie

Les XP sont fixes par rencontre et n’augmentent pas quand une stratégie consomme plus de tours. Niveau 12 maximum dans cette run ; les XP finales n’ouvrent pas de niveau 13. Tous les deux niveaux, un point parmi puissance (+5 % Pbase), vitalité (+6 % PVbase), résolution (+2 points de résistance physique et +5 % de garde produite). Six points au total ; pas de remise à zéro des caractéristiques dans cette V1.

Aux niveaux 4, 8, 12 : une famille améliorée, pour trois familles distinctes maximum. Un point peut être gardé en attente. Au niveau 4 : une spécialisation parmi les deux de la classe, définitive pour la run. Un gain de niveau augmente les PV actuels du gain de PV max ; il ne remet pas à pleine santé. Un changement d’équipement conserve au contraire le pourcentage de santé, pour interdire les soins par échanges répétés.

| Profondeur sans combat | Services |
|---|---|
| 4 | Premier marchand ; préparation |
| 7 | Marchand et refuge, soin gratuit 35 % PV max |
| 9 | Lecture du prochain groupe et préparation libre |
| 11 | Marchand et refuge, soin gratuit 35 % |
| 14 | Préparation et attribution des améliorations éventuellement gardées |
| 16 | Marchand et refuge, soin gratuit 35 % |
| 18 | Dernier marchand et refuge, soin gratuit 50 % |
| 19 | Inspection du boss, préparation finale ; aucune nouvelle récompense |

Le modèle applique les services immédiatement après le combat précédent ; ces haltes n’introduisent ni événement aléatoire ni combat supplémentaire.

Chaque victoire ordinaire donne 35 or, chaque élite 65. Marchand à stock fini : deux sacs aléatoires de six normales à 36 or ; un exemplaire de chaque normale commune/native à 8 or ; deux trocs de trois normales contre une normale commune/native choisie ; un soin de 30 % PV max à 25 or ; une réaffectation d’amélioration de famille à 35 or. L’équipement accessible est proposé une fois par référence et par marchand, sauf une référence déjà possédée ; les reliques deviennent achetables au palier 3, une par référence non possédée. Leur choix ne relance aucun drop.

Seules les cartes se revendent : normale 1, élite 3, rare 10, légendaire 25, dieu 60, immortel 120. Les raretés supérieures à normale ne s’achètent pas ; pas de montée de rareté par fusion. Aucun intérêt, aucun crédit, aucun rafraîchissement payant, pas de revente d’équipement ou de relique. Ainsi ni la monnaie ni le troc ne court-circuitent la rareté des drops extraordinaires.

Le sac est rentable en quantité, l’unité en précision. Le troc détruit deux copies. Acheter six normales et les revendre coûte 36 et rend 6 ; acheter/revendre une unité coûte 8 et rend 1 ; troquer/revendre trois normales rend 1 au lieu de 3. Les soins consomment de la monnaie et ne produisent rien de revendable. L’équipement ne se convertit pas en or. Pas de cycle économique positif dans ce graphe fermé.

## 10. Sauvegarde, lisibilité et fin de run

Sauvegarder : version de règles, graine de run, rencontre, copie complète du héros, inventaire avec UID, deck préparé, main/pioche/défausse/consommées, ordre des ennemis et états, surfaces, tours, marqueurs de déclenchement, marchand et reçus de transactions. Rejouer un identifiant de transaction déjà reçu ne dépense ni ne donne rien. Une action invalide est rejetée avant toute mutation. Le modèle démontre la reprise du combat et l’idempotence marchande ; la persistance Godot doit encore porter ces garanties.

L’interface doit afficher : cartes préparées/réserve, consommation irréversible, prochain marchand, sacs garantis et taux par mob, portée minimale, ordre des ennemis, zones dangereuses, prochain niveau et effet exact d’une amélioration. Pour un sac, montrer les exemplaires obtenus et leur provenance, sans demander de choisir. Une perte doit distinguer mort, pression et épuisement d’options ; jamais accuser seulement « pas de chance ».

Victoire contre le groupe final : écran de résultat, catalogue des découvertes, historique des cartes consommées et restant en réserve. Défaite/abandon : résultat enregistré, économie close. Recommencer recrée les quinze cartes initiales ; aucun stock n’est transféré. Aucun score ne récompense de garder des cartes : conserver une légendaire jusqu’à une défaite ne doit pas être encouragé artificiellement.

## 11. Frontière du modèle

Le résolveur exécute tous les effets du catalogue et les cinq mécanismes de salle. La politique automatique ne recherche que deux actions à l’avance sur les six meilleurs premiers choix ; elle évalue approximativement la menace. Elle ne représente pas un joueur optimal. Les achats automatiques utilisent les sacs, soins, trocs et équipements, mais pas la totalité des choix de marchand ; les achats unitaires, de reliques et la réaffectation sont vérifiés par scénarios transactionnels dédiés.

Le modèle ne valide pas l’ergonomie, les animations, la durée réelle d’un tour humain, le plaisir de perdre un exemplaire, ni la migration d’une sauvegarde existante. La V1 ferme les décisions pour rendre ces vérifications possibles ; elle ne transforme pas un taux de victoire automatique en preuve de satisfaction.
