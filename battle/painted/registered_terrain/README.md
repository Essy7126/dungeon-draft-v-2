# Registered terrain runtime

One production renderer serves every authored terrain plan. `RegisteredTerrainBattle.tscn`
uses the existing PaintedBattle/GridData/Pathfinder/units and ArenaVisualAssembler.
It adds registered terrain surfaces, pit artwork, a cosmetic ground band and palette
materials to the real source dalles. It does not create tactical cells or collisions.

## Room contract

- Use an `ArenaDefinition` with its existing HYBRID topology and `battle_scene` pointing
  to `res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn`.
- Set `registered_terrain_plan_path` to the JSON plan. It is exported and included in
  ArenaDefinition snapshots. A non-empty scene property of the same name overrides it.
- The scene exposes `registered_terrain_ready` only after successful setup and emits
  `registered_terrain_configured(report)`. Standard Battle APIs remain unchanged.
- `get_registered_terrain_manifest_path()` resolves `geometry_manifest_path` from the
  plan, or sibling `geometry_manifest.json`. It never assumes the campaign room lives
  in the arena package. The platform validates every annotated pit against live VOID.

## Plan data

Existing version1 native geometry remains the authority: `canvas_size`, `land_polygon`,
`shorelines`, `excluded_floor_polygons`, `water`, `land`, `soil_patches`, `world_decor`.
Textures do not define topology. All positions/UVs use the calibrated native plane.

Surface fields: `texture_path`, `texture_scale` (number or [x,y]), `texture_repeat`,
`tint`, optional `shader_path` and `shader_parameters`. A full-canvas painting uses
`texture_scale:[1,1]` and `texture_repeat:false`. The stone materials sample the same
Land texture instance, scale, tint and repetition setting.

Palette example (colors accept #hex or RGB/RGBA arrays):

```json
{
  "floor_palette": {
    "shade": "#30262b", "body": "#5b4542", "light": "#947158",
    "warmth": [-0.08, -0.025, 0.025, 0.065],
    "painted_steps": 0.24, "bevel_flatten_strength": 0.9
  },
  "props_palette": {
    "ink": "#31252d", "top": "#897363", "left": "#67514c",
    "right": "#49353e", "highlight": "#aa8a68", "moss": [0.2,0.15,0.18,0.25]
  },
  "pit_palette": {
    "floor": "#17121c", "back_wall": "#45343e", "left_wall": "#2c222f",
    "depth_native_px": 16
  },
  "ground_details": {"mode": "contacts_only", "tint": "#ffffff"},
  "combat_ground_band": {
    "enabled": true, "width_cells": 0.42, "minimum_shore_clearance_native_px": 20,
    "shader_path": "res://battle/painted/registered_terrain/shaders/combat_ground_band.gdshader",
    "shader_parameters": {
      "band_earth": "#665048", "band_light": "#796155", "band_shadow": "#45333b"
    }
  }
}
```

The defaults preserve the validated Greek drawing. `floor_palette.warmth` accepts a
single number or a non-empty variant list. Floor and band shader parameters share the
same soil functions, so the outer stone edge and underlay retain matching colors.

Additional prop palette keys: `shadow`, `edge_shadow`, `carving`, `crack`, `fleck_dark`,
`fleck_light`, `column`, `bench`. Reusable scenes live in `props/StonePlinth.tscn`,
`props/StoneBenchSection.tscn`, `props/BrokenColumn.tscn`. They retain the calibrated
cell footprint and scale their entire drawing with it. Per-entry `props_palette`
overrides the plan palette for a world_decor scene.

For `water`, a missing `shader_path` uses `shaders/water_ink.gdshader`; an explicit
empty path disables the default, and a supplied path uses that shader and its parameters.

## Decor contacts and layering

`world_decor` accepts full textures or atlas `region_px`, normalized `pivot`, native
`anchor` (or `anchor_grid`), scale, rotation, and `back` / `y_sorted` / `foreground`.
Use normalized `contact_profiles:[[[u,v],...],...]` for root/rock contact lines;
`contact_disabled:true` or an empty profile list disables them. Full textures use
their real dimensions. Existing Greek ID profiles remain compatibility defaults.
Contacts are clipped away from every FLOOR polygon.

RGB magenta atlases may declare chroma_key.magenta_despill:1 to decontaminate matte edges. It defaults to0; native-alpha images bypass the chroma shader. Validate silhouettes in a GPU capture.

`ground_details` supports `enabled`, `mode:all|contacts_only`, `seed`, `tint`,
`contact_outer` and `contact_inner`. The compact contacts-only mode avoids painted
biome details being overdrawn by the historical procedural shoreline vegetation.

The band is a filled native underlay clipped to inset Land and rock exclusions,
never a new walkable ring. It uses one closed combat outline (FLOOR + verified pits),
a logical MITER offset and at most128 simplified contour vertices. `GroundBand.materials()`
returns the shared material; `outer_contour_grid`, `offset_contours_grid` and
`geometry_report()` expose authoring and rendered geometry for independent checks.

## Compatibility and ownership

Lab scripts are thin subclasses of these components. Lab shader paths include the
same production shader bodies; GreekDrawnCourtyard therefore retains its original
scene/material identity for existing probes. Production code has no dependency on
lab runtime or biome-specific bitmaps. Node names `GreekTerrainComposition`,
`GreekPlatformRisersAndPits` and existing `greek_*` metadata remain stable intentionally.
Pixel snapping is disabled only for the active viewport and restored on scene exit.
Character view scripts, gameplay rules and campaign encounter selection are unchanged.
