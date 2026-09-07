# Catabase : doctrines, découvertes et équipement

## Point de départ commun

Achille entre dans le premier combat avec les quatre Resources canoniques : Frappe du Péléide, Percée fulgurante, Tir du Pélion, Garde d'airain. Aucun point de maîtrise, carte, retrait de sort ou achat d'arbre ne peut modifier ce départ. Les statistiques initiales et la progression du Champion sont celles de Catabase.

La première victoire accorde deux points. Le joueur peut investir dans une amélioration de son kit actuel, ouvrir une doctrine, puis apprendre une technique qui remplacera librement l'un des quatre sorts. La collection et les emplacements équipés restent séparés. Une nouvelle forme remplace sa famille si elle est équipée ; l'ancienne forme reste disponible, mais deux formes d'une même famille ne peuvent pas occuper deux emplacements.

## Trois doctrines permanentes

| Doctrine et racine (1 point) | Premier axe | Second axe |
| --- | --- | --- |
| Colère du Péléide : Frappe applique -15 armure après l'impact, jusqu'à la prochaine activation de sa cible | Briseur : attraction, regroupement, fauchage, contrôle | Sang : sacrifices non létaux, burst, soin sur PV réellement retirés |
| Leçon de Chiron : Tir gagne 20 % dégâts à au moins quatre cases | Chasseur : portée, ligne, marque à charges | Danseur : déplacement, esquive temporaire, passage derrière la cible |
| Égide d'Éaque : Garde devient 6 % PV max + 30 % Prouesse, avec +10 résistance magique temporaire | Airain : poussées, collision, armure et bouclier | Endurance : vitalité, réserve finie de soin, purification de pénalités PA/PM |

La racine est le prérequis commun des deux axes. Une carte peut enseigner une technique martiale sans cette racine, ce qui permet une entrée hybride par une récompense. Son amélioration reste soumise aux autres prérequis, coûts et profondeurs.

Chaque axe contient deux apprentissages à 1 point, deux liaisons de statistiques à 1 point, une mutation à 2 points (dès II), une signature à 2 points (dès VI), et une légende à 2 points (dès XII, exige mutation et signature). Les formes changent les coûts, angles, zones et fonctions : contrôle contre dégâts, mobilité contre esquive, PV contre burst, ligne contre poussée. Elles ne remplacent pas toutes le même comportement par davantage de dégâts.

## Branches découvertes

- **Affinités élémentaires**, découverte accessible à partir de IV : Feu pour investir dans le terrain, Givre pour fermer une route, Foudre pour exploiter un alignement. Cette branche reste scellée sans découverte effective ; une carte ne contourne pas cet accès.
- **Serments du Styx**, découverte accessible à partir de VIII : deux serments mutuellement exclusifs. Rempart dépense 5 % PV max pour un bouclier de 18 % PV max ; Brasier dépense 8 % PV max pour une croix de dégâts Feu fondée sur Prouesse et PV max. Deux usages par combat, sacrifice non létal. Choisir une protection ou une offensive engage cette branche pour la run, sauf correction unique de son dernier achat.

Les droits de découverte, leurs minima de profondeur, les prérequis et l'exclusion des serments sont validés avant de restaurer une sauvegarde. La session enregistre séparément la visite au sanctuaire qui a accordé ces droits.

## Budget et emplacements

La run distribue 24 points de maîtrise : deux aux profondeurs I, VI, X, XIV et XVIII ; un aux autres destinations résolues jusqu'à XIX ; aucun point inutilisable après le combat final. Un axe complet coûte 10 points plus sa racine commune. Un spécialiste peut compléter les deux axes d'une doctrine pour 21 points ; un hybride doit financer plusieurs racines et renoncer à certaines légendes. Le budget favorise plusieurs décisions pendant toute la run.

Le cinquième emplacement s'ouvre au niveau de Champion 5. Au jalon XII, le joueur choisit entre un sixième emplacement et Tempête du Péléide, une forme en croix de Frappe. Il dispose d'une correction de son dernier achat de maîtrise ; les cartes et découvertes ne sont pas remboursées ni effacées par cette correction.

## Douze équipements et leurs décisions

| Objet | Emplacement | Décision de build |
| --- | --- | --- |
| Levier des Myrmidons | Arme | +1 Force ; +25 % dégâts physiques sur une cible déplacée ou entrée en collision dans l'activation. Crochet prépare Frappe. |
| Lame du talon | Arme | +30 % dégâts à 40 % PV ou moins, -12 armure. Un sacrifice peut ouvrir la fenêtre avant son propre impact. |
| Javeline des longues vues | Arme | +1 portée et +30 % dégâts à quatre cases sur les familles Tir, Rupture, Marque ; distance minimale relevée à trois. |
| Xiphos des deux appuis | Arme | +25 % dégâts physiques après deux cases effectivement parcourues, +2 initiative. Feinte prépare une attaque. |
| Masse du rempart | Arme | Heurt et ses formes ajoutent 10 % de l'armure effective, plafond huit dégâts par cible ; +15 armure, -2 initiative. Posture devient préparation offensive. |
| Fer de la fournaise | Arme | +30 % dégâts magiques élémentaires directs, -15 % physiques. Le terrain ne reçoit pas ce multiplicateur. |
| Cuirasse d'Éaque | Armure | +30 armure et +25 % boucliers de sorts, -1 PM. |
| Lin du survivant | Armure | +15 % PV max sans soin ; +25 % au soin réel de Second souffle et ses formes, avec consommation de la réserve commune. |
| Sandales du détour | Armure | +1 PM, +8 points d'esquive, -10 armure. La mobilité coûte de la tenue au contact. |
| Sceau de la dernière chasse | Accessoire | +25 % dégâts contre une cible à 30 % PV ou moins ; -10 % PV max. |
| Prisme de Chiron | Accessoire | +1 portée aux sorts magiques élémentaires qui possèdent déjà une portée ; -8 résistance magique. |
| Agrafe du serment | Accessoire | +20 % dégâts tant qu'un bouclier est encore actif ; exige de préserver sa protection jusqu'à l'attaque. |

Les objets passent par EquipmentService, ses sources de statistiques et le pipeline réel de SpellCaster. Les retirer supprime leurs effets. Aucun objet ne crée de tour supplémentaire, de remboursement de PA ou de boucle de soin. Le soin commun reste plafonné par les PV max à l'entrée du combat ; il ne se recharge pas lors d'un changement d'équipement.

## Validation et limites

La scène `tests/expedition/build_state_test.tscn` vérifie le départ canonique, les droits de découverte, les dépenses, les familles exclusives, les sauvegardes atomiques, les douze équipements et des casts réels avec déplacement, dégâts et soin. Les assertions d'équipement passent par l'inventaire et EquipmentService, puis par SpellCaster ; elles ne simulent pas une activation d'objet à part.

Les chiffres constituent une première proposition jouable. Les objets ont des bonus conditionnels et des contreparties lisibles ; leur fréquence d'obtention, leur prix et leur combinaison avec les rencontres doivent encore être observés en run complète. Les noms et descriptions du catalogue runtime font foi si un équilibrage ultérieur diverge de ce document.
