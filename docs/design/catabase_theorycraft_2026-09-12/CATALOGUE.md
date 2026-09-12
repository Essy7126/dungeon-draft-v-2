# Catabase — Catalogue des constructions et des transformations

**Propositions de conception, 12 septembre 2026. Aucun contenu de ce catalogue n’est déclaré implémenté ou équilibré.** Les rotations numériques du laboratoire sont des sondes réduites ; elles ne simulent pas ces assemblages complets. Voir [l’analyse et ses limites](README.md).

## 1. Une grammaire commune pour des Achille différents

Achille conserve 6 PA et 3 PM de base. Une action principale a un coût payé ; ses retours, ricochets et effets de relique portent une origine secondaire. Les secondaires peuvent faire des dégâts, pousser ou consommer un état si leur texte le prévoit. Ils ne comptent pas comme une nouvelle action payée et n’héritent pas automatiquement de tous ses déclenchements.

La **Puissance P** vaut 18 au départ. `1,3 P` signifie 23,4 dégâts avant défenses et arrondi. Une portée exprimée en cases conserve les règles de ligne de vue sauf exception écrite. Un recul ou une traction obéit à la Force et aux règles de collision ; l’effet n’est pas garanti sur un ennemi explicitement ancré. Une recharge de deux tours signifie qu’un lancement au tour 1 rend la technique disponible au tour 3.

Les éléments ont une fonction et une représentation : **airain** pour la protection et la rupture physique, **braise** pour les zones et la conversion d’altérations, **onde** pour les déplacements et la conduction, **ombre** pour les accès et les lignes de vue. Airain est une famille de techniques, pas une nouvelle catégorie de résistance obligatoire. Les catégories de dégâts restent physiques ou magiques ; leurs éventuels éléments sont affichés séparément. Aucun joueur n’a besoin d’équiper les quatre familles.

Les réserves additionnelles appartiennent à un objet ou une technique : jusqu’à 40 de bronze pour l’urne, jusqu’à 30 PV de soin pour la fibule sanguine, oboles déjà connues pour le péage. Le joueur ne gère pas une jauge universelle de mana, de rage et de chaleur ajoutée à tous les builds. Une réserve apparaît dans l’interface seulement si le kit l’utilise.

## 2. Huit armes et vingt-quatre aspects

L’arme fournit deux actions de départ, améliorables par un aspect à 4 points. Les techniques libres viennent compléter cette paire. Les chiffres ci-dessous établissent des hypothèses initiales : leur utilité dépend de la grille, du coût des accès et des seuils de mort des ennemis.

| Arme | Action A | Action B | Limite qui crée un choix |
|---|---|---|---|
| **Lance de frêne** | Estoc, 3 PA : 1,3 P à portée 1–2 en ligne. | Mesure, 2 PA : 0,6 P, recule la cible d’une case. | Angles et alignements ; l’ennemi qui revient au contact oblige à reconfigurer la ligne. |
| **Xiphos et bouclier** | Taille, 3 PA : 1,15 P au contact. | Couverture, 2 PA : 16 de garde vers un arc frontal jusqu’au prochain tour. | La direction est engagée lors de la garde ; les dégâts de zone restent dangereux. |
| **Marteau funéraire** | Masse, 4 PA : 1,6 P au contact, ignore 35 % d’armure. | Ébranler, 2 PA : 0,45 P et pousse d’une case. | Une grande frappe ratée en accès laisse peu d’actions ; moins bon contre des cibles dispersées. |
| **Javelots de chasse** | Jet, 2 PA : 0,75 P à portée 2–5, consomme un des trois javelots. | Ramasser, 1 PA : récupère les javelots tombés à deux cases ou moins. | Munitions visibles sur le sol ; les déplacements préparent la suite. Fin du combat : récupération complète. |
| **Arc de Chiron** | Trait, 3 PA : 1,25 P à portée 3–7. | Visée, 2 PA : le prochain Trait avant déplacement ignore un obstacle bas et gagne 30 %. | Portée minimale, position exposée pendant la préparation ; aucun bonus si la cible n’est plus accessible. |
| **Disque de bronze** | Lancer, 3 PA : 0,9 P, finit sur une case libre derrière la cible. | Retour, 2 PA : 0,65 P sur le trajet jusqu’à Achille, puis revient en main. | Lancer indisponible tant que le disque n’est pas récupéré ; objets hauts bloquent le retour. |
| **Chaîne lestée** | Fouet, 3 PA : 1 P à portée 1–3. | Harpon, 2 PA : 0,35 P et traction de deux cases. | Résistance aux déplacements, danger de ramener l’ennemi vers soi ; dégâts directs moyens. |
| **Hampe des braises** | Tison, 3 PA : 0,8 P magique à portée 1–4. | Soufflet, 2 PA : déplace une zone d’une case ; si aucune zone admissible, crée une braise de 4 dégâts pour un tour. | Nécessite des positions préparées ; un ennemi peut quitter sa zone. |

Les deux actions d’arme restent présentes quand une technique apparentée est équipée. Une technique de rappel peut ainsi fournir une autre manière de récupérer le disque, mais ne donne pas un deuxième disque. Les doubles emplois volontaires ouvrent une interaction ; ils ne doublent pas une ressource matérielle.

