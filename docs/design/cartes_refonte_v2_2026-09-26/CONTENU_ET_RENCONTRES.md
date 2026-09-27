# Contenu, rencontres et calibration

## 1. Périmètre complet du profil

48 familles et leurs améliorations, quatre classes, huit spécialisations, 18 équipements, huit reliques. Les définitions complètes sont dans [CATALOGUE.md](CATALOGUE.md) et [manifest.json](manifest.json). Les anciens catalogues Godot restent affectés aux anciennes runs ; aucun mélange automatique de leurs 112 définitions avec ce pool.

23 familles changent par rapport à V1, sans ajout de famille ni changement de rareté. Les pools économiques restent comparables. Réutiliser les illustrations et VFX existants lorsqu'ils décrivent le bon effet ; une image commune n'impose pas de réutiliser un ancien identifiant ou ses coefficients. Eau, ligne de trois cases et retour d'ancre exigent des aperçus adaptés.

Départs conseillés : ceux du manifeste. Pour le Thaumaturge, Standard conserve givre/braise/sceau/garde/pas ; Terrain remplace le sceau par Onde du Léthé. Le premier conserve davantage de dégâts préparés, le second montre la transformation du plateau. Les presets ne sont pas des performances équivalentes démontrées.

## 2. Arbitrages qui ferment les propositions antérieures

| Sujet | Retenu dans V2 | Conséquence |
|---|---|---|
| Répercussion | Choix du sacrifice, coefficient 1,50, cap de sacrifice 0,80 P, base 0,70 P | Abandon du « confort seul » à l'ancien coefficient pour ce candidat ; comparer les résultats sans mélanger les deux versions. |
| Transfert de marque | Spécialisation Relais, pas carte à 1 PA | Pas de copie de préparation supplémentaire ; valeur/durée/provenance bornées. |
| Arpenteur | Ancre remplace le PM de classe ; Tir de relais remplace Trait tendu | Aucune addition implicite de trois remboursements de mouvement. |
| Accès au plan | Une normale en ouverture + rétention via une amélioration de Garde brève | Pas de grande main globale ni nouvelle carte de filtrage. |
| Thaumaturge | Eau normale et transformations via deux sorts normaux existants | Accès au terrain avant les rares ; mêmes 48 familles. |
| Condensation | Non intégrée | La conversion proposée n'était pas suffisamment rémunérée ; extinction/vision assurent un rôle distinct à l'eau. |
| Génération de cartes | Aucune création d'exemplaires permanents ou de jetons dans ce candidat | Conservation de l'économie et du plafond par famille. |
| Compagnons, nouvelle jauge | Non intégrés dans cette refonte | Le contrôle du plateau est éprouvé avec les ressources existantes. |
| Raretés extraordinaires | Effets V1 conservés, fonctions essentielles assurées par normales | Aucune rencontre ne requiert une rare particulière. |
| Pression | Formule V1 gardée pour comparaison, affichage renforcé | Son réglage reste une question de calibration après test, pas une mécanique cachée. |

## 3. Route et pédagogie des douze combats

Budgets, niveaux, XP et compositions numériques viennent du manifeste. Les variantes ci-dessous changent le comportement indiqué, pas les PV/ATK de base. Aucun ancien correctif `card_enemy_ecosystem` n'est ajouté par-dessus ce profil.

| Combat / profondeur | Épreuve et règle | Ce que le joueur doit pouvoir apprendre |
|---|---|---|
| 1 / 1 | Brute, terrain simple | Dépenser une copie, compléter avec un secours, voir ce qui reste. |
| 2 / 2 | Brute + archer, piliers | Distance, ligne de vue et usage d'un déplacement. |
| 3 / 3 | Dernière brute = Exécuteur préparé | Sortir de la case annoncée ou déplacer l'ennemi, avant le premier marchand. |
| 4 / 5 | Presse ; Lamie = soutien avec ligne de vue | Isoler le soutien, exploiter la ligne dangereuse. |
| 5 / 6 | Sablier ; groupe mixte | Payer pour différer une menace, préserver une sortie. |
| 6 / 8 | Jardin | Déplacer le centre ou les victimes d'une zone. |
| 7 / 10 | Porte-égide en formation | Briser une condition spatiale de protection. |
| 8 / 12 | Convoi | Éliminer ou interrompre les porteurs avant sacrifice, avec conséquence de butin visible. |
| 9 / 13 | Réservoirs | Investir des PA puis choisir le moment d'une décharge. |
| 10 / 15 | Porte-égide avec parade finie | Choisir l'ordre des impacts ou le canal ; aucune immunité de classe. |
| 11 / 17 | Jardin, groupe mobile | Préparer le boss en conservant des fonctions offensives. |
| 12 / 20 | Pâris en deux phases | Traverser une transition sans croire le combat terminé ni réinitialiser ses ressources. |

### Précisions de comportement

