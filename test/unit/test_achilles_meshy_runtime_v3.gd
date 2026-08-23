extends GutTest

const PROFILE_PATH := "res://data/visuals/achilles/achilles_meshy_profile_v3.tres"
const UNIT_PATH := "res://data/units/allies/achilles.tres"
const ADAPTER_SCENE := preload("res://characters/achilles/AchillesIsoUnitView.tscn")
const READY_TIMEOUT_MSEC := 12000
const EXPECTED_ACTIONS: Array[StringName] = [
	&"Alert", &"Archery_Shot_3", &"Basic_Jump", &"Charged_Spell_Cast",
	&"Charged_Upward_Slash", &"Chest_Pound_Taunt",
	&"Double_Combo_Attack", &"Draw_and_Shoot_from_Back_2",
	&"Electrocution_Reaction", &"Hit_Reaction_1", &"Idle_11",
	&"Left_Slash", &"mage_soell_cast_7", &"run_fast_3_inplace",
	&"Running", &"Simple_Kick", &"Sword_Judgment",
	&"Sword_Parry_Backward_2", &"Triple_Combo_Attack", &"Walking",
]
const EXPECTED_SPELL_CLIPS := {
	&"achilles_spear_thrust": &"Left_Slash",
	&"achilles_advance": &"run_fast_3_inplace",
	&"achilles_sweep": &"Charged_Upward_Slash",
	&"achilles_guard": &"Sword_Parry_Backward_2",
}


func test_v3_is_the_direct_meshy_model_with_all_native_actions() -> void:
	var profile := load(PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_eq(profile.profile_id, &"achilles_meshy_animation_pool_v3")
	assert_eq(profile.expected_bone_count, 24)
	assert_eq(profile.root_motion_bone_names, [&"Hips"] as Array[StringName])
	assert_eq(profile.required_action_names, EXPECTED_ACTIONS)
	assert_eq(
		profile.skeleton_signature_mode,
		AchillesVisualProfile.SKELETON_SIGNATURE_MODE_EXACT_BONE_NAMES,
	)
	assert_true(profile.is_character_only_valid())

	var asset := load(profile.character_asset_path) as PackedScene
	assert_not_null(asset)
	var model := asset.instantiate() as Node3D
	add_child_autofree(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_eq(skeletons.size(), 1)
	assert_eq(meshes.size(), 1)
	assert_eq(players.size(), 1)
	if skeletons.size() != 1 or players.size() != 1:
		return
	assert_eq((skeletons[0] as Skeleton3D).get_bone_count(), 24)
	var imported_actions: Array[StringName] = []
	for action_name in (players[0] as AnimationPlayer).get_animation_list():
		if action_name != &"RESET":
			imported_actions.append(action_name)
	imported_actions.sort()
	var expected_sorted := EXPECTED_ACTIONS.duplicate()
	expected_sorted.sort()
	assert_eq(imported_actions, expected_sorted)


func test_idle_is_meshy_idle_and_does_not_chain_a_combat_clip() -> void:
	var context := await _ready_runtime()
	var visual := context.visual as Achilles3DVisual
	var player := visual.get_animation_player()
	assert_eq(visual.get_active_semantic(), &"IDLE")
	assert_eq(StringName(player.current_animation), &"Idle_11")
	assert_ne(StringName(player.current_animation), &"Anim_0_004")
	await wait_seconds(2.15)
	assert_eq(visual.get_active_semantic(), &"IDLE")
	assert_eq(StringName(player.current_animation), &"Idle_11")


func test_short_paths_walk_and_six_cells_run() -> void:
	var context := await _ready_runtime()
	var adapter := context.adapter as AchillesIsoUnitView
	var player := (context.visual as Achilles3DVisual).get_animation_player()
	adapter.begin_path_movement_feedback(_straight_path(5))
	await wait_process_frames(1)
	assert_eq(StringName(player.current_animation), &"Walking")
	adapter.cancel_movement_feedback()
	adapter.begin_path_movement_feedback(_straight_path(6))
	await wait_process_frames(1)
	assert_eq(StringName(player.current_animation), &"run_fast_3_inplace")
	adapter.cancel_movement_feedback()


func test_each_odyssey_spell_uses_its_native_meshy_clip() -> void:
	var context := await _ready_runtime()
	var adapter := context.adapter as AchillesIsoUnitView
	var player := (context.visual as Achilles3DVisual).get_animation_player()
	var runtime_data := RunHeroResolver.resolve_runtime_hero_data(
		load("res://data/runs/odyssey.tres") as RunData,
		false,
	).heroes[0] as UnitData
	for spell in runtime_data.spells:
		var spell_id := spell.get_effective_spell_id()
		assert_true(adapter.play_spell_action(spell), String(spell_id))
		await wait_process_frames(1)
		assert_eq(
			StringName(player.current_animation),
			EXPECTED_SPELL_CLIPS[spell_id] as StringName,
			String(spell_id),
		)
		adapter.cancel_spell_action()
		await wait_process_frames(1)
		assert_eq(StringName(player.current_animation), &"Idle_11")


func _ready_runtime() -> Dictionary:
	var adapter := ADAPTER_SCENE.instantiate() as AchillesIsoUnitView
	add_child_autofree(adapter)
	adapter.bind_unit(Unit.from_data(load(UNIT_PATH) as UnitData))
	var deadline := Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while adapter.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	var visual := adapter.viewport_backend.get_achilles_visual()
	assert_not_null(visual)
	return {"adapter": adapter, "visual": visual}


func _straight_path(step_count: int) -> Array:
	var path: Array = []
	for x in range(step_count + 1):
		path.append(Vector2i(x, 0))
	return path
