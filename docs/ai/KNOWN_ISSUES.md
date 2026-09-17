# Problèmes connus et suivis

## Présentation Cartes — WORKTREE_CANDIDATE, 2026-09-16

Base vérifiée : `main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + worktree.

- CORRIGÉ : dock séparé et commandes répétées ; la main utilise le vrai HUD.
- CORRIGÉ : noms longs faisant dépasser une main de six cartes à 720p.
- CORRIGÉ : états de sélection persistants après annulation, libellé CARTES
  perdu au rafraîchissement de thème, glissement des commandes après un tour.
- CORRIGÉ : panneau d'inspection recouvrant le haut de la nouvelle barre.
- CORRIGÉ DANS LA SONDE : arbre du HUD persistant non collecté ; compteur
  TIME_PROCESS contaminé par la capture, impropre à un percentile de performance.
- VÉRIFIÉ : 26 captures / 332 contrôles UI, cycle joueur/IA/joueur, 720p/1080p.
- OUVERT : marges sombres de la peinture à 720p ; confort humain sur une run,
  manette, autres ratios et trois drops longs non certifiés. Pas de nouvelle
  illustration propre à chaque sort ; deux assets communs créés seulement.
- Les 16 échecs de la suite Catabase élargie de la précédente itération ne sont
  pas déclarés résolus ; cette passe exécute des régressions ciblées de présentation.

[Résultats et preuves](CARDS_VISUAL_ITERATION_2026-09-16.md).

## Itération Cartes — WORKTREE_CANDIDATE, 2026-09-16

Base `main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + travaux locaux.

- CORRIGÉ : recomposition hors activation au niveau du modèle ; les refus
  ne dépensent ni PA ni carte. Départ/reprise remettent la porte d'activation à zéro.
- CORRIGÉ : disque/bronze/PA indisponibles explicités avant ciblage par le
  résolveur partagé ; conditions liées à la case toujours vérifiées au ciblage.
- CORRIGÉ : main empilée sur le HUD vide, actions tronquées dans les fixtures
  testées, copies de Geste répétées dans la réserve et remplacement global.
- CORRIGÉ : écran de butin ouvert trop bas par le focus ; ajout au deck visible
  à 720p/1080p pour les drops de la fixture. Trois familles longues restent à
  vérifier visuellement ; tous les formats et toutes les salles ne sont pas certifiés.
- AJUSTÉ : provisions Cartes 20 oboles, pas 40 ni 0. Le budget humain et la
  valeur relative des choix restent à mesurer. L'Arc bénéficie aussi de ces oboles.
- OUVERT : Disque/Hampe fragiles avec les pilotes testés, adaptation automatique
  du deck souvent moins bonne que le deck initial. Ce n'est pas une preuve que
  leurs cartes doivent être renforcées ; pilotage, ordre et composition interagissent.
- LIMITE VISUELLE : cadrage Cartes protège les dalles mais réduit la peinture ;
  des marges sombres subsistent en 720p. Pas de nouvelle illustration de cartes.
- RÉGRESSION ÉLARGIE NON VERTE : 463/479 tests passent. Les 16 cas en échec,
  les textes d'erreurs et les fuites de fin sont identiques au lot du même HEAD
  exécuté le matin avant cette itération. Assets/icônes, ancien lancement/seuil,
  vertical slice et inventaire restent ouverts ; aucun nouvel identifiant
  d'échec constaté. Rapport `artifacts/dev/20260916-160717-test-catabase-ad18eb93/`.
- INCONNU : plaisir, durée 30–45 min, progression d'apprentissage humaine,
  confort manette et performances GPU en plein combat. Pas de certification studio.

Preuves et résultats de régression : [itération](CARDS_ITERATION_2026-09-16.md).

## Audit Cartes initial — HISTORIQUE après l'itération du 2026-09-16

