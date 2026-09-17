# Catabase r6 — intégration, audit et rééquilibrage

Statut : WORKTREE_CANDIDATE. Vérification du 14 septembre 2026.
Dépôt : `Essy7126/dungeon-draft-v-2`, copie locale
`C:/Users/p.montebello/Documents/GitHub/dungeon-draft-v-2`.
Branche `main`, base `055584c37f60d99b2f87bdbb4d670895bf8ef2b2` ; changements non commités.

## Verdict de la première passe intégrée

La proposition est intégrée au jeu, pas seulement décrite dans un document.
La cible reste une victoire normale en 30–45 minutes, avec une difficulté
exigeante. Ce temps et l'apprentissage humain ne sont pas mesurables par un
bot headless : ils restent à confirmer en jouant avec l'interface et les animations.

La route, ses transactions et ses rencontres sont exécutables. Les essais
continus produisent de vraies victoires et défaites, mais ne justifient pas de
déclarer les six armes équivalentes ou le rythme humain définitivement réglé.
Le rééquilibrage corrige d'abord les incohérences démontrées, sans diminuer les
menaces pour compenser un mauvais pilote automatique.

## Décisions validées et réalisation

- Catabase solo, Achille ou Passe-rive. Aucun retour du trio historique.
- Vingt profondeurs, douze combats, trois élites, trois refuges ; pas de
  combats de remplissage ajoutés pour rallonger la durée.
- Quatre engagements de branche. Le Léthé conserve ses cinq escales II–VI.
- Normal et Facile sont choisis au départ et enregistrés. Les sauvegardes
  r2–r5 conservent leur route et leurs règles historiques.
- Facile conserve les menaces et le contre-jeu : PV ennemis ×0,90, dégâts
  ×0,80, refuges 40 % contre 30 %. Pas d'IA volontairement aveugle.
- XIX est une préparation, pas un quatrième soin gratuit. Le joueur peut
  revoir ses sorts, son équipement et la règle de métamorphose de Pâris.

## Ce que demande chaque séquence

| Profondeurs | Question tactique ou économique |
| --- | --- |
| I | Comprendre déplacement, portée et coût d'une action. |
| II–III | Choisir l'approche, isoler un côté, atteindre le tireur ; première alternative d'arme en II. |
| IV | Choisir une dépense, une branche ou une découverte selon le trajet engagé. |
| V–VI | Composer avec poursuite et portée, puis casser un groupe de quatre rôles. |
| VII | Récupérer une fois et préparer le segment suivant. |
| VIII–X | Couper le conducteur de sa meute, puis rompre la combinaison Chaîne/Sentence. |
| XI | Arbitrer la préparation avec les ressources restantes. |
| XII–XIII | Séparer soutien et convoi ; anticiper les déplacements dans le feu. |
| XIV–XV | Dépenser ou choisir un secours, puis désassembler Égide/visée/poussée. |
| XVI–XVIII | Dernier vrai refuge, combat mêlant feu/déplacement/givre, dernière dépense. |
| XIX–XX | Préparer puis exécuter le plan contre Pâris et ses deux spectres. |

Les combats ne sont pas douze puzzles à solution unique. Leur identité vient
des rôles, du terrain, de l'ordre d'élimination et des ressources consommées.
La table décrit l'intention encodée, pas une preuve que tout joueur la percevra.

## Rééquilibrages et incohérences traitées

1. **Budgets fixes par rencontre.** Les ennemis ne lisent pas les PV, les
   attributs ou l'arme du joueur pour s'ajuster. Les packs à trois corps sont
   normalisés, au lieu d'être renforcés simplement par une cible supplémentaire.
2. **Outils qui conservaient des valeurs plates.** Salve, Braise, Urne et
   Coupe évoluent avec leur référence pertinente. Les réserves sont plafonnées
   au début du combat ; pas de recharge par un changement d'équipement.
3. **Conduction.** Le bonus r6 porte sur les dégâts élémentaires, non sur
   toute la Prouesse. Les sauvegardes historiques gardent leur ancien calcul.
4. **Secours tardifs.** Plaque vaut au moins 24 garde et 10 % des PV maximum
   en r6, pour rester une alternative aux +2 PM. Coût 1 PA, durée et usage
   unique conservés. Les autres fournitures ne sont pas gonflées globalement.
