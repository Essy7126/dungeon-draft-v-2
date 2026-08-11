extends Control

const RUN: RunData = preload("res://data/runs/first_run.tres")
const FIREBALL: Spell = preload("res://data/spells/Mage/boule_de_feu.tres")
const ICE_WALL: Spell = preload("res://data/spells/mur_de_glace.tres")
const WATER: TerrainEffectData = preload("res://data/terrain/eau.tres")
const OUTPUT := "res://artifacts/dynamic_terrain_tile_replacement/captures"
const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(1200, 896),
]
const TEST_OPTIONS := {
	"spawn_enemies": true,
	"spawn_heroes": true,
	"deployment_enabled": false,
	"hud_enabled": false,
	"combat_enabled": false,
	"draw_base_cells": false,
	"draw_grid_lines": true,
	"draw_cell_centers": false,
	"draw_map_bounds": false,
	"draw_logic_types": false,
	"draw_void_cells": false,
	"draw_coordinates": false,
	"draw_spawns": false,
	"draw_calibration": false,
}

var _battle: Node = null
var _overlay_layer: CanvasLayer = null
var _overlay: PanelContainer = null
var _overlay_label: Label = null
var _metrics: Dictionary = {
	"mission": "DYNAMIC_TERRAIN_TILE_REPLACEMENT",
	"status": "WORKTREE_CANDIDATE",
	"captures": [],
	"failures": [],
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run")


func _run() -> void:
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=run_started")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_build_overlay()
	for requested_size in SIZES:
		print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=resolution_start:", requested_size)
		get_window().size = requested_size
		await _wait_frames(5)
		print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=resolution_frames_ready:", requested_size)
		await _capture_resolution(requested_size)
	_write_report()
	print("DYNAMIC_TERRAIN_CAPTURE_COMPLETE=", JSON.stringify({
		"ok": (_metrics.failures as Array).is_empty(),
		"capture_count": (_metrics.captures as Array).size(),
		"failures": _metrics.failures,
	}))
	get_tree().quit(0 if (_metrics.failures as Array).is_empty() else 1)


func _capture_resolution(size: Vector2i) -> void:
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=battle_setup_start:", size)
	var setup := await _create_integrated_battle()
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=battle_setup_end:", size, ":", setup.get("ok", false))
	if not bool(setup.get("ok", false)):
		_fail("setup_%dx%d:%s" % [size.x, size.y, setup.get("error", "unknown")])
		return
	var room := setup.room as ArenaDefinition
	var grid := setup.grid as GridData
	var caster := setup.caster as SpellCaster
	var terrain := setup.terrain as TerrainEffects
	var mage := setup.mage as Unit
	var target: Vector2i = setup.target
	var fire_cells: Array = caster.get_aoe_cells(FIREBALL, target, mage.grid_pos)
	var fingerprint_before := RoomDataSnapshotService.room_fingerprint(room)

	await _capture_case(
		"01_terrain_normal_before_fireball", size, room, fire_cells,
		"Terrain pierre avant Boule de feu\nAucune surface runtime active"
	)
	mage.current_ap = mage.max_ap.get_int()
	var cast_report: Dictionary = caster.cast(mage, FIREBALL, target)
	await _wait_frames(1)
	await _capture_case(
		"02_fireball_impact", size, room, fire_cells,
		"Impact réel · Boule de feu\nterrain_changed=%d · cible=%s" % [
			(cast_report.get("terrain_changed", []) as Array).size(), target,
		]
	)
	await _wait_frames(3)
	await _capture_case(
		"03_nine_lava_tiles", size, room, fire_cells,
		"9 dalles lave · texture complète\nSols pierre masqués · grille/unités au-dessus"
	)
	terrain.tick_all_effects()
	await _wait_frames(2)
	await _capture_case(
		"04_remaining_duration", size, room, fire_cells,
		"Lave active · durée restante 2/3\nGameplay et visuel synchronisés"
	)
	terrain.tick_all_effects()
	terrain.tick_all_effects()
	await _wait_frames(2)
	await _capture_case(
		"05_expiration_stone_return", size, room, fire_cells,
		"Expiration au tick 3\nDalles lave retirées · pierre exacte restaurée"
	)

	var ice_target := _find_full_target(caster, mage, ICE_WALL, terrain)
	var ice_cells: Array = caster.get_aoe_cells(ICE_WALL, ice_target, mage.grid_pos)
	_apply_terrain_spell(terrain, ICE_WALL, ice_cells, mage)
	await _wait_frames(2)
	await _capture_case(
		"06_ice_wall", size, room, ice_cells,
		"Mur de glace réel · texture ice\nDurée 3 · CellType ICE"
	)
	terrain.reset()
	var water_cell := _find_remote_surface_cell(terrain, target)
	terrain.place_effect(water_cell, WATER, mage)
	await _wait_frames(2)
	await _capture_case(
		"07_temporary_water", size, room, [water_cell],
		"Eau temporaire · eau.tres\nDurée 3 · statut Mouillé · base conservée"
	)

	terrain.reset()
	terrain.place_effect(water_cell, FIREBALL.terrain_effect, mage, FIREBALL)
	terrain.place_effect(water_cell, WATER, mage)
	await _wait_frames(2)
	await _capture_case(
		"08_fire_plus_water_steam", size, room, [water_cell],
		"Feu + eau → vapeur\nDalle vapeur temporaire · durée gameplay 2"
	)

	terrain.reset()
	terrain.place_effect(water_cell, FIREBALL.terrain_effect, mage, FIREBALL)
	terrain.place_effect(water_cell, ICE_WALL.terrain_effect, mage, ICE_WALL)
	await _wait_frames(2)
	await _capture_case(
		"09_fire_plus_ice_water", size, room, [water_cell],
		"Feu + glace → eau\nRésultat gameplay = dalle water"
	)
	terrain.reset()
	await _wait_frames(2)
	await _capture_case(
		"10_static_terrain_restored", size, room, [water_cell],
		"Terrain statique restauré\nZéro nœud dynamique résiduel"
	)

	await _capture_studio_preview(size, room, target)
	_apply_terrain_spell(terrain, FIREBALL, fire_cells, mage)
	await _capture_case(
		"12_direct_test_runtime", size, room, fire_cells,
		"Tester direct · scène runtime réelle\nMême service, couche et caméra"
	)
	_apply_terrain_spell(terrain, FIREBALL, fire_cells, mage)
	await _wait_frames(2)
	await _capture_case(
		"13_integrated_true_run", size, room, fire_cells,
		"Run principale intégrée · salle 0\nBoule de feu réelle · 9 surfaces lave"
	)
	var fingerprint_after := RoomDataSnapshotService.room_fingerprint(room)
	if fingerprint_before != fingerprint_after:
		_fail("canonical_fingerprint_changed_%dx%d" % [size.x, size.y])
	await _destroy_battle()


func _create_integrated_battle() -> Dictionary:
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=create_battle_cleanup")
	await _destroy_battle()
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=create_battle_prepare_run")
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		RUN, GameManager.PRODUCTION_HERO_DATA_PATHS
	):
		return {"ok": false, "error": "run_prepare_failed"}
	GameManager.current_room_index = 0
	get_tree().set_meta(&"arena_studio_test_options", TEST_OPTIONS.duplicate(true))
	var room := GameManager.get_current_room() as ArenaDefinition
	if room == null or room.battle_scene == null:
		return {"ok": false, "error": "integrated_room_missing"}
	_battle = room.battle_scene.instantiate()
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=create_battle_instantiated")
	add_child(_battle)
	move_child(_battle, 0)
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=create_battle_added")
	await _wait_frames(14)
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=create_battle_frames_ready")
	var grid := _battle.get("grid") as GridData
	var caster := _battle.get("spell_caster") as SpellCaster
	var terrain := _battle.get("terrain_effects") as TerrainEffects
	var mage := _find_mage(grid)
	if grid == null or caster == null or terrain == null or mage == null:
		return {"ok": false, "error": "battle_runtime_missing"}
	var target := _find_full_target(caster, mage, FIREBALL, terrain)
	if target == Vector2i(-1, -1):
		return {"ok": false, "error": "full_fireball_cross_missing"}
	return {
		"ok": true,
		"room": room,
		"grid": grid,
		"caster": caster,
		"terrain": terrain,
		"mage": mage,
		"target": target,
	}


