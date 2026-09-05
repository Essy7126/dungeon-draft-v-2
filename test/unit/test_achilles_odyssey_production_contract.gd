extends GutTest

const ODYSSEY_PATH := "res://data/runs/odyssey.tres"
const CONTENT_PATH := "res://data/runs/profiles/odyssey_content_profile.tres"
const MAIN_CONTENT_PATH := "res://data/runs/profiles/main_content_profile.tres"
const ACHILLES_DATA_PATH := "res://data/units/allies/achilles.tres"
const ACHILLES_VISUAL_PATH := "res://characters/achilles/AchillesIsoUnitView.tscn"
const ACHILLES_PREVIEW_PATH := "res://assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres"
const GUARD_VFX_PATH := "res://battle/vfx/achilles_guard_sprite_vfx.tscn"
const EXPECTED_SPELL_IDS: Array[StringName] = [
	&"achilles_peleid_strike", &"achilles_fulminant_dash",
	&"achilles_pelion_shot", &"achilles_bronze_guard",
]
const EXPECTED_DOCTRINE_IDS: Array[StringName] = [
	&"achilles_wrath_of_peleus", &"achilles_lesson_of_chiron", &"achilles_aegis_of_aeacus",
]
const PRODUCTION_COPY_PATHS: Array[String] = [
	CONTENT_PATH, ACHILLES_DATA_PATH,
	"res://data/ui/achilles_hud_theme_refined.tres",
	"res://data/spells/achilles/peleid_strike.tres",
	"res://data/spells/achilles/fulminant_dash.tres",
	"res://data/spells/achilles/pelion_shot.tres",
	"res://data/spells/achilles/bronze_guard.tres",
	"res://data/characters/achilles/doctrines/wrath_of_peleus.tres",
	"res://data/characters/achilles/doctrines/lesson_of_chiron.tres",
	"res://data/characters/achilles/doctrines/aegis_of_aeacus.tres",
]
const RETIRED_PRESENTATION_LABELS := [
	"prototype", "expérimental", "experimental", "vertical slice",
	"slice verticale", "discipline minimale",
]


func test_catabase_keeps_one_champion_and_the_three_current_room_routes() -> void:
	# The content resolver does not require room scenes. Inspect the authored route
	# separately so a room's imported enemy visuals cannot mask a champion regression.
	var content := load(CONTENT_PATH) as RunContentProfile
	assert_true(content.is_valid(), str(content.validation_errors()))
	assert_eq(content.profile_id, &"odyssey")
	assert_eq(content.hero_profiles.size(), 1)
	var hero_profile := content.hero_profiles[0]
	assert_eq(hero_profile.character_id, &"achilles")
	assert_eq(hero_profile.base_unit_data.resource_path, ACHILLES_DATA_PATH)
	assert_eq(hero_profile.progression_profile.character_id, &"achilles")
	var resolution := _resolve_content(content)
	assert_true(resolution.is_valid(), str(resolution.errors))
	assert_false(resolution.used_legacy_fallback)
	assert_eq(resolution.heroes.size(), 1)
	var runtime_data := resolution.heroes[0]
	assert_eq(runtime_data.get_effective_unit_id(), &"achilles")
	assert_eq(_spell_ids(runtime_data.spells), EXPECTED_SPELL_IDS)
	assert_true(runtime_data.progression_profile.uses_champion_progression())
	assert_eq(runtime_data.visual_scene, hero_profile.base_unit_data.visual_scene)
	assert_eq(runtime_data.preview_sprite_frames, hero_profile.base_unit_data.preview_sprite_frames)

	var source := FileAccess.get_file_as_string(ODYSSEY_PATH)
	assert_true(source.contains('run_name = "Catabase"'))
	assert_true(source.contains('path="%s"' % CONTENT_PATH))
	var room_pattern := RegEx.new()
	assert_eq(room_pattern.compile('path="(res://data/rooms/[^" ]+\\.tres)"'), OK)
	var room_paths: Array[String] = []
	for match_result in room_pattern.search_all(source):
		room_paths.append(match_result.get_string(1))
	assert_eq(room_paths, [
		"res://data/rooms/odyssey/room_01.tres",
		"res://data/rooms/odyssey/room_02.tres",
		"res://data/rooms/odyssey/room_03.tres",
	])
	for room_path in room_paths:
		assert_true(FileAccess.file_exists(room_path))
		var room_source := FileAccess.get_file_as_string(room_path)
		assert_true(room_source.contains("battle_scene = ExtResource("), room_path)
		assert_true(room_source.contains("encounter_definition = ExtResource("), room_path)
		assert_true(room_source.contains("hero_spawn_zone = Array[Vector2i]([Vector2i("), room_path)


