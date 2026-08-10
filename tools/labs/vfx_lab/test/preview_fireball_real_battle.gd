extends Node

const RUN := preload("res://data/runs/first_run.tres")
const FIREBALL_SCENE := preload("res://tools/labs/vfx_lab/effects/FireballLabVFX.tscn")
const OUTPUT_DIR := "res://artifacts/fireball_variants/real_battle"
const REFERENCE_SEED := 424242
const VARIANTS := [&"A", &"B", &"C"]
const CAPTURE_TIMES := [0.62, 1.18]
const FRAME_NAMES := ["projectile_mid_t062.png", "impact_expansion_t118.png"]

var _battle: Node = null
var _stage: Node2D = null
var _start := Vector2.ZERO
var _target := Vector2.ZERO
var _failures := 0
var _captures: Array[String] = []
var _exit_code := 0


func _ready() -> void:
	call_deferred("_preview")


func _preview() -> void:
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	):
		_fail("initialisation de la run impossible")
		await _finish()
		return
	GameManager.current_room_index = 0
	get_tree().set_meta(&"arena_studio_test_options", {
		"spawn_enemies": true,
		"spawn_heroes": true,
		"deployment_enabled": false,
		"hud_enabled": true,
		"combat_enabled": false,
		"draw_base_cells": false,
		"draw_grid_lines": false,
		"draw_cell_centers": false,
		"draw_map_bounds": false,
		"draw_logic_types": false,
		"draw_void_cells": false,
		"draw_coordinates": false,
		"draw_spawns": false,
		"draw_calibration": false,
	})
	_battle = RUN.rooms[0].battle_scene.instantiate()
	_battle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_battle)
	for _frame in 8:
		await get_tree().process_frame
	if not _resolve_reference_anchors():
		await _finish()
		return
	for variant in VARIANTS:
		await _capture_variant(variant)
	await _finish()


func _resolve_reference_anchors() -> bool:
	var views := _battle.get("_unit_views") as Dictionary
	_stage = _battle.get("_unit_view_parent") as Node2D
	if _stage == null or views.is_empty():
		_fail("couche d'unites reelle indisponible")
		return false
	var caster_view: Node2D = null
	var target_view: Node2D = null
	for unit in views:
		var view := views[unit] as Node2D
		if view == null:
			continue
		if int(unit.team) == 0 and StringName(unit.unit_id) == &"mage":
			caster_view = view
		elif int(unit.team) == 1 and target_view == null:
			target_view = view
	if caster_view == null or target_view == null:
		_fail("mage ou cible ennemie absente de la scene reelle")
		return false
	_start = _stage.to_local(caster_view.to_global(Vector2(0.0, -62.0)))
	_target = _stage.to_local(target_view.to_global(Vector2(0.0, -8.0)))
	return true


func _capture_variant(variant: StringName) -> void:
	var directory := OUTPUT_DIR.path_join("variant_%s" % variant)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var effect: Node2D = FIREBALL_SCENE.instantiate() as Node2D
	_stage.add_child(effect)
	effect.play({
		"seed": REFERENCE_SEED,
		"variant": variant,
		"start": _start,
		"target": _target,
	})
	effect.set_process(false)
	var previous_time := 0.0
	for frame_index in CAPTURE_TIMES.size():
		var target_time: float = CAPTURE_TIMES[frame_index]
		await _advance(effect, target_time - previous_time)
		previous_time = target_time
		await RenderingServer.frame_post_draw
		var path := directory.path_join(FRAME_NAMES[frame_index])
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			_fail("capture contexte %s impossible: %s" % [path, error_string(error)])
		else:
			_captures.append(path)
			print("FIREBALL_REAL_BATTLE_CAPTURE=%s" % ProjectSettings.globalize_path(path))
	effect.stop_and_clear()
	effect.free()
	if _stage.get_children().any(func(child): return child.scene_file_path == FIREBALL_SCENE.resource_path):
		_fail("node Fireball residuel dans la bataille reelle")
	for _frame in 3:
		await get_tree().process_frame


func _advance(effect: Node, seconds: float) -> void:
	var frames := maxi(1, ceili(seconds * 60.0))
	var step := seconds / float(frames)
	for _frame in frames:
		effect.advance_simulation(step)
		await get_tree().process_frame


func _finish() -> void:
	if get_tree().has_meta(&"arena_studio_test_options"):
		get_tree().remove_meta(&"arena_studio_test_options")
	if is_instance_valid(_battle):
		_battle.process_mode = Node.PROCESS_MODE_INHERIT
		_battle.free()
		print("FIREBALL_REAL_BATTLE_FREED=%s" % str(not is_instance_valid(_battle)))
		for _frame in 8:
			await get_tree().process_frame
		_battle = null
	GameManager.cleanup_run_state()
	for _frame in 4:
		await get_tree().process_frame
	print("FIREBALL_REAL_BATTLE_CAPTURE_COUNT=%d" % _captures.size())
	print("FIREBALL_REAL_BATTLE_FAILURES=%d" % _failures)
	if _failures == 0:
		print("FIREBALL_REAL_BATTLE_PREVIEW_OK")
	_exit_code = 1 if _failures > 0 else 0
	_delayed_quit.call_deferred()


func _delayed_quit() -> void:
	for _frame in 24:
		await get_tree().process_frame
	get_tree().quit(_exit_code)


func _fail(message: String) -> void:
	_failures += 1
	push_error("FIREBALL_REAL_BATTLE_PREVIEW: %s" % message)
