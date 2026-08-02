class_name MountainPassBlockoutRoomData
extends RoomData

## RoomData dediee au test. Les zones de deploiement sont derivees du layout
## unique afin de ne pas recopier manuellement les cellules A/E dans le .tres.

const BLOCKOUT_DATA: MountainPassBlockoutData = preload(
	"res://data/maps/mountain_pass_blockout.tres"
)


func _init() -> void:
	hero_spawn_zone.assign(BLOCKOUT_DATA.ally_spawn_cells())
	enemy_spawn_zone.assign(BLOCKOUT_DATA.enemy_spawn_cells())


func get_blockout_data() -> MountainPassBlockoutData:
	return BLOCKOUT_DATA
