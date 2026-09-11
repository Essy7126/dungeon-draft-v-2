extends Node
const Fixture := preload("res://tools/run_explorer/route_explorer_fixture.gd")
const Routes := preload("res://hub/seuil_crossroads/seuil_route_choices.gd")
var output := ""
var checks: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, passed: bool) -> void:
	checks.append({ "label": label, "passed": passed })
	if not passed:
		push_error("SEUIL: " + label)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if not output.begins_with("res://artifacts/dev/"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	get_tree().current_scene = null
	GameManager.expedition_save_path = output.path_join("checkpoint.json")
	var initial := Fixture.prepare(self, 2401, "d01_0", output.path_join("fixture.json"))
	_check("initial_snapshot", GameManager.restore_expedition_snapshot(initial))
	GameManager.start_next_battle()
	var ready: bool = await _wait_scene("RegisteredTerrainBattle.tscn")
	_check("first_battle_loaded", ready)
	if not ready:
		_finish()
		return
	await _capture("combat")
	var battle_ref: WeakRef = weakref(get_tree().current_scene)
	GameManager.on_battle_won()
	ready = await _wait_scene("SeuilCrossroads.tscn")
	_check("victory_opens_exploration", ready)
	_check("combat_scene_freed", battle_ref.get_ref() == null)
	if not ready:
		_finish()
		return
	var scene = get_tree().current_scene
	for frame in 8:
		await get_tree().create_timer(0.2).timeout
		await _capture("fire-%02d" % frame)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().create_timer(0.2).timeout
		await _capture("exploration-%dx%d" % [resolution.x, resolution.y])
	get_window().size = Vector2i(1280, 720)
	await get_tree().create_timer(0.2).timeout
	for index in 3:
		var landmark: Dictionary = scene.definition.landmarks[index]
		var screen_point: Vector2 = scene.world.to_global(scene.point(landmark.focus))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = screen_point
		click.global_position = screen_point
		Input.parse_input_event(click)
		await get_tree().process_frame
		click = click.duplicate()
		click.pressed = false
		Input.parse_input_event(click)
		for frame in 1000:
			scene.advance_world(0.05)
			if scene.interactions.active:
				break
		_check(
			"click_and_approach_" + str(landmark.id),
			scene.interactions.active and scene.interactions.selected == index,
		)
		_check("safe_approach_" + str(landmark.id), scene.nav.is_walkable(scene.player.position))
		if index == 0:
			await get_tree().create_timer(0.3).timeout
			await _capture("progression")
			get_window().size = Vector2i(1920, 1080)
			await get_tree().create_timer(0.3).timeout
			await _capture("progression-1920x1080")
			get_window().size = Vector2i(1280, 720)
			await get_tree().create_timer(0.3).timeout
		scene.interactions.close()
	scene.interactions.open(0)
	await get_tree().create_timer(0.3).timeout
	var attribute := scene.find_child("Attribute_vitality", true, false) as Button
	_check("attribute_visible", attribute != null and attribute.is_visible_in_tree())
	if attribute != null:
		await _click_control(attribute)
	_check(
		"attribute_spent_by_click",
		GameManager.expedition.character.champion_progression.unspent_attribute_points == 0,
	)
	await _capture("reward")
	var reward := scene.find_child("SeuilReward_supplies", true, false) as Button
	_check("reward_visible", reward != null and reward.is_visible_in_tree())
	if reward != null:
		await _click_control(reward)
	_check("reward_claimed_by_click", GameManager.expedition.route.phase == "map")
	var saved := GameManager.get_expedition_snapshot()
	for index in 3:
		_check("restore_crossroads", GameManager.restore_expedition_snapshot(saved))
		GameManager._request_scene_change(GameManager.get_expedition_destination_scene())
		await get_tree().process_frame
		_check("resumed_room_ready", await _wait_scene("SeuilCrossroads.tscn"))
		scene = get_tree().current_scene
		var landmark: Dictionary = scene.definition.landmarks[index]
		var expected := Routes.destination(GameManager.expedition, landmark.id)
		scene.interactions.open(index)
		await _capture("choice-" + str(landmark.id))
		_check("departure_" + str(landmark.id), scene.depart(index))
		_check(
			"destination_" + str(landmark.id),
			GameManager.expedition.route.current_node_id == str(expected.id),
		)
		_check("next_battle_" + str(landmark.id), await _wait_scene("RegisteredTerrainBattle.tscn"))
	_finish()


func _wait_scene(suffix: String) -> bool:
	for frame in 1800:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null or not scene.scene_file_path.ends_with(suffix):
			continue
		if suffix == "SeuilCrossroads.tscn" and scene.is_ready_for_play():
			return true
		if (
			suffix == "RegisteredTerrainBattle.tscn"
			and scene.get("registered_terrain_ready") == true
		):
			return true
	return false


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(output.path_join(label + ".png"))
	)


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	_check("button_on_screen_" + str(control.name), get_viewport().get_visible_rect().has_point(
			position
		))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout


func _finish() -> void:
	var passed := checks.all(
		func(check):
			return bool(check.passed),
	)
	var file := FileAccess.open(output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({ "passed": passed, "count": checks.size(), "checks": checks }, "\t")
	)
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
	await get_tree().process_frame
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