| Arme | Aspect A | Aspect B | Aspect C |
|---|---|---|---|
| Lance | **Géomètre** : l’estoc gagne 25 % à distance exactement deux. | **Veilleur** : Mesure prépare une réaction de 0,6 P contre le premier ennemi qui rentre dans sa ligne ; expire au prochain tour. | **Pilier** : Mesure peut planter la lance et Achille frappe alors à mains nues à 0,6 P jusqu’à récupération. |
| Xiphos | **Myrmidon** : après avoir bloqué deux impacts, la prochaine Taille frappe un second ennemi adjacent à 60 %. | **Duel** : +25 % sur Taille si aucun autre ennemi n’est adjacent à la cible. | **Éclat** : consommer sa garde ajoute 50 % de sa valeur à Taille ; la défense disparaît. |
| Marteau | **Fissure** : Masse laisse −25 armure pour deux tours, non cumulable. | **Démolisseur** : une collision détruit un obstacle fragile et projette des débris à 0,5 P derrière lui. | **Cloche** : Masse gagne une zone d’une case, mais son coefficient principal passe à 1,1 P. |
| Javelots | **Traque** : un javelot fiché marque sa victime ; le prochain jet sur une autre cible gagne 20 %. | **Hérisson** : les javelots au sol deviennent des piques à huit dégâts physiques par entrée volontaire ou forcée, consommées après un impact. | **Lest** : deux javelots sur une cible lui retirent un PM pendant un tour ; les munitions restent engagées. |
| Arc | **Perce-brume** : Visée révèle aussi le premier ennemi derrière un écran de brume. | **Corde courte** : Trait fonctionne au contact, portée maximale réduite à cinq et coefficient à 1,05 P. | **Chasse longue** : un Trait préparé peut être retardé d’un tour et gagne 60 % au lieu de 30 % ; la cible et la ligne sont engagées. |
| Disque | **Double rive** : le retour peut finir sur une lance plantée ; sa récupération reste nécessaire. | **Ébréché** : chaque cible traversée perd 10 armure jusqu’au prochain tour, une fois par trajet. | **Retour fatal** : Lancer tombe à 0,6 P, Retour monte à 1,15 P ; la préparation compte davantage. |
| Chaîne | **Geôlier** : Harpon peut attacher une cible à un point pendant un tour ; elle reste libre dans un rayon de deux cases. | **Pendule** : traction latérale d’une case au lieu de vers Achille, pour choisir une collision. | **Arrache-garde** : un Harpon qui ne déplace pas retire jusqu’à 18 de garde, sans contourner une immunité aux effets. |
| Hampe | **Cendrier** : Soufflet éteint une braise et stocke un unique tison, dépensé pour +0,5 P sur Tison. | **Veine** : une zone peut suivre une fissure de terrain sur trois cases ; sa durée n’augmente pas. | **Fournaise** : Tison gagne 0,4 P quand Achille est lui-même dans une zone hostile de chaleur ; aucun bonus dans sa propre zone. |

Une arme n’est donc pas un simple paquet de statistiques. Les javelots engagent physiquement des munitions ; le disque existe à un endroit ; le bouclier engage une direction. Ces engagements offrent des occasions de construire des reliques originales.

## 3. Vingt-quatre techniques, trois mutations chacune

**T01 à T12 sont proposées au départ.** Les autres se découvrent ou s’achètent pendant la descente. Une mutation remplace l’effet concerné de la racine ; sauf mention explicite, elle conserve son coût, sa portée et sa recharge. Elle n’additionne pas les trois colonnes. Les valeurs servent de points de départ pour un prototype.

