# Comparaison avec Dungeon Draft : diagnostic et décisions proposées

## 1. Deux objets différents à auditer

**Le catalogue Godot et le laboratoire consommable V1 ne décrivent pas le même jeu.** Les conclusions ci-dessous indiquent leur périmètre. Une absence dans le simulateur n'est pas une absence dans le moteur ; une mécanique écrite dans le moteur n'est pas une preuve de son bon fonctionnement en partie.

| Périmètre | Lecture effectuée | Portée de la preuve |
|---|---|---|
| Cartes Godot | 60 définitions de base, 28 d'initiation, 24 avancées ; fabrique des sorts et modificateurs | Contrats statiques, sans exécution moteur. Les anciennes définitions `s_*` de sauvegarde sont exclues. |
| Classes Godot | Passifs de quatre classes et douze spécialisations | Conditions et bonus dans `class_card_modifier.gd`. La spécialisation remplace le passif de classe dans cette branche ; elle ne s'y ajoute pas. |
| Bestiaire Godot | Évolution des familles, rôles spécialisés, ajouts de l'écosystème de cartes, Pâris | Composition et règles de sorts. Pas de nouvelle validation de l'IA ou de l'interface. |
| Terrain Godot | Table d'interactions et branche de résolution des surfaces dynamiques | Présence des réactions ; accessibilité de chaque combinaison par les cartes non démontrée. |
| Proposition V1 | 48 familles, passifs, améliorations et règles du modèle ; huit séquences exécutées | Résultats du modèle indépendant seulement. Ni équilibrage Godot ni taux de victoire joueur. |

L'[inventaire](INVENTAIRE_LOCAL.md) donne les définitions locales avec leur fichier et leur ligne. Les contrats externes et leurs références figurent dans les [lectures comparées](LECTURES_COMPAREES.md).

## 2. Ce que nous avons déjà et devons préserver

### Des bases de classe cohérentes

Les quatre boucles d'initiation ne sont pas vides :

- Assassin : marquer puis exploiter l'ouverture ; se déplacer puis frapper.
- Gardien : produire de la garde puis frapper ; déplacer une cible puis la punir.
- Arpenteur : ralentir et repousser pour maintenir sa distance.
- Thaumaturge : appliquer un état, grouper les adversaires, employer une zone.

Le problème est leur développement. Beaucoup de cartes avancées augmentent l'intensité du même geste au lieu d'ajouter un usage à la préparation. Kasaï donne plusieurs débouchés à ses auras ; Pikuxala transforme le déplacement en moteur d'effets ; le Roublard réutilise les mêmes pièces avec plusieurs commandes. Ce sont des comparaisons de structure, pas une demande de copier ces classes.

### Un bestiaire plus riche que les sept archétypes du laboratoire

| Élément existant dans Godot | Décision qu'il crée | Ce que la V1 doit représenter avant un nouvel équilibrage global |
|---|---|---|
| Conducteur de la chasse + Molosses | Tuer le soutien, éviter la cible marquée ou casser l'engagement des chasseurs | Marque de groupe, disparition avec sa source, déplacement des poursuivants. |
| Oracle | Retirer un renforcement en éliminant sa source | Distinguer réduction des PV ennemis et suppression d'une menace future. |
| Porte-Égide | Rompre la formation de protection | Effet réel de la proximité, du déplacement forcé et du choix de cible. |
| Collecteur + Porteur d'obole | Empêcher l'arrivée d'un soutien fragile | Conditions de soin liées à une pièce vivante proche, et non soin inconditionnel. |
| Rejeton / Artilleur — Fournaise | Casser une ligne de vue ; pour le kit concerné, entrer dans la portée minimale | Intention, délai, revalidation de la cible, coût du déplacement pour y répondre. |
| Exécuteur — Sentence du bronze | Quitter le contact pendant la préparation | Valeur d'un PM économisé, d'une poussée et d'une carte de mobilité. |
| Appel du passeur | Occuper la dalle annoncée pour annuler l'invocation | Réponse sans dégâts et possibilité de payer en position plutôt qu'en copies. |
| Fondeur / Tisseuse | Lire les zones et les trajectoires | Effets de début d'activation et d'entrée, interaction avec déplacements forcés. |
| Pâris | Préparer une transition et conserver de quoi finir le combat | Deux formes dans la branche lue, retour des PV à la transition, sorts et compagnons ; aucun équivalent complet dans le boss simplifié V1. |