Base `main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + variante Cartes locale.
180 runs de bots / 1 493 combats, 7 tests / 71 689 assertions, 90 contrôles UI /
12 captures. Aucun changement de règles de production dans cette mission.

- OBSERVÉ, UX P1 : à six cartes, main sur 16,96 % du viewport 720p, masque
  une partie d'ennemi ; noms d'actions tronqués aussi en 1080p. Réserve dominée
  par les copies de Geste et remplacement via sélecteur global.
- OBSERVÉ, feedback P1 : disponibilité du bouton ne reflète pas tous les
  prérequis métier (disque lancé, bronze). Le cast effectif reste validé.
- OBSERVÉ, défense en profondeur P2 : API `recompose()` accepte un appel
  hors activation si les PA restent présents ; l'UI bloque ce cas. Pas
  d'exploitation par le joueur démontrée.
- OBSERVÉ, outillage : ancien pilote sous-évalue Répercussion, dont le vrai
  dégât dépend du bronze. Contre-pilote et test du résolveur ajoutés ; ne pas
  utiliser le classement historique seul pour augmenter les dégâts du xiphos.
- RISQUE À ÉVALUER : revente moyenne 212,53 oboles sur 1 000 séquences avec pool
  initial figé, contre jusqu'à 440 via onze choix des anciennes fournitures.
  Ce n'est pas une comparaison de valeur totale ; prix des services à réexaminer.
- INCONNU : taux de victoire, plaisir, durée humaine, performance FPS fiable,
  animations Passe-rive et combinaisons non parcourues. Les bots ne les valident pas.

Preuves, limites, priorités et sources :
[audit expérimental complet](CARDS_STUDIO_AUDIT_2026-09-16.md).

## Catabase Cartes — WORKTREE_CANDIDATE, 2026-09-16

Base `main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + worktree.

- INCONNU : difficulté, durée et choix économiques humains du mode Cartes.
  Le catalogue et les stats existants sont réutilisés ; la nouvelle contrainte
  de pioche et la souplesse des drops nécessitent des essais comparatifs.
- LIMITE DE CONTENU : les raretés Mythique/Légendaire peuvent être absentes
  du pool légal. Poids nominaux renormalisés, pas de taux effectif mensonger.
- LIMITE DE PRÉSENTATION : réserve longue à faire défiler ; pas de filtre
  avancé ni nouvelle illustration de chaque carte. Depuis l'itération, copies
  regroupées et effets accessibles aussi par bouton ; défilement encore nécessaire.
- HORS PÉRIMÈTRE : pas de nouvelles cartes consommées définitivement pendant
  la run ou de permanents inédits, ni marché entre joueurs.
- NON VÉRIFIÉ : difficulté humaine 30–45 min, manette exhaustive, autres OS
  et CI globale. Le rapport donne les vérifications ciblées réellement faites.

Preuves : [rapport Cartes](CARDS_RUN_IMPLEMENTATION_NOTES.md).

## Mort Catabase — candidat du 2026-09-15

Base `main@40ea393dcd539c63f2aa7f024271524f65ade399`, modifications locales.

- CORRIGÉ DANS LE CANDIDAT : le résultat Catabase ouvrait l'Archiviste,
  dont le catalogue historique sélectionne l'ancienne aventure à trois héros.
  La nouvelle tentative passe désormais par la sélection publique solo.
- CORRIGÉ DANS LE CANDIDAT : le bilan utilisait les compteurs génériques de
  salles ; il expose maintenant les faits de la route et le nom Passe-rive.
- PROTECTION AJOUTÉE : après une suppression terminale impossible, les sorties
  titre/hub/abandon ne remplacent plus l'opération de fin par une autre action.
- HORS PÉRIMÈTRE : les contenus Archiviste/trio restent dans le dépôt et ses
  laboratoires. Ce correctif n'en effectue pas une purge générale.
- OBSERVÉ HORS CORRECTIF : la sélection publique affiche encore « Incarner
  Achille » pour Passe-rive. La configuration obtenue est bien Passe-rive dans
  Catabase (probe GPU), mais ce libellé mérite une harmonisation ultérieure.
- NON DÉCIDÉ : conséquences supplémentaires de la mort, résurrection ou
  méta-progression ; brainstorming utilisateur ultérieur.

Résultats réellement exécutés et limites :
[rapport du correctif](CATABASE_DEATH_FLOW_2026-09-15.md).

## Catabase r6 — suivi du candidat 2026-09-14

Base `main@055584c37f60d99b2f87bdbb4d670895bf8ef2b2`, worktree non commité.

- INCONNU : durée et difficulté humaines de la run 30–45 min. Une victoire ou
  une défaite de bot ne constitue pas un taux de victoire humain.
- À SURVEILLER : poids des premiers points de Sagesse, récupération issue des
  montées de niveau, intérêt relatif des six armes et lenteur des phases IA.
- CORRIGÉ DANS LE CANDIDAT : Salve/réserves/Braise qui devenaient des valeurs
  plates tardives ; Conduction globale malgré sa vocation élémentaire ;
  préparation finale pouvant être confondue avec un quatrième refuge.