func _capture_studio_preview(
		size: Vector2i,
		room: ArenaDefinition,
		target: Vector2i
	) -> void:
	if _battle is CanvasItem:
		(_battle as CanvasItem).visible = false
	var studio := ArenaStudioMain.new()
	studio.name = "DynamicTerrainCaptureStudio"
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(studio)
	move_child(_overlay_layer, get_child_count() - 1)
	await _wait_frames(12)
	studio._set_arena(room, false, "dynamic_terrain_capture")
	studio.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
	studio.runtime_preview.rebuild_now()
	studio.runtime_preview.simulate_terrain_spell(
		FIREBALL, target, load("res://data/units/alliés/mage.tres")
	)
	await _wait_frames(8)
	var cells := studio.runtime_preview.runtime_state.terrain_effects.active_surface_cells()
	await _capture_case(
		"11_studio_exact_preview", size, room, cells,
		"Arena Studio · APERÇU RUNTIME EXACT\nVraie Spell · durée 3 · working copy inchangée",
		studio.runtime_preview.runtime_state.terrain_effects,
		studio.runtime_preview.dynamic_surface_visuals
	)
	studio.queue_free()
	await _wait_frames(3)
	if _battle is CanvasItem:
		(_battle as CanvasItem).visible = true


func _capture_case(
		case_name: String,
		size: Vector2i,
		room: ArenaDefinition,
		cells: Array,
		title: String,
		metric_terrain: TerrainEffects = null,
		metric_adapter = null
	) -> void:
	var terrain := metric_terrain
	if terrain == null and is_instance_valid(_battle):
		terrain = _battle.get("terrain_effects") as TerrainEffects
	var adapter = metric_adapter
	if adapter == null and is_instance_valid(_battle):
		adapter = _battle.get("terrain_surface_visual_adapter")
	var active_cells: Array = terrain.active_surface_cells() \
		if terrain != null else cells
	var rendered_cells: Array = adapter.rendered_cells() \
		if adapter != null else []
	var expected_cells := _cell_keys(cells)
	var active_keys := _cell_keys(active_cells)
	var rendered_keys := _cell_keys(rendered_cells)
	var expected_render_cells: Array = []
	if terrain != null:
		for active_cell in active_cells:
			if terrain.get_visual_terrain_id(active_cell) != &"":
				expected_render_cells.append(active_cell)
	var expected_render_keys := _cell_keys(expected_render_cells)
	var missing := _difference(expected_render_keys, rendered_keys)
	var unexpected := _difference(rendered_keys, expected_render_keys)
	_overlay_label.text = (
		"DYNAMIC TERRAIN TILE REPLACEMENT · WORKTREE_CANDIDATE\n%s\n"
		+ "Attendu=%d · Actif=%d · Rendu=%d · Manquantes=%d · Inattendues=%d"
	) % [
		title, expected_cells.size(), active_keys.size(), rendered_keys.size(),
		missing.size(), unexpected.size(),
	]
	_overlay.visible = true
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file_name := "%s_%dx%d.png" % [case_name, size.x, size.y]
	print("DYNAMIC_TERRAIN_CAPTURE_PROGRESS=save:", file_name)
	var path := OUTPUT.path_join(file_name)
	var ok := image != null and not image.is_empty() \
		and image.save_png(ProjectSettings.globalize_path(path)) == OK
	if not ok:
		_fail("capture_failed:%s" % file_name)
	(_metrics.captures as Array).append({
		"case": case_name,
		"resolution": [size.x, size.y],
		"path": path,
		"ok": ok,
		"expected_cells": expected_cells,
		"expected_render_cells": expected_render_keys,
		"active_cells": active_keys,
		"rendered_cells": rendered_keys,
		"missing_cells": missing,
		"unexpected_cells": unexpected,
		"room_fingerprint": RoomDataSnapshotService.room_fingerprint(room),
	})