| ID et technique | Racine | Mutation A | Mutation B | Mutation C |
|---|---|---|---|---|
| **T01 Frappe du Péléide** | 3 PA, contact, 1,3 P physique. | **Fendre** : 1 P et −25 armure pour deux tours, non cumulable. | **Achever** : 1,1 P ; 1,7 P sous 35 % PV. | **Traverser** : 0,9 P et avance dans une case libre derrière la cible. |
| **T02 Percée** | 3 PA, avance jusqu’à deux cases en ligne ; 0,8 P à la première cible rencontrée. | **Pointe** : portée de déplacement trois, aucun dégât. | **Bélier** : portée une, pousse deux et conserve 0,8 P. | **Fuite** : part d’une case voisine d’un ennemi et laisse une entrave de −1 PM pour son prochain tour ; aucun dégât. |
| **T03 Tir du Pélion** | 3 PA, portée 2–6, 1,15 P physique. | **Clouer** : 0,8 P et −1 PM pour un tour. | **Ouvrir** : ignore 40 % d’armure, coefficient 1 P. | **Croiser** : 0,8 P ; +50 % si Achille a changé de côté par rapport à la cible depuis son dernier tour. |
| **T04 Garde de bronze** | 2 PA, 22 garde frontale jusqu’au prochain tour. | **Salve** : réduit de six les trois premiers impacts frontaux ; aucune réserve restante après ces impacts. | **Rempart** : 30 garde, mais seulement contre le prochain impact frontal. | **Riposte** : 14 garde ; le premier impact bloqué prépare +0,5 P sur la prochaine attaque de contact avant fin du prochain tour. |
| **T05 Lance plantée** | 2 PA, portée trois ; 0,4 P si ennemi, puis plante une lance rituelle sur une case libre voisine. Une seule. | **Appui** : Achille peut dépenser un PM pour se rapprocher de deux cases du point, une fois par tour. | **Obstacle** : le point bloque déplacement et projectile bas, 25 PV ; disparaît s’il est détruit. | **Relais** : le prochain projectile payé peut partir du point, qui se consume après ce tir. |
| **T06 Arrachement** | 2 PA, portée trois, 0,5 P et traction de deux cases. | **Désaxer** : déplacement latéral d’une case au lieu de traction. | **Dénuder** : aucun déplacement ; enlève 20 garde puis inflige 0,5 P. | **Ramener** : peut tirer un objet de terrain mobile de deux cases, sans dégâts. |
| **T07 Fauchage** | 3 PA, cône de trois cases adjacentes, 0,7 P à chaque cible. | **Moisson** : coefficient 0,55 P, chaque cible distincte blessée prépare deux de garde, max six. | **Balayer** : 0,5 P et pousse d’une case. | **Crochet** : vise deux cases latérales, 0,9 P ; laisse libre la case devant Achille. |
| **T08 Défi** | 1 PA, portée quatre, recharge deux tours ; la prochaine attaque payée sur la cible gagne 20 %, et celle-ci gagne 20 % contre Achille pendant un tour. | **Isoler** : bonus 35 % si aucun allié de la cible n’est adjacent ; sinon aucun bonus. | **Attirer** : remplace les bonus par une préférence de déplacement annoncée vers Achille si le chemin existe. | **Témoin** : aucun bonus immédiat ; +1 PA au prochain tour si la cible a infligé des dégâts aux PV d’Achille. Une seule marque active. |
| **T09 Entaille** | 2 PA, contact, 0,6 P physique et quatre dégâts persistants à la fin de deux tours ; rafraîchit sans cumuler. | **Plaie** : deux dégâts par case déplacée, max huit par tour, remplace les dégâts périodiques. | **Hémorragie** : zéro dégât direct ; huit persistants pendant deux tours. | **Cicatrice** : seulement deux persistants, mais −15 armure tant que l’état subsiste. |
| **T10 Sceau protecteur** | 2 PA, recharge deux tours ; retire une altération négative au choix et donne dix de garde contre la magie pour un tour. | **Prévenir** : protège contre la prochaine altération pendant deux tours, sans nettoyer l’actuelle. | **Rejeter** : nettoyage sans garde ; inflige 0,5 P magique au poseur encore visible. | **Conserver** : ne nettoie pas ; l’altération dure normalement, mais sa première application donne 16 garde magique. |
| **T11 Braise** | 3 PA, portée quatre, 0,7 P magique et une case de feu à six dégâts en fin de tour pendant deux tours. | **Sillon** : trois cases alignées, trois dégâts chacune, pas de dégât direct. | **Four** : une case à dix dégâts, s’active à la fin du prochain tour seulement. | **Tison porté** : la zone suit sa cible, quatre dégâts et une seule cible voisine touchée ; deux tours. |
| **T12 Pas de brume** | 2 PA, recharge deux tours ; transfert de deux cases vers une case visible libre. | **Retour** : laisse un point de retour jusqu’au prochain tour ; le retour coûte un PM et consomme le point. | **Traversée** : peut franchir une case occupée, arrivée libre toujours requise ; portée trois. | **Voile** : déplacement d’une case seulement, mais crée une brume sur la case quittée pendant un tour. |
| **T13 Répercussion** | 3 PA, consomme jusqu’à 30 de garde disponible pour infliger 1,5 fois la valeur consommée en ligne de trois cases. | **Aiguille** : une cible à portée cinq ; conversion ×2, maximum 40 dégâts. | **Onde** : cercle adjacent ; conversion ×1, garde consommée maximum 20. | **Plaque** : aucun dégât ; transforme la garde consommée en obstacle avec autant de PV, un seul obstacle. |
| **T14 Marque du chasseur** | 1 PA, portée cinq ; la prochaine action payée infligeant des dégâts à cette cible reçoit +0,3 P, puis consomme la marque. | **Relais** : à sa consommation, une nouvelle marque de +0,15 P apparaît sur le voisin le plus proche ; ne se propage plus. | **Réserve** : marque deux tours, bonus +0,5 P, mais seulement sur une attaque de 4 PA ou plus. | **Partage** : +0,15 P à deux cibles marquées par la même action de zone, sans bonus sur une cible seule. |
| **T15 Contretemps** | 2 PA, portée trois, recharge deux tours ; interrompt une canalisation interruptible. | **Retarder** : portée cinq, repousse la résolution d’un tour sans l’annuler. | **Rompre** : portée une, interruption et 0,7 P. | **Détourner** : ne l’annule pas ; décale d’une case une zone fixe annoncée, si le sort autorise ce déplacement. |
| **T16 Cendre froide** | 3 PA, portée quatre ; consomme un tison porté ou une case de braise occupée par la cible pour retirer deux PM au prochain tour et infliger ses dégâts futurs restants, max 16. | **Scorie** : remplace le ralentissement par −25 armure pendant deux tours. | **Vapeur** : transforme les dégâts restants en brume de deux cases, sans dégâts immédiats. | **Reprise** : réduit de deux PA le prochain sort de braise ce tour, min un ; aucun dégât ni ralentissement. |
| **T17 Étincelle** | 3 PA, portée quatre, 1 P magique ; rebond de 0,5 P sur un voisin mouillé, une fois. | **Circuit** : trois cibles maximum, coefficients 0,8 / 0,5 / 0,3 P ; chaque cible doit être mouillée. | **Arc sec** : supprime le rebond, 1,25 P contre une cible non mouillée. | **Retour de terre** : 0,7 P ; le rebond peut finir sur une lance plantée et y préparer dix de garde à récupérer. |
| **T18 Flux** | 2 PA, portée quatre ; translate une zone mobile d’une case, sans modifier durée ni puissance. | **Dérive** : deux cases dans le sens du courant. | **Contre-courant** : peut déplacer à contre-sens, mais seulement une case. | **Accostage** : agit sur une barque ou un ponton mobile admissible, selon les positions autorisées de la salle. |
| **T19 Entrave** | 2 PA, portée trois, recharge deux tours ; −2 PM au prochain tour, non cumulable. | **Lien** : la cible garde ses PM mais ne peut s’éloigner de plus de deux cases d’un point jusqu’au prochain tour. | **Étau** : −1 PM seulement, mais interdit le premier déplacement forcé subi, au choix d’Achille. | **Rupture** : −1 PM ; quand la cible dépense son dernier PM, elle perd dix de garde. |
| **T20 Offrande** | 1 PA, coûte 12 PV réels ; la prochaine attaque payée ce tour gagne 0,7 P. Une offrande active maximum, ne peut tuer Achille. | **Ferveur** : coûte 18 PV, +1 P ; aucune augmentation des effets secondaires. | **Partage du mal** : coûte huit PV ; transpose une altération admissible sur la prochaine cible touchée, sans durée supplémentaire. | **Serment vivant** : coûte 12 PV, aucun bonus offensif ; crée 24 garde qui disparaît au prochain tour. |
| **T21 Rappel** | 2 PA ; récupère une arme lancée ou un point rituel, inflige 0,8 P aux ennemis sur le trajet dégagé, une fois par cible. | **Détour** : peut passer par un point planté avant Achille, coefficient 0,6 P. | **Arrimer** : arrive sur une case libre choisie à deux cases d’Achille ; pas de récupération en main. | **Désarmer** : une seule cible touchée, coefficient 0,5 P et −25 % sur sa prochaine attaque physique. |
| **T22 Linceul** | 2 PA, portée trois ; brume sur deux cases pendant deux tours, bloque les lignes de vue traversantes selon la règle de salle. | **Couloir** : quatre cases en ligne, durée un tour. | **Refuge** : une case, durée trois tours. | **Dissipation** : retire au lieu de créer deux cases de brume et révèle les occupants sans les attaquer. |
| **T23 Péage** | 1 PA et 12 oboles ; la prochaine attaque payée ce tour produit une répétition secondaire à 50 %, sans mouvement ni gain de ressources. | **Avance** : 20 oboles, répétition à 80 %. | **Assurance** : six oboles, aucun dégât ; la prochaine relique éphémère rend sa charge si elle n’a produit aucun effet admissible. | **Passage réservé** : huit oboles ; ignore le prochain coût en PA lié à un accostage ou une traction de salle ce combat. |
| **T24 Héritage des morts** | 2 PA, portée trois ; consomme un vestige de cadavre et donne +0,5 P à la prochaine action payée. Les oboles de victoire ordinaires ne sont pas retirées. | **Dernier souffle** : remplace le bonus par 12 garde, aucun soin. | **Fosse** : transforme le vestige en piège à 0,8 P, détruit après un déclenchement. | **Mémoire** : stocke un seul vestige jusqu’à la fin du combat pour une consommation ultérieure à un PA. |

