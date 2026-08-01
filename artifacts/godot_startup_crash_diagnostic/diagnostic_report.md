# Diagnostic du gel de Godot à l'ouverture — 2026-08-01

## Conclusion

**Cause racine confirmée et corrigée localement.** Le symptôme déclaré comme un crash est un `AppHangB1` : le thread principal de l'éditeur cesse de répondre lorsque la GDExtension Ziva v3.1.1, ignorée par Git dans `addons/ziva_agent/`, est chargée en ouverture normale. Le code et les ressources REFINED V2 ne causent pas ce gel.

La correction minimale consiste à maintenir `addons/ziva_agent/` hors du projet. Le dossier complet est conservé sans perte à `C:\tmp\godot_startup_crash_diagnostic_20260801\ziva_agent`. Un cache `.godot` propre, sans entrée Ziva, a été reconstruit et est conservé dans le projet.

## 1. Branche et HEAD

- Branche finale : `main`
- HEAD final : `79c4aebf3ff10fbab8b40bed45ea242dd41ea963`
- Aucun checkout, pull, rebase, commit, push ou stage.

## 2. État Git

- Les 15 fichiers suivis REFINED V2 modifiés avant le diagnostic sont toujours modifiés.
- Aucun fichier suivi n'a été modifié par la correction du gel.
- Index vide.
- `git diff --check` : code de sortie 0.
- Le dossier de diagnostic ajoute des fichiers non suivis ; les captures V2 non suivies ont été régénérées par leur runner de validation.

La photographie initiale est dans `git_snapshot_before_diagnostic.md`.

## 3. Exécutable, renderer, plugins

- Exécutable : `C:\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe`
- Console : `C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe`
- Version : `4.7.1.stable.official.a13da4feb`
- Renderer projet : D3D12 / Forward+
- GPU : NVIDIA GeForce RTX 4070 Laptop GPU ; pilote exposé par OpenGL : 595.97
- Plugins éditeur activés : GUT et Meshy.
- GDExtension trouvée avant correction : `res://addons/ziva_agent/ziva_agent.gdextension`.
- Ziva est ignoré par `.gitignore` (`addons/ziva_agent/`) et n'appartient donc pas au travail REFINED V2 suivi par Git.

## 4. Nature exacte du problème

Windows n'a enregistré aucune faute native Godot et aucun dump Godot dans `%LOCALAPPDATA%\CrashDumps`. Il a enregistré plusieurs événements `Application Hang` / `AppHangB1`, notamment à 17:29:30, 17:32:51, 17:33:37, 17:39:01 et 17:40:09.

Le journal Ziva `2026-08-01_sidecar.log` indique pour les ouvertures concernées :

- thread principal Godot non réactif depuis environ 10 s ;
- toujours non réactif après 45 s ;
- déconnexion seulement lorsque le processus parent Godot est fermé.

Le test contrôlé normal avec Ziva chargé n'a pas quitté après 64 s. La dernière opération cohérente du journal Godot est le chargement de `res://asset/Background/fond terrain.webp`, pendant le parcours des dépendances de ressources ; ce fichier n'est pas désigné comme cause, car le même projet et les mêmes ressources passent dès que Ziva est isolé.

## 5. Test discriminant Ziva

Configuration identique hors présence du dossier Ziva : même HEAD, mêmes modifications, même cache initial, même D3D12.

- Avec Ziva : ouverture normale bloquée au-delà de 64 s ; Ziva signale le thread principal gelé ; arrêt manuel des seuls PID diagnostiques.
- Sans Ziva : ouverture normale terminée proprement en 8,7 s, code 0.
- Sans Ziva et avec cache reconstruit : ouvertures normales en 9,3 s puis 8,6 s, 8,8 s et 8,8 s, toutes code 0.
- Ouverture prolongée à 1 200 frames : code 0 en 15,5 s, au-delà du délai où Ziva détectait auparavant le gel.

Cette paire de tests confirme la causalité. La GDExtension initialise notamment un sidecar, un WebSocket et une WebView native avant que le thread principal ne devienne non réactif.

## 6. Import headless

- Cache initial, avec ressources et `poison.svg` : code 0 en 7,9 s.
- Cache reconstruit : code 0 en 37,6 s, import complet de 448 assets.
- Aucun crash d'import, aucune erreur UID, aucune ressource REFINED manquante.
- `poison.svg` est importé en 5 ms dans le cache neuf.

Un lancement headless initial a laissé un processus Godot sans fenêtre malgré le code 0 ; le PID diagnostique exact a été arrêté avant le test suivant. Ce résidu n'a pas été reproduit après l'isolation de Ziva.

## 7. Mode récupération et renderers

