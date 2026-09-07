extends SceneTree

# One-time authoring preparation for the two persistent Catabase resources.
# Run after importing the registered terrain packages; never edits the run,
# encounters, economy, third room, or canonical arena packages.
const ROOMS := [
	"res://data/rooms/odyssey/room_01.tres",
	"res://data/rooms/odyssey/room_02.tres",
]
const PACKAGES := ["greek_drawn_courtyard_v1", "ashen_hell_courtyard_v1"]
const ENCOUNTERS := [
	"res://data/encounters/catabase_frail_hellspawn_encounter.tres",
	"res://data/encounters/odyssey_room_02_encounter.tres",
]
const SCENE := "res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn"


func _initialize() -> void:
	call_deferred("_prepare")


func _prepare() -> void:
	var rooms: Array[ArenaDefinition] = []
	var errors: Array[String] = []
	for index in range(ROOMS.size()):
		var room := ResourceLoader.load(ROOMS[index], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ArenaDefinition
		if room == null:
			errors.append("room_missing:%s" % ROOMS[index])
			continue
		var expected_plan := "res://data/arenas/%s/terrain_plan.json" % PACKAGES[index]
		if room.registered_terrain_plan_path != expected_plan or not FileAccess.file_exists(expected_plan):
			errors.append("registered_plan_missing_or_wrong:%s" % ROOMS[index])
			continue
		if room.encounter_definition == null or room.encounter_definition.resource_path != ENCOUNTERS[index]:
			errors.append("encounter_changed:%s" % ROOMS[index])
			continue
		if room.battle_scene == null or room.battle_scene.resource_path != SCENE:
			errors.append("production_scene_missing:%s" % ROOMS[index])
			continue
		var name_before := room.room_name
		if not ArenaRuntimeBridge.sync_runtime_resources(room):
			errors.append("runtime_projection_failed:%s" % ROOMS[index])
			continue
		if room.room_name != name_before or room.enemies.size() != [1, 3][index]:
			errors.append("room_name_or_roster_changed:%s" % ROOMS[index])
		if room.get_ultimate_reward_base_chance() != 0 or room.get_ultimate_reward_gain_range() != Vector2i.ZERO:
			errors.append("ultimate_economy_changed:%s" % ROOMS[index])
		if room.grid_layout == null or room.painted_map_visual_data == null:
			errors.append("derived_resources_missing:%s" % ROOMS[index])
		if room.cells.size() != 217 or room.get_wave_count() != 1 or not room.waves.is_empty():
			errors.append("floor_or_wave_contract_changed:%s" % ROOMS[index])
		rooms.append(room)
	if not errors.is_empty() or rooms.size() != 2:
		print(JSON.stringify({"ok": false, "errors": errors}))
		quit(1)
		return
	var saved: Array[String] = []
	for index in range(rooms.size()):
		var status := ResourceSaver.save(rooms[index], ROOMS[index])
		if status != OK:
			errors.append("resource_save_failed:%s:%d" % [ROOMS[index], status])
		else:
			saved.append(ROOMS[index])
	print(JSON.stringify({"ok": errors.is_empty(), "saved": saved, "errors": errors, "floor_cells_per_room": 217, "enemy_counts": [1, 3]}))
	quit(0 if errors.is_empty() else 1)
