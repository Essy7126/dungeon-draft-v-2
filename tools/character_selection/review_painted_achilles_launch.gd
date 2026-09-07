extends SceneTree
## Actual selection -> introduction -> Catabase battle, captured by the renderer.
## The dedicated review process writes only an isolated temporary route save.

const OUTPUT := "res://artifacts/achilles_painted_g_integration/"
const SELECTION := "res://ui/selection/CharacterSelectionScreen.tscn"
const INTRO := "res://cinematics/intro/intro_cinematic.tscn"
const PAINTED_SCENE := "res://characters/achilles/AchillesPaintedGUnitView.tscn"
const PAINTED_PORTRAIT := "res://assets/characters/Achilles/sprites_painted_g/achilles_portrait.tres"
var _manager: Node
var _save_path := ""
var _player_save_path := ""
var _player_save_before := ""
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("PAINTED_ACHILLES_PROBE: selection setup")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	_manager = root.get_node("GameManager")
	_player_save_path = _manager.expedition_save_path
	_player_save_before = _fingerprint(_player_save_path)
	_save_path = OS.get_environment("TEMP").path_join("painted-achilles-review-%d.json" % Time.get_ticks_usec())
	_manager.expedition_save_path = _save_path
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	# Load project classes after autoload initialization: this is a SceneTree entry.
	var selection = load(SELECTION).instantiate()
	root.add_child(selection)
	current_scene = selection
	await _settle()
	var painted_index := -1
	var entries = selection.get_entries()
	for index in range(entries.size()):
		if entries[index].id == &"achilles_painted_g":
			painted_index = index
	if not _check(painted_index >= 0 and selection.select_character(painted_index), "Painted Achille is selectable"):
		await _finish()
		return
	var selected = selection.get_selected_entry()
	var run = selected.run
	_check(selected.unit.get_effective_unit_id() == &"achilles", "Selection retains canonical gameplay identity")
	_check(run.hero_visual_variants == {"achilles": "painted_g"}, "Selection carries the painted appearance")
	_check(selection.get_preview().get_sprite_instance().sprite_frames == selected.unit.preview_sprite_frames, "Selection renders the actual painted preview")
	_check(selection._portrait_for(selected.unit, true).resource_path == PAINTED_PORTRAIT, "Painted selection uses its cropped portrait")
	_check(selection.select_character(0), "Classic Achille remains selectable after painted Achille")
	selection._roster_buttons[0].grab_focus()
	var classic = selection.get_selected_entry()
	_check(classic.id == &"achilles" and classic.run.hero_visual_variants.is_empty(), "Returning to classic clears the appearance selection")
	_check(classic.unit.visual_scene.resource_path != PAINTED_SCENE, "Classic choice restores its original unit scene")
	_check(classic.unit.portrait_texture_override == null and selection._portrait_for(classic.unit).resource_path.contains("illustrated_v2"), "Classic choice keeps its original portrait")
	_check(selection.get_preview().get_sprite_instance().sprite_frames == classic.unit.preview_sprite_frames, "Classic choice restores its original preview")
	_check(classic.unit.spells == selected.unit.spells and classic.unit.progression_profile == selected.unit.progression_profile, "Switching appearance preserves the same spells and progression")
	await _settle()
	await _capture("selection_classique_apres_peint_1280x720")
	_check(selection.select_character(painted_index), "Painted Achille can be reselected for the actual launch")
	selection._roster_buttons[painted_index].grab_focus()
	await _settle()
	await _capture("selection_peint_1280x720")
	root.size = Vector2i(1920, 1080)
	await _settle()
	await _capture("selection_peint_1920x1080")
	# The same launch button and cinematic handlers used by the player own launch.
	selection.start_button.pressed.emit()
	if not await _wait_for_scene(INTRO):
		await _finish()
		return
	_check(_manager.peek_next_run_data() == run, "Cinematic keeps the selected RunData")
	current_scene.request_skip()
	var battle_path: String = run.rooms[0].battle_scene.resource_path
	if not await _wait_for_scene(battle_path):
		await _finish()
		return
	var battle := current_scene
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not bool(battle.get("runtime_ready_state")):
		await create_timer(0.1).timeout
	if not _check(bool(battle.get("runtime_ready_state")), "Actual Catabase battle becomes ready"):
		await _finish()
		return
	var deployment = battle.get("_deployment")
	var grid = battle.get("grid")
	if deployment != null and deployment.is_active():
		for cell in _manager.get_current_room().hero_spawn_zone:
			if grid.is_walkable(cell) and not grid.has_unit(cell):
				deployment.on_cell_clicked(cell)
				break
	await _settle()
	var hero = _manager.get_character_state(&"achilles").unit
	_check(hero.visual_scene.resource_path == PAINTED_SCENE, "Battle uses painted unit scene")
	_check(_manager.get_ordered_heroes().size() == 1 and hero.unit_id == &"achilles", "Run uses one canonical Achille")
	_check(_manager.expedition.route.current_node_id == "d01_0", "Run starts at the canonical Catabase opening")
	var hud = battle.get("action_bar")
	var portrait_view = hud.get("_portrait_view") if hud != null else null
	_check(portrait_view != null and portrait_view.portrait_texture.texture == hero.portrait_texture_override and hero.portrait_texture_override.resource_path == PAINTED_PORTRAIT, "Actual battle HUD renders the painted portrait")
	var views: Dictionary = battle.get("_unit_views")
	_check(views.has(hero) and is_instance_valid(views[hero]), "Painted unit has a real battle view")
	if views.has(hero):
		var painted_visual := views[hero].get_optional_visual() as Node2D
		_check(is_instance_valid(painted_visual) and painted_visual.scene_file_path == PAINTED_SCENE, "Shared UnitView instantiates the selected painted scene")
	await _capture("catabase_peint_1920x1080")
	root.size = Vector2i(1280, 720)
	await _settle()
	await _capture("catabase_peint_1280x720")
	await _finish()


func _wait_for_scene(path: String) -> bool:
	print("PAINTED_ACHILLES_PROBE: waiting for ", path)
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path:
			await _settle()
			return _check(true, "Actual scene reached: " + path)
		await create_timer(0.1).timeout
	return _check(false, "Timed out waiting for scene: " + path)


func _settle() -> void:
	await create_timer(0.7).timeout
	for index in range(4):
		await process_frame


func _capture(label: String) -> void:
	print("PAINTED_ACHILLES_PROBE: capturing ", label)
	for frame in range(3):
		await process_frame
	# Hidden/off-screen windows may not emit frame_post_draw until forced.
	RenderingServer.force_draw(false)
	var rendered := root.get_texture().get_image()
	if not _check(rendered != null and not rendered.is_empty(), "Viewport captured: " + label):
		return
	var path := OUTPUT + label + ".png"
	_check(rendered.save_png(ProjectSettings.globalize_path(path)) == OK, "Capture written: " + label)
	_captures.append({"path": path, "width": rendered.get_width(), "height": rendered.get_height()})


func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"


func _check(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error(description)
	return condition


func _finish() -> void:
	if is_instance_valid(current_scene):
		var scene := current_scene
		current_scene = null
		scene.queue_free()
		await process_frame
		await process_frame
	_manager.clear_next_run_configuration()
	_manager.cleanup_run_state()
	_manager.expedition_save_path = _player_save_path
	_check(_fingerprint(_player_save_path) == _player_save_before, "Player route save is unchanged")
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	var report := {"passed": _failures.is_empty(), "checks": _checks, "failures": _failures, "captures": _captures, "writes_player_save": false}
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("PAINTED_ACHILLES_LAUNCH_REVIEW: ", JSON.stringify(report))
	# Let _run unwind so its local RunData, unit and view references are released.
	_quit_after_cleanup.call_deferred(0 if _failures.is_empty() else 1)


func _quit_after_cleanup(exit_code: int) -> void:
	for frame in range(4):
		await process_frame
	quit(exit_code)
