extends GutTest

const PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile_v2.tres"
)
const ANIMATION_SET_PATH := "res://data/characters/achilles/animations.tres"
const UNIT_DATA_PATH := "res://data/units/allies/achilles.tres"
const VISUAL_SCENE := preload(
	"res://characters/achilles/3d/Achilles3DVisual.tscn"
)
const ADAPTER_SCENE := preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const RUNTIME_READY_TIMEOUT_MSEC := 10000
const ACTION_FALLBACK_CLIP := &"achilles_v2__mage_soell_cast_7"

const EXPECTED_POOL_CLIPS: Array[StringName] = [
	&"achilles_v2__Alert",
	&"achilles_v2__Archery_Shot_3",
	&"achilles_v2__Basic_Jump",
	&"achilles_v2__Charged_Spell_Cast",
	&"achilles_v2__Charged_Upward_Slash",
	&"achilles_v2__Chest_Pound_Taunt",
	&"achilles_v2__Double_Combo_Attack",
	&"achilles_v2__Draw_and_Shoot_from_Back_2",
	&"achilles_v2__Electrocution_Reaction",
	&"achilles_v2__Hit_Reaction_1",
	&"achilles_v2__Idle_11",
	&"achilles_v2__Left_Slash",
	&"achilles_v2__Running",
	&"achilles_v2__Simple_Kick",
	&"achilles_v2__Sword_Judgment",
	&"achilles_v2__Sword_Parry_Backward_2",
	&"achilles_v2__Triple_Combo_Attack",
	&"achilles_v2__Walking",
	&"achilles_v2__mage_soell_cast_7",
	&"achilles_v2__run_fast_3_inplace",
]

const EXPECTED_SPELL_CLIPS := {
	&"achilles_advance": &"achilles_v2__run_fast_3_inplace",
	&"achilles_guard": &"achilles_v2__Sword_Parry_Backward_2",
	&"achilles_spear_thrust": &"achilles_v2__Left_Slash",
	&"achilles_sweep": &"achilles_v2__Charged_Upward_Slash",
}

const SPELL_PATHS := {
	&"achilles_advance": "res://data/spells/achilles/advance.tres",
	&"achilles_guard": "res://data/spells/achilles/guard.tres",
	&"achilles_spear_thrust": "res://data/spells/achilles/spear_thrust.tres",
	&"achilles_sweep": "res://data/spells/achilles/sweep.tres",
}


func test_v2_profile_and_import_expose_the_complete_animation_pool() -> void:
	var profile := _profile()
	assert_not_null(profile)
	assert_true(profile.is_character_only_valid())
	assert_eq(profile.profile_id, &"achilles_character_animation_pool_v2")
	assert_eq(profile.run_min_path_cells, 6)
	assert_eq(profile.clip_runtime.size(), 20)

	var visual := _create_initialized_visual()
	var source_clips := visual.get_all_source_action_names()
	assert_true(
		source_clips.size() >= 24,
		"le rig V2 doit conserver au moins 24 clips hors RESET"
	)
	var pool_clip_count := 0
	for clip: StringName in source_clips:
		if String(clip).begins_with("achilles_v2__"):
			pool_clip_count += 1
	assert_eq(pool_clip_count, 20)
	for clip: StringName in EXPECTED_POOL_CLIPS:
		assert_true(source_clips.has(clip), "clip importe : %s" % clip)
		assert_true(
			profile.clip_runtime.has(String(clip)),
			"calibration runtime : %s" % clip
		)


func test_profile_and_character_set_only_reference_real_imported_clips() -> void:
	var profile := _profile()
	var visual := _create_initialized_visual()
	var player := visual.get_animation_player()
	assert_not_null(player)

	for semantic: String in [
		"IDLE", "MOVE", "WALK", "RUN", "HIT", "ACTION_FALLBACK",
	]:
		var entry := profile.animation_profile.get(semantic, {}) as Dictionary
		var clip := StringName(entry.get("godot_name", ""))
		assert_ne(clip, &"", "mapping de profil : %s" % semantic)
		assert_true(
			player.has_animation(clip),
			"mapping de profil reel : %s -> %s" % [semantic, clip]
		)

	var animation_set := load(ANIMATION_SET_PATH) as CharacterAnimationSetData
	assert_not_null(animation_set)
	assert_eq(animation_set.configured_action_ids().size(), 9)
	for action_id: StringName in animation_set.configured_action_ids():
		var mapped_clip := animation_set.get_animation_name(action_id)
		assert_true(
			player.has_animation(mapped_clip),
			"mapping personnage reel : %s -> %s" % [action_id, mapped_clip]
		)