- CORRIGÉ DANS LE CANDIDAT : découverte d'un secret à la profondeur déjà
  engagée ; les mémoires devenues sans débouché offrent désormais un choix
  unique entre deux fournitures tactiques existantes.
- CORRIGÉ DANS LE CANDIDAT : indicateurs des attaques préparées non raccordés
  au plateau ; nom/contre-jeu désormais entiers et lisibles à 720p/1080p.
  Sentence/Visée conservent un libellé générique, amélioration P2 documentée.
- CORRIGÉ DANS LE CANDIDAT : accès aux haltes interactives encore indexés sur
  les anciennes profondeurs. Les quatre lieux disponibles suivent leur identité
  r6 ; l'étal de IV conserve sa salle propre malgré les inversions de colonnes.
- RÉGRESSION ÉLARGIE NON VERTE : 438/454 tests réussis, 16 échecs historiques
  classés dans le rapport r6 (assets, ancien lancement, vertical slice,
  inventaire). L'ancien test de lancement accède à une salle nulle ; le lot
  rapporte aussi des ressources non libérées à sa fermeture, dont l'origine
  totale reste non attribuée. Aucun échec n'est masqué. Les sept suites liées
  à l'intégration passent à 50/50 ; runs et GPU ne rapportent pas d'erreur moteur.
- Les points ci-dessus ne sont pas une déclaration CURRENT générale :
  [preuves et tâches restantes](CATABASE_R6_WORKLOG_2026-09-14.md).

## Studio Terrain — suites du test humain 2026-08-24

- **PROUVÉ** — les champs de données `random_destination` et
  `single_vortex_effect_id` ne pilotent pas la branche runtime actuelle, qui
  choisit le comportement selon le nombre de cases. Ils doivent être clarifiés
  ou supprimés lors de la décision vortex, pas silencieusement dans cette passe.
- **RAPPORTÉ** — le propriétaire poursuivra plus tard le test humain des étapes
  suivant l'ajustement de la grille.
- **À CONFIRMER** — le confort réel du nouveau choix vortex et du sélecteur
  direct d'illustration doit encore être confirmé par ce test humain. Les tests
  automatisés et les captures ne remplacent pas cette validation d'usage.

## Arena authoring — réserves du candidat 2026-08-12

- Le bundle gelé `data/arenas/produced/room_01_forest` possède un UID de profil
  invalide ; les shards GUT qui interdisent les warnings inattendus le comptent
  comme échec. La mission ne le réécrit pas.
- `data/runs/profiles/test_content_profile.tres` comporte aussi des UID
  historiques résolus par chemin texte.
- Le renderer headless de Godot 4.7.1 a subi un crash natif avant `_ready` pour
  le runner de captures. Le renderer Windows D3D12 direct est vert à 88/88.
- La revue humaine interactive des nouveaux assistants reste à faire ; les
  captures vérifient néanmoins la lisibilité en 1280x720.

## Catalogue complet des terrains — avertissements candidat

- Le bundle non suivi `data/arenas/produced/room_01_forest` reste gelé et n’est
  ni une production canonique ni une source de Tester.
- La baseline globale conserve ses échecs historiques ; aucune carte de
  production n’est réécrite par ce candidat.
- Les chiffres Poison sont provisoires et doivent être réévalués par playtest.
- Les runners Godot peuvent encore rapporter les fuites renderer/ObjectDB et le
  doublon `output/validation-feedback-candidate/.../ItemDefinition` historiques.

## L’Odyssée — limites du candidat Meshy V3

- Le candidat courant utilise directement le modèle Meshy, son rig de 24 os et
  ses 20 animations natives. Aucun clip n’est retargeté et les V1/V2 restent
  conservées uniquement comme assets historiques.
- Le repos est explicitement lié à `Idle_11`, la marche à `Walking` et la
  course rapide à `run_fast_3_inplace`. Le seuil reste 1–5 cases = marche et
  6+ = course ; avec 3 PM de base, la course automatique demande normalement
  un bonus de déplacement ou une future règle. La marche est ralentie à 75 %
  et 0,40 s par case ; la course garde 0,20 s par case.
- Le profil peint utilise une base et un minimum de 1,0, avec un maximum de
  1,15. Les valeurs finales attendues sont 1,05 / 1,08 / 1,10 dans les trois
  cartes ; l’ancien calibrage proche de 2,0 n’est plus courant.
- Les quatre capacités possèdent des affectations distinctes dans le pool V3.
  Les clips d’action conçus autour d’une arme restent cependant sans contact
  d’équipement : le modèle Meshy n’embarque ni arme, ni bouclier, ni arc.
