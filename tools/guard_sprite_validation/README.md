# Garde d’airain — validation des sprites

Ce scénario charge la vraie Cour des sources, attend son déploiement et place Achille via l’entrée normale de Battle sur une case libre de sa zone. Il sélectionne ensuite **Garde d’airain** et clique sa case via les coordonnées du sprite de sol et les entrées `GridView.update_hover/click_at`. Il vérifie le coût de 2 PA, les 10 points de bouclier, l’activation du VFX canonique, son repos immobile, puis un déplacement réel d’une case. Il ne simule pas le pointeur Windows.

La suite est explicitement appelée `lifecycle_probe` : `Unit.take_damage(3)` puis `Unit.take_damage(7)` vérifient l’absorption partielle, le retour au maintien, l’épuisement et la suppression. Ces deux appels ne prétendent pas représenter une action de l’IA ennemie. Le scénario ne crée jamais directement un effet ou un personnage de démonstration ; si le raccordement canonique manque, il échoue.

Depuis le dossier du projet, importer d’abord les nouveaux assets puis exécuter **séquentiellement** :

```powershell
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --import --quit
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://addons/gut/gut_cmdln.gd -- -gconfig= -gexit -gdisable_colors -gtest=res://test/unit/test_achilles_guard_sprite_vfx.gd
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 1600x1000 res://tools/guard_sprite_validation/GuardSpriteCourtyardValidation.tscn -- --artifact-dir=res://artifacts/guard_sprite_validation_v1/visual
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 1600x1000 res://tools/guard_sprite_validation/GuardSpriteCourtyardValidation.tscn -- --no-screenshots --artifact-dir=res://artifacts/guard_sprite_validation_v1/timing
```

Les captures `guard_activation.png`, `guard_hold.png`, `guard_hold_moving.png`, `guard_hit.png`, `guard_end.png` montrent les états réellement observés pendant le jeu. `runtime_validation.json` contient les résultats, les changements de frame et leurs temps bruts, la dérive des pieds, le suivi de l’ancrage, les valeurs de PA/PM/bouclier et la portée exacte du test.

La compression PNG est différée après les actions. Les lectures GPU des captures peuvent encore affecter le rythme ; utiliser la passe graphique `--no-screenshots` pour mesurer les temps. Ne pas ajouter `--capture` ou `--verify`, qui lanceraient un autre scénario de la map.

La suite GUT vérifie en plus les quatre ressources et leur alpha, l’absence de 3D/particules, le repos sans horloge, l’absence de modifications des stats/pieds, les absorptions, le clear, le dédoublonnage, la mort, la libération du UnitView et la reprise après pause.

## Court aperçu du jeu

Ajouter `--capture-clip` active une capture optionnelle autour d’Achille : rectangle fixe de 420 × 340 pixels, objectif 30 images/s, maximum 150 images. Chaque image provient du viewport réel après `frame_post_draw`, uniquement recadré ; les PNG sont compressés après le scénario. Un court repos initial et final encadre la séquence. L’option peut être combinée à `--no-screenshots` pour éviter les cinq captures plein écran pendant cette passe.

Le dossier `clip/` contient `frame_0000.png`, etc. et `clip_manifest.json` : rectangle, timestamps en microsecondes, temps relatifs, phase et frame observées. Assembler l’aperçu selon les timestamps enregistrés ; ne pas imposer artificiellement 30 images/s. Cette passe est destinée à présenter le rendu et ne constitue pas une mesure de cadence. Une vraie mesure emploie `--no-screenshots` **sans** `--capture-clip`.

Le rapport `lifecycle_probe` fournit également `exhaustion_started_usec`, `visual_removed_usec` et `observed_dissolution_seconds` pour le temps total de dissipation.
Assembler le clip réel après la passe `--no-screenshots --capture-clip` :

```powershell
node tools/guard_sprite_validation/assemble_clip.cjs artifacts/guard_sprite_validation_v1/gameplay_clip/clip/clip_manifest.json
```

Le script requiert Sharp localement ou via `SHARP_PATH` ; le runtime Codex est utilisé en dernier recours sur cette machine. Il produit `garde_airain_gameplay.gif`, `poster.png` et `encode_report.json` dans le dossier des captures. Le cadre est agrandi deux fois et la durée de chaque image est calculée depuis les timestamps, arrondie au centième de seconde du GIF. Aucun dessin ni frame intermédiaire n’est reconstruit.

Résultats du 5 septembre 2026 : 70 tests graphiques / 1 310 assertions passent dans `artifacts/guard_sprite_validation_v1/gut_final/`. Les passes `visual`, `timing` et `gameplay_clip` ont `ok: true`, avec ancrage et pieds sans dérive. Les journaux conservent les messages de ressources/RID non libérés à la fermeture Godot ; les assertions fonctionnelles réussies ne signifient pas une fermeture sans erreur de toute l’application.