func _apply_terrain_spell(
		terrain: TerrainEffects,
		spell: Spell,
		cells: Array,
		mage: Unit
	) -> void:
	for cell in cells:
		terrain.place_effect(cell, spell.terrain_effect, mage, spell)


func _find_mage(grid: GridData) -> Unit:
	if grid == null:
		return null
	for value in grid.get_units():
		var unit := value as Unit
		if unit != null and StringName(unit.unit_id) == &"mage":
			return unit
	return null


func _find_full_target(
		caster: SpellCaster,
		mage: Unit,
		spell: Spell,
		terrain: TerrainEffects
	) -> Vector2i:
	for value in caster.get_targetable_cells(mage, spell):
		var cell := value as Vector2i
		var affected := caster.get_aoe_cells(spell, cell, mage.grid_pos)
		if affected.size() != 1 + spell.aoe_size * 4:
			continue
		var all_eligible := true
		for affected_cell in affected:
			if not terrain.can_receive_surface(
				affected_cell, spell.terrain_effect
			):
				all_eligible = false
				break
		if all_eligible:
			return cell
	return Vector2i(-1, -1)


func _find_remote_surface_cell(
		terrain: TerrainEffects,
		origin: Vector2i
	) -> Vector2i:
	var selected := origin
	var best_distance := -1
	for cell in terrain.runtime_service.state_cells():
		if not terrain.can_receive_surface(cell, WATER):
			continue
		if terrain.runtime_service.grid.get_unit(cell) != null:
			continue
		var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
		if distance > best_distance:
			best_distance = distance
			selected = cell
	return selected


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "DynamicTerrainCaptureOverlayLayer"
	_overlay_layer.layer = 100
	add_child(_overlay_layer)
	_overlay = PanelContainer.new()
	_overlay.name = "DynamicTerrainCaptureDiagnostic"
	_overlay.position = Vector2(18, 18)
	_overlay.custom_minimum_size = Vector2(560, 88)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_overlay)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 17)
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("shadow_offset_x", 2)
	_overlay_label.add_theme_constant_override("shadow_offset_y", 2)
	_overlay.add_child(_overlay_label)


func _destroy_battle() -> void:
	if is_instance_valid(_battle):
		_battle.queue_free()
		await _wait_frames(3)
	_battle = null
	if get_tree().has_meta(&"arena_studio_test_options"):
		get_tree().remove_meta(&"arena_studio_test_options")
	GameManager.cleanup_run_state()


func _write_report() -> void:
	var file := FileAccess.open(OUTPUT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if file == null:
		_fail("capture_metrics_write_failed")
		return
	file.store_string(JSON.stringify(_metrics, "  "))
	file.close()


func _cell_keys(cells: Array) -> Array[String]:
	var keys: Array[String] = []
	for value in cells:
		if value is Vector2i:
			var cell := value as Vector2i
			keys.append("%d,%d" % [cell.x, cell.y])
	keys.sort()
	return keys


func _difference(first: Array, second: Array) -> Array[String]:
	var result: Array[String] = []
	for value in first:
		if not second.has(value):
			result.append(str(value))
	return result


func _fail(message: String) -> void:
	(_metrics.failures as Array).append(message)
	push_error(message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame
