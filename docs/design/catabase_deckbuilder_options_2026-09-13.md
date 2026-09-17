# Catabase : construire une run avec un deck

Étude du 13 septembre 2026. Proposition de conception, **aucun mode de combat ajouté**. Les chiffres ci-dessous sont des hypothèses de prototype ; seuls les calculs de pioche sont exacts. Ils ne mesurent ni le plaisir ni les chances de gagner une run.

## Direction proposée

Garder les deux gestes de l'arme toujours disponibles, conserver les déplacements avec les PM, et construire un petit deck de manœuvres. L'arme fournit la continuité ; le deck transforme les occasions offertes par le terrain en décisions différentes à chaque tour. Les reliques changent les règles de cette construction ; les consommables restent des secours choisis, accessibles hors pioche.

Exemple : avec le marteau, je peux toujours frapper et ébranler. Ma main me propose aujourd'hui d'ouvrir la garde d'un squelette, de déplacer un archer ou de préparer une collision. Je décide quelle position construire avec mes 6 PA. Au tour suivant, une autre main peut me pousser à défendre et à changer de cible. La pioche doit faire varier mon plan, pas m'interdire d'utiliser mon arme.

Ce choix répond au prototype précédemment rejeté : conserver l'identité des armes, le terrain, les statistiques et les reliques. Il faut néanmoins comparer cette hypothèse au jeu actuel avant de la généraliser.

## Ce que les recherches apportent

