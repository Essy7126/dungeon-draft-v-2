# Audit approfondi de Catabase — règles, construction et décisions

23 septembre 2026. Analyse du code sur HEAD `ad1f4c58` avec modifications de travail concurrentes, notamment les salles tactiques. Aucune modification du gameplay effectuée pour cet audit. Les constats ci-dessous distinguent **fait de code**, **calcul**, **risque de conception** et **hypothèse à tester**.

Les deux dossiers de références accompagnent celui-ci : `enquete_gameplay_2026-09-23_references.md` et `enquete_gameplay_2026-09-23_ankama_larian.md`. Le premier rapport `gameplay_benchmark_et_axes_2026-09-23.md` reste une première liste d'hypothèses ; ce nouvel audit fait autorité pour nos conclusions de cette enquête.

## 1. Diagnostic principal

Le jeu possède déjà une base tactique substantielle : placement, collisions, terrain, familles ennemies, économie de run, rétention et recomposition. Le problème le plus documenté n'est pas un manque brut de sorts. C'est la différence entre **diversité de paramètres** et **diversité des décisions de construction**.

Le mode Cartes donne 112 familles mais ses douze spécialisations reposent principalement sur un bonus de dégâts ou de garde au premier déclenchement admissible. Le mode Classique possède, lui, des objets et ressources persistants plus structurants : disque à rappeler, braise à déplacer, urne à remplir puis dépenser. Il serait dommage de chercher uniquement à l'extérieur des mécanismes déjà amorcés ici.

Cette lecture ne prouve pas que Cartes est ennuyeux ou déséquilibré. Elle identifie les endroits où des tests joueurs doivent départager des hypothèses précises. Aucun taux de victoire représentatif, aucune durée médiane de run et aucune préférence de classe n'ont été mesurés dans cette tâche.

## 2. Ce qui a été inspecté et exécuté

Lecture de README et des références courantes, puis des catalogues, générations de sorts, modificateurs, règles de deck, butin, équipement, progression, dégâts, états d'unités, ennemis et salles. Points d'entrée principaux :

| Sujet | Sources locales et symboles |
|---|---|
| Classes, spécialisations, sorts | `core/expedition/class_card_catalog.gd` : CLASSES, SPECS, ROWS, make_spell |
| Initiation, raretés | `class_starter_catalog.gd`, `card_ecosystem_catalog.gd` |
| Conditions, passifs | `class_card_modifier.gd` : on_targets_resolved, on_cast_complete |
| Stase et surfaces | `card_ecosystem_effects.gd` : get_target_cell_failure_reason, surface |
| Deck, pioche, recomposition | `class_cards.gd`, `catabase_cards.gd` |
| Acquisition | `card_drop_catalog.gd` : factors, roll ; `class_cards.gd` : grant_loot, shop |
| Objets et runes | `class_equipment_catalog.gd`, `class_rune_catalog.gd` |
| Courbe de run | `catabase_route_v6.gd`, `data/runs/progression/odyssey/achilles_champion_progression_v0.tres` |
| Résolution | `core/damage_resolver.gd`, `core/spell_caster.gd`, `units/unit.gd` |
| Adversaires | `card_enemy_ecosystem.gd`, `catabase_monster_evolution_catalog.gd`, `catabase_monster_encounter_catalog.gd` |
| Classique | `catabase_first_six_spells.gd` et modificateurs associés |
| Salles en cours de modification | `card_tactical_room_catalog.gd`, `card_tactical_room_rules.gd`, `card_tactical_resource_rules.gd` |

Les noms abrégés du tableau sont sous `core/expedition/`, sauf indication contraire.

**Exécution réelle :** scène existante `res://tools/build_system_lab/card_catalog_audit.tscn` sous Godot 4.7.1, avec APPDATA/LOCALAPPDATA isolés. Elle a exporté les 112 cartes et effectué 7 200 tirages indépendants de butin, puis quitté avec code 0 en 28 secondes. Le journal contient néanmoins `ERROR: Failed to read the root certificate store.` : l'export est obtenu, mais cette exécution n'est pas qualifiée de validation moteur sans erreur. Aucun import complet ni test de combat n'a été exécuté dans cette enquête.

