extends Node

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const OUTPUT_DIR := "res://artifacts/odyssey_validation/captures"
const VIEWPORT_SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = VIEWPORT_SIZE
	var resolution := RunHeroResolver.resolve_runtime_hero_data(RUN, false)
	if not resolution.is_valid():
		push_error("CATABASE_MAP_CAPTURE: résolution d'Achille impossible.")
		get_tree().quit(1)
		return
	var captures: Array[Dictionary] = []
	for room_index in range(RUN.rooms.size()):
		GameManager.cleanup_run_state()
		if not GameManager._prepare_preconfigured_run(RUN, resolution.heroes):
			push_error("CATABASE_MAP_CAPTURE: préparation runtime impossible.")
			get_tree().quit(1)
			return
		GameManager.current_room_index = room_index
		var room := RUN.rooms[room_index]
		var battle = room.battle_scene.instantiate()
		# The actual battle scene renders the map. Simulation is frozen only so
		# captures stay deterministic and no AI turn runs in the background.
		battle.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(battle)
		await _settle(10)
		_deploy_first_hero(battle, room)
		await _settle(4)
		_hide_transient_overlays(battle)
		await _settle(2)
		var file_name := "catabase_map_%02d_1920x1080.png" % (room_index + 1)
		var path := OUTPUT_DIR.path_join(file_name)
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("CATABASE_MAP_CAPTURE: capture impossible : %s" % path)
			get_tree().quit(1)
			return
		captures.append({
			"room": room_index + 1,
			"room_name": room.room_name,
			"path": path,
			"size": [image.get_width(), image.get_height()],
			"camera_position": str(battle.camera.position),
			"camera_zoom": str(battle.camera.zoom),
		})
		battle.queue_free()
		await _settle(4)
	GameManager.cleanup_run_state()
	print("CATABASE_MAP_CAPTURES=" + JSON.stringify(captures))
	get_tree().quit(0)


func _deploy_first_hero(battle, room: RoomData) -> void:
	if battle._deployment == null or not battle._deployment.is_active():
		return
	for cell in room.hero_spawn_zone:
		if battle.grid.is_valid(cell) \
				and battle.grid.is_walkable(cell) \
				and not battle.grid.has_unit(cell):
			battle._deployment.on_cell_clicked(cell)
			return


func _hide_transient_overlays(battle: Node) -> void:
	var banner := battle.find_child("TurnIntroBanner", true, false)
	if not is_instance_valid(banner):
		banner = get_tree().root.find_child("TurnIntroBanner", true, false)
	if not is_instance_valid(banner):
		return
	if banner.has_method("hide_immediately"):
		banner.hide_immediately()
	banner.process_mode = Node.PROCESS_MODE_DISABLED
	banner.visible = false
	banner.modulate.a = 0.0


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
