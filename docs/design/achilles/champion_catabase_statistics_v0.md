# Achille — statistiques et maîtrises de la Catabase

Valeurs V0 générées depuis les ressources et le resolver utilisés en combat. Document actualisé par `tools/champion_progression/export_champion_statistics.gd`.

## Progression du champion

La Catabase conserve ses trois rencontres actuelles : 100, 120 et 140 XP après victoire. Sans Sagesse ni Gloire, Achille termine au niveau 4. Les niveaux 5–14 et les spécialisations restent définis et vérifiés dans les fixtures de simulation ; aucune nouvelle run n’est créée.

L’XP n’est jamais attribuée à un sort. Chaque victoire est comptée une seule fois par identifiant de rencontre. La Sagesse est figée au début du combat. Le Serment du Pélion est accepté avant le combat ; la victoire sans consommable accorde ensuite le multiplicateur de Gloire ×1,30.

`XP = arrondi(XP de base × (1 + 0,10 × Sagesse au départ) × Gloire)`

Chaque niveau 2–14 accorde 1 maîtrise. Chaque niveau 2–10 accorde aussi 1 caractéristique. Les points peuvent être conservés ; leur dépense est disponible entre les combats.

| Niveau | XP cumulée | PV de base | Prouesse | Frappe | Tir | Garde |
|---|---|---|---|---|---|---|
| 1 | 0 | 110 | 18 | 10 | 9 | 10 |
| 2 | 100 | 135 | 22 | 12 | 11 | 12 |
| 3 | 220 | 165 | 27 | 15 | 14 | 15 |
| 4 | 360 | 200 | 33 | 18 | 17 | 18 |
| 5 | 520 | 240 | 40 | 22 | 20 | 22 |
| 6 | 700 | 290 | 48 | 26 | 24 | 27 |
| 7 | 900 | 350 | 57 | 31 | 29 | 32 |
| 8 | 1120 | 420 | 68 | 37 | 34 | 38 |
| 9 | 1360 | 500 | 82 | 45 | 41 | 46 |
| 10 | 1700 | 600 | 100 | 55 | 50 | 55 |
| 11 | 1990 | 635 | 106 | 58 | 53 | 58 |
| 12 | 2300 | 675 | 112 | 62 | 56 | 62 |
| 13 | 2630 | 720 | 119 | 65 | 60 | 66 |
| 14 | 2950 | 770 | 127 | 70 | 64 | 70 |

Valeurs sans équipement ni maîtrise. 6 PA, 3 PM, initiative 14 et quatre emplacements restent constants. L’équipement demeure passif ; il ne crée ni attaque de base ni arme visible.

## Quatre techniques

| Technique | PA | Portée | Règle |
|---|---|---|---|
| Frappe du Péléide | 3 | 1 | 55 % Prouesse ; une utilisation par activation. |
| Percée fulgurante | 1 | 1–3 | Déplacement cardinal vers une case libre, sans traverser les obstacles ni les unités. |
| Tir du Pélion | 3 | 2–6 | 50 % Prouesse ; ligne de vue ; une utilisation par activation. |
| Garde d’airain | 2 | Soi | 5 % PV max + 25 % Prouesse ; une utilisation ; expire au début de l’activation suivante. |

La Garde est une source indépendante. Une garde plus faible ne remplace pas la garde restante ; ses effets ne consomment pas les autres boucliers. Les attaques automatiques n’utilisent ni PA ni quota manuel et ne donnent aucune XP.

## Caractéristiques

| Caractéristique | Effet par point |
|---|---|
| Vitalité | +6 % des PV de base du niveau, sous forme de bonus plat. |
| Puissance | +5 % de Prouesse. |
| Résolution | +4 armure ; +5 % à la création des boucliers. |
| Sagesse | +10 % à l’XP des combats futurs, maximum 5 points. |

Les montées de niveau et la Vitalité ajoutent seulement le gain de PV max aux PV actuels, en conservant les blessures. L’équipement et la forge ne soignent jamais. Le codex calcule les aperçus avec les mêmes stats et les mêmes règles que le combat.

