extends Node

const RUN := preload("res://data/runs/first_run.tres")
const LAB_SCENE := preload("res://tools/labs/vfx_studio_slice/VFXStudioSliceLab.tscn")
const OUTPUT_ROOT := "res://artifacts/vfx_studio_feasibility"
const SHIELD := "res://vfx/profiles/test/shield_lifecycle.tres"
const LIGHTNING := "res://vfx/profiles/test/lightning_multi_target.tres"
const PATH := "res://vfx/profiles/test/player_path_preview.tres"

var captures: Array[String] = []
var failures: Array[String] = []
var metrics := {
	"schema_version": 1,
	"seed": 424242,
	"art_status": "TECHNICAL_PLACEHOLDER",
	"contexts": {},
	"fingerprints": {},
	"nodes": {},
}
var _lab: VFXStudioSliceLab
var _composer: VFXComposer
var _battle: Node
var _battle_instances: Array[VFXRuntimeInstance] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_window().size = Vector2i(1600, 900)
	_create_directories()
	await _capture_lab()
	await _capture_composer()
	await _capture_true_battle()
	_build_contact_sheet()
	metrics["captures"] = captures
	metrics["failures"] = failures
	metrics["capture_count"] = captures.size()
	_write_json(OUTPUT_ROOT + "/metrics/runtime_parity_metrics.json", metrics)
	print("VFX_STUDIO_CAPTURE_COUNT=%d" % captures.size())
	print("VFX_STUDIO_CAPTURE_FAILURES=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture_lab() -> void:
	_lab = LAB_SCENE.instantiate() as VFXStudioSliceLab
	add_child(_lab)
	for _frame in 4:
		await get_tree().process_frame
	_lab.play_all()
	metrics.fingerprints["lab"] = _lab.profile_fingerprints.duplicate(true)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_save(image, OUTPUT_ROOT + "/runtime_parity/lab.png")
	_save_region(image, Rect2i(0, 80, 533, 780), OUTPUT_ROOT + "/shield/lab_apply.png")
	_save_region(image, Rect2i(533, 80, 533, 780), OUTPUT_ROOT + "/lightning/lab_multi_target.png")
	_save_region(image, Rect2i(1066, 80, 534, 780), OUTPUT_ROOT + "/path/lab_ordered_cells.png")
	metrics.contexts["lab"] = "three fixed preview contexts; player path consumer_kind=PLAYER_CONTROLLED"
	_lab.clear_all()
	_lab.free()
	_lab = null
	for _frame in 2:
		await get_tree().process_frame


func _capture_composer() -> void:
	_composer = VFXComposer.new()
	add_child(_composer)
	for _frame in 5:
		await get_tree().process_frame
	_composer.scenario_option.select(0)
	_composer.play_preview()
	if is_instance_valid(_composer.current_instance):
		_composer.current_instance.set_process(false)
		_composer.current_instance.advance_simulation(0.24)
	metrics.fingerprints["composer"] = {
		str(_composer.document.working_copy.profile_id): _composer.document.current_fingerprint(),
	}
	metrics.contexts["composer"] = "working copy deep preview context"
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_save(image, OUTPUT_ROOT + "/composer/composer.png")
	_save_region(image, Rect2i(1260, 60, 340, 260), OUTPUT_ROOT + "/composer/module_stack.png")
	_save_region(image, Rect2i(1260, 300, 340, 580), OUTPUT_ROOT + "/composer/blackboard.png")
	_save_region(image, Rect2i(230, 690, 1030, 190), OUTPUT_ROOT + "/composer/timeline.png")
	_composer.clear_preview()
	_composer.free()
	_composer = null
	for _frame in 3:
		await get_tree().process_frame


func _capture_true_battle() -> void:
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(RUN, GameManager.PRODUCTION_HERO_DATA_PATHS):
		_fail("Initialisation de la vraie run impossible.")
		return
	GameManager.current_room_index = 0
	get_tree().set_meta(&"arena_studio_test_options", {
		"spawn_enemies": true, "spawn_heroes": true, "deployment_enabled": false,
		"hud_enabled": true, "combat_enabled": false, "draw_base_cells": false,
		"draw_grid_lines": false, "draw_cell_centers": false, "draw_map_bounds": false,
		"draw_logic_types": false, "draw_void_cells": false, "draw_coordinates": false,
		"draw_spawns": false, "draw_calibration": false,
	})
	_battle = RUN.rooms[0].battle_scene.instantiate()
	_battle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_battle)
	for _frame in 10:
		await get_tree().process_frame
	var views := _battle.get("_unit_views") as Dictionary
	var layer := _battle.get_node_or_null("VFXLayer") as Node2D
	var grid_view := _battle.get_node_or_null("IsoGridView") as Node2D
	if layer == null or grid_view == null or views.is_empty():
		_fail("VFXLayer, grille ou unités de vraie bataille indisponibles.")
		await _cleanup_battle()
		return
	var player_views: Array[Node2D] = []
	var enemy_views: Array[Node2D] = []
	for unit in views:
		var view := views[unit] as Node2D
		if view == null:
			continue
		if int(unit.team) == 0:
			player_views.append(view)
		else:
			enemy_views.append(view)
	if player_views.is_empty() or enemy_views.is_empty():
		_fail("Unités joueur/ennemies absentes du harness de vraie bataille.")
		await _cleanup_battle()
		return
	var shield_target := layer.to_local(player_views[0].to_global(Vector2(0, -28)))
	var lightning_origin := layer.to_local(player_views[-1].to_global(Vector2(0, -55)))
	var impacts := PackedVector2Array()
	for index in mini(enemy_views.size(), 3):
		impacts.append(layer.to_local(enemy_views[index].to_global(Vector2(0, -28))))
	var fixed_gameplay_cells: Array[Vector2i] = [
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 3),
	]
	var path_points := PackedVector2Array()
	for cell in fixed_gameplay_cells:
		var local_point: Vector2 = grid_view.grid_to_local(cell) if grid_view.has_method("grid_to_local") else grid_view.grid_to_world(cell)
		path_points.append(layer.to_local(grid_view.to_global(local_point)))
	var profiles := [_profile(SHIELD), _profile(LIGHTNING), _profile(PATH)]
	var contexts := [
		VFXExecutionContext.create({"target_world": shield_target, "impact_world_points": PackedVector2Array([shield_target + Vector2(24, -8)]), "seed": 424242, "quality_tier": 2, "magnitude": 0.8}),
		VFXExecutionContext.create({"origin_world": lightning_origin, "target_world": impacts[-1], "impact_world_points": impacts, "seed": 424242, "quality_tier": 2}),
		VFXExecutionContext.create({"origin_cell": fixed_gameplay_cells[0], "target_cell": fixed_gameplay_cells[-1], "ordered_path_cells": fixed_gameplay_cells, "path_world_points": path_points, "origin_world": path_points[0], "target_world": path_points[-1], "impact_world_points": PackedVector2Array([path_points[-1]]), "path_valid": true, "seed": 424242, "quality_tier": 2, "consumer_kind": &"PLAYER_CONTROLLED"}),
	]
	var sequences := [&"apply", &"play", &"play"]
	var battle_fingerprints := {}
	for index in profiles.size():
		battle_fingerprints[profiles[index].profile_id] = VFXProfileSnapshotService.fingerprint(profiles[index])
		var result := VFXProfileRunner.play(profiles[index], contexts[index], sequences[index], layer, false)
		if not bool(result.ok):
			_fail("Runner vraie bataille refusé : %s" % result.errors)
			continue
		var instance := result.instance as VFXRuntimeInstance
		instance.process_mode = Node.PROCESS_MODE_ALWAYS
		instance.advance_simulation(0.28)
		_battle_instances.append(instance)
	metrics.fingerprints["true_battle"] = battle_fingerprints
	metrics.contexts["true_battle"] = {
		"ordered_path_cells": fixed_gameplay_cells.map(func(cell): return [cell.x, cell.y]),
		"impact_count": impacts.size(), "layer": str(layer.get_path()),
	}
	metrics.nodes["battle_active"] = _battle_instances.size()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_save(image, OUTPUT_ROOT + "/runtime_parity/true_battle.png")
	_save(image, OUTPUT_ROOT + "/shield/true_battle.png")
	_save(image, OUTPUT_ROOT + "/lightning/true_battle.png")
	_save(image, OUTPUT_ROOT + "/path/true_battle.png")
	await _cleanup_battle()


