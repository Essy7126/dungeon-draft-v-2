extends GutTest

const FIX_BASE_SHA := "7bc3d69c0f434e8038bbb199300a96baae8443a4"
const RUN_PATH := "res://data/runs/odyssey.tres"
const ACHILLES_UNIT_PATH := "res://data/units/allies/achilles.tres"
const ADAPTER_PATH := "res://characters/achilles/AchillesIsoUnitView.tscn"
const BACKEND_PATH := (
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)
const VISUAL_PATH := "res://characters/achilles/3d/Achilles3DVisual.tscn"
const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile_v2.tres"
)
const HUD_THEME_PATH := "res://data/ui/achilles_hud_theme_refined.tres"
const PORTRAIT_PATH := (
	"res://assets/characters/Achilles/processed/idle_00.png"
)
const GLB_INSPECTION_PATH := (
	"res://assets/characters/Achilles/3d/character_glb_inspection.json"
)
const MISSING_CHARACTER_PATH := (
	"res://assets/characters/Achilles/3d/__binding_fix_missing__.glb"
)
const ROOM_II_INDEX := 1
const ROOM_II_PATH := "res://data/rooms/odyssey/room_02.tres"
const RUNTIME_READY_TIMEOUT_MSEC := 10000
const EXPECTED_PROJECT_PATH_ENV := "ACHILLES_FIX_EXPECTED_PROJECT_PATH"
const EXPECTED_HEAD_ENV := "ACHILLES_FIX_EXPECTED_HEAD"
const EXPECTED_SPELL_HASHES := {
	"res://data/spells/achilles/spear_thrust.tres": (
		"BEE399DFF7CDDBA27E84B27C2F2C5219E23D512902057F1ABDA68E3DE668CBA1"
	),
	"res://data/spells/achilles/advance.tres": (
		"059B37EC845BCB9835D7BF008506431E6C81E9D913B527B637B944793410446A"
	),
	"res://data/spells/achilles/sweep.tres": (
		"F80E9CA9A9769C81B873A03347545646899C000199F35DB4DC36003C738F1B67"
	),
	"res://data/spells/achilles/guard.tres": (
		"EE532DC126588D2580DD5D14E572C62B6DC58B9D1D96AE41AD35995BEE5887C7"
	),
}
const RUNTIME_DEPENDENCY_ROOTS: Array[String] = [
	ADAPTER_PATH,
	BACKEND_PATH,
	VISUAL_PATH,
	PROFILE_PATH,
]

const ODYSSEY_RUN: RunData = preload("res://data/runs/odyssey.tres")
const ADAPTER_SCENE: PackedScene = preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const BACKEND_SCENE: PackedScene = preload(
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)
const VISUAL_SCENE: PackedScene = preload(
	"res://characters/achilles/3d/Achilles3DVisual.tscn"
)
const UNIT_VIEW_SCENE: PackedScene = preload("res://battle/unit_view.tscn")


# Projet réellement lancé -----------------------------------------------------

func test_runtime_project_path_matches_worktree() -> void:
	var expected := _expected_project_path()
	var actual := _actual_project_path()
	assert_false(expected.is_empty(), "%s is required" % EXPECTED_PROJECT_PATH_ENV)
	assert_true(expected.is_absolute_path(), "Expected project path must be absolute")
	assert_eq(_normalize_path(actual), _normalize_path(expected))
	assert_true(FileAccess.file_exists(actual.path_join("project.godot")))


func test_runtime_head_matches_reported_head() -> void:
	var expected := _expected_head().to_lower()
	assert_eq(expected.length(), 40, "%s must be a full SHA" % EXPECTED_HEAD_ENV)
	assert_true(expected.is_valid_hex_number(false))
	var head := _git_value(PackedStringArray(["rev-parse", "HEAD"]))
	assert_eq(head.to_lower(), expected)
	var status := _git_value(PackedStringArray([
		"status", "--porcelain=v1", "--untracked-files=normal",
	]))
	assert_true(
		status.is_empty(),
		"The tested runtime must be represented by a clean reported HEAD: %s" % status,
	)


func test_no_other_checkout_is_used() -> void:
	var expected_path := _expected_project_path()
	var expected_head := _expected_head().to_lower()
	var top_level := _git_value(PackedStringArray(["rev-parse", "--show-toplevel"]))
	var head := _git_value(PackedStringArray(["rev-parse", "HEAD"]))
	assert_false(
		expected_path.is_empty(), "%s is required" % EXPECTED_PROJECT_PATH_ENV
	)
	assert_eq(_normalize_path(top_level), _normalize_path(_actual_project_path()))
	assert_eq(_normalize_path(top_level), _normalize_path(expected_path))
	assert_eq(head.to_lower(), expected_head)


# Chaîne de binding ----------------------------------------------------------

func test_odyssey_resolves_achilles_unit() -> void:
	assert_eq(ODYSSEY_RUN.resource_path, RUN_PATH)
	var resolution := _odyssey_resolution()
	assert_true(resolution.is_valid())
	assert_eq(resolution.heroes.size(), 1)
	assert_eq(resolution.hero_profiles.size(), 1)
	assert_not_null(resolution.hero_profiles[0].base_unit_data)
	assert_eq(
		resolution.hero_profiles[0].base_unit_data.resource_path,
		ACHILLES_UNIT_PATH,
	)
	assert_eq(resolution.heroes[0].get_effective_unit_id(), &"achilles")
	assert_eq(_room_ii().resource_path, ROOM_II_PATH)


func test_achilles_unit_resolves_iso_view() -> void:
	var hero_data := _odyssey_achilles_data()
	assert_not_null(hero_data)
	assert_not_null(hero_data.visual_scene)
	assert_eq(hero_data.visual_scene.resource_path, ADAPTER_PATH)
	var canonical_data := load(ACHILLES_UNIT_PATH) as UnitData
	assert_not_null(canonical_data)
	assert_eq(canonical_data.visual_scene.resource_path, ADAPTER_PATH)


func test_iso_view_requests_viewport_3d_backend() -> void:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	assert_not_null(adapter)
	assert_not_null(adapter.visual_profile)
	assert_eq(
		adapter.visual_profile.rendering_mode,
		AchillesVisualProfile.RENDERING_VIEWPORT_3D,
	)
	assert_eq(
		adapter.visual_profile.fallback_policy,
		AchillesVisualProfile.FALLBACK_POLICY_LEGACY_2D_ON_VERIFIED_ERROR,
	)
	assert_not_null(adapter.visual_profile.fallback_backend_scene)
	assert_eq(AchillesIsoUnitView.REQUESTED_BACKEND, &"VIEWPORT_3D")
	adapter.free()


func test_viewport_3d_backend_instantiates() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	assert_not_null(backend)
	add_child_autofree(backend)
	assert_not_null(backend.character_viewport)
	assert_not_null(backend.camera)
	assert_not_null(backend.rendered_sprite)


func test_achilles_3d_scene_instantiates() -> void:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	assert_not_null(visual)
	add_child_autofree(visual)
	assert_not_null(visual.character_asset)
	assert_not_null(visual.foot_marker)
	assert_true(visual.initialize_from_profile(_profile()))
	assert_eq(visual.character_asset.get_child_count(), 1)
	var model_root := visual.character_asset.get_child(0) as Node3D
	assert_not_null(model_root)
	assert_eq(model_root.scene_file_path, _profile().character_asset_path)


func test_skeleton_is_present() -> void:
	var visual := _create_initialized_visual()
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1)
	assert_not_null(visual.get_skeleton())
	assert_eq(visual.get_skeleton().get_bone_count(), 52)


func test_character_mesh_is_visible() -> void:
	var visual := _create_initialized_visual()
	var meshes := visual.get_mesh_instances()
	assert_gt(meshes.size(), 0)
	for mesh: MeshInstance3D in meshes:
		assert_not_null(mesh.mesh)
		assert_true(mesh.visible)
		assert_true(mesh.is_visible_in_tree())
	assert_true(visual.has_visible_character_materials())
	var adapter := await _create_ready_adapter()
	assert_true(adapter.visible)
	assert_true(adapter.is_visible_in_tree())
	assert_gt(adapter.modulate.a, 0.01)


# Visibilité -----------------------------------------------------------------

