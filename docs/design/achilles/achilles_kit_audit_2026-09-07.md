# Achille — audit du kit, des maîtrises et du theorycraft

Date : 7 septembre 2026. Référence du dépôt : `c1311f389b68e7c9d5ab83c3585bbaa512f73ac9`.

Cet audit accompagne la [proposition de kit recomposable](achilles_kit_recomposable_v1.md). Il décrit les ressources et le code présents, puis distingue les conséquences calculables des hypothèses de ressenti. Aucun comportement de jeu n'a été modifié pour cet audit.

## Méthode et limites

- **Observé dans le dépôt** : ressources reliées à la run, règles de résolution, intégration, sauvegarde et assertions des tests existants.
- **Calculé** : coûts PA, budgets de progression et seuils dérivés de ces ressources. Les hypothèses sont indiquées avec le calcul.
- **Diagnostic de design** : interprétation des possibilités et contraintes. Elle devra être confrontée à des parties réelles.
- **Non mesuré ici** : plaisir, taux de victoire, durée réelle d'une salle, fréquence effective des combos, télémétrie et comportement des joueurs. Les tests cités ont été lus ; leurs résultats historiques ne constituent pas une exécution nouvelle de cette passe.

Les liens ci-dessous sont relatifs au dépôt. Les numéros de ligne sont ceux de la référence auditée et servent de repères de lecture.

## 1. Quelle version d'Achille est réellement concernée ?

Le nom de fichier `odyssey.tres` ne désigne plus un autre prototype : sa propriété `run_name` vaut **Catabase**, et elle référence cinq salles. Le chemin actif passe par le profil de contenu Odyssey, puis le profil de progression Champion d'Achille.

Sources : [run](../../../data/runs/odyssey.tres), lignes 5–29 ; [profil Champion](../../../data/runs/progression/odyssey/achilles_progression_profile.tres), lignes 5–21 ; [test de la Catabase](../../../test/unit/test_catabase_champion_run.gd), lignes 4–36.

| Élément actuel | État observé |
|---|---|
| Châssis initial | 110 PV, 18 Prouesse, 6 PA, 3 PM, initiative 14 |
| Kit actif et connu au départ | Frappe du Péléide, Percée fulgurante, Tir du Pélion, Garde d'airain |
| Emplacements actifs | 4 |
| Progression | XP de champion à la victoire ; aucun gain d'XP propre aux sorts |
| Arbres actifs | Colère du Péléide, Leçon de Chiron, Rempart d'Éaque |
| Catalogue | 27 nœuds dans les trois doctrines, plus 9 nœuds avancés : **36 maîtrises** |

Sources : [profil de sorts](../../../data/runs/progression/odyssey/achilles_progression_profile.tres), lignes 15–20 ; [catalogue de maîtrises](../../../data/characters/achilles/doctrines/achilles_mastery_catalog.tres), lignes 4–13 ; [test du châssis](../../../test/unit/test_catabase_champion_run.gd), lignes 23–53 ; [test de topologie](../../../test/unit/test_achilles_mastery_doctrines_gate34.gd), lignes 18–50.

Les anciens fichiers `spear_thrust`, `advance`, `sweep` et `guard` existent encore. Ils ne constituent pas le kit déclaré par le profil de progression actif. Il faut éviter de proposer une refonte à partir de leurs coûts ou de leurs anciens arbres individuels.

## 2. L'économie des actions concentre le tour sur peu de familles

| Technique | PA | Portée et forme initiales | Limite |
|---|---:|---|---|
| Frappe du Péléide | 3 | Contact, 1 case ; 55 % Prouesse | Une fois par activation |
| Tir du Pélion | 3 | 2–6 cases, ligne de vue ; 50 % Prouesse | Une fois par activation |
| Percée fulgurante | 1 | 1–3 cases, ligne cardinale vers une case libre ; aucun dégât initial | Une fois par activation |
| Garde d'airain | 2 | Soi ; bouclier de 5 % PV max + 25 % Prouesse | Une fois par activation ; expire au début de l'activation suivante |

Sources : [Frappe](../../../data/spells/achilles/peleid_strike.tres), lignes 15–21 ; [Tir](../../../data/spells/achilles/pelion_shot.tres), lignes 15–23 ; [Percée](../../../data/spells/achilles/fulminant_dash.tres), lignes 9–16 ; [Garde](../../../data/spells/achilles/bronze_guard.tres), lignes 18–24.