- Récupération D3D12 avec état initial : code 0 en 10,9 s.
- Récupération D3D12 avec cache neuf et sans Ziva : code 0 en 13,8 s.
- Récupération `gl_compatibility` avec cache neuf et sans Ziva : code 0 en 27,5 s.
- Ouverture normale D3D12 avec cache neuf et sans Ziva : code 0 en 9,3 s.

Le gel n'est donc pas propre à D3D12/Forward+ et le mode récupération ne plante pas dans le test contrôlé, une fois les processus précédents nettoyés. Le signalement utilisateur « récupération plante aussi » correspond vraisemblablement aux tentatives en cascade alors qu'un éditeur/sidecar précédent restait gelé ; il n'est pas reproductible dans un environnement nettoyé.

## 8. Cache `.godot`

Cache avant reconstruction :

- 1 737 fichiers ; 638 092 355 octets ;
- sauvegardé à `C:\tmp\godot_startup_crash_diagnostic_20260801\godot_cache_before_rebuild` ;
- fonctionnait déjà sans Ziva : il n'est pas la cause racine.

Cache actuel reconstruit après validations :

- 1 239 fichiers ; 441 314 758 octets ;
- aucune `extension_list.cfg` Ziva ;
- aucune entrée d'import correspondant aux captures V2 ;
- import, éditeur normal et récupération validés.

Il est sûr de garder le cache actuel. L'ancien reste une sauvegarde temporaire de retour arrière.

## 9. `.gdignore` et captures

- `.godot/.gdignore` : nom exact, 1 octet LF.
- `artifacts/skill_tree_refined_v2/.gdignore` : nom exact, 1 octet LF, créé le 01/08 à 17:00:59 ; il couvre le dossier complet et ses sous-dossiers.
- `artifacts/godot_startup_crash_diagnostic/.gdignore` : nom exact, 1 octet LF.
- Aucun sidecar `.import` dans `artifacts/skill_tree_refined_v2`.
- 22 fichiers `.md5` résiduels du cache initial datent de 16:58, donc avant le `.gdignore`; aucune texture `.ctex` V2 correspondante n'était encore présente.
- Le cache reconstruit contient 0 entrée pour les captures V2.

Les 26 PNG ont été décodés sans réencodage par `System.Drawing`, avec signature PNG et `IEND` final exacts : 26/26 valides. Aucun profil ICC inhabituel, aucune dimension extrême, aucun PNG tronqué.

Fichiers contrôlés en particulier :

- `before_after_comparison.png` : 1920×594, 1 182 720 octets ;
- `components_contact_sheet.png` : 1600×980, 201 961 octets ;
- `icon_mapping_sheet.png` : 1220×672, 44 915 octets ;
- plus grande capture : 2560×1440, 291 160 octets après régénération.

Le runner visuel a régénéré 22 PNG existants pour la validation finale. Les dimensions, scénarios et rendu REFINED sont préservés ; certains octets/hashes PNG diffèrent de la photographie initiale, sans sauvegarde binaire séparée de ces sorties générées.

## 10. `poison.svg`

- Emplacement unique : `asset/ui/dungeon_draft/arbre_compétences/generated/icons/poison.svg`.
- 455 octets ; 64×64 ; `viewBox="0 0 64 64"`.
- Pas de filtre, masque, CSS, référence externe, image embarquée, entité XML ou base64.
- Structure XML simple et valide.
- SHA-256 SVG : `01AF4A14B11B3A3C4FD52EFF0CF48C9C350A97BBA67C895AAF4884309300B4FC`.
- SHA-256 sidecar : `C9152D850B6DAE16BE53F94D17EC19CE0A4BBB11851ECCE99C134A8145CAF9CB`.
- Le sidecar a le même format que les autres imports SVG et a été généré par Godot.

Test sans SVG et sidecar : import headless code 0 en 5,5 s, avec l'erreur attendue de ressource absente. Les deux fichiers ont été restaurés immédiatement et leurs hashes vérifiés. `poison.svg` n'est pas la cause.

## 11. Audit REFINED V2

- Aucun marqueur de conflit Git dans les `.gd`, `.tscn`, `.tres` ou `.cfg`.
- Catalogue `skill_tree_icon_catalog_refined.tres` : `load_steps=29`, 28 `ExtResource`, 0 `SubResource`, donc valeur exacte attendue 29.
- 28 chemins externes sur 28 existent lorsqu'ils sont lus en UTF-8.
- Aucun chemin de casse incorrect ou type de ressource invalide détecté par l'import Godot.
- Aucun chargement récursif de scène, UID dupliqué ou référence circulaire signalé.
- Les appels de layout sont finis et data-driven ; aucune valeur `NaN`/infinie ni création de nodes non bornée n'a été observée.
- Le runner affiche Elf rang 1, Elf rang maximum, Mage et un gardien sans progression à 1280×720, 1920×1080 et 2560×1440.