func test_legacy_body_is_not_visible_when_3d_succeeds() -> void:
	var adapter := await _create_ready_adapter()
	assert_null(adapter.fallback_backend)
	assert_true(adapter.find_children(
		"*", "AnimatedSprite2D", true, false
	).is_empty())
	var state := adapter.get_visual_runtime_state()
	assert_false(bool(state.get("ACHILLES_LEGACY_BODY_VISIBLE", true)))


func test_legacy_body_is_not_processing_when_3d_succeeds() -> void:
	var adapter := await _create_ready_adapter()
	assert_null(adapter.fallback_backend)
	var state := adapter.get_visual_runtime_state()
	assert_false(bool(state.get("ACHILLES_LEGACY_BODY_PROCESSING", true)))
	for node: Node in _all_nodes(adapter):
		if node is AnimatedSprite2D:
			assert_false(node.can_process())


func test_only_one_visual_backend_emits_action_signals() -> void:
	var adapter := await _create_ready_adapter()
	var counters := {"started": 0, "released": 0, "finished": 0}
	adapter.viewport_backend.action_started.connect(
		func(_action_name: StringName) -> void: counters.started += 1
	)
	adapter.cast_release_reached.connect(func() -> void: counters.released += 1)
	adapter.animation_finished.connect(
		func(_action_name: StringName) -> void: counters.finished += 1
	)
	assert_null(adapter.fallback_backend)
	assert_true(adapter.play_spell_action())
	_finish_active_3d_action(adapter)
	assert_eq(counters.started, 1)
	assert_eq(counters.released, 1)
	assert_eq(counters.finished, 1)
	_finish_active_3d_action(adapter)
	assert_eq(counters.released, 1)
	assert_eq(counters.finished, 1)


func test_portrait_2d_does_not_count_as_gameplay_body() -> void:
	var theme: Resource = load(HUD_THEME_PATH)
	assert_not_null(theme)
	var portrait := theme.get("portrait_texture") as Texture2D
	assert_not_null(portrait)
	assert_eq(portrait.resource_path, PORTRAIT_PATH)
	var adapter := await _create_ready_adapter()
	for node: Node in _all_nodes(adapter):
		var texture: Texture2D = null
		if node is Sprite2D:
			texture = node.texture
		elif node is TextureRect:
			texture = node.texture
		if texture != null:
			assert_ne(texture.resource_path, PORTRAIT_PATH)
	assert_true(adapter.find_children(
		"*", "AnimatedSprite2D", true, false
	).is_empty())


# SubViewport ----------------------------------------------------------------

func test_subviewport_has_camera() -> void:
	var backend := await _create_ready_backend()
	assert_not_null(backend.camera)
	assert_true(backend.camera.current)
	assert_eq(backend.camera.get_viewport(), backend.character_viewport)
	assert_eq(backend.camera.projection, Camera3D.PROJECTION_ORTHOGONAL)


func test_subviewport_texture_is_valid() -> void:
	var backend := await _create_ready_backend()
	assert_true(backend.has_valid_render_output())
	var image := _viewport_image(backend)
	assert_not_null(image)
	assert_false(image.is_empty())
	assert_true(_visible_alpha_bounds(image).has_area())


func test_rendered_sprite_uses_viewport_texture() -> void:
	var backend := await _create_ready_backend()
	assert_not_null(backend.rendered_sprite.texture)
	assert_true(backend.rendered_sprite.texture is ViewportTexture)
	assert_eq(
		backend.rendered_sprite.texture,
		backend.character_viewport.get_texture(),
	)


func test_character_is_inside_camera_frame() -> void:
	var backend := await _create_ready_backend()
	var visual := backend.get_achilles_visual()
	assert_not_null(visual)
	assert_false(backend.camera.is_position_behind(
		visual.foot_marker.global_position
	))
	assert_false(backend.camera.is_position_behind(
		visual.vfx_marker.global_position
	))
	var frame := Rect2(Vector2.ZERO, Vector2(backend.character_viewport.size))
	assert_true(frame.has_point(backend.camera.unproject_position(
		visual.foot_marker.global_position
	)))
	assert_true(frame.has_point(backend.camera.unproject_position(
		visual.vfx_marker.global_position
	)))
	var image := _viewport_image(backend)
	var bounds := _visible_alpha_bounds(image)
	assert_true(bounds.has_area())
	assert_true(Rect2i(Vector2i.ZERO, image.get_size()).encloses(bounds))


