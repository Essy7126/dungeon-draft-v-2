class_name MountainPassBlockoutRoomData
extends RoomData

const BLOCKOUT_DATA: MountainPassBlockoutData=preload("res://data/maps/mountain_pass_blockout.tres")

func _init() -> void:
	hero_spawn_zone.assign(BLOCKOUT_DATA.ally_spawn_cells())
	enemy_spawn_zone.assign(BLOCKOUT_DATA.enemy_spawn_cells())

func get_blockout_data() -> MountainPassBlockoutData:return BLOCKOUT_DATA