Références locales : [évolution des monstres](../../../core/expedition/catabase_monster_evolution_catalog.gd), [écosystème des ennemis](../../../core/expedition/card_enemy_ecosystem.gd), [rencontres et Pâris](../../../core/expedition/catabase_monster_encounter_catalog.gd), [Sentence du bronze](../../../data/spells/enemies/catabase_execution.tres), [Fournaise](../../../data/spells/catabase_monsters/braise_fournaise.tres).

Les soins et les invocations comportent déjà des limites dans les branches lues. Il faut les conserver : une run à stock fini supporte mal une génération infinie d'ennemis ou de PV. Les références Death Shepherd et Aetera montrent ce que ces mécaniques peuvent apporter ; elles ne justifient pas de retirer nos garde-fous.

### La chimie du terrain existe déjà

Le résolveur actuel définit quatre interactions : feu/eau, feu/glace, glace/eau et foudre/eau. Le service possède aussi des comportements propres aux surfaces, dont l'eau électrifiée. La résolution du choc dans la branche lue emploie une constante de 20 dégâts : vérifier sa pertinence dans la progression réelle avant de s'en servir comme récompense de combo.

**L'écart réel :** le laboratoire V1 n'intègre pas cette table, et l'inventaire des cartes ne garantit pas un accès cohérent à toutes ses entrées. Le prochain prototype devrait employer les services de terrain existants et préciser les cas accessibles, pas implémenter une seconde chimie parallèle.

## 3. Redondances et manques établis

### 3.1 Identité : beaucoup de vocabulaire commun, peu de règles exclusives

Après une normalisation volontairement simple — variantes élémentaires d'une attaque regroupées, par exemple — **neuf familles d'effets existent dans les quatre classes** : attaque directe, attaque de zone, garde, marque, déplacement, attraction, poussée, ralentissement, affaiblissement.

Le comptage n'évalue ni portée, ni coût, ni synergie. Partager une poussée n'est pas un problème. Le risque apparaît si le passif n'en change presque jamais l'usage. Les spécialités Godot lues ajoutent surtout des bonus conditionnels : cible marquée, déplacée, ralentie, distance, PV bas, mouvement préalable. La V1 introduit déjà quelques autres réponses — PM, riposte, garde après état — qu'il faut distinguer de cet état actuel.

**Direction :** conserver les outils d'autonomie communs, mais donner à chaque classe un fait à créer puis deux manières de l'exploiter. Exemple : une position de retour pour l'Arpenteur ; une garde que le Gardien peut préserver ou convertir ; une marque qui organise la prochaine cible pour l'Assassin ; un terrain que le Thaumaturge peut transformer ou laisser agir.

### 3.2 Des noms promettent parfois une autre fonction

| Nom local | Contrat réellement lu | Conséquence pour la conception |
|---|---|---|
| G Sectionner les tendons `a_disarm` | Dégâts et retrait de PA | N'est pas le poison de déplacement de Divinity. Évaluer le vrai rôle avant de compter « saignement de déplacement » comme couvert. |
| G Briser l'incantation `g_silence`, Dissonance `t_disrupt` | Retrait de PA à l'activation suivante | N'annule pas directement un sort annoncé. Le joueur doit pouvoir prévoir si les PA restants suffisent quand même. |
| G Chant du Léthé `t_charm` | Attraction et −1 PA ; aucun changement d'équipe | Ne pas le comparer à une domination. Un nom narratif convient si la fiche est parfaitement explicite. |
| G Entrave de bronze / Filet du chasseur | Retrait de 2 PM | N'est pas une immobilisation absolue. La valeur dépend des PM et de la distance de la cible. |
| V1 Entaille tenace `a03` | Impact physique puis dégâts de brûlure résolus dans le canal magique du modèle | La continuité avec le saignement physique Godot n'est pas acquise. Choisir et afficher cette identité avant de construire résistances et équipements. |
| V1 Couper le souffle `a08` | Affaiblit le prochain impact ; effet réduit contre boss | Ce n'est ni un retrait de PA ni une interruption. C'est un troisième contrat. |

### 3.3 Deux exemples nets de progression verticale dans la V1

