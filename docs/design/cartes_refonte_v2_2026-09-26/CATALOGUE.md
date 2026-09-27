# Catalogue de la refonte Cartes V2

Généré depuis `preparer.mjs`. Version 2.0.0-design.1. Valeurs de conception à intégrer puis tester ; aucun équilibrage humain revendiqué. P est la puissance effective du héros. Les effets exacts sont complétés par [REGLES.md](REGLES.md).

## Quatre classes et huit spécialisations

| Classe | Passif | Choix au niveau 4 | Départ conseillé, trois copies de chaque |
|---|---|---|---|
| Assassin | Premier impact direct sur une cible isolée : +0,25 P. | execution: Premier impact sur une cible à 35 % PV ou moins : +0,30 P. / relay: Première élimination directe d’une cible marquée : transfert optionnel vers une cible à ≤2 cases du mort, valeur min(marque capturée,0,20 P), expire à la fin de la prochaine activation du héros. Une marque issue de relais ne peut pas être retransmise. | a01, a02, a04, n02, n03 |
| Gardien | La première attaque ennemie absorbée au moins en partie par la garde, chaque tour, renvoie 0,25 P physiques à son auteur. | bastion: Première garde produite par une carte du tour : +25 %. / crusher: Première cible effectivement poussée : subit 0,25 P physiques supplémentaires. | g01, g02, g03, n05, n03 |
| Arpenteur | Ancre de repli : après un impact direct de carte à distance ≥3, peut revenir sur sa case de début de tour pour 1 PM, une fois, si libre et à distance ≤3. | sniper: Premier impact à distance 4 ou plus : +0,25 P. / skirmish: Première carte offensive jouée après 2 cases de mouvement volontaire admissible : pioche 1 après sa résolution, limite de main normale. | r01, r02, r03, n02, n03 |
| Thaumaturge | Première application directe de marque/brûlure/entrave OU première transformation élémentaire valide du tour : +0,20 P de garde. Compteur partagé. | pyre: Première brûlure appliquée par tour : +0,10 P par tic. / frost: Première entrave appliquée par tour : +0,30 P de garde. | t01, t02, t03, n02, n03 |

Le Thaumaturge dispose aussi du départ Terrain : t01, t02, t04, n02, n03. Les deux départs sont accessibles ; Standard reste présélectionné.

## Les 48 familles

`cc2_` préfixe les identifiants runtime. Les anciennes cartes Godot ne sont pas converties. ★ signale une modification face à la V1.

