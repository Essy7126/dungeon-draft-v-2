# Paris — règles de combat

Paris conserve l'identité de **L’Ombre de Paris** (`catabase_shadow_paris`) pour devenir le boss de la cinquième et dernière salle de Catabase, au Temple du Serment Noir. Il n’apparaît pas dans les quatre salles précédentes. Deux spectres à l’épée, déjà présents dans cette rencontre, protègent son approche ; aucun adversaire ne reçoit de PV supplémentaires. La troisième salle accueille désormais le Champion et un spectre, pour 179 PV au total, suivis des 185 PV de la quatrième salle et des 248 PV du groupe final (hors carapace conditionnelle). Il commence en archer spectral : 120 PV, 4 PA, 3 PM, initiative 9, sans attaque de base gratuite. Son arc privilégie la distance et son kit emploie les mêmes surfaces, statuts, lignes de vue et déplacements que les autres combattants.

| Sort | PA | Portée | Effet réel | Retour disponible |
|---|---:|---:|---|---|
| Flèche des ombres | 2 | 2–7 | 16 dégâts spectraux | Immédiat |
| Flèche incendiaire | 2 | 2–6 | 12 dégâts de feu, Brûlure, feu pendant 2 rounds | Activation N+2 |
| Flèche du Cocyte | 2 | 2–6 | 10 dégâts de glace, Gelé, glace pendant 2 rounds | Activation N+2 |
| Flèche du vortex | 2 | 2–5 | 8 dégâts spectraux, attraction d'une case | Activation N+2 |
| Pas du vortex | 2 | 2–4 | Téléportation sur une case libre | Activation N+3 |

Les quatre flèches sont des projectiles : les obstacles qui bloquent les projectiles ou la vision sont vérifiés au ciblage et au lancement. Gelé retire 1 PM pendant une activation ; il ne supprime pas le tour et ne fait pas glisser physiquement le personnage. Brûlure est le statut canonique, avec 6 dégâts au début du tour pendant sa durée normale de trois activations. Le feu et la glace temporaires durent deux rounds et participent aux réactions existantes, notamment avec l'eau. La surface permanente de la map est conservée sous ces effets. Poser un nouveau feu sous une unité applique immédiatement ses 8 dégâts de terrain en plus de la flèche ou de la couronne ; une réaction de surface peut produire un autre résultat. En particulier, glace temporaire puis feu donnent une surface d’eau et non deux couches superposées.

La Flèche du vortex exerce une vraie attraction : une case de feu, de glace, d'eau ou un téléporteur atteint par ce déplacement conserve ses effets normaux. **Pas du vortex** est un sort de téléportation distinct, utilisable dans les deux formes. Il paie 2 PA, ne dépense aucun PM, déplace réellement l'unité dans la grille et applique une seule fois la dalle d'arrivée. S'il vise un téléporteur de la map, le rapport expose la destination effectivement obtenue. Il ne crée pas de réseau permanent supplémentaire.

## Métamorphose

Une seule fois, après un dégât réel survivable laissant Paris **strictement sous 20 % de ses PV initiaux**, le kit infernal remplace le kit spectral. À 24/120 PV, il reste archer. À 23/120 PV ou moins, il devient démon et gagne **30 points de bouclier** de source `paris_infernal_carapace`. Le bouclier dure jusqu'à son absorption ou sa suppression normale. Il ne s'agit pas d'un soin et les dégâts létaux, directs comme périodiques, tuent normalement.

La transformation conserve la même unité, son identité de combat, sa case, son orientation, son initiative, ses PA/PM restants, ses statuts et les délais de récupération partagés. Elle ne réinitialise pas l'activation. Des bonus temporaires de PV maximaux ne déplacent pas son seuil initial. Guérir Paris après la transformation ne restaure jamais l'arc et ne recharge jamais la carapace.

| Sort infernal | PA | Portée | Effet réel | Retour disponible |
|---|---:|---:|---|---|
| Fouet du Tartare | 2 | 1–3 | 20 dégâts de feu | Une fois par activation |
| Couronne de braises | 2 | 1–3 | 14 dégâts de feu aux ennemis dans une croix de rayon 1, feu sur les cases affectées pendant 2 rounds | Activation N+2 |
| Étreinte du Tartare | 2 | 2–4 | 12 dégâts de feu, attraction d'une case | Activation N+2 |
| Pas du vortex | 2 | 2–4 | Téléportation réelle, même récupération que dans la forme spectrale | Activation N+3 |

Le fouet et l'étreinte sont classés comme attaques de mêlée, même lorsque leur allonge dépasse une case. La couronne est une attaque de zone. Ses impacts directs épargnent les alliés ; les surfaces de feu restent ensuite dangereuses pour toutes les équipes.

## Décision et synchronisation

L'archer utilise d'abord le gel sur une cible non gelée, puis le feu. Durant la récupération des flèches élémentaires, il emploie les flèches spectrales. Un tir létal légal est prioritaire. Une attraction vers un danger ou un vortex peut passer avant ces attaques ; l'IA n'invente pas une nouvelle position de la cible pour enchaîner un second tir après cette attraction.

Pas du vortex lui permet de quitter le contact ou une dalle dangereuse. La forme infernale l'emploie aussi pour rejoindre la portée du fouet. L'IA évite les destinations dangereuses et les destinations de téléporteur incertaines lorsqu'elle prépare un sort depuis la nouvelle case. Les déplacements ordinaires conservent l'évaluation des téléporteurs déjà utilisée par le Dialecticien. La zone de braises devient prioritaire lorsqu'elle atteint plusieurs adversaires.

Le modèle émet `combat_form_changed(unit, old_form, new_form)` après le changement effectif de kit et la création du bouclier. La vue attend sa transformation avant toute nouvelle action. Si un déplacement sur terrain transforme Paris au milieu de son plan, le tour ennemi est recalculé avec les ressources réellement restantes et une borne d'actions inchangée.

Les sorts portent une forme requise. Une ancienne flèche préparée est annulée lors du changement ; un contexte de tir déjà payé mais pas encore résolu est annulé sans rembourser des ressources ni infliger des dégâts tardifs. Une deuxième résolution renvoie le même résultat. Les rapports de dégâts conservent les PV perdus et le bouclier absorbé par le coup initial, même quand une nouvelle carapace apparaît immédiatement après ce coup.

## Validation

Les cas de gameplay se trouvent dans `test/unit/test_paris_gameplay.gd`. Ils vérifient les bornes 20 %/19 %, le coup létal, les dégâts périodiques, les ressources et l'identité conservées, les annulations, les deux kits, les surfaces réelles, le passage par un portail, les coûts du Pas du vortex, les obstacles et les choix de l'IA. Leur résultat exécuté est consigné dans le rapport de validation d'intégration ; ce document ne tient pas lieu d'un résultat de test.