func test_background_is_transparent() -> void:
	var backend := await _create_ready_backend()
	assert_true(backend.character_viewport.transparent_bg)
	var image := _viewport_image(backend)
	var last := image.get_size() - Vector2i.ONE
	for point: Vector2i in [
		Vector2i.ZERO,
		Vector2i(last.x, 0),
		Vector2i(0, last.y),
		last,
	]:
		assert_true(image.get_pixel(point.x, point.y).a <= 0.02)


func test_foot_anchor_is_aligned() -> void:
	var backend := await _create_ready_backend()
	await wait_process_frames(2)
	var anchored := (
		backend.rendered_sprite.position
		+ backend.get_projected_foot_pixel() * backend.rendered_sprite.scale
	)
	assert_almost_eq(anchored.x, 0.0, 0.05)
	assert_almost_eq(anchored.y, 0.0, 0.05)


# Fallback -------------------------------------------------------------------

func test_missing_3d_asset_activates_legacy_fallback() -> void:
	var adapter := await _create_missing_asset_adapter()
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DFallbackBackend")
	assert_not_null(adapter.fallback_backend)
	assert_true(adapter.fallback_backend.is_backend_active())
	assert_true(adapter.fallback_backend.is_visible_in_tree())
	assert_true(adapter.fallback_backend.can_process())
	assert_false(adapter.viewport_backend.visible)
	var sprites := adapter.find_children("*", "AnimatedSprite2D", true, false)
	assert_eq(sprites.size(), 1)
	assert_true((sprites[0] as AnimatedSprite2D).is_visible_in_tree())


func test_nominal_runtime_does_not_activate_fallback() -> void:
	var adapter := await _create_ready_adapter()
	var state := adapter.get_visual_runtime_state()
	assert_eq(state.get("ACHILLES_VISUAL_BACKEND_REQUESTED"), "VIEWPORT_3D")
	assert_eq(state.get("ACHILLES_VISUAL_BACKEND_ACTIVE"), "VIEWPORT_3D")
	assert_false(bool(state.get("ACHILLES_VISUAL_FALLBACK_ACTIVE", true)))
	assert_null(adapter.fallback_backend)
	assert_true(adapter.get_last_backend_error().is_empty())


func test_fallback_emits_structured_reason() -> void:
	var adapter := await _create_missing_asset_adapter()
	var event := adapter.get_last_backend_error()
	assert_eq(event.get("event"), "ACHILLES_VISUAL_FALLBACK_ACTIVATED")
	assert_eq(event.get("reason"), "CHARACTER_ASSET_MISSING")
	assert_eq(event.get("requested_backend"), "VIEWPORT_3D")
	assert_eq(event.get("failed_resource"), MISSING_CHARACTER_PATH)
	assert_eq(event.get("room_id"), ROOM_II_PATH)
	assert_eq(String(event.get("commit", "")).to_lower(), _expected_head().to_lower())
	assert_true(bool(event.get("legacy_2d_loaded", false)))
	assert_true(bool(event.get("fallback_active", false)))


func test_fallback_never_displays_both_bodies() -> void:
	var adapter := await _create_missing_asset_adapter()
	assert_false(adapter.viewport_backend.visible)
	assert_false(adapter.viewport_backend.is_backend_active())
	assert_null(adapter.viewport_backend.get_achilles_visual())
	assert_true(adapter.fallback_backend.visible)
	var visible_legacy_bodies := 0
	for node: Node in _all_nodes(adapter):
		if node is AnimatedSprite2D and node.is_visible_in_tree():
			visible_legacy_bodies += 1
	assert_eq(visible_legacy_bodies, 1)
	assert_eq(
		int(adapter.viewport_backend.visible)
		+ int(adapter.fallback_backend.visible),
		1,
	)


# Absence d'arme -------------------------------------------------------------