func _cleanup_battle() -> void:
	for instance in _battle_instances:
		if is_instance_valid(instance):
			instance.clear()
			instance.free()
	_battle_instances.clear()
	metrics.nodes["battle_after_clear"] = 0
	if get_tree().has_meta(&"arena_studio_test_options"):
		get_tree().remove_meta(&"arena_studio_test_options")
	if is_instance_valid(_battle):
		_battle.process_mode = Node.PROCESS_MODE_INHERIT
		_battle.free()
		_battle = null
	GameManager.cleanup_run_state()
	for _frame in 6:
		await get_tree().process_frame


func _build_contact_sheet() -> void:
	var paths := [
		OUTPUT_ROOT + "/runtime_parity/lab.png",
		OUTPUT_ROOT + "/composer/composer.png",
		OUTPUT_ROOT + "/runtime_parity/true_battle.png",
	]
	var sheet := Image.create(1920, 360, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("08101b"))
	for index in paths.size():
		var image := Image.load_from_file(ProjectSettings.globalize_path(paths[index]))
		if image == null or image.is_empty():
			_fail("Image de contact sheet absente : %s" % paths[index])
			continue
		image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i(index * 640, 0))
	_save(sheet, OUTPUT_ROOT + "/runtime_parity/contact_sheet.png")


func _profile(path: String) -> VFXProfile:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as VFXProfile


func _create_directories() -> void:
	for folder in ["boot", "inventory", "architecture", "shield", "lightning", "path", "composer", "runtime_parity", "stress", "metrics"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT.path_join(folder)))


func _save(image: Image, path: String) -> void:
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("Capture impossible %s : %s" % [path, error_string(error)])
	else:
		captures.append(path)
		print("VFX_STUDIO_CAPTURE=%s" % ProjectSettings.globalize_path(path))


func _save_region(image: Image, rect: Rect2i, path: String) -> void:
	_save(image.get_region(rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))), path)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Métriques impossibles à écrire : %s" % path)
		return
	file.store_string(JSON.stringify(value, "  "))
	file.close()


func _fail(message: String) -> void:
	failures.append(message)
