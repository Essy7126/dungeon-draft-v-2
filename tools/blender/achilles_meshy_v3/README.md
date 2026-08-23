# Achilles Meshy animation pool V3

This pipeline builds a character-only GLB directly from the immutable Meshy
merged-animation source. It does not retarget animations and never edits or
overwrites the Achilles V1/V2 assets.

Validated input:

- file: `Meshy_AI_Meshy_Merged_Animations (4).glb`
- SHA-256: `21DAD4EE17146F3A1430A684C7EFD14544701100307C233D4E5B27812EF58770`
- expected contents: one `Armature`, one skinned `char1`, 24 bones and 20 actions

Run from the repository root with Blender 5.1 or newer:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' `
  --background --factory-startup `
  --python tools\blender\achilles_meshy_v3\build_achilles_meshy_v3.py
```

The script removes the source helper `Icosphere`, exports only `Armature` and
`char1`, re-imports the result, verifies
the complete animation/rig/material contract, and writes:

- `assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb`
- `assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3_manifest.json`
- `assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3_inspection.json`

Use `-- --source <path> --output <path> --manifest <path> --inspection <path>`
to override the defaults. The source hash remains mandatory.