## Doctrines et destin héroïque

Chaque racine coûte 1 maîtrise ; les paliers II–IV coûtent 1 par choix. Au moins un choix du palier précédent suffit. Les deux choix majeurs d’une doctrine sont exclusifs et coûtent 2 chacun. Premier choix majeur au niveau 10, second au niveau 13. Sommet au niveau 13 ; jonction et apothéose au niveau 14.

Précision du mandat : Allonge et Tir rapproché sont exclusifs. La doctrine de Chiron est donc complète à 8 points légaux, contre 9 pour les deux autres. Le resolver considère le choix exclu comme couvert pour l’accès à une doctrine complète.

| Maîtrise | Coût | Niveau min. | Effet |
|---|---|---|---|
| Fureur lucide | 1 | 1 | Pendant une activation, contre une même cible, la deuxième technique offensive distincte gagne 15 % et la troisième 25 %. |
| Entaille d’ouverture | 1 | 1 | Frappe retire 20 Armure jusqu’au début de la prochaine activation ; si la cible possède déjà 0 Armure, Frappe gagne 15 %. |
| Élan meurtrier | 1 | 1 | Après une Percée d’au moins deux cases terminée au contact, la prochaine Frappe gagne 25 %. |
| Exécution | 1 | 1 | Frappe et Tir gagnent 35 % contre une cible à 35 % de ses PV ou moins. |
| Sang pour sang | 1 | 1 | Après une perte d’au moins 10 % des PV maximum depuis l’activation précédente, la prochaine technique offensive gagne 30 %, une fois par activation. |
| Pas victorieux | 1 | 1 | Une élimination par Frappe ou Tir propose un déplacement optionnel gratuit de deux cases maximum, une fois par activation. |
| Brise-formation | 1 | 1 | Une cible déplacée ou entrée en collision à cause d’Achille perd 25 Armure et subit 25 % de plus à la prochaine Frappe, jusqu’à la prochaine activation. |
| Fléau de Troie | 2 | 10 | Frappe devient une ligne de deux cases : 120 % sur la première cible et 70 % sur la seconde. |
| Colère irrépressible | 2 | 13 | Sous 40 % PV au début de l’activation, Frappe et Tir gagnent 30 % ; la première élimination crée un bouclier de 8 % des PV max. |
| Œil du centaure | 1 | 1 | Après au moins deux cases parcourues pendant l’activation, le prochain Tir gagne 10 %. |
| Allonge du Pélion | 1 | 1 | Tir passe à portée 3–8 : +25 % à six cases ou plus et -20 % à trois cases. Exclusif avec Tir rapproché. |
| Tir rapproché | 1 | 1 | Tir passe à portée 1–5 : +25 % à trois cases ou moins, poussée 1 et -15 % à cinq cases. Exclusif avec Allonge. |
| Angle impossible | 1 | 1 | Après Percée, propose un pas orthogonal optionnel gratuit d’une case, une fois par activation. |
| Flèche d’arrêt | 1 | 1 | À quatre cases ou moins, la cible perd 1 PM à sa prochaine activation. Non cumulable. |
| Flèche perforante | 1 | 1 | Tir traverse la première cible et inflige 60 % à une seconde cible alignée. |
| Chasse mobile | 1 | 1 | Après au moins trois cases parcourues, Tir gagne 20 % et le premier déplacement normal suivant ignore 1 point de pénalité d’engagement. |
| Ligne de mort | 2 | 10 | Tir traverse jusqu’à trois cibles à 100/70/40 % et ignore 25 Armure à six cases ou plus. |
| Volée du centaure | 2 | 13 | Tir devient un éventail de trois cases, portée 2–5, à 70 % par cible ; il n’est plus perforant. |
| Garde active | 1 | 1 | Si Garde absorbe au moins 10 % des PV maximum avant la prochaine activation, la prochaine technique offensive gagne 15 %. |
| Garde orientée | 1 | 1 | Le joueur choisit une direction : les attaques frontales infligent 35 % de moins à Garde, les attaques latérales ou arrière 15 % de plus. |
| Ancrage d’airain | 1 | 1 | Tant que Garde subsiste : +30 Armure, immunité aux poussées et aux attractions. |
| Réplique | 1 | 1 | Après absorption d’au moins 10 % des PV max, la prochaine Frappe gagne 40 % et ignore 25 Armure. |
| Mur aux flèches | 1 | 1 | Le premier projectile reçu sous Garde inflige 50 % de dégâts au bouclier et ne pousse, n’attire ni ne retire de PM. |
| Bouclier brisé | 1 | 1 | Si Garde est détruite par un ennemi, la prochaine Percée gagne 1 portée et ignore les pénalités d’engagement. |
| Bastion mobile | 1 | 1 | Percée sous Garde consomme 20 % de sa valeur actuelle, pousse les ennemis adjacents et inflige la valeur consommée, plafonnée à 8 % des PV max. |
| Contre d’Éaque | 2 | 10 | La première attaque de mêlée frontale reçue sous Garde demande une Frappe automatique à 70 %, une fois avant la prochaine activation. |
| Rempart des Myrmidons | 2 | 13 | Garde crée devant Achille une ligne temporaire de trois cases : bloque les projectiles, +1 PM de traversée ennemi, expire à la prochaine activation ; Garde personnelle -25 %. |
| Sommet Colère | 3 | 13 | Les bonus conditionnels augmentent de 15 % de leur valeur ; Pas victorieux répond à toute élimination offensive. |
| Sommet Chiron | 3 | 13 | Tir gagne 1 portée maximale et les conditions de déplacement demandent une case de moins, minimum une. |
| Sommet Rempart | 3 | 13 | Garde gagne 20 % ; les seuils de 10 % passent à 8 % des PV maximum. |
| Prédateur du champ de bataille | 1 | 14 | Après Frappe, le prochain Tir ignore sa portée minimale et gagne 25 % ; après Tir, la prochaine Frappe gagne portée 2 et 25 %, une fois par relation et activation. |
| Vengeur d’airain | 1 | 14 | Les dégâts absorbés par Garde (plafond 15 % PV max) deviennent un bonus brut pour la prochaine Frappe ; une élimination restaure 25 % de la Garde initiale, une fois par activation. |
| Sentinelle du Pélion | 1 | 14 | Le premier projectile neutralisé ou fortement réduit par Garde demande un Tir de réponse à 60 % si une ligne de vue valide existe. |
| Fléau des Troyens | 1 | 14 | La première élimination offensive de l’activation demande une Frappe à 50 % sur une cible adjacente valide, une fois par activation. |
| Trait du destin | 1 | 14 | Après Percée, Tir peut calculer portée, ligne de vue et origine depuis la case de départ ou d’arrivée ; le choix est prévisualisé. |
| Le héros invincible | 1 | 14 | À l’activation suivante, si Garde subsiste, choisir entre en conserver 50 % comme nouveau bouclier ou convertir le reste pour la prochaine Frappe, jamais les deux. |

