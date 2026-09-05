extends "res://battle/painted/registered_terrain/registered_terrain_battle.gd"

# Preserve the historical scene/probe resource identity while all shader code
# and battle logic live in the shared production terrain pipeline.
const COMPATIBILITY_PALETTE := preload("res://tools/labs/greek_drawn_arena/limestone_palette.gdshader")

func _floor_palette_shader() -> Shader:
	return COMPATIBILITY_PALETTE