Preuves : `artifacts/dev/20260923-135932-enquete-catalogue-corrige-8cb2b8cd/` contient `cards.csv`, `report.json`, commande, journaux, résultat du processus et contexte Git. Une première invocation avec un argument d'isolation inadapté n'a pas produit le rapport et a expiré après 90 secondes ; ses traces sont conservées dans `20260923-135727-enquete-gameplay-catalogue-83ac9263`. Elle n'entre pas dans les résultats.

Commande moteur utile, exécutée par `Invoke-DevProcess` avec les variables d'environnement isolées :

```text
Godot_v4.7.1-stable_win64_console.exe --headless --path <dépôt> --log-file <répertoire-audit>/catalogue.engine.log res://tools/build_system_lab/card_catalog_audit.tscn -- output=<répertoire-audit>
```

Le CSV fournit coût, portée minimale/maximale, effet, valeur, dégâts à Prouesse 20 aux maîtrises 0/2/4, garde à maîtrise 2, recharge et restriction d'activation. **Les dégâts exportés sont avant armure, passifs et bonus conditionnels.** Les tirages utilisent aussi des combinaisons profondeur/type synthétiques : ils vérifient les formules, pas le déroulement de runs complètes.

## 3. Inventaire fonctionnel : ce que le nombre de cartes masque

Chaque classe a 28 familles publiques : 7 d'initiation, 15 usuelles, 4 rares et 2 épiques. Les anciennes cartes `s_*` sont conservées pour compatibilité ; elles ne sont pas comptées comme contenu public actuel.

| Familles d'effet | Nombre de cartes | Observation |
|---|---:|---|
| Déplacement / téléportation | 12 + 2 | Mobilité abondante, destinations et contraintes proches |
| Marque / bonus sur marque | 7 + 7 | Une boucle de préparation commune à plusieurs classes |
| Garde | 8 | Variantes de rendement/durée, peu de conversions propres à Cartes |
| Poussée / attraction | 8 + 7 | Bon socle pour des objectifs spatiaux |
| Saignement / brûlure | 4 + 2 | Usure de deux activations, pas d'empilement du même effet par la même source |
| Ralentissement / frost / ice_area / root | 4 + 2 + 1 + 2 | Plusieurs identifiants pour des réductions de mobilité |
| Champs feu / glace | 3 + 2 | Terrain temporaire, deux camps concernés |
| Stase | 2 | Un vrai saut d'activation, avec préparation et protection anti-répétition |

Les quatre premières lignes représentent 51 cartes, soit 45,5 % du catalogue. Cela **ne signifie pas 45,5 % de doublons** : placement et garde peuvent légitimement être communs. Le point à examiner est ce que chaque classe fait ensuite de ces outils.

Un regroupement du CSV par coût, portée, effet, valeur, dégâts/garde à maîtrise 2 et recharge trouve neuf groupes couvrant 23 cartes. Exemples :

- `a_step`, `r_step`, `t_step`, `i_a_step`, `i_r_step` : même déplacement à 1 PA vers deux cases selon cette signature.
- `a_escape`, `r_escape`, `t_escape`, `i_a_escape` : déplacement à 2 PA jusqu'à trois cases.
- `a_phantom`, `r_horizon` : téléportation à 2 PA jusqu'à quatre cases.
- `a_parry`, `r_guard` : garde de même profil.

Ce regroupement n'intègre pas tous les tags, types de dégâts, passifs et contextes d'acquisition. Les groupes mêlant physique/magique ne sont donc pas des équivalences complètes. Il s'agit d'une liste de revue, pas d'une liste de suppressions automatiques.

**Amélioration proposée :** conserver quelques outils universels lisibles, mais faire diverger leur conséquence : déplacement qui prépare un retour, déplacement qui protège une case, déplacement qui modifie la prochaine portée. Ne pas exiger une animation ou un nom différent pour masquer une même règle.

## 4. Les identités de classe : intentions et comportement