Un vestige est un objet de terrain laissé par une mort admissible, pas une nouvelle créature alliée. Un ennemi réanimé ne produit pas plusieurs vestiges ; les invocations renouvelables n’en produisent pas. Ce choix permet une construction nécromantique d’Achille sans créer de nouveau personnage jouable ni une armée autonome.

## 4. Six arbres approfondis : trente-six aboutissements

Chaque ligne ci-dessous propose **deux choix exclusifs après une mutation précise**, coûtant chacun quatre points supplémentaires. Les autres effets de la mutation restent inchangés sauf remplacement écrit. Les interactions trop dépendantes de la géométrie doivent être essayées sur les arènes existantes avant extension aux dix-huit autres arbres.

### T01 — Frappe du Péléide

| Après | Aboutissement 1 | Aboutissement 2 |
|---|---|---|
| Fendre | **Armure ouverte** : si la réduction d’armure est déjà présente, la frappe la consomme et ignore toute l’armure pour cet impact. Il faut ensuite rouvrir la cible. | **Faille commune** : la réduction d’armure se transmet à un ennemi adjacent à la cible, mais vaut −15 au lieu de −25 sur chacun. |
| Achever | **Dernier pas** : une exécution sous le seuil rend deux PM pour ce tour ; aucun PA. | **Trophée lourd** : une exécution prépare +0,6 P sur la prochaine frappe contre une autre cible, puis le trophée disparaît ; ne s’applique pas à cette nouvelle exécution elle-même. |
| Traverser | **Enfilade** : frappe également la case d’arrivée à 0,6 P si elle contient un ennemi ; dans ce cas Achille reste devant la première cible. | **Duel retourné** : après une traversée réussie, la cible inflige −30 % à Achille jusqu’au prochain tour, les autres ennemis restent inchangés. |

### T04 — Garde de bronze

| Après | Aboutissement 1 | Aboutissement 2 |
|---|---|---|
| Salve | **Écailles** : cinq impacts réduits de cinq au lieu de trois réduits de six. Très bon contre les petits projectiles, médiocre contre un coup lourd. | **Dernière écaille** : après consommation des trois réductions, crée un fragment de six garde récupérable par déplacement ; il expire au prochain tour. |
| Rempart | **Paroi** : garde 38 contre un impact ; Achille ne peut plus se déplacer volontairement après la garde ce tour. | **Déviation** : garde 22 ; un projectile physique entièrement absorbé dépose huit dégâts en débris dans la case voisine choisie au lancement de la garde. |
| Riposte | **Réponse courte** : consomme la riposte pour une attaque immédiate de 0,5 P contre l’attaquant adjacent ; aucune riposte n’est conservée. | **Colère retenue** : deux blocages de tours différents peuvent préparer 1 P au lieu de 0,5 P ; la première attaque consomme tout et la réserve expire après trois tours. |

La réduction fixe de Salve et la garde à impact unique de Rempart sont des expériences alternatives au bouclier universel du modèle. Elles ne résolvent pas par texte tous les abus : leur orientation, leur persistance et les compositions doivent être testées.

### T05 — Lance plantée

| Après | Aboutissement 1 | Aboutissement 2 |
|---|---|---|
| Appui | **Deux rives** : deux points autorisés ; se déplacer vers l’un consume l’autre. | **Pivot** : le déplacement d’appui peut finir à une case latérale du point ; il ne donne ni PA ni attaque gratuite. |
| Obstacle | **Digue** : obstacle de 40 PV, infranchissable au courant de faible intensité ; ne bloque pas les effets de salle majeurs annoncés. | **Écharde** : obstacle de 15 PV ; sa destruction par un ennemi inflige 0,8 P aux deux cases derrière lui, pas autour d’Achille automatiquement. |
| Relais | **Angle mort** : le tir partant du relais ignore un obstacle bas ; le relais se consume normalement. | **Chaînage** : le relais demeure après le premier tir mais tombe à un PV ; il se consume après le second tir, même s’il n’a touché personne. |

### T09 — Entaille

| Après | Aboutissement 1 | Aboutissement 2 |
|---|---|---|
| Plaie | **Écartèlement** : les déplacements forcés infligent trois dégâts par case, plafond neuf par tour ; les déplacements volontaires restent à deux. | **Claudication** : conserve deux par case, plafond huit ; après quatre dégâts de déplacement, la cible perd un PM restant ce tour, une fois. |
| Hémorragie | **Pression** : cinq dégâts par tour pendant quatre tours, au lieu de huit pendant deux ; rafraîchir ne verse pas les dégâts futurs immédiatement. | **Rupture rouge** : une frappe payée de 4 PA ou plus consomme les dégâts persistants restants et en inflige 75 % immédiatement. |
| Cicatrice | **Sous la plaque** : pénalité d’armure −25 ; dégâts persistants supprimés. | **Mémoire de fer** : pénalité −10 persistante jusqu’à la fin du combat, non cumulable ; ne réduit pas l’armure sous zéro par cet effet. |

### T11 — Braise