func test_the_four_achilles_spells_resolve_to_their_exact_clips() -> void:
	var animation_set := load(ANIMATION_SET_PATH) as CharacterAnimationSetData
	var visual := _create_initialized_visual()
	var player := visual.get_animation_player()
	for spell_id: StringName in EXPECTED_SPELL_CLIPS:
		var spell := load(String(SPELL_PATHS[spell_id])) as Spell
		assert_not_null(spell, String(SPELL_PATHS[spell_id]))
		assert_eq(spell.get_effective_spell_id(), spell_id)
		var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
			spell_id
		)
		var expected_clip := EXPECTED_SPELL_CLIPS[spell_id] as StringName
		assert_eq(animation_set.get_animation_name(action_id), expected_clip)
		assert_true(player.has_animation(expected_clip))


func test_adapter_uses_walk_for_five_steps_and_run_from_six_steps() -> void:
	var adapter := await _create_ready_adapter(_base_unit_data())
	var visual := adapter.viewport_backend.get_achilles_visual()
	var player := visual.get_animation_player()

	adapter.begin_path_movement_feedback(_straight_path(5))
	assert_eq(adapter._movement_action_id, &"walk")
	assert_eq(visual.get_active_semantic(), &"WALK")
	assert_eq(
		StringName(player.current_animation),
		&"achilles_v2__Walking"
	)

	adapter.cancel_movement_feedback()
	adapter.begin_path_movement_feedback(_straight_path(6))
	assert_eq(adapter._movement_action_id, &"run")
	assert_eq(visual.get_active_semantic(), &"RUN")
	assert_eq(
		StringName(player.current_animation),
		&"achilles_v2__run_fast_3_inplace"
	)
	adapter.cancel_movement_feedback()


func test_unknown_character_mapping_keeps_3d_and_uses_artistic_fallback() -> void:
	var probe_spell := Spell.new()
	probe_spell.spell_id = &"achilles_unknown_animation_probe"
	var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
		probe_spell.spell_id
	)
	var unit_data := _unit_data_with_mapping(
		action_id, &"achilles_v2__clip_that_does_not_exist"
	)
	var adapter := await _create_ready_adapter(unit_data)
	var visual := adapter.viewport_backend.get_achilles_visual()
	var player := visual.get_animation_player()

	assert_true(adapter.play_spell_action(probe_spell))
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_true(adapter.viewport_backend.is_backend_active())
	assert_null(adapter.fallback_backend)
	assert_eq(visual.get_active_semantic(), action_id)
	assert_eq(StringName(player.current_animation), ACTION_FALLBACK_CLIP)
	assert_true(adapter.get_last_backend_error().is_empty())
	adapter.cancel_pending_visual_actions()
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")


func test_long_clip_uses_dynamic_timeout_and_emits_each_signal_once() -> void:
	var probe_spell := Spell.new()
	probe_spell.spell_id = &"achilles_long_clip_probe"
	var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
		probe_spell.spell_id
	)
	var adapter := await _create_ready_adapter(_base_unit_data())
	var visual := adapter.viewport_backend.get_achilles_visual()
	var longest_clip := _longest_effective_pool_clip(visual, _profile())
	assert_ne(longest_clip, &"")

	var animation_set := (
		load(ANIMATION_SET_PATH) as CharacterAnimationSetData
	).duplicate(true) as CharacterAnimationSetData
	animation_set.set_animation_name(action_id, longest_clip)
	var unit_data := _base_unit_data().duplicate() as UnitData
	unit_data.animation_set = animation_set
	adapter.bind_unit(Unit.from_data(unit_data))

	var counters := {"started": 0, "released": 0, "finished": 0}
	var completed_actions: Array[StringName] = []
	adapter.viewport_backend.action_started.connect(
		func(_started_action: StringName) -> void: counters.started += 1
	)
	adapter.cast_release_reached.connect(
		func() -> void: counters.released += 1
	)
	adapter.animation_finished.connect(
		func(completed_action: StringName) -> void:
			counters.finished += 1
			completed_actions.append(completed_action)
	)

	var expected_timeout := visual.get_action_watchdog_seconds(
		action_id, longest_clip
	)
	assert_gt(expected_timeout, 2.0)
	assert_true(adapter.play_spell_action(probe_spell))
	assert_almost_eq(
		adapter._action_timeout_seconds,
		expected_timeout,
		0.001
	)
	assert_eq(counters.started, 1)

	visual._process(visual._action_finish_seconds + 0.01)
	visual._process(visual._action_finish_seconds + 0.01)
	assert_eq(counters.started, 1)
	assert_eq(counters.released, 1)
	assert_eq(counters.finished, 1)
	assert_eq(completed_actions, [action_id] as Array[StringName])


