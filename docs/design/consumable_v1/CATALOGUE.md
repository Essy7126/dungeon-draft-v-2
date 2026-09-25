# Catalogue fermé de la V1 théorique

Généré par `export_tables.mjs` depuis `content.mjs`. P = puissance effective. Une carte = un exemplaire consommé après résolution légale ; au plus une carte d’une même famille par tour. Toutes les affinités sont jouables par toutes les classes. Chaque famille reçoit au plus une amélioration, partagée par ses exemplaires présents et futurs.

## Classes et préparation de départ

| Classe | Passif | Quinze exemplaires conseillés | Spécialisations, choix au niveau 4 |
|---|---|---|---|
| Assassin | Premier impact direct sur une cible isolée : +0,25 P. Impacts de cartes uniquement. | Ouvrir la garde ×3 ; Frapper la faille ×3 ; Attaque oblique ×3 ; Garde brève ×3 ; Pas latéral ×3 | execution : Premier impact sur une cible à 35 % PV ou moins : +0,30 P. / ambush : Premier impact après deux cases parcourues : +0,30 P de garde. |
| Gardien | La première attaque ennemie absorbée au moins en partie par la garde, chaque tour, renvoie 0,25 P physiques à son auteur. | Garde ferme ×3 ; Heurt du rempart ×3 ; Repousser ×3 ; Trait court ×3 ; Pas latéral ×3 | bastion : Première garde produite par une carte du tour : +25 %. / crusher : Première cible effectivement poussée : subit 0,25 P physiques supplémentaires. |
| Arpenteur | Premier impact direct à distance 3 ou plus : +1 PM. Impacts de cartes uniquement. | Trait tendu ×3 ; Trait de recul ×3 ; Flèche entravante ×3 ; Garde brève ×3 ; Pas latéral ×3 | sniper : Premier impact à distance 4 ou plus : +0,25 P. / skirmish : Premier impact après deux cases parcourues : +1 PM. |
| Thaumaturge | Première marque, brûlure ou entrave appliquée : +0,20 P de garde. | Trait de givre ×3 ; Braise tenace ×3 ; Sceau ombreux ×3 ; Garde brève ×3 ; Pas latéral ×3 | pyre : Première brûlure appliquée par tour : +0,10 P par tic. / frost : Première entrave appliquée par tour : +0,30 P de garde. |

## Les 48 cartes et leurs améliorations

La portée est une distance de Manhattan, avec ligne de vue sauf déplacement/téléportation ; 0 désigne soi. Les croix font cinq cases au maximum. La rareté décrit l’accès, pas une multiplication uniforme des dégâts.

| ID | Nom / affinité / rareté | PA ; portée | Effet de base | Effet une fois amélioré |
|---|---|---|---|---|
| n01 | Estoc / shared / normal | 1 ; 1–1 | 0,55 P physiques | 0,7 P physiques |
| n02 | Garde brève / shared / normal | 1 ; 0–0 | 0,45 P de garde | 0,7 P de garde |
| n03 | Pas latéral / shared / normal | 1 ; 1–2 | 2 cases par chemin libre | 3 cases par chemin libre ; portée 1–3 |
| n04 | Heurt / shared / normal | 1 ; 1–1 | 0,25 P physiques ; pousse de 1 cases | 0,4 P physiques ; pousse de 1 cases |
| n05 | Trait court / shared / normal | 1 ; 2–4 | 0,45 P physiques | 0,6 P physiques |
| n06 | Repérage / shared / normal | 1 ; 1–4 | 0,2 P physiques ; 0,35 P au prochain impact de carte ; expire après 2 phases ennemies | 0,35 P physiques ; 0,35 P au prochain impact de carte ; expire après 2 phases ennemies |
| n07 | Entrave légère / shared / normal | 1 ; 1–3 | 0,2 P physiques ; -1 PM pour la prochaine activation | 0,35 P physiques ; -1 PM pour la prochaine activation |
| n08 | Recentrage / shared / normal | 1 ; 0–0 | pioche 2 exemplaires existants, limitée par la main | pioche 3 exemplaires existants, limitée par la main |
| a01 | Ouvrir la garde / assassin / normal | 1 ; 1–2 | 0,35 P physiques ; 0,45 P au prochain impact de carte ; expire après 2 phases ennemies | 0,5 P physiques ; 0,45 P au prochain impact de carte ; expire après 2 phases ennemies |
| a02 | Frapper la faille / assassin / normal | 2 ; 1–1 | 0,95 P physiques ; +0,55 P si cible marquée | 1,1 P physiques ; +0,55 P si cible marquée |
| a03 | Entaille tenace / assassin / normal | 2 ; 1–1 | 0,7 P physiques ; 0,15 P magiques × 2 activations | 0,85 P physiques ; 0,15 P magiques × 2 activations |
| a04 | Attaque oblique / assassin / normal | 2 ; 1–1 | 1,05 P physiques ; +0,35 P si 2 cases parcourues | 1,2 P physiques ; +0,35 P si 2 cases parcourues |
| g01 | Garde ferme / gardien / normal | 2 ; 0–0 | 1,15 P de garde | 1,4 P de garde |
| g02 | Heurt du rempart / gardien / normal | 2 ; 1–1 | 1 P physiques ; +0,5 P si garde présente | 1,15 P physiques ; +0,5 P si garde présente |
| g03 | Repousser / gardien / normal | 2 ; 1–1 | 0,8 P physiques ; pousse de 2 cases | 0,95 P physiques ; pousse de 2 cases |
| g04 | Ramener au front / gardien / normal | 1 ; 2–3 | 0,2 P physiques ; attire de 1 cases | 0,35 P physiques ; attire de 1 cases |
| r01 | Trait tendu / arpenteur / normal | 2 ; 2–5 | 1 P physiques | 1,15 P physiques |
| r02 | Trait de recul / arpenteur / normal | 2 ; 2–4 | 0,7 P physiques ; pousse de 1 cases | 0,85 P physiques ; pousse de 1 cases |
| r03 | Flèche entravante / arpenteur / normal | 2 ; 2–4 | 0,6 P physiques ; -2 PM pour la prochaine activation | 0,75 P physiques ; -2 PM pour la prochaine activation |
| r04 | Volée croisée / arpenteur / normal | 3 ; 2–4 | 0,6 P physiques en croix | 0,75 P physiques en croix |
| t01 | Trait de givre / thaumaturge / normal | 2 ; 1–4 | 0,65 P magiques ; -1 PM pour la prochaine activation | 0,8 P magiques ; -1 PM pour la prochaine activation |
| t02 | Braise tenace / thaumaturge / normal | 2 ; 1–3 | 0,55 P magiques ; 0,18 P magiques × 2 activations | 0,7 P magiques ; 0,18 P magiques × 2 activations |
| t03 | Sceau ombreux / thaumaturge / normal | 1 ; 1–4 | 0,25 P magiques ; 0,4 P au prochain impact de carte ; expire après 2 phases ennemies | 0,4 P magiques ; 0,4 P au prochain impact de carte ; expire après 2 phases ennemies |
| t04 | Éclat de braise / thaumaturge / normal | 3 ; 1–3 | 0,65 P magiques en croix | 0,8 P magiques en croix |
| a05 | Bond spectral / assassin / elite | 2 ; 1–3 | 3 cases par téléportation | 4 cases par téléportation ; portée 1–4 |
| a06 | Dernier verdict / assassin / elite | 3 ; 1–2 | 1,3 P physiques ; +0,7 P si cible à 35 % PV ou moins | 1,45 P physiques ; +0,7 P si cible à 35 % PV ou moins |
| a07 | Pointe franche / assassin / elite | 2 ; 1–3 | 0,9 P physiques ; ignore l’armure | 1,05 P physiques ; ignore l’armure |
| g05 | Contre préparé / gardien / elite | 2 ; 0–0 | 0,9 P de garde et une riposte de 0,5 P | 1,15 P de garde et une riposte de 0,5 P |
| g06 | Choc de masse / gardien / elite | 2 ; 1–1 | 0,9 P physiques ; pousse de 2 cases | 1,05 P physiques ; pousse de 2 cases |
| g07 | Dette du bronze / gardien / elite | 3 ; 1–2 | 1,2 P physiques ; +0,5 P si garde absorbée au tour précédent | 1,35 P physiques ; +0,5 P si garde absorbée au tour précédent |
| r05 | Au-delà du front / arpenteur / elite | 2 ; 1–4 | 4 cases par téléportation | 5 cases par téléportation ; portée 1–5 |
| r06 | Pluie de pointes / arpenteur / elite | 3 ; 2–5 | 0,85 P physiques en croix | 1 P physiques en croix |
| r07 | Trait harpon / arpenteur / elite | 2 ; 2–5 | 0,55 P physiques ; attire de 2 cases | 0,7 P physiques ; attire de 2 cases |
| t05 | Bûcher des ombres / thaumaturge / elite | 2 ; 1–4 | 0,35 P magiques par phase, 2 phases, croix affectant les deux camps | 0,45 P magiques par phase, 2 phases, croix affectant les deux camps |
| t06 | Jardin de givre / thaumaturge / elite | 2 ; 1–4 | -1 PM aux ennemis en croix pendant 2 phases | -1 PM aux ennemis en croix pendant 3 phases |
| t07 | Prélèvement / thaumaturge / elite | 2 ; 1–3 | 0,75 P magiques ; soigne 50 % des PV effectivement retirés | 0,9 P magiques ; soigne 50 % des PV effectivement retirés |
| a08 | Couper le souffle / assassin / rare | 2 ; 1–3 | 0,7 P physiques ; prochaine attaque à −50 % ; boss −25 % | 0,85 P physiques ; prochaine attaque à −50 % ; boss −25 % |
| a09 | Sommeil marqué / assassin / rare | 3 ; 1–3 | consomme une marque ; annule une activation ; immunité 3 suivantes ; boss : affaiblissement 25 % | consomme une marque ; annule une activation ; immunité 3 suivantes ; boss : affaiblissement 25 % ; portée 1–4 |
| g08 | Bastion vivant / gardien / rare | 3 ; 0–0 | 1,9 P de garde | 2,15 P de garde |
| g09 | Répercussion / gardien / rare | 2 ; 1–3 | 0,5 P physiques ; consomme la garde ; +60 % de sa valeur, bonus plafonné à 1,2 P | 0,65 P physiques ; consomme la garde ; +60 % de sa valeur, bonus plafonné à 1,2 P |
| r08 | Permutation / arpenteur / rare | 2 ; 1–5 | échange les positions ; boss exclu | échange les positions ; boss exclu ; portée 1–6 |
| r09 | La longue vue / arpenteur / rare | 3 ; 3–6 | 1,75 P physiques | 1,9 P physiques |
| t08 | Convergence / thaumaturge / rare | 3 ; 1–4 | 0,8 P magiques en croix ; attire d’une case vers le centre les ennemis à distance ≤2, puis frappe la croix | 0,95 P magiques en croix ; attire d’une case vers le centre les ennemis à distance ≤2, puis frappe la croix |
| t09 | Résonance du sceau / thaumaturge / rare | 3 ; 1–4 | 0,9 P magiques ; +0,8 P si cible marquée | 1,05 P magiques ; +0,8 P si cible marquée |
| l01 | Orage du passage / shared / legendary | 3 ; 0–0 | 1,1 P magiques dans un rayon de 2 | 1,25 P magiques dans un rayon de 2 |
| l02 | Grâce du bronze / shared / legendary | 2 ; 0–0 | soigne 1,5 P ; garde 0,5 P | soigne 1,75 P ; garde 0,5 P |
| d01 | Décret du dernier souffle / shared / god | 3 ; 0–0 | premier impact létal laisse 1 PV jusqu’au prochain tour ; pression exclue | premier impact létal laisse 1 PV jusqu’au prochain tour ; pression exclue ; garde 0,6 P |
| i01 | Seconde aurore / shared / immortal | 4 ; 0–0 | soigne 60 % PV max ; garde 1 P ; finit l’activation | soigne 75 % PV max ; garde 1 P ; finit l’activation |

