@tool
extends "res://battle/dynamic_terrain/dynamic_wall.gd"

## Adaptateur du lab : il ne contient que la bibliotheque de configurations de
## demonstration. Toute la logique reutilisable vit dans battle/dynamic_terrain.

const BASE_CONFIG := preload("res://battle/dynamic_terrain/configs/wall_base.tres")
const FIRE_CONFIG := preload("res://battle/dynamic_terrain/configs/wall_fire.tres")
const ICE_CONFIG := preload("res://battle/dynamic_terrain/configs/wall_ice.tres")


func _init() -> void:
	set_variant_configs({
		WallVariant.BASE: BASE_CONFIG,
		WallVariant.FIRE: FIRE_CONFIG,
		WallVariant.ICE: ICE_CONFIG,
	})