5. **Mémoires sans débouché.** Un secret à la profondeur déjà engagée ne peut
   plus être vendu comme une découverte utile. Sans secret futur, le service
   devient un choix unique garde/mobilité, sans ajouter de soin ou d'or.
6. **Progression et lisibilité.** Fenêtres de comparaison du kit espacées,
   alternative d'arme garantie dans les choix de récompense de II, avertissements
   sur les associations inactives, préparation XIX explicitement sans gain.
7. **Attaques retardées non affichées.** La logique de préparation existait,
   mais Battle n'instanciait pas son indicateur. Raccordement au plateau réel,
   suivi des cibles, isolation entre combats et nettoyage ajoutés. La revue GPU
   a aussi révélé une consigne coupée, puis trop petite à 1280 × 720 : le texte
   passe sur deux lignes et sa lisibilité est contrôlée aux deux résolutions.
8. **Haltes interactives attachées aux anciennes profondeurs.** Leur liaison
   était encore IV/VIII. En r6, les quatre lieux disponibles sont retrouvés
   par leur identité stable ; leurs services, reçus et sauvegardes restent
   inchangés. L'étal de IV conserve sa propre salle marchande, même lorsque
   la branche change de colonne. Les manifestes et illustrations ne sont pas
   remplacés. Les autres lieux gardent leur présentation normale.

## Audit des premières runs réelles

Le premier bot marteau/Normal/graine 2401 mourait au Léthé II après sept tours
sans action. Inspection du chemin : le tireur est accessible, avec un détour
que le bot refusait parce qu'il augmente temporairement la distance directe.
Le correctif porte sur **le pilote de test**, pas sur le terrain ou les ennemis.

Le même cas, avec ce détour autorisé, atteint XV sans modification des budgets.
Il y entre avec 537/924 PV et meurt en trois tours. Ce résultat ne prouve ni
que XV est injuste ni que Normal est bien calibré : il faut regarder les choix,
les secours réellement employés et plusieurs armes.

Preuves :

- `artifacts/catabase_run_balance_validation/first_case_2401_normal_marteau/report.json`.
- `artifacts/catabase_run_balance_validation/after_path_fallback_2401_normal_marteau/report.json`.

## Validation finale

### Douze runs continues, graine 2401

OBSERVÉ : les douze exécutions de la politique V2 se terminent sans erreur
moteur ou structurelle. Trois parcourent toute la route. Les autres sont des
échecs du bot, non des résultats de joueurs humains.

| Arme | Normal : dernière profondeur / tours héros | Facile : dernière profondeur / tours héros |
| --- | --- | --- |
| Arc | XX, victoire / 44 | XX, victoire / 43 |
| Disque | VI, défaite / 22 | XX, défaite / 57 |
| Hampe | V, défaite / 19 | XIII, défaite / 56 |
| Lame | VIII, défaite / 76 | XX, défaite / 78 |
| Marteau | XX, défaite / 60 | XX, victoire / 59 |
| Xiphos | VIII, défaite / 91 | VIII, plafond du pilote / 110 |

Preuve lue :
`artifacts/catabase_run_balance_validation/stage1_seed2401_v2/report.json`
et `summary.json` : 12/12, trois routes complètes, aucune erreur moteur.
Les 18 contrôles de sauvegarde/reprise atteints dans cette matrice réussissent.

**Interprétation bornée.** La politique appelée `balanced` dépense ici ses
attributs en Vitalité prioritaire, choisit le ravitaillement, n'achète pas chez
les marchands et ne sait pas planifier plusieurs tours. Elle n'est donc pas
un panel de builds équilibrés ni une estimation de jeu optimal. Les longs
combats Lame/Xiphos sont des cas à auditer, pas à effacer du rapport.

**Disque contre Arc.** Le Disque utilise réellement Lancer et Retour, mais
subit davantage d'attrition : il entre en VI avec 119/298 PV contre 211/298
pour l'Arc. Sa décision de déplacement ne valorise pas l'alignement de plusieurs
cibles pour le prochain Retour. INFÉRENCE : une part de son échec relève du
pilotage, sans exclure un écart de puissance. Aucun bonus arbitraire n'est
ajouté pour faire gagner le bot.

### Trois contre-tests du pilote, sans changement de difficulté

