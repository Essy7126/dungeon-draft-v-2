extends Node

# Scene entry point: autoloads exist before gameplay dependencies are loaded.
# Each configured launcher persists exactly one registered room.
@export_file("*.tres") var room_path := ""
@export_file("*.json") var terrain_plan_path := ""
@export_file("*.tres") var encounter_path := ""
@export var expected_room_name := ""
@export var expected_enemy_count := 3
const SCENE := "res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn"


func _ready() -> void:
	_prepare.call_deferred()


func _prepare() -> void:
	var errors: Array[String] = []
	if room_path.is_empty() or terrain_plan_path.is_empty() or encounter_path.is_empty() or expected_room_name.is_empty():
		_finish(["launcher_configuration_missing"])
		return
	var room := ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ArenaDefinition
	if room == null:
		_finish(["room_missing"])
		return
	if room.registered_terrain_plan_path != terrain_plan_path or not FileAccess.file_exists(terrain_plan_path):
		errors.append("registered_plan_missing_or_wrong")
	if room.encounter_definition == null or room.encounter_definition.resource_path != encounter_path:
		errors.append("canonical_encounter_missing_or_wrong")
	if room.battle_scene == null or room.battle_scene.resource_path != SCENE:
		errors.append("production_scene_missing_or_wrong")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(terrain_plan_path.get_base_dir().path_join("geometry_manifest.json")))
	if not parsed is Dictionary:
		errors.append("geometry_manifest_missing_or_invalid")
	if not errors.is_empty():
		_finish(errors)
		return
	var manifest: Dictionary = parsed
	var floor := _cells(manifest.get("floor_cells", []))
	var blocked := {}
	for group: Dictionary in manifest.get("obstacles", []):
		blocked.merge(_cells(group.get("cells", [])))
	var actual_floor := {}
	for cell in room.cells:
		if cell != null and cell.defined and cell.cell_type != GridData.CellType.HOLE:
			actual_floor[cell.coordinate] = true
	var actual_blocked := {}
	for obstacle in room.obstacles:
		if obstacle != null:
			actual_blocked[obstacle.cell] = true
	if actual_floor != floor or actual_blocked != blocked:
		errors.append("tactical_geometry_differs_from_manifest")
	var gameplay_before := RoomDataSnapshotService.to_gameplay_snapshot(room)
	var name_before := room.room_name
	if not ArenaRuntimeBridge.sync_runtime_resources(room):
		_finish(["runtime_projection_failed"])
		return
	if RoomDataSnapshotService.to_gameplay_snapshot(room) != gameplay_before:
		errors.append("gameplay_changed_during_projection")
	if room.room_name != name_before or room.room_name != expected_room_name:
		errors.append("room_identity_changed")
	if room.grid_layout == null or room.painted_map_visual_data == null:
		errors.append("persisted_projection_missing")
	if room.enemies.size() != expected_enemy_count or room.get_wave_count() != 1 or not room.waves.is_empty():
		errors.append("roster_or_waves_changed")
	if room.get_ultimate_reward_base_chance() != 0 or room.get_ultimate_reward_gain_range() != Vector2i.ZERO:
		errors.append("ultimate_economy_changed")
	if _cells(manifest.get("hero_spawns", [])) != _position_set(room.hero_spawn_zone) \
			or _cells(manifest.get("enemy_spawns", [])) != _position_set(room.enemy_spawn_zone):
		errors.append("spawn_projection_differs_from_manifest")
	if not errors.is_empty():
		_finish(errors)
		return
	var status := ResourceSaver.save(room, room_path)
	if status != OK:
		errors.append("room_save_failed:%d" % status)
	_finish(errors)


func _cells(values: Array) -> Dictionary:
	var result := {}
	for value: Array in values:
		result[Vector2i(int(value[0]), int(value[1]))] = true
	return result


func _position_set(values: Array[Vector2i]) -> Dictionary:
	var result := {}
	for cell in values:
		result[cell] = true
	return result


func _finish(errors: Array[String]) -> void:
	print(JSON.stringify({"ok": errors.is_empty(), "room": room_path, "saved": errors.is_empty(), "errors": errors}))
	get_tree().quit(0 if errors.is_empty() else 1)
