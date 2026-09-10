# Reprise locale — pipeline de personnages

## Orientation actuelle — dessin guidé par Blender, 10 septembre 2026

L'utilisateur valide le gain de cohérence du mannequin, mais rejette l'habillage
`sentinelle_armor_v1`, trop éloigné du sprite original. Il propose désormais
Blender comme référence des poses et des appuis, avec génération des dessins
complets depuis le sprite original. Le kit initial apprécié est celui d'Achille.

La [fiche de l'essai guidé](../../art/source/sprite_workshop/sentinelle_guided_v1/README.md)
contient quatre poses techniques de l'estoc E et le prompt. La génération reste
bloquée par une erreur d'accès aux images du bac à sable Codex : aucun nouveau
sprite ni résultat artistique validé à ce stade. Les sections suivantes
conservent l'historique ; l'armure 3D n'est pas la référence artistique à poursuivre.


## Pilote Blender commencé — 10 septembre 2026

Blender et sa connexion MCP sont maintenant configurés. Le
[guide du pilote Blender](../../tools/blender_sentinelle/README.md) donne le fichier
éditable, le panneau de revue, les versions et les preuves. Un mannequin commun
aux quatre vues et un premier estoc sont construits. **Les poses attendent la
revue artistique** avant toute préparation des pièces peintes ou déclinaison du kit.


## Dernier retour — 10 septembre 2026, après V7

La cohérence artistique reste insuffisante selon l'utilisateur. Le
[diagnostic de méthode](diagnostic_methode_2026-09-10.md) est la lecture prioritaire :
directions E/S ambiguës, pièces issues de PNG aplatis, bassin/thorax non séparés,
poses du corps entier non validées avant la déclinaison du kit. Audit sur Git
`2473c335` et JSON V7 hachés ; rapport dans
`artifacts/dev/sentinelle-method-audit-20260910/report.json`.
Blender 5.1.2 présent, connexion MCP non joignable lors du contrôle. Prochain
pilote recommandé : référence spatiale simple, un estoc dans une vue vérifiée,
validation des poses puis habillage articulable et revue en contexte Godot.
Aucun nouveau kit produit pendant cette recherche. Les sections suivantes
conservent les constats historiques et les validations de l'installation.


Constats du 9 septembre 2026, base Git `1b5cedb0` (`direction spine`).
À l'ouverture, seul `tools/sprite_workshop/experiments/sentinelle_probe.gd.uid`
était non suivi ; il est conservé. Relire Git avant de réutiliser cette fiche.

## Contexte à charger selon le besoin

- [Dossier Spine](README.md) et [évaluation](../tools/spine_assessment_2026-09-09.md) : connecteur, formats et protocole proposé. Pas encore de connecteur Spine installé, de runtime Spine-Godot ni de production Spine validée.
- [Atelier Godot](../../tools/sprite_workshop/README.md) : scène `SpriteWorkshop.tscn`, menu Studio, comparaison, montage, événements, contrôles et export de clips.
- [Pipeline monstres](../../tools/catabase_monster_sprite_pipeline/README.md) : vues indépendantes, pièces articulées, IK et assembleur existants.
- [Kit Achille](../../tools/achilles_kit_sprite_pipeline/README.md) : ancrages, atlas et synchronisation de la ruée avec l'arrivée réelle.
- [Références](../tools/sprite_motion_references_2026-09-09.md) et [bilan Sentinelle](../tools/sentinelle_attack_pilot_2026-09-09.md) : variantes A/B/B2 rejetées ; conserver la ruée d'Achille appréciée. Pas de directions fabriquées par miroir.
- [Outils de contexte](../../tools/dev/README.md) : `dev.ps1 context`, inspection des ressources, rapports compacts et tests stricts. Lire les détails seulement selon le besoin ; aucune économie chiffrée de tokens démontrée.

## Environnement retrouvé et restauré

- Godot ouvert sur Dungeon Draft. Console vérifiée : `C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe`, version `4.7.1.stable.official.a13da4feb`, GUT `9.7.1`. Chemin mémorisé par `doctor` dans `artifacts/dev-tools/local.json`.
- Connecteur Godot : ancien chemin périmé ; override `mcp_servers.godot.env.GODOT_PATH` dans `.codex/config.toml`, limité au projet. Configuration effective vérifiée avec `codex mcp get godot --json` et bon numéro de version reçu via un serveur MCP temporaire. La connexion déjà chargée dans cette tâche n'est pas redémarrée.
- Spine Trial installé dans `C:/Program Files/Spine Trial/`, processus ouvert et installateur conservé dans les téléchargements. `C:/Users/paolo/SpineTrial/version.txt` contient `latestbeta` : canal de sélection, pas version précise. Constater la version dans Spine avant de choisir le lecteur ; le candidat MCP étudié cible 4.2.
- [Limites officielles de la trial](https://esotericsoftware.com/spine-download), relues le 9 septembre : pas de sauvegarde, texture packing ou export personnel ; exemples avec exports fournis pour évaluer les runtimes.
- Formateur `0.25.0` et Workbench restaurés depuis les archives verrouillées dans `toolchain.json`, avec vérification SHA256. Workbench : tests Go réussis, compilation et protocole de l'addon vérifiés ; première tentative échouée sur un renommage Windows de dépendance. Logs conservés dans `artifacts/dev-tools/workbench-tests.log`, `workbench-modules-retry.log` et `workbench-tests-retry.log`.
- Workbench configuré en mode `lite`, avec les 20 outils de `tools/dev/workbench-tools.json`. Configuration effective vérifiée. Recharger la connexion MCP pour les exposer dans une nouvelle session.
- Python isolé : `artifacts/dev-tools/sprite-python/Scripts/python.exe`. Pillow `12.3.0`, NumPy `2.5.3`, SciPy `1.18.1` ; versions conservées dans `artifacts/dev-tools/sprite-python-requirements.txt`. Le Python du PATH n'avait pas ces dépendances ; aucun paquet global modifié.
- Node : `C:/Program Files/nodejs/node.exe`. Dépendances fournies par Codex : `C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules`. Utiliser `NODE_PATH` ou `SHARP_PATH` selon le script.

## Vérifications de cette reprise

Dossiers relatifs à `artifacts/dev/` ; lire leurs résumés puis les détails utiles.

| Contrôle | Résultat | Dossier |
| --- | --- | --- |
| Diagnostic final | PASS, moteur et outils présents ; ce diagnostic seul ne teste pas l'import | `20260909-190649-doctor--5f15defc` |
| Import Godot et GUT atelier | PASS, 13 tests / 88 assertions | `20260909-185742-test-test_unit_test_sprite_clip_workshop.gd-f4600143` |
| MCP Godot, lecture de version | PASS, 4.7.1 | `godot-mcp-1788973412250` |
| Workbench, éditeur et runtime isolés | PASS, 8 contrôles (connexion, inspection, état, capture, arrêt, déconnexion) | `workbench-ad08a0d9-f325-40a7-8899-fb11e92874e8` |
| Document Achille, 4 poses | PASS technique, revue formelle absente | `20260909-190002-sprites-check-28228038` |
| Document historique Sentinelle | FAIL d'empreintes, diagnostic ci-dessous | `20260909-190021-sprites-check-c35f8e96` |
| Nouvel import Sentinelle | PASS | `20260909-190308-sprites-import-c784b142` |
| Nouvel import, 8 poses | PASS technique, sans approbation artistique | `20260909-190431-sprites-check-8a1729e0` |
| Assets Sentinelle | PASS, N/E/S/W complets | `20260909-190429-reprise-sentinelle-assets-48c0628d` |

Le document historique Sentinelle conserve les empreintes CRLF de `sprite_frames.tres`
et `sentinelle_airain_sprite_profile.tres`. Les fichiers actuels sont en LF ;
leur conversion en mémoire vers CRLF reproduit exactement les empreintes historiques.
Les empreintes historiques et les assets de production sont conservés.
L'import public a créé un document distinct depuis les ressources actuelles :
`artifacts/sprite_workshop/reprise_20260909/sentinelle_attack_e.json`.
Il reprend l'attaque existante ; aucune amélioration artistique n'est revendiquée.

Les anciens rapports et le comparatif HTML du pilote sont absents de cette copie.
Les PNG, prompts et JSON restent présents sous
`art/source/sprite_workshop/sentinelle_attack_pilot_2026-09-09/`.
Les résultats historiques restent documentaires ; les rapports n'ont pas été
récupérés ni recréés. Aucun essai de combat ni suite CI globale relancé ici.

## Suite du chantier Spine

1. Recharger les connexions MCP du projet et constater la version précise de Spine Trial.
2. Ouvrir un exemple officiel ; évaluer le connecteur retenu sur une copie, notamment Windows et format.
3. Éprouver les exports fournis dans un runtime Godot compatible si cette sortie est retenue. La trial ne permet pas d'exporter un nouveau pilote personnel.
4. Reprendre ensuite l'estoc Sentinelle par poses complètes, vue frontale puis arrière, avec revue de la mécanique corporelle avant les détails.

## Kit complet demandé — livraison du 9 septembre, 20 h 20

- Révision retenue : `art/source/spine/sentinelle_kit_v5/`, 24 clips E/S/W/N.
- Reprendre par `docs/spine/sentinelle_kit.md`, puis seulement les sources nécessaires.
- Galerie : `http://127.0.0.1:8734/files/sentinelle_kit_v5/review.html`.
- Commandes : `./tools/spine_trial/kit.ps1 start|verify|godot|build`.
- Rig 16 os : épaulières séparées, pieds articulés ; IK cuit à environ 30 clés/s.
- Recettes : `tools/spine_trial/sentinelle_kit.py`. Pont commun : `prepare_sentinelle.py`.
- Clips : idle 2.4, walk .72, attack .8, cast .88, hit .2, death .8 secondes.
- Impact .4, émission .44. Quatre dessins originaux ; aucune symétrie automatique.
- Vérifié : 24 clips web + 24 Godot, 22 mesures géométriques, smoke 16 tests / 215 assertions.
- Captures des 24 clips examinées ; première proposition artistique à revoir avec l’utilisateur.
- Preuves et hachages : `art/source/spine/sentinelle_kit_v5/validation.json`.
- Limites : JSON 4.2.22, trial 4.3.26 sans sauvegarde/export ; import éditeur non constaté.
- Lint : aucune erreur ; avertissements de densité dus au calcul des articulations,
  informations de raccord uniquement sur la mort, qui ne boucle pas.
- Les ressources du combat n’ont pas été remplacées. Pas de commit créé.
- Préserver `tools/sprite_workshop/experiments/sentinelle_probe.gd.uid`, préexistant.

## Retour utilisateur du 10 septembre — proposition V7

- La V5 a été jugée insuffisante : marche et estoc incohérents, chute rejetée,
  sort trop discret. Ne pas confondre les anciens tests réussis avec une approbation artistique.
- Courant : `art/source/spine/sentinelle_kit_v7/` ; guide `docs/spine/sentinelle_kit.md`.
- Mort remplacée par une explosion noire embarquée dans Spine : corps invisible
  à 0,16 s, particules dissipées avant 0,65 s, événements death_burst / vanish.
- Flexion directionnelle locale (deux genoux dans le même sens), pas parallèles,
  estoc préparé avec appui avant puis poussée dans l’axe ; sort au bouclier amplifié.
- Sources : `sentinelle_motion.py`, `spine_burst.py`, `sentinelle_kit.py`.
  Le rig partagé des monstres n’est pas modifié. Le pont accepte une fabrique optionnelle.
- 24 contrôles des mouvements directement sur JSON + 24 clips web + 24 Godot passent.
- Test smoke tenté deux fois : verrou du moteur détenu par une autre tâche,
  donc ne pas annoncer un nouveau smoke réussi. Les rapports sont dans validation.json.
- Les raccords des pièces peintes restent à examiner, surtout en gros plan.
  La V7 est une proposition à revoir en mouvement avec l’utilisateur.
- Préserver les modifications concurrentes de `asset/map/painted/halts/emerald_sanctuary_v1/`.