OBSERVÉ : les oscillations Lame/Xiphos ne sont pas une impossibilité du terrain.
Après deux tours sans attaque offensive, le pilote repère une alternance de
positions et emprunte le détour légal déjà calculé. Ce correctif ne donne ni
PA, ni PM, ni dégâts, ni soin supplémentaires.

- Lame Normal franchit désormais VIII, puis perd à XIII : 94 tours cumulés.
  À VIII, les positions répétées passent de 33 à huit, avec quatre détours forcés.
- Xiphos Normal perd encore en VIII ; les répétitions passent de 27 à six.
  Six Tailles contre 38 Salves montrent le biais défensif persistant du pilote.
- Xiphos Facile gagne la route, mais en 155 tours cumulés. Ce nombre n'est pas
  assimilé à une durée humaine ni présenté comme un rythme satisfaisant.

Les trois contre-tests sont sans erreur moteur. Preuves :
`artifacts/catabase_run_balance_validation/loop_recheck_lame_normal/report.json`
et `loop_recheck_xiphos_both/report.json` dans le même dossier parent.
Le [bilan détaillé du pilote](../../tools/catabase_run_balance_validation/STAGE1_SEED2401_V2.md)
conserve les résultats avant/après. Aucun autre réglage du bot n'est utilisé
pour fabriquer un bilan artificiellement favorable.

### Contrôles visuels dans le moteur

OBSERVÉ : le parcours GPU final réussit **127/127 contrôles**, six captures,
aucune erreur moteur. Les six images natives ont été inspectées : départ avec
choix Facile, préparation XIX et attaque retardée, chacun en 1280 × 720 et
1920 × 1080. Les commandes de compétences, inventaire et poursuite sont
réellement activées. Le panneau de départ reste défilable à 720 px.

Le télégraphe provient d'un vrai lancement ennemi, avec dépense de PA et état
en attente, dans la première salle peinte ; ni position ni événement ne sont
fabriqués pour l'image. Ligne et cible sont correctement placées. Le nom et
« brisez la ligne de vue » sont entiers, sur deux lignes, avec taille de texte
compensée pour le zoom. Les contrôles GUT complètent le suivi de cible et le
nettoyage entre combats. Le HUD de combat est désactivé dans cette capture
ciblée : elle ne certifie pas toutes les superpositions possibles d'une run.

Preuve finale :
`artifacts/catabase_run_balance_validation/r6_ui_telegraph_screen_constant_20260914_1810/summary.json`
et les six PNG du même dossier. Les essais précédents ayant révélé une erreur
de typage puis une taille insuffisante ne servent pas de preuve finale.

### Première régression élargie

OBSERVÉ : `./dev.ps1 test catabase`, 449 tests exécutés, 427 réussis,
22 échoués ; 69 580 assertions réussies sur 69 798. Rapport conservé :
`artifacts/dev/20260914-163953-test-catabase-a56a3a43/gut-strict-report.json`.
Cette exécution n'est **pas** présentée comme verte.

Les huit tests de route r6 et onze tests de budgets ennemis passent dans ce
lot. Deux défauts de validation sont identifiés et corrigés pour rejeu : type
manquant dans la détection de boucle du pilote, et fixture Conduction créant
une ancienne session après avoir initialisé les descriptions d'une nouvelle.

La migration de route impose aussi de dater explicitement les tests r5 ou de
les faire rejoindre les nouvelles haltes. Les échecs d'assets peints et
d'inventaire sont classés séparément : les peintures, leur registre et les
fichiers d'inventaire n'ont pas été modifiés par cette passe. Cela ne dispense
pas d'expliquer leurs attentes obsolètes ou leurs défauts ; les résultats
restent visibles et aucun asset n'est remplacé pour obtenir un test vert.

### Deuxième régression et correction des accès aux haltes

OBSERVÉ : le deuxième lot exécute 452 tests, dont 433 réussis et 19 échoués ;
69 089 assertions réussies sur 69 335. Les cinq suites ciblant les nouveaux
contrats passent : effets 8/8, rencontres 11/11, route 8/8, harnais 5/5 et
télégraphes 3/3. Preuve :
`artifacts/dev/20260914-171645-test-catabase-22f1e9c3/gut-strict-report.json`.

