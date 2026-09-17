# Catabase r6 — audit tactique ciblé des rencontres

Statut : `WORKTREE_CANDIDATE`, non commité. Vérification du 14 septembre 2026.
Base de départ : `main@055584c37f60d99b2f87bdbb4d670895bf8ef2b2` ; le worktree contient les changements concurrents de l'intégration r6.

Cette note complète, sans la remplacer, `CATABASE_R6_AUDIT_RUNS_2026-09-14.md`.
Elle porte sur l'identité des profils V1, la géométrie du Léthé II et le raccord
des avertissements d'attaques retardées. Les résultats d'un bot sont des traces
d'exécution, pas une preuve de difficulté ou de durée humaine.

## Verdict tactique provisoire

**OBSERVÉ.** Les douze combats ont une progression lisible sur le papier :
approche simple, fronts multiples, soutien, combinaison marque/meute,
Chaîne/Sentence, convoi, feu/poussée, formation protégée, puis boss à deux
formes. Huit profils portent une question nettement distincte. Les recouvrements
les plus faibles sont Styx III/Styx V, dont les rôles sont identiques, puis
XIII/XVII, qui réutilisent tous deux feu + déplacement forcé.

**RECOMMANDATION.** Ne pas ajouter de famille, d'ennemi ou de budget. Les écarts
doivent d'abord être travaillés avec la carte, l'ordre d'apparition et au plus un
échange de rôle existant. La matrice headless sert à repérer les cas ; seule une
session jouée permet de confirmer que la menace et ses réponses sont comprises.

| Profondeur | Contrat tactique réellement encodé | Ruptures disponibles et point de vigilance |
| --- | --- | --- |
| I | Un tireur fragile apprend portée, ligne de vue et attaque différée. | Sortir de portée ou rompre la ligne avant la prochaine activation. Le télégraphe de ce sort possède un libellé explicite. |
| II | Premier choix entre contact, tireur et, selon la route, poursuite ou magie. | Couvert, concentration sur la cible fragile, choix du côté d'approche. Airain n'a que deux corps : sa pression doit être relue séparément des variantes à trois. |
| III | Deux poursuivants ou deux brutes fixent le front pendant qu'un tireur/une Lamie exploite l'angle. | Goulet, séparation, suppression de l'appui distant. Styx répète exactement `archer + molosse + molosse` en V : identité insuffisante si la carte ne change pas réellement la décision. |
| V | Mélange de familles avant l'élite : feu fragile en Airain, tir en Styx, contrôle Léthé. | Atteindre l'appui puis gérer le corps à corps. Le profil Styx ne se distingue de III que par profondeur/carte, pas par rôles. |
| VI | Première élite à quatre fonctions : brute, tireur, poursuivant, officiant. | Tuer/intercepter l'officiant ou dépasser ses deux soins ; utiliser couvert et goulets contre les trois menaces. Aucun gros dégât différé : la lisibilité repose surtout sur les rôles et l'ordre de cible. |
| VIII | Le Conducteur marque pour la meute. | Éliminer le Conducteur dissipe la marque liée, ou empêcher le Molosse d'atteindre la cible. La synergie est maximale en Styx avec deux Molosses et plus légère dans les deux autres routes. |
| X | Le Rabatteur prépare le contact de l'Exécuteur : Chaîne, Fracture, Sentence. | Couper la ligne de Chaîne ; quitter le contact avant Sentence ; contrôler ou tuer l'un des deux. C'est la combinaison la plus clairement interrompable. |
| XII | Le Collecteur dépend de deux Porteurs ; un lourd met la pression. | Tuer/éloigner les Porteurs coupe la condition de soin à deux cases ; éliminer le Collecteur ou dépasser ses trois soins. Les quatre corps expliquent une partie des tours de poursuite tardifs. |
| XIII | Fournaise annoncée + deux pousseurs, avec une Lamie à la place d'un pousseur en Léthé. | Briser la ligne/sortir des 2–6 cases avant Fournaise, supprimer un pousseur, garder une sortie hors du feu. La variante Léthé réduit la poussée et ajoute le contrôle de passage. |
| XV | Égide, tir préparé à longue portée, poussée et protection distante. | Approcher le Guetteur dans sa zone morte, séparer les protecteurs ou supprimer le soutien. Profil riche mais chargé : le pic doit rester lisible avant d'être jugé sur ses dégâts. |
| XVII | Dernière synthèse feu/poussée/givre ; l'Artilleur allonge la Fournaise. | Rompre la ligne, fermer la distance ou séparer Tisseuse et Déplaceur. Proche de XIII ; Airain et Léthé partagent le même roster, seule la formation change (`double_line` contre `split`). |
| XX | Pâris, deux Spectres, puis restauration complète et carapace de 30 à la forme infernale. | Ordre de cible, maîtrise des surfaces et du placement. Les attaques de Pâris sont immédiates : l'intérêt doit venir de la phase et du terrain, pas d'un télégraphe inexistant ou d'un enrage global. |