## 12. Validation fonctionnelle

- Scène principale `ui/TitreEcran.tscn` : code 0, 180 frames.
- `data/rooms/maps/battle_salle1_iso.tscn` : code 0, 180 frames.
- Runner visuel REFINED : 22 captures fonctionnelles produites, code 0.
- GUT ciblé : 3 scripts, 24/24 tests, 1 433 assertions, code 0.
- Gestionnaire de projets Godot : code 0.
- Projet minimal indépendant : code 0.
- `git diff --check` : code 0.

## 13. Diagnostics non bloquants encore présents

- GUT ciblé termine avec des compteurs de nettoyage : 5 RID Dummy, 520 objets et 86 ressources encore référencées. Les 24 tests passent avant ces messages.
- Le runner visuel signale après les captures 2 textures GLES3/RID, 50 objets et 31 ressources encore référencées.
- `test_dark_pause_menu.gd`, non modifié par cette mission, a quatre erreurs d'inférence de type aux lignes 54, 62, 74 et 95 ; GUT l'ignore car il ne peut pas être chargé comme `GutTest`.
- Le lancement global involontaire a retrouvé le résultat antérieur : 358/364 tests, avec les 6 échecs gameplay déjà connus.
- D3D12 convertit plusieurs textures RGB8 en RGBA8 ; avertissement géré, non fatal.
- OpenGL signale `NVAPI_EXECUTABLE_ALREADY_IN_USE` lors du projet minimal/gestionnaire, sans impact sur leur code de sortie 0.

Aucun de ces diagnostics ne reproduit l'`AppHangB1` d'ouverture.

## 14. Fichiers et sauvegardes du diagnostic

Créés dans `artifacts/godot_startup_crash_diagnostic/` : `.gdignore`, photographie Git, présent rapport, projet minimal et journaux de chaque test.

Sauvegardes externes :

- `C:\tmp\godot_startup_crash_diagnostic_20260801\ziva_agent` — 34 fichiers, 180 495 577 octets ;
- `C:\tmp\godot_startup_crash_diagnostic_20260801\godot_cache_before_rebuild` — 1 737 fichiers, 638 092 355 octets ;
- `C:\tmp\godot_startup_crash_diagnostic_20260801\poison` — dossier vide après restauration réussie.

Hashes Ziva principaux :

- `.gdextension` : `33923A502EE3B4FC8F8A981C4F11E986FF84F102E1215B9ADE067EAEE8019CC2` ;
- DLL : `3BEF529519A91DBCC8AD75F84E582E73160BD539FD82C1FD496140EB3C55F2A7`.

## 15. Retour arrière exact

1. Fermer tous les processus Godot et Ziva.
2. Pour réactiver Ziva, déplacer `C:\tmp\godot_startup_crash_diagnostic_20260801\ziva_agent` vers `C:\Users\paolo\Documents\dungeon-draft-v-2\addons\ziva_agent`. Cela réintroduira probablement le gel tant que la GDExtension n'est pas remplacée par une version compatible.
3. Pour restaurer l'ancien cache, déplacer d'abord le cache actuel `.godot` vers une autre sauvegarde, puis déplacer `C:\tmp\godot_startup_crash_diagnostic_20260801\godot_cache_before_rebuild` vers `C:\Users\paolo\Documents\dungeon-draft-v-2\.godot`.
4. `poison.svg` et `poison.svg.import` sont déjà à leur emplacement initial et n'exigent aucune action.
5. Pour retirer les seuls ajouts de diagnostic sans suppression, déplacer `artifacts/godot_startup_crash_diagnostic` hors du dépôt. Les 15 modifications suivies REFINED restent intactes.
6. Les captures régénérées sont des sorties du runner actuel ; leur état visuel est reproductible, mais les octets exacts antérieurs au diagnostic n'ont pas été sauvegardés séparément.

## 16. Fichiers de preuve principaux

- `editor_normal_d3d12.log` : gel contrôlé avec Ziva.
- `editor_normal_without_ziva.log` : démarrage réussi avec cache initial.
- `headless_import_rebuilt_cache.log` : reconstruction complète réussie.
- `editor_recovery_d3d12_rebuilt.log` : récupération D3D12 réussie.
- `editor_recovery_gl_rebuilt.log` : récupération OpenGL réussie.
- `editor_normal_repeat_1.log` à `editor_normal_repeat_3.log` : répétitions réussies.
- `editor_normal_extended_1200_frames.log` : ouverture prolongée réussie.
- `gut_refined_targeted_only.log` : 24/24 tests REFINED.
- `capture_skill_tree_refined_validation.log` : affichages demandés.
- `run_project_main_scene.log` et `run_battle_salle1_iso.log` : scènes lancées.

