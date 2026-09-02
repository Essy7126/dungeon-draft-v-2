# Captures UX du HUD en graybox

Ce runner instancie le châssis `CombatHUDRecraftV1` et ses vrais composants avec
une fixture Achille déterministe. Il ne lance pas de combat et ne modifie aucun
état de run.

États couverts : `idle`, `hover`, `selected`, `unavailable`, `cooldown`,
`locked`, `targeting_valid`, `targeting_invalid`, `resolving`, `enemy_turn`.

Résolutions de référence : 1280×720, 1200×896 et 1920×1080.

```powershell
& "C:\chemin\vers\Godot_console.exe" --path . --display-driver windows --rendering-driver opengl3 --audio-driver Dummy --scene res://tools/ui_snapshots/HudGrayboxCaptureRunner.tscn
```

Le runner utilise volontairement une fenêtre de rendu : le driver `headless`
de Godot repose sur un renderer dummy et ne fournit pas de texture de viewport
à enregistrer.

Pour ne régénérer qu'une capture :

```powershell
& "C:\chemin\vers\Godot_console.exe" --path . --display-driver windows --rendering-driver opengl3 --audio-driver Dummy --scene res://tools/ui_snapshots/HudGrayboxCaptureRunner.tscn -- --state=selected --resolution=1280x720
```

Les PNG, planches contact, métriques de layout, checksums et la galerie HTML
sont produits sous `artifacts/hud_graybox_validation/`.
