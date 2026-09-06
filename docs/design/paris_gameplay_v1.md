# Paris — règles de combat

Mise à jour du 7 septembre 2026 : la métamorphose rend désormais tous ses PV à Paris. Les résultats et captures du lot v1 sont historiques et précèdent cette règle ; ils ne prouvent pas le nouveau soin.

Paris conserve l'identité de **L’Ombre de Paris** (`catabase_shadow_paris`) pour devenir le boss de la cinquième et dernière salle de Catabase, au Temple du Serment Noir. Il n’apparaît pas dans les quatre salles précédentes. Deux spectres à l’épée, déjà présents dans cette rencontre, protègent son approche. Les PV maximaux initiaux des adversaires restent inchangés. La troisième salle accueille désormais le Champion et un spectre, pour 179 PV au total, suivis des 185 PV de la quatrième salle et des 248 PV du groupe final (PV initiaux, hors carapace et récupération de la métamorphose). Il commence en archer spectral : 120 PV, 4 PA, 3 PM, initiative 9, sans attaque de base gratuite. Son arc privilégie la distance et son kit emploie les mêmes surfaces, statuts, lignes de vue et déplacements que les autres combattants.

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

Une seule fois, après un dégât réel survivable laissant Paris **strictement sous 20 % de ses PV initiaux**, le kit infernal remplace le kit spectral. À 24/120 PV, il reste archer. Après un coup qui le laisse entre 1 et 23/120 PV, il devient démon, **récupère tous ses PV** — 120/120 sans modificateur — et gagne **30 points de bouclier** de source `paris_infernal_carapace`. Le bouclier dure jusqu'à son absorption ou sa suppression normale. Le soin est plafonné aux PV maximaux en vigueur. Les dégâts létaux, directs comme périodiques, tuent normalement : aucun soin ni retour à la vie n'est déclenché à 0 PV.

La transformation conserve la même unité, son identité de combat, sa case, son orientation, son initiative, ses PA/PM restants, ses statuts et les délais de récupération partagés. Elle ne réinitialise pas l'activation. Des bonus temporaires de PV maximaux ne déplacent pas son seuil initial. La restauration complète ne survient qu'une fois. Un soin ultérieur ne restaure jamais l'arc et ne recharge jamais la carapace.

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

Le modèle émet `combat_form_changed(unit, old_form, new_form)` après le changement effectif de kit, la création du bouclier et la restauration des PV. La vue attend sa transformation avant toute nouvelle action. Si un déplacement sur terrain transforme Paris au milieu de son plan, le tour ennemi est recalculé avec les ressources réellement restantes et une borne d'actions inchangée.

Les sorts portent une forme requise. Une ancienne flèche préparée est annulée lors du changement ; un contexte de tir déjà payé mais pas encore résolu est annulé sans rembourser des ressources ni infliger des dégâts tardifs. Une deuxième résolution renvoie le même résultat. Les rapports de dégâts conservent les PV perdus et le bouclier absorbé par le coup initial, même quand une nouvelle carapace et un soin apparaissent immédiatement après ce coup. Le soin est publié séparément par `Unit.heal()` ; le rapport du coup n'en retranche pas le montant.

## Validation

Les cas de gameplay se trouvent dans `test/unit/test_paris_gameplay.gd`. Ils vérifient les bornes 20 %/19 %, le coup létal, les dégâts périodiques, les ressources et l'identité conservées, les annulations, les deux kits, les surfaces réelles, le passage par un portail, les coûts du Pas du vortex, les obstacles et les choix de l'IA. Le résultat exécuté du lot initial reste consigné dans le rapport historique `paris_combat_validation_v1.json`. La récupération complète ajoutée le 7 septembre 2026 exige une validation distincte ; les 298 tests et 32 combats de ce rapport antérieur ne la certifient pas. Ce document ne tient pas lieu d'un résultat de test.
