extends GutTest

const ODYSSEY_PATH := "res://data/runs/odyssey.tres"
const ACHILLES_DATA_PATH := "res://data/units/allies/achilles.tres"
const ACHILLES_VISUAL_PATH := (
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const ACHILLES_PREVIEW_PATH := (
	"res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb"
)
const EXPECTED_SPELL_IDS: Array[StringName] = [
	&"achilles_spear_thrust",
	&"achilles_advance",
	&"achilles_sweep",
	&"achilles_guard",
]
const EXPECTED_DISCIPLINE_IDS: Array[StringName] = [
	&"spear", &"advance", &"sweep", &"guard",
]
const PRODUCTION_COPY_PATHS: Array[String] = [
	"res://data/runs/profiles/odyssey_content_profile.tres",
	ACHILLES_DATA_PATH,
	"res://data/ui/achilles_hud_theme_refined.tres",
	"res://data/spells/achilles/spear_thrust.tres",
	"res://data/spells/achilles/advance.tres",
	"res://data/spells/achilles/sweep.tres",
	"res://data/spells/achilles/guard.tres",
	"res://data/characters/achilles/disciplines/spear.tres",
	"res://data/characters/achilles/disciplines/advance.tres",
	"res://data/characters/achilles/disciplines/sweep.tres",
	"res://data/characters/achilles/disciplines/guard.tres",
]
const RETIRED_PRESENTATION_LABELS := [
	"prototype",
	"expérimental",
	"experimental",
	"vertical slice",
	"slice verticale",
	"discipline minimale",
]


func test_odyssey_routes_one_production_achilles_through_all_three_rooms() -> void:
	var run := load(ODYSSEY_PATH) as RunData
	assert_not_null(run)
	assert_true(run.is_valid(), str(run.validation_errors()))
	assert_eq(run.rooms.size(), 3)
	assert_not_null(run.content_profile)
	assert_eq(run.content_profile.profile_id, &"odyssey")
	assert_eq(run.content_profile.hero_profiles.size(), 1)

	var hero_profile := run.content_profile.hero_profiles[0]
	assert_eq(hero_profile.character_id, &"achilles")
	assert_not_null(hero_profile.base_unit_data)
	assert_eq(hero_profile.base_unit_data.resource_path, ACHILLES_DATA_PATH)
	assert_not_null(hero_profile.progression_profile)
	assert_eq(hero_profile.progression_profile.character_id, &"achilles")

	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	assert_true(resolution.is_valid(), str(resolution.errors))
	assert_false(resolution.used_legacy_fallback)
	assert_eq(resolution.heroes.size(), 1)
	var runtime_data := resolution.heroes[0] as UnitData
	assert_not_null(runtime_data)
	assert_eq(runtime_data.get_effective_unit_id(), &"achilles")
	assert_eq(_spell_ids(runtime_data.spells), EXPECTED_SPELL_IDS)
	assert_eq(_discipline_ids(runtime_data.disciplines), EXPECTED_DISCIPLINE_IDS)
	for room_index in range(run.rooms.size()):
		var room := run.rooms[room_index]
		assert_not_null(room, "Salle %d" % (room_index + 1))
		assert_not_null(room.battle_scene, room.resource_path)
		assert_false(room.hero_spawn_zone.is_empty(), room.resource_path)
		assert_not_null(room.encounter_definition, room.resource_path)


func test_achilles_production_chassis_keeps_gameplay_values_and_v3_visuals() -> void:
	var data := load(ACHILLES_DATA_PATH) as UnitData
	assert_not_null(data)
	assert_eq(data.get_effective_unit_id(), &"achilles")
	assert_eq(
		[data.max_hp, data.initiative, data.max_ap, data.max_mp, data.attack_power],
		[110, 14, 6, 3, 18],
	)
	assert_false(data.basic_attack_enabled)
	assert_eq(data.active_spell_slots, 4)
	assert_not_null(data.visual_scene)
	assert_eq(data.visual_scene.resource_path, ACHILLES_VISUAL_PATH)
	assert_not_null(data.preview_visual_scene)
	assert_eq(data.preview_visual_scene.resource_path, ACHILLES_PREVIEW_PATH)
	assert_not_null(data.animation_set)
	for spell_id in EXPECTED_SPELL_IDS:
		var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
			spell_id
		)
		assert_true(data.animation_set.has_animation_name(action_id), spell_id)