| Après | Aboutissement 1 | Aboutissement 2 |
|---|---|---|
| Sillon | **Contre-feu** : une seule translation de la zone par Flux ajoute deux dégâts par case pour sa durée restante. | **Terre brûlée** : les cases expirées deviennent difficiles pendant un tour ; aucun dégât supplémentaire. |
| Four | **Porte fermée** : si un obstacle bloque un côté de la case, le Four atteint 14 dégâts au lieu de dix ; un seul bonus. | **Réserve de chaleur** : si personne n’est touché, récupérer le Four avec Soufflet stocke un tison à +0,7 P ; la zone disparaît. |
| Tison porté | **Passation** : à la mort de la cible, le tison passe au voisin le plus proche, durée restante inchangée. | **Couronne de suie** : ne touche plus de voisin ; la cible laisse une case de brume derrière elle lors de son premier déplacement par tour. |

### T12 — Pas de brume

| Après | Aboutissement 1 | Aboutissement 2 |
|---|---|---|
| Retour | **Retraite préparée** : la première attaque physique annoncée sur la case d’arrivée peut déclencher le retour en réaction, en dépensant le PM réservé ; point consommé. | **Geste laissé** : le premier projectile payé après le pas peut partir du point de retour ; cela le consume et supprime la retraite possible. |
| Traversée | **Entre les lances** : traverser une case occupée prépare huit garde contre la prochaine attaque physique. | **Derrière le voile** : arrivée permise dans une brume révélée même si sa case n’est pas actuellement visible ; aucune traversée de mur. |
| Voile | **Rideau** : brume de deux cases au lieu d’une, mais Achille ne peut pas tirer à travers sans un autre outil. | **Apparition** : quitter volontairement sa propre brume prépare +0,4 P sur la prochaine attaque de contact, une fois par lancement. |

## 5. Seize reliques permanentes

Proposition d’emplacements : deux au départ, dont un occupé par la relique choisie ; un troisième à la première épreuve commune. Une seule relique « souveraine » — R12 à R16 — équipée à la fois au premier prototype, pour tester leurs interactions séparément. Cette restriction est un outil temporaire de conception ; son intérêt ludique devra être vérifié.

Les reliques R01 à R08 composent l’offre de départ. Leurs éveils à quatre points doivent amplifier leur règle, pas donner une statistique universelle. Quatre éveils sont spécifiés ici ; les autres restent à concevoir.

| ID | Relique et effet | Faiblesse ou dépense |
|---|---|---|
| **R01 Clou des Myrmidons** | La première attaque physique payée contre une cible déplacée ce tour gagne 20 %. | Il faut encore payer l’attaque après le placement ; ne se déclenche pas sur son propre déplacement initial. |
| **R02 Urne de bronze** | Stocke la moitié des dégâts ennemis effectivement absorbés par une garde, plafond 40. Cette réserve peut alimenter Répercussion. | La réserve ne protège pas les PV ; elle disparaît en fin de combat. Aucun gain sur dégâts auto-infligés ou absorbés par un obstacle. |
| **R03 Fil d’orme** | Le premier retour d’arme de chaque tour peut passer par un point planté admissible. | Le point se consume ; il faut l’avoir créé. Ne crée pas une deuxième arme. |
| **R04 Fibule du poursuivant** | Après une action payée qui blesse A, la prochaine action payée contre B différent gagne 20 % avant fin du tour. | Le bonus ne peut pas préparer une nouvelle fibule sur cette même action ; alterner conserve un coût et une cible utile. |
| **R05 Coupe des blessures** | Soigne 15 % des PV réellement retirés par les attaques physiques directes payées, avec une réserve de soin de 30 PV par combat. | Aucun soin sur sur-dégâts, soi-même, objets, invocations renouvelables ou dégâts persistants. La réserve consommée ne revient pas avant un nouveau combat. |
| **R06 Mèche errante** | La première zone de braise déplacée par une action payée chaque tour peut avancer une case supplémentaire. | La durée ne se réinitialise pas et aucune nouvelle zone n’est créée sur le trajet. |
| **R07 Obole fendue** | Une élimination par action payée rend quatre oboles, maximum vingt par combat. | Les répétitions du Péage ne rapportent rien ; le gain ne finance pas une boucle sur des invocations. |
| **R08 Amulette du seuil** | Annule la première altération négative reçue du combat, puis devient inactive. | Peut être consommée par un effet secondaire peu grave ; aucune résistance aux dégâts. |
| **R09 Cuirasse fêlée** | Une garde détruite par un ennemi crée un éclat ; consommer l’éclat avec une attaque de contact ajoute 0,6 P. Trois éclats produits maximum par combat. | Briser la garde soi-même avec Répercussion ne crée pas d’éclat. |
| **R10 Parole tenue** | Blesser par trois actions payées depuis la même case donne deux PA au prochain tour, une seule fois par combat. | Le déplacement volontaire ou forcé avant la troisième action annule la préparation. |
| **R11 Clef de brume** | Permet de cibler sa propre lance plantée ou son point de retour à travers la brume ; ne révèle pas les ennemis derrière. | Nécessite un point connu ; ne contourne ni murs ni portes fermées. |
| **R12 Miroir de la rive** | Après Flux, une zone hostile mobile devient neutre : elle peut toucher ses anciens alliés aussi bien qu’Achille. | Elle garde son calendrier et sa puissance ; ses dégâts ne déclenchent aucune autre relique d’Achille. |
| **R13 Vase des derniers gestes** | Le premier vestige consommé du combat ajoute un écho de 0,6 P à la prochaine attaque payée contre une autre cible. | Un écho secondaire, pas une copie du sort de l’ennemi. Il faut d’abord avoir obtenu une mort admissible. |
| **R14 Balance des souffles** | Une Offrande peut payer son coût depuis une dette temporaire de PV, plafond 24 ; dette retirée des PV à la fin du prochain tour d’Achille. | La dette peut tuer lors du paiement ; le montant et le moment sont affichés. Elle ne produit pas de garde ni de soin par elle-même. |
| **R15 Contrat du passeur** | Une fois dans la run, un coup fatal peut consommer toutes les oboles, minimum 60, et laisser Achille à 25 PV. | Le joueur accepte avant le combat ; le contrat ne s’active pas sans son prix et ne retire pas les ennemis restants. |
| **R16 Couronne sans retour** | Un retour d’arme peut emprunter deux relais distincts ; dégâts décroissants à 100 %, 65 %, puis 42 %. | Les relais se consument, aucun point ne peut être visité deux fois ; l’arme finit au dernier relais et doit être récupérée. |

