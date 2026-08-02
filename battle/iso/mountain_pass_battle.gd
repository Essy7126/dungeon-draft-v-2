extends "res://battle/battle.gd"

@export var blockout_data: MountainPassBlockoutData=preload("res://data/maps/mountain_pass_blockout.tres")

func _ready() -> void:
	grid_cols=blockout_data.logical_size.x;grid_rows=blockout_data.logical_size.y
	super._ready()

func _import_terrain_from_tilemap() -> void:
	if blockout_data==null or grid==null:push_error("BlockoutData absent.");return
	blockout_data.apply_to_grid(grid)