func test_hit_mapping_is_playable_and_never_emits_cast_signals() -> void:
	var unit := Unit.from_data(_base_unit_data())
	var adapter := await _create_ready_adapter()
	adapter.bind_unit(unit)
	var visual := adapter.viewport_backend.get_achilles_visual()
	var player := visual.get_animation_player()
	var counters := {"release": 0, "finish": 0}
	adapter.cast_release_reached.connect(
		func() -> void: counters.release += 1
	)
	adapter.animation_finished.connect(
		func(_action: StringName) -> void: counters.finish += 1
	)

	EventBus.hit_resolved.emit(CombatEventFact.create(
		&"hit_resolved",
		unit,
		null,
		{"amount_resolved": 4, "amount_applied": 4},
	))
	assert_eq(visual.get_active_semantic(), &"HIT")
	assert_eq(
		StringName(player.current_animation),
		&"achilles_v2__Hit_Reaction_1",
	)
	assert_eq(counters.release, 0)
	assert_eq(counters.finish, 0)
	visual._on_animation_player_finished(
		&"achilles_v2__Hit_Reaction_1"
	)
	assert_eq(visual.get_active_semantic(), &"IDLE")
	assert_eq(counters.release, 0)
	assert_eq(counters.finish, 0)


func test_action_restarts_even_when_its_clip_is_already_playing() -> void:
	var visual := _create_initialized_visual()
	var player := visual.get_animation_player()
	var clip := ACTION_FALLBACK_CLIP
	var animation := player.get_animation(clip)
	assert_not_null(animation)
	assert_true(visual._play_clip(clip, &"IDLE"))
	player.seek(animation.length * 0.9, true)
	assert_gt(player.current_animation_position, animation.length * 0.8)

	assert_true(visual.play_action(&"cast:restart_probe", clip))
	assert_eq(visual.get_active_semantic(), &"cast:restart_probe")
	assert_lt(player.current_animation_position, 0.01)


func _profile() -> AchillesVisualProfile:
	return load(PROFILE_PATH) as AchillesVisualProfile


func _base_unit_data() -> UnitData:
	var unit_data := (
		load(UNIT_DATA_PATH) as UnitData
	).duplicate(true) as UnitData
	unit_data.animation_set = load(ANIMATION_SET_PATH) as CharacterAnimationSetData
	return unit_data


func _create_initialized_visual() -> Achilles3DVisual:
	var visual := VISUAL_SCENE.instantiate() as Achilles3DVisual
	assert_not_null(visual)
	add_child_autofree(visual)
	assert_true(visual.initialize_from_profile(_profile()))
	assert_true(visual.is_initialized())
	return visual


func _create_ready_adapter(
		unit_data: UnitData = null
	) -> AchillesIsoUnitView:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	assert_not_null(adapter)
	adapter.visual_profile = _profile()
	add_child_autofree(adapter)
	if unit_data != null:
		adapter.bind_unit(Unit.from_data(unit_data))
	var deadline := Time.get_ticks_msec() + RUNTIME_READY_TIMEOUT_MSEC
	while adapter.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_true(adapter.viewport_backend.is_backend_active())
	assert_null(adapter.fallback_backend)
	return adapter


func _unit_data_with_mapping(
		action_id: StringName,
		clip: StringName
	) -> UnitData:
	var unit_data := _base_unit_data().duplicate() as UnitData
	var animation_set := (
		load(ANIMATION_SET_PATH) as CharacterAnimationSetData
	).duplicate(true) as CharacterAnimationSetData
	animation_set.set_animation_name(action_id, clip)
	unit_data.animation_set = animation_set
	return unit_data


func _straight_path(step_count: int) -> Array:
	var path: Array = []
	for x in range(step_count + 1):
		path.append(Vector2i(x, 0))
	return path


func _longest_effective_pool_clip(
		visual: Achilles3DVisual,
		profile: AchillesVisualProfile
	) -> StringName:
	var player := visual.get_animation_player()
	var longest_clip: StringName = &""
	var longest_duration := -1.0
	for clip: StringName in EXPECTED_POOL_CLIPS:
		var animation := player.get_animation(clip)
		if animation == null:
			continue
		var runtime := profile.runtime_for_clip(clip)
		var effective_duration := animation.length / maxf(
			float(runtime.get("speed_scale", 1.0)), 0.05
		)
		if effective_duration > longest_duration:
			longest_duration = effective_duration
			longest_clip = clip
	return longest_clip