Éveils proposés : **R01**, bonus 30 % mais uniquement après collision ; **R02**, plafond 60, gain conservé à 50 % ; **R03**, le point consommé rend un PM si le retour blesse deux ennemis distincts ; **R05**, réserve de soin 40, taux conservé à 15 %. Ces éveils accentuent une décision au lieu de multiplier tous les dégâts.

## 6. Douze reliques éphémères

Deux emplacements de ceinture, chacun contenant un objet d’une charge. Une utilisation coûte un PA sauf mention contraire. Aucun rechargement pendant un combat. La ceinture limite la préparation : emporter une issue de secours occupe la place d’un amplificateur offensif.

| Objet | Effet | Décision recherchée |
|---|---|---|
| **Obole noire** | Le prochain Péage ne coûte pas d’or ; son coût en PA reste payé. | Employer maintenant son amplification ou la garder pour un élite. |
| **Clou de berge** | Ancre Achille contre le prochain déplacement forcé pendant deux tours. | Fixer une position malgré la traction, sans supprimer tous les courants. |
| **Sel blanc** | Retire une altération et empêche sa réapplication pendant deux tours. | Nettoyer une faiblesse pour sauver un cycle offensif. |
| **Souffle en fiole** | Donne deux PM ce tour. | Finir un ennemi ou sortir d’une zone ; n’augmente pas les attaques possibles. |
| **Plaque d’offrande** | Donne 24 garde contre le prochain impact. | Absorber un gros coup annoncé plutôt que plusieurs petits. |
| **Cire des noms** | La prochaine attaque magique subie dans les deux tours perd son effet secondaire, dégâts conservés. | Accepter une perte de PV pour préserver son plan. |
| **Écharde d’ambre** | La prochaine cible blessée par une action payée est mouillée pendant deux tours. | Ouvrir une conduction hors de la barque sans dépendre du terrain. |
| **Braise captive** | Place une zone à six dégâts pendant deux tours sur une case à portée deux. | Fournir le carburant d’une transformation quand la salle n’en donne pas. |
| **Fil du retour** | Récupère une arme au sol par un trajet admissible ; aucun dégât de retour. | Réparer un mauvais lancer sans perdre une activation entière. |
| **Morceau de nuit** | Pose une brume d’une case jusqu’au prochain tour. | Couper une ligne particulière, sans immunité générale au ciblage. |
| **Dernier onguent** | Deux PA, rend 24 PV ; ne retire pas une dette déjà engagée. | Soigner pendant la pression au prix d’une vraie action. |
| **Sceau fendu** | Réduit de 25 l’armure OU la défense magique d’une cible pendant deux tours, choix à l’emploi. | Permettre un pari risqué sans transformer une défense spécialisée en obstacle absolu. |

Les nécessaires initiaux du dossier et ces reliques ne sont pas des systèmes de combat différents : les nécessaires occupent les mêmes emplacements et représentent des préparations avec deux charges. À l’épuisement, l’emplacement accueille un autre objet. Leur puissance respective devra être harmonisée avant intégration.

## 7. Vingt-quatre constructions à chercher pendant la run

Ces fiches définissent des moteurs et des décisions, pas des classes verrouillées. Les techniques citées sont les noyaux ; les deux autres emplacements libres en milieu de run servent à une défense, un accès ou une conversion selon le trajet. Une relique tardive augmente le plafond : chaque moteur doit avoir une version fonctionnelle avec une relique de départ ou ses seules techniques.