| ID | Nom / affinité / rareté | PA ; portée | Base | Amélioration familiale |
|---|---|---|---|---|
| n01 | Estoc / shared / normal | 1 ; 1–1 | 0,55 P physiques | 0,7 P physiques |
| n02 ★ | Garde brève / shared / normal | 1 ; 0–0 | 0,45 P de garde | 0,45 P de garde ; peut retenir une autre copie en main pour une transition de tour. |
| n03 | Pas latéral / shared / normal | 1 ; 1–2 | 2 cases par chemin libre | 3 cases par chemin libre ; portée 1–3 |
| n04 ★ | Heurt / shared / normal | 1 ; 1–1 | 0,25 P physiques ; pousse de 1 cases | 0,25 P physiques ; poussée de 2 cases. |
| n05 | Trait court / shared / normal | 1 ; 2–4 | 0,45 P physiques | 0,6 P physiques |
| n06 ★ | Repérage / shared / normal | 1 ; 1–4 | 0,2 P physiques ; 0,35 P au prochain impact de carte ; expire après 2 phases ennemies | Effet de base ; portée maximale 5. |
| n07 ★ | Entrave légère / shared / normal | 1 ; 1–3 | 0,2 P physiques ; -1 PM pour la prochaine activation | Effet de base ; portée maximale 4. |
| n08 | Recentrage / shared / normal | 1 ; 0–0 | pioche 2 exemplaires existants, limitée par la main | pioche 3 exemplaires existants, limitée par la main |
| a01 ★ | Ouvrir la garde / assassin / normal | 1 ; 1–2 | 0,35 P physiques ; 0,45 P au prochain impact de carte ; expire après 2 phases ennemies | Effet de base ; la marque dure 3 phases ennemies au lieu de 2. |
| a02 ★ | Frapper la faille / assassin / normal | 2 ; 1–1 | 0,95 P physiques ; +0,55 P si cible marquée | Effet de base ; portée 1–2. |
| a03 ★ | Entaille tenace / assassin / normal | 2 ; 1–1 | 0,70 P physiques ; saignement physique 0,15 P pendant 2 activations. | 0,70 P physiques ; saignement physique 0,20 P pendant 2 activations. |
| a04 ★ | Attaque oblique / assassin / normal | 2 ; 1–1 | 1,05 P physiques ; +0,35 P si 2 cases parcourues | 1,05 P physiques ; +0,35 P après 1 case de mouvement volontaire admissible. |
| g01 | Garde ferme / gardien / normal | 2 ; 0–0 | 1,15 P de garde | 1,4 P de garde |
| g02 | Heurt du rempart / gardien / normal | 2 ; 1–1 | 1 P physiques ; +0,5 P si garde présente | 1,15 P physiques ; +0,5 P si garde présente |
| g03 ★ | Repousser / gardien / normal | 2 ; 1–1 | 0,8 P physiques ; pousse de 2 cases | 0,80 P physiques ; pousse de 3 cases. |
| g04 ★ | Ramener au front / gardien / normal | 1 ; 2–3 | 0,2 P physiques ; attire de 1 cases | 0,20 P physiques ; attire de 2 cases. |
| r01 ★ | Tir de relais / arpenteur / normal | 2 ; 2–4 | 0,80 P physiques ; après 2 cases de mouvement volontaire admissible, pioche 1 dans la limite de main. | Même effet ; portée 1–4. |
| r02 ★ | Trait de recul / arpenteur / normal | 2 ; 2–4 | 0,7 P physiques ; pousse de 1 cases | Effet de base ; portée 1–4. |
| r03 ★ | Flèche entravante / arpenteur / normal | 2 ; 2–4 | 0,6 P physiques ; -2 PM pour la prochaine activation | Effet de base ; portée 2–5. |
| r04 | Volée croisée / arpenteur / normal | 3 ; 2–4 | 0,6 P physiques en croix | 0,75 P physiques en croix |
| t01 ★ | Trait de givre / thaumaturge / normal | 2 ; 1–4 | 0,65 P magiques ; −1 PM à la prochaine activation ; sur eau dynamique, transforme la case en glace pour 2 phases. | Même effet ; glace issue de l’eau : 3 phases. |
| t02 ★ | Braise tenace / thaumaturge / normal | 2 ; 1–3 | 0,55 P magiques ; brûlure 0,18 P × 2 ; sur eau dynamique, vapeur bloquant la vision pour 1 phase. | Même effet ; vapeur issue de l’eau : 2 phases. |
| t03 ★ | Sceau ombreux / thaumaturge / normal | 1 ; 1–4 | 0,25 P magiques ; 0,4 P au prochain impact de carte ; expire après 2 phases ennemies | 0,25 P magiques ; marque de 0,60 P pendant 2 phases. |
| t04 ★ | Onde du Léthé / thaumaturge / normal | 3 ; 1–3 | 0,45 P magiques en croix ; pose de l’eau dynamique 2 phases sur les cases valides de la croix. | Même effet ; eau 3 phases. |
| a05 | Bond spectral / assassin / elite | 2 ; 1–3 | 3 cases par téléportation | 4 cases par téléportation ; portée 1–4 |
| a06 | Dernier verdict / assassin / elite | 3 ; 1–2 | 1,3 P physiques ; +0,7 P si cible à 35 % PV ou moins | 1,45 P physiques ; +0,7 P si cible à 35 % PV ou moins |
| a07 | Pointe franche / assassin / elite | 2 ; 1–3 | 0,9 P physiques ; ignore l’armure | 1,05 P physiques ; ignore l’armure |
| g05 | Contre préparé / gardien / elite | 2 ; 0–0 | 0,9 P de garde et une riposte de 0,5 P | 1,15 P de garde et une riposte de 0,5 P |
| g06 ★ | Choc de masse / gardien / elite | 2 ; 1–1 | 0,65 P physiques ; poussée 1 ; si un mur/obstacle fixe arrête cette poussée : 0,30 P de garde, une fois. | Même effet ; garde de collision 0,45 P. |
| g07 | Dette du bronze / gardien / elite | 3 ; 1–2 | 1,2 P physiques ; +0,5 P si garde absorbée au tour précédent | 1,35 P physiques ; +0,5 P si garde absorbée au tour précédent |
| r05 | Au-delà du front / arpenteur / elite | 2 ; 1–4 | 4 cases par téléportation | 5 cases par téléportation ; portée 1–5 |
| r06 ★ | Pluie de pointes / arpenteur / elite | 3 ; 2–5 | 0,70 P physiques sur une ligne de 3 cases perpendiculaire à l’axe dominant lanceur–centre ; une fois par cible. | Même effet ; portée 2–6. |
| r07 ★ | Trait harpon / arpenteur / elite | 2 ; 2–5 | 0,55 P physiques ; attire de 2 cases | 0,55 P physiques ; choisit une attraction de 1 ou 2 cases. |
| t05 | Bûcher des ombres / thaumaturge / elite | 2 ; 1–4 | 0,35 P magiques par phase, 2 phases, croix affectant les deux camps | 0,45 P magiques par phase, 2 phases, croix affectant les deux camps |
| t06 | Jardin de givre / thaumaturge / elite | 2 ; 1–4 | -1 PM aux ennemis en croix pendant 2 phases | -1 PM aux ennemis en croix pendant 3 phases |
| t07 | Prélèvement / thaumaturge / elite | 2 ; 1–3 | 0,75 P magiques ; soigne 50 % des PV effectivement retirés | 0,9 P magiques ; soigne 50 % des PV effectivement retirés |
| a08 | Couper le souffle / assassin / rare | 2 ; 1–3 | 0,7 P physiques ; prochaine attaque à −50 % ; boss −25 % | 0,85 P physiques ; prochaine attaque à −50 % ; boss −25 % |
| a09 | Sommeil marqué / assassin / rare | 3 ; 1–3 | consomme une marque ; annule une activation ; immunité 3 suivantes ; boss : affaiblissement 25 % | consomme une marque ; annule une activation ; immunité 3 suivantes ; boss : affaiblissement 25 % ; portée 1–4 |
| g08 | Bastion vivant / gardien / rare | 3 ; 0–0 | 1,9 P de garde | 2,15 P de garde |
| g09 ★ | Répercussion / gardien / rare | 2 ; 1–3 | Choisit S entre 0 et min(garde, 0,80 P), consomme S ; inflige 0,70 P + 1,50 S physiques. | Même formule et coût ; portée 1–4. |
| r08 | Permutation / arpenteur / rare | 2 ; 1–5 | échange les positions ; boss exclu | échange les positions ; boss exclu ; portée 1–6 |
| r09 | La longue vue / arpenteur / rare | 3 ; 3–6 | 1,75 P physiques | 1,9 P physiques |
| t08 ★ | Convergence / thaumaturge / rare | 3 ; 1–4 | 0,8 P magiques en croix ; attire d’une case vers le centre les ennemis à distance ≤2, puis frappe la croix | Effet de base ; portée 1–5. |
| t09 ★ | Résonance du sceau / thaumaturge / rare | 3 ; 1–4 | 0,9 P magiques ; +0,8 P si cible marquée | 0,90 P magiques ; +1,05 P si la cible est marquée. |
| l01 | Orage du passage / shared / legendary | 3 ; 0–0 | 1,1 P magiques dans un rayon de 2 | 1,25 P magiques dans un rayon de 2 |
| l02 | Grâce du bronze / shared / legendary | 2 ; 0–0 | soigne 1,5 P ; garde 0,5 P | soigne 1,75 P ; garde 0,5 P |
| d01 | Décret du dernier souffle / shared / god | 3 ; 0–0 | premier impact létal laisse 1 PV jusqu’au prochain tour ; pression exclue | premier impact létal laisse 1 PV jusqu’au prochain tour ; pression exclue ; garde 0,6 P |
| i01 | Seconde aurore / shared / immortal | 4 ; 0–0 | soigne 60 % PV max ; garde 1 P ; finit l’activation | soigne 75 % PV max ; garde 1 P ; finit l’activation |

