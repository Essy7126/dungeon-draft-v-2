# Monstres de Catabase — rencontres et évolution v3

Cette version donne aux salles des effectifs et des combinaisons de rôles distincts. La difficulté dépend de la profondeur, du grade, des actions accessibles et du budget propre à la formation. Elle ne réagit pas au build, aux PV actuels ou à l’équipement du joueur.

Le départ canonique de l’étape I, le champion de bronze de VII et Pâris de XX conservent leurs rencontres. Les haltes et la construction de build restent régies par la route existante. Aucun objet, arbre ou circuit de récompense nouveau n’est introduit par cette évolution des ennemis.

## Familles et grades

Le catalogue `CatabaseMonsterEvolutionCatalog` crée des copies indépendantes des unités et de leurs sorts. Les grades sont fixes : **Initié aux étapes II–V**, **Vétéran VI–XII**, **Spécialiste XIII–XVIII**. Le budget général est de 4, 5 puis 6 PA ; certains auxiliaires gardent 4 PA. Les coûts, usages par combat et délais limitent les combinaisons réellement possibles.

| Famille | Premier apprentissage | Évolution tactique |
| --- | --- | --- |
| Airain | Brute lente à une attaque de contact | Fracture d’armure et revers ; Rabatteur à chaîne, Porte-Égide de groupe, Exécuteur à sentence préparée |
| Braise | Projectile de feu | Fournaise différée ; Fondeur à terrain brûlant, Artilleur à longue portée, Conducteur qui marque pour la meute |
| Styx | Molosse poursuivant | Saignement ; déplacement vers les braises, chasse rapide, Alpha protégeant la meute |
| Léthé | Projectile d’ombre | Ralentissement d’un PM ; Tisseuse à terrain de givre, Oracle renforçant un allié |
| Tireurs | Tir à distance, mobilité de 3 PM | 4 puis 5 PM ; Traqueur de proximité ou Guetteur à 2 PM et grande portée |
| Officiants | Soutien à soins limités | Protection d’allié ou de groupe ; Collecteur dépendant de porteurs proches |
| Auxiliaires | Serviteur fragile | Porteur fragile disposant d’une protection à usage unique |

Les archers utilisent actuellement le visuel peint du Rejeton ; les officiants utilisent celui de la Lamie. Leurs noms, grades, statistiques, sorts et comportements les distinguent, mais cette livraison ne produit pas deux nouvelles silhouettes. Les quatre silhouettes peintes conservent leurs animations articulées et leurs quatre directions indépendantes.

## Progression des rencontres

Les formations ci-dessous sont celles choisies par le catalogue runtime selon l’étape et la branche. Les noms du chemin et ceux de sa formation sont deux informations complémentaires.

| Étape | Formation et effectif | Question tactique |
| --- | --- | --- |
| I | Départ canonique | Comprendre les quatre techniques d’Achille |
| II | Deux brutes **ou** trois tireurs | Contourner une approche lente ou couper des lignes de tir |
| III | Un tireur et deux molosses **ou** deux gardiens élites | Gérer la poursuite sous couverture ou isoler un défenseur résistant |
| IV | Halte | Préparer le secteur suivant |
| V | Lamie et brute **ou** trois tireurs | Garder une issue au contact ou changer de ligne à couvert |
| VI | Cinq brutes à **2 PM** **ou** Conducteur et trois molosses | Exploiter zones et lenteur ou empêcher la marque de soutenir l’encerclement |
| VII | Champion de bronze canonique | Épreuve commune conservée |
| VIII | Halte | Rééquiper et choisir sa prochaine orientation |
| IX | Officiant, brute et deux porteurs **ou** six serviteurs | Atteindre le soutien ou réduire rapidement une foule fragile |
| X | Trois tireurs, deux molosses et Lamie **ou** Rabatteur et Exécuteur | Supprimer un front ou briser le duo attraction/sentence |
| XI | Deux brutes et cinq serviteurs **ou**, si combat de bibliothèque, Officiant, deux brutes et deux tireurs | Ouvrir l’espace ou contourner une défense soignée |
| XII | Halte | Préparer les spécialistes |
| XIII | Fondeur et deux pousseurs **ou** deux Porte-Égides et deux tireurs | Sortir de la combinaison feu/poussée ou séparer la couverture des tireurs |
| XIV | Deux Guetteurs, Traqueur, deux chasseurs et Tisseuse **ou** trois brutes et deux Porte-Égides à **2 PM** | Gérer plusieurs lignes de menace ou exploiter la lenteur d’un groupe protégé |
| XV | Rabatteur et Exécuteur élites | Interrompre leur combinaison avec le placement |
| XVI | Halte **ou** duel facultatif contre le champion de la dernière obole | Récupérer ou affronter un seul adversaire polyvalent |
| XVII | Alpha et quatre serviteurs **ou** Porte-Égide, Guetteur et Protecteur | Réduire la meute ou isoler le tireur protégé |
| XVIII | Collecteur, trois brutes et quatre porteurs **ou** Rabatteur, Exécuteur, Artilleur, deux pousseurs et Oracle | Couper le convoi de soutien ou défaire une combinaison adverse prioritaire |
| XIX | Halte | Préparer le dernier combat |
| XX | Pâris canonique | Conclusion conservée |

Chaque salle reste une seule vague : **un à huit ennemis**, plafond vivant égal au groupe initial, sans invocation ni résurrection ajoutée. Les grandes formations paient leur nombre par des coefficients de PV et de dégâts réduits ; cinq brutes lentes ne reprennent pas les statistiques d’un duel d’élite.

## PV, dégâts et pression

La factory applique deux budgets séparés :