| Construction | Noyau proposé | Tour ou situation satisfaisante | Punition et pivot possible |
|---|---|---|---|
| **1. Le géomètre** | Lance Géomètre, T02 Pointe, T03 Croiser, R01. | Pousser, se remettre à distance deux, exploiter un angle opposé au tour suivant. | Piégé au contact par plusieurs ennemis ; ajouter T07 Balayer ou passer en Corde courte avec un arc trouvé. |
| **2. Le coupe-file** | Xiphos Duel, T01 Traverser, T08 Isoler, R04. | Traverser l’écran pour isoler un archer, puis changer de cible pour rentabiliser la fibule. | Se retrouve entouré derrière la formation ; T12 Retour sécurise l’engagement au prix d’une technique offensive. |
| **3. Le démolisseur** | Marteau Démolisseur, T06 Désaxer, T01 Fendre, R01. | Employer une tombe comme surface de collision puis les débris pour atteindre le tireur. | Terrain ouvert et cibles ancrées ; mutation Dénuder conserve une réponse aux gardes. |
| **4. Le porte-rempart** | Xiphos, T04 Rempart, T13 Répercussion, R02. | Absorber la grosse frappe annoncée, convertir la réserve en ligne de dégâts au bon tour. | Petites salves et attaques par plusieurs côtés ; passer en Salve sacrifie l’avantage contre le gros impact. |
| **5. L’écaille patiente** | Xiphos Myrmidon, T04 Salve, T07 Moisson, R09. | Laisser trois archers consommer la défense puis engager avec les éclats et une frappe double. | Mage à forte frappe unique ; préparer un déplacement ou une protection éphémère. |
| **6. Le contre-duelliste** | Lance Veilleur, T04 Riposte, T08 Attirer, R10. | Inviter un attaquant dans une ligne, riposter puis exploiter le tour de PA préparé. | Ennemis qui refusent le contact ; échanger Attirer contre Tir du Pélion. |
| **7. Le chasseur de dos** | Arc Chasse longue, T03 Croiser, T12 Retour, R04. | Préparer un tir à une position, se retirer et croiser une nouvelle ligne de tir. | Passage étroit empêchant le changement de côté ; prendre Perce-brume pour jouer l’information plutôt que le flanc. |
| **8. Le semeur de fers** | Javelots Hérisson, T06, T09 Plaie, R01. | Planter ses munitions dans une trajectoire puis y tracter l’ennemi marqué. | Munitions loin d’Achille et combat mobile ; réserver un Fil du retour ou investir T21. |
| **9. Le gardien des rives** | Disque Double rive, T05 Relais, T21 Détour, R03. | Un lancer atteint l’avant ; un retour préparé depuis l’autre rive atteint le soutien. | Relais détruit ou retour bloqué ; prévoir une action de récupération qui renonce aux dégâts. |
| **10. Le moissonneur circulaire** | Disque Retour fatal, T07 Balayer, T06 Désaxer, R16 tardive. | Placer trois cibles sur les segments du retour et accepter de laisser l’arme loin de soi. | Cible unique et aucune case de relais ; revenir à une attaque directe et conserver la couronne pour une autre branche. |
| **11. Le geôlier** | Chaîne Geôlier, T19 Lien, T05 Obstacle, R01. | Enfermer une menace dans un petit espace tout en traitant l’autre. | Incantation sans besoin de déplacement ; prendre Contretemps au lieu d’un second verrou spatial. |
| **12. Le bourreau des angles** | Chaîne Pendule, T09 Plaie, T06 Désaxer, R04. | Faire saigner par déplacements latéraux sans se rapprocher de la cible. | Immunité annoncée aux déplacements ; basculer Plaie vers Cicatrice à une halte. |
| **13. Le sanguin prudent** | Xiphos, T09 Cicatrice, T10 Prévenir, R05. | Investir quelques PV pour ouvrir la défense, récupérer une partie par dégâts réels avant épuisement de la coupe. | Réserve de soin finie et gros coup soudain ; le dernier onguent occupe la ceinture à la place d’un amplificateur. |
| **14. Le débiteur vivant** | Marteau, T20 Ferveur, T01 Achever, R14 tardive. | Avancer le prix d’un gros coup pour supprimer immédiatement la principale source de dégâts. | La dette arrive même si la cible survit ; exiger un calcul de seuil visible et un plan de paiement. |
| **15. Le chirurgien d’airain** | Lance, T09 Cicatrice, T01 Armure ouverte, R01. | Alterner ouverture et consommation de faille pour rendre une brute vulnérable à une frappe décisive. | Trop lent contre une horde fragile ; remplacer une préparation par Fauchage. |
| **16. Le porteur de braises** | Hampe Cendrier, T11 Four, T18 Flux, R06. | Préparer une case dangereuse, l’amener sous l’ennemi et récupérer la chaleur si le piège échoue. | Cibles qui se dispersent et absence de fenêtre de préparation ; Arc sec ou Tir couvre ce défaut. |
| **17. Le forgeron de scories** | Marteau Fissure, T11 Tison porté, T16 Scorie, R01. | Brûler, convertir en faiblesse d’armure, puis briser un ennemi auparavant trop résistant. | Trois préparations coûtent du tempo ; ne pas appliquer le cycle complet aux petits ennemis. |
| **18. Le contre-incendiaire** | Hampe Veine, T18 Contre-courant, T15 Détourner, R12 tardive. | Retourner une zone hostile contre sa propre formation, puis choisir où elle doit finir. | Ennemi à dégâts directs sans terrain ; garder Tison et une zone personnelle, qui restent opérationnels. |
| **19. Le conducteur** | Hampe, T17 Circuit, T18 Dérive, R06 ou R08 au départ. | Mouiller plusieurs cibles sur la barque puis construire un arc à trois impacts. | Terrain sec ; emporter une Écharde d’ambre ou muter en Arc sec, sans imposer que chaque salle offre de l’eau. |
| **20. Le briseur d’incantations** | Javelots Lest, T15 Rompre, T10 Rejeter, R08. | Faire payer une canalisation, éliminer le soutien affaibli et réemployer ses munitions. | Salle de tireurs physiques sans canalisation ; les dégâts d’arme et Clouer deviennent la réponse de repli. |
| **21. Le passe-muraille de brume** | Arc Perce-brume, T12 Voile, T05 Relais, R11 tardive. | Créer son propre écran, tirer depuis un point extérieur, puis abandonner ce point. | Ennemi de zone qui n’a pas besoin de le voir ; préserver une sortie et ne pas confondre brume et invulnérabilité. |
| **22. Le conservateur des morts** | Lance ou chaîne, T24 Mémoire, T13 Plaque, R13 tardive. | Transformer une première élimination en abri, conserver un vestige pour alimenter le prochain changement de cible. | Début de combat sans cadavre, boss seul ; prendre une technique directe et ne jamais exiger un vestige pour démarrer. |
| **23. Le riche de passage** | Arc ou marteau, T23 Avance, T14 Réserve, R07. | Dépenser vingt oboles pour dépasser un seuil de mort que le kit normal n’atteignait pas. | Les victoires n’assurent pas le remboursement ; la carte doit présenter une branche lucrative et une échappatoire sans dépense. |
| **24. Le survivant des pactes** | Xiphos, T10 Prévenir, T12 Retour, R15 tardive ; ceinture offensive. | Accepter un élite risqué parce qu’un contrat coûteux protège d’un unique coup fatal. | Après activation, or perdu et 25 PV : il faut encore finir le combat. Le contrat permet un pari, il ne remplace pas une défense. |

Une même découverte doit pouvoir changer plusieurs constructions. Fil d’orme intéresse les javelots, le disque et les lanceurs depuis un point. L’Urne intéresse le rempart mais aussi un mage qui veut convertir une garde magique. Le Sceau fendu intéresse un tireur autant qu’un lanceur de braises. Cette transversalité évite de multiplier des objets qui ne servent qu’à une recette nommée.

## 8. Dix combinaisons capables de dépasser le cadre ordinaire

Les coefficients sont des exemples avant défenses ; les grands tours demandent une préparation antérieure ou une ressource finie. Une combinaison peut être extraordinairement forte dans sa salle sans avoir un remboursement gratuit sur chaque ennemi.

### 1 — Le retour aux trois rives

Disque, deux points de T05 Appui / Deux rives, R16 et T21 Détour. La couronne autorise le parcours par deux relais ; elle remplace la limite d’un détour de la technique. Un dégât de référence de 40 donne 40 + 26 + 16,8, soit 82,8 sur trois cibles distinctes. Les deux points coûtent chacun deux PA à poser ; le lancer et le retour demandent cinq PA supplémentaires selon l’action choisie. C’est un montage sur plusieurs tours. Les points sont consommés et l’arme finit au dernier : le prochain tour est affaibli si Achille n’a pas prévu sa récupération.

### 2 — La forteresse projectile