- La source ne fournit aucune animation de mort. Le fondu de l’adaptateur reste
  le rendu de mort prévu.
- Le corps de grille et l’aperçu 3D utilisent la V3. Le portrait du HUD reste
  l’illustration 2D historique ; il n’est pas un rendu animé du GLB.
- Les clips avec forte translation de hanche sont neutralisés localement afin
  de conserver la grille comme autorité. Les 13 captures finales valident le
  cadrage général ; une future passe artistique pourra encore polir les appuis
  et les transitions.
- Validation actuelle : tests ciblés proportions/V3/locomotion/Odyssée et
  squelettes 61/61 (1 102 assertions),
  Studio 19/19 (208 assertions) et binding SHA-exact 34/34 (643 assertions).
  La comparaison graphique relie les vrais identifiants Odyssée aux profils
  ennemis et maintient les trois familles à ±5 % de la hauteur rendue
  d'Achille. Le full-flow post-calibrage produit 13 captures ; Achille mesure
  environ 102,86 / 104,94 / 107,76 px après la réduction commune de 8,1 %.
- Les runners graphiques peuvent encore signaler des ressources renderer ou
  `ObjectDB` à la fermeture, après le marqueur PASS et avec un code de sortie
  nul. Cette dette de teardown n'est pas attribuée au gameplay Meshy.
- Lorsqu'il est sélectionné, le modèle Meshy apparaît sombre/bleuté et ses
  détails de matière sont peu perceptibles. C'est la prochaine priorité
  cosmétique.
- Les captures fixes prouvent le choix `Walking` / `run_fast_3_inplace`, mais
  une future revue vidéo restera utile pour affiner la cadence au-delà du
  réglage actuel validé mécaniquement.
- `Percée` conserve la grille comme autorité et se recale sur la case finale ;
  sa transition visuelle entre les deux cases reste sans tween de finition.
- La cible de durée 18–25 minutes et une partie humaine non forcée n’ont pas
  encore été validées. Les récompenses d’équipement restent désactivées.
- La modification concerne L’Odyssée, run solo officielle. Les runs au trio et
  leurs contenus historiques restent inchangés.

État courant vérifié le 2026-08-23 avec Godot 4.7.1 et GUT 9.7.1 ;
validation graphique finale : PASS / GO.

## Run content isolation

- Aucun partage mutable interdit n’est connu entre les deux profils officiels ;
  l’audit mesure `progression_shared_count = 0`.
- Les `hero_sources` de `LanternboundArchivistData` et les constantes de trio de
  `GameManager` restent volontairement comme compatibilité legacy. Les runs
  officielles ne les utilisent pas comme autorité.
- Le Studio Skill Tree 2.0 candidat ouvre désormais le profil de progression de
  la run. La voie `open(UnitData)` reste conservée pour les tests et documents
  legacy, mais elle n’est pas l’autorité d’une session run-aware.
- Le runner de migration direct peut afficher, après son rapport `ok: true`, des
  diagnostics CLI historiques liés à l’ordre de chargement de `DebugLogger`.
  Le scan éditeur et les suites GUT compilent les services correctement.

## Reclassifié par RUN_FLOW_ISOLATION_V1

- **Vagues dans la run principale** : résolu dans le diff local par la politique
  sérialisée `SINGLE_ENCOUNTER`, le nettoyage des six salles de production et les
  gardes runtime/UI. La clôture définitive attend une suite complète verte.

## Dette technique préexistante observée

- `data/units/alliés/Guerrier.tres` contient l’UID invalide
  `uid://0flkpto1jkby` pour `frappe_lourde.tres`. Le fallback par chemin fonctionne,
  mais GUT peut comptabiliser l’avertissement comme erreur inattendue lors de
  lancements ciblés historiques.
- Le scan final charge aussi quatre assets GLB (trois ennemis et l’Elfe) dont un
  UID de texture est résolu par le chemin texte. Les sources et imports existent ;
  Godot termine le scan avec le code 0.
- `output/validation-feedback-candidate/data/items/item_definition.gd` redéclare
  la classe globale `ItemDefinition` et provoque une erreur de parsing à l’import.
- La suite complète finale est stable à 787/800. Les 13 échecs sont inventoriés
  dans `RUN_CONTENT_ISOLATION_VALIDATION.md` : captures absentes, textures pause
  nulles, contrats Elfe déjà incompatibles avec `eagle_eye.tres`, et comparaison
  flottante. Aucun de ces fichiers n’est modifié par la mission.