## Léthé II : géométrie conservée

**OBSERVÉ.** La salle est `data/rooms/catabase_routes/route_f51a86b714b9/room.tres`
(`Les traces du Léthé`). Dans le probe corrigé graine 2401, le déploiement
choisi est `(6,11)` et les ennemis apparaissent en `(3,9)` (archer), `(2,10)`
(brute) et `(12,10)` (Lamie). Les distances de chemin depuis les quatre cases
de déploiement sont :

| Départ | Archer | Brute | Lamie |
| --- | ---: | ---: | ---: |
| `(6,11)` | 7 | 7 | 7 |
| `(7,11)` | 8 | 8 | 6 |
| `(6,12)` | 6 | 6 | 8 |
| `(7,12)` | 7 | 7 | 7 |

Depuis `(6,11)`, une case adjacente à l'archer est à 6 PM : Achille à 3 PM
consacre une activation à l'approche, puis peut engager à la suivante. Les murs
centraux `(7,4)` à `(7,8)` sont à la fois bloquants dans la grille et matérialisés
par des colonnes brisées. Les obstacles bas `(4,10)`, `(5,10)`, `(9,10)` et
`(10,10)` ont eux aussi des décors associés et ne bloquent ni ligne de vue ni
projectiles. Le polygone d'occlusion de premier plan est vide.

**VERDICT.** Aucun mur invisible ni trajet impossible n'explique l'ancien échec.
Le cas corrigé gagne II en 7 tours, avec trois mouvements de détour et zéro tour
inactif. La poursuite est une contrainte tactique réelle et la géométrie doit être
conservée ; ne pas réduire les dégâts pour compenser un pilote qui refusait un
détour temporairement moins direct.

Preuve :
`artifacts/catabase_run_balance_validation/after_path_fallback_2401_normal_marteau/report.json`.

## Élites X : pourquoi le probe reçoit 0 PV

**OBSERVÉ.** Le Marteau entre en X à 234/476 PV et gagne en quatre tours.
L'Exécuteur (194 PV, Prouesse 42) lance une Sentence ; le Rabatteur (194 PV,
Prouesse 35) lance une Fracture. Le rapport contient une préparation bloquée,
un impact brut connu de 30, aucun impact résolu et aucun PV perdu. Achille lance
Feinte une fois, quatre coups de Masse et une poussée.

**INFÉRENCE FORTE.** La Sentence a été annulée lors de sa résolution parce que
la cible n'était plus au contact. La Fracture de 30 a été esquivée pendant la
fenêtre de +25 points de Feinte : `Unit._apply_damage_result()` émet l'événement
d'esquive puis retourne avant `hit_resolved`, ce qui correspond exactement à
`known_raw_hit_count=1` mais `resolved_hit_count=0`. Le duo n'est donc pas resté
inactif et aucun blocage de ligne de vue n'est démontré ; le probe a exécuté les
deux réponses prévues par le profil.