func test_four_production_spells_and_disciplines_keep_their_combat_contract() -> void:
	var run := load(ODYSSEY_PATH) as RunData
	var progression := (
		run.content_profile.hero_profiles[0].progression_profile
		as CharacterProgressionProfile
	)
	assert_not_null(progression)
	assert_eq(progression.active_spell_slots, 4)
	assert_eq(_spell_ids(progression.spells), EXPECTED_SPELL_IDS)
	assert_eq(_discipline_ids(progression.disciplines), EXPECTED_DISCIPLINE_IDS)

	var spear := progression.spells[0]
	assert_eq(
		[spear.ap_cost, spear.minimum_range, spear.spell_range, spear.damage],
		[2, 1, 2, 9],
	)
	assert_eq(spear.damage_type, Spell.DamageType.PHYSICAL)
	assert_true(spear.once_per_activation)

	var advance := progression.spells[1]
	assert_eq(
		[advance.ap_cost, advance.minimum_range, advance.spell_range, advance.damage],
		[2, 1, 3, 5],
	)
	assert_true(advance.line_from_caster)
	assert_true(advance.once_per_activation)
	assert_eq(advance.modifiers.size(), 1)
	assert_eq(advance.modifiers[0].effect_type, 29)
	assert_true(advance.modifiers[0].movement_requires_clear_path)

	var sweep := progression.spells[2]
	assert_eq([sweep.ap_cost, sweep.spell_range, sweep.damage], [3, 0, 6])
	assert_eq(sweep.aoe_shape, Spell.AoeShape.CROSS)
	assert_eq(sweep.aoe_size, 1)
	assert_eq(sweep.push_distance, 1)
	assert_true(sweep.push_affected_units)
	assert_true(sweep.exclude_caster_from_area_effects)
	assert_true(sweep.is_self_only())
	assert_true(sweep.once_per_activation)

	var guard := progression.spells[3]
	assert_eq([guard.ap_cost, guard.spell_range, guard.shield_grant], [2, 0, 10])
	assert_true(guard.is_self_only())
	assert_true(guard.once_per_activation)

	for discipline in progression.disciplines:
		assert_eq(discipline.ranks.size(), 1, discipline.resource_path)
		assert_eq(discipline.ranks[0].rank, 1, discipline.resource_path)
		assert_true(
			discipline.ranks[0].choices.is_empty(),
			discipline.resource_path,
		)


func test_achilles_hud_and_player_copy_are_production_ready() -> void:
	var data := load(ACHILLES_DATA_PATH) as UnitData
	var run := load(ODYSSEY_PATH) as RunData
	var progression := run.content_profile.hero_profiles[0].progression_profile
	var theme := CharacterHUDThemeCatalog.resolve_refined(Unit.from_data(data))
	assert_not_null(theme)
	assert_eq(theme.character_id, &"achilles")
	assert_true(theme.refined_components)
	assert_not_null(theme.portrait_texture)
	assert_not_null(theme.move_action_icon)
	assert_not_null(theme.utility_inventory_icon)
	assert_not_null(theme.utility_map_icon)
	assert_not_null(theme.utility_skills_icon)

	var player_copy := [
		run.run_name,
		run.content_profile.display_name,
		run.content_profile.description,
		data.description,
		data.role,
		data.presentation_summary,
		data.progression_summary,
		data.presentation_badge,
		theme.display_name,
		theme.discipline_name,
	]
	for spell in progression.spells:
		assert_not_null(theme.get_spell_icon_for(spell), spell.resource_path)
		player_copy.append(spell.spell_name)
		player_copy.append(spell.description)
	for discipline in progression.disciplines:
		player_copy.append(discipline.display_name)
		player_copy.append(discipline.description)

	for copy_value in player_copy:
		var copy := str(copy_value).strip_edges()
		assert_false(copy.is_empty())
		var normalized := copy.to_lower()
		for retired_label in RETIRED_PRESENTATION_LABELS:
			assert_false(
				normalized.contains(retired_label),
				"Libellé retiré '%s' trouvé dans : %s" % [retired_label, copy],
			)

	for resource_path in PRODUCTION_COPY_PATHS:
		assert_true(FileAccess.file_exists(resource_path), resource_path)
		var source := FileAccess.get_file_as_string(resource_path).to_lower()
		for retired_label in RETIRED_PRESENTATION_LABELS:
			assert_false(
				source.contains(retired_label),
				"Libellé retiré '%s' trouvé dans %s" % [
					retired_label,
					resource_path,
				],
			)


func _spell_ids(spells: Array[Spell]) -> Array[StringName]:
	var result: Array[StringName] = []
	for spell in spells:
		result.append(spell.get_effective_spell_id())
	return result


func _discipline_ids(
		disciplines: Array[DisciplineData]
	) -> Array[StringName]:
	var result: Array[StringName] = []
	for discipline in disciplines:
		result.append(discipline.discipline_id)
	return result