- Les runners graphiques existants laissent des ressources renderer signalées à
  la fermeture ; le smoke termine néanmoins avec le code 0 et son contrat PASS.

## Studio 2.0 candidat

- Les barres et graphes restent denses en 1280×720 ; les contrôles utilisent
  maintenant des lignes repliables, des scrolls et des tooltips. Le grand
  viewport 1920×1080 demeure la vue de production recommandée.
- Le réimport conserve `occlusion.png` dans `ArenaDefinition.occlusion_mask_path`.
  Le runtime actuel continue cependant d’utiliser le foreground et le polygone
  d’occlusion canoniques pour le Y-sort ; le masque importé reste une couche de
  livraison tant qu’un renderer bitmap dédié n’est pas adopté.
- Les runners Studio 2.0 signalent des fuites `ObjectDB` à la fermeture, comme
  les runners graphiques de baseline. Aucun échec fonctionnel ciblé n’en résulte.
- Le statut reste `WORKTREE_CANDIDATE` : aucune activation `CURRENT`, aucun
  commit et aucune publication ne font partie de cette mission.

## Conséquences de design à mesurer

- recalibrage futur de la durée de la principale ;
- cadence XP après réduction du nombre de combats ;
- validation de l’attrition sur les six rencontres ;
- distinction future entre rencontre, renfort et phase persistante.

Ces suivis sont des conséquences attendues de la décision de design, pas des
régressions introduites par la migration.

## Item Studio V1 — limites WORKTREE_CANDIDATE

- Date : 2026-08-07 ; branche `main` ; HEAD de base
  `29f307b5ff61822f266bbd2d14636ca8dcea2d95`.
- Statut : **WORKTREE_CANDIDATE**.
- Tests : Item Studio 30/30 (190 assertions), smoke PASS, captures inspectées ; activation à un
  commit et revue humaine interactive non vérifiées.
- Il n’existe aucun runtime de reliques au HEAD. Les chemins historiques
  `data/relics/**` et `data/equipment/**` ne sont pas importés.
- Il n’existe aucun catalogue d’objets spécifique par run ; la publication
  `RUN_SPECIFIC` est bloquée explicitement.
- Les nouvelles familles déclenchées nécessitant des hooks inédits doivent être
  implémentées et enregistrées avant d’être éditables.
- Les effets dépendant d’une grille de bataille sont signalés lorsque la sandbox
  pure ne peut pas les exécuter intégralement.
- Le scan d’éditeur rencontre toujours la copie historique
  `output/validation-feedback-candidate/data/items/item_definition.gd`, qui
  masque la classe globale. Ce fichier préexistant n’est pas modifié.
- Les runners graphiques signalent encore des ressources renderer et ObjectDB à
  la fermeture, sans échec fonctionnel des marqueurs ciblés.
# Réserves Arena Studio 2.0 — candidat local 2026-08-10

- La suite globale possède une allowlist de 13 échecs historiques ; aucun nouvel échec n’est accepté.
- `output/validation-feedback-candidate/data/items/item_definition.gd` masque une classe globale pendant le scan ; anomalie historique hors périmètre.
- Godot signale des fuites RID/ObjectDB de fermeture déjà observées.
- `res://data/arenas/produced/room_01_forest/` est un bundle incomplet gelé, non canonique et non utilisable pour Tester.
- Les 187 fichiers Achilles/VFX/outillage non trackés et 10 suppressions Achilles sont un travail externe à préserver.
- Deux répétitions globales Windows post-correction responsive ont été instables au niveau du processus (timeout en progression puis sortie native `-1`) sans nouvel échec d’assertion observé. Le dernier global complet conserve exactement les 13 historiques ; les suites UI/visuelles affectées sont vertes séparément.

## Refonte du Studio Terrain — limites du candidat 2026-08-24

- Statut : **WORKTREE_CANDIDATE**. Aucun commit, aucun stage, aucun push.
- `ArenaRuntimeBridge.sync_runtime_resources()` est désormais strictement non
  mutante sur la working copy. `grid_layout`, `painted_map_visual_data`, zones
  de départ, ennemis, `room_name`, `arena_visual_profile` et `battle_scene`
  sont résolus sur une projection séparée. La politique conserve cependant
  l'autorité historique de ces champs pour une `RoomData` et pour une
  `ArenaDefinition` déjà produite. Seule une `ArenaDefinition` explicitement
  marquée comme document d'auteur traite ces valeurs comme dérivées.
