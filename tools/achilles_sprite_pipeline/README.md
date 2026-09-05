# Achilles sprite production pipeline

Build from the four checked-in ImageGen source sheets:

```powershell
node tools/achilles_sprite_pipeline/build.cjs
```

The script loads `sharp` from normal Node resolution, `SHARP_PATH`, or the bundled Codex runtime fallback. It uses no network or generative API. To install a newly generated source into the versioned source directory, add `--source 'E=C:/absolute/path/to/source.png'` (and similarly N/S/W). `--allow-partial` is only for intermediate development previews; shipping output requires all four directions.

## Source contract

- Four genuinely transparent RGBA sheets, one direction per sheet, arranged in nominal 4 by 4 cells.
- First row: four idle poses. Next two rows: eight run poses. Final row: anticipation, extension, impact, recovery.
- Front E/S and back N/W are separately authored views. Never mirror an asymmetric shield and spear loadout.
- The original ImageGen PNGs and generation prompts are retained under `art/source/characters/achilles/sprites_cour_des_sources_v1/`.

The generated sheets are not exactly divisible by four, and a few spear tips and foot poses cross cell boundaries. Uniform rectangle slicing would silently cut them. The pipeline instead finds the sixteen eight-connected components at alpha > 32, associates each component with its nominal cell by its opaque centroid, and extracts the whole component. It retains source RGB and alpha in the component and its two-pixel dilation, dropping only separate faint alpha debris. Any discarded pixel with alpha > 32, missing component, or ambiguous assignment stops the build. No hue key, repainting, articulated deformation, or inferred hidden body parts are used.

## Registration

Each frame is placed in a 512 by 384 transparent canvas with the world anchor at `(256, 320)`. A shared local X pivot is measured from the lower body of the four idle poses, independently of the spear. Walk frames in each source row share their lowest foot baseline: airborne poses retain their lift. Idle and stationary attack frames use their own actual lowest foot contact, avoiding floating windup or impact poses. No pose is horizontally recentered from spear extent. A fixed scale per direction brings the initial idle crest-to-floor height to 220 pixels. It is not recalculated for crouches, running, or lunges.

`alignment.json` accepts an object per direction with optional `root_local_x`, `crest_top`, `scale`, and `frames` (source index to `anchor_x`/`anchor_y` corrections). Corrections are source pixels added to the shared pivot before resampling. Keep corrections small and explain any future hand-measured changes there or in the production brief. Regeneration should retain the same body scale and camera; the tool cannot repair inconsistent drawing or joint motion.

## Runtime assets

`assets/characters/Achilles/sprites_cour_des_sources_v1/` contains:

- `achilles_sprite_frames.tres`: twelve Godot animations, with four separate cardinal facings.
- `atlas_N/E/S/W.png`: one lossless 2048 by 1536 atlas per direction, sixteen complete transparent cells each.
- `manifest.json`: source and output SHA-256 hashes, alpha statistics, component boxes, cropping exceptions, measured pivots/scales, output bounds and animation mappings.
- `preview_N/E/S/W.jpg`: neutral-background contact sheets.
- `idle_*_preview.gif`, `walk_*_preview.gif`, `attack_*_preview.gif`: temporal previews. GIF timing is rounded to centiseconds; the Godot resource has exact speeds.

Idle uses the single stable source pose `[0]` at 1 fps: cycling separately drawn ready poses produced morphological motion and foot sliding. Unused idle drawings are retained in the source atlas. Walk loops at `4 / 0.28 = 14.2857142857` fps, four poses per 0.28-second cell. N/E/S use `[5,6,7,8,9,10,11,4]`; W uses `[8,9,10,11,4,5,6,7]`. These cyclic offsets put planted contact poses at sequence indices 3 and 7; running at speed 1.4 gives 20 fps and 0.20 seconds per cell. The runtime must finish the four-pose segment on contact before returning to idle; the eight-frame attack does not loop and uses 12 fps. The attack mapping is `[idle0, attack0, attack1, attack2, attack2, attack3, idle0, idle0]`. S skips the inconsistent arm-ownership anticipation with `[0, 0, 13, 14, 14, 15, 0, 0]`; the original source pose remains retained but unused. The hit event is frame index 3; index 4 is a short impact hold. Neither a sound nor damage is implemented in this asset pack: the gameplay backend owns those events.

The build checks source transparency, sixteen complete components, absence of significant discarded alpha, output cell margins, and nonempty output. Gameplay validation must additionally check direction selection, contact registration during actual map movement, frame-3 hit timing, and return to idle after attacks.

An optional separately generated 2 by 2 attack sheet can replace source poses 12-15 with `--attack-source W=C:/absolute/path.png`. It is retained as `attack_W.png` and recorded separately in the manifest. Its fixed scale and pivot are configurable under `alignment.W.attack`; `enabled: false` switches back to the original authored attack. The E supplement corrects the original double-ended spear, and W provides a full extension. All output cells are widened to 512 pixels so the extra spear reach does not force a smaller character. E keeps a fixed .368705 scale after comparing helmet/crest and chest size against idle; its shorter stance is an authored knee bend. Its 214-pixel shared body target and small pivot correction were checked against the original model at game size. `compare_model.cjs E` and `compare_model.cjs W` generate visual comparisons, and `inspect.cjs` reports source alpha components. All sprites are hand-drawn-style generated frames, not a 3D render or a rig.