**Exécuteur C3.** PV, attaque et PM de la brute remplacée. Activation impaire : se rapproche si nécessaire, puis désigne la case du héros s'il est au contact ; aucune attaque ce tour-là. Activation suivante : frappe la case désignée à 1,5 ATK si elle est encore au contact de sa position et occupée par le héros ; sinon attaque perdue. Il ne se déplace pas lors de cette résolution. S'il n'avait pu préparer aucune case, il reprend l'approche au lieu d'inventer une frappe. L'intention indique case, échéance et dégâts. Un déplacement du héros ou de l'exécuteur peut l'annuler.

**Soutien C4.** Sur ses activations impaires, la Lamie protège un autre allié à trois cases ou moins avec ligne de vue ; bénéficiaire = plus faible ratio PV, puis UID. Garde 0,40 P de rencontre jusqu'à sa prochaine activation. S'il n'existe aucun bénéficiaire, attaque normale. Activations paires : attaque normale. Cette protection remplace l'action offensive de l'activation concernée.

**Porte-égide C7.** Protection des alliés à une case, jamais lui-même, uniquement sans héros adjacent. 0,25 P de rencontre par allié ; dure jusqu'à sa prochaine activation. Les gains successifs ne s'empilent pas. Sa résistance personnelle V1 reste ; l'ancien soutien de groupe est remplacé, pas doublé.

**Parade C10.** Première attaque physique directe de carte ou de secours entre deux activations : réduit de 0,40 P de rencontre, au plus les dégâts de cet impact, puis perd sa charge. La réduction est appliquée avant résistance/garde. Les dégâts magiques, terrain et saignement ne la consomment pas. Déplacement/statut de la carte restent applicables. Pas de contre-dégâts ni annulation complète du tour ; pas de bonus de formation C7 ajouté.

**Pâris C12.** Un seul pool de PV total V1, seuil à 50 %. L'UI peut afficher deux segments mais les conditions « cible à 35 % PV » portent sur le total. Franchir le seuil change sa forme au terme de l'action ; les dégâts excédentaires sont déjà retranchés, aucun soin. Une attaque peut traverser les deux segments et le tuer. Même UID, un seul décès, pas de récompense de transition ; effets, garde et compteurs du héros restent.

Phase 1 : toutes les trois activations (1,4,7…), annonce une ligne orthogonale de trois cases dans l'axe dominant vers le héros ; pas d'attaque ce tour. À l'activation suivante, frappe cette ligne fixe à 1,40 ATK, une fois par victime, sans déplacement. Les autres activations emploient l'attaque V1. Si la transition arrive avant résolution, l'annonce reste et se résout avant le comportement de phase 2. Phase 2 : attaque V1 suivie d'une poussée de une case du héros touché si possible ; aucun dégât de collision. Les accompagnants restent ceux du budget V1, sans ajout d'invocations.

Ces comportements sont des **définitions proposées**, pas des comportements observés dans le build courant. Le contrôle visuel, les déplacements et les transformations de Pâris réutilisent ses ressources existantes.

## 4. Premiers chiffres à surveiller

À P40, sans équipements, résistances ou passifs : Garde ferme donne 46 garde. Heurt du rempart inflige 60 en conservant la garde. Répercussion maximale sacrifie 32, inflige 76 et en laisse 14. Pour 16 dégâts supplémentaires, le joueur abandonne donc 32 de protection. La portée et l'élimination d'une menace peuvent rémunérer ce choix ; aucune supériorité universelle n'est revendiquée.

Tir de relais passe de l'ancienne attaque à 40 dégâts à 32, avec pioche conditionnelle. Dépenser un Pas latéral à 1 PA et sa copie pour activer ce bonus coûte réellement quelque chose ; les PM ordinaires ou une sortie nécessaire peuvent le rendre rentable. La pioche ne crée aucune copie.

Une cible marquée peut recevoir 60 dégâts de Frapper la faille à P40, avant le bonus propre de la marque. Le relais d'une marque plafonnée à 8 intervient seulement après un décès éligible. Il peut être inutile sur un boss seul et utile dans un groupe. Le gain doit être évalué après sur-dégâts et seuils de mort.

L'ouverture préparée augmente l'accès au duo mais occupe une place de main ; la rétention coûte le supplément de garde de l'amélioration et une place du prochain remplissage. Le test doit comparer l'ensemble de la séquence, pas seulement la probabilité de voir une carte.

## 5. Critères de calibration, pas de faux résultats

Une première passe doit couvrir chaque classe/spécialisation avec les mêmes graines, puis les deux presets du Thaumaturge. Mesurer : victoire, cause de mort, tours, copies consommées par fonction, garde utile, achats ciblés, dégâts évités par placement, activations sans action utile et rares gardées jusqu'à la défaite.

Les anciens 640, 120 et 440 runs restent des résultats **V1**. Ils ne valident pas les nouveaux arrondis, passifs, surfaces, adversaires ou ouvertures. Le dossier livré vérifie la cohérence de conception et les microcalculs ; les campagnes moteur appartiennent aux lots d'implémentation.

Avant ajustement global, inspecter les premières défaites des combats 1–3 et les écarts de budget sur les variantes C4/C7/C10. Une nouvelle réaction peut rendre un personnage plus économique dans une salle et moins dans une autre ; ne pas compenser automatiquement chaque écart par des dégâts gratuits.