- La barre historique interne (`ArenaStudioMain.top_bar`) n'apparaît plus que
  dans un hôte autonome, en mode avancé et au-dessus de 760 px de haut.
  `StudioWorkspace` la désactive : c'est l'en-tête Terrain qui porte
  désormais Accueil, Nouveau terrain, Ouvrir et le mode guidé.
- À 1280 × 720, ouvrir le tiroir inférieur efface temporairement le guidage
  contextuel : les deux ne tiennent pas ensemble au-dessus du canvas. La
  préférence de l'utilisateur n'est pas modifiée et le guidage revient à la
  fermeture du tiroir.
- Le rail des étapes, la palette contextuelle et l'inspecteur défilent. Une
  action peut donc se trouver sous la ligne de flottaison de son panneau ;
  elle reste atteignable au clavier et à la molette. Les captures vérifient
  qu'aucune action primaire hors zone défilante ne sort de la fenêtre.
- La visite guidée de 22 pages est conservée comme aide détaillée, accessible
  depuis le glossaire. Elle n'est plus le parcours nominal et son contenu
  emploie encore le vocabulaire technique historique.
- Quelques messages du validateur conservent des accents manquants hérités
  (« est place sur la bordure »). Ils sont affichés tels quels dans les cartes
  de validation ; leur correction touche des chaînes assertées par d'autres
  tests et n'entre pas dans ce chantier.
- La revue humaine interactive dans Godot reste à faire. Les captures
  prouvent la lisibilité et l'absence de débordement, pas le confort réel.

## Authoring spatial Terrain V2 — limites du candidat 2026-08-25

- Les anciens composants de rail d'étapes, guidage et palettes contextuelles
  restent dans le dépôt pour compatibilité, mais ne sont plus instanciés dans le
  parcours nominal.
- `set_current_step()` et l'état `step` persistent comme adaptateurs de
  compatibilité ; ils ne pilotent plus les outils ni les panneaux.
- La visite historique demeure une aide facultative et peut encore employer le
  vocabulaire de l'ancien parcours.
- La revue humaine interactive dans l'éditeur Godot reste distincte des
  captures automatisées et du smoke headless.

## Catabase — limites du candidat cinématique V4 2026-08-28

- Statut : **WORKTREE_CANDIDATE**. Aucun commit, stage, push ou marquage CURRENT.
- Deux sources fournies contredisent le contrat 1920 x 1080 :
  `01_troie_assiegee.png` et `03_achille_choisit_troie.png` mesurent
  1672 x 941. Elles sont conservées byte-for-byte et mises à l'échelle en
  préservant leur ratio ; leur remplacement par des masters 1920 x 1080 reste
  nécessaire avant validation artistique finale.
- Aucun visuel Paris dédié n'existe dans le dépôt. L'Ombre de Paris réutilise
  temporairement le meilleur archer spectral compatible et reste explicitement
  `PLACEHOLDER_VISUAL`. Ses statistiques restent `PLACEHOLDER_BALANCE` et ne
  sont pas inscrites dans `BALANCE_BASELINE.md`.
- EB Garamond n'est pas légalement présente dans le dépôt. Le lecteur réutilise
  `LobsterTwo`, la serif déjà approuvée du projet, tout en conservant la
  hiérarchie et les proportions. L'écart typographique avec la référence MP4
  demande une revue humaine.
- Seule la localisation française exacte est livrée. La traduction anglaise
  est absente par décision de périmètre ; le français sert de fallback.
- `Catabase.mp3` est une source utilisateur prémixée : la musique et ses effets
  ne peuvent pas être ajustés séparément. Sa durée réellement importée par
  Godot est 80,053497 s, et non l'estimation 80,088 s du brief. Sa provenance
  est consignée ; son statut juridique reste `TO_CONFIRM`.
- Le MP4 de référence n'est pas embarqué au runtime. Les textes restent rendus
  par Godot ; les captures prises exactement au début d'un cue montrent donc
  normalement son alpha initial nul pendant le fondu ASS.
- Les salles techniques `odyssey` 2 et 3 ne sont pas renommées : leur migration
  était explicitement hors périmètre. Les IDs, dossiers, économie, seed,
  reliques et progression restent inchangés.
- La fermeture forcée des runners graphiques signale des ressources renderer,
  comme les runners historiques du dépôt, sans échec fonctionnel ciblé.
- Le visionnage et l'écoute humains continus des 72 secondes, ainsi que les
  skips perçus vers 2, 35 et 69 secondes, restent obligatoires avant toute
  déclaration prête ou CURRENT.