| Classe | Règle de départ | Spécialisations actuelles | Limite observée |
|---|---|---|---|
| Assassin | +20 % sur premier coup de contact contre cible isolée orthogonalement | Exécution sous 35 % PV ; déplacement préalable ; cible marquée | Trois conditions de dégâts, pas trois économies distinctes |
| Gardien | +20 % première garde | +40 % garde ; +30 % premier coup après perte de PV ; +35 % sur cible déplacée | Protection produite et protection utile peu différenciées dans le passif |
| Arpenteur | +20 % premier coup à distance ≥3 | +35 % à ≥4 ; +30 % après deux cases ; +30 % sur ralenti | Escarmoucheur proche de l'Embusqué ; rang de distance surtout numérique |
| Thaumaturge | +20 % premier coup magique sur marqué/ralenti | Feu +25 % ; glace +35 % ; zone +25 % si deux ennemis | École élémentaire principalement choisie pour un bonus de dégâts directs |

**Fait important :** la spécialisation remplace le passif initial, elle ne s'y ajoute pas. Le joueur choisit donc parfois une nouvelle condition d'accès à un meilleur pourcentage. Le texte et la comparaison doivent le rendre explicite.

**Effet de séquence à examiner.** Le passif est consommé au premier sort admissible, même si c'est une petite attaque préparatoire. Chez l'Arpenteur à trois cases, une marque avec dégâts peut consommer le bonus avant la grosse attaque. Une garde de secours peut consommer le premier bonus du Gardien avant une garde plus importante. Le code permet de le prévoir ; on n'a pas encore observé si les joueurs le comprennent.

**Axes :** garder une spécialisation simple de rendement par classe, et transformer les deux autres en règles qui changent un choix. Le joueur cherchant la simplicité conserve une option claire ; le joueur expert accède à une manière différente d'organiser ses tours.

## 5. La main : les combinaisons existent, leur disponibilité doit être conçue

En Cartes actuel (`rules_revision = 3`), le deck contient exactement dix copies, deux maximum par famille. Le départ sélectionne cinq familles distinctes parmi sept, chacune en deux copies. La main est de quatre. L'ouverture configurée des anciennes révisions est désactivée. Une carte peut être retenue ; recomposer coûte 1 PA, une fois par activation. La carte de remplacement est tirée avant de défausser celle remplacée.

**Calcul analytique, première main, mélange uniforme, sans effet supplémentaire :**

- A en deux copies : probabilité d'en voir au moins une = `1 − C(8,4)/C(10,4)` = **66,67 %**.
- A et B en deux copies chacune : au moins une de chaque = `1 − 2×C(8,4)/C(10,4) + C(6,4)/C(10,4)` = **40,48 %**.
- A, B et C en deux copies chacune : au moins une de chaque = `1 − 3×70/210 + 3×15/210 − 1/210` = **20,95 %**.
- Après remplacement par deux pièces uniques, A et B présentes ensemble : `C(8,2)/C(10,4)` = **13,33 %**.

Ces chiffres décrivent l'ouverture, pas la fiabilité sur plusieurs tours : rétention, défausse, cycles et recomposition changent la situation. Ils expliquent cependant pourquoi une idée à trois pièces peut sembler brillante dans un document et absente du vécu du joueur.

Vérification effectuée par énumération des 210 mains possibles : 140 contiennent A, 85 contiennent A et B, 44 contiennent A/B/C, 28 contiennent les deux pièces uniques. Résultat conservé dans `analytic_hand_check.json` à côté du rapport d'export.

Autre tension : les restrictions « une fois par tour, copies confondues » et les recharges sont stockées par identifiant de sort dans `Unit`. Deux copies augmentent la probabilité de disponibilité, mais ne permettent pas nécessairement deux utilisations. Piocher les deux peut laisser une carte sans utilité immédiate. Ce n'est pas intrinsèquement mauvais ; il faut que le joueur comprenne ce qu'il achète en doublant une carte.

**Décision recommandée :** chaque moteur doit fonctionner avec deux pièces accessibles tôt, et rester utile quand elles sont séparées. Un tuteur, une carte générée ou un rappel peut être plus pertinent qu'une troisième pièce aléatoire. Ne pas ajouter simultanément pioche, remboursement et répétition : on ne saurait plus quel mécanisme a amélioré le jeu.

