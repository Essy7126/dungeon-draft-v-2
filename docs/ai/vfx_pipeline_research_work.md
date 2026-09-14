# Reprise — recherche de production VFX

- 12 septembre 2026 ; HEAD lu : `0bdfd5bffca5df5d5d7a8206dc651b050b7c7a43`. Dépôt déjà très modifié : vérifier sa fraîcheur avant toute reprise.
- Demande : comprendre en profondeur les techniques et pipelines Ankama/autres studios ; établir une méthode réalisable avec la DA Catabase. Complément choisi : plan des outils et compétences à acquérir.
- Livrables : `docs/design/achilles/vfx_pipeline_research_2026-09-12.md` et `vfx_tools_learning_plan_2026-09-12.md`. Sources primaires et limites d'accès dans les documents.
- Conclusions : méthode hybride ; Krita à éprouver, Blender 5.1 présent ; Animate utilisable mais en maintenance officielle. Aucune pipeline uniforme Ankama publiquement démontrée. Nindash est le cas le plus explicite de choix de techniques et d'export. Cas Waven Execution = test de recrutement.
- Audit : flipbooks à cadence uniforme et rotation fixe ; burst actuel = primitives ; publication Studio vers fixtures seulement. Scrub et services de manifeste déjà présents. Ne pas reconstruire un grand atelier avant un pilote.
- Vérifications : doctor Godot 4.7.1/GUT9.7.1, import non vérifié par doctor. Premier test limité par permissions Windows, zéro test. Relance hors sandbox : 18 tests/487 assertions GUT réussis MAIS verdict strict FAIL : 6 textures RID et 18 ressources encore utilisées à la sortie. Rapport `artifacts/dev/20260912-111401-test-test_unit_test_vfx_flipbook_foundation.gd-a659be53/gut-strict-report.json`. Cause des références restantes non diagnostiquée. Aucun test ne vaut preuve de qualité artistique.
- Aucun nouveau visuel, profil de production, logiciel installé ou contact externe dans cette recherche. Pas de correction du moteur entreprise au titre du dossier.
- Suite proposée : exercice de silhouettes avec trois rythmes, retouche native d'une pose et export reproductible ; diagnostiquer la fermeture des tests. Éclat de fresque reste une recherche non approuvée, ne pas le traiter comme direction finale acquise.

## Complément : construction réalisable

- Nouvelle demande : approfondir encore, puis produire une construction précise adaptée au jeu. HEAD contrôlé identique lors du complément ; conserver les autres changements du dépôt.
- Nouveau dossier : `docs/design/achilles/vfx_feasible_construction_2026-09-12.md`. Sources nouvelles : McDonald / Maya Attack Swipes, Geri / Venom Slash, VFX Apprentice / timing. Décision proposée : calques animés dans Godot à la création, puis bake en flipbook pour le lecteur existant, sans nouveau runtime universel.
- Étude effective : petit projet indépendant `tools/labs/peleid_contact_study/` (lancer avec `--path`, pas F6 du projet parent). Quatre calques existants, trois rythmes, temps absolu, shader alpha, cibles/fonds en fixture. Peinture non approuvée ; plage ivoire trop importante et masque procédural encore à juger artistiquement.
- Validation : capture finale Godot 4.7.1 / Forward+ / Vulkan / RTX 4070 Laptop ; 3 contrôles GPU positifs, 7 PNG et 84 frames ; sortie 0 et journal sans erreur ni fuite signalée. Première capture Compatibility sous sandbox avec erreurs cache/certificats conservée séparément. Aucun test de combat/fondation relancé. Formateur appliqué seulement au nouveau script.
- Artefacts : `artifacts/dev/peleid_contact_study/` : `report.json`, `engine.log`, `study.gif`, `build_manifest.json`, `t_*.png`, `frames/`.
- Non fait : correction native de peinture, export transparent/atlas, import Studio, branchement au combat, synchronisation audio, revue aux huit directions, mesures de performance. Contrat d’export détaillé dans le dossier ; ne pas le confondre avec un export déjà fabriqué.
- Suite : revue du rythme puis correction de la silhouette/palette et éventuellement masque peint ; garder cette étape avant de figer un atlas. Une seule construction est éprouvée, pas une pipeline complète validée.
