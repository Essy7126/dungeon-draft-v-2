# Catabase monster validation

The unit suite loads the four production monsters and all 768 imported poses
(48 per direction). Trimmed atlas regions preserve the logical 512×384 canvas
through AtlasTexture margins; portraits retain the exact fixed E source view.
It exercises primary and special spell costs, actual health/status/push effects,
AI movement and casting, delayed cancellation, and three seeded route rosters.
Missing imports or dependencies are failures.

From the repository root, with the Godot 4.7.1 console binary:

```powershell
$monsterGodot = 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe'
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -ExpectedTestCount 9
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -Runtime -SuiteId runtime_1280x720 -Resolution 1280x720
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath $monsterGodot -Runtime -SuiteId runtime_1920x1080 -Resolution 1920x1080
```

The graphical probe builds four actual encounters selected from the seeded
production route. It uses the authored battlefield, real deployment, real unit
views, and EnemyTurnRunner AI. It then positions the existing hero on a legal
target cell and advances enemy activations to exercise both authored abilities.
These additional placements are explicit test fixtures; they do not represent
played traversal, a full-run victory, or a balance simulation.

The process exits nonzero on failed checks. Reports and viewport PNGs are written
to ignored `artifacts/catabase_monsters/{resolution}/`. Capture labels include
the original encounter, an observed eight-frame idle loop, actual
walk/attack/cast/death frames, and resolved combat.
The JSON reports contain exact AP/MP/HP changes, observed animations and failures.
Run the strict suite and graphical probes sequentially after asset generation
has completed so imports cannot race writes.

The helper uses the existing strict analyzer in `tools/ci/run_gut_strict.ps1`
against real subprocess logs and JUnit output. It changes only orchestration:
editor recovery mode prevents editor plugin side effects, and child APPDATA is
isolated under the ignored artifacts directory. This avoids the generic runner's
unrelated recursive access to a protected old Meshy dependency directory. No
engine errors or failing tests are suppressed.

The wrapper also rejects shutdown resource/ObjectDB leaks even when the probe's
functional checks pass. See the executed results and recorded limitations in
[the validation report](../../docs/design/catabase_monsters_validation_v2.md).