## 6. Le butin et les builds : distinguer collection et construction de run

Le système actuel tire des cartes, avec biais de classe native à 70 %. Le choix de récompense parmi trois offres est une autre révision ; il ne faut pas l'attribuer au flux actuel. Le magasin propose six familles distinctes tirées dans le pool disponible ; il ne garantit pas la classe native. Les rares entrent à profondeur 4 et les épiques à 10.

| Situation indépendante | Espérance de cartes | Probabilité théorique de zéro | Zéro observé / 300 |
|---|---:|---:|---:|
| Profondeur 1 normal, sécheresse 0 | 0,65 | 42,84 % | 123 = 41 % |
| Profondeur 1 normal, sécheresse 3, cas synthétique | 1,01 | 21,78 % | 59 = 19,67 % |
| Profondeur 10 élite, sécheresse 0 | 1,09 | 22,464 % | 62 = 20,67 % |

L'échantillon n'est pas destiné à estimer un taux de victoire. Le deuxième cas illustre l'effet de la mémoire de sécheresse ; une nouvelle run n'arrive évidemment pas au premier combat avec trois combats sans carte derrière elle.

**Risque documenté.** Une carte trouvée n'est pas nécessairement une carte compatible avec le build, ni une amélioration nette, ni une pièce que le joueur peut améliorer. La correction de sécheresse compte les cartes reçues, pas leur utilité. Un drop hors classe peut donc arrêter la protection sans rendre le deck plus intéressant. Il faut mesurer séparément drop, ajout à la réserve, incorporation et usage réussi.

**Proposition mesurable.** Comparer le système actuel à une variante offrant une décision de construction après le premier combat, puis à une autre offrant un choix orienté vers une fonction manquante. Garder les seeds et l'économie constantes. Ne pas garantir aveuglément la meilleure synergie : cela transformerait toutes les runs en exécution du même plan.

## 7. Progression : le calendrier contraint les promesses

La route v6 comporte douze combats aux profondeurs 1,2,3,5,6,8,10,12,13,15,17,20. En Cartes, les bonus de Sagesse et de Gloire sont neutralisés dans le profil. Avec les récompenses fixes de cette route, le calcul donne :

| Après combat | Profondeur | XP cumulée | Niveau | Perfection totale acquise |
|---:|---:|---:|---:|---:|
| 1 | 1 | 100 | 2 | 2 |
| 2 | 2 | 225 | 3 | 2 |
| 3 | 3 | 370 | 4 | 4 |
| 4 | 5 | 545 | 5 | 4 |
| 5 | 6 | 740 | 6 | 6 |
| 6 | 8 | 955 | 7 | 6 |
| 7 | 10 | 1 200 | 8 | 8 |
| 8 | 12 | 1 465 | 9 | 8 |
| 9 | 13 | 1 760 | 10 | 10 |
| 10 | 15 | 2 085 | 11 | 10 |
| 11 | 17 | 2 440 | 12 | 12 |
| 12 | 20 | 2 785 | 13 | 12 |

La spécialisation est donc accessible après le troisième combat. Le plafond général 14 ne signifie pas qu'une run Cartes atteint 14 : son seuil est 2 950 XP. Le niveau 13 arrive après le boss dans ce calcul. Vérifier toute future récompense XP supplémentaire avant de réutiliser le tableau.

La maîtrise principale part à 2 ; passer à 3 coûte 3 points, à 4 coûte 4 autres points. Une amélioration de copie coûte 2 et exige maîtrise 3. Les classes étrangères plafonnent à 2 : **leurs cartes ne peuvent donc pas recevoir cette amélioration de copie**. Monter une classe étrangère à 2 coûte 2+3 = 5 points.

Conséquences concrètes :

- Première maîtrise 3 possible au niveau 4 ; première copie améliorée au niveau 6 si on a d'abord payé cette maîtrise, soit après cinq combats.
- Maîtrise principale 4 coûte 7 des 12 points ; il reste de quoi améliorer deux copies, avec un point résiduel.
- Maîtrise principale 3 + quatre copies améliorées coûte 11 points.
- Principale 4 + étrangère 2 coûte exactement 12 : aucune amélioration de copie.

