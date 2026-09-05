extends Node

const BATTLE_SCRIPT := "res://tools/labs/greek_drawn_arena/greek_drawn_battle.gd"
const OUTPUT := "res://artifacts/arena_dofus_greece_2026-09-05/runtime"
const STONE := "res://tools/labs/dynamic_arena/assets/normalized/stone.png"
const TERRAIN_SUPPORT_CHECKS := preload("res://tools/labs/greek_drawn_arena/greek_terrain_support_checks.gd")
const COMBAT_BAND_CHECKS := preload("res://tools/labs/greek_drawn_arena/greek_combat_band_checks.gd")
const TERRAIN_MATERIAL_CHECKS := preload("res://tools/labs/greek_drawn_arena/greek_terrain_material_checks.gd")
const GEOMETRY_CHECKS := preload("res://tools/labs/greek_drawn_arena/greek_geometry_checks.gd")
const INTERACTION_CHECKS := preload("res://tools/labs/greek_drawn_arena/greek_interaction_checks.gd")
var capture_enabled := true
var quit_after_capture := true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle: Node = null
	for _frame in range(600):
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and candidate.get_script() != null \
				and candidate.get_script().resource_path == BATTLE_SCRIPT \
				and bool(candidate.get("runtime_ready_state")):
			battle = candidate
			break
	if battle == null:
		_finish({"ok": false, "error": "real_battle_timeout"})
		return
	for _frame in range(24):
		await get_tree().process_frame
	var deployment := battle.get("_deployment") as DeploymentController
	if deployment != null and deployment.is_active():
		var deploy_grid := battle.get("grid") as GridData
		var deploy_room := battle.get("room_data") as ArenaDefinition
		for spawn: Vector2i in deploy_room.hero_spawn_zone:
			if not deployment.is_active():
				break
			if deploy_grid.is_walkable(spawn) and not deploy_grid.has_unit(spawn):
				deployment.on_cell_clicked(spawn)
	# Wait for real presentation time, then explicitly observe the banner rather
	# than assuming a fixed number of frames means its tween has completed.
	await get_tree().create_timer(3.0).timeout
	var hud_port = battle.get("_hud_port")
	var banner: Control = hud_port.get_turn_intro_banner() as Control if hud_port != null else null
	var banner_deadline := Time.get_ticks_msec() + 4000
	while is_instance_valid(banner) and banner.visible and Time.get_ticks_msec() < banner_deadline:
		await get_tree().process_frame
	var arena := battle.get("room_data") as ArenaDefinition
	var grid := battle.get("grid") as GridData
	var pathfinder := battle.get("pathfinder") as Pathfinder
	var grid_view := battle.get("grid_view") as Node2D
	var assembly: Dictionary = battle.get("arena_assembly")
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var errors: Array[String] = []
	if is_instance_valid(banner) and banner.visible:
		errors.append("turn_intro_banner_still_visible")
	if arena == null or grid == null or pathfinder == null or grid_view == null or renderer == null:
		_finish({"ok": false, "error": "production_system_missing"})
		return
	var actual := renderer.actual_render_report()
	var stone_count := 0
	for cell_data in actual.get("cells", {}).values():
		if str(cell_data.get("texture_path", "")) == STONE:
			stone_count += 1
	var expected_floor_count := 0
	for definition in arena.cells:
		if definition != null and definition.defined and definition.cell_type != GridData.CellType.HOLE:
			expected_floor_count += 1
	if stone_count != expected_floor_count:
		errors.append("source_stone_count_%d_expected_%d" % [stone_count, expected_floor_count])
	if int(battle.get_meta("greek_limestone_tile_count", 0)) != expected_floor_count:
		errors.append("local_palette_not_applied_to_every_tile")
	var geometry_report := GEOMETRY_CHECKS.run(battle, arena, grid, grid_view, renderer)
	errors.append_array(geometry_report.errors)
	var terrain_support_report := TERRAIN_SUPPORT_CHECKS.run(battle, arena, grid_view, renderer)
	errors.append_array(terrain_support_report.errors)
	var terrain_material_report := TERRAIN_MATERIAL_CHECKS.run(battle, arena, renderer)
	errors.append_array(terrain_material_report.errors)
	var combat_band_report := COMBAT_BAND_CHECKS.run(battle, arena, renderer)
	errors.append_array(combat_band_report.errors)
	var void_count := int(geometry_report.void_cells)
	for obstacle in arena.obstacles:
		if grid.is_walkable(obstacle.cell):
			errors.append("obstacle_walkable:%s" % obstacle.cell)
		if obstacle.blocks_line_of_sight and grid.is_transparent(obstacle.cell):
			errors.append("column_does_not_block_sight")
	var units: Array = battle.get("units")
	var hero: Unit = null
	var allies := 0
	var enemies := 0
	var illegal_unit_cells := 0
	for unit_value in units:
		var unit := unit_value as Unit
		if unit == null:
			continue
		if unit.team == 0:
			allies += 1
			hero = unit
		else:
			enemies += 1
		var unit_cell := grid.find_unit(unit)
		if not grid.is_valid(unit_cell) or not grid.is_walkable(unit_cell, unit):
			illegal_unit_cells += 1
	if allies != 1 or enemies != 2 or illegal_unit_cells != 0:
		errors.append("unit_deployment_invalid:%d_allies_%d_enemies_%d_illegal" % [allies,enemies,illegal_unit_cells])
	var hero_spell_ids: Array[String] = []
	var route: Array = []
	if hero != null:
		for spell_value in hero.spells:
			var spell := spell_value as Spell
			if spell != null:
				hero_spell_ids.append(str(spell.get_effective_spell_id()))
		route = GEOMETRY_CHECKS.farthest_walkable_route(grid, pathfinder, hero)
	if hero_spell_ids.size() != 4:
		errors.append("canonical_achilles_requires_four_disciplines")
	if route.is_empty():
		errors.append("cross_arena_route_missing")
	for step in route:
		if not grid.is_walkable(step, hero):
			errors.append("route_crosses_blocker:%s" % step)
	var visual_report := assembly.get("report") as ArenaVisualAssemblyReport
	if visual_report == null or not visual_report.valid:
		errors.append("real_assembly_report_invalid")
	var valid_drawn_props := 0
	for prop_value in assembly.get("decorations", []):
		var prop := prop_value as Node2D
		if prop == null or prop.get_script() == null \
				or not prop.get_script().can_instantiate() \
				or not bool(prop.get_meta(&"greek_prop_ready", false)) \
				or int(prop.get_meta(&"greek_prop_draw_count", 0)) < 1:
			errors.append("original_prop_script_or_drawing_missing:%s" % str(prop))
		else:
			valid_drawn_props += 1
	if assembly.get("decorations", []).size() != arena.decorations.size() or valid_drawn_props != arena.decorations.size():
		errors.append("drawn_props_count_%d_expected_%d" % [valid_drawn_props, arena.decorations.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var captures: Array[String] = []
	var capture_size := Vector2i.ZERO
	if capture_enabled:
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		if screenshot != null:
			capture_size = Vector2i(screenshot.get_width(), screenshot.get_height())
		var capture_path := OUTPUT.path_join("combat_%dx%d.png" % [capture_size.x, capture_size.y])
		if screenshot == null or screenshot.is_empty() or screenshot.save_png(ProjectSettings.globalize_path(capture_path)) != OK:
			errors.append("combat_capture_failed")
		else:
			captures.append(capture_path)
	if capture_enabled:
		var terrain := battle.get_node_or_null("GreekTerrainComposition")
		if terrain != null:
			terrain.set_world_decor_visible(false)
			for prop: Node2D in assembly.get("decorations", []):
				prop.visible = false
			var terrain_capture := await _capture_image("diagnostic_terrain_without_decor", errors)
			if not terrain_capture.is_empty():
				captures.append(terrain_capture)
			terrain.set_world_decor_visible(true)
			for prop: Node2D in assembly.get("decorations", []):
				prop.visible = true
		var old_grid_lines: bool = grid_view.get("draw_grid_lines")
		grid_view.set("draw_grid_lines", true)
		grid_view.queue_redraw()
		var diagnostic := await _capture_image("diagnostic_grid", errors)
		if not diagnostic.is_empty():
			captures.append(diagnostic)
		grid_view.set("draw_grid_lines", old_grid_lines)
		grid_view.queue_redraw()
		battle._on_move_pressed()
		var movement_overlay := await _capture_image("diagnostic_move_range", errors)
		if not movement_overlay.is_empty():
			captures.append(movement_overlay)
		battle._on_move_pressed()
	var interaction_probe := INTERACTION_CHECKS.new()
	add_child(interaction_probe)
	var interaction_report: Dictionary = await interaction_probe.run(battle, hero, grid, pathfinder, grid_view, renderer)
	errors.append_array(interaction_report.errors)
	interaction_probe.queue_free()
	if capture_enabled:
		var action_capture := await _capture_image("proof_after_move_guard", errors)
		if not action_capture.is_empty():
			captures.append(action_capture)
	var result := {
		"ok": errors.is_empty(), "errors": errors,
		"actual_scene": battle.scene_file_path,
		"actual_script": battle.get_script().resource_path,
		"arena_id": str(arena.arena_id),
		"grid_size": [grid.cols,grid.rows],
		"stone_source_texture": STONE,
		"rendered_source_stone_tiles": stone_count,
		"expected_floor_cells_from_arena": expected_floor_count,
		"local_palette_tiles": int(battle.get_meta("greek_limestone_tile_count",0)), "fractional_rendering_enabled": bool(battle.get_meta("greek_fractional_rendering",false)),
		"void_cells_verified": void_count,
		"geometry_measurements": geometry_report,
		"terrain_support": terrain_support_report, "ground_details": battle.get_meta("greek_ground_details", {}),
		"terrain_materials": terrain_material_report,
		"combat_ground_band": combat_band_report,
		"real_player_interaction": interaction_report,
		"primary_screenshot_phase": "deployed combat before validation actions",
		"blocking_cells": arena.obstacles.size(),
		"y_sorted_prop_sections": assembly.get("decorations",[]).size(),
		"original_props_drawn": valid_drawn_props,
		"allies": allies, "enemies": enemies,
		"achilles_equipped_spell_ids": hero_spell_ids,
		"turn_banner_hidden": not is_instance_valid(banner) or not banner.visible,
		"cross_arena_route_length": route.size(),
		"real_assembly_valid": visual_report.valid if visual_report != null else false,
		"viewport_size": [get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],
		"screenshots": captures,
		"captured_image_size": [capture_size.x,capture_size.y],
	}
	_finish(result)

func _finish(result: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var payload := JSON.stringify(result, "  ")
	var report_paths: Array[String] = [OUTPUT.path_join("runtime_validation.json")]
	var viewport: Array = result.get("viewport_size", [])
	if viewport.size() >= 2:
		report_paths.append(OUTPUT.path_join("runtime_validation_%dx%d.json" % [
			int(viewport[0]), int(viewport[1]),
		]))
	for report_path in report_paths:
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(payload)
			file.close()
	print("GREEK_DRAWN_ARENA_VALIDATION ",JSON.stringify(result))
	if quit_after_capture:
		get_tree().quit(0 if bool(result.get("ok",false)) else 1)
	else:
		queue_free()





func _capture_image(prefix: String, errors: Array[String]) -> String:
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		errors.append("capture_empty:%s" % prefix)
		return ""
	var path := OUTPUT.path_join("%s_%dx%d.png" % [prefix, screenshot.get_width(), screenshot.get_height()])
	if screenshot.save_png(ProjectSettings.globalize_path(path)) != OK:
		errors.append("capture_save_failed:%s" % prefix)
		return ""
	return path