## Dix-huit équipements

Six emplacements, un objet de chaque ; changement uniquement hors combat, PV conservés en proportion. Aucun niveau d’objet supplémentaire, aucune amélioration aléatoire, aucune revente d’équipement. Paliers 1/2/3 = combats 1–3/4–6/7–12.

| ID | Nom | Emplacement | Palier | Prix | Modifications exactes |
|---|---|---|---|---|---|
| w_blade | Lame des brèches | weapon | 1 | 55 | dégâts directs de carte à distance 1 : +12 % |
| w_bow | Arc des longues rives | weapon | 1 | 60 | dégâts directs de carte à distance ≥3 : +10 % ; portée maximale des cartes ciblées : +1 ; PM : -1 |
| w_staff | Bâton des braises | weapon | 1 | 55 | dégâts directs magiques de carte : +12 % |
| b_leather | Cuir du passage | body | 1 | 50 | PV max : +12 % |
| b_plate | Cuirasse pesante | body | 2 | 65 | résistance physique : +12 % ; PM : -1 |
| b_robe | Robe de cendre | body | 2 | 65 | résistance magique : +12 % ; garde produite : +10 % |
| h_watch | Masque du guetteur | head | 1 | 65 | taille de main : +1 |
| h_bronze | Casque du seuil | head | 1 | 50 | garde au début du combat, en P : +0,6 P |
| h_sage | Diadème patient | head | 2 | 55 | garde produite : +15 % |
| f_quick | Sandales du détour | feet | 1 | 55 | PM : +1 |
| f_brace | Solerets du rempart | feet | 2 | 60 | dégâts directs de carte à distance 1 : +8 % ; résistance physique : +4 % |
| f_flow | Bottes du reflux | feet | 2 | 65 | dégâts directs de carte à distance ≥3 : +6 % ; PM : +1 ; garde produite : -10 % |
| s_life | Ceinture des vivants | belt | 1 | 55 | PV max : +16 % |
| s_care | Trousse du passeur | belt | 2 | 55 | soins reçus : +30 % ; PV max : +4 % |
| s_guard | Sangle de bronze | belt | 2 | 55 | garde produite : +20 % |
| j_cup | Pendentif écarlate | amulet | 3 | 80 | vol de vie direct plafonné à 10 % PV max par combat : +10 % |
| j_shard | Éclat téméraire | amulet | 3 | 75 | dégâts directs de carte : +8 % ; PV max : -6 % |
| j_eye | Œil des distances | amulet | 3 | 80 | portée maximale des cartes ciblées : +1 ; réduction de la première attaque ennemie, en P : +0,12 P |