Trois échecs sont ensuite traités : le test des 17 peintures est rattaché à
sa vraie route historique r3 ; le raccord des haltes interactives suit maintenant
leur identité r6 plutôt que leurs anciennes profondeurs. L'étal IV n'est pas
la forge IX : chacun retrouve sa présentation. Rejeux ciblés sans erreur :

- Haltes et sauvegardes : 6/6 tests, 599 assertions,
  `artifacts/dev/20260914-172803-test-test_unit_test_painted_halt_catabase.gd-b984e4ad/gut-strict-report.json`.
- Peintures historiques et r6 : 9/9 tests, 6 004 assertions,
  `artifacts/dev/20260914-173022-test-test_unit_test_catabase_halt_art.gd-65a87fbd/gut-strict-report.json`.

Un ultime lot complet est exécuté après ces corrections ; son résultat figure
dans la section suivante, sans remplacer les traces des lots échoués.

### Résultat final de régression

OBSERVÉ : `./dev.ps1 test catabase` exécute les 53 scripts sélectionnés,
**454 tests : 438 réussis, 16 échoués**, aucun test ignoré ou en attente.
69 107 assertions réussies sur 69 238. Temps GUT : 299,635 secondes.
Le contrôle strict reste **FAIL** pour les raisons détaillées ci-dessous.

| Suites directement liées à cette intégration | Réussites |
| --- | --- |
| Mise à l'échelle des effets r6 | 8/8 |
| Budgets et placement des rencontres r6 | 11/11 |
| Route, récompenses, difficulté et sauvegardes r6 | 8/8 |
| Contrat du pilote de runs | 5/5 |
| Télégraphes tactiques | 3/3 |
| Peintures des haltes r3 et r6 | 9/9 |
| Accès aux haltes, transactions et reprises | 6/6 |

Ces **50 tests réussis** font partie du lot global, pas d'une liste blanche
qui en retirerait les échecs. Preuves finales lues :
`artifacts/dev/20260914-173134-test-catabase-014d0040/gut-strict-report.json`,
`gut.junit.xml` et les logs du même dossier. Les 16 échecs restants portent sur
les sept groupes de tests historiques décrits ci-dessous ; le détail nominal
est conservé dans `observed_failures` du rapport.

Aucune donnée de combat n'a été changée après la matrice et ses trois
contre-tests. Les derniers ajustements concernent la présentation, ses accès
et les fixtures ; ils ne servent pas à améliorer artificiellement les runs.

### Échecs historiques séparés du changement de gameplay

Comparaison en lecture seule avec `git show HEAD:...` et le diff courant,
sans changer de branche ni restaurer de fichier de production :

| Groupe | Tests échoués | Constat déjà présent dans le code de HEAD |
| --- | --- | --- |
| Sélection et seuil | 2 + 3 | Le catalogue contient déjà trois identifiants d'apparence (deux apparences d'Achille et Passe-rive) ; l'ancien test en attend deux. Le lancement ouvre déjà la préparation avant la première bataille, contrairement aux attentes de ces tests. Cela ne réintroduit pas d'autres personnages jouables dans la run. |
| Vertical slice | 2 | La salle historique III utilise déjà `cavern_crypt_v1`, tandis que le test attend `silent_judgment`. Salle V et planificateur ne sont pas modifiés par r6 ; l'ancienne contrainte de déploiement ne correspond pas à ces données. |
| Icônes, peintures, glyphes | 3 + 2 + 2 | Les registres, équipements et assets sont inchangés. Les tests figent encore 46 sorts, 55 nœuds, 12 équipements ou des empreintes de marqueurs antérieures au contenu actuel. Les équipements Catabase possèdent déjà leurs SVG de préparation. |
| Inventaire | 2 | Les fichiers sont inchangés ; le nombre de colonnes est déjà adaptatif à HEAD, alors que le test exige trois colonnes. Un contrôle de marge 1280 px échoue aussi et reste à reprendre dans une passe UI. |

Ces constats reposent sur le code et les données de HEAD, **pas sur une
exécution d'un autre checkout**. Les tests historiques ne sont ni supprimés ni
mis sur liste blanche. Leur résultat rouge demeure dans le rapport complet.

