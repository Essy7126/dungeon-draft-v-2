extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const VISUAL_SCENE := preload(
	"res://characters/achilles/3d/Achilles3DVisual.tscn"
)
const BACKEND_SCENE := preload(
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)
const ADAPTER_SCENE := preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const UNIT_VIEW_SCENE := preload("res://battle/unit_view.tscn")
const ODYSSEY_RUN: RunData = preload("res://data/runs/odyssey.tres")
const ACHILLES_UNIT_PATH := "res://data/units/allies/achilles.tres"
const PROGRESSION_PATH := (
	"res://data/runs/progression/odyssey/achilles_progression_profile.tres"
)
const ECONOMY_PATH := (
	"res://data/runs/economy/odyssey_economy_profile.tres"
)
const EXPECTED_UNIT_SHA := (
	"88B80F80A8F4FA3E48818FD6DCA73ED3C47FEB41DD7A9798717B30842755F62A"
)
const EXPECTED_PROGRESSION_SHA := (
	"A1F2C8B77263D8519065D6CED424FFD4B450E79CD76A70A2EFB50D55BAA75AC1"
)
const EXPECTED_ECONOMY_SHA := (
	"70F6CE8085E5D7A7C0AFA5B2ADB37161380B7A5364470B17A3192E89506A24D6"
)
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
const MANUAL_FLOW_BOUNDARY := (
	"OWNER_SELECTED_B_SUBVIEWPORT_384: the dedicated graphical promotion "
	+ "runner validates production handlers programmatically; this unit test "
	+ "does not claim physical mouse input or an enemy-defeat playthrough."
)


# Personnage -----------------------------------------------------------------

func test_achilles_3d_visual_instantiates() -> void:
	var visual := VISUAL_SCENE.instantiate()
	assert_not_null(visual)
	assert_true(visual is Achilles3DVisual)
	visual.free()


func test_single_runtime_skeleton() -> void:
	var visual := _create_visual()
	assert_eq(visual.find_children("*", "Skeleton3D", true, false).size(), 1)
	assert_not_null(visual.get_skeleton())


func test_character_meshes_visible() -> void:
	var visual := _create_visual()
	var meshes := visual.get_mesh_instances()
	var visible_meshes := 0
	for mesh in meshes:
		assert_not_null(mesh.mesh)
		if mesh.visible:
			visible_meshes += 1
	assert_true(not meshes.is_empty())
	assert_eq(visible_meshes, meshes.size())


func test_expected_materials_visible() -> void:
	var visual := _create_visual()
	assert_true(visual.has_visible_character_materials())
	for mesh in visual.get_mesh_instances():
		var material_count := 0
		for surface_index in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface_index) != null:
				material_count += 1
		assert_true(material_count > 0, "Every canonical mesh needs a material.")


func test_no_weapon_mesh_embedded() -> void:
	var visual := _create_visual()
	assert_false(visual._contains_equipment_named_node())
	for mesh in visual.get_mesh_instances():
		var identity := (
			String(mesh.name) + " " + String(mesh.mesh.resource_name)
		).to_lower()
		for token in ["weapon", "sword", "blade", "shield", "bow", "quiver"]:
			assert_false(token in identity, "Forbidden mesh token: %s" % token)


func test_no_equipment_instance_present() -> void:
	var visual := _create_visual()
	assert_null(visual.find_child("EquipmentController", true, false))
	assert_null(visual.find_child("WeaponAdapterRoot", true, false))
	assert_null(visual.find_child("WeaponVisualProfile", true, false))


# Profil ---------------------------------------------------------------------

func test_character_only_profile_schema() -> void:
	var profile := _profile()
	assert_not_null(profile)
	assert_eq(profile.schema_version, 1)
	assert_eq(profile.profile_id, &"achilles_character_only_v1")
	assert_true(profile.is_character_only_valid())


func test_equipment_enabled_is_false() -> void:
	var profile := _profile()
	assert_false(profile.equipment_enabled)
	assert_true(profile.is_character_only_valid())


func test_weapon_profile_is_null() -> void:
	var profile := _profile()
	assert_null(profile.weapon_profile)
	assert_true(profile.is_character_only_valid())


func test_skeleton_signature_matches() -> void:
	var profile := _profile()
	var visual := _create_visual()
	assert_eq(visual.get_runtime_skeleton_signature(), profile.skeleton_signature)


# Animation ------------------------------------------------------------------