func test_no_weapon_asset_loaded() -> void:
	var adapter := await _create_ready_adapter()
	assert_false(adapter.visual_profile.equipment_enabled)
	assert_null(adapter.visual_profile.weapon_profile)
	var dependencies := _transitive_dependencies(RUNTIME_DEPENDENCY_ROOTS)
	for dependency_path: String in dependencies:
		var lowered := dependency_path.to_lower()
		for token: String in [
			"/weapons/", "weapon_visual", "sword", "shield", "quiver",
		]:
			assert_false(token in lowered, dependency_path)
	var inspection := _load_json(GLB_INSPECTION_PATH)
	assert_eq(inspection.get("weapon_name_matches", []), [])
	var visual := adapter.viewport_backend.get_achilles_visual()
	assert_not_null(visual)
	assert_false(visual._contains_equipment_named_node())


func test_no_equipment_controller_instantiated() -> void:
	var adapter := await _create_ready_adapter()
	for node: Node in _all_nodes(adapter):
		var lowered := String(node.name).to_lower()
		assert_false("equipmentcontroller" in lowered)
		assert_false("weaponadapterroot" in lowered)
		assert_false("weaponvisualprofile" in lowered)


func test_no_weapon_child_under_hand() -> void:
	var visual := _create_initialized_visual()
	var skeleton := visual.get_skeleton()
	assert_true(skeleton.find_bone("mixamorig_LeftHand") >= 0)
	assert_true(skeleton.find_bone("mixamorig_RightHand") >= 0)
	assert_true(visual.find_children(
		"*", "BoneAttachment3D", true, false
	).is_empty())
	assert_false(visual._contains_equipment_named_node())


# Gameplay -------------------------------------------------------------------

func test_release_emitted_once() -> void:
	var adapter := await _create_ready_adapter()
	var releases := {"count": 0}
	adapter.cast_release_reached.connect(func() -> void: releases.count += 1)
	assert_true(adapter.play_spell_action())
	_finish_active_3d_action(adapter)
	_finish_active_3d_action(adapter)
	assert_eq(releases.count, 1)


func test_finished_emitted_once() -> void:
	var adapter := await _create_ready_adapter()
	var finishes := {"count": 0}
	adapter.animation_finished.connect(
		func(_action_name: StringName) -> void: finishes.count += 1
	)
	assert_true(adapter.play_spell_action())
	_finish_active_3d_action(adapter)
	_finish_active_3d_action(adapter)
	assert_eq(finishes.count, 1)


func test_selection_unchanged() -> void:
	# Battle and UnitView now carry one additive, presentation-only path hook so
	# Achilles can choose walk/run from the real route length. Selection remains
	# governed by the unchanged action bar/turn-state contract.
	assert_true(_path_unchanged_from_fix_base("ui/action_bar.gd"))
	var unit := Unit.from_data(_odyssey_achilles_data())
	var unit_view := UNIT_VIEW_SCENE.instantiate() as Node2D
	add_child_autofree(unit_view)
	unit_view.call("setup", unit)
	unit_view.call("set_active", true)
	await wait_process_frames(2)
	assert_true(bool(unit_view.get("_is_active")))
	var adapter := unit_view.call("get_optional_visual") as AchillesIsoUnitView
	assert_not_null(adapter)
	adapter.set_facing(Vector2i.RIGHT)
	adapter.cancel_pending_visual_actions()
	assert_true(bool(unit_view.get("_is_active")))


func test_pathfinding_unchanged() -> void:
	assert_true(_path_unchanged_from_fix_base("core/pathfinder.gd"))
	assert_true(_path_unchanged_from_fix_base("core/grid_data.gd"))
	var room := _room_ii()
	var grid := EncounterGridFactory.build_from_room(room)
	assert_not_null(grid)
	var achilles := Unit.from_data(_odyssey_achilles_data())
	var origin := _first_legal_spawn(room.hero_spawn_zone, grid)
	assert_ne(origin, Vector2i(-1, -1))
	assert_true(grid.place_unit(achilles, origin))
	var destination := _adjacent_legal_cell(origin, grid)
	assert_ne(destination, origin)
	var path: Array = Pathfinder.new(grid).find_path(
		origin, destination, achilles
	)
	assert_true(path.size() >= 2)
	assert_eq(path[0], origin)
	assert_eq(path[path.size() - 1], destination)
	assert_eq(achilles.grid_pos, origin)


