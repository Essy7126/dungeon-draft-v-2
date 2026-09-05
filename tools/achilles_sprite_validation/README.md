# Achilles sprite validation

This harness launches the real `GreekDrawnCourtyard` launcher and waits for its canonical hero to deploy. It does not substitute a demo unit or alter the equipped spells, grid, AP, MP, animation speed, or input eligibility.

The capture uses the existing GridView pointer-coordinate endpoints to move two cells and cast Guard. It then casts Spear Thrust at a legally reachable target, or Sweep on the hero if no enemy is in range. The first sprite release deliberately shares the same attack animation between those two offensive spells. The report verifies AP/MP, occupancy, spell uses, the return to idle, and one visual release and completion for each cast. Physical mouse/OS input is not simulated.

## Focused tests

After generating the SpriteFrames resource and promoting the canonical scene to `SPRITE_2D`, run from the project root:

```powershell
& ./tools/ci/run_gut_strict.ps1 -GodotPath 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' -ProjectPath . -SuiteId achilles-sprite-v1 -TestPath @('res://test/unit/test_achilles_sprite_assets.gd', 'res://test/unit/test_achilles_sprite_runtime.gd', 'res://test/unit/test_achilles_sprite_preview.gd', 'res://test/unit/test_achilles_sprite_stride.gd', 'res://test/unit/test_achilles_sprite_advance_timing.gd', 'res://test/unit/test_presentation_tween_clock.gd') -ExpectedTestCount 21 -ArtifactsDirectory 'artifacts/achilles_sprite_validation_v1/gut'
```

The twenty-one tests cover the canonical sprite-only path; all twelve animation clips; transparent, unclipped frame extents and shared ground anchor; non-mirrored cardinal orientations; a fixed frame-zero rest with unchanged feet over repeated idle requests; authored walk cadence with no restart under repeated move requests; action exclusivity and exact-once callbacks; cancellation before release and inside the release callback; facing changes during actions; Guard/Advance/Sweep reuse; terminal death and duplicate death notifications; the canonical UI sprite preview, inactive 3D rendering, stable portrait framing on resize and clip changes, pause/resume, and cleanup. Stride tests also measure opaque foot pixels at one-cell arrivals in every direction, preserve phase across turns, and cover running contacts followed by an attack. The long-Advance test uses the real UnitView release wait and Battle movement tween for three and four cells, including arrival cleanup.

The runtime tests load the actual shipped profile and sprite resource. They do not fabricate substitute textures. Old SubViewport-focused tests remain separate historical-backend tests; this selection proves the newly selected sprite path.

## Real-map screenshots and gameplay

Use a graphical renderer for PNG evidence:

```powershell
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 1600x1000 --scene 'res://tools/achilles_sprite_validation/AchillesSpriteCourtyardValidation.tscn'
```

The default output is `artifacts/achilles_sprite_validation_v1/`: `courtyard_idle.png`, `courtyard_walk.png`, `courtyard_attack.png`, `courtyard_rest_after_actions.png`, and `runtime_validation.json`. Screenshots record the live sprite animation name/frame and its visible pixel bounds. Captures never pause playback. Before movement and after the offensive action, the harness passively samples 0.65 seconds of real rest and verifies frame zero, stopped playback, unchanged transforms, and less than 0.01 screen pixel of ground-anchor drift. The report also records the observed walk/attack frame transitions, authored FPS, and speed multiplier. Ordinary walking is driven by the same tween as the grid position, with four poses per cell; the AnimatedSprite2D clock is paused while that tween sets frame and progress. The preview clips use the equivalent nominal FPS.

For another output directory, append `-- --artifact-dir=C:/absolute/output/path`. Do **not** append `--capture`, `--capture-quit`, or `--verify`: those belong to the older courtyard launcher and would start a second validation probe.

`--headless` automatically omits screenshots while preserving controller and sprite-node validation. A zero exit code and `"ok": true` in the JSON report indicate all requested runtime checks passed. The report describes whether PNG capture was enabled, so a headless pass is never presented as visual proof.

No runner imports or gameplay runs should execute concurrently against the same project import cache.


## Timing run without screenshot work

Frame capture requires synchronous GPU readback. PNG compression and character alpha-bound extraction now happen after the action sequence, but readback can still slow a visual run. Do not use the screenshot run to claim normal playback cadence.

Run the same scene graphically a second time with no screenshots and another output directory:

```powershell
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 1600x1000 --scene 'res://tools/achilles_sprite_validation/AchillesSpriteCourtyardValidation.tscn' -- --no-screenshots --artifact-dir=artifacts/achilles_sprite_timing_v1
```

The JSON `animation_timing` contains raw wall intervals for consecutive observed frame indices within the same clip and playback speed. Loops, direction changes and skipped observations are listed separately. Expected intervals use the authored frame duration divided by FPS and speed. No smoothing, phase correction, normalization, or stall removal is applied. The offensive action includes input, animation-start, release and completion timestamps, expected durations, and measured duration/recovery. Animation spans compare the sprite/facade's own translation against the UnitView's actual travel. Each GPU readback and deferred compression interval is recorded in visual runs so capture overhead remains visible.

These measurements describe the sampled real controller sequence. A short sample is not a hardware performance benchmark, and screenshots alone cannot demonstrate smooth animation.

## Delivery evidence — 2026-09-05

Graphical GUT: **86 tests, 2,163 assertions, all passing**, exit 0. This includes the six focused suites above plus unit movement presentation, turn-order timeline, post-combat flow, and the three explicitly selected historical 3D backend suites. Evidence: `artifacts/achilles_sprite_validation_v1/gut_delivery/gut.junit.xml` and adjacent logs.

Real graphical map: `artifacts/achilles_sprite_validation_v1/runtime_delivery/runtime_validation.json`, `ok: true`, exit 0; four PNG captures in the same directory. Independent timing: `timing_clock_final/runtime_validation.json`, `ok: true`. Two cells took 570.904 ms (560 ms nominal); seven observed walk intervals averaged 70.615 ms, range 66.699–72.749 ms (70 ms nominal).

Movement Tween interpolation is advanced by `characters/presentation_tween_clock.gd` from elapsed time since its own creation, respecting inherited pause and Engine time scale. It cannot inherit pre-creation time from a busy engine frame. Tests specifically cover mismatched engine delta, pause/resume, exact-once completion and helper cleanup. Synchronous animation/frame-change traces retain the initial observations and distinguish the corrected startup from the earlier truncated movement.

The graphical GUT result is distinct from the strict import gate: existing importer/runtime resource-at-exit diagnostics are retained in the logs and described in the integration brief. No clean strict import verdict is claimed.