func test_achilles_chassis_keeps_current_stats_combat_sprite_and_selection_preview() -> void:
	var data := load(ACHILLES_DATA_PATH) as UnitData
	assert_eq(data.get_effective_unit_id(), &"achilles")
	assert_eq([data.max_hp, data.initiative, data.max_ap, data.max_mp, data.attack_power], [110, 14, 6, 3, 18])
	assert_false(data.basic_attack_enabled)
	assert_eq(data.active_spell_slots, 4)
	assert_not_null(data.visual_scene)
	assert_eq(data.visual_scene.resource_path, ACHILLES_VISUAL_PATH)
	assert_not_null(data.preview_sprite_frames)
	assert_eq(data.preview_sprite_frames.resource_path, ACHILLES_PREVIEW_PATH)
	assert_eq(data.preview_sprite_animation, &"idle_E")
	assert_true(data.preview_sprite_frames.has_animation(data.preview_sprite_animation))
	assert_gt(data.preview_sprite_frames.get_frame_count(data.preview_sprite_animation), 0)
	assert_not_null(data.animation_set)
	for spell_id in EXPECTED_SPELL_IDS:
		assert_true(data.animation_set.has_animation_name(
			CharacterAnimationSetData.cast_action_id_for_spell_id(spell_id)
		), spell_id)


func test_four_champion_techniques_keep_their_scaling_movement_and_guard_contract() -> void:
	var progression := _champion_progression()
	assert_true(progression.is_valid(), str(progression.validation_errors()))
	assert_eq(progression.active_spell_slots, 4)
	assert_eq(_spell_ids(progression.spells), EXPECTED_SPELL_IDS)
	for spell in progression.spells:
		assert_true(spell.once_per_activation, spell.spell_name)
		assert_eq(spell.damage, 0, "Damage is calculated from Prouesse")
	var strike := progression.spells[0]
	assert_eq([strike.ap_cost, strike.minimum_range, strike.spell_range], [3, 1, 1])
	assert_eq(strike.damage_type, Spell.DamageType.PHYSICAL)
	assert_almost_eq(strike.damage_scaling.prowess_coefficient, 0.55, 0.0001)
	assert_eq(strike.skill_tree.discipline_id, EXPECTED_DOCTRINE_IDS[0])

	var dash := progression.spells[1]
	assert_eq([dash.ap_cost, dash.minimum_range, dash.spell_range], [1, 1, 3])
	assert_true(dash.line_from_caster)
	assert_true(dash.can_target_free_cell)
	assert_false(dash.can_target_enemy)
	assert_false(dash.needs_line_of_sight)
	assert_eq(dash.caster_movement, Spell.CasterMovement.TARGET_CELL)
	assert_true(dash.movement_requires_clear_path)
	assert_null(dash.damage_scaling)
	assert_null(dash.skill_tree, "The dash remains a base movement technique without a fourth doctrine")

	var shot := progression.spells[2]
	assert_eq([shot.ap_cost, shot.minimum_range, shot.spell_range], [3, 2, 6])
	assert_true(shot.needs_line_of_sight)
	assert_almost_eq(shot.damage_scaling.prowess_coefficient, 0.5, 0.0001)
	assert_eq(shot.skill_tree.discipline_id, EXPECTED_DOCTRINE_IDS[1])

	var guard := progression.spells[3]
	assert_eq([guard.ap_cost, guard.spell_range, guard.shield_grant], [2, 0, 0])
	assert_true(guard.is_self_only())
	assert_almost_eq(guard.shield_scaling.prowess_coefficient, 0.25, 0.0001)
	assert_almost_eq(guard.shield_scaling.max_hp_coefficient, 0.05, 0.0001)
	assert_eq(guard.shield_duration_activations, 1)
	assert_has(guard.shield_tags, &"guard")
	assert_has(guard.shield_tags, &"achilles_guard")
	assert_eq(guard.skill_tree.discipline_id, EXPECTED_DOCTRINE_IDS[2])
	assert_not_null(guard.vfx_scene)
	assert_eq(guard.vfx_scene.resource_path, GUARD_VFX_PATH)
	var effect := guard.vfx_scene.instantiate() as VFXShieldSpriteEffect
	assert_not_null(effect)
	assert_eq(effect.effect_id, &"achilles_guard_bronze")
	assert_eq(effect.profile.resource_path, "res://vfx/profiles/achilles_guard_bronze_v1/guard_profile.tres")
	effect.free()


func test_champion_uses_victory_xp_and_thirty_six_masteries_without_spell_xp() -> void:
	var progression := _champion_progression()
	assert_true(progression.uses_champion_progression())
	assert_false(progression.uses_legacy_cast_xp())
	var profile := progression.champion_progression_profile
	assert_eq(profile.level_cap, 14)
	assert_eq(profile.cumulative_xp_thresholds, PackedInt32Array([0, 100, 220, 360, 520, 700, 900, 1120, 1360, 1700, 1990, 2300, 2630, 2950]))
	assert_eq(profile.base_hp_by_level, PackedInt32Array([110, 135, 165, 200, 240, 290, 350, 420, 500, 600, 635, 675, 720, 770]))
	assert_eq(profile.base_prowess_by_level, PackedInt32Array([18, 22, 27, 33, 40, 48, 57, 68, 82, 100, 106, 112, 119, 127]))
	assert_eq([profile.first_capstone_level, profile.second_capstone_level, profile.purchased_mastery_cap], [10, 13, 3])
	var catalog := progression.mastery_catalog
	assert_eq(_discipline_ids(catalog.doctrines), EXPECTED_DOCTRINE_IDS)
	assert_eq(catalog.get_advanced_nodes().size(), 9)
	assert_eq(catalog.node_catalog().size(), 36)
	for doctrine in catalog.doctrines:
		assert_eq(SkillTreeResolver.champion_doctrine_nodes(doctrine).size(), 9, doctrine.display_name)
	var runtime_data := _resolve_content(load(CONTENT_PATH) as RunContentProfile).heroes[0]
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(runtime_data), runtime_data))
	assert_true(state.get_spell_progressions().is_empty())
	var snapshot := state.get_progression_snapshot()
	assert_true(state.add_spell_xp(EXPECTED_SPELL_IDS[0], 999).is_empty())
	assert_eq(state.get_progression_snapshot(), snapshot)
	state.begin_encounter()
	assert_true(state.award_encounter_xp(&"production_contract_victory", 100, true).granted)
	assert_eq(state.champion_progression.current_level, 2)
	assert_eq(state.champion_progression.unspent_mastery_points, 1)
	assert_eq(state.champion_progression.unspent_attribute_points, 1)
	state.dispose()