func test_idle_or_stable_pose_available() -> void:
	var visual := _create_visual()
	assert_true(visual.play_idle())
	assert_eq(visual.get_active_semantic(), &"IDLE")
	assert_eq(_profile().animation_profile.IDLE.godot_name, "Anim_0_004")


func test_move_has_explicit_clip_or_fallback() -> void:
	var visual := _create_visual()
	assert_true(visual.play_move())
	assert_eq(visual.get_active_semantic(), &"MOVE")
	assert_eq(_profile().animation_profile.MOVE.godot_name, "Anim_0_005")


func test_action_has_explicit_clip_or_fallback() -> void:
	var visual := _create_visual()
	assert_true(visual.play_action())
	assert_eq(visual.get_active_semantic(), &"ACTION_FALLBACK")
	assert_eq(
		_profile().animation_profile.ACTION_FALLBACK.godot_name,
		"Anim_0_003",
	)


func test_unclassified_action_not_silently_named() -> void:
	var profile := _profile()
	var action_entry := profile.animation_profile.ACTION_FALLBACK as Dictionary
	assert_eq(action_entry.mode, "SOURCE_CLIP_GENERIC_ACTION")
	assert_eq(action_entry.source_name, "Anim_0.003")
	assert_false(action_entry.has("weapon_semantic"))
	assert_eq(_create_visual().get_root_motion_policy(), &"ROOT_MOTION_UNCLASSIFIED")


func test_release_emitted_once() -> void:
	var visual := _create_visual()
	var releases := {"count": 0}
	visual.action_release_reached.connect(func() -> void: releases.count += 1)
	assert_true(visual.play_action())
	visual._process(visual._action_release_seconds + 0.01)
	assert_eq(releases.count, 1)
	visual._process(visual._action_finish_seconds + 1.0)
	visual._process(visual._action_finish_seconds + 1.0)
	assert_eq(releases.count, 1)


func test_finished_emitted_once() -> void:
	var visual := _create_visual()
	var finishes := {"count": 0}
	visual.action_finished.connect(func(_name: StringName) -> void:
		finishes.count += 1
	)
	assert_true(visual.play_action())
	visual._process(visual._action_finish_seconds + 1.0)
	visual._process(visual._action_finish_seconds + 1.0)
	assert_eq(finishes.count, 1)


func test_timeout_prevents_soft_lock() -> void:
	var adapter := await _create_ready_adapter()
	var releases := {"count": 0}
	var finishes := {"count": 0, "name": &""}
	adapter.cast_release_reached.connect(func() -> void: releases.count += 1)
	adapter.animation_finished.connect(func(action_name: StringName) -> void:
		finishes.count += 1
		finishes.name = action_name
	)
	assert_true(adapter.play_spell_action())
	# Suppress the backend completion so the adapter watchdog is the only
	# completion path exercised by this test.
	adapter.viewport_backend.cancel_action()
	adapter.fallback_backend.cancel_action()
	assert_true(adapter._action_pending)
	adapter._action_elapsed = AchillesIsoUnitView.ACTION_TIMEOUT_SECONDS - 0.01
	adapter._process(0.02)
	assert_false(adapter._action_pending)
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)
	assert_eq(finishes.name, &"ACTION_FALLBACK")
	adapter._process(AchillesIsoUnitView.ACTION_TIMEOUT_SECONDS * 2.0)
	assert_eq(releases.count, 1)
	assert_eq(finishes.count, 1)


func test_root_motion_does_not_move_gameplay_parent() -> void:
	var gameplay_parent := Node3D.new()
	gameplay_parent.transform = Transform3D(Basis.IDENTITY, Vector3(8.0, 2.0, -5.0))
	add_child_autofree(gameplay_parent)
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	gameplay_parent.add_child(visual)
	assert_true(visual.initialize_from_profile(_profile()))
	var before := gameplay_parent.transform
	assert_true(visual.play_move())
	var animation_player := visual.get_animation_player()
	animation_player.advance(0.5)
	visual._process(0.5)
	var hips_index := visual.get_skeleton().find_bone("mixamorig_Hips")
	if hips_index < 0:
		hips_index = visual.get_skeleton().find_bone("mixamorig:Hips")
	assert_true(hips_index >= 0)
	var move_hips := visual.get_skeleton().get_bone_pose_position(hips_index)
	assert_almost_eq(move_hips.x, visual._active_clip_hips_origin.x, 0.001)
	assert_almost_eq(move_hips.z, visual._active_clip_hips_origin.y, 0.001)
	assert_eq(visual._model_root.transform, visual._model_local_transform)
	assert_eq(gameplay_parent.transform, before)
	assert_true(visual.play_action())
	animation_player.advance(0.4)
	visual._process(0.4)
	var action_hips := visual.get_skeleton().get_bone_pose_position(hips_index)
	assert_almost_eq(action_hips.x, visual._active_clip_hips_origin.x, 0.001)
	assert_almost_eq(action_hips.z, visual._active_clip_hips_origin.y, 0.001)
	assert_eq(visual._model_root.transform, visual._model_local_transform)
	assert_eq(gameplay_parent.transform, before)