## Pourquoi ces changements

| Famille | Décision recherchée |
|---|---|
| n02 — Garde brève | Protection contre accès différé ; remplace le bonus de garde. |
| n04 — Heurt | Différencier déplacement et dégâts. |
| n06 — Repérage | Faciliter la préparation à distance. |
| n07 — Entrave légère | Étendre une réponse de contrôle ordinaire. |
| a01 — Ouvrir la garde | Préparation plus souple sans multiplier les marques. |
| a02 — Frapper la faille | Le finisseur gagne une cible possible, pas un multiplicateur. |
| a03 — Entaille tenace | Résoudre la confusion entre blessure de l’Assassin et brûlure magique. |
| a04 — Attaque oblique | Rendre la condition plus accessible. |
| g03 — Repousser | Créer un outil de placement distinct. |
| g04 — Ramener au front | Construire le contact. |
| g06 — Choc de masse | Une élite spécialisée dans les obstacles. Bord, unité et limitation du boss exclus. |
| g09 — Répercussion | Le sacrifice doit rémunérer un choix réel, avec défense restante visible. |
| r01 — Tir de relais | Relier position et accès aux cartes, sans remboursement de PA. |
| r02 — Trait de recul | Ouvrir une réponse de dégagement. |
| r03 — Flèche entravante | Mieux préparer les approches. |
| r06 — Pluie de pointes | La formation ennemie décide entre ligne et croix. |
| r07 — Trait harpon | Précision du placement. |
| t01 — Trait de givre | Une réponse élémentaire accessible sans rare. |
| t02 — Braise tenace | Choisir entre visibilité et protection. La cible est validée avant apparition de la vapeur. |
| t03 — Sceau ombreux | Améliorer la préparation plutôt que son impact. |
| t04 — Onde du Léthé | Remplace une zone de dégâts redondante par un support de transformation. |
| t08 — Convergence | Élargir la préparation des groupes. |
| t09 — Résonance du sceau | Renforcer l’identité de finisseur préparé. |

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

Les valeurs des 18 équipements et des huit reliques sont conservées dans le manifeste V2. Leur adéquation au nouveau combat doit être testée ; les anciens taux de victoire ne la certifient pas.