**Risque :** le multiclassage est surtout un accès à des utilitaires étrangers, car monter leur maîtrise coûte des améliorations natives sans ouvrir leurs mutations. Cela peut être un choix voulu. Il faut toutefois cesser de le présenter comme la même profondeur de spécialisation qu'une classe principale.

**Statistiques.** La Prouesse de base passe de 18 au niveau 1 à 100 au niveau 10, puis 112 au niveau 12. Les PV passent de 110 à 600 puis 675. Les attributs et l'équipement s'y ajoutent. Une variation de ressenti entre début et fin ne peut donc être attribuée au seul deck. Comparer les dégâts normalisés par Prouesse et les tours nécessaires pour tuer est indispensable.

## 8. Rendement, états et descriptions : endroits où la promesse peut dévier

### Les dégâts affichés ne sont pas les dégâts finaux

À Prouesse 20, maîtrise 2 native, sans passif ni armure : `a_open` inflige 8 après arrondi ; `a_finish` inflige 19 de base plus 13 si marqué. La paire à 3 PA peut donc atteindre 40 bruts dans ces conditions. À l'initiation, `i_a_open` + `i_a_strike` donne 3 + 9 + 7 = 19. La Frappe de secours fait 11 pour 2 PA, toujours accessible au contact. Elle ne remplace pas portée, marque ou placement ; comparer uniquement les dégâts est insuffisant.

Le résolveur applique résistance élémentaire, défense physique ou magique selon le type, multiplicateurs, critique et arrondi ; l'esquive intervient également. Pour une défense positive A, le facteur de défense est `100/(100+A)` : 25 donne 0,8 ; 50 donne 0,667 ; 100 donne 0,5. L'armure de ce jeu n'est donc pas la seconde barre de PV de DOS2. Copier des recommandations de « briser l'armure » sans conversion serait faux.

### Ralenti, Engourdi, Entravé : même famille intuitive, identifiants distincts

`ClassCardModifier` reconnaît précisément `class_slow` pour Thaumaturge, Cryomancien et Chasseur. Le terrain gelé applique `ecosystem_ice` ; Root applique `class_root`. `Unit.has_status` compare les identifiants effectifs, sans alias général de ralentissement.

**Constat statique :** une réduction de PM par ces autres états ne suffit pas à satisfaire le prédicat `class_slow`. **Risque produit :** un joueur construit « glace → Chasseur » et n'obtient pas le bonus attendu. Il faut soit un prédicat commun explicite, soit des textes et icônes qui enseignent cette différence. Ne pas corriger silencieusement sans décider quelles synergies sont voulues. Un test de combat ciblé reste nécessaire avant de qualifier une correction de validée.

### Les noms avancés promettent parfois plus que la règle

- Envoûté attire de deux cases et enlève un PA ; ne change pas d'équipe.
- Entravé réduit les PM, sans garantir une immobilisation complète.
- Désorienté retire des PA, sans interdire spécialement l'incantation.
- Stase exige une marque, saute une activation normale, applique trois activations de protection et a quatre activations de recharge ; sur Pâris elle ne retire qu'un PA.

Les descriptions précisent une bonne partie de ces limites. C'est positif. L'enjeu est que le titre, l'icône et la prévisualisation ne créent pas une autre attente. La stase sur boss ne doit pas être découverte comme une déception après avoir acheté les pièces du build.

### Les améliorations peuvent effacer le plateau

Garde améliorée dure deux activations ; déplacement amélioré traverse les obstacles ; sort de portée supérieure à un ignore la ligne de vue ; sinon portée +1. Ces mutations sont lisibles mais répétitives. Généraliser l'ignorance des obstacles risque de rendre les piliers moins importants précisément quand le joueur maîtrise enfin son deck. Comparer une mutation de trajectoire, de coût ou d'effet différé à cette solution universelle.

## 9. L'équipement : beaucoup de références, peu de règles nouvelles