# SubViewport ----------------------------------------------------------------

func test_subviewport_backend_instantiates() -> void:
	var backend := BACKEND_SCENE.instantiate()
	assert_not_null(backend)
	assert_true(backend is AchillesViewport3DBackend)
	backend.free()


func test_transparent_background() -> void:
	var backend := await _create_ready_backend()
	assert_true(backend.character_viewport.transparent_bg)
	var world_environment := backend.get_node(
		"AchillesSubViewport/RenderWorld/WorldEnvironment"
	) as WorldEnvironment
	assert_not_null(world_environment)
	assert_almost_eq(world_environment.environment.background_color.a, 0.0, 0.001)


func test_rendered_sprite_receives_texture() -> void:
	var backend := await _create_ready_backend()
	assert_not_null(backend.rendered_sprite.texture)
	assert_true(backend.rendered_sprite.texture is ViewportTexture)


func test_backend_does_not_receive_gameplay_input() -> void:
	var backend := await _create_ready_backend()
	assert_true(backend.character_viewport.gui_disable_input)
	assert_false(backend.character_viewport.handle_input_locally)
	assert_false(backend.character_viewport.physics_object_picking)
	assert_true(
		backend.character_viewport.find_children(
			"*", "CollisionObject3D", true, false
		).is_empty()
	)


func test_foot_anchor_alignment() -> void:
	var backend := await _create_ready_backend()
	backend.set_backend_active(true)
	for resolution in [256, 384, 512]:
		assert_true(backend.set_viewport_resolution(resolution))
		await wait_process_frames(2)
		var anchored := (
			backend.rendered_sprite.position
			+ backend.get_projected_foot_pixel() * backend.rendered_sprite.scale
		)
		assert_almost_eq(anchored.x, 0.0, 0.01, str(resolution))
		assert_almost_eq(anchored.y, 0.0, 0.01, str(resolution))


func test_four_cardinal_orientations() -> void:
	var backend := await _create_ready_backend()
	var profile := _profile()
	var observed := {}
	for direction in ["N", "E", "S", "W"]:
		backend.set_facing_label(direction)
		var yaw := backend.get_achilles_visual().character_asset.rotation_degrees.y
		assert_almost_eq(yaw, profile.yaw_for_direction(direction), 0.001)
		observed[snappedf(yaw, 0.001)] = true
	assert_eq(observed.size(), 4)


func test_backend_cleanup_releases_viewport() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child(backend)
	assert_true(backend.configure(_profile()))
	await wait_process_frames(4)
	var viewport_ref: WeakRef = weakref(backend.character_viewport)
	backend.shutdown()
	backend.queue_free()
	await wait_process_frames(3)
	assert_null(viewport_ref.get_ref())


func test_no_visual_action_fallback_available() -> void:
	var profile := _profile()
	assert_not_null(profile.fallback_backend_scene)
	var fallback := profile.fallback_backend_scene.instantiate()
	assert_eq(
		fallback.get_script(),
		load("res://characters/achilles/3d/achilles_no_visual_fallback_backend.gd"),
	)
	assert_true(fallback.find_children(
		"*", "CanvasItem", true, false
	).is_empty())
	fallback.free()


func test_backends_never_visible_together() -> void:
	var adapter := await _create_ready_adapter()
	assert_true(adapter.viewport_backend.visible)
	assert_false(adapter.fallback_backend.visible)
	assert_eq(_visible_backend_count(adapter), 1)
	adapter.force_safe_fallback(&"MANDATE_COVERAGE_FORCED_FALLBACK")
	assert_false(adapter.viewport_backend.visible)
	assert_false(adapter.fallback_backend.visible)
	assert_eq(_visible_backend_count(adapter), 0)