func test_targeting_unchanged() -> void:
	assert_true(_path_unchanged_from_fix_base("battle/turn_state.gd"))
	assert_true(_path_unchanged_from_fix_base("core/spell_caster.gd"))
	var hero_data := _odyssey_achilles_data()
	assert_eq(hero_data.spells.size(), 4)
	var spell := hero_data.spells[0]
	var turn_state := TurnState.new()
	var observed := {
		"count": 0,
		"spell": null,
		"cell": Vector2i(-1, -1),
	}
	turn_state.request_cast_spell.connect(
		func(requested_spell: Spell, cell: Vector2i) -> void:
			observed.count += 1
			observed.spell = requested_spell
			observed.cell = cell
	)
	turn_state.on_spell_selected(spell)
	assert_eq(turn_state.current, TurnState.State.TARGET_SPELL)
	assert_eq(turn_state.selected_spell, spell)
	var target_cell := Vector2i(5, 5)
	turn_state.on_cell_clicked(target_cell)
	assert_eq(observed.count, 1)
	assert_eq(observed.spell, spell)
	assert_eq(observed.cell, target_cell)


func test_achilles_stats_unchanged() -> void:
	# Presentation references intentionally evolved to V2; gameplay values are
	# still the protected contract.
	var data := load(ACHILLES_UNIT_PATH) as UnitData
	assert_eq(data.max_hp, 110)
	assert_eq(data.initiative, 14)
	assert_eq(data.max_ap, 6)
	assert_eq(data.max_mp, 3)
	assert_eq(data.attack_power, 18)
	assert_false(data.basic_attack_enabled)
	assert_eq(data.active_spell_slots, 4)
	assert_not_null(data.animation_set)
	assert_eq(
		data.animation_set.resource_path,
		"res://data/characters/achilles/animations.tres"
	)
	assert_not_null(data.preview_visual_scene)
	assert_eq(
		data.preview_visual_scene.resource_path,
		"res://assets/characters/Achilles/3d/achilles_rig_animation_pool_v2.glb"
	)


func test_spells_unchanged() -> void:
	assert_true(_path_unchanged_from_fix_base("data/spells/achilles"))
	for path_value: Variant in EXPECTED_SPELL_HASHES:
		var path := String(path_value)
		assert_eq(
			FileAccess.get_sha256(path).to_upper(),
			String(EXPECTED_SPELL_HASHES[path]),
			path,
		)
	assert_eq(_odyssey_achilles_data().spells.size(), 4)


# Helpers --------------------------------------------------------------------

func _odyssey_resolution() -> RunHeroResolution:
	return RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)


func _odyssey_achilles_data() -> UnitData:
	return _odyssey_resolution().heroes[0]


func _room_ii() -> RoomData:
	return ODYSSEY_RUN.rooms[ROOM_II_INDEX]


func _profile() -> AchillesVisualProfile:
	return load(PROFILE_PATH) as AchillesVisualProfile


func _create_initialized_visual() -> Achilles3DVisual:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	assert_not_null(visual)
	add_child_autofree(visual)
	assert_true(visual.initialize_from_profile(_profile()))
	assert_true(visual.is_initialized())
	return visual


func _create_ready_backend() -> AchillesViewport3DBackend:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	assert_not_null(backend)
	add_child_autofree(backend)
	assert_true(backend.configure(_profile()))
	var deadline := Time.get_ticks_msec() + RUNTIME_READY_TIMEOUT_MSEC
	while not backend.is_ready_for_render() \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_true(backend.is_ready_for_render())
	backend.set_backend_active(true)
	await wait_process_frames(2)
	assert_true(backend.is_backend_active())
	assert_true(backend.has_valid_render_output())
	return backend


func _create_ready_adapter() -> AchillesIsoUnitView:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	assert_not_null(adapter)
	add_child_autofree(adapter)
	adapter.configure_runtime_diagnostics(
		true, ROOM_II_PATH, _expected_head()
	)
	var deadline := Time.get_ticks_msec() + RUNTIME_READY_TIMEOUT_MSEC
	while adapter.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_true(adapter.viewport_backend.is_backend_active())
	assert_true(adapter.viewport_backend.has_valid_render_output())
	return adapter