Les 72 objets de classe viennent de 6 emplacements × 4 affinités × 3 paliers. Statistiques de base par palier : arme +3 Prouesse, armure +8, résistance magique +6, initiative +1, PV +15, esquive +2 points ; affinité +4 % dégâts au contact/à distance/magiques ou +5 % garde/soins, multipliés par palier. Les quatre runes sont également des gains de statistiques.

**Fait :** le gros de cet équipement ajuste le rendement. **Nuance :** les reliques Clou, Coupe et Obole existent, notamment dans les récompenses élites ; on ne doit pas conclure que tous les objets du jeu sont de simples statistiques.

**Proposition :** convertir une petite partie des récompenses majeures en règles de build, avec contrepartie et espace limité. Exemples de prototypes, non implémentés : une garde conservée mais moitié moins forte ; une carte retenue qui coûte moins cher mais réduit la pioche suivante ; un retour de disque qui déplace au lieu d'infliger des dégâts. Éviter de fabriquer 72 variantes textuelles d'effets déclenchés : la charge d'explication deviendrait le problème.

## 10. Les ennemis et salles doivent éprouver les constructions

Le catalogue d'évolution distingue 26 rôles, pas seulement six ennemis. Le grade fait évoluer les PA et les profils. Le système Cartes ajoute à partir des profondeurs concernées des techniques de contrôle, terrain ou exécution issues du vocabulaire des cartes. L'invocation annoncée de certains officiants peut être bloquée en occupant la case. Ce sont de vrais points de contre-jeu.

**Risque à tester :** donner une carte du joueur à un ennemi ne suffit pas à rendre son intention compréhensible. Examiner ce que le joueur peut savoir avant sa décision : cible, portée, recharge, prochaine invocation, conséquence d'un retrait PA. Les dégâts moyens ne mesurent pas cette lisibilité.

### Les corrections concurrentes changent le diagnostic

Le catalogue relu contient maintenant neuf destinations spéciales et des chefs explicitement désignés. Les anciennes critiques « chef choisi selon les PV » et « aucune garantie de salle spéciale » ne sont pas répétées comme faits actuels. Les travaux et tests de l'autre tâche sont consignés dans ses propres rapports ; je n'en revendique pas l'exécution.

| Salle actuelle, règles lues | Décision intéressante | Question d'équilibrage |
|---|---|---|
| Forge : presse 32 héros / 60 ennemis ; rail choisi pour 1 PA | Dépenser une action pour rentabiliser le déplacement adverse | À quels niveaux les 60 dégâts changent-ils encore une décision ? |
| Jardin : anneau de 28 à distance 2,3,1 du chef | Déplacer l'origine de la zone plutôt que seulement fuir | L'aperçu suit-il clairement une poussée avant validation ? |
| Convoi : porteurs alimentent le chef, sceau à 2 PA | Intercepter ou fermer l'autel, au prix du retour des attaques | La fermeture est-elle presque toujours meilleure ? |
| Sablier : croix fixe 32, report à 48 pour 1 PA | Acheter du temps et amplifier un danger utilisable | Le report offre-t-il un vrai choix plutôt qu'un clic obligatoire ? |
| Réservoir : PA restants → charges, 22 par charge, six maximum | Transformer une mauvaise main en préparation spatiale | Le stockage domine-t-il les cartes de dégâts à certaines profondeurs ? |

Ces salles introduisent justement les conversions que le catalogue de classes utilise peu. Elles sont de bons bancs d'essai pour les classes : même deck, objectifs différents, plans différents.

Attention aux nombres fixes face à la courbe de Prouesse : 22 dégâts représentent 122 % de la Prouesse initiale 18, mais environ 19,6 % à Prouesse 112. Les profondeurs d'apparition, défense de la cible et coûts d'accès changent l'interprétation. Ce calcul sert à poser une question, pas à décréter que le Réservoir est faible ou trop fort.

Pâris a également une transformation conditionnelle sous un seuil de PV après dommage non fatal. Une élimination directe peut éviter la transformation. Il faut tester les builds d'usure et de burst séparément : un palier de boss peut sélectionner involontairement une famille de dégâts.

## 11. Ce qu'il faut préserver du mode Classique