func test_no_visual_action_before_warmup_defers_viewport_activation() -> void:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	add_child_autofree(adapter)
	assert_eq(adapter.get_active_backend_name(), &"NoVisualFallbackBackend")
	assert_true(adapter.play_spell_action())
	assert_true(adapter._action_pending)
	await wait_process_frames(4)
	assert_true(adapter.viewport_backend.is_ready_for_render())
	assert_true(adapter._viewport_activation_deferred)
	assert_eq(adapter.get_active_backend_name(), &"NoVisualFallbackBackend")
	assert_false(adapter.fallback_backend.visible)
	assert_false(adapter.viewport_backend.visible)
	adapter._on_backend_action_finished(&"ACTION_FALLBACK")
	assert_false(adapter._action_pending)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_false(adapter.fallback_backend.visible)
	assert_true(adapter.viewport_backend.visible)
	adapter.force_safe_fallback(&"RACE_TEST_FORCED_FALLBACK")
	assert_eq(adapter.get_active_backend_name(), &"NoVisualFallbackBackend")
	assert_true(adapter.play_spell_action())
	assert_true(adapter._action_pending)
	assert_eq(adapter.get_active_backend_name(), &"NoVisualFallbackBackend")
	adapter.cancel_pending_visual_actions()
	assert_false(adapter._action_pending)


func test_double_configure_is_rejected_without_duplicate_visual() -> void:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child_autofree(backend)
	var profile := _profile()
	assert_true(backend.configure(profile))
	assert_false(backend.configure(profile))
	assert_eq(
		backend.get_last_error_code(),
		&"SUBVIEWPORT_BACKEND_ALREADY_CONFIGURED",
	)
	assert_eq(
		backend.render_world.find_children(
			"*", "Achilles3DVisual", true, false
		).size(),
		1,
	)
	assert_not_null(backend.get_achilles_visual())
	backend.shutdown()
	assert_null(backend.get_achilles_visual())
	assert_eq(
		backend.render_world.find_children(
			"*", "Achilles3DVisual", true, false
		).size(),
		0,
	)


func test_force_safe_fallback_mid_action_stops_hidden_3d_action() -> void:
	var adapter := await _create_ready_adapter()
	var visual := adapter.viewport_backend.get_achilles_visual()
	assert_true(adapter.play_spell_action())
	assert_true(visual._action_active)
	adapter.force_safe_fallback(&"MID_ACTION_REGRESSION_TEST")
	assert_eq(adapter.get_active_backend_name(), &"NoVisualFallbackBackend")
	assert_false(adapter.viewport_backend.visible)
	assert_false(visual._action_active)
	assert_true(adapter.fallback_backend._action_pending)
	assert_true(adapter._action_pending)
	adapter.cancel_pending_visual_actions()
	assert_false(adapter.fallback_backend._action_pending)
	assert_false(adapter._action_pending)


func test_finish_listener_can_start_next_action_without_idle_override() -> void:
	var visual := _create_visual()
	var restarted := {"value": false}
	visual.action_finished.connect(func(_action_name: StringName) -> void:
		restarted.value = visual.play_action()
	, CONNECT_ONE_SHOT)
	assert_true(visual.play_action())
	visual._finish_action_once()
	assert_true(restarted.value)
	assert_true(visual._action_active)
	assert_eq(visual.get_active_semantic(), &"ACTION_FALLBACK")


# Odyssey --------------------------------------------------------------------

func test_room_01_spawns_single_achilles() -> void:
	await _assert_room_supports_single_3d_achilles(0)


func test_room_02_spawns_single_achilles() -> void:
	var resolution = RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)
	assert_not_null(resolution)
	assert_true(resolution.is_valid())
	assert_eq(resolution.heroes.size(), 1)
	var runtime_data: UnitData = resolution.heroes[0]
	assert_eq(runtime_data.unit_id, &"achilles")
	var room: RoomData = ODYSSEY_RUN.rooms[1]
	var grid: GridData = EncounterGridFactory.build_from_room(room)
	assert_not_null(grid)
	var achilles := Unit.from_data(runtime_data)
	var spawn_cell := _first_legal_spawn(room.hero_spawn_zone, grid)
	assert_ne(spawn_cell, Vector2i(-1, -1))
	assert_true(grid.place_unit(achilles, spawn_cell))
	var stage := Node2D.new()
	add_child_autofree(stage)
	var unit_view = UNIT_VIEW_SCENE.instantiate()
	stage.add_child(unit_view)
	unit_view.setup(achilles)
	await wait_process_frames(8)
	var adapters := unit_view.find_children(
		"*", "AchillesIsoUnitView", true, false
	)
	assert_eq(adapters.size(), 1)
	assert_eq(achilles.unit_id, &"achilles")
	assert_eq(achilles.grid_pos, spawn_cell)
	assert_true(grid.has_unit(spawn_cell))


