# Catabase — Construire son Achille, choisir sa descente

**Dossier de conception — 12 septembre 2026. Propositions, sans modification du jeu.**

Le projet peut soutenir beaucoup plus de constructions si les équipements, les techniques et les reliques modifient les décisions qu’Achille prend dans une salle. Une lance qui récompense la distance, une cuirasse qui permet d’encaisser une salve et une relique qui transforme une collision en point d’origine de sort ne produisent pas seulement des dégâts différents : elles donnent une valeur différente aux mêmes ennemis, aux mêmes cases et aux mêmes embranchements.

La direction proposée est une **préparation volontaire, suivie d’une spécialisation opportuniste**. Le départ fournit un moteur de combat déjà fonctionnel et une faiblesse assumée. La run apporte des moyens d’approfondir ce moteur, de couvrir cette faiblesse ou de changer de plan. Certains assemblages doivent effectivement devenir démesurés dans leur domaine. Leurs contraintes de placement, de ressources et de cibles doivent cependant continuer à compter.

Le dossier comprend :

- cette analyse : systèmes, routes, chiffres, recherches, conclusions et protocole d’essai ;
- [le catalogue de conception](CATALOGUE.md) : huit armes et leurs aspects, vingt-quatre constructions, vingt-quatre techniques, soixante-douze mutations, six arbres approfondis, reliques et combinaisons ;
- [le modèle reproductible](model.py), [ses résultats](results.json), [la matrice de combats](combat_sensitivity.csv), [sa synthèse](combat_summary.csv), [l’expérience sur la garde](guard_experiment.csv) et [les budgets de parcours](run_budget.csv).

**Statut des chiffres.** Les valeurs du code et le dénombrement de son graphe sont des observations. Les armes, sorts, statistiques d’ennemis et systèmes décrits ensuite sont des propositions. Les combats calculés sont un modèle abstrait de rotations, pas des parties exécutées dans Godot et pas une mesure du plaisir ou du taux de victoire des joueurs.

## 1. Le diagnostic : le départ choisit trop peu, la défense peut choisir à sa place

Le code actuel donne à Achille 110 PV, 6 PA, 3 PM, 18 de puissance d’attaque et quatre emplacements actifs. `ExpeditionBuildState.initialize()` équipe toujours les mêmes quatre sorts. Le cinquième emplacement arrive au niveau 5 ; le choix de capacité supplémentaire se situe à la profondeur 12. La progression accorde 24 points sur les dix-neuf premières profondeurs. Il existe déjà des doctrines, des branches découvertes en route, des équipements conditionnels et des règles de dégâts suffisamment riches pour accueillir une conception plus ambitieuse.

Le défaut du départ est donc précis : **la première décision géographique ne sélectionne pas encore un problème auquel on a construit sa propre réponse**. Ajouter quinze sorts acquis après plusieurs combats ne résout pas entièrement cela. Il faut pouvoir entrer dans la descente avec une stratégie différente dès la première salle.

La seconde difficulté est économique. Quand les PV persistent entre les combats, éviter dix points de dégâts a une valeur future. Si une défense répétable annule toute attaque, même une victoire en douze tours devient meilleure qu’une victoire en quatre tours avec une blessure. Renforcer les ennemis sans traiter cette relation favorise encore les rares constructions qui arrivent à annuler leur tour.

La réponse proposée conserve plusieurs manières de défendre : tuer le tireur, interrompre le mage, interposer un obstacle, garder une direction, absorber une salve, déplacer la source du danger. Une protection ne doit pas nécessairement tout faire ; l’équipement de départ permet de choisir les menaces que l’on accepte de subir.

Sources internes examinées : [Achille](../../../data/units/allies/achilles.tres), [construction](../../../core/expedition/expedition_build_state.gd), [catalogue de doctrines](../../../core/expedition/expedition_build_catalog.gd), [équipements](../../../core/expedition/expedition_equipment_catalog.gd), [résolution des dégâts](../../../core/damage_resolver.gd), [rencontres initiales](../../../core/expedition/catabase_early_encounters.gd).

## 2. Ce que les recherches apportent

Ces références éclairent des problèmes de conception. Les mécaniques proposées dans ce dossier sont des hypothèses pour Catabase ; elles ne sont pas des résultats démontrés par les jeux cités.

| Référence primaire | Observation documentée | Conséquence proposée pour Catabase |
|---|---|---|
| [Into the Breach — présentation officielle](https://subsetgames.com/itb.html) | Les attaques ennemies annoncées permettent d’examiner les réponses possibles. | Une punition sévère devient intelligible si la menace, son déclencheur et son moyen de défense sont lisibles. Une intention peut annoncer une règle de ciblage, pas nécessairement une case définitivement figée. |
| [Last Epoch — compétences](https://lastepoch.com/skills/) | Les spécialisations peuvent transformer le fonctionnement d’une compétence. | Une mutation doit changer une décision : conserver sa lance sur le terrain, transformer un soin en réserve, déplacer une zone. Les nœuds de statistiques accompagnent cette transformation. |
| [Grim Dawn — règles de combat](https://www.grimdawn.com/guide/gameplay/combat/) | La conversion suit un ordre explicite ; un même dégât n’est pas converti indéfiniment. | Les assemblages puissants ont besoin d’une causalité précise : événement initial, conversion, effet secondaire, ressource consommée. Cela autorise des effets extravagants sans boucle gratuite. |
| [Cogmind — Designing for Mastery](https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/) | Les équipements peuvent permettre de reconstruire radicalement son personnage en cours de partie ; les consommables offrent des issues coûteuses. | Prévoir des pivots réels, financés par des ressources ou une occasion sacrifiée. La tolérance à l’erreur défendue par cet auteur est plus généreuse que la difficulté de départ souhaitée ici : ce point n’est pas repris tel quel. |
| [Cogmind — Area Denial](https://www.gridsagegames.com/blog/2021/09/spicing-up-primary-maps-2-area-denial/) | La portée d’une menace et l’arrivée de renforts sont annoncées ; les spécialistes conservent une identité visuelle reconnaissable. | Une composition doit se lire par ses rôles et ses silhouettes. La difficulté peut venir de deux pressions simultanées, sans cacher les règles derrière des variantes presque identiques. |
| [Battle Brothers — Injury Mechanics](https://battlebrothersgame.com/dev-blog-79-progress-update-injury-mechanics/) | Ce journal de développement décrit des blessures dont les conséquences dépassent le combat. | Une victoire peut coûter de la capacité future. Pour un héros seul, privilégier des dettes récupérables et annoncées plutôt que des réductions permanentes qui condamnent silencieusement la run. |

Ces sources sont des présentations et des textes de développeurs, pas des essais comparatifs prouvant qu’un mécanisme conviendrait à Catabase. Leur apport commun est néanmoins utile : la profondeur vient de relations entre systèmes, de menaces compréhensibles et de conséquences persistantes. Elle ne dépend pas du seul nombre d’objets.

## 3. Le départ : choisir un outil, une manière de survivre et un pari

Proposition pour le Seuil des Ombres : afficher d’abord les trois départs, leurs menaces fréquentes et la nature de leur première halte. L’équipement se compose ensuite, avant le premier combat. Le seuil commun peut conserver son combat, à condition que le personnage soit déjà construit ; le choix de route reste confirmé avant la première salle thématique.

Le joueur sélectionne une arme parmi huit, une protection parmi quatre, deux techniques parmi douze, une relique de départ parmi huit et un nécessaire de voyage parmi quatre. L’arme apporte deux actions : on conserve ainsi quatre actions équipées au départ, mais leur combinaison est choisie. Les descriptions indiquent les conditions et les limites ; aucune recherche dans un wiki ne doit être nécessaire pour savoir qu’une cuirasse physique ne protège pas d’une brûlure magique.

**Exemple de décision initiale.** Le puits annonce des canaliseurs, une réduction temporaire de puissance et une halte de récupération. On peut prendre une protection magique et affronter les incantations, une arme rapide et une interruption pour supprimer leur source, ou une portée élevée pour exploiter les angles morts. Un set lourd, lent, purement physique et dépourvu de portée, de résistance magique ou d’interruption doit y perdre beaucoup de PV. Ce n’est pas un mauvais personnage en général : c’est une préparation qui ne sait pas traiter les menaces annoncées.

Les quatre protections proposées sont : Airain, 55 armure et 0 défense magique ; Sceau, l’inverse ; Mixte, 22 dans les deux catégories ; Légère, 10 dans les deux et un avantage de mobilité à tester. Les deux protections spécialisées ne retirent pas de PM dans le premier prototype : on pourra ajouter un poids après avoir vérifié que leur spécialisation produit déjà un choix. La mobilité de la tenue légère n’est pas simulée dans les résultats joints.

Les nécessaires de voyage ont chacun deux charges : **sels**, neutraliser la faiblesse de puissance durant un combat ; **amarres**, ignorer le coût d’action des déplacements de courant durant un combat ; **onguent**, rendre 18 PV hors combat ; **lampe**, révéler la composition de deux salles ciblées. Les deux premiers sont représentés par un drapeau actif pour le combat isolé du modèle. Leur rareté et leur épuisement sur la run n’y sont pas simulés.

Le produit des choix donne `8 × 4 × C(12,2) × 8 × 4 = 67 584` départs formellement possibles. **Ce nombre ne représente pas 67 584 builds intéressants.** La cible de conception est d’abord vingt-quatre moteurs distincts, dont plusieurs fonctionnent sur chaque chemin et dont les variantes changent les décisions en combat. Les affinités et les ressources propres à une arme doivent fonctionner dès le départ sans dépendre d’un objet rare.

Pour un premier joueur, trois exemples de préparations sont affichables et modifiables. Ils expliquent une intention et une faiblesse. Tout le catalogue de départ reste accessible ; la méta-progression peut ouvrir des variantes et des informations, sans réserver la résistance indispensable à plusieurs échecs préalables.

## 4. Les techniques : des décisions locales, un budget global

Les trois doctrines actuelles peuvent rester des repères narratifs. Elles ne devraient pas enfermer toute la construction dans trois couloirs. Le catalogue propose vingt-quatre techniques réparties entre attaque, positionnement, protection, altérations, éléments et manipulation de ressources. Douze sont accessibles au départ ; les douze autres se découvrent ensuite.

Chaque technique conserve une racine puis offre trois mutations exclusives. Une mutation ouvre deux aboutissements exclusifs. Cela permet de reconnaître le sort tout en changeant sa fonction. Une lance plantée peut devenir un ancrage de déplacement, un obstacle ou un relais de projectile ; le joueur n’acquiert pas ces trois fonctions simultanément.

Le catalogue détaille les trois mutations des vingt-quatre techniques et les six aboutissements de six techniques prioritaires. Cela représente **132 entrées conçues à différents niveaux de détail**, et non 132 sorts actifs simultanés. Les aboutissements des dix-huit autres techniques restent à concevoir après les essais. La cible exhaustive serait 240 entrées ; la produire avant de vérifier les premiers arbres créerait surtout du contenu difficile à corriger.

Budget proposé, en conservant les 24 points de la run actuelle :

| Achat | Coût | Engagement |
|---|---:|---|
| Les deux techniques initiales | 0 | Le moteur fonctionne avant le premier butin. |
| Une autre racine | 1 | Ouvre une possibilité, occupe un emplacement si équipée. |
| Mutation d’une technique | 2 | Remplace le comportement de la racine. |
| Aboutissement | 4 supplémentaires | Nécessite sa mutation ; une chaîne complète coûte donc 6. |
| Aspect d’arme | 4 | Transforme les deux actions de l’arme selon l’aspect. |
| Éveil d’une relique équipée | 4 | Renforce sa règle spécifique, sans ajouter un emplacement. |
| Liaison entre deux techniques | 3 | Interaction ciblée et explicitement décrite. |

Trois budgets légaux illustrent des choix différents. **Spécialiste :** deux chaînes complètes, un aspect, un éveil et une liaison coûtent `12 + 4 + 4 + 3 = 23` ; le dernier point ouvre un outil de secours. **Hybride :** deux chaînes complètes, deux nouvelles racines mutées et un aspect coûtent `12 + 2 + 4 + 4 = 22` ; deux points restent disponibles. **Collectionneur tactique :** six nouvelles racines, quatre mutations, un aspect et un éveil coûtent `6 + 8 + 4 + 4 = 22` ; il connaît beaucoup de réponses, mais n’en équipe que quatre en plus des actions d’arme et n’a aucun aboutissement.

Cette distinction entre connaître et équiper compte. Les emplacements supplémentaires arrivent progressivement. Entre les combats, on peut changer une technique connue. Revenir sur une mutation ou déplacer des points demande une halte de forge ou de mémoire : proposition de coût, 25 oboles et remplacement d’une autre prestation. Le prix doit empêcher une reconstruction gratuite avant chaque rencontre tout en autorisant un pivot réel.

L’expérience d’un sort ne dépendrait pas du nombre de lancements dans un combat. Les points de profondeur actuels évitent déjà cette incitation à prolonger les rencontres. Les armes et les reliques n’ajoutent pas une seconde progression à farmer en frappant un ennemi neutralisé.

## 5. Donner un problème distinct aux trois chemins

### Le puits : décider quelle incantation peut passer

Le puits met en scène des corps qui supportent mal leur propre puissance : fondeurs, conducteurs, rejetons. Les attaques magiques ne doivent pas simplement remplacer une flèche physique par une boule rouge. Un conducteur prépare une faiblesse ; un fondeur menace une cible suivie ; un rejeton impose une proximité dangereuse. Le joueur doit choisir entre interrompre, supporter un effet, rompre une ligne de vue et accélérer une élimination.

La résistance magique protège les PV, la purification protège un cycle de dégâts, la mobilité protège l’accès à une cible. Ces trois réponses ne sont pas interchangeables. Un build de collisions peut projeter un conducteur hors d’une zone conductrice ; un build de sacrifice peut encaisser une faiblesse qu’il compense par des dégâts fixes ; un tireur peut préparer son burst pendant une canalisation. La chaleur devient une ressource pour certaines constructions, mais cette conversion provient d’un équipement choisi, pas d’une règle obligatoire pour tous.

### La porte : ouvrir une formation avant qu’elle ne fasse son travail

Les squelettes proposent des problèmes physiques lisibles : un écran résistant, des tireurs derrière, une relève qui ferme un angle. La brume coupe certaines lignes de vue et les tombes organisent les approches. Éviter l’esquive aléatoire gratuite liée à la brume : son utilité doit se lire sur la grille.

Un briseur ouvre l’écran ; un voltigeur le contourne ; un élémentaliste atteint plusieurs ennemis groupés ; un rempart accepte une salve afin d’établir sa position. Les ossements ne doivent pas être universellement immunisés à toutes les altérations : cela supprimerait arbitrairement trop de départs. L’altération de saignement peut devenir une « fêlure » sur ces corps, avec la même règle mécanique et une représentation adaptée, annoncée dans le lexique.

### La barque : choisir où l’on pourra agir au prochain tour

Le combat utilise la barque, les pontons et les rives comme géographie indispensable. Une carte ne se contente pas d’avoir de l’eau autour de son sol. Le courant déplace la barque d’un cran annoncé, ou change le point d’accostage ; les molosses menacent les passages et l’officiant impose une traction. Il faut arbitrer entre sécuriser l’embarcation, éliminer le tracteur et engager un ennemi qui sera bientôt hors d’accès.

Une arme à retour peut frapper depuis la rive puis revenir par la barque. Une défense ancrée transforme celle-ci en poste de tir. Un manipulateur de terrain dirige le courant vers un obstacle. Un assassin traverse au bon moment. Le mauvais départ est une construction dont toutes les actions exigent une cible immobile à une case et qui n’a prévu aucun moyen d’y parvenir.

Le nom Léthé peut évoquer la mémoire, tandis que la traversée évoque Charon et le Styx ; il faut décider dans la narration s’il s’agit d’un affluent, d’une autre rive ou d’une traversée composite. Le jeu ne doit pas changer de fleuve sans explication. Une proposition est que Charon transporte Achille jusqu’aux eaux de l’oubli : le même bateau assure alors le fil visuel entre deux lieux explicitement nommés.

## 6. La carte actuelle : beaucoup de parcours, des occasions inégales

L’énumération reproduit les connexions de `expedition_route_itineraries.gd`, avec la préservation des chemins utilisée par la révision 5. Elle explore les deux natures possibles de la bibliothèque, les deux natures possibles du défi et les deux orientations du graphe. Elle ne reproduit pas le générateur aléatoire de Godot ; elle énumère les configurations possibles de ces paramètres.

| Accès | Parcours complets | Puits | Porte | Barque |
|---|---:|---:|---:|---:|
| Sans passages secrets | 280 | 160 | 80 | 40 |
| Deux passages secrets accessibles, orientation normale | 385 | 220 | 110 | 55 |
| Deux passages secrets accessibles, orientation miroir | 455 | 260 | 130 | 65 |

Ce sont des chemins topologiques, pas des probabilités de sélection et pas des runs qualitativement distinctes. L’asymétrie des secrets vient de leur sortie vers la dernière voie affichée : un miroir peut donc changer leur destination logique. C’est une observation à vérifier dans une future tâche sur la carte, pas une correction incluse ici. Les totaux avec secrets supposent que les deux sont disponibles ; une run donnée ne les révèle pas nécessairement.

Dans le début actuel, puits et porte se rejoignent à la profondeur V ; la barque reste séparée jusqu’à l’épreuve commune VII. Les étapes IV sont déjà une différenciation pertinente : camp pour le puits, marchand pour la porte, mémoire pour la barque. Entre II et VI, chaque entrée rencontre quatre combats et une halte ; la porte et la barque incluent toutefois un élite dans leur segment propre. Le choix n’est donc pas à équilibrer seulement par une longueur dessinée.

Les parcours contiennent entre 14 et 16 combats selon les destinations incertaines ; les élites varient de 2 à 7, et les camps de soin de 0 à 4. Ces écarts sont assez grands pour produire des économies différentes. Il faut les communiquer et rémunérer les risques. Un joueur qui choisit zéro camp ne doit pas découvrir seulement à la fin que ses consommables ne peuvent mathématiquement pas suffire.

Proposition : garder les confluences V et VII, mais donner **deux décisions locales effectives à chaque origine** avant VII. Le puits peut choisir un foyer instable ou des canalisations ; la porte, percer une phalange ou traverser une nécropole de tireurs ; la barque, accoster pour casser une chaîne ou rester à bord sous la traction. Ces choix peuvent modifier la rencontre et la prestation de la halte sans rajouter deux traits parallèles sur la carte.

La confluence doit conserver une conséquence du trajet. Le puits peut produire une relique refroidie ou surchargée ; la porte, un sauf-conduit acheté ou un tribut refusé ; la barque, un nom retenu ou sacrifié. Chacune de ces décisions influence une offre et une rencontre ultérieures annoncées. La narration porte ainsi un engagement mécanique, et le marchand suivant se souvient de ce qu’Achille a fait.

## 7. Résultats du laboratoire de combat

Le programme calcule **2 592 cas** : huit rotations, quatre protections, trois états de préparation, trois rencontres et neuf couples de variations de PV/dégâts ennemis. Chaque grandeur ennemie varie indépendamment à 80 %, 100 % ou 120 %. Il ajoute 648 évaluations pour comparer deux règles de garde, dont une partie reprend les situations de référence. Il ne s’agit pas de 3 240 parties indépendantes ni d’un échantillonnage statistique de joueurs.

Les huit rotations sont des sondes simplifiées, inspirées des constructions du catalogue : elles ne compilent pas ses arbres complets. Chaque séquence coûte au plus 6 PA. Le modèle résout les dégâts, l’armure, une faiblesse, des dégâts persistants, un contrôle périodique, un soin borné et la mort des cibles. Les priorités de cible sont imposées. Une taxe de PA représente grossièrement certains problèmes d’accès. La carte, les déplacements exacts, les lignes de vue, les erreurs humaines, les critiques et les équipements de milieu de run sont absents.

### Les ennemis utilisés

| Salle proposée | Composition et valeurs de base | Question représentée |
|---|---|---|
| Puits | Conducteur : 46 PV, 30 défense magique, 12 dégâts magiques par tour, faiblesse de puissance ; fondeur : 64 PV, 15 armure, 20 défense magique, 24 dégâts tous les deux tours. | Supprimer le soutien ou encaisser les cycles magiques. |
| Porte | Deux archers : 38 PV, 9 dégâts physiques chacun par tour ; brute : 90 PV, 70 armure, 18 dégâts tous les deux tours. | Accéder aux tireurs puis traiter le corps blindé. |
| Barque | Officiant : 55 PV, 10 armure, 25 défense magique, 16 dégâts magiques tous les deux tours ; deux molosses : 50 PV, 15 armure, 9 dégâts physiques chacun. | Gérer des dégâts mixtes et le coût périodique du courant. |

Le modèle n’attribue pas à ces valeurs une équivalence de difficulté. Le puits a moins de PV cumulés ; la porte possède un obstacle blindé et la barque davantage de perturbations. C’est précisément ce que les essais doivent remettre en cause.

### Ce que montrent les comparaisons

PV perdus à valeurs ennemies centrales, de la meilleure à la moins bonne préparation testée pour la même rotation :

| Rotation | Puits | Porte | Barque |
|---|---:|---:|---:|
| Duelliste | 15,5 → 24 | 40,6 → 63 | 34,8 → 72 |
| Briseur | 23,2 → 36 | 40,6 → 63 | 34,8 → 72 |
| Voltigeur | 38,7 → 60 | 41,5 → 64,4 | 53,7 → 81,4 |
| Cendre | 23,2 → 36 | 40,6 → 63 | 40,6 → 91,3 |
| Entrave | 24,2 → 66 | 24,5 → 82 | 38,5 → 74,5 |
| Sanguin | 15,2 → 28 | 24,5 → 46,9 | 26,8 → 56,2 |
| Foudroyant | 23,2 → 36 | 34,8 → 54 | 50,8 → 64,3 |
| Rempart, garde répétable | 0 → 4 | 1,2 → 19 | 5,6 → 17,8 |

Les extrêmes comparent toutes les protections et les préparations disponibles dans ce laboratoire. Ce ne sont pas des intervalles de confiance. Ils omettent le prix et la quantité limitée des nécessaires de voyage.

**Premier enseignement : les défenses suffisent déjà à créer une punition sensible.** Pour le duelliste sur la barque, une préparation adaptée conserve environ 37 PV de plus que la pire configuration du modèle. Inutile d’ajouter immédiatement cinq nouvelles jauges pour donner du poids à la préparation.

**Deuxième enseignement : la garde répétable domine l’attrition.** Avec la protection mixte et sans nécessaire, le rempart perd 0 PV en cinq tours au puits, 7,6 en onze tours à la porte et 11,7 en quatorze tours sur la barque. Le combat lent devient presque toujours préférable à une prise de risque. Cette version est à écarter.

**Troisième enseignement : une correction mécanique peut aller trop loin.** En alternant garde et frappe de remplacement, le même rempart perd 39,3, 51,6 et 57,4 PV. Les combats de la porte et de la barque raccourcissent à huit et neuf tours, mais sa fonction défensive devient insuffisante. Cette variante n’est donc pas retenue comme solution équilibrée. La prochaine expérience doit tester une garde directionnelle ou une réduction liée au nombre d’impacts, sur la vraie grille.

**Quatrième enseignement : le catalogue ne doit pas valider ses propres promesses.** Le briseur n’améliore pas ici la perte de PV à la porte par rapport au duelliste ; les seuils d’élimination et la priorité imposée masquent l’intérêt de la pénétration. Le voltigeur paie son retrait sans bénéficier d’un vrai placement et sort trop faible. L’entrave atteint dix-huit tours dans un cas central. Ces résultats interdisent d’annoncer ces builds comme équilibrés : il faut tester les géométries qui donnent un sens à leurs outils, puis corriger leurs coûts si cet intérêt ne se matérialise pas.

Enfin, le soin du sanguin paraît très avantageux. Son remboursement reste borné à cinq PV par tour dans le modèle, mais une limite par tour n’empêche pas de soigner indéfiniment contre une cible inoffensive. Le catalogue retient donc une réserve de soin par combat, alimentée uniquement par des PV réellement retirés à des ennemis admissibles.

## 8. Statistiques et économie de la run

La formule actuelle de défense positive est une bonne base : `dégâts × 100 / (100 + défense)`, après les résistances élémentaires. Une défense de 55 réduit donc d’environ 35,5 % les dégâts concernés ; ce n’est pas 55 % de réduction. La Force actuelle sert aux déplacements et collisions : conserver cette signification, et employer Puissance pour la grandeur qui augmente les dégâts.

Proposition de corridor de progression, avant les extrêmes créés par les reliques :

| Moment | PV maximum | Puissance | Défense spécialisée | PA / PM |
|---|---:|---:|---:|---|
| Départ | 110 | 18 | 55 | 6 / 3 |
| Confluence VII | 125–140 | 21–24 | 60–80 | 6 / 3, mobilité choisie |
| Épreuve XV | 150–170 | 27–30 | 80–100 | 6 / 3 ou 4 selon investissement |
| Pâris | 170–190 | 30–34 | 90–120 | 6 PA de base ; exceptions coûteuses |

Ces fourchettes sont des cibles proposées, pas un relevé de la progression actuelle. Les gros écarts de puissance doivent venir des conditions accomplies. Un spécialiste à 32 de puissance qui aligne trois cibles peut dépasser largement un généraliste à 34 ; il n’a pas besoin de 150 de puissance pour sentir sa construction aboutie.

L’économie des PV impose une contrainte plus sévère que le combat isolé. Avec 110 PV constants, quatre camps rendant chacun 30 % et deux onguents de 18 PV, le budget total théorique est `110 + 4 × 33 + 36 = 278 PV`. C’est un plafond : les soins excédentaires sont perdus. Réserver 50 PV au boss laisse 228 PV pour quatorze combats, soit **16,3 PV de perte moyenne maximale**. Sans camp, le même calcul tombe à `96 / 14 = 6,9 PV`. La hausse des PV maximum et d’autres sources de soin changeraient ces chiffres ; elles sont volontairement exclues de ce calcul de contrôle.

En conséquence, des premières salles faisant perdre régulièrement 40 PV à une bonne préparation sont incompatibles avec cette économie, sauf à fournir beaucoup plus de récupération ou à obtenir une réduction rapide de l’attrition par la progression. **Il ne faut pas appliquer directement les statistiques du laboratoire à toutes les salles du jeu.**

Cible de premier réglage : une salle normale bien jouée coûte souvent 8–16 PV, un mauvais accord entre préparation et menace 25–45 PV, un élite 20–35 PV avec des possibilités de neutralisation. Ce sont des cibles d’essai, pas des pertes obligatoires : une bonne résolution peut coûter zéro, et une erreur majeure peut tuer. Une salle où toutes les constructions perdent le même nombre de PV fonctionne comme un péage, pas comme un combat tactique.

Les rencontres supplémentaires doivent avoir une rémunération propre. Pour un combat facultatif, la valeur du butin et de l’information doit être comparable au coût probable en PV, en charge de relique et en oboles de soin. Les points de maîtrise peuvent rester attachés aux profondeurs : cela évite que le chemin à seize combats domine automatiquement celui à quatorze. Le supplément de risque rémunère surtout un choix d’équipement, une amélioration ciblée ou une monnaie utilisable.

### Audit de budget sur les parcours complets

Un second calcul parcourt les 280 itinéraires ordinaires d’une configuration où la bibliothèque est une halte et le défi XVI un combat. Il fixe les PV maximum à 110, les camps à +33 PV, le boss à une perte de 45 PV et les élites à `arrondi supérieur(1,75 × perte normale + 5)`. Une programmation dynamique cherche le meilleur moment pour employer les onguents : les échecs ne proviennent donc pas d’une consommation arbitrairement mal placée. Les gains de niveau, les boutiques de soin, les reliques et l’amélioration des combats par le build sont exclus.

Avec deux onguents de 18 PV :

| Perte supposée normale / élite | Parcours du puits restant au-dessus de zéro PV | Porte | Barque |
|---|---:|---:|---:|
| 8 / 19 PV | 104 sur 160 | 20 sur 80 | 10 sur 40 |
| 12 / 26 PV | 28 sur 160 | 0 sur 80 | 0 sur 40 |
| 16 / 33 PV | 0 sur 160 | 0 sur 80 | 0 sur 40 |

**Ce sont des comptes de budgets faisables sous des coûts imposés, pas des taux de victoire.** Ils montrent que proposer des salles « également difficiles » ne rend pas les origines équivalentes : le camp précoce et l’élite supplémentaire changent l’économie. La porte doit pouvoir acheter une réponse suffisamment tôt ; la mémoire de la barque doit apporter une valeur exploitable avant que l’attrition ne ferme toute possibilité. Cela peut prendre la forme d’une charge de préparation, d’un accès à un accostage moins coûteux ou d’un choix de relique ciblé, avec un sacrifice alternatif explicite.

Le fichier `run_budget.csv` étend ce contrôle à zéro, deux et quatre onguents. Une future simulation de run devra remplacer les pertes constantes par les résultats de combats sur grille et y intégrer la progression. Ce contrôle préalable évite simplement de demander aux combats de résoudre une économie impossible.

## 9. Construire une run connue et inconnue

Le joueur connaît les familles de menaces des deux prochains segments, la prestation d’une halte visible et les conditions d’un défi accepté. Il ignore la variante exacte d’une composition, une partie des objets proposés et les événements marqués comme inconnus. Les rencontres sont tirées dans des familles définies ; le jeu ne fabrique pas après coup l’ennemi qui contre la relique récemment choisie.

La récompense peut proposer trois intentions : approfondir une interaction équipée, couvrir une faiblesse, prendre une ressource de voyage. Ce sont des catégories d’offres, pas une garantie d’obtenir la relique exacte désirée. Une première mutation doit pouvoir s’acheter avec les points sans attendre un tirage. Un moteur qui exige trois objets nommés avant de fonctionner constitue un mauvais départ.

Un calcul de butin mesure cette fragilité. Dans un pool de 24 reliques, avec cinq offres indépendantes de trois objets distincts chacune, une relique précise apparaît au moins une fois avec une probabilité de **48,7 %**. Si trois objets différents permettent le même raccord mécanique, on atteint **87,7 %** ; avec six solutions, **98,9 %**. La formule est `1 − [C(24−k,3) / C(24,3)]^5`. Elle suppose que les objets peuvent réapparaître entre les offres ; un pool sans remise entre les offres donnerait d’autres résultats.

La recommandation issue de ce calcul est de prévoir plusieurs raccords compatibles, pas d’assurer chaque combo. Une construction de retour d’arme peut obtenir son relais par une technique, une relique ou un aspect ; l’objet rare transforme son plafond de puissance. Elle fonctionne déjà sans lui.

Trois parcours illustratifs montrent ce que cela peut raconter. Ils sont des scénarios de conception, pas des parties simulées :

- **La descente du briseur.** Départ au puits avec marteau, interruption et protection magique. Le joueur choisit le fondeur à risque pour obtenir un matériau de collision ; au camp, il renonce à une amélioration pour réparer les PV perdus. À la confluence, une relique de relais apparaît : le marteau devient un outil pour placer les ennemis dans une ligne de projectiles. Il choisit ensuite des couloirs de tireurs et conserve une amarre pour le dernier segment mobile. Son identité a changé sans perdre l’investissement initial dans la rupture.
- **Le deuil immobile.** Départ par la porte avec bouclier, lance plantée et protection physique. Le joueur dépense tôt chez le marchand pour une garde de salve, puis transforme la lance en obstacle. Une découverte permet de convertir le bronze brisé en projectile. Face aux incantations ultérieures, il achète une interruption plutôt qu’une quatrième amélioration de garde. Le build devient très fort contre les formations tout en restant vulnérable aux attaques de zone derrière lui.
- **La traversée endettée.** Départ en barque avec disque, passage et nécessaire d’ancrage. La mémoire de la première halte révèle une bifurcation lucrative. Une relique permet de dépenser des oboles pour répéter un lancer : le joueur gagne un élite, mais renonce à une offre de soin. Il abandonne ensuite cette économie fragile pour un retour d’arme alimenté par ses placements. Le trésor a servi de transition, pas de bonus permanent sans coût.

## 10. Les défis : orienter un prochain combat, sans condamner tous les builds lents

Les défis facultatifs conservés dans le jeu conviennent à cette structure. Leur contrat doit afficher la condition, la récompense et le modificateur exact du prochain combat. La durée du combat précédent ne devient pas un malus global : cela ferait payer systématiquement les builds de contrôle, d’usure et de défense, même lorsqu’ils sont bien joués.

Exemples proposés :

| Défi volontaire | Condition | Effet annoncé sur le prochain combat |
|---|---|---|
| Couper la voix | Tuer ou interrompre deux canalisations avant leur résolution. | Le prochain soutien commence avec une recharge supplémentaire ; échec : sa première canalisation est accélérée, sans dégâts cachés. |
| Traverser à sec | Ne pas dépenser de charge d’ancrage. | Succès : une charge éphémère au choix ; échec : aucune récompense, pas de peine supplémentaire. |
| Briser la ligne | Déplacer deux ennemis distincts hors de leur formation. | Succès : +20 oboles ; échec : l’écran ennemi suivant reçoit 15 de garde au premier tour. |
| Prendre de vitesse | Finir avant la fin du quatrième tour. | Succès : choix de mutation offert ; échec : le premier attaquant suivant commence avancé d’une case. |

Un seul modificateur de dette est actif à la fois, et il expire après le combat suivant. Le moteur ne doit pas faire boule de neige sur plusieurs salles après un seul défi raté. La condition de vitesse reste une occasion choisie par certains builds ; elle ne définit pas toute la run.

## 11. Construire des assemblages excessifs sans supprimer le combat

Les combinaisons du catalogue privilégient un changement de règle : lancer depuis sa propre lance, changer une barrière en munition, employer un danger de salle comme source d’attaque, dépenser de l’or comme tempo. Un multiplicateur de dégâts peut récompenser le montage, mais le changement visible doit arriver avant le gros nombre.

Trois règles de causalité sont nécessaires. Une attaque porte une origine : action payée, retour d’arme, effet de relique, terrain. Un effet précise les origines admissibles. Une conversion s’applique une fois et ne recrée pas un événement de départ. Les gains de ressource précisent leur réserve : un ennemi ne peut donner plusieurs fois ses PV initiaux en soin ; un projectile ne peut générer les oboles qui paient sa propre répétition.

Exemple chiffré : une lance plantée et deux relais préparés permettent de transformer une frappe de 40 en trois impacts à 40, 26 et 17 sur des cibles différentes, soit 83 avant défenses. Le tour paraît démesuré, mais les relais ont coûté des actions, la géométrie est nécessaire et le dernier impact ne crée pas un nouveau relais. Avec deux ennemis alignés seulement, une partie de la puissance disparaît. Le calcul ne promet pas 83 dégâts chaque tour.

Autre exemple : une relique conserve jusqu’à 40 points de bronze absorbé ; une technique consomme 30 de cette réserve pour infliger 45 dégâts en ligne. C’est une conversion spectaculaire de défense en attaque, mais la réserve consommée ne protège plus Achille. Les dégâts de cette ligne ne remplissent pas la réserve. Le joueur peut choisir de garder sa sécurité ou de la sacrifier, même au sommet du build.

Le but n’est pas que Pâris annule ces assemblages avec une immunité générale. Ses phases peuvent alterner tireurs espacés, charges lisibles et obstacles destructibles. Une construction dispose de fenêtres favorables et d’autres où elle doit utiliser ses outils secondaires. Ses vulnérabilités sont annoncées avant la dernière halte pour permettre une préparation.

## 12. Ce qui mérite un prototype en premier

Le catalogue est une réserve de directions, pas une demande de produire simultanément vingt-quatre armes et cent arbres. Le premier lot devrait permettre de vérifier six moteurs réellement distincts : rupture, garde de salve, retour d’arme, combustion déplacée, saignement avec soin fini et dépense d’oboles. Chacun reçoit un départ complet, une mutation forte, une relique permanente et une issue éphémère. Les vingt-quatre constructions du catalogue restent l’horizon de variété.

Le protocole suivant rend les résultats comparables : mêmes graines, trois compositions par origine, géométries enregistrées, santé persistante sur le premier segment. Pour chaque moteur, comparer une préparation adaptée, une préparation vulnérable annoncée et une variante polyvalente. Jouer avec au moins deux politiques : résolution compétente et erreurs plausibles. Une IA de dégâts maximaux ne représente ni le débutant ni le joueur prudent.

Mesures utiles : PV perdus, charges consommées, tours, PA inutilisés, nombre de cibles traitées par plusieurs options viables, changement de cible décisif, offres refusées et coût du pivot. Enregistrer aussi la raison verbalisée de chaque choix : deux boutons avec le même résultat numérique peuvent paraître distincts dans le catalogue et identiques en jeu.

Critères proposés pour poursuivre : au moins trois moteurs viables par origine ; une mauvaise préparation coûte nettement plus que la bonne sans mort inévitable cachée ; aucun départ n’est le meilleur partout ; une mutation change au moins une décision récurrente ; un pivot arrive assez tôt pour être utilisé ; un assemblage rare produit une salle spectaculaire tout en conservant un problème à résoudre ailleurs.

Critères d’abandon : garde ou soin infinis, mêmes deux actions optimales dans presque toutes les salles, ennemis simplement rallongés en PV, technique inutile hors de son biome, récompense obligatoire absente la moitié du temps, dette qui continue de grossir après l’échec initial. La première expérience sur la garde a déjà identifié un de ces cas.

## 13. Reproduction et limites

Exécuter `python model.py` avec Python 3.10 ou supérieur depuis n’importe quel répertoire. Le programme relit le graphe du dépôt, enregistre son empreinte SHA-256 dans `results.json` et régénère les quatre CSV ainsi que `results.json`. Les sorties sont déterministes ; aucune dépendance externe n’est requise. Des contrôles intégrés vérifient les budgets de PA, les longueurs des chemins et la monotonie des défenses dans les rencontres à dégâts d’une seule catégorie. `verify.py` contrôle séparément les comptes, les fichiers et plusieurs cas calculables à la main.

L’énumération est une traduction Python des connexions lues dans le GDScript, pas une exécution de `create_nodes()` dans Godot. Les secrets sont traités comme entièrement disponibles ou entièrement absents. Le modèle de combat ne simule ni la totalité des options d’action ni une recherche de stratégie optimale. Les priorités imposées et la taxe d’accès peuvent défavoriser artificiellement certaines armes. Les fractions sont conservées, tandis que le jeu applique ses propres arrondis. Les coûts de voyage sont comparés sur une seule salle à pleine santé.

Les calculs répondent donc à des questions bornées : combien de chemins ce graphe autorise-t-il, quelle différence produit une défense dans cette situation, quel risque crée un objet indispensable aléatoire, et quelles règles conduisent à une attrition triviale ? Ils ne démontrent pas encore la viabilité d’une run complète ni l’équilibrage des vingt-quatre constructions.

### Sources externes

Consultées le 12 septembre 2026. Les liens sont repris dans le tableau de recherche, à proximité des enseignements associés.

1. Subset Games, *Into the Breach*, présentation officielle : https://subsetgames.com/itb.html
2. Eleventh Hour Games, *Last Epoch — Skills* : https://lastepoch.com/skills/
3. Crate Entertainment, *Grim Dawn — Combat* : https://www.grimdawn.com/guide/gameplay/combat/
4. Grid Sage Games, *Designing for Mastery in Roguelikes*, 7 août 2025 : https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/
5. Grid Sage Games, *Spicing Up Primary Maps 2: Area Denial*, 28 septembre 2021 : https://www.gridsagegames.com/blog/2021/09/spicing-up-primary-maps-2-area-denial/
6. Overhype Studios, *Dev Blog 79: Progress Update — Injury Mechanics*, journal historique de développement : https://battlebrothersgame.com/dev-blog-79-progress-update-injury-mechanics/