| Comparaison, sans amélioration | Différence | Diagnostic |
|---|---|---|
| `g03` Repousser / `g06` Choc de masse | Même coût de 2 PA, portée de contact et poussée 2 ; dégâts 0,80 / 0,90 P | Au même contexte et avec les copies disponibles, l'élite est meilleure sans décision différente. La rareté et la revente peuvent justifier une réserve de consommables ; elles ne créent pas un nouveau style de combat. |
| `r04` Volée croisée / `r06` Pluie de pointes | Même coût de 3 PA, même croix ; 0,60 / 0,85 P et portée maximale 4 / 5 | Progression verticale claire. Un autre dessin de zone ferait choisir selon la formation plutôt que selon la seule rareté. |

Ce ne sont pas les mêmes doublons dans Godot : par exemple `g_push` et `g_crush` n'y ont pas le même coût. Le diagnostic ne doit pas glisser d'un catalogue à l'autre.

### 3.4 Améliorer un sort devrait parfois changer sa décision

**33 cartes sur 48** ont une amélioration V1 constituée du seul champ `damage`. C'est **68,75 %**. Les autres améliorations sont principalement des valeurs, portées et durées.

En comparaison, les améliorations Godot peuvent prolonger la garde, franchir un obstacle ou ignorer la ligne de vue. Ce sont déjà des changements qualitatifs, mais une règle générale « ignore la ligne de vue » peut effacer trop de contraintes d'arène. Il vaut mieux choisir les sorts concernés et les nouveaux problèmes qu'ils résolvent.

La leçon de Seek, Catalyst ou Body Slam n'est pas d'ajouter davantage de puissance partout. Une amélioration peut permettre de sélectionner un outil, de conserver une ressource ou d'en changer la conversion. Elle doit être comparée à son coût de préparation, pas évaluée uniquement sur un mannequin.

### 3.5 Fiabilité des mains : le plafond de 30 cartes peut étouffer les combos

Hypothèse : pioche uniforme de cinq cartes sans remise, trois copies de A et trois copies de B, pas de mulligan ni sélection. Pour obtenir au moins une de chaque :

`Pr(A et B) = 1 − 2 × C(N−3, h)/C(N, h) + C(N−6, h)/C(N, h)`.

| Taille du deck | Main de 5 | Main de 6 |
|---:|---:|---:|
| 15 | 51,45 % | 64,76 % |
| 30 | 16,53 % | 22,96 % |

Calcul exact, contrôlé par énumération de toutes les mains. Ce ne sont pas des probabilités de réussite de run. Les tours suivants dépendent de la consommation, des défausses et du reste de la pioche ; ils ne sont pas indépendants.

**Conséquence :** ajouter des cartes augmente la réserve mais peut réduire fortement la disponibilité du plan. Le jeu doit présenter clairement la différence entre réserve de run et cartes préparées pour le combat. Une carte de sélection ou une règle de conservation peut valoir davantage qu'une nouvelle attaque. Rendre tous les moteurs dépendants de deux outils rares serait particulièrement fragile.

## 4. Vérification de huit séquences V1

Exécution du modèle de référence à **P = 40**, sans équipement, relique, amélioration, résistance ni action ennemie. Une cible survivante. Le Gardien sans spécialisation sert à isoler les effets, sauf la ligne Bastion ; son passif de riposte n'intervient pas dans ces séquences. Il ne s'agit donc pas des dégâts complets d'un build Assassin.

| Séquence / carte | PA | Copies consommées | Dégâts | Garde restante | Lecture |
|---|---:|---:|---:|---:|---|
| Ouvrir la garde → Frapper la faille | 3 | 2 | 92 | 0 | La marque consommée et le bonus conditionnel se cumulent : 0,35 + 0,45 + 0,95 + 0,55 = 2,30 P. |
| Garde ferme → Heurt du rempart | 4 | 2 | 60 | 46 | Le bonus demande de la garde mais ne la consomme pas. |
| Garde ferme → Répercussion | 4 | 2 | 47,6 | 0 | La garde devient dégâts, mais le total est inférieur au duo précédent au contact. |
| Même duo, spécialisation Bastion | 4 | 2 | 54,5 | 0 | Le bonus de garde améliore la conversion, sans inverser cette comparaison de dégâts au contact. |
| Repousser | 2 | 1 | 32 | 0 | Pousse de deux cases si l'espace le permet. |
| Choc de masse | 2 | 1 | 36 | 0 | Même déplacement, rendement supérieur. |
| Volée croisée, une cible à distance 3 | 3 | 1 | 24 | 0 | Zone en croix. |
| Pluie de pointes, même situation | 3 | 1 | 34 | 0 | Même zone, portée maximale supérieure. |