func test_room_03_spawns_single_achilles() -> void:
	await _assert_room_supports_single_3d_achilles(2)


func test_no_weapon_in_all_rooms() -> void:
	var profile := _profile()
	assert_false(profile.equipment_enabled)
	assert_null(profile.weapon_profile)
	for room_value in ODYSSEY_RUN.rooms:
		var room := room_value as RoomData
		assert_not_null(room)
		assert_not_null(room.battle_scene)
	var adapter_text := FileAccess.get_file_as_string(
		"res://characters/achilles/AchillesIsoUnitView.tscn"
	)
	assert_false(adapter_text.contains("AchillesLegacy2DBackend"))
	assert_false(adapter_text.contains("AchillesVisual2D"))


func test_room_transition_leaves_no_duplicate() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " Normal transitions driven by enemy defeat remain outside this unit test."
	)


func test_reload_leaves_no_duplicate() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " Normal room reload was NOT_MEASURED; visual-instance reload is not "
		+ "presented as a normal room reload."
	)


func test_odyssey_normal_entry_path() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " The production Hub path is covered by the graphical runner, not here."
	)


func test_three_room_character_visual_smoke() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " See achilles_odyssey_3d_runtime_promotion_smoke for graphical evidence."
	)


func test_odyssey_result_screen_reached() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " The result UI uses a synthetic recorded victory in the graphical runner."
	)


# Non-regression -------------------------------------------------------------

func test_achilles_stats_unchanged() -> void:
	assert_eq(FileAccess.get_sha256(ACHILLES_UNIT_PATH).to_upper(), EXPECTED_UNIT_SHA)
	var unit_data := load(ACHILLES_UNIT_PATH) as UnitData
	assert_not_null(unit_data)
	assert_eq(unit_data.unit_id, &"achilles")
	assert_eq(unit_data.max_hp, 110)
	assert_eq(unit_data.initiative, 14)
	assert_eq(unit_data.max_ap, 6)
	assert_eq(unit_data.max_mp, 3)
	assert_eq(unit_data.attack_power, 18)
	assert_false(unit_data.basic_attack_enabled)
	assert_eq(unit_data.active_spell_slots, 4)


func test_achilles_spell_resources_unchanged() -> void:
	for path in EXPECTED_SPELL_HASHES:
		assert_eq(
			FileAccess.get_sha256(path).to_upper(),
			EXPECTED_SPELL_HASHES[path],
			path,
		)
	var resolution = RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)
	assert_true(resolution.is_valid())
	assert_eq(resolution.heroes[0].spells.size(), 4)


func test_odyssey_progression_profile_unchanged() -> void:
	assert_eq(
		FileAccess.get_sha256(PROGRESSION_PATH).to_upper(),
		EXPECTED_PROGRESSION_SHA,
	)
	var profile = load(PROGRESSION_PATH)
	assert_eq(profile.character_id, &"achilles")
	assert_eq(profile.active_spell_slots, 4)
	assert_eq(profile.spells.size(), 4)
	assert_eq(profile.disciplines.size(), 4)


func test_odyssey_economy_unchanged() -> void:
	assert_eq(
		FileAccess.get_sha256(ECONOMY_PATH).to_upper(),
		EXPECTED_ECONOMY_SHA,
	)
	var economy = load(ECONOMY_PATH)
	assert_false(economy.equipment_rewards_enabled)
	assert_eq(economy.starting_items.size(), 2)
	assert_eq(ODYSSEY_RUN.economy_profile.resource_path, ECONOMY_PATH)


func test_grid_position_unchanged() -> void:
	var unit_data := load(ACHILLES_UNIT_PATH) as UnitData
	var achilles := Unit.from_data(unit_data)
	achilles.grid_pos = Vector2i(4, 6)
	var before := achilles.grid_pos
	var adapter := await _create_ready_adapter()
	adapter.bind_unit(achilles)
	assert_true(adapter.play_basic_attack())
	adapter.viewport_backend.cancel_action()
	adapter._action_elapsed = AchillesIsoUnitView.ACTION_TIMEOUT_SECONDS
	adapter._process(0.01)
	assert_eq(achilles.grid_pos, before)


func test_selection_unchanged() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " Selection/click flow is NOT_MEASURED and was not simulated by a unit test."
	)