T04 Rempart, R02, T13. Plusieurs blocages remplissent une urne qui ne protège pas directement. Répercussion dépense 30 bronze pour 45 dégâts sur une ligne de trois cases, donc 135 dégâts cumulés si trois ennemis sont réellement alignés. Le coût est de trois PA et de 30 réserve, à laquelle s’ajoutent les gardes des tours précédents. La ligne ne remplit pas l’urne. Contre une cible isolée qui refuse de frapper la garde, le montage s’alimente mal.

### 3 — La nécropole hérissée

Javelots Hérisson, T09 Plaie / Écartèlement, T06 Désaxer. Un ennemi déplacé sur deux piques reçoit deux petits impacts et les dégâts de déplacement. Avec deux piques à huit dégâts proposés et deux cases à trois, l’événement représente 22 dégâts avant les défenses applicables à chaque composante. Les piques disparaissent et les munitions doivent être récupérées. Le déplacement ne recrée pas les piques ; un ennemi ancré réclame une autre réponse.

### 4 — La fournaise volée

T18 et R12 transforment une zone hostile en danger neutre. Le mage ennemi peut alors être blessé par sa propre puissance. Le point fort est de retourner une menace calibrée pour Achille contre plusieurs ennemis, sans augmenter les statistiques d’Achille. La zone garde sa durée et peut encore toucher Achille ; le joueur ne récolte ni soin, ni monnaie, ni tison par ces dégâts. T15 Détourner et Flux ne doivent pas déplacer deux fois la même résolution au-delà des positions admissibles.

### 5 — Le coup acheté trop cher

T20 Ferveur, T23 Avance et une Masse à quatre PA consomment six PA, 18 PV et vingt oboles. Avec P = 30, la Masse vaut 48 avant défense ; Ferveur ajoute 30 à l’impact principal. La répétition du Péage reprend la base admissible de 48 à 80 %, soit 38,4, sans recopier l’Offrande : total 116,4 avant défenses. Le joueur peut éliminer une menace majeure, mais perd de la vie, un achat futur et tout son tour. L’ordre des bonus doit être affiché ; une copie qui réapplique Ferveur donnerait un résultat différent et n’est pas proposée ici.

### 6 — La frappe depuis l’absence

T12 Retour / Geste laissé, T05 Relais, R11. Achille laisse un point visible, rejoint un refuge, puis tire depuis l’ancien emplacement à travers sa propre brume. Le gain vient d’un angle impossible depuis son corps. Le point utilisé est consommé, donc la retraite préparée disparaît. Il n’existe pas de double sécurité gratuite ; une zone annoncée sur le refuge reste un problème.

### 7 — Le sang à terme

R14, T20 et R05 permettent de payer après avoir frappé. Une offrande de 12 PV décalée peut être partiellement couverte par 60 PV de dégâts physiques réels donnant neuf de soin, s’il reste neuf dans la réserve de la coupe et de la santé manquante à soigner. Le coût net peut alors tomber à trois PV, mais jamais être supposé nul : à pleine santé le soin est perdu, et les trois derniers points restent dus. La réserve de 30 empêche de répéter ce financement indéfiniment.

### 8 — Le champ de tombeaux

T24 Fosse, T06 Ramener, T05 Obstacle. Achille organise des vestiges piégés puis dirige les ennemis vers eux. Une mort produit une ressource de terrain qui prépare la suivante. Chaque cadavre fournit un seul vestige, chaque piège se détruit après usage et sa victime réanimée n’en produit pas un autre. Le premier ennemi doit être tué avec les outils ordinaires. Aucun personnage supplémentaire n’est créé.

### 9 — L’incendie froid

T11 Sillon, R06, T18 et T16 Reprise. Le joueur place une zone, la déplace pour toucher plusieurs cibles puis la consomme pour préparer un nouveau feu à coût réduit. La réduction de deux PA a un plancher d’un PA et ne se cumule pas avec elle-même. Consommer la brûlure retire ses dégâts futurs : accélérer son prochain sort sacrifie une partie du rendement déjà posé. Plusieurs étapes restent nécessaires, même avec une grande mobilité de zone.

### 10 — La parole et la dernière frappe

R10, T08 Témoin et une arme à quatre PA. Après avoir tenu une position et accepté une attaque marquée, Achille peut commencer un tour à neuf PA : six de base, deux de Parole et un de Témoin. Il peut alors payer deux grandes frappes et un Défi. Le tour exceptionnel est annoncé et préparé ; Parole est consommée pour le combat, Témoin ne se multiplie pas sur les effets secondaires, et prendre le coup nécessaire a un coût réel.

## 9. Trois garde-fous qui doivent rester compréhensibles

**La matière existe.** Un disque, un javelot, un vestige et une lance plantée ont un emplacement et un propriétaire. Leur duplication demande une règle explicite. Revenir par trois points n’autorise pas trois copies de l’arme.

**Un remboursement nomme son origine.** Les dégâts effectivement retirés, les premières morts admissibles ou les attaques ennemies réellement absorbées sont des événements vérifiables. L’interface indique les réserves épuisées. Un effet ne promet pas « à chaque dégât » si seule l’attaque payée compte.

**L’excès conserve un coût visible.** Une réserve peut être pleine, un grand tour peut tuer trois ennemis et une relique peut sauver une run. Le coût porte sur le positionnement préparé, la matière consommée, les PV ou les oboles. Un plafond arbitraire ajouté après chaque interaction doit rester le dernier recours : mieux vaut une boucle naturellement finie par les ressources qui la rendent possible.

## 10. Les décisions de conception encore ouvertes

La garde directionnelle doit être jouée sur la grille pour mesurer ses angles morts. Les objets physiques demandent des règles lisibles de case occupée et de récupération. La brume doit utiliser une convention unique pour les tirs entrants, sortants et traversants. La neutralisation d’un danger doit identifier précisément les zones admissibles. Les six arbres détaillés réclament leurs essais avant l’écriture des cent huit aboutissements encore absents des autres arbres.

Les vingt-quatre constructions n’ont pas toutes besoin de survivre au prototype. Celles qui produisent les mêmes choix peuvent fusionner. Celles qui transforment réellement une route, une cible prioritaire ou une utilisation de ceinture méritent davantage de contenu. Le critère de variété reste la manière de jouer et de préparer la suite, pas le nombre de noms dans ce catalogue.