| Référence primaire | Fait documenté | Question utile pour Catabase |
|---|---|---|
| [Slay the Spire — Mega Crit](https://www.megacrit.com/press-kits/slay-the-spire/) | Construction du deck pendant la progression, cartes et reliques | Une récompense améliore-t-elle vraiment ma stratégie, ou dilue-t-elle mes bonnes cartes ? |
| [Shogun Showdown — Goblinz](https://goblinzstudio.com/game/shogun-showdown/) | Positionnement, moment de l'attaque, amélioration et combinaison de tuiles | Nos améliorations peuvent-elles modifier les fenêtres d'action et la géométrie plutôt qu'ajouter des dégâts ? |
| [Knights in Tight Spaces — site officiel](https://www.knightsintightspaces.com/) | La main doit être exploitée avec les positions, ennemis et obstacles | Comment une carte crée-t-elle une situation sur notre grille ? |
| [Monster Train — site officiel](https://www.themonstertrain.com/index.html) | Les ennemis progressent entre plusieurs zones à défendre | Quel objectif spatial rend une défense prolongée intéressante sans imposer une course au DPS à tous les builds ? |
| [Inkbound — Shiny Shoe](https://shinyshoe.com/games/inkbound/) | Choix d'améliorations des capacités et de chemins pendant la run | Une construction par récompenses pourrait-elle suffire, même sans main aléatoire ? |

Les propositions qui suivent sont notre interprétation de ces principes, pas des fonctionnalités attribuées à ces jeux. Aucune de leurs ressources supplémentaires, cartes ou structures de plateau n'est reprise telle quelle.

## Trois possibilités réelles

| Option | Gain principal | Risque pour notre jeu | Avis |
|---|---|---|---|
| Toutes les actions passent dans le deck | Chaque ajout, retrait et pioche transforme fortement les tours | Une main sans mobilité ou sans rappel rend l'arme incohérente ; refonte importante des sorts | À comparer ultérieurement, avec un déplacement de secours garanti |
| Deux actions d'arme fixes + deck de manœuvres | Combos variables, continuité du personnage, adaptation tactique | Si les manœuvres sont faibles, on les ignore ; trop fortes, elles effacent l'arme | **Premier prototype recommandé** |
| Tous les sorts restent fixes ; draft des améliorations et reliques | Renforce les choix de run avec peu de complexité supplémentaire | Le même enchaînement peut rester optimal à chaque tour ; ce n'est pas un deck à piocher | Référence de comparaison et solution viable si la pioche déplaît |

## Contrat du premier prototype

- **6 PA, 3 PM**, mêmes coûts pour les actions d'arme. Aucun second système d'énergie au départ.
- Deux gestes d'arme fixes. Les deux techniques libres initiales deviennent des cartes de manœuvre dans ce prototype, sans cumuler une barre complète de sorts et une autre barre complète de cartes.
- **10 cartes, main de 4**. Début de combat : mélange et pioche. Début de chaque activation d'Achille : compléter la main à 4. Fin d'activation : défausser les cartes restantes ; une seule peut être conservée, elle occupe une place dans la prochaine main.
- Jouer une carte consomme ses PA et l'envoie dans la défausse après résolution. Une cible invalide ne paie rien et garde la carte. Les cartes puissantes « épuisées » quittent le cycle jusqu'au prochain combat.
- Quand la pioche est vide, mélanger la défausse. Recommencer chaque combat avec le deck complet ; ne pas reporter une mauvaise main au combat suivant.
- Deux exemplaires maximum d'une même carte. Minimum de huit cartes après retrait. Quatre cartes en main restent le plafond initial, même avec une relique de pioche.
- Pas de génération gratuite récursive de cartes, de PA ou de déclenchements. Un effet copié ne recopie pas son propre déclencheur. La première version n'a aucune carte de récupération de PA.
- Reliques permanentes visibles et passives ; éphémères accessibles dans les objets, avec leur charge et coût existants. Pas de carte morte « relique passive » dans la main.

Avant validation d'une action, l'aperçu doit indiquer les dégâts, les déplacements et les déclenchements attendus. Pioche, défausse et cartes épuisées sont consultables ; l'ordre de la pioche reste caché sauf effet explicite. Les ennemis conservent des intentions lisibles : la main sert à répondre à un problème compréhensible.

## Ce que les nombres changent

Calcul combinatoire, pioche uniforme sans remise, main initiale de quatre, aucune carte conservée ni pioche supplémentaire. « Paire » signifie deux cartes précises, chacune présente une seule fois, dans la même main.

| Taille du deck | Voir une carte unique au tour 1 | Voir au moins un de ses deux exemplaires | Avoir la paire au tour 1 | Avoir vu une carte unique d'ici le tour 2 |
|---|---:|---:|---:|---:|
| 8 | 50,0 % | 78,6 % | 21,4 % | 100,0 % |
| 10 | 40,0 % | 66,7 % | 13,3 % | 80,0 % |
| 12 | 33,3 % | 57,6 % | 9,1 % | 66,7 % |
| 16 | 25,0 % | 45,0 % | 5,0 % | 50,0 % |
| 25 | 16,0 % | 30,0 % | 2,0 % | 32,0 % |

Formules : carte unique = `4/N` ; au moins un de deux exemplaires = `1 − C(N−2,4)/C(N,4)` ; paire = `C(N−2,2)/C(N,4)` ; vue au tour 2 = `min(8,N)/N`. Tableau calculé avec `math.comb` en Python. Conserver une carte réduit les nouvelles cartes vues et rend la dernière colonne inapplicable.

Dans dix cartes, deux exemplaires de **chacune** des deux pièces donnent 40,5 % de chances d'avoir la combinaison au premier tour, contre 13,3 % sans doublons. Cela crée un véritable choix entre redondance et variété. Une mécanique essentielle au fonctionnement de l'arme ne devrait donc pas dépendre de deux cartes uniques à réunir.

Avec un départ à dix cartes et quinze récompenses ajoutant obligatoirement une carte, on termine à vingt-cinq. La probabilité de retrouver sa carte centrale en ouverture passe de 40 % à 16 %. **Passer, remplacer et améliorer doivent être des choix normaux de récompense.** Objectif initial : observer des decks finaux de 10 à 16 cartes, pas imposer cette fourchette artificiellement.

## Douze constructions à explorer avec les six armes

Chaque ligne propose un plan de jeu et sa fragilité. Ce sont des variantes à concevoir, pas douze builds déjà équilibrés ou implémentés.

| Arme | Première direction | Deuxième direction | Ce qui doit les mettre à l'épreuve |
|---|---|---|---|
| Marteau | **Architecte** : amener les adversaires contre les obstacles, valoriser chaque collision | **Exécuteur** : ouvrir une armure, concentrer les PA sur une frappe décisive | Terrain ouvert pour le premier ; cibles nombreuses et espacées pour le second |
| Xiphos / bouclier | **Rempart mobile** : absorber une salve, avancer et libérer le bronze | **Duelliste** : isoler un adversaire, réduire une seule grosse attaque puis riposter | Magie et contrôle ; attaques multiples venant d'angles distincts |
| Disque | **Géomètre** : déplacer les ennemis sur la ligne de retour | **Veilleur** : conserver le disque au sol pour contrôler un passage et choisir quand le rappeler | Obstacles fermant les lignes ; ennemis contournant la zone |
| Hampe | **Fournaise** : préparer une surface dangereuse puis y ramener les ennemis | **Passeur de braises** : déplacer les surfaces, ouvrir des chemins sûrs et combattre en mouvement | Adversaires dispersés ; urgence imposant de quitter une position préparée |
| Lame | **Moissonneur** : répandre les fêlures puis récolter au bon moment | **Survivant** : échanger une partie de sa vie contre une fenêtre de puissance, récupérer les dégâts réels | Blindage ; effets empêchant de rejoindre la cible et budget de soin épuisé |
| Arc | **Percepteur** : payer un pic de puissance pour éliminer une menace avant son activation | **Chasseur économe** : immobiliser les trajectoires et préserver l'or pour améliorer son deck | Adversaires au contact ; adversaires demandant une élimination immédiate |

Une carte peut relier plusieurs familles : attirer un ennemi aide le marteau, le disque et la hampe. Un soin ne suffit pas à distinguer des builds ; la manière de produire ce soin, sa condition et ce qu'il oblige à sacrifier le peuvent.

## Un petit catalogue concret pour éprouver la direction

Valeurs de départ à mesurer. Sauf mention contraire, effets limités à l'activation en cours. Les cartes de placement respectent obstacles, cases occupées, immunités et règles de déplacement forcé du moteur.

| Manœuvre | PA | Effet proposé | Décision créée |
|---|---:|---|---|
| Appel du bronze | 1 | Attirer une cible en ligne de deux cases au maximum, portée 3 | Dépenser un PA pour préparer le terrain ou garder assez pour frapper ? |
| Coin d'airain | 2 | La prochaine collision ennemie causée ce tour retire 20 armure pendant deux tours | Construire la collision avant la frappe ; rien si aucun obstacle n'est atteint |
| Angle mort | 1 | Se déplacer d'une case libre ; la prochaine attaque directe depuis le flanc gagne 20 % | Quitter une protection pour obtenir le bon angle ? Définir le flanc par l'intention ennemie affichée |
| Tenir le passage | 2 | Choisir une case adjacente : le premier ennemi qui y entre perd 2 PM, jusqu'au prochain tour d'Achille | Défendre un espace plutôt que simplement acheter du bouclier |
| Bronze patient | 1 | Conserver jusqu'au prochain tour le reliquat de la garde de salve, sans ajouter de charges | Attendre une meilleure riposte au prix d'un PA présent |
| Rendre le choc | 2 | Dépenser jusqu'à 20 bronze pour pousser une cible d'une case et infliger autant de dégâts physiques bruts | Utiliser maintenant la réserve ou attendre Répercussion ? |
| Fil tendu | 1 | Déplacer le disque posé d'une case libre adjacente, sans traverser de mur | Préparer une meilleure ligne de rappel ; ne remplace jamais le rappel fixe |
| Passage interdit | 2 | Le premier ennemi traversant la ligne Achille–disque perd 2 PM ; dure jusqu'au prochain tour | Rappeler pour les dégâts ou conserver un obstacle tactique ? |
| Cendre portée | 1 | Déplacer sa braise d'une case valide, sans rafraîchir sa durée | Sauver son placement plutôt que reposer une surface |
| Étouffer la braise | 1 | Consommer une de ses surfaces adjacentes pour gagner 12 garde jusqu'au prochain tour | Sacrifier la pression future pour survivre maintenant |
| Rouvrir | 1 | Prolonger d'un tour une fêlure existante, une seule fois par cible et par tour | Préserver une cible pour plus tard au lieu de récolter tout de suite |
| Part du vivant | 1 | Payer 8 PV sans pouvoir se tuer ; prochaine attaque directe +25 %, carte épuisée | Pari explicite, sans augmenter le plafond de soin de la Coupe |
| Obole d'avance | 0 | Payer 8 oboles pour conserver deux cartes à cette fin de tour, carte épuisée | Acheter de la prévisibilité en sacrifiant l'économie de la run |
| Tir de sommation | 2 | Infliger 50 % des dégâts du trait et retirer 2 PM, sans cumul du retrait par cette carte | Renoncer aux dégâts pour rester hors du contact |
| Lire les présages | 1 | Regarder les deux prochaines cartes et choisir leur ordre, carte épuisée | Dépenser maintenant pour préparer son prochain tour |
| Reprendre souffle | 1 | Défausser une autre carte de sa main pour gagner 2 PM, une fois par tour | Sacrifier une possibilité future pour gagner une position immédiate |

Exemple de tour Marteau : Appel du bronze (1 PA) + Angle mort (1 PA) + Masse (4 PA) = 6 PA. Avec Coin d'airain (2) + Ébranler (2), il ne reste que 2 PA : la Masse n'entre plus dans ce tour. Le joueur doit accepter un tour de préparation, choisir une autre attaque ou renoncer à la fracture. Ce genre de contrainte est plus intéressant qu'un bonus gratuit systématique.

Les cartes défensives doivent compter dans le même budget que les attaques. Si chaque tour permet la meilleure frappe, une protection complète et le meilleur déplacement, nous aurons seulement ajouté des clics.

## Faire des reliques des choix qui transforment la run

Les reliques actuelles restent le premier support : Clou, Urne, Fil, Mèche, Coupe, Obole. Tester ensuite quelques changements de règle, **mutuellement exclusifs dans un même emplacement expérimental**, plutôt qu'empiler tous leurs avantages.

| Relique proposée | Avantage | Prix ou limite |
|---|---|---|
| Mémoire de bronze | Une manœuvre choisie avant le combat est garantie dans les quatre cartes initiales | Main maximale de 3 à partir du deuxième tour ; la carte réservée n'est pas une cinquième carte |
| Urne scellée | Une fois par tour, la première absorption ennemie d'au moins 6 par la garde permet de remplacer une carte de la main | Retire 6 à la réserve de bronze disponible ; pas de déclenchement par auto-dégât |
| Fil des retours | Après un rappel ayant traversé deux ennemis, replacer une manœuvre de la défausse au sommet de la pioche | Une fois par tour ; préparer un tour suivant, sans jouer immédiatement la carte récupérée |
| Pacte des cendres | Une manœuvre choisie inflige +50 % de dégâts directs | Elle s'épuise après usage pendant le combat ; aucun effet sur le soin ou la pioche |

Une amélioration majeure doit faire apparaître de nouvelles priorités : « mon gros tour est garanti à l'ouverture », « je dois provoquer une salve », « je prépare mon prochain rappel ». Sur les coups décisifs, montrer au joueur quel effet a changé le résultat.

## Lier le deck aux chemins et au récit

Les familles ci-dessous prolongent l'intention artistique exprimée ; elles ne supposent pas que toutes ces rencontres existent déjà.

| Chemin | Questions posées par les rencontres | Récompenses cohérentes | Événement narratif possible |
|---|---|---|---|
| Porte / brume / ossements | Traverser un écran physique, atteindre l'archer, distinguer salves et gros impacts | Fracture, interception, déplacement latéral | Une tombe offre de remplacer une technique oubliée par une manœuvre défensive |
| Puits / profondeurs | Sortir d'une surface, interrompre une préparation magique, supporter une baisse de PA | Purification, mobilité, actions moins coûteuses | Une forge consume une carte pour transformer définitivement une autre |
| Barque / eau | Tenir un passage étroit, résister à un déplacement, aligner les cibles sans se coincer | Ancrage, déplacement forcé, manipulation de la prochaine pioche | Un passeur garantit une carte d'ouverture contre des oboles ou une contrepartie annoncée |

Le chemin annonce **un problème**, pas une unique couleur de dégâts obligatoire. Le puits doit pouvoir se résoudre par résistance magique, mobilité, interruption ou élimination ciblée. Un mauvais départ peut coûter cher dès la première salle ; il doit rester possible d'identifier pourquoi et de corriger sa construction.

Offres initiales : trois cartes visibles, dont une liée à l'arme, une au chemin et une transversale. Éviter les doublons inutilisables et proposer de passer. Le premier choix d'un chemin ne déclenche pas une fenêtre de construction supplémentaire : les choix restent à la préparation, au niveau gagné, au butin ou à une halte.

Le segment du Léthé à cinq salles pose un problème de budget indépendant du deck. Ne pas donner automatiquement cinq cartes contre trois sur un autre chemin. Définir un budget de puissance comparable **entre deux carrefours** : mêmes occasions d'améliorer le cœur du build ; le chemin plus long peut offrir davantage de choix, d'information ou d'oboles, mais davantage d'usure. Tester ensuite la valeur effective de ce surplus, car plus de choix augmente aussi la puissance. Conserver des objectifs de combat comparables pour les trois itinéraires, sans imposer la même composition.

## Progression, défis et rythme de la run

Au départ, choisir l'arme et une orientation fournit un deck de dix cartes consultable et modifiable. Ne pas ajouter dix choix obligatoires aux fenêtres déjà présentes. Une composition de départ candidate : quatre cartes de la famille d'arme, deux de placement, deux défensives et deux polyvalentes, avec doublons autorisés dans la limite de deux.

Au niveau gagné : annonce → caractéristiques → fenêtre de progression des techniques → équipement / butin → retour au lieu. Dans cette variante, la fenêtre des techniques propose **une** décision : ajouter, améliorer ou remplacer. La carte refusée ne doit pas être automatiquement ajoutée au deck. Une récompense d'équipement reste distincte, avec son asset et ses effets.

Les arbres actuels gardent les transformations de l'arme et les spécialisations permanentes. Les manœuvres deviennent le contenu acquis dans la run. Éviter qu'une même amélioration soit payée dans l'arbre, dans la carte puis dans une relique. Ne pas convertir automatiquement le budget actuel de 24 points : mesurer d'abord la valeur d'une amélioration de carte face à une mutation permanente.

Conserver les défis qui influencent la rencontre suivante, avec conséquence affichée avant acceptation. Exemples à tester : réussir deux déplacements forcés → une récompense de placement ; échouer → le premier ennemi de la prochaine salle gagne 12 garde pour un tour. La sanction ne se cumule pas indéfiniment et cesse après cette rencontre. Ne pas lier systématiquement toute la difficulté au nombre de tours : cela invaliderait les constructions de défense et de préparation que l'on veut justement rendre intéressantes.

## Comment décider si cela fonctionne

Premier lot expérimental : les six armes existantes, un petit catalogue d'environ 16 manœuvres, aucune nouvelle créature, deux compositions existantes retouchées par chemin. Tester les règles de main avec les reliques actuelles avant d'ajouter les quatre reliques proposées.

Comparer les mêmes salles, préparations et graines dans le jeu actuel et la variante. Alterner l'ordre des deux versions lors des essais humains. Premier passage : six armes × trois chemins × deux graines = 36 segments courts par version. Les pilotes automatiques peuvent détecter un blocage et compter les états ; ils ne prouvent pas qu'une décision est amusante.

Observer : variété des premiers tours, PA dépensés en préparation/défense, cartes jamais utilisées, causes de dégâts, abandons d'une combinaison, fréquence des récompenses refusées et possibilité d'un pivot avant le carrefour. Un tour sans carte utile reste acceptable si l'arme permet une décision tactique ; une série de tours où la meilleure action est d'attendre indique un échec.

Critères de rejet : spam de la même action d'arme malgré les cartes ; tours résolus sans regarder la grille ; mort dépendant d'une carte indispensable introuvable ; victoire obtenue par une boucle de pioche ; construction défensive punie uniquement parce qu'elle prend plus de temps. La cible est une différence observable entre les builds et entre deux mains, sans perdre la lecture du combat.

## Points d'intégration à préserver si le prototype est retenu

Réutiliser `SpellCaster`, les effets de statistiques, les surfaces, les déplacements et l'inventaire. Les cartes référencent des actions ; elles ne créent pas un second calculateur de dégâts. L'arme conserve les deux premiers emplacements du loadout. Les états de pioche, main, défausse et épuisement appartiennent à un état de combat dédié ; les identifiants et améliorations de cartes appartiennent à la session de run.

Versionner le nouveau format sans réactiver l'ancien champ `deck` retiré : `ExpeditionSession` sait déjà migrer ce champ vers les défis conservés. Séparer les graines de route, d'offres et de pioche pour qu'un clic d'aperçu ne change pas les récompenses. La reprise actuelle redémarre au point d'entrée sauvegardé d'un combat ; conserver cette règle et la même pioche initiale, plutôt que promettre une reprise au milieu du tour.

Prévoir dans Caractéristiques un récapitulatif de la construction : arme, caractéristiques effectives, reliques, deck et améliorations. En combat, afficher les compteurs de chaque pile et les effets actifs. Les choix de deck ne doivent jamais bloquer la route sans bouton de reprise visible.
