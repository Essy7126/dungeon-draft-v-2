extends Node

# Persist only the new third Catabase room after the registered package import.
# The run, first two rooms and canonical encounter/economy are read-only.
const ROOM := "res://data/rooms/odyssey/room_03.tres"
const PLAN := "res://data/arenas/silent_judgment_courtyard_v1/terrain_plan.json"
const ENCOUNTER := "res://data/encounters/odyssey_room_03_encounter.tres"
const SCENE := "res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn"


func _ready() -> void:
	_prepare.call_deferred()


func _prepare() -> void:
	var errors: Array[String] = []
	var room := ResourceLoader.load(ROOM, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ArenaDefinition
	if room == null:
		_finish(["room_missing"])
		return
	if room.registered_terrain_plan_path != PLAN or not FileAccess.file_exists(PLAN):
		errors.append("registered_plan_missing_or_wrong")
	if room.encounter_definition == null or room.encounter_definition.resource_path != ENCOUNTER:
		errors.append("canonical_finale_encounter_missing_or_wrong")
	if room.battle_scene == null or room.battle_scene.resource_path != SCENE:
		errors.append("production_scene_missing_or_wrong")
	if not errors.is_empty():
		_finish(errors)
		return
	var gameplay_before := RoomDataSnapshotService.to_gameplay_snapshot(room)
	var name_before := room.room_name
	if not ArenaRuntimeBridge.sync_runtime_resources(room):
		_finish(["runtime_projection_failed"])
		return
	if RoomDataSnapshotService.to_gameplay_snapshot(room) != gameplay_before:
		errors.append("finale_gameplay_changed_during_projection")
	if room.room_name != name_before or room.room_name != "Catabase III — Le Jugement de Paris":
		errors.append("room_identity_changed")
	if room.cells.size() != 217 or room.obstacles.size() != 12:
		errors.append("tactical_geometry_changed")
	if room.grid_layout == null or room.painted_map_visual_data == null:
		errors.append("persisted_projection_missing")
	if room.enemies.size() != 2 or room.get_wave_count() != 1 or not room.waves.is_empty():
		errors.append("finale_roster_or_waves_changed")
	if room.get_ultimate_reward_base_chance() != 0 or room.get_ultimate_reward_gain_range() != Vector2i.ZERO:
		errors.append("ultimate_economy_changed")
	if not errors.is_empty():
		_finish(errors)
		return
	var status := ResourceSaver.save(room, ROOM)
	if status != OK:
		errors.append("room_save_failed:%d" % status)
	_finish(errors)


func _finish(errors: Array[String]) -> void:
	print(JSON.stringify({"ok": errors.is_empty(), "room": ROOM, "saved": errors.is_empty(), "errors": errors}))
	get_tree().quit(0 if errors.is_empty() else 1)