func _create_missing_asset_adapter() -> AchillesIsoUnitView:
	var invalid_profile := _profile().duplicate(true) as AchillesVisualProfile
	invalid_profile.character_asset_path = MISSING_CHARACTER_PATH
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	adapter.visual_profile = invalid_profile
	add_child_autofree(adapter)
	adapter.configure_runtime_diagnostics(
		true, ROOM_II_PATH, _expected_head()
	)
	var deadline := Time.get_ticks_msec() + RUNTIME_READY_TIMEOUT_MSEC
	while adapter.get_active_backend_name() != &"Legacy2DFallbackBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(adapter.get_active_backend_name(), &"Legacy2DFallbackBackend")
	return adapter


func _finish_active_3d_action(adapter: AchillesIsoUnitView) -> void:
	var visual := adapter.viewport_backend.get_achilles_visual()
	assert_not_null(visual)
	visual._process(visual._action_finish_seconds + 0.01)


func _viewport_image(backend: AchillesViewport3DBackend) -> Image:
	var texture: Texture2D = backend.character_viewport.get_texture()
	assert_not_null(texture)
	var image: Image = texture.get_image()
	assert_not_null(image)
	return image


func _visible_alpha_bounds(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _all_nodes(root_node: Node) -> Array[Node]:
	var result: Array[Node] = [root_node]
	result.append_array(root_node.find_children("*", "Node", true, false))
	return result


func _transitive_dependencies(root_paths: Array[String]) -> Array[String]:
	var pending: Array[String] = root_paths.duplicate()
	var seen := {}
	var result: Array[String] = []
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		seen[path] = true
		result.append(path)
		for raw_dependency: String in ResourceLoader.get_dependencies(path):
			var dependency_path := _dependency_resource_path(raw_dependency)
			if not dependency_path.is_empty() and not seen.has(dependency_path):
				pending.append(dependency_path)
	return result


func _dependency_resource_path(raw_dependency: String) -> String:
	var resource_index := raw_dependency.find("res://")
	if resource_index < 0:
		return ""
	var path := raw_dependency.substr(resource_index)
	var metadata_index := path.find("::")
	if metadata_index >= 0:
		path = path.left(metadata_index)
	return path


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _first_legal_spawn(cells: Array[Vector2i], grid: GridData) -> Vector2i:
	for cell: Vector2i in cells:
		if grid.is_valid(cell) and grid.is_walkable(cell) \
				and not grid.has_unit(cell):
			return cell
	return Vector2i(-1, -1)


func _adjacent_legal_cell(origin: Vector2i, grid: GridData) -> Vector2i:
	for direction: Vector2i in [
		Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
	]:
		var candidate := origin + direction
		if grid.is_valid(candidate) and grid.is_walkable(candidate) \
				and not grid.has_unit(candidate):
			return candidate
	return origin


func _expected_project_path() -> String:
	return OS.get_environment(EXPECTED_PROJECT_PATH_ENV)


func _expected_head() -> String:
	return OS.get_environment(EXPECTED_HEAD_ENV)


func _actual_project_path() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()


func _git_value(arguments: PackedStringArray) -> String:
	var result := _git_command(arguments)
	assert_eq(int(result.get("exit_code", -1)), 0, String(result.get("output", "")))
	return String(result.get("output", "")).strip_edges()


func _path_unchanged_from_fix_base(path: String) -> bool:
	var result := _git_command(PackedStringArray([
		"diff", "--quiet", FIX_BASE_SHA, "--", path,
	]))
	return int(result.get("exit_code", -1)) == 0


func _git_command(arguments: PackedStringArray) -> Dictionary:
	var project_path := _actual_project_path()
	var command_arguments := PackedStringArray([
		"-c", "safe.directory=%s" % project_path,
		"-C", project_path,
	])
	command_arguments.append_array(arguments)
	var output: Array = []
	var exit_code := OS.execute(
		"git", command_arguments, output, true, false
	)
	var combined_output := ""
	for chunk: Variant in output:
		combined_output += String(chunk)
	return {"exit_code": exit_code, "output": combined_output}
