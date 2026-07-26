class_name SpellModTerrainOnAffectedCells
extends SpellModifier

@export var terrain_effect: TerrainEffectData = null
@export var duration_override: int = -1


func on_terrain_resolved(ctx) -> void:
	if terrain_effect == null or ctx.terrain == null:
		return
	for cell in ctx.affected_cells:
		var result: Dictionary = ctx.terrain.place_effect(
			cell,
			terrain_effect,
			ctx.caster,
			ctx.spell,
			duration_override
		)
		if result.get("changed", false) and not ctx.report["terrain_changed"].has(cell):
			ctx.report["terrain_changed"].append(cell)
