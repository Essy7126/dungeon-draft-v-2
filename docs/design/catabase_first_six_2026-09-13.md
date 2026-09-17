# Six constructions jouables — 13 septembre 2026

Ce lot implémente les six moteurs prioritaires du dossier du 12 septembre. Le catalogue de vingt-quatre constructions reste une réserve de conception. Les actions passent par le combat sur grille, les statistiques, les statuts, les surfaces, l'inventaire et les sauvegardes de production.

## Jouer

Nouvelle partie → Achille → cinématique → Seuil des Ombres → franchir la porte. La préparation s'ouvre avant le premier combat commun. Après celui-ci, terminer les fenêtres de progression et de butin, puis revenir au Seuil pour rejoindre physiquement le puits, la porte ou la barque. Une sauvegarde plus ancienne conserve son départ historique ; commencer une nouvelle run pour choisir une préparation.

Choisir une arme (deux actions), une protection, deux techniques libres parmi treize, une relique permanente et une éphémère. Les six boutons sont des préparations modifiables. Départ : 110 PV, 6 PA, 3 PM, 18 Prouesse, 60 oboles ; la tenue légère ajoute 1 PM.

| Construction | Décision de combat | Limite / coût |
|---|---|---|
| Marteau funéraire | Déplacer puis exploiter le Clou ; fissurer une cible blindée | Contact ; Masse 4 PA et Ébranler 2 PA |
| Xiphos et bouclier | Absorber une salve pour charger l'Urne ; choisir quand dépenser le bronze | Trois impacts réduits de 6, expiration au prochain tour ; réserve 40, Répercussion dépense au plus 30 |
| Disque de bronze | Placer le disque, changer d'angle, traverser plusieurs ennemis au retour | Un seul disque ; un mur bloque le rappel ; 3 PA au lancer, 2 au retour |
| Hampe des braises | Poser une braise puis déplacer la menace avec Flux et les déplacements adverses | Durée conservée ; terrain hostile aux alliés aussi ; Mèche déplace de deux cases |
| Lame des cicatrices | Maintenir une fêlure, puis Récolte ; récupérer les PV effectivement retirés | Pas de cumul de fêlures ; Coupe : 15 % des dégâts physiques directs, réserve 30 PV par combat |
| Arc du tribut | Payer pour une élimination urgente, ou garder les oboles pour les haltes | Tir impossible au contact ; Péage 1 PA + 12 oboles pour +50 % sur un seul impact |

Les protections changent le profil de risque : Airain +55 armure, Sceau +55 résistance magique, Lin gravé +22 aux deux, tenue légère +10 aux deux et +1 PM. Aucune immunité de route. Sceau protecteur et Sel blanc peuvent retirer les pertes de PA/PM et les pénalités de statistiques.

## Progression et recomposition

Chaque moteur a deux mutations exclusives à partir du jalon II (2 points), puis son accomplissement au jalon VIII (4 points). Les racines choisies au départ remplissent leurs prérequis sans rachat. Les nouvelles racines se trouvent dans les branches existantes ; la Hampe ouvre ses propres éléments dès le départ. Le budget existant de 24 points, le cinquième emplacement au niveau 5 et le choix du jalon XII sont conservés.

Les deux premiers emplacements suivent l'arme équipée. Changer d'arme entre les destinations apprend ses deux actions et les équipe ; les techniques libres restent. Les mutations déjà connues restent dans le grimoire. Les six armes historiques de Catabase sont raccordées aux familles correspondantes, avec leur bonus d'équipement existant. Les armes, protections et reliques entrent dans les offres de récompense ; les reliques déjà possédées ne sont pas reproposées par l'interface.

Les reliques permanentes utilisent l'activation du sac déjà existante. Ce lot ne crée pas encore un écran de deux emplacements de reliques équipées, ni les aspects d'armes et éveils du grand catalogue. Les éphémères sont activables dans l'onglet Objets : 1 PA, une charge, puis disparition. Onguent soigne 24 PV, Souffle donne 2 PM, Plaque donne 24 garde jusqu'au prochain tour, Sel purifie les pénalités. Un usage sans effet ne dépense rien.

## Règles de sûreté du gameplay

- Garde de salve : plafond par impact et nombre d'impacts sérialisés ; les anciens boucliers gardent leur absorption habituelle.
- Urne : seule l'absorption de garde causée par un adversaire charge la réserve ; pas de recharge par sa propre Répercussion.
- Disque : origine visible au sol ; aperçu et résolution du retour partagent le même tracé.
- Flux : vérifie le propriétaire, l'obstacle et la destination avant de payer ; conserve la durée restante, déplace une seule surface.
- Coupe : aucun soin calculé sur les dégâts excédentaires, les boucliers ou les effets secondaires ; budget fini.
- Péage : engagement de la dépense une seule fois par action ; bonus sur un impact, pas de copie de sort ni de remboursement. Obole fendue : au plus 20 oboles par combat.

Les défis existants continuent d'agir sur le combat suivant. Le lot n'ajoute aucune pioche, aucun nouveau personnage et aucun moteur de combat séparé.

## Validation reproductible

Dernière validation du lot : **12 tests, 925 assertions, tous réussis**, import Godot inclus. La série automatisée de 78 combats et le parcours visuel préparation → défi → lancer/rappel sont également terminés. La suite globale du dépôt demeure non validée : erreurs de tests Studio/animations/inventaire et dépassement de son délai maximal.

- `./dev.ps1 test test/unit/test_catabase_first_six.gd` : préparation, compatibilité des sauvegardes, six parcours de vingt jalons avec victoires injectées, achats exclusifs, pivots d'armes, sorts et reliques dans le moteur réel, contrôles de l'interface.
- Ouvrir `tools/catabase_monster_validation/first_six_playtest.tscn` : 78 combats indépendants sur les treize salles I–VI du seed 2401, six préparations, grilles/formations/IA/SpellCaster réels. Rapport dans `artifacts/dev/early_run_playtest/first_six/report.json`. Chaque salle démarre à pleine vie ; le pilote est une politique heuristique limitée, sans objets manuels. Ce n'est pas une mesure de survie continue ni une preuve d'équilibrage humain.
- Ouvrir `tools/catabase_monster_validation/first_six_capture.tscn` : préparation et confirmation réelles, déploiement, défi, lancer puis retour via le HUD. Captures dans `artifacts/dev/first_six_capture/`. Instance et sauvegarde de laboratoire isolées.

Les rapports datés et limites de la validation finale sont recensés dans `docs/ai/theorycraft_first_six_work.md`. Les statistiques ennemies ne sont pas retouchées sur la seule base du pilote automatique : certains échecs viennent de ses décisions de déplacement. L'équilibrage humain de la survie entre les combats reste une étape de playtest.