**INCONNU.** Un seul jet déterministe ne prouve pas que X est assez exigeant.
Le cumul burst Marteau + déplacement + esquive peut neutraliser le duo ; il faut
comparer les douze cas et un joueur humain avant de modifier sa vie ou ses dégâts.

## P1 découvert et corrigé : affichage des attaques retardées

**DIVERGENCE OBSERVÉE AVANT CORRECTION.** `SpellCaster` créait bien l'état en
attente et émettait `ability_telegraphed`. `TacticalTelegraphLayer` savait dessiner
ligne, cible, croix et libellé, mais aucune scène ni `battle.gd` de production ne
l'instanciait. Les attaques étaient annulables par les règles sans avertissement
visuel garanti au joueur.

**CORRECTION WORKTREE.** `battle/battle.gd` crée maintenant une unique couche
`TacticalTelegraphs`, enfant de la vraie `grid_view` afin d'hériter des
transformations peintes/isométriques, avec un ordre Z au-dessus du combat et sous
les `CanvasLayer` du HUD. La couche est liée au `GridData` du combat, ignore les
événements d'une autre bataille pendant une transition et se déconnecte dès
`_begin_battle_shutdown()`. `battle/tactical_telegraph_layer.gd` expose un
instantané borné pour les tests et nettoie unités, signaux et entrées à la
fermeture.

Le libellé est séparé au premier tiret long en deux lignes centrées. Sa largeur
est mesurée au lieu d'être bornée à 108 unités ; taille, marge, offset et contour
sont compensés par la transformation canvas afin de rester constants à l'écran.
La surveillance de cette échelle n'est active que lorsqu'une menace est visible
et ne demande un nouveau dessin que si elle change.

**TEST CIBLÉ INITIAL EXÉCUTÉ.** `test/unit/test_catabase_tactical_telegraph_integration.gd` :
PASS, 1 test / 17 assertions. Il vérifie le raccord de la vraie classe Battle,
le parent transformé, le suivi d'une cible déplacée, le filtrage d'un autre
`GridData`, l'effacement et l'absence de nouvel événement après fermeture.
Rapport :
`artifacts/dev/20260914-163614-test-test_unit_test_catabase_tactical_telegraph_integration.gd-59e537e4/gut-strict-report.json`.

**REJEU OBSERVÉ.** Les trois tests passent dans le lot complet
`artifacts/dev/20260914-171645-test-catabase-22f1e9c3/gut-strict-report.json`.
Deux contrats supplémentaires vérifient
désormais la séparation de `Trait d’ombre — brisez la ligne de vue`, le fallback
sur une ligne, la compensation d'un parent à l'échelle 0,5 et l'activation de la
surveillance seulement entre affichage et effacement. Ce résultat du lot complet
ne doit pas être confondu avec le PASS ciblé initial ci-dessus.

**VALIDATION GPU OBSERVÉE.** Le cas réel Catabase I a préparé Trait d'ombre dans
la vraie arène peinte. Après correction, le harnais termine à 127/127 assertions,
produit six PNG et ne rapporte aucune erreur moteur :
`artifacts/catabase_run_balance_validation/r6_ui_telegraph_screen_constant_20260914_1810/`.
L'inspection visuelle à 1280×720 et 1920×1080 confirme une ligne et une croix
alignées, ainsi que les deux lignes complètes et lisibles à taille écran stable.
La surveillance d'un changement de zoom pendant qu'un avertissement reste actif
a été ajoutée après ces captures : son activation et son arrêt sont couverts
par le contrat de code rejoué, pas par cette preuve GPU statique.

**LIMITE P2.** Le Rejeton de I et la Fournaise ont des libellés de contre-jeu
explicites ; Sentence et Visée utilisent encore le texte générique `Prochaine
activation`. Étendre ces formulations est utile pour la compréhension de la
menace, mais ne justifie aucune retouche des budgets ennemis.