| Mécanique existante | Règles vérifiées | Pourquoi elle est plus structurante qu'un bonus |
|---|---|---|
| Disque | Lancer 3 PA, 90 % Prouesse ; Retour 2 PA, 65 % sur trajet dégagé, mur bloquant | La position future du héros change une attaque déjà préparée |
| Braise et Flux | Braise 3 PA, impact 70 %, terrain deux tours ; Flux 2 PA déplace la braise sans réinitialiser sa durée | Le terrain devient un objet manipulable avec une durée à investir |
| Urne / Répercussion | Bronze réellement absorbé, réserve consommée ; Répercussion 3 PA, 150 % du bronze dépensé, cap lié à Prouesse | Encaisser produit une ressource, l'attaque la dépense réellement |
| Garde de salve | 2 PA, trois prochains impacts réduits de max(6 ; 33 % Prouesse) | Défense dont la valeur dépend du profil des attaques adverses |
| Péage | PA + oboles pour renforcer le prochain impact direct payé | Économie de run contre puissance immédiate |

La braise dispose déjà d'une bifurcation entre durée et intensité. Les mutations exclusives sont un exemple plus utile que l'amélioration universelle « sans ligne de vue ». Il faut tester leur intelligibilité, mais ne pas repartir d'une feuille blanche.

## 12. Axes d'amélioration prioritaires et prototypes concrets

Les valeurs suivantes sont **des paramètres de prototype**, sans prétention d'équilibrage final. Ils rendent les propositions jouables et réfutables ; ils ne constituent pas une demande d'implémentation automatique.

### Priorité 0 — rendre les règles fiables et les choix observables

1. Décider d'une sémantique commune pour les états de mobilité ; afficher les synergies admissibles.
2. Montrer quand le passif du tour est disponible, ce qui le consommera et le bonus réellement appliqué.
3. Montrer pourquoi une seconde copie est bloquée et combien d'activations reste la recharge.
4. Conserver dans un bilan de run acquisitions, cartes incorporées, usages, effets déclenchés et raison d'échec.

**Critère :** le joueur doit pouvoir expliquer une absence de bonus sans consulter le code. La mesure pertinente est l'écart entre prédiction avant action et résultat, pas seulement le nombre de tooltips.

### Priorité 1 — quatre moteurs courts, deux pièces chacun

| Prototype | Règle distinctive | Première paire proposée | Limite et contre-jeu |
|---|---|---|---|
| Assassin : contrat | Une seule proie, la tuer change la prochaine main | Désigner, 1 PA ; Encaisser, attaque 2 PA, défausse facultative puis pioche sur mort de la proie | Une récompense de pioche par activation, pas de remboursement PA récursif ; garder une utilité sans mise à mort |
| Gardien : bronze | Garde réellement absorbée stockée, puis sacrifiée | Abri, 2 PA ; Décharge, 2 PA, consomme une réserve plafonnée | Réserve bornée, pas d'alimentation par dégâts auto-infligés ; attaquer réduit la sécurité future |
| Arpenteur : retour | Une ancre de début de séquence définit un trajet | Jalon, 1 PA ; Tir de retour, 2 PA, effet selon les cases traversées | Une ancre, aperçu exact, murs bloquants ; pas d'infini de téléportations |
| Thaumaturge : transformation | Une surface change de fonction au lieu d'être simplement remplacée | Braise, 2 PA ; Étouffer, 1 PA, retire une braise pour créer une protection locale temporaire | Sacrifice de dégâts futurs, durée fixe, mêmes règles pour deux camps |

**Pourquoi ces quatre-là :** ils changent respectivement le deck, la défense, la géométrie et le terrain. Ils réutilisent des services existants. Ils ne demandent pas quatre nouvelles jauges globales ni une équipe d'invocations.

**Conditions d'accès :** première pièce au départ ou après le premier combat ; seconde accessible avant le premier élite. Chaque pièce doit fonctionner seule. Les autres cartes peuvent amplifier le moteur sans être indispensables à son apparition.

### Priorité 2 — mutations qui divisent les builds

Proposer deux améliorations incompatibles sur quelques cartes structurantes :