func test_pathfinding_unchanged() -> void:
	var resolution = RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)
	assert_true(resolution.is_valid())
	var room: RoomData = ODYSSEY_RUN.rooms[1]
	var grid: GridData = EncounterGridFactory.build_from_room(room)
	var achilles := Unit.from_data(resolution.heroes[0])
	var origin := _first_legal_spawn(room.hero_spawn_zone, grid)
	assert_true(grid.place_unit(achilles, origin))
	var destination := _adjacent_legal_cell(origin, grid)
	assert_ne(destination, origin)
	var path: Array = Pathfinder.new(grid).find_path(origin, destination, achilles)
	assert_true(path.size() >= 2)
	assert_eq(path[0], origin)
	assert_eq(path[path.size() - 1], destination)
	assert_eq(achilles.grid_pos, origin)


func test_targeting_unchanged() -> void:
	pending(
		MANUAL_FLOW_BOUNDARY
		+ " Target selection is NOT_MEASURED and was not simulated by a unit test."
	)


# The historical armed sprite remains in the repository as a POC asset, but it
# must no longer be reachable from the Odyssey runtime adapter or its fallback.
func test_retired_2d_fallback_is_unreachable_from_runtime() -> void:
	var fallback := _profile().fallback_backend_scene.instantiate()
	assert_eq(
		fallback.get_script(),
		load("res://characters/achilles/3d/achilles_no_visual_fallback_backend.gd"),
	)
	assert_true(fallback.find_children(
		"*", "AnimatedSprite2D", true, false
	).is_empty())
	var adapter_text := FileAccess.get_file_as_string(
		"res://characters/achilles/AchillesIsoUnitView.tscn"
	)
	assert_false(adapter_text.contains("AchillesLegacy2DBackend"))
	assert_false(adapter_text.contains("AchillesVisual2D"))
	fallback.free()


func _profile() -> AchillesVisualProfile:
	return load(PROFILE_PATH) as AchillesVisualProfile


func _create_visual() -> Achilles3DVisual:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	add_child_autofree(visual)
	assert_true(visual.initialize_from_profile(_profile()))
	assert_true(visual.is_initialized())
	return visual


func _create_ready_backend() -> AchillesViewport3DBackend:
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	add_child_autofree(backend)
	assert_true(backend.configure(_profile()))
	await wait_process_frames(4)
	assert_true(backend.is_ready_for_render())
	return backend


func _create_ready_adapter() -> AchillesIsoUnitView:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	add_child_autofree(adapter)
	await wait_process_frames(6)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	return adapter


func _assert_room_supports_single_3d_achilles(room_index: int) -> void:
	var resolution = RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)
	assert_true(resolution.is_valid())
	assert_eq(resolution.heroes.size(), 1)
	var room := ODYSSEY_RUN.rooms[room_index] as RoomData
	assert_not_null(room)
	assert_not_null(room.battle_scene)
	var grid := EncounterGridFactory.build_from_room(room)
	var achilles := Unit.from_data(resolution.heroes[0])
	var spawn_cell := _first_legal_spawn(room.hero_spawn_zone, grid)
	assert_ne(spawn_cell, Vector2i(-1, -1))
	assert_true(grid.place_unit(achilles, spawn_cell))
	var unit_view = UNIT_VIEW_SCENE.instantiate()
	add_child_autofree(unit_view)
	unit_view.setup(achilles)
	await wait_process_frames(8)
	var adapter := unit_view.get_optional_visual() as AchillesIsoUnitView
	assert_not_null(adapter)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_eq(
		adapter.viewport_backend.character_viewport.size,
		Vector2i(384, 384),
	)
	assert_true(adapter.find_children(
		"*", "AnimatedSprite2D", true, false
	).is_empty())


func _visible_backend_count(adapter: AchillesIsoUnitView) -> int:
	return int(adapter.fallback_backend.visible) + int(adapter.viewport_backend.visible)


func _first_legal_spawn(cells: Array[Vector2i], grid: GridData) -> Vector2i:
	for cell in cells:
		if grid.is_valid(cell) and grid.is_walkable(cell) and not grid.has_unit(cell):
			return cell
	return Vector2i(-1, -1)


func _adjacent_legal_cell(origin: Vector2i, grid: GridData) -> Vector2i:
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
	]
	for direction: Vector2i in directions:
		var candidate: Vector2i = origin + direction
		if grid.is_valid(candidate) and grid.is_walkable(candidate) \
				and not grid.has_unit(candidate):
			return candidate
	return origin