Sortie détaillée : [calculs_comparatifs.json](calculs_comparatifs.json). Les actions passent par la vérification de légalité du modèle ; elles ne sont pas seulement des multiplications écrites dans le rapport.

### Ce que dit exactement le cas Répercussion

Avec `G` points de garde, son coefficient est `0,50 + min(1,20 ; 0,60 × G/P)`. Tous les points de garde sont supprimés. Pour dépasser les `1,50 P` du Heurt sous garde, il faut `G > 1,6667 P`. Même alors, la défense perdue a une valeur et le bonus plafonne.

La carte conserve des usages : portée 1–3 au lieu du contact ; garde obtenue autrement ; fin de combat où la défense ne sert plus ; cible prioritaire inaccessible. **Elle n'est donc pas strictement dominée partout.** Mais la recette naturelle avec Garde ferme ne paie pas sa contrepartie au contact. C'est une priorité de prototype plus concrète que « ajouter de la synergie au Gardien ».

## 5. Huit propositions à prototyper, avec un périmètre limité

Ces propositions ne modifient pas le manifeste V1. Les chiffres sont des points de départ explicites, pas un nouvel équilibrage validé. Une seule évolution par prototype pour pouvoir mesurer sa contribution.

| Priorité / proposition | Contrat de départ proposé | Intérêt et critères de vérification |
|---|---|---|
| P0 — Répercussion `g09` | 2 PA, portée 1–3 ; 0,70 P + 1,50 × garde consommée ; consomme **au plus 0,80 P** de garde, conserve l'excédent. | Avec Garde ferme : 1,90 P de dégâts et 0,35 P de garde, soit 76 et 14 à P40, calcul algébrique non simulé. Choix face à Heurt : +16 dégâts contre −32 garde. Vérifier portée, résistances, garde d'équipement, durée, et absence de conversion multiple d'un même point. |
| P1 — Différencier Choc de masse `g06` | 2 PA, contact, 0,65 P, poussée 1 ; si la poussée est arrêtée par un obstacle fixe, donne 0,30 P de garde une fois. | Rend les murs utiles au Gardien. Le déclencheur doit distinguer obstacle, unité, bord et boss ; ne pas assimiler « aucun déplacement possible » à « collision réussie » sans règle explicite. Comparer aux deux cases de Repousser sur une carte ouverte et une carte encombrée. |
| P1 — Différencier Pluie de pointes `r06` | 3 PA, portée 2–5, 0,70 P sur une ligne de trois cases orientée depuis le lanceur, une seule fois par cible ; ligne de vue normale. | Concurrence la croix par la géométrie. Prévisualisation obligatoire ; vérifier obstacles et orientation diagonale avant adoption. Une cible isolée doit rester mieux traitée par une vraie attaque monocible. |
| P1 — Préparation de main | À la préparation du combat, choisir une copie comme première carte de la main ; elle occupe un des cinq emplacements et est retirée de la pioche. Les quatre autres sont piochées normalement. | Stabilise un moteur sans créer ni dupliquer une carte. Comparer à la règle actuelle pour decks 15/20/30, surveiller l'ouverture automatique avec une rare dominante. Si elle écrase les choix de deck, préférer une rétention limitée plutôt qu'additionner les deux. |
| P2 — Arpenteur, ancre de repli | Prototype de capacité de classe remplaçant son passif : mémorise la case de départ du tour ; après un tir à distance 3+, autorise un retour vers cette case pour 1 PM, une fois, si libre et à trois cases au plus ; ne rembourse ni PA ni copie. | La case initiale devient une décision. Définir explicitement franchissement des obstacles et effets d'arrivée ; tester déplacement forcé, case occupée et menace préparée. Comparer au +1 PM actuel de la V1, ne pas cumuler les deux par défaut. |
| P2 — Assassin, transmission de la marque | Prototype remplaçant le bonus de classe : première élimination directe d'une cible marquée du tour, possibilité de transmettre la marque à un ennemi dans les deux cases de la victime ; valeur mémorisée avant sa consommation, durée 1 phase, aucun cumul. | Donne un choix de prochaine cible au lieu d'un bonus générique. Comparer à l'Assassin actuel contre isolé, groupe et boss ; vérifier qu'une élimination multiple ne transmet qu'une marque et que l'action basique ne déclenche pas. |
| P2 — Thaumaturge, une réaction accessible | Construire un kit d'essai avec un générateur d'eau commun et les sorts de feu/givre existants, branchés sur le service de terrain Godot. Fixer le coût seulement après avoir mesuré extinction, fonte et gel sur trois cartes. | Le prototype doit prouver au moins deux usages distincts de l'eau sans exiger de rare. Vérifier surface de base versus dynamique, propriétaire, durée, dégâts alliés, et si les interfaces montrent le résultat avant consommation. Ne pas inventer de propriété de vapeur absente de la définition. |
| P2 — Dueliste ennemi à parade lisible | Première attaque physique directe reçue entre deux activations : réduction de 0,40 P de référence, puis parade dépensée. Pas d'annulation de statut ou de déplacement associé. | Encourage l'ordre des impacts, offre une réponse par attaque basique, magie ou terrain. La parade doit être visible avant la dépense et plafonnée ; mesurer si elle rend les petits consommables injustement mauvais. |