- Une poussée gagne une case **ou** protège le lanceur si une collision a effectivement eu lieu.
- Une marque dure plus longtemps **ou** se consomme pour améliorer la prochaine pioche.
- Une garde persiste davantage **ou** peut être convertie en attaque, avec perte de la protection.
- Une zone couvre plus de cases **ou** laisse une seule case persistante manipulable.

Ces choix doivent créer des préférences de cartes et de salles différentes. Si les deux branches conduisent au même ordre d'actions et qu'une seule a un meilleur rendement, la mutation est ratée.

### Priorité 3 — acquisition et hybrides

Tester une récompense de construction précoce ; rendre la première hybridation visible comme une fonction (contrôle, retour, sacrifice), plutôt qu'un +10 %. Réexaminer séparément le plafond étranger de maîtrise 2 et la condition d'amélioration à 3. Si l'impossibilité d'améliorer les cartes étrangères est maintenue, l'expliquer avant l'investissement.

### Priorité 4 — donner aux builds des questions différentes

Concevoir des situations qui valorisent alternativement : sauver une case, déplacer une origine de zone, arrêter une alimentation, tenir une durée courte, éliminer une cible mobile. Ne pas ajouter de résistance totale qui invalide le deck sans issue. Le contre-jeu doit changer le plan, pas annuler la classe.

## 13. Validation de conception à mener, sans la confondre avec cet audit

### Essais mécaniques ciblés

- Glace de terrain → Chasseur/Cryomancien : comparer le résultat voulu, l'état présent et le bonus.
- Deux copies d'une carte à recharge : comparer disponibilité, rétention et recomposition.
- Petite préparation → grosse attaque : vérifier consommation du passif et aperçu des dégâts.
- Contrôle sur ennemi normal, élite et Pâris : préconditions, immunité, durée et texte.
- Réservoir : comparer dégâts finaux par PA investi, coût de déplacement, vol de charges et carte alternative.

### Tests joueurs proposés

Douze participants exploratoires, quatre découvrant le genre, quatre familiers des deckbuilders, quatre familiers du tactique. Ce nombre sert à trouver des problèmes, pas à annoncer une significativité statistique. Deux variantes maximum par session, ordre alterné, mêmes seeds par comparaison. Observer au moins le départ, le premier élite et une salle spéciale ; compléter par des runs entières pour les effets d'économie.

Mesurer : premier tour où le joueur réalise le moteur voulu ; tours avec une carte retenue ou une recomposition utile ; acquisitions incorporées ; fréquence du geste de secours ; usage des objectifs spatiaux ; temps de décision ; raison donnée pour choisir/améliorer une carte ; prédiction correcte d'un effet ; variété des séquences sur trois combats consécutifs.

Questions après l'essai : « Raconte ton meilleur tour », « Quelle carte voudrais-tu obtenir maintenant, et pourquoi ? », « Qu'est-ce qui a fait échouer ton plan ? ». Un joueur qui nomme seulement « plus de dégâts » ne prouve pas un échec, mais indique que l'identité systémique n'est pas encore perceptible.

### Décider à partir de ces résultats

Une amélioration est prometteuse si elle rend le plan reconnaissable plus tôt, crée plusieurs réponses utiles selon la salle et n'allonge pas excessivement les tours. Un taux de victoire supérieur ne suffit pas. Une mécanique puissante mais jamais comprise, ou comprise mais systématiquement répétitive, doit être retravaillée.

## 14. Limites et conclusion opérationnelle

L'audit couvre règles et contenu inspectés, export de catalogue et échantillonnage de butin. Il ne remplace pas une campagne de parties humaines, une inspection visuelle complète ou des tests de toutes les interactions. Les salles concurrentes peuvent encore changer après ce relevé ; leur état doit être recontrôlé avant implémentation. Les retours joueurs externes constituent un échantillon qualitatif volontairement contradictoire.

La recommandation est de **faire converger la richesse tactique déjà présente vers quatre moteurs de classe compréhensibles**, d'en garantir une première expression précoce, puis de diversifier leurs mutations et leurs contre-jeux. Ajouter des familles de dégâts avant cette étape augmenterait surtout la taille du catalogue à apprendre.