## Équipements, reliques et préparation

Le catalogue de Catabase contient 16 équipements, 8 reliques et les 2 consommables de départ déjà présents. Il est séparé du catalogue des autres personnages. Achille conserve ses 2 potions et son parchemin initiaux.

Économie V0 de la Catabase : 120 drachmes au départ, puis 60 par victoire. L’étape de Chiron est accessible dans le bilan des deux premières salles. La forge augmente de 20 % par palier les bonus de caractéristiques positifs d’une pièce, jusqu’à +2, sans modifier ses malus ni les PV actuels. Les trois leçons au maximum n’ignorent jamais les prérequis de niveau.

| Objet | Type | Effet |
|---|---|---|
| Xiphos de Pélée | Équipement | +15 % Prouesse, +20 % Frappe, -15 % Garde. |
| Kopis brise-ligne | Équipement | +10 % Prouesse ; +20 % contre une cible déplacée ou entrée en collision pendant l’activation. |
| Arc du Pélion | Équipement | +12 % Prouesse ; Tir gagne 1 portée maximale et sa portée minimale devient 3. |
| Arc court de Scyros | Équipement | +10 % Prouesse ; Tir gagne 25 % à 4 cases ou moins et perd 1 portée maximale. |
| Bouclier-lame d’Éaque | Équipement | +10 % PV max, +10 % Prouesse, +15 % Garde. |
| Cuirasse de Phthie | Équipement | +20 % PV max, +30 Armure, -10 % Prouesse. |
| Linothorax des Myrmidons | Équipement | +10 % PV max, +20 Armure ; Percée gagne 1 portée après un déplacement préalable d’au moins 2 cases. |
| Pectoral du duelliste | Équipement | +10 % PV max, +25 Armure ; Frappe gagne 20 % après une perte de PV depuis la précédente activation. |
| Mantelet du chasseur | Équipement | +10 % PV max, +10 % Prouesse ; Tir gagne 15 % après une dépense d’au moins 2 PM. |
| Cuirasse des vagues | Équipement | +15 % PV max ; Garde +25 % contre projectile et -15 % contre mêlée. |
| Bracelet de Thétis | Équipement | +20 % PV max, +20 % Garde. |
| Sceau de Pélée | Équipement | +15 % Prouesse ; +15 % Frappe contre une cible au-dessus de 50 % PV. |
| Nœud de Phthie | Équipement | Percée gagne 1 portée ; -10 % PV max. |
| Ferret de Chiron | Équipement | +12 % Prouesse ; +20 % Tir à 6 cases ou plus. |
| Broche de Patrocle | Équipement | +15 % PV max, +10 % Prouesse ; +15 % Frappe après destruction de la Garde. |
| Aigrette des Myrmidons | Équipement | +10 % PV max, +12 % Prouesse, +2 Initiative. |
| Cendres de Patrocle | Relique | Le premier ennemi infligeant au moins 15 % des PV max devient la Vengeance : +25 % dégâts et +25 % Garde contre lui. |
| Clou d’Héphaïstos | Relique | Une collision provoquée retire 40 Armure ; la prochaine Frappe touche la case derrière pour 50 %. |
| Pas du Centaure | Relique | Après Percée, le prochain Tir ignore sa portée minimale et gagne 15 % dégâts, une fois par activation. |
| Miroir d’Athéna | Relique | Le premier projectile entièrement absorbé par Garde est renvoyé à 50 %. |
| Éclat du Pélion | Relique | Si Frappe et Tir sont utilisés dans la même activation, la seconde gagne 25 % et ignore 25 Armure. |
| Ancre de Thétis | Relique | Percée avec Garde active consomme 30 % de la Garde, inflige cette valeur autour de l’arrivée et pousse d’une case, une fois par activation. |
| Talon de Thétis | Relique | La première descente sous 25 % PV par combat accorde une Garde égale à 18 % des PV max. |
| Fil des Moires | Relique | Une fois par run, un coup mortel laisse 1 PV, accorde 20 % PV max de Garde puis détruit la relique. |
| Potion de soin mineure | Consommable | Rend 25 PV au héros sélectionné. Les potions identiques s’empilent par cinq. |
| Parchemin d’élan mineur | Consommable | Rend 1 PA au héros sélectionné. Les parchemins identiques s’empilent par trois. |

## Persistance et intégration

Le snapshot d’inventaire et d’équipement est en version 5. Il conserve progression du champion, points non dépensés, choix de maîtrises, PV, Gloire, tirages de récompenses et de marchand, achats, forge, drachmes et priorités de réactions. Un ancien snapshot d’XP de sorts est refusé explicitement pour un champion ; les progressions historiques des autres personnages restent prises en charge.

Les cartes, sprites, cinématique et le parcours actuel de trois salles restent les ressources de production. Les écrans utilisent les données runtime ; les options de déplacement facultatif restent des choix explicites sur les cases légales. Les barrières temporaires n’altèrent pas les terrains authored.

Les chiffres constituent un réglage V0, pas une conclusion d’équilibrage définitif. Les tests vérifient les règles, les interactions et les transactions ; le ressenti de difficulté doit être affiné en jouant la Catabase.
