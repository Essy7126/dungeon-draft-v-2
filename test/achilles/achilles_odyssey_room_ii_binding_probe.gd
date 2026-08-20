extends SceneTree

const RUN_PATH := "res://data/runs/odyssey.tres"
const ACHILLES_DATA_PATH := "res://data/units/allies/achilles.tres"
const RESOLVER_PATH := "res://core/run_content/run_hero_resolver.gd"
const ROOM_INDEX := 1
const WINDOW_SIZE := Vector2i(1600, 1000)
const SETTLE_FRAME_COUNT := 12
const LEGACY_VISUAL_PATH := (
	"res://assets/characters/Achilles/AchillesVisual2D.tscn"
)
const ADAPTER_PATH := "res://characters/achilles/AchillesIsoUnitView.tscn"
const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const VIEWPORT_BACKEND_PATH := (
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)
const CHARACTER_3D_PATH := (
	"res://characters/achilles/3d/Achilles3DVisual.tscn"
)
const CHARACTER_GLB_PATH := (
	"res://assets/characters/Achilles/3d/achilles_rig_v1.glb"
)

var _artifact_dir := ""
var _phase := "before"
var _expected_body := "LEGACY_2D"
var _reported_project_path := ""
var _reported_head := ""
var _classification := ""
var _actual_project_path := ""
var _actual_head := ""
var _actual_git_root := ""
var _actual_git_status := ""
var _failures: Array[String] = []
var _capture_records: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_artifact_dir = _argument_value("--artifact-dir=")
	_phase = _argument_value("--phase=")
	_expected_body = _argument_value("--expected-body=")
	_reported_project_path = _argument_value("--project-path=")
	_reported_head = _argument_value("--project-head=").to_lower()
	_classification = _argument_value("--classification=")
	_actual_project_path = ProjectSettings.globalize_path("res://").trim_suffix("/")
	_actual_head = _derive_git_head(_actual_project_path)
	_actual_git_root = _derive_git_value(
		_actual_project_path, PackedStringArray(["rev-parse", "--show-toplevel"])
	)
	_actual_git_status = _derive_git_value(
		_actual_project_path, PackedStringArray(["status", "--porcelain"])
	)
	var version_info := Engine.get_version_info()
	if (
		int(version_info.get("major", 0)) != 4
		or int(version_info.get("minor", 0)) != 7
		or int(version_info.get("patch", 0)) != 1
		or String(version_info.get("status", "")) != "stable"
	):
		_fail("The runtime must use Godot 4.7.1 stable")
	if _classification != "WRONG_WORKTREE_OR_PROJECT_LAUNCHED":
		_fail("The verified classification must be WRONG_WORKTREE_OR_PROJECT_LAUNCHED")
	if _phase not in ["before", "after"]:
		_fail("--phase must be before or after")
	if _expected_body not in ["LEGACY_2D", "VIEWPORT_3D"]:
		_fail("--expected-body must be LEGACY_2D or VIEWPORT_3D")
	if _reported_project_path.is_empty():
		_fail("An explicit --project-path is required")
	elif _normalize_path(_actual_project_path) != _normalize_path(
			_reported_project_path
		):
		_fail("The runtime project path does not match --project-path")
	if not _is_full_git_sha(_reported_head):
		_fail("A full 40-character --project-head is required")
	if _actual_head.is_empty():
		_fail("The runtime project HEAD could not be derived with Git")
	elif _actual_head != _reported_head:
		_fail("The runtime project HEAD does not match --project-head")
	if _normalize_path(_actual_git_root) != _normalize_path(_actual_project_path):
		_fail("The runtime project is not the root of the reported Git worktree")
	if not _actual_git_status.is_empty():
		_fail("The runtime worktree is dirty; HEAD cannot identify the executed code")
	if _artifact_dir.is_empty() or not _artifact_dir.is_absolute_path():
		_fail("An absolute --artifact-dir is required")
		_finish_without_runtime()
		return
	if DirAccess.make_dir_recursive_absolute(_artifact_dir) != OK:
		_fail("The artifact directory could not be created")
		_finish_without_runtime()
		return

	root.size = WINDOW_SIZE
	RenderingServer.set_default_clear_color(Color(0.018, 0.023, 0.034, 1.0))
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		_fail("The real GameManager autoload is missing")
		_finish_without_runtime()
		return
	manager.call("cleanup_run_state")

	var run_data = load(RUN_PATH)
	var resolver = load(RESOLVER_PATH)
	if run_data == null or resolver == null:
		_fail("The real Odyssey RunData or RunHeroResolver could not be loaded")
		_finish_without_runtime()
		return
	var resolution = resolver.call("resolve_runtime_hero_data", run_data, false)
	if resolution == null or not resolution.call("is_valid") \
			or resolution.get("heroes").size() != 1:
		_fail("The real Odyssey resolver did not produce exactly one hero")
		_finish_without_runtime()
		return
	var hero_sources: Array = resolution.get("heroes")
	var hero_data = hero_sources[0]
	var resolved_base_unit_data_path := ""
	var hero_profiles: Array = resolution.get("hero_profiles")
	if hero_profiles.size() == 1 and hero_profiles[0] != null:
		var base_unit_data = hero_profiles[0].get("base_unit_data")
		if base_unit_data != null:
			resolved_base_unit_data_path = String(base_unit_data.resource_path)
	if resolved_base_unit_data_path != ACHILLES_DATA_PATH:
		_fail("Odyssey did not resolve the canonical Achilles UnitData")
	if not manager.call("_prepare_preconfigured_run", run_data, hero_sources):
		_fail("The real Odyssey RunData could not be prepared")
		_finish_without_runtime()
		return

	manager.set("current_room_index", ROOM_INDEX)
	var rooms: Array = run_data.get("rooms")
	if rooms.size() <= ROOM_INDEX:
		_fail("Odyssey room II is missing")
		_finish_without_runtime()
		return
	var room = rooms[ROOM_INDEX]
	var battle_scene = room.get("battle_scene")
	if battle_scene == null:
		_fail("Odyssey room II has no production Battle scene")
		_finish_without_runtime()
		return
	var battle = battle_scene.instantiate()
	root.add_child(battle)
	await _settle(SETTLE_FRAME_COUNT)

	var grid = battle.get("grid")
	var deployment = battle.get("_deployment")
	if grid == null or deployment == null or not deployment.call("is_active"):
		_fail("The production Battle did not enter deployment")
		await _cleanup(battle, manager)
		_finish_without_runtime()
		return
	var deployment_cell := _first_legal_spawn(room.get("hero_spawn_zone"), grid)
	if deployment_cell == Vector2i(-1, -1):
		_fail("No legal Achilles deployment cell exists in room II")
		await _cleanup(battle, manager)
		_finish_without_runtime()
		return
	deployment.call("on_cell_clicked", deployment_cell)
	await _settle(SETTLE_FRAME_COUNT)

	var runtime := await _find_achilles_runtime(battle)
	var hero = runtime.get("hero")
	var unit_view = runtime.get("unit_view")
	var adapter = runtime.get("adapter")
	if hero == null or unit_view == null or adapter == null:
		_fail("The production Battle did not instantiate AchillesIsoUnitView")
		await _cleanup(battle, manager)
		_finish_without_runtime()
		return
	if adapter.has_method("configure_runtime_diagnostics"):
		adapter.call(
			"configure_runtime_diagnostics", true, room.resource_path,
			_actual_head
		)

	await _wait_for_turn_banner(battle)
	await _settle(4)
	var visual_nodes := _collect_visual_nodes(adapter)
	var backend_state := _inspect_backend_state(adapter, visual_nodes)
	if _phase == "after":
		_validate_after_fix_state(backend_state, room.resource_path)
	var resource_paths := _collect_resource_paths(
		run_data, room, hero_data, battle, unit_view, adapter
	)
	var tree_text := _build_scene_tree_text(battle)
	var base_name := "room_ii_before_fix" if _phase == "before" \
		else "room_ii_after_fix"
	var full_capture := await _capture_full(base_name + ".png")
	var closeup_capture := _capture_closeup(
		base_name + "_closeup.png", full_capture.get("image"), unit_view
	)
	full_capture.erase("image")
	closeup_capture.erase("image")
	_capture_records.append(full_capture)
	_capture_records.append(closeup_capture)

	var actual_project_file := ProjectSettings.globalize_path("res://project.godot")
	var observation_matches: bool = (
		(_expected_body == "LEGACY_2D" and backend_state.legacy_body_visible)
		or (
			_expected_body == "VIEWPORT_3D"
			and _after_fix_binding_is_valid(backend_state)
		)
	)
	if not observation_matches:
		_fail("The observed gameplay body did not match --expected-body")

	var report := {
		"schema": "dd.achilles.odyssey-room-ii-binding-probe.v1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"phase": _phase,
		"classification": _classification,
		"expected_body": _expected_body,
		"observation_matches_expected": observation_matches,
		"process": {
			"executable": OS.get_executable_path(),
			"command_line": OS.get_cmdline_args(),
			"actual_project_path": _actual_project_path,
			"actual_project_file": actual_project_file,
			"reported_project_path": _reported_project_path,
			"project_path_matches_reported": (
				_normalize_path(_actual_project_path)
				== _normalize_path(_reported_project_path)
			),
			"reported_head": _reported_head,
			"actual_head": _actual_head,
			"head_matches_reported": _actual_head == _reported_head,
			"actual_git_root": _actual_git_root,
			"worktree_porcelain": _actual_git_status,
			"worktree_clean": _actual_git_status.is_empty(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(),
			"godot_version": version_info,
		},
		"runtime": {
			"run_path": run_data.resource_path,
			"room_index": ROOM_INDEX,
			"room_id": room.resource_path,
			"room_name": room.get("room_name"),
			"battle_scene": battle_scene.resource_path,
			"hero_id": String(hero.get("unit_id")),
			"hero_data_path": resolved_base_unit_data_path,
			"resolved_visual_scene": (
				hero_data.get("visual_scene").resource_path
				if hero_data.get("visual_scene") != null else ""
			),
			"adapter_scene_file_path": adapter.scene_file_path,
			"adapter_script": _script_record(adapter),
			"deployment_cell": [deployment_cell.x, deployment_cell.y],
		},
		"backend": backend_state,
		"captures": _capture_records,
		"failures": _failures,
	}

	var suffix := "before_fix" if _phase == "before" else "after_fix"
	_write_text(
		_artifact_dir.path_join("runtime_scene_tree_%s.txt" % suffix),
		tree_text
	)
	_write_json(
		_artifact_dir.path_join("runtime_visual_nodes_%s.json" % suffix),
		{"phase": _phase, "nodes": visual_nodes}
	)
	_write_json(
		_artifact_dir.path_join("loaded_resource_paths_%s.json" % suffix),
		{"phase": _phase, "resources": resource_paths}
	)
	var backend_file := (
		"backend_selection_before_fix.json"
		if _phase == "before" else "visual_backend_state_after_fix.json"
	)
	_write_json(_artifact_dir.path_join(backend_file), backend_state)
	if _phase == "before":
		_write_json(
			_artifact_dir.path_join("fallback_reason_before_fix.json"),
			{
				"fallback_active": backend_state.fallback_active,
				"reason": backend_state.fallback_reason,
				"direct_legacy_binding": backend_state.direct_legacy_binding,
			}
		)
		_write_text(
			_artifact_dir.path_join("reproduction_report.md"),
			_build_reproduction_report(report)
		)
	else:
		_write_text(
			_artifact_dir.path_join("comparison_before_after.md"),
			_build_after_summary(report)
		)
	_write_json(
		_artifact_dir.path_join("room_ii_binding_probe_%s.json" % suffix),
		report
	)

	await _cleanup(battle, manager)
	print("ACHILLES_ROOM_II_BINDING_PROBE=" + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _find_achilles_runtime(battle) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		var units: Array = battle.get("units")
		var views: Dictionary = battle.get("_unit_views")
		for unit in units:
			if unit != null and int(unit.get("team")) == 0 \
					and String(unit.get("unit_id")) == "achilles":
				var unit_view = views.get(unit)
				var adapter = (
					unit_view.call("get_optional_visual")
					if unit_view != null
						and unit_view.has_method("get_optional_visual")
					else null
				)
				if adapter != null:
					await _settle(6)
					return {
						"hero": unit,
						"unit_view": unit_view,
						"adapter": adapter,
					}
		await process_frame
	return {}


func _inspect_backend_state(adapter, visual_nodes: Array[Dictionary]) -> Dictionary:
	var profile = adapter.get("visual_profile") if _has_property(adapter, "visual_profile") \
		else null
	var raw_requested := ""
	var character_scene_path := ""
	var character_asset_path := ""
	if profile != null:
		raw_requested = String(profile.get("rendering_mode"))
		character_asset_path = String(profile.get("character_asset_path"))
		var character_scene = profile.get("character_scene")
		character_scene_path = (
			character_scene.resource_path if character_scene != null else ""
		)
	var direct_legacy_binding: bool = not adapter.has_method(
		"get_active_backend_name"
	)
	var raw_active := (
		String(adapter.call("get_active_backend_name"))
		if adapter.has_method("get_active_backend_name") else "Legacy2DDirect"
	)
	var requested_backend := (
		"VIEWPORT_3D"
		if "SUBVIEWPORT" in raw_requested or "VIEWPORT_3D" in raw_requested
		else "LEGACY_2D"
	)
	var active_backend := "INITIALIZING"
	if "Viewport3D" in raw_active:
		active_backend = "VIEWPORT_3D"
	elif "Legacy2D" in raw_active or direct_legacy_binding:
		active_backend = "LEGACY_2D"
	var fallback_reason: Variant = {}
	if adapter.has_method("get_last_backend_error"):
		fallback_reason = adapter.call("get_last_backend_error")
	var fallback_active: bool = false
	var structured_runtime_state: Dictionary = {}
	if adapter.has_method("get_visual_runtime_state"):
		structured_runtime_state = adapter.call("get_visual_runtime_state")
		fallback_active = bool(structured_runtime_state.get(
			"ACHILLES_VISUAL_FALLBACK_ACTIVE", false
		))
	elif not direct_legacy_binding:
		fallback_active = active_backend != requested_backend
	var legacy_visible := false
	var legacy_processing := false
	var animated_sprite_count := 0
	var subviewport_count := 0
	var skeleton_count := 0
	var mesh_count := 0
	var visible_mesh_count := 0
	var rendered_sprite_uses_viewport_texture := false
	var rendered_sprite_visible := false
	var viewport_texture_valid := false
	var background_transparent := false
	var character_inside_camera_frame := false
	var camera_count := 0
	var current_camera_count := 0
	var equipment_node_count := 0
	var subviewport_path := ""
	var skeleton_path := ""
	var rendered_sprite_path := ""
	var instantiated_character_asset_path := ""
	var canonical_character_asset_instance_count := 0
	for record in visual_nodes:
		var searchable := (
			String(record.path) + " " + String(record.name)
		).to_lower()
		if _contains_equipment_token(searchable):
			equipment_node_count += 1
		if record.class == "AnimatedSprite2D":
			animated_sprite_count += 1
			legacy_visible = legacy_visible or bool(record.visible_in_tree)
			legacy_processing = legacy_processing or bool(record.can_process)
		elif record.class == "SubViewport":
			subviewport_count += 1
			if subviewport_path.is_empty():
				subviewport_path = record.path
			viewport_texture_valid = viewport_texture_valid \
				or bool(record.get("viewport_texture_valid", false))
			background_transparent = background_transparent \
				or bool(record.get("background_transparent", false))
			character_inside_camera_frame = character_inside_camera_frame \
				or bool(record.get("character_inside_camera_frame", false))
		elif record.class == "Camera3D":
			camera_count += 1
			if bool(record.get("camera_current", false)):
				current_camera_count += 1
		elif record.class == "Skeleton3D":
			skeleton_count += 1
			if skeleton_path.is_empty():
				skeleton_path = record.path
		elif record.class == "MeshInstance3D":
			mesh_count += 1
			if bool(record.visible_in_tree):
				visible_mesh_count += 1
		if bool(record.get("uses_viewport_texture", false)):
			rendered_sprite_uses_viewport_texture = true
			rendered_sprite_visible = bool(record.visible_in_tree)
			rendered_sprite_path = record.path
		if String(record.get("scene_file_path", "")) == CHARACTER_GLB_PATH:
			canonical_character_asset_instance_count += 1
			instantiated_character_asset_path = CHARACTER_GLB_PATH
	var foot_anchor_error_pixels := 1000000000.0
	var backend = adapter.get("viewport_backend") \
		if _has_property(adapter, "viewport_backend") else null
	if backend != null and backend.has_method("get_projected_foot_pixel"):
		var sprite = backend.get("rendered_sprite")
		if sprite is Sprite2D:
			var projected_foot: Vector2 = backend.call(
				"get_projected_foot_pixel"
			)
			foot_anchor_error_pixels = (
				sprite.position + projected_foot * sprite.scale
			).length()
	return {
		"requested_backend": requested_backend,
		"requested_backend_raw": raw_requested,
		"active_backend": active_backend,
		"active_backend_raw": raw_active,
		"fallback_active": fallback_active,
		"fallback_reason": fallback_reason,
		"direct_legacy_binding": direct_legacy_binding,
		"character_scene_path": character_scene_path,
		"character_asset_path": character_asset_path,
		"canonical_character_asset_cached": ResourceLoader.has_cached(
			CHARACTER_GLB_PATH
		),
		"instantiated_character_asset_path": instantiated_character_asset_path,
		"canonical_character_asset_instance_count": (
			canonical_character_asset_instance_count
		),
		"legacy_body_visible": legacy_visible,
		"legacy_body_processing": legacy_processing,
		"legacy_animated_sprite_count": animated_sprite_count,
		"subviewport_count": subviewport_count,
		"subviewport_path": subviewport_path,
		"viewport_texture_valid": viewport_texture_valid,
		"rendered_sprite_uses_viewport_texture": (
			rendered_sprite_uses_viewport_texture
		),
		"rendered_sprite_visible": rendered_sprite_visible,
		"rendered_sprite_path": rendered_sprite_path,
		"camera_count": camera_count,
		"current_camera_count": current_camera_count,
		"background_transparent": background_transparent,
		"character_inside_camera_frame": character_inside_camera_frame,
		"foot_anchor_error_pixels": foot_anchor_error_pixels,
		"foot_anchor_aligned": foot_anchor_error_pixels <= 1.0,
		"skeleton_count": skeleton_count,
		"skeleton_path": skeleton_path,
		"mesh_count": mesh_count,
		"visible_mesh_count": visible_mesh_count,
		"equipment_node_count": equipment_node_count,
		"adapter_visible": adapter.visible if adapter is CanvasItem else true,
		"adapter_modulate_alpha": (
			adapter.modulate.a if adapter is CanvasItem else 1.0
		),
		"structured_runtime_state": structured_runtime_state,
	}


func _validate_after_fix_state(state: Dictionary, room_path: String) -> void:
	var structured: Dictionary = state.get("structured_runtime_state", {})
	var checks := {
		"requested_backend_is_viewport_3d": state.requested_backend == "VIEWPORT_3D",
		"active_backend_is_viewport_3d": state.active_backend == "VIEWPORT_3D",
		"fallback_is_inactive": not bool(state.fallback_active),
		"fallback_was_never_activated": Dictionary(
			state.get("fallback_reason", {})
		).is_empty(),
		"legacy_body_is_not_visible": not bool(state.legacy_body_visible),
		"legacy_body_is_not_processing": not bool(state.legacy_body_processing),
		"legacy_body_is_not_instantiated": int(state.legacy_animated_sprite_count) == 0,
		"exactly_one_subviewport": int(state.subviewport_count) == 1,
		"exactly_one_current_camera": (
			int(state.camera_count) == 1 and int(state.current_camera_count) == 1
		),
		"viewport_texture_has_visible_alpha": bool(state.viewport_texture_valid),
		"rendered_sprite_uses_viewport_texture": bool(
			state.rendered_sprite_uses_viewport_texture
		),
		"rendered_sprite_is_visible": bool(state.rendered_sprite_visible),
		"transparent_background_is_preserved": bool(state.background_transparent),
		"character_is_inside_camera_frame": bool(
			state.character_inside_camera_frame
		),
		"foot_anchor_is_aligned": bool(state.foot_anchor_aligned),
		"exactly_one_skeleton": int(state.skeleton_count) == 1,
		"character_mesh_is_visible": int(state.visible_mesh_count) >= 1,
		"no_equipment_node_is_instantiated": int(state.equipment_node_count) == 0,
		"canonical_character_asset_is_selected": (
			String(state.character_asset_path) == CHARACTER_GLB_PATH
		),
		"canonical_character_asset_is_loaded": bool(
			state.instantiated_character_asset_path == CHARACTER_GLB_PATH
			and int(state.canonical_character_asset_instance_count) == 1
		),
		"structured_requested_matches": String(structured.get(
			"ACHILLES_VISUAL_BACKEND_REQUESTED", ""
		)) == "VIEWPORT_3D",
		"structured_active_matches": String(structured.get(
			"ACHILLES_VISUAL_BACKEND_ACTIVE", ""
		)) == "VIEWPORT_3D",
		"structured_fallback_is_false": not bool(structured.get(
			"ACHILLES_VISUAL_FALLBACK_ACTIVE", true
		)),
		"structured_viewport_texture_is_valid": bool(structured.get(
			"ACHILLES_VIEWPORT_TEXTURE_VALID", false
		)),
		"structured_character_scene_matches": String(structured.get(
			"ACHILLES_CHARACTER_SCENE_PATH", ""
		)) == CHARACTER_3D_PATH,
		"structured_skeleton_path_matches": (
			not String(state.skeleton_path).is_empty()
			and String(structured.get("ACHILLES_SKELETON_PATH", ""))
				== String(state.skeleton_path)
		),
		"structured_subviewport_path_matches": (
			not String(state.subviewport_path).is_empty()
			and String(structured.get("ACHILLES_SUBVIEWPORT_PATH", ""))
				== String(state.subviewport_path)
		),
		"structured_room_matches": String(structured.get(
			"ACHILLES_ROOM_ID", ""
		)) == room_path,
		"structured_legacy_body_is_hidden": not bool(structured.get(
			"ACHILLES_LEGACY_BODY_VISIBLE", true
		)),
		"structured_head_matches_git": String(structured.get(
			"commit", ""
		)).to_lower() == _actual_head,
		"adapter_is_visible": bool(state.adapter_visible),
		"adapter_alpha_is_visible": float(state.adapter_modulate_alpha) > 0.01,
	}
	for check_name in checks:
		if not bool(checks[check_name]):
			_fail("After-fix runtime invariant failed: %s" % check_name)


func _after_fix_binding_is_valid(state: Dictionary) -> bool:
	return (
		state.requested_backend == "VIEWPORT_3D"
		and state.active_backend == "VIEWPORT_3D"
		and not state.fallback_active
		and Dictionary(state.get("fallback_reason", {})).is_empty()
		and not state.legacy_body_visible
		and not state.legacy_body_processing
		and state.legacy_animated_sprite_count == 0
		and state.subviewport_count == 1
		and state.camera_count == 1
		and state.current_camera_count == 1
		and state.viewport_texture_valid
		and state.rendered_sprite_uses_viewport_texture
		and state.rendered_sprite_visible
		and state.character_inside_camera_frame
		and state.background_transparent
		and state.foot_anchor_aligned
		and state.skeleton_count == 1
		and state.visible_mesh_count >= 1
		and state.equipment_node_count == 0
		and state.character_asset_path == CHARACTER_GLB_PATH
		and state.instantiated_character_asset_path == CHARACTER_GLB_PATH
		and state.canonical_character_asset_instance_count == 1
		and state.adapter_visible
		and state.adapter_modulate_alpha > 0.01
	)


func _collect_visual_nodes(adapter) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var nodes: Array[Node] = [adapter]
	nodes.append_array(adapter.find_children("*", "Node", true, false))
	for node in nodes:
		var record := {
			"path": String(node.get_path()),
			"name": String(node.name),
			"class": node.get_class(),
			"scene_file_path": node.scene_file_path,
			"script": _script_record(node),
			"process_mode": node.process_mode,
			"can_process": node.can_process(),
			"visible": true,
			"visible_in_tree": true,
			"modulate_alpha": 1.0,
			"self_modulate_alpha": 1.0,
			"z_index": 0,
		}
		if node is CanvasItem:
			record.visible = node.visible
			record.visible_in_tree = node.is_visible_in_tree()
			record.modulate_alpha = node.modulate.a
			record.self_modulate_alpha = node.self_modulate.a
			record.z_index = node.z_index
		elif node is Node3D:
			record.visible = node.visible
			record.visible_in_tree = node.is_visible_in_tree()
		if node is Sprite2D:
			record["texture_class"] = (
				node.texture.get_class() if node.texture != null else ""
			)
			record["texture_path"] = (
				node.texture.resource_path if node.texture != null else ""
			)
			record["uses_viewport_texture"] = node.texture is ViewportTexture
		if node is AnimatedSprite2D:
			record["animation"] = String(node.animation)
			record["frame"] = node.frame
		if node is SubViewport:
			var texture: Texture2D = node.get_texture()
			var image: Image = texture.get_image() if texture != null else null
			var alpha_bounds := _visible_alpha_bounds(image)
			record["viewport_size"] = [node.size.x, node.size.y]
			record["transparent_bg"] = node.transparent_bg
			record["viewport_texture_valid"] = (
				texture != null and image != null and not image.is_empty()
				and alpha_bounds.size.x > 0 and alpha_bounds.size.y > 0
			)
			record["visible_alpha_bounds"] = [
				alpha_bounds.position.x, alpha_bounds.position.y,
				alpha_bounds.size.x, alpha_bounds.size.y,
			]
			record["background_transparent"] = (
				node.transparent_bg and _image_corners_are_transparent(image)
			)
			record["character_inside_camera_frame"] = (
				_alpha_bounds_are_inside_frame(alpha_bounds, node.size)
			)
		if node is Camera3D:
			record["camera_current"] = node.current
			record["camera_projection"] = node.projection
		if node is Skeleton3D:
			record["bone_count"] = node.get_bone_count()
		if node is MeshInstance3D:
			record["mesh_present"] = node.mesh != null
		result.append(record)
	return result


func _collect_resource_paths(
		run_data,
		room,
		hero_data,
		battle,
		unit_view,
		adapter
	) -> Array[Dictionary]:
	var paths: Dictionary = {}
	_add_resource_path(paths, RUN_PATH, "RUN_DATA")
	var resolved_base_unit_data_path := ""
	var content_profile = run_data.get("content_profile")
	if content_profile != null:
		var hero_profiles: Array = content_profile.get("hero_profiles")
		if hero_profiles.size() == 1 and hero_profiles[0] != null:
			var base_unit_data = hero_profiles[0].get("base_unit_data")
			if base_unit_data != null:
				resolved_base_unit_data_path = String(base_unit_data.resource_path)
	_add_resource_path(
		paths, resolved_base_unit_data_path, "RESOLVED_ACHILLES_UNIT_DATA"
	)
	_add_resource_path(paths, room.resource_path, "ROOM_DATA")
	_add_resource_path(paths, room.get("battle_scene").resource_path, "BATTLE_SCENE")
	_add_resource_path(paths, ADAPTER_PATH, "ACHILLES_ISO_VIEW")
	if run_data.get("content_profile") != null:
		_add_resource_path(
			paths, run_data.get("content_profile").resource_path, "RUN_CONTENT_PROFILE"
		)
	if hero_data.get("visual_scene") != null:
		_add_resource_path(
			paths, hero_data.get("visual_scene").resource_path,
			"RESOLVED_VISUAL_SCENE"
		)
	for known_path in [
		LEGACY_VISUAL_PATH, PROFILE_PATH, VIEWPORT_BACKEND_PATH,
		CHARACTER_3D_PATH, CHARACTER_GLB_PATH,
	]:
		_add_resource_path(paths, known_path, "KNOWN_ACHILLES_RESOURCE")
	var nodes: Array[Node] = [battle, unit_view, adapter]
	nodes.append_array(battle.find_children("*", "Node", true, false))
	for node in nodes:
		if not node.scene_file_path.is_empty():
			_add_resource_path(paths, node.scene_file_path, "INSTANTIATED_SCENE")
		var script = node.get_script()
		if script != null and not script.resource_path.is_empty():
			_add_resource_path(paths, script.resource_path, "INSTANTIATED_SCRIPT")
	var result: Array[Dictionary] = []
	for path in paths:
		var record: Dictionary = paths[path]
		record["cached"] = ResourceLoader.has_cached(path)
		result.append(record)
	result.sort_custom(func(a, b): return a.path < b.path)
	return result


func _add_resource_path(paths: Dictionary, path: String, role: String) -> void:
	if path.is_empty():
		return
	if not paths.has(path):
		paths[path] = {
			"path": path,
			"roles": [],
			"exists": ResourceLoader.exists(path),
		}
	var roles: Array = paths[path].roles
	if not roles.has(role):
		roles.append(role)


func _build_scene_tree_text(root_node: Node) -> String:
	var lines: Array[String] = []
	_append_tree_lines(root_node, lines, 0)
	return "\n".join(lines) + "\n"


func _append_tree_lines(node: Node, lines: Array[String], depth: int) -> void:
	var script := _script_record(node)
	var details := ""
	if node is CanvasItem:
		details = " visible=%s effective=%s alpha=%.3f z=%d" % [
			str(node.visible), str(node.is_visible_in_tree()), node.modulate.a,
			node.z_index,
		]
	elif node is Node3D:
		details = " visible=%s effective=%s" % [
			str(node.visible), str(node.is_visible_in_tree()),
		]
	lines.append("%s%s <%s> script=%s scene=%s%s" % [
		"  ".repeat(depth), node.name, node.get_class(),
		script.path, node.scene_file_path, details,
	])
	for child in node.get_children():
		_append_tree_lines(child, lines, depth + 1)


func _script_record(node: Node) -> Dictionary:
	var script = node.get_script()
	if script == null:
		return {"path": "", "global_name": ""}
	return {
		"path": script.resource_path,
		"global_name": (
			String(script.get_global_name())
			if script.has_method("get_global_name") else ""
		),
	}


func _capture_full(file_name: String) -> Dictionary:
	await _settle(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _artifact_dir.path_join(file_name)
	var error := (
		image.save_png(path)
		if image != null and not image.is_empty() else ERR_CANT_CREATE
	)
	if error != OK:
		_fail("Full runtime capture failed")
	return {
		"file": file_name,
		"path": path,
		"save_error": error,
		"size": [image.get_width(), image.get_height()] if image != null else [0, 0],
		"sha256": FileAccess.get_sha256(path).to_upper() if error == OK else "",
		"image": image,
	}


func _capture_closeup(file_name: String, source: Image, unit_view) -> Dictionary:
	var path := _artifact_dir.path_join(file_name)
	if source == null or source.is_empty() or not unit_view is CanvasItem:
		_fail("The close-up source image or UnitView is missing")
		return {
			"file": file_name, "path": path, "save_error": ERR_CANT_CREATE,
			"size": [0, 0], "sha256": "", "image": null,
		}
	var center := Vector2i(unit_view.get_global_transform_with_canvas().origin.round())
	var crop_size := Vector2i(360, 360)
	var origin := center - crop_size / 2
	origin.x = clampi(origin.x, 0, maxi(0, source.get_width() - crop_size.x))
	origin.y = clampi(origin.y, 0, maxi(0, source.get_height() - crop_size.y))
	var region := source.get_region(Rect2i(origin, crop_size))
	region.resize(1080, 1080, Image.INTERPOLATE_LANCZOS)
	var error := region.save_png(path)
	if error != OK:
		_fail("The Achilles close-up could not be saved")
	return {
		"file": file_name,
		"path": path,
		"save_error": error,
		"source_rect": [origin.x, origin.y, crop_size.x, crop_size.y],
		"size": [region.get_width(), region.get_height()],
		"sha256": FileAccess.get_sha256(path).to_upper() if error == OK else "",
		"image": region,
	}


func _build_reproduction_report(report: Dictionary) -> String:
	return "\n".join([
		"# Reproduction du binding Achille — salle II avant correction",
		"",
		"- Classification : `%s`" % _classification,
		"- Projet réellement exécuté : `%s`" % report.process.actual_project_path,
		"- HEAD relevé avant lancement : `%s`" % _reported_head,
		"- RunData : `%s`" % report.runtime.run_path,
		"- Salle : `%s`" % report.runtime.room_id,
		"- Scène visuelle résolue : `%s`" % report.runtime.resolved_visual_scene,
		"- Backend demandé : `%s`" % report.backend.requested_backend,
		"- Backend actif : `%s`" % report.backend.active_backend,
		"- Corps 2D visible : `%s`" % str(report.backend.legacy_body_visible),
		"- SubViewport : `%d`" % report.backend.subviewport_count,
		"- Skeleton3D : `%d`" % report.backend.skeleton_count,
		"",
		"Le checkout lancé lie directement `AchillesVisual2D` dans la façade ",
		"gameplay. Le corps 2D observé est donc reproduit depuis la vraie ",
		"RunData et la vraie scène Battle de la salle II.",
		"",
	])


func _build_after_summary(report: Dictionary) -> String:
	return "\n".join([
		"# Salle II — état runtime après correction",
		"",
		"- Projet : `%s`" % report.process.actual_project_path,
		"- HEAD : `%s`" % _reported_head,
		"- Backend demandé : `%s`" % report.backend.requested_backend,
		"- Backend actif : `%s`" % report.backend.active_backend,
		"- Fallback actif : `%s`" % str(report.backend.fallback_active),
		"- Texture de viewport valide : `%s`" % str(
			report.backend.viewport_texture_valid
		),
		"- Corps 2D visible : `%s`" % str(report.backend.legacy_body_visible),
		"- Skeleton3D : `%d`" % report.backend.skeleton_count,
		"",
	])


func _first_legal_spawn(cells: Array, grid) -> Vector2i:
	for cell in cells:
		if grid.call("is_valid", cell) and grid.call("is_walkable", cell) \
				and not grid.call("has_unit", cell):
			return cell
	return Vector2i(-1, -1)


func _wait_for_turn_banner(battle) -> void:
	var action_bar = battle.get("action_bar")
	if action_bar == null or not action_bar.has_method("get_turn_intro_banner"):
		await create_timer(2.2).timeout
		return
	var banner = action_bar.call("get_turn_intro_banner")
	var deadline := Time.get_ticks_msec() + 4000
	while banner != null and banner.visible and Time.get_ticks_msec() < deadline:
		await process_frame


func _visible_alpha_bounds(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _image_corners_are_transparent(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
	for point in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
		if image.get_pixelv(point).a > 0.02:
			return false
	return true


func _alpha_bounds_are_inside_frame(
		bounds: Rect2i,
		viewport_size: Vector2i
	) -> bool:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return false
	var end := bounds.end
	return (
		bounds.position.x > 1
		and bounds.position.y > 1
		and end.x < viewport_size.x - 1
		and end.y <= viewport_size.y
	)


func _contains_equipment_token(value: String) -> bool:
	for token in [
		"weapon", "equipment", "sword", "shield", "bow",
		"epee", "épée", "bouclier", "arc",
	]:
		if token in value:
			return true
	return false


func _derive_git_head(project_path: String) -> String:
	return _derive_git_value(
		project_path, PackedStringArray(["rev-parse", "HEAD"])
	).to_lower()


func _derive_git_value(
		project_path: String,
		arguments: PackedStringArray
	) -> String:
	var output: Array = []
	var git_arguments := PackedStringArray(["-C", project_path])
	git_arguments.append_array(arguments)
	var exit_code := OS.execute(
		"git",
		git_arguments,
		output,
		true
	)
	if exit_code != 0 or output.is_empty():
		return ""
	return "\n".join(PackedStringArray(output)).strip_edges()


func _is_full_git_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.name) == property_name:
			return true
	return false


func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value, "  ", false) + "\n")


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write artifact: %s" % path)
		return
	file.store_string(value)
	file.close()


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame


func _cleanup(battle, manager) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	await _settle(8)
	manager.call("cleanup_run_state")


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
	push_error("ACHILLES ROOM II BINDING PROBE: %s" % message)


func _finish_without_runtime() -> void:
	if not _artifact_dir.is_empty() and _artifact_dir.is_absolute_path():
		_write_json(
			_artifact_dir.path_join("room_ii_binding_probe_early_failure.json"),
			{"status": "FAIL", "failures": _failures}
		)
	quit(1)