**Calcul PA, sans objet, maîtrise ni réaction :** si l'on se limite aux ensembles de techniques qui dépensent les 6 PA et ignore leur ordre, il reste trois familles :

1. Frappe + Tir : `3 + 3` ; toute la dépense en attaques.
2. Frappe + Percée + Garde : `3 + 1 + 2` ; cycle de mêlée complet.
3. Tir + Percée + Garde : `3 + 1 + 2` ; cycle de tir complet.

Une énumération indépendante des coûts et quotas donne 28 séquences ordonnées non vides, dont 14 dépensent exactement 6 PA. Ce dénombrement abstrait ne simule pas leur légalité sur une carte. Ce ne sont donc pas « trois tours possibles » : déplacements normaux, ordre des actions, cibles, obstacles, engagement, options gratuites et tours volontairement incomplets multiplient les décisions. Mais ce sont trois familles de dépense complète, et deux partagent exactement le couple Percée/Garde. La restriction explique pourquoi un tour peut revenir rapidement à « une attaque + déplacement spécial + protection » malgré l'habillage du build.

**Diagnostic :** ajouter un cinquième sort réellement échangeable, avec une fonction et un coût distincts, peut changer cette économie plus fortement que plusieurs bonus de dégâts. Ajouter seulement un autre sort à 3 PA, de même portée et de même fréquence, risque de produire un substitut esthétique à Frappe ou Tir.

### Une promesse de combo qui dépasse le kit de départ

Fureur lucide annonce `+15 %` à la deuxième technique offensive distincte sur une même cible et `+25 %` à la troisième. Son catalogue nomme Frappe, Percée et Tir. Cependant, le compteur de combat est alimenté par des impacts infligeant des dégâts : une Percée initiale sans impact ne suffit pas. Frappe + Tir + Percée coûteraient déjà 7 PA, et la Percée doit en outre acquérir un impact offensif pour participer au compteur.

Sources : [Fureur lucide](../../../data/characters/achilles/doctrines/wrath_of_peleus.tres), lignes 10–40 ; [adaptateur de combat](../../../battle/mastery_combat_adapter.gd), lignes 187–198 et 942–956 ; [test de Percée offensive](../../../test/unit/test_mastery_combat_adapter.gd), à partir de la ligne 202.

Le bonus à la troisième technique n'est donc pas une boucle immédiatement offerte par le kit initial. Des effets de haut niveau, réactions ou sources supplémentaires peuvent changer cette situation ; ils ne doivent pas être supposés acquis à la première maîtrise.

### La racine défensive demande plus que la Garde nue ne peut absorber

Garde active demande d'absorber au moins 10 % des PV maximum. Le runtime cumule les dégâts effectivement absorbés et compare ce total à `plafond(PV max × 0,10)`.

| Niveau, sans équipement ni autre maîtrise | Garde créée | Seuil d'absorption |
|---|---:|---:|
| 1 | 10 | 11 |
| 2 | 12 | 14 |
| 3 | 15 | 17 |
| 4 | 18 | 20 |
| 10 | 55 | 60 |

**Calcul statique :** avec la racine seule et une Garde sans bonus, absorber toute sa valeur n'atteint pas le seuil. Ce n'est pas une maîtrise intrinsèquement inopérante : Résolution, équipement, Garde orientée et d'autres effets peuvent changer sa capacité effective. L'orientation intervient sur les dégâts bloqués, ce qui peut permettre d'absorber plus de dégâts que la valeur de bouclier consommée. Mais le premier achat ne délivre pas seul la boucle annoncée sur un héros nu.

Sources : [condition de Garde active](../../../data/characters/achilles/doctrines/aegis_of_aeacus.tres), ligne 22 ; [accumulateur et seuil](../../../characters/progression/mastery_reactive_runtime_service.gd), lignes 233–254 ; [valeurs calculées du Champion](champion_catabase_statistics_v0.md), lignes 17–26 ; [absorption effective des boucliers](../../../units/unit.gd), lignes 1374–1412.

**Diagnostic :** une racine devrait produire un changement reconnaissable dès son achat. Si elle a besoin d'une autre amélioration pour fonctionner, cette dépendance doit être explicite ou sa condition révisée.

## 3. Ce que les doctrines font déjà, et ce qui reste fixe

### Colère du Péléide

Les premiers achats reposent surtout sur le rendement conditionnel : enchaîner sur une cible, retirer de l'armure, frapper après Percée, finir une cible blessée, prendre un risque de PV. Pas victorieux ajoute ensuite un déplacement optionnel gratuit de deux cases après élimination ; Brise-formation récompense le déplacement forcé. Le choix majeur transforme Frappe en ligne de deux cases ou renforce une stratégie à faibles PV.

Repères : [doctrine Colère](../../../data/characters/achilles/doctrines/wrath_of_peleus.tres), descriptions aux lignes 28, 74, 124, 157, 204, 240, 325, 356 et 419.

### Leçon de Chiron

Chiron propose déjà une bifurcation spatiale forte : Allonge du Pélion impose une portée 3–8, tandis que Tir rapproché permet 1–5 et une poussée. Les deux sont exclusifs. Les niveaux suivants ajoutent un pas optionnel après Percée, du retrait de PM, de la perforation ou un bonus de déplacement. Les choix majeurs donnent une ligne jusqu'à trois cibles ou un éventail.

Repères : [doctrine Chiron](../../../data/characters/achilles/doctrines/lesson_of_chiron.tres), descriptions aux lignes 43, 104, 175, 213, 247, 284, 359, 411 et 459 ; exclusivité aux lignes 112 et 183.

### Rempart d'Éaque

La doctrine transforme progressivement la défense en préparation d'attaque : absorption vers bonus offensif, orientation choisie avec contrepartie sur les côtés et dans le dos, ancrage, riposte renforcée et neutralisation de projectile. Bouclier brisé favorise la sortie ; Bastion mobile convertit une partie de Garde en poussée et dégâts autour de Percée. Les choix majeurs ajoutent un contre automatique ou une ligne de protection temporaire devant Achille.

Repères : [doctrine Éaque](../../../data/characters/achilles/doctrines/aegis_of_aeacus.tres), descriptions aux lignes 45, 82, 116, 194, 243, 318, 353, 394 et 449.

### Les neuf maîtrises avancées

- Trois **sommets**, coût 3, niveau 13, après doctrine complète : renforcements propres à Colère, Chiron ou Rempart.
- Trois **jonctions**, coût 1, niveau 14, avec au moins 6 points dans chacune de deux doctrines : alternance Frappe/Tir, conversion d'absorption en Frappe, ou réponse par projectile.
- Trois **apothéoses**, coût 1, niveau 14, après le sommet correspondant : Frappe supplémentaire après élimination, choix d'origine du Tir entre départ et arrivée de Percée, ou choix de conservation/conversion de Garde.

Source : [maîtrises avancées](../../../data/characters/achilles/doctrines/advanced_masteries.tres), lignes 62–169, 177–184, 302–452 et 479–567.

**Diagnostic :** réduire l'existant à de simples `+5 %` serait inexact. Orientation, portée minimale, formes de zone, déplacements après action, contre et origine alternative sont déjà des changements tactiques substantiels. Mais ils se greffent sur les mêmes quatre techniques. L'arbre améliore et transforme un kit imposé ; il ne permet pas encore d'en composer un autre.

Les effets ciblent très souvent des identifiants précis (`achilles_peleid_strike`, `achilles_pelion_shot`, etc.). Retirer un de ces sorts sans changer le contrat des maîtrises peut rendre une partie du build inactive. Exemple : [cibles de Colère](../../../data/characters/achilles/doctrines/wrath_of_peleus.tres), lignes 20, 52, 114 et 149 ; [données des nœuds](../../../data/characters/skill_tree_node_data.gd), lignes 25–35.

## 4. Une grande part de l'arbre arrive après la fin de la run

Les cinq rencontres accordent respectivement 100, 120, 140, 160 et 180 XP de base. Sans Sagesse ni Gloire :

| Après la salle | XP cumulée | Niveau atteint | Maîtrises obtenues par niveau |
|---|---:|---:|---:|
| 1 | 100 | 2 | 1 |
| 2 | 220 | 3 | 2 |
| 3 | 360 | 4 | 3 |
| 4 | 520 | 5 | 4 |
| 5 | 700 | 6 | 5 |

Sources : [test des récompenses](../../../test/unit/test_catabase_champion_run.gd), lignes 33–36 et 203 ; [seuils Champion](../../../data/runs/progression/odyssey/achilles_champion_progression_v0.tres), lignes 8–13.

Le point gagné après la cinquième salle ne peut plus servir contre une sixième salle dans la run actuelle. Avant le dernier combat, le budget naturel réellement jouable est de quatre maîtrises. Les leçons du marchand peuvent ajouter des points, mais ne contournent aucun niveau minimum.

| Transformation | Seuil minimal actuel |
|---|---|
| Premier choix majeur | Niveau 10, 1 700 XP, chemin minimal de 6 maîtrises |
| Deuxième choix majeur d'une autre doctrine | Niveau 13, 2 630 XP |
| Variante de choix majeur authored niveau 13 | Niveau 13 même si c'est le premier choix majeur acheté |
| Sommet | Niveau 13 + doctrine complète + 3 maîtrises |
| Jonction / apothéose | Niveau 14, 2 950 XP + prérequis propres |

Le resolver prend le maximum entre le niveau propre au nœud et le seuil premier/deuxième choix majeur. Ainsi, les deux options d'un même palier ne deviennent pas simultanément disponibles au niveau 10. Sources : [resolver d'achat](../../../characters/progression/skill_tree_resolver.gd), lignes 395–423 ; [profil](../../../data/runs/progression/odyssey/achilles_champion_progression_v0.tres), lignes 22–26.

**Borne volontairement généreuse :** même en accordant fictivement Sagesse 5 dès la première rencontre et toutes les Gloires réussies, `700 × 1,5 × 1,3 = 1 365 XP`. Les cinq montants donnent ici des produits entiers ; cette borne reste sous 1 700 XP. Aucun choix majeur n'est donc accessible dans cette Catabase normale, même avec cette hypothèse plus favorable qu'une progression réelle.

Source de la formule : [profil de progression](../../../data/runs/progression/champion_progression_profile.gd), lignes 141–155 ; limites Sagesse et Gloire dans le [profil d'Achille](../../../data/runs/progression/odyssey/achilles_champion_progression_v0.tres), lignes 18–20. Le [test des gates](../../../test/unit/test_achilles_mastery_doctrines_gate34.gd), lignes 130–156, vérifie que des maîtrises supplémentaires ne remplacent pas les niveaux requis.

**Conséquence de design :** il faut donner une identité transformée assez tôt pour la jouer pendant plusieurs salles. Allonger à 10–15 salles peut rendre les paliers atteignables, mais ne corrige pas à lui seul l'absence de nouveaux sorts ni le coût d'attente avant la première transformation.

### Économie et extension à 10–15 salles

La run déclare actuellement une durée cible de 18 minutes, étendue à 25 ; ce sont des objectifs de ressource, pas des durées mesurées dans cet audit. Elle démarre avec 120 de monnaie, deux potions et un parchemin d'action, puis accorde 60 par victoire. Le camp est accessible après les salles non finales ; achats et caractéristiques se font entre combats.

Sources : [durée déclarée](../../../data/runs/odyssey.tres), lignes 19–20 ; [économie](../../../data/runs/economy/odyssey_economy_profile.tres), lignes 9–28 ; [accès au camp](../../../ui/post_combat/champion_progression_summary.gd), lignes 75–80 ; [dépense de progression](../../../core/game_manager.gd), lignes 1900–1919.

Les limites marchandes restent globales à la run : trois soins de 25 %, trois achats d'équipement, deux reliques, deux forges, trois renouvellements, une réorientation d'un point et trois leçons. Ces plafonds ne se multiplient pas automatiquement avec le nombre de salles. L'équipement apporte des statistiques passives ; il ne constitue pas une bibliothèque d'attaques d'armes. Achille n'a pas non plus d'attaque de base gratuite indépendante de ses quatre techniques.

Sources : [offres marchandes](../../../data/runs/economy/odyssey_merchant_profile.tres), lignes 6–80 ; [présentation des statistiques et équipements](champion_catabase_statistics_v0.md), ligne 32 ; [attaque de base désactivée](../../../data/units/allies/achilles.tres), ligne 26.

L'XP et la récompense de victoire sont protégées contre les doublons par l'identifiant de rencontre. Une extension peut réutiliser une carte, mais les occurrences récompensées doivent avoir des identifiants de rencontre distincts. Copier des salles sans revoir ces identifiants peut empêcher la progression attendue.

Sources : [attribution d'XP](../../../characters/progression/champion_progression_state.gd), lignes 86–120 ; [attribution de monnaie](../../../core/game_manager.gd), lignes 1843–1846.

## 5. Les choix sont davantage cumulatifs que mutuellement engageants

Les paliers II à IV permettent généralement d'acheter les deux branches. Un seul parent du palier précédent suffit. Les exceptions explicites sont notamment Allonge/Tir rapproché et les deux choix majeurs d'une doctrine. Le test vérifie expressément que deux frères non exclusifs peuvent être achetés.

Sources : [resolver](../../../characters/progression/skill_tree_resolver.gd), lignes 424–458 ; [test des frères](../../../test/unit/test_achilles_mastery_doctrines_gate34.gd), lignes 92–127.

La complétion demandée par un sommet encourage l'achat de l'ensemble des nœuds compatibles, et pas seulement d'un chemin distinctif. Le coût structurel complet est 9 pour Colère et Rempart ; Chiron est légalement complet à 8 grâce à sa paire exclusive comptée comme couverte. Le coût de 9 affiché par l'outil structurel ne signifie pas que Chiron doive acheter deux options incompatibles.

Sources : [calcul et complétion](../../../characters/progression/skill_tree_resolver.gd), lignes 628–669 ; [précision du catalogue de statistiques](champion_catabase_statistics_v0.md), lignes 58–60.

**Diagnostic :** un build spécialisé tend à collectionner les améliorations de sa doctrine. Pour obtenir un choix qui change la manière de jouer, il faudra conserver de véritables alternatives, notamment entre apprendre une technique, changer le comportement d'une technique et renforcer une synergie. Les prérequis ne devraient pas imposer d'acheter un outil que le joueur a volontairement retiré de son kit.

## 6. Recomposer le kit : une base technique existe, le parcours reste à construire

`SpellLoadoutState` distingue déjà sorts connus et sorts équipés. Il possède `learn_spell`, `equip_spell` et `unequip_slot`. L'équipement vérifie un slot valide, un sort connu et l'absence de doublon ; il ne réserve pas de slot de défense, mobilité ou attaque. Un sort offensif peut donc techniquement occuper le slot précédemment utilisé par Garde.

Source : [loadout de sorts](../../../characters/progression/spell_loadout_state.gd), lignes 4–11, 31–45 et 53–74. La synchronisation vers `unit.spells` existe : [état du personnage](../../../characters/progression/character_run_state.gd), lignes 118–120.

Cependant :

- Le profil démarre avec exactement quatre sorts connus pour quatre slots.
- La recherche des appels à `learn_spell`, `equip_spell` et `unequip_slot` dans `characters`, `core`, `ui` et `data` ne trouve que la classe du loadout elle-même : aucun parcours joueur de changement du kit n'y est raccordé.
- `SkillTreeNodeData` ne déclare pas d'effet d'apprentissage de sort ; il expose surtout modificateurs ciblés et effets réactifs.
- L'achat d'une maîtrise actualise les modificateurs et le runtime réactif ; il n'apprend ni ne remplace de sort.

Sources : [profil](../../../data/runs/progression/odyssey/achilles_progression_profile.tres), lignes 16–17 ; [schéma des nœuds](../../../data/characters/skill_tree_node_data.gd), lignes 14–35 ; [achat](../../../characters/progression/character_run_state.gd), lignes 472–485.

Il existe aussi une dépendance moins visible : l'adaptateur cherche les techniques des réactions automatiques dans `actor.spells`, donc dans le kit équipé. Déséquiper Frappe peut rendre inexécutable un contre qui appelle cette Frappe. Une future réaction devra soit déclarer cette dépendance, soit posséder son propre profil d'attaque autonome. Source : [résolution des attaques automatiques](../../../battle/mastery_combat_adapter.gd), lignes 580–587 et 605–620.

La réorientation marchande n'est pas un changement libre de build. Elle coûte 55, est limitée à une utilisation par run, et rembourse un seul nœud racine/maîtrise de coût 1 si son retrait laisse tous les autres prérequis valides. Elle ne rembourse pas les choix majeurs.

Sources : [offre](../../../data/runs/economy/odyssey_merchant_profile.tres), lignes 56–64 ; [validation du remboursement](../../../core/run_content/champion_camp_service.gd), lignes 140–152.

### Sauvegarde à étendre

Le snapshot Champion contient sa progression et les nœuds choisis. Le snapshot global ajoute inventaire, équipement, économie et autres états de run. Aucun de ces chemins ne sérialise actuellement une bibliothèque variable de sorts connus et un ordre de slots équipés.

Sources : [snapshot de progression](../../../characters/progression/character_run_state.gd), lignes 223–233 ; [snapshot global](../../../core/game_manager.gd), lignes 696–716 ; [état du loadout](../../../characters/progression/spell_loadout_state.gd), lignes 1–90.

La recomposition doit donc prévoir un contrat de persistance : sorts acquis, quatre slots ordonnés, provenance d'apprentissage, validation au chargement, et comportement des maîtrises lorsque leur sort cible est déséquipé. Il ne suffit pas d'appeler `equip_spell` depuis un écran.

### Schéma des arbres à assouplir

Le validateur impose aujourd'hui exactement trois doctrines, neuf nœuds par doctrine, une topologie `1 / 2 / 2 / 2 / 2`, deux choix majeurs, un chemin minimal de coût 6 et un coût complet structurel de 9. Les tests réaffirment ces nombres. Les nœuds avancés ont également leurs niveaux 13/14 codifiés dans la validation.

Sources : [validateur Champion](../../../characters/progression/skill_tree_resolver.gd), lignes 504–562 ; [tests de catalogue](../../../test/unit/test_achilles_mastery_doctrines_gate34.gd), lignes 18–50 et 181–195.

**Conséquence technique :** introduire de nouvelles techniques et une topologie adaptée demande un changement explicite du modèle, de la validation, de l'aperçu et de la persistance. La fondation réutilisable est solide — prérequis ET/OU, exclusions, modificateurs, événements, réactions et slots — mais l'extension n'est pas une simple réécriture des descriptions.

## 7. Le laboratoire de theorycraft n'est pas encore un simulateur du Champion

Le laboratoire Godot conserve une qualité importante : sa baseline charge la run actuelle et résout le héros via `RunHeroResolver`. Il lit donc les ressources actives au lieu d'en recopier les quatre techniques. En revanche, il attribue encore à cette baseline la famille constante `SPEAR_LEGACY`, héritée d'un état précédent.

Source : [catalogue du laboratoire](../../../tools/achilles_theorycraft/achilles_theorycraft_catalog.gd), lignes 10–38.

Le service de comparaison additionne directement `spell.damage` pour l'attaque et `spell.shield_grant + spell.heal` pour la défense. Or les techniques Champion passent par des coefficients de Prouesse et de PV, avec champs bruts à zéro. Ces sommes peuvent donc afficher zéro tout en décrivant des techniques parfaitement capables d'infliger des dégâts ou de créer Garde en combat. Elles ne prennent pas en compte le niveau, les attributs, les maîtrises et l'équipement du Champion.

Sources : [comparaison brute](../../../tools/achilles_theorycraft/achilles_theorycraft_comparison_service.gd), lignes 120–147 ; [scaling de Frappe](../../../data/spells/achilles/peleid_strike.tres), ligne 10 ; [scaling de Tir](../../../data/spells/achilles/pelion_shot.tres), ligne 10 ; [scaling de Garde](../../../data/spells/achilles/bronze_guard.tres), lignes 10–12 et 27.

L'analyse PA énumère des séquences abstraites avec coûts et quotas. Sa légalité contextuelle peut reposer sur une liste d'actions autorisées manuellement ; elle ne simule pas le nouvel état spatial après chaque déplacement, les nouvelles lignes de vue, ni le positionnement exact des cibles. Elle reste utile pour détecter des problèmes d'économie, à condition de ne pas convertir ses séquences en fréquence de combos réellement jouables.

Source : [analyseur d'économie d'actions](../../../tools/achilles_theorycraft/achilles_action_economy_analyzer.gd), lignes 225–290 et 322–328.

Les avertissements existants sont de bons garde-fous de conception : choix uniquement numériques, PA inutilisables, risque de kite, boucle défensive, absence de récupération et builds trop semblables. Ils signalent des hypothèses à examiner, pas des preuves de domination en partie réelle. Les concepts épée/bouclier et arc restent des templates d'intention ; les builds exportés ne sont pas chargés automatiquement en jeu.

Sources : [validateur du laboratoire](../../../tools/achilles_theorycraft/achilles_theorycraft_validator.gd), lignes 4–17 ; [templates](../../../tools/achilles_theorycraft/achilles_theorycraft_catalog.gd), lignes 71–99 ; [statut des builds](../../../tools/achilles_theorycraft/achilles_theorycraft_build.gd), lignes 72–73 et 121.

Le laboratoire web `web/achilles-run-lab` constitue encore un autre modèle expérimental : son document de gameplay décrit notamment 100 PV, 10 armure, une économie d'actions différente et des effets de séquence fondés sur l'action précédente. Son architecture déterministe peut faciliter l'expérimentation, mais ses conclusions ne se transposent pas directement au Champion Godot actuel.

Sources : [contrat expérimental web](../../../web/achilles-run-lab/docs/GAMEPLAY_EXPERIMENT.md), lignes 3–19 ; [architecture du laboratoire web](../../../web/achilles-run-lab/docs/ARCHITECTURE.md), lignes 7–19.

**Conséquence :** avant de comparer des builds recomposables, le banc d'essai devra calculer leurs profils via les mêmes resolvers que le combat, puis distinguer simulation spatiale, contraintes manuelles et simple énumération PA. La baseline « données live » ne garantit pas que toutes les métriques dérivées reflètent le gameplay live.

## 8. Contradictions et documents devenus historiques

Le [rapport d'intégration du 5 septembre](champion_catabase_integration_2026-09-05.md), au paragraphe « Comportement livré », et le [tableau de statistiques](champion_catabase_statistics_v0.md), ligne 7, décrivent encore trois rencontres et un niveau final 4. La run et le test courants en déclarent cinq, pour un niveau final naturel 6. Cette contradiction vient de la cadence des modifications ; les ressources actives priment pour cet audit.

Le texte à trois salles est encore codé en dur dans l'[exporteur des statistiques](../../../tools/champion_progression/export_champion_statistics.gd), lignes 29 et 81 : régénérer ce document sans corriger sa source peut reproduire l'information périmée. Le [contrat de theorycraft V1](achilles_theorycraft_contract_v1.md) décrit également une ancienne baseline lance/Balayage, trois salles et un ancien dénombrement de séquences. Il constitue un historique de méthode, pas un état courant du kit.

Le [document d'animations](achilles_spell_animation_inventory_v2.md), ligne 84, précise déjà que les présentations de builds avancés reposent sur des fixtures de haut niveau. Une capture de Volée, de Rempart ou de Trait du destin prouve une capacité du système ; elle ne prouve pas son accessibilité dans une partie fraîche de cinq salles.

Le [rapport de l'atlas dynamique](../dynamic_mastery_atlas_2026-09-06.md) décrit surtout une amélioration de navigation, de présentation et de retour visuel. Il précise que l'atlas n'ajoute ni points de démonstration ni nouvelle règle de progression. Améliorer l'affichage de l'arbre ne corrige donc pas ses gates ni la composition fixe du kit.

## 9. Conclusions de l'audit

1. Le système possède déjà plusieurs mécanismes tactiques intéressants ; leur accès tardif et leur dépendance aux quatre sorts masquent une partie de leur potentiel.
2. Les premières récompenses modifient surtout le rendement d'actions déjà disponibles. Les transformations qui peuvent changer la forme du tour arrivent souvent après la fin de la run normale.
3. La liberté demandée — sacrifier défense ou mobilité pour une nouvelle attaque — est compatible avec la notion actuelle de slots, mais l'apprentissage, l'interface, les effets ciblés et la sauvegarde doivent être raccordés.
4. Une progression satisfaisante doit distribuer tôt de nouvelles possibilités, puis laisser assez de salles pour les maîtriser et les combiner. La seule augmentation de l'XP ou du nombre de salles ne répond pas à toute la demande.
5. Les critères de validation futurs doivent mesurer les comportements obtenus : ordres d'actions, positions recherchées, vulnérabilités assumées, récupération après erreur et combinaisons réellement choisies. Une différence d'`effect_axis` ou de dégâts ne démontre pas à elle seule deux styles de jeu distincts.

Les propositions de design correspondantes sont détaillées dans [Achille — kit recomposable V1](achilles_kit_recomposable_v1.md).