Le contrôle strict classe également l'accès à `grid_layout` sur une valeur
nulle dans l'ancien test de lancement (`test_catabase_selection_launch.gd:82`)
comme `PARSE_ERROR`, bien qu'il s'agisse ici d'une erreur à l'exécution de ce
test. Des diagnostics de ressources/ObjectDB apparaissent à la sortie du lot
complet ; leur provenance totale n'est pas attribuée par cet audit gameplay.
Ils ne sont pas masqués et empêchent de déclarer la régression générale verte.

Les seules adaptations de fixtures portent sur des contrats réellement changés
par r6 : anciennes routes miroir/bronze à dater r5 ; le catalogue historique de
17 destinations appartient, lui, à r3. Les nouveaux accès aux haltes sont
rejoints via les branches r6. Un test supplémentaire vérifie que les haltes r6
réutilisent les peintures avec le titre explicite de préparation finale.

### Pointeurs de code inspectés

- Route : `catabase_route_v6.gd`, `expedition_route_catalog.gd`,
  `expedition_route_state.gd`, `expedition_map_catalog.gd`.
- Transactions et sauvegarde : `expedition_session.gd`, `expedition_flow.gd`,
  `core/game_manager.gd`, `expedition_build_state.gd`, `painted_halt_catalog.gd`.
- Rencontres : `expedition_run_factory.gd`, `catabase_monster_encounter_catalog.gd`,
  `catabase_monster_evolution_catalog.gd`, `catabase_early_encounters.gd`.
- Effets : `catabase_first_six_spells.gd`, `catabase_combat_modifier.gd`,
  `catabase_preparation_catalog.gd`, `items/catabase_relic_results.gd`,
  `items/relic_runtime_service.gd`.
- Présentation : départ, écran de préparation et carte dans `ui/expedition/`,
  `battle/battle.gd`, `battle/tactical_telegraph_layer.gd`.

Les fichiers sans préfixe sont dans `core/expedition/`. La note
[audit tactique des rencontres](CATABASE_R6_ENCOUNTER_RUNTIME_AUDIT_2026-09-14.md)
détaille les contre-jeux, la géométrie et les répétitions restantes.

## Limites à ne pas masquer

- Un PASS de harnais signifie « exécution et métriques cohérentes », pas
  « le bot a gagné » et encore moins « la difficulté humaine est validée ».
- Les tests de transactions peuvent marquer des combats gagnés pour vérifier
  récompenses/sauvegardes ; ces tests ne servent pas de preuve de victoire.
- Le bot n'a ni perception visuelle ni temps de réflexion humain. Il ne prouve
  pas la durée 30–45 minutes ou une victoire Facile en quelques tentatives.
- Sagesse, récupération par montée de niveau, valeur relative des armes et
  temps des tours ennemis restent des axes de playtest à surveiller.
- Une seule graine est jouée avec les six armes dans les deux modes. Les
  81 chemins ordinaires sont vérifiés structurellement, pas tous joués en
  combat continu. Marchands et paris ne sont pas exploités par cette politique.
- Aucun commit, push, changement de branche, reset ou suppression de fichiers
  utilisateur n'est réalisé par cette mission.

## Essai utile suivant et critères encore ouverts

Commencer une **nouvelle Catabase** : une ancienne sauvegarde n'est pas migrée
silencieusement vers r6. Normal est la référence ; choisir Facile au dernier
écran de préparation pour comparer les mêmes plans avec davantage de marge.

Les critères de conception « une victoire reproductible avec chacun des six
presets » et « une victoire humaine de 30–45 minutes » ne sont pas encore
validés. Multiplier les graines avec un bot dont le placement et la politique
défensive sont insuffisants ne permettrait pas de les certifier.

La prochaine passe utile doit porter sur l'attrition I–VI du Disque et de la
Hampe, une partie Lame/Xiphos jouée offensivement, puis la fenêtre de
métamorphose de Pâris. Relever durée combat/menus, PV à chaque sortie, secours
et récompenses sacrifiées, cause de défaite et contre-jeu compris. Comparer
ensuite trois graines et les choix de provisions, au lieu de déduire un
rééquilibrage global des seuls résultats de la politique actuelle.

Ne pas imposer un quota de défaites : un joueur expérimenté peut gagner tôt.
L'objectif Normal reste une maîtrise nécessaire des priorités, du placement
et des ressources ; celui de Facile reste l'apprentissage en quelques essais.
