extends Node

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const UNIT_VIEW_SCENE: PackedScene = preload("res://battle/unit_view.tscn")
const ROOM_INDEX := 1
const WINDOW_SIZE := Vector2i(1600, 1000)
const REVIEW_SCALE := 4.5
const RESOLUTIONS := [256, 384, 512]
const FACINGS := {
	"N": Vector2i.UP,
	"E": Vector2i.RIGHT,
	"S": Vector2i.DOWN,
	"W": Vector2i.LEFT,
}

var _artifact_dir := ""
var _capture_dir := ""
var _report := {
	"schema": "dd.achilles.room-ii-character-visual-smoke.v1",
	"status": "FAIL",
	"base_sha": "2d99ea4137ba1893e486b3ff1e39a73e66d0a469",
	"evidence_head": "2d99ea4137ba1893e486b3ff1e39a73e66d0a469",
	"final_head_pending": true,
	"run_path": "res://data/runs/odyssey.tres",
	"room_index_zero_based": ROOM_INDEX,
	"room_path": "",
	"character_only": true,
	"weapon_runtime_integration": false,
	"checks": {},
	"orientations": [],
	"resolutions": [],
	"spell_visuals": [],
	"captures": [],
	"not_measured": {
		"normal_menu_return_path": {
			"status": "NOT_MEASURED",
			"reason": "This development smoke frees its stage and run state; it does not load the normal menu scene.",
		},
		"normal_room_reload_flow": {
			"status": "NOT_MEASURED",
			"reason": "Only the UnitView/optional visual is recreated; RoomData, the stage and the normal room flow are not reloaded.",
		},
		"selection_and_click_flow": {"status": "NOT_MEASURED"},
		"target_selection_flow": {"status": "NOT_MEASURED"},
		"end_turn_flow": {"status": "NOT_MEASURED"},
		"room_change_stability": {
			"status": "PAUSED_OWNER_GATE_ROOM_II_ONLY",
		},
	},
	"compliance_findings": {
		"canonical_3d_weapon_content": "NONE_OBSERVED",
		"legacy_2d_fallback_visual": "LEGACY_2D_BAKED_WEAPON_PIXELS_OBSERVED",
		"classification": "LEGACY_2D_FALLBACK_WEAPON_VISUAL_DIVERGENCE",
		"global_no_weapon_requirement": "BLOCKED",
		"separate_weapon_runtime_instance": false,
		"owner_review_required": true,
		"no_weapon_claim_scope": "CANONICAL_3D_SUBVIEWPORT_ONLY",
	},
	"failures": [],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_artifact_dir = _argument_value("--artifact-dir=")
	var evidence_head := _argument_value("--evidence-head=").to_lower()
	if evidence_head.length() == 40 and evidence_head.is_valid_hex_number(false):
		_report.evidence_head = evidence_head
		_report.final_head_pending = false
		_report["evidence_head_source"] = "EXPLICIT_POST_COMMIT_ARGUMENT"
	if _artifact_dir.is_empty() or not _artifact_dir.is_absolute_path():
		_fail("An absolute --artifact-dir is required; no res:// output is allowed.")
		_finish()
		return
	_capture_dir = _artifact_dir.path_join("captures")
	if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
		_fail("Cannot create the external capture directory.")
		_finish()
		return

	get_window().size = WINDOW_SIZE
	RenderingServer.set_default_clear_color(Color(0.025, 0.03, 0.045, 1.0))
	GameManager.cleanup_run_state()
	var resolution = RunHeroResolver.resolve_runtime_hero_data(RUN, false)
	if resolution == null or not resolution.is_valid() or resolution.heroes.size() != 1:
		_fail("RunHeroResolver did not produce exactly one runtime Achilles.")
		_finish()
		return
	if not GameManager._prepare_preconfigured_run(RUN, resolution.heroes):
		_fail("The real Odyssey RunData could not be prepared.")
		_finish()
		return
	GameManager.current_room_index = ROOM_INDEX
	var room: RoomData = RUN.rooms[ROOM_INDEX]
	_report.room_path = room.resource_path
	_report["room_name"] = room.room_name
	_report["room_resource_sha256"] = FileAccess.get_sha256(room.resource_path).to_upper()
	var grid: GridData = EncounterGridFactory.build_from_room(room)
	if grid == null:
		_fail("Room II GridData could not be built from the real RoomData.")
		_finish()
		return

	var stage := Node2D.new()
	stage.name = "RoomIIReviewStage"
	add_child(stage)
	var visual: PaintedMapVisualData = room.painted_map_visual_data
	var background_texture := visual.load_background_texture()
	if background_texture == null:
		_fail("Room II background texture could not be loaded.")
		stage.queue_free()
		_finish()
		return
	var background := Sprite2D.new()
	background.name = "RoomIIBackground"
	background.centered = false
	background.texture = background_texture
	background.position = visual.image_offset
	background.scale = visual.image_scale
	background.z_index = -100
	stage.add_child(background)
	var grid_view := PaintedGridView.new()
	grid_view.name = "RoomIIGrid"
	grid_view.configure(visual, room.grid_layout, room.hero_spawn_zone, room.enemy_spawn_zone)
	grid_view.setup(grid)
	grid_view.set_render_options(false, true, false, false)
	stage.add_child(grid_view)

	var map_size := Vector2(visual.source_image_size) * visual.image_scale
	var room_scale := minf(
		float(WINDOW_SIZE.x - 40) / maxf(map_size.x, 1.0),
		float(WINDOW_SIZE.y - 40) / maxf(map_size.y, 1.0)
	)
	stage.scale = Vector2.ONE * room_scale
	stage.position = (Vector2(WINDOW_SIZE) - map_size * room_scale) * 0.5

	var runtime_data: UnitData = resolution.heroes[0]
	var achilles := Unit.from_data(runtime_data)
	achilles.start_turn()
	var spawn_cell: Vector2i = _first_legal_spawn(room.hero_spawn_zone, grid)
	if spawn_cell == Vector2i(-1, -1) or not grid.place_unit(achilles, spawn_cell):
		_fail("No legal Room II hero spawn could place Achilles.")
		stage.queue_free()
		_finish()
		return
	var unit_view = await _create_unit_view(stage, achilles, visual, spawn_cell)
	if unit_view == null:
		stage.queue_free()
		_finish()
		return
	var adapter := unit_view.get_optional_visual() as AchillesIsoUnitView
	var backend := adapter.viewport_backend
	var visual_3d := backend.get_achilles_visual()
	var gameplay_parent_position: Vector2 = unit_view.position
	var baseline_stats := {
		"hp": achilles.current_hp,
		"ap": achilles.current_ap,
		"mp": achilles.current_mp,
		"cell": [achilles.grid_pos.x, achilles.grid_pos.y],
	}

	var skeletons := adapter.find_children("*", "Skeleton3D", true, false)
	var subviewports := adapter.find_children("*", "SubViewport", true, false)
	var collision_nodes := adapter.find_children("*", "CollisionObject3D", true, false)
	var forbidden_nodes := _forbidden_named_nodes(adapter)
	_report.checks = {
		"real_run_data": RUN.resource_path == "res://data/runs/odyssey.tres",
		"room_ii_only": GameManager.current_room_index == ROOM_INDEX,
		"room_is_arena_definition": room is ArenaDefinition,
		"single_runtime_hero": resolution.heroes.size() == 1 and achilles.unit_id == &"achilles",
		"single_runtime_skeleton": skeletons.size() == 1,
		"single_subviewport": subviewports.size() == 1,
		"character_mesh_visible": visual_3d != null and not visual_3d.get_mesh_instances().is_empty(),
		"character_material_visible": visual_3d != null and visual_3d.has_visible_character_materials(),
		"no_collision_object_3d": collision_nodes.is_empty(),
		"no_forbidden_equipment_node": forbidden_nodes.is_empty(),
		"equipment_disabled": adapter.visual_profile != null and not adapter.visual_profile.equipment_enabled,
		"weapon_profile_null": adapter.visual_profile != null and adapter.visual_profile.weapon_profile == null,
		"viewport_backend_active": adapter.get_active_backend_name() == &"Viewport3DBackend",
		"no_legacy_2d_loaded": adapter.find_children(
			"*", "AchillesVisual2D", true, false
		).is_empty(),
		"fallback_backend_invisible": not adapter.fallback_backend.visible,
		"transparent_background_property": backend.character_viewport.transparent_bg,
		"gameplay_parent_position_before_actions": [gameplay_parent_position.x, gameplay_parent_position.y],
		"baseline_stats": baseline_stats,
	}
	for check_name in _report.checks:
		if _report.checks[check_name] is bool and not bool(_report.checks[check_name]):
			_fail("Structural check failed: %s" % check_name)

	await _capture("room_ii_full_384.png")
	var viewport_image := backend.character_viewport.get_texture().get_image()
	var corner_alpha := viewport_image.get_pixel(0, 0).a if viewport_image != null and not viewport_image.is_empty() else 1.0
	_report.checks["transparent_background_corner_alpha"] = corner_alpha <= 0.001
	_report["capture_notes"] = {
		"room_ii_full_384.png": "Real UnitView overlays remain visible for context.",
		"review_closeups": "Existing HP/shield/status overlays are hidden only in close-up evidence so they do not mask the SubViewport image.",
	}
	_set_unit_overlays_visible(unit_view, false)
	var original_stage_scale: Vector2 = stage.scale
	var original_stage_position: Vector2 = stage.position
	_focus_stage_on(stage, unit_view.position)
	var review_player: AnimationPlayer = visual_3d.get_animation_player()
	var review_action := StringName(
		adapter.visual_profile.animation_profile.IDLE.get("godot_name", "")
	)
	var review_sample_seconds := 0.0
	if review_player != null and review_player.has_animation(review_action):
		var review_animation := review_player.get_animation(review_action)
		review_sample_seconds = review_animation.length * 0.5
		review_player.play(review_action)
		review_player.seek(review_sample_seconds, true)
		review_player.advance(0.0)
		review_player.speed_scale = 0.0
	_report["resolution_review_pose"] = {
		"source_action": String(review_action),
		"godot_action": String(review_action),
		"sample_seconds": review_sample_seconds,
		"fixed_across_resolutions": true,
	}
	for viewport_resolution in RESOLUTIONS:
		var resolution_started := Time.get_ticks_usec()
		var accepted: bool = backend.set_viewport_resolution(viewport_resolution)
		await _settle(5)
		var capture_record: Dictionary = await _capture(
			"room_ii_achilles_%d.png" % viewport_resolution
		)
		_report.resolutions.append({
			"resolution": viewport_resolution,
			"accepted": accepted,
			"settle_elapsed_usec": Time.get_ticks_usec() - resolution_started,
			"capture": capture_record,
		})
		if not accepted:
			_fail("Backend rejected supported resolution %d." % viewport_resolution)
	backend.set_viewport_resolution(384)

	var character_transform_before_facings: Transform3D = visual_3d.character_asset.transform
	for facing_name in FACINGS:
		adapter.set_facing(FACINGS[facing_name])
		await _settle(3)
		var yaw := visual_3d.character_asset.rotation_degrees.y
		var facing_capture: Dictionary = await _capture(
			"room_ii_facing_%s.png" % facing_name.to_lower()
		)
		_report.orientations.append({
			"direction": facing_name,
			"yaw_degrees": yaw,
			"capture": facing_capture,
		})
	var unique_yaws := {}
	for orientation in _report.orientations:
		unique_yaws[snappedf(float(orientation.yaw_degrees), 0.001)] = true
	_report.checks["four_distinct_internal_yaws"] = unique_yaws.size() == 4
	_report.checks["character_internal_transform_only"] = (
		unit_view.position == gameplay_parent_position
		and stage.scale == Vector2.ONE * REVIEW_SCALE
		and character_transform_before_facings.origin == visual_3d.character_asset.transform.origin
	)
	if unique_yaws.size() != 4:
		_fail("The four cardinal facings did not produce four distinct internal yaws.")
	if review_player != null:
		review_player.speed_scale = 1.0
		adapter.play_idle()
		await _settle(2)

	var event_counts := {"release": 0, "finish": 0}
	adapter.cast_release_reached.connect(func() -> void: event_counts.release += 1)
	adapter.animation_finished.connect(func(_name: StringName) -> void: event_counts.finish += 1)
	var target_cell := _adjacent_legal_cell(achilles.grid_pos, grid)
	for spell in runtime_data.spells:
		var release_before: int = event_counts.release
		var finish_before: int = event_counts.finish
		var action_parent_before: Vector2 = unit_view.position
		var released: bool = await unit_view.prepare_spell_visual(target_cell, spell)
		var action_capture: Dictionary = await _capture(
			"room_ii_action_%s.png" % String(spell.get_effective_spell_id())
		)
		await unit_view.wait_for_action_visual_finished(5000)
		var action_record := {
			"spell_path": spell.resource_path,
			"spell_id": String(spell.get_effective_spell_id()),
			"visual_semantic": "ACTION_FALLBACK",
			"released": released,
			"release_count": event_counts.release - release_before,
			"finish_count": event_counts.finish - finish_before,
			"gameplay_parent_unchanged": unit_view.position == action_parent_before,
			"ap_unchanged": achilles.current_ap == baseline_stats.ap,
			"mp_unchanged": achilles.current_mp == baseline_stats.mp,
			"hp_unchanged": achilles.current_hp == baseline_stats.hp,
			"capture": action_capture,
		}
		_report.spell_visuals.append(action_record)
		if not released or action_record.release_count != 1 \
				or action_record.finish_count != 1 \
				or not action_record.gameplay_parent_unchanged:
			_fail("Visual release/finish/root isolation failed for %s." % action_record.spell_id)

	var move_destination := _adjacent_legal_cell(achilles.grid_pos, grid)
	var pathfinder := Pathfinder.new(grid)
	var movement_path: Array = pathfinder.find_path(
		achilles.grid_pos, move_destination, achilles
	)
	var movement_from := achilles.grid_pos
	var movement_parent_before: Vector2 = unit_view.position
	unit_view.begin_movement_feedback(movement_from, move_destination)
	if movement_path.size() >= 2 and grid.relocate_unit(achilles, move_destination):
		var move_tween := create_tween()
		move_tween.tween_property(
			unit_view, "position", visual.cell_to_display(move_destination), 0.35
		)
		await move_tween.finished
	unit_view.end_movement_feedback()
	await _settle(4)
	_report.checks["movement_path_nonempty"] = movement_path.size() >= 2
	_report.checks["movement_cell_updated"] = achilles.grid_pos == move_destination
	_report.checks["movement_visual_parent_moved"] = unit_view.position != movement_parent_before
	_report.checks["movement_preserved_ap_mp"] = (
		achilles.current_ap == baseline_stats.ap and achilles.current_mp == baseline_stats.mp
	)
	await _capture("room_ii_after_movement.png")

	var hp_before_damage: int = achilles.current_hp
	achilles.take_damage(7)
	await _settle(4)
	_report.checks["damage_received"] = achilles.current_hp < hp_before_damage
	await _capture("room_ii_after_damage.png")
	achilles.heal(hp_before_damage - achilles.current_hp)
	await _settle(2)

	var old_adapter_ref: WeakRef = weakref(adapter)
	unit_view.queue_free()
	await _settle(5)
	unit_view = await _create_unit_view(stage, achilles, visual, achilles.grid_pos)
	if unit_view == null:
		_fail("Room II visual reload failed.")
		stage.queue_free()
		_finish()
		return
	adapter = unit_view.get_optional_visual() as AchillesIsoUnitView
	backend = adapter.viewport_backend
	_set_unit_overlays_visible(unit_view, false)
	_report.checks["visual_instance_reload_old_adapter_released"] = old_adapter_ref.get_ref() == null
	_report.checks["visual_instance_reload_single_optional_visual"] = _count_descendants_of_type(stage, "AchillesIsoUnitView") == 1
	_report.checks["visual_instance_reload_single_subviewport"] = adapter.find_children("*", "SubViewport", true, false).size() == 1
	_focus_stage_on(stage, unit_view.position)
	await _capture("room_ii_after_reload.png")

	adapter.force_safe_fallback(&"ROOM_II_SMOKE_FORCED_FALLBACK")
	await _settle(4)
	_report.checks["forced_fallback_active"] = adapter.get_active_backend_name() == &"NoVisualFallbackBackend"
	_report.checks["forced_fallback_never_double_visible"] = (
		not adapter.fallback_backend.visible and not adapter.viewport_backend.visible
	)
	await _capture("room_ii_forced_no_visual_fallback.png")

	var viewport_ref: WeakRef = weakref(adapter.viewport_backend.character_viewport)
	stage.scale = original_stage_scale
	stage.position = original_stage_position
	stage.queue_free()
	await _settle(6)
	_report.checks["cleanup_released_subviewport"] = viewport_ref.get_ref() == null
	_report.checks["development_tool_cleanup_completed"] = true
	GameManager.cleanup_run_state()
	for check_name in _report.checks:
		if _report.checks[check_name] is bool and not bool(_report.checks[check_name]):
			_fail("Final check failed: %s" % check_name)
	_finish()


func _create_unit_view(
		stage: Node2D,
		achilles: Unit,
		visual: PaintedMapVisualData,
		cell: Vector2i
	):
	var unit_view = UNIT_VIEW_SCENE.instantiate()
	stage.add_child(unit_view)
	unit_view.setup(achilles)
	unit_view.position = visual.cell_to_display(cell)
	unit_view.set_active(true)
	if visual.presentation_profile != null:
		unit_view.apply_painted_presentation(visual.presentation_profile)
	var adapter := unit_view.get_optional_visual() as AchillesIsoUnitView
	if adapter == null:
		_fail("AchillesIsoUnitView was not instantiated by the real UnitView.")
		unit_view.queue_free()
		await _settle(2)
		return null
	var deadline := Time.get_ticks_msec() + 8000
	while adapter.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if adapter.get_active_backend_name() != &"Viewport3DBackend":
		_fail("The character-only SubViewport backend did not become ready: %s" % JSON.stringify(adapter.get_last_backend_error()))
		unit_view.queue_free()
		await _settle(2)
		return null
	await _settle(4)
	return unit_view


func _focus_stage_on(stage: Node2D, point: Vector2) -> void:
	stage.scale = Vector2.ONE * REVIEW_SCALE
	stage.position = Vector2(WINDOW_SIZE) * 0.5 - point * REVIEW_SCALE


func _set_unit_overlays_visible(unit_view: Node, overlays_visible: bool) -> void:
	for property_name in ["_hp_bar", "_shield_bar", "_status_row"]:
		var overlay := unit_view.get(property_name) as CanvasItem
		if overlay != null:
			overlay.visible = overlays_visible


func _first_legal_spawn(cells: Array[Vector2i], grid: GridData) -> Vector2i:
	for cell in cells:
		if grid.is_valid(cell) and grid.is_walkable(cell) and not grid.has_unit(cell):
			return cell
	return Vector2i(-1, -1)


func _adjacent_legal_cell(origin: Vector2i, grid: GridData) -> Vector2i:
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var candidate: Vector2i = origin + direction
		if grid.is_valid(candidate) and grid.is_walkable(candidate) and not grid.has_unit(candidate):
			return candidate
	return origin


func _forbidden_named_nodes(root_node: Node) -> Array[String]:
	var result: Array[String] = []
	var nodes: Array[Node] = [root_node]
	nodes.append_array(root_node.find_children("*", "Node", true, false))
	for node in nodes:
		var lowered := String(node.name).to_lower()
		for token in ["weapon", "sword", "blade", "shield", "bow", "quiver", "equipmentcontroller"]:
			if token in lowered:
				result.append(String(node.get_path()))
				break
	return result


func _count_descendants_of_type(root_node: Node, type_name: String) -> int:
	return root_node.find_children("*", type_name, true, false).size()


func _capture(file_name: String) -> Dictionary:
	await _settle(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _capture_dir.path_join(file_name)
	var save_error := image.save_png(path) if image != null and not image.is_empty() else ERR_CANT_CREATE
	var record := {
		"file": file_name,
		"path": path,
		"save_error": save_error,
		"size": [image.get_width(), image.get_height()] if image != null else [0, 0],
		"sha256": FileAccess.get_sha256(path).to_upper() if save_error == OK else "",
	}
	_report.captures.append(record)
	if save_error != OK:
		_fail("Capture failed: %s" % file_name)
	return record


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(message: String) -> void:
	_report.failures.append(message)
	push_error("ACHILLES ROOM II SMOKE: %s" % message)


func _finish() -> void:
	_report.status = "PASS" if _report.failures.is_empty() else "FAIL"
	if not _artifact_dir.is_empty() and _artifact_dir.is_absolute_path():
		var report_path := _artifact_dir.path_join("room_ii_smoke.json")
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(_report, "  ", false) + "\n")
			output.close()
	print("ACHILLES_ROOM_II_SMOKE=" + JSON.stringify(_report))
	get_tree().quit(0 if _report.status == "PASS" else 1)