- PV = PV du rôle et de son grade × coefficient de profondeur × coefficient de la formation × coefficient élite éventuel ;
- Prouesse = Prouesse du rôle × coefficient de profondeur × coefficient de la formation × coefficient élite éventuel.

Les élites ajoutent 15 % de PV et 12 % de Prouesse aux budgets de leur formation. Le nombre d’ennemis, les grades, les PM et les nouveaux sorts sont écrits dans les rencontres ; aucun coefficient caché ne contre un choix du joueur. Les plafonds de PM des deux processions de cinq sont appliqués avant le placement.

Les soins fixes suivent le coefficient de PV de la rencontre ; les dégâts périodiques, terrains, marques offensives et renforcements suivent le coefficient de Prouesse. Les impacts et boucliers qui utilisent une formule lisent les statistiques finales. Les ressources auteur partagées restent inchangées.

Les chiffres précis de chaque salle figurent dans sa fiche « Forces et techniques » et dans le rapport du probe. Une courbe de données vérifiée ne prouve pas le temps de victoire, les pertes de PV d’une run complète ou le plaisir de jeu. Ces aspects demandent encore des parties avec différents builds.

## IA, soutien et réponses du joueur

L’IA réévalue ses possibilités après chaque action des profils évolués, avec au plus quatre actions réelles dans une activation et toujours sous leurs coûts en PA, usages et délais. Elle peut rapprocher puis frapper, se protéger puis attaquer, reculer pour dégager un tir, soigner un allié blessé ou chercher une poussée vers du feu. Ce plafond de sécurité ne donne pas quatre actions gratuites.

Les soins sont limités à deux usages au premier grade et trois ensuite, avec une activation d’attente entre eux. Le Collecteur exige un porteur vivant de son équipe à deux cases au maximum. Cette condition est revalidée au lancement ; son absence refuse le soin sans dépenser le coût ou une charge. Les porteurs peuvent donc devenir une cible utile sans constituer une réserve de soin infinie.

Les porteurs rejoignent un Collecteur vivant et restent à proximité tant qu’il possède des soins, y compris pendant leur délai de récupération. Ils peuvent quitter cette zone pour éviter un terrain plus dangereux. Un Collecteur ayant un soin disponible et un allié blessé cherche un porteur ; sans porteur, il conserve ses autres actions. La formation de soutien existe donc aussi dans les déplacements de l’IA.

Les protections temporaires et les effets de groupe utilisent les cibles alliées réelles. Le présage de l’Oracle renforce une activation offensive et disparaît avec sa source. Le givre retire un PM ; aucun étourdissement faisant sauter tout le tour n’est ajouté.

La Fournaise, la visée préparée et la sentence suivent leur cible et revérifient la portée et la ligne de vue lors de leur résolution. Quitter le contact de l’Exécuteur ou rompre la ligne d’un tireur annule un impact devenu illégal. La résolution consomme l’activation du lanceur. Ce ne sont pas des explosions promises sur une case fixe. Les zones de feu et de givre sont posées immédiatement par leurs techniques ; elles ne sont pas présentées comme des bombardements différés.

Le placement conserve une distance minimale propre au rôle : au moins `max(5, PM + 3)`, augmentée à la portée maximale + 1 pour les profils de tir. Le planificateur valide chaque corps et sa distance ; la distance maximale reste une préférence. Les effectifs sont placés sur la vraie grille de chaque salle.

Les dix arènes d’expansion possédaient un verrou d’auteur limitant les ennemis à leurs trois ou quatre anciens marqueurs. Pour ces seules copies de rencontres évoluées, la factory remplace ce verrou par les sols normaux réellement praticables, hors obstacles, dangers et cases de déploiement du héros. Les autres salles conservent leurs restrictions ; aucune scène auteur n’est réécrite. Les profils ayant les contraintes de distance les plus fortes sont placés en premier.

## Lire la rencontre avant de choisir

La carte présente, pour les combats connus proches ou déjà révélés : le nom de la formation, l’effectif réel, sa menace principale et une piste tactique. « Forces et techniques » ouvre une liste défilante des adversaires regroupés par type : grade, PV, PA, PM, initiative, défenses et sorts. Les valeurs de dégâts avant défenses, soins et boucliers sont calculées depuis les copies finales de la salle.

Cette consultation ne choisit pas la destination, ne relance pas le tirage et ne modifie pas la sauvegarde. Les inconnus et les destinations lointaines ne révèlent pas leur composition par ce panneau, même si leur identifiant interne est déjà déterminé. Les rencontres protégées ne reçoivent pas de fiche de monstres inventée.

## Vérification reproductible

Les cinq tests `test/unit/test_catabase_encounter_preview.gd` couvrent les valeurs effectivement proposées, l’immuabilité du nœud, le masquage des inconnus et des lieux lointains, les rencontres protégées et l’absence d’engagement lors de la consultation.

Le probe `tests/expedition/CatabaseEncounterEvolutionProbe.tscn` examine toutes les branches des seeds 2401, 42 et 777 : effectifs réels, placements, coûts et portées des sorts, correspondance entre fiche et salle. Son mode graphique ouvre les détails de route puis instancie trois vraies salles : les trois tireurs, les cinq brutes et le convoi de huit. Il ne joue pas trois victoires et ne mesure pas l’équilibrage d’une run.

Les sorties sont isolées dans `artifacts/catabase_monsters/evolution/<résolution>/` ; elles restent des artefacts locaux. Les commandes et résultats de la passe finale sont ajoutés après son exécution. La méthode graphique des sprites demeure documentée dans [le README du pipeline](../../tools/catabase_monster_sprite_pipeline/README.md).