func test_main_trio_keeps_its_four_spells_and_legacy_cast_xp_progression() -> void:
	var content := load(MAIN_CONTENT_PATH) as RunContentProfile
	var resolution := _resolve_content(content)
	assert_true(resolution.is_valid(), str(resolution.errors))
	assert_eq(resolution.heroes.map(func(hero): return hero.get_effective_unit_id()), [&"elf", &"mage", &"warrior"])
	for index in range(resolution.heroes.size()):
		var hero := resolution.heroes[index]
		var authored := content.hero_profiles[index].base_unit_data
		assert_true(hero.progression_profile.uses_legacy_cast_xp())
		assert_null(hero.progression_profile.champion_progression_profile)
		assert_eq(_spell_ids(hero.spells), _spell_ids(authored.spells))
		assert_eq(hero.spells.size(), 4)
		assert_eq(hero.visual_scene, authored.visual_scene)
		var state := CharacterRunState.new()
		assert_true(state.initialize(Unit.from_data(hero), hero))
		assert_false(state.uses_champion_progression())
		assert_eq(state.get_disciplines().size(), 4)
		for spell in hero.spells:
			assert_eq(spell.skill_tree.ranks.size(), 5, spell.spell_name)
		var first := hero.spells[0]
		var earned := state.add_spell_xp(first.get_effective_spell_id(), first.skill_tree.ranks[1].required_total_xp)
		assert_false(earned.is_empty())
		assert_eq(state.get_pending_progression_choices().size(), 1)
		state.dispose()


func test_achilles_hud_icons_and_player_copy_are_production_ready() -> void:
	var data := load(ACHILLES_DATA_PATH) as UnitData
	var content := load(CONTENT_PATH) as RunContentProfile
	var progression := _champion_progression()
	var theme := CharacterHUDThemeCatalog.resolve_refined(Unit.from_data(data))
	assert_not_null(theme)
	assert_eq(theme.character_id, &"achilles")
	assert_true(theme.refined_components)
	for texture in [theme.portrait_texture, theme.move_action_icon, theme.utility_inventory_icon, theme.utility_map_icon, theme.utility_skills_icon]:
		assert_not_null(texture)
	var player_copy := [
		content.display_name, content.description, data.description, data.role,
		data.presentation_summary, data.progression_summary, data.presentation_badge,
		theme.display_name, theme.discipline_name,
	]
	for spell in progression.spells:
		assert_not_null(theme.get_spell_icon_for(spell), spell.resource_path)
		player_copy.append(spell.spell_name)
		player_copy.append(spell.description)
	for doctrine in progression.mastery_catalog.doctrines:
		player_copy.append(doctrine.display_name)
		player_copy.append(doctrine.description)
	for value in player_copy:
		var copy := str(value).strip_edges()
		assert_false(copy.is_empty())
		_assert_no_retired_labels(copy, copy)
	for path in PRODUCTION_COPY_PATHS:
		assert_true(FileAccess.file_exists(path), path)
		_assert_no_retired_labels(FileAccess.get_file_as_string(path), path)


func _assert_no_retired_labels(copy: String, context: String) -> void:
	for retired in RETIRED_PRESENTATION_LABELS:
		assert_false(copy.to_lower().contains(retired), "Libellé retiré '%s' dans %s" % [retired, context])


func _champion_progression() -> CharacterProgressionProfile:
	return (load(CONTENT_PATH) as RunContentProfile).hero_profiles[0].progression_profile


func _resolve_content(content: RunContentProfile) -> RunHeroResolution:
	var fixture := RunData.new()
	fixture.content_profile = content
	return RunHeroResolver.resolve_runtime_hero_data(fixture, false)


func _spell_ids(spells: Array[Spell]) -> Array[StringName]:
	var result: Array[StringName] = []
	for spell in spells:
		result.append(spell.get_effective_spell_id())
	return result


func _discipline_ids(disciplines: Array[DisciplineData]) -> Array[StringName]:
	var result: Array[StringName] = []
	for discipline in disciplines:
		result.append(discipline.discipline_id)
	return result
