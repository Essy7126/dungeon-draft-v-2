extends Node

const RUN := preload("res://data/runs/first_run.tres")
const OUTPUT_DIR := "res://artifacts/first_run_v2/captures/rooms"
const EXPECTED := [
	{&"skeleton_normal": 4, &"skeleton_chief": 0, &"skeleton_centurion": 0},
	{&"skeleton_normal": 3, &"skeleton_chief": 1, &"skeleton_centurion": 0},
	{&"skeleton_normal": 4, &"skeleton_chief": 2, &"skeleton_centurion": 0},
	{&"skeleton_normal": 0, &"skeleton_chief": 3, &"skeleton_centurion": 1},
	{&"skeleton_normal": 4, &"skeleton_chief": 2, &"skeleton_centurion": 2},
	{&"skeleton_normal": 0, &"skeleton_chief": 4, &"skeleton_centurion": 4},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	):
		_fail("initialisation de la run impossible")
		return
	var report := {
		"seed": GameManager.get_run_seed(),
		"resolution": [1920, 1080],
		"rooms": [],
		"passed": true,
	}
	for room_index in RUN.rooms.size():
		var room_report := await _capture_room(room_index)
		report.rooms.append(room_report)
		if not room_report.get("passed", false):
			report.passed = false
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	await get_tree().process_frame
	var output := FileAccess.open(
		"res://artifacts/first_run_v2/room_capture_report.json",
		FileAccess.WRITE,
	)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("FIRST_RUN_ROOM_CAPTURES=" + JSON.stringify(report))
	get_tree().quit(0 if report.passed and output != null else 1)


func _capture_room(room_index: int) -> Dictionary:
	GameManager.current_room_index = room_index
	var room := RUN.rooms[room_index] as RoomData
	var battle := room.battle_scene.instantiate()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(battle)
	for _frame in 4:
		await get_tree().process_frame
	var enemies: Array = battle.units.filter(func(value):
		return value != null and (value as Unit).team == 1
	)
	var roles := {
		&"skeleton_normal": 0,
		&"skeleton_chief": 0,
		&"skeleton_centurion": 0,
	}
	var cells: Array[String] = []
	var all_visible := true
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var views := battle.get("_unit_views") as Dictionary
	for enemy_value in enemies:
		var enemy := enemy_value as Unit
		roles[enemy.tactical_role_id] = int(roles.get(enemy.tactical_role_id, 0)) + 1
		cells.append("%d,%d" % [enemy.grid_pos.x, enemy.grid_pos.y])
		var view := views.get(enemy) as Node2D
		if view == null or not view.visible or not viewport_rect.has_point(
			view.get_global_transform_with_canvas().origin
		):
			all_visible = false
	cells.sort()
	var unique_cells := {}
	for cell in cells:
		unique_cells[cell] = true
	await RenderingServer.frame_post_draw
	var path := "%s/room_%02d_full_roster.png" % [OUTPUT_DIR, room_index + 1]
	var save_error := get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(path)
	)
	var expected := EXPECTED[room_index] as Dictionary
	var passed: bool = enemies.size() == room.encounter_definition.expanded_roster().size() \
		and roles == expected \
		and unique_cells.size() == enemies.size() \
		and all_visible \
		and save_error == OK
	var result := {
		"room": room_index + 1,
		"room_name": room.room_name,
		"enemy_count": enemies.size(),
		"roles": roles,
		"cells": cells,
		"formation": str(battle.encounter_formation_snapshot.get("formation_id", &"")),
		"all_unit_anchors_visible": all_visible,
		"capture": path,
		"passed": passed,
	}
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return result


func _fail(message: String) -> void:
	push_error("CAPTURE FIRST RUN V2: %s" % message)
	get_tree().quit(1)