### Ordre de travail recommandé

1. **Porter les rencontres représentatives existantes dans le laboratoire**, avant de conclure que nos cartes de placement sont trop faibles : préparation à interrompre, soutien à isoler, dalle à occuper, danger de terrain, transition de boss.
2. Réparer les rôles manifestement proches ou mal rémunérés : Répercussion, Choc de masse, Pluie de pointes.
3. Mesurer la fiabilité du plan avec la préparation de main. Ne pas ajouter simultanément sélection gratuite, rétention et pioche supplémentaire.
4. Essayer un seul moteur identitaire à la fois, avec ses cartes communes disponibles au départ et ses interactions rares optionnelles.
5. Ajouter une réaction ennemie seulement lorsque ses informations et ses réponses ordinaires sont lisibles.

Ce programme doit aboutir à des changements de décision observables, pas seulement à des dégâts moyens plus élevés.

## 6. Contraintes propres à notre drop de cartes sur les monstres

La règle demandée reste le **drop de sacs et de cartes sur les mobs**, avec abondance croissante des communes et raretés supérieures moins fréquentes. Les références étudiées n'obligent ni à apprendre automatiquement une technique à chaque ennemi tué, ni à remplacer cette économie par des récompenses de deckbuilding classiques.

Conséquences des sorts pour cette économie :

- Le générateur d'un moteur de classe doit être commun, disponible dans le départ ou très régulièrement fourni. Un finisseur rare peut enrichir le plan, pas en être l'unique raison de fonctionner.
- Si un sort produit une carte, préciser **copie existante déplacée**, **effet temporaire non vendable**, ou **nouveau bien économique**. Ces trois objets ne doivent pas partager silencieusement les mêmes règles.
- Une invocation ennemie ne doit pas permettre une ferme infinie de sacs. Décider explicitement si le butin dépend du groupe initial ; ne pas laisser le gain dépendre sans plafond des renforts créés.
- Un monstre qui bloque, soigne ou se ressuscite consomme indirectement des copies. Le budget d'une rencontre doit inclure ce surcoût, même si ses dégâts directs sont faibles.
- Les objectifs de style peuvent plus tard modifier le drop, mais ne doivent pas retirer les cartes communes nécessaires lorsque le joueur échoue à un challenge optionnel.
- Une réponse tactique par PM, ligne de vue ou interaction d'arène est particulièrement précieuse : elle récompense l'apprentissage sans toujours prélever une carte.

## 7. Ce qu'il reste à mesurer en jeu

Pour chaque prototype, relever : fréquence de choix quand l'outil est disponible ; copies dépensées par menace supprimée ; actions ennemies évitées ; déplacements utiles ; situations où la carte est morte ; délai jusqu'au premier combo ; décisions réellement différentes entre classes. Les taux de victoire seuls masqueraient les cartes rares conservées indéfiniment ou les plans répétitifs.

Comparer au minimum cinq situations : cible isolée, groupe dispersé, formation avec soutien, attaque préparée, boss avec transition. Varier la taille du deck et le stock restant. Demander au joueur ce qu'il voulait accomplir avant de lui montrer le résultat, pour distinguer un effet mal équilibré d'un contrat mal compris.

**État de validation de ce dossier :** lecture de code, recherche documentaire, comptages reproductibles, huit séquences du modèle et quatre probabilités exactes. Les pistes ci-dessus restent à mettre en prototype puis à tester dans le moteur avec des joueurs. Aucune popularité de classe, satisfaction ou viabilité générale de run n'est déduite des seuls calculs.