## Huit reliques

Deux reliques distinctes actives ; aucun cumul de doublons. Prix uniquement chez les marchands de palier ≥3. Les reliques garanties viennent des victoires 5 et 10 ; doublon conservé en réserve sans deuxième effet.

| ID | Nom | Prix | Règle |
|---|---|---|---|
| thread | Fil du détour | 90 | Le premier déplacement par carte de chaque tour rend 1 PM. |
| bronze | Urne patiente | 95 | Si de la garde a absorbé des dégâts, gagne 0,25 P de garde au prochain tour. |
| embers | Mèche obstinée | 95 | Les brûlures et zones de feu infligent +0,10 P par tic. |
| obole | Obole fendue | 90 | Une élimination directe rapporte 4 or, maximum 20 par combat. |
| archive | Agrafe des archives | 95 | La première carte à 3 PA ou plus du combat coûte 1 PA de moins. |
| mirror | Miroir du bronze | 100 | La première attaque reçue de chaque combat renvoie 0,40 P ; aucun déclenchement récursif. |
| cup | Coupe des blessures | 100 | Les deux premières éliminations directes du combat soignent chacune 0,35 P. |
| seal | Sceau du chasseur | 95 | Une marque appliquée gagne +0,20 P de bonus au prochain impact. |

Les coefficients complets et identifiants transportables sont aussi dans [manifest.json](manifest.json). Les résultats par famille sont dans [card_summary.csv](card_summary.csv), et les comparaisons d’équipement, relique et spécialisation dans [item_summary.csv](item_summary.csv). Un effet utile dans un scénario ne prouve pas qu’il convient à tous les builds.
