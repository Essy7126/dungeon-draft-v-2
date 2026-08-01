extends GutTest

const Factory = preload("res://test/support/factory.gd")
const HUD_SCENE := preload("res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn")
const COMPACT_LAYOUT := preload("res://data/ui/combat_hud_layout_run_v1_compact.tres")
const WARRIOR_VISUAL_SCENE := preload("res://characters/warrior/WarriorVisual3D.tscn")
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const GUARDIAN_PATH := "res://data/units/alliés/Gardien.tres"

const EXPECTED_SPELL_IDS := [
	&"warrior_shove",
	&"warrior_hook",
	&"warrior_shoulder_charge",
	&"warrior_shockwave",
	&"warrior_war_mark",
	&"warrior_execution",
	&"warrior_stomp",
	&"warrior_corrupted_ground",
]
const EXPECTED_DISCIPLINE_IDS := [
	&"warrior_breaker",
	&"warrior_executioner",
	&"warrior_ravager",
]
const EXPECTED_AP_COSTS := [1, 2, 3, 4, 2, 4, 2, 4]


func test_fixed_run_contract_keeps_three_heroes_and_guardian_loadable() -> void:
	var elf := load(ELF_PATH) as UnitData
	var mage := load(MAGE_PATH) as UnitData
	var warrior := load(WARRIOR_PATH) as UnitData
	assert_eq([elf.unit_id, mage.unit_id, warrior.unit_id], [&"elf", &"mage", &"warrior"])
	assert_not_null(load(GUARDIAN_PATH) as UnitData)
	assert_eq([elf.active_spell_slots, mage.active_spell_slots, warrior.active_spell_slots], [4, 4, 8])


func test_warrior_is_strictly_pa_pm_and_eight_spells_have_stable_contracts() -> void:
	var data := load(WARRIOR_PATH) as UnitData
	var warrior := Unit.from_data(data)
	assert_eq([warrior.max_ap.get_int(), warrior.max_mp.get_int()], [6, 3])
	assert_false(warrior.has_energy())
	assert_null(data.energy_type)
	assert_null(data.chassis_trait)
	assert_true(warrior.traits.is_empty())
	assert_eq(data.spells.size(), 8)
	assert_eq(
		data.spells.map(func(spell): return spell.spell_id),
		EXPECTED_SPELL_IDS
	)
	assert_eq(
		data.spells.map(func(spell): return spell.ap_cost),
		EXPECTED_AP_COSTS
	)
	for spell in data.spells:
		assert_eq(spell.fervor_cost, 0.0, spell.spell_name)
		assert_eq(spell.imprint_fervor_cost, 0.0, spell.spell_name)
		assert_eq(spell.energy_generated, 0.0, spell.spell_name)
		assert_eq(spell.charge_verb, "", spell.spell_name)
		assert_false(spell.can_imprint(), spell.spell_name)
		var description := spell.description.to_lower()
		for forbidden in ["ferv", "rage", "energie", "energy", "hit", "exploit", "ecole"]:
			assert_false(forbidden in description, "%s: %s" % [spell.spell_name, forbidden])
	warrior.clear_traits()


func test_warrior_disciplines_have_vertical_slice_thresholds_and_two_choices() -> void:
	var data := load(WARRIOR_PATH) as UnitData
	assert_eq(
		data.disciplines.map(func(discipline): return discipline.discipline_id),
		EXPECTED_DISCIPLINE_IDS
	)
	var spell_disciplines := {}
	for spell in data.spells:
		spell_disciplines[spell.spell_id] = spell.discipline_id
	assert_eq(spell_disciplines[&"warrior_shove"], &"warrior_breaker")
	assert_eq(spell_disciplines[&"warrior_hook"], &"warrior_breaker")
	assert_eq(spell_disciplines[&"warrior_shoulder_charge"], &"warrior_breaker")
	assert_eq(spell_disciplines[&"warrior_shockwave"], &"warrior_breaker")
	assert_eq(spell_disciplines[&"warrior_war_mark"], &"warrior_executioner")
	assert_eq(spell_disciplines[&"warrior_execution"], &"warrior_executioner")
	assert_eq(spell_disciplines[&"warrior_stomp"], &"warrior_ravager")
	assert_eq(spell_disciplines[&"warrior_corrupted_ground"], &"warrior_ravager")
	for discipline in data.disciplines:
		assert_true(SkillTreeResolver.validate_discipline(discipline).is_empty(), discipline.display_name)
		assert_eq(
			discipline.ranks.map(func(rank_data): return rank_data.required_total_xp),
			[0, 3, 7],
			discipline.display_name
		)
		assert_true(discipline.ranks[0].choices.is_empty(), discipline.display_name)
		assert_eq(discipline.ranks[1].choices.size(), 2, discipline.display_name)
		assert_eq(discipline.ranks[2].choices.size(), 2, discipline.display_name)
		for rank_index in [1, 2]:
			for choice in discipline.ranks[rank_index].choices:
				assert_eq(choice.spell_modifiers.size(), 1, choice.display_name)
				assert_eq(choice.excluded_node_ids.size(), 1, choice.display_name)


func test_successful_cast_grants_exactly_one_xp_and_choice_applies_modifier() -> void:
	var data := load(WARRIOR_PATH) as UnitData
	var warrior := Unit.from_data(data)
	var state := CharacterRunState.new()
	assert_true(state.initialize(warrior, data, data.active_spell_slots))
	var shove := data.spells[0] as Spell
	var service := CharacterProgressionService.new()
	var states := {&"warrior": state}
	for expected_xp in [1, 2, 3]:
		var result := service.grant_cast_xp(states, warrior, shove, {})
		assert_eq(result.gained_xp, 1)
		assert_eq(result.xp, expected_xp)
	var progress := state.get_discipline_progress(&"warrior_breaker")
	assert_eq(progress.rank, 2)
	assert_eq(progress.pending_rank_choices, [2])
	var choices := state.get_pending_progression_choices()
	assert_eq(choices.size(), 1)
	assert_eq(choices[0].choices.size(), 2)
	assert_true(state.select_upgrade(
		&"warrior_breaker",
		2,
		&"warrior_breaker_driving_shove"
	))
	assert_false(state.select_upgrade(
		&"warrior_breaker",
		2,
		&"warrior_breaker_long_hook"
	))
	assert_eq(warrior.get_progression_spell_modifiers().size(), 1)

	var battlefield := Factory.make_battlefield(8, 1)
	battlefield.grid.place_unit(warrior, Vector2i(0, 0))
	var enemy := Unit.new("Cible", 1, 100)
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	var report := battlefield.caster.cast(warrior, shove, Vector2i(1, 0))
	assert_false(report.get("failed", false))
	assert_eq(enemy.grid_pos, Vector2i(3, 0), "Bourrade passe reellement de 1 a 2 cases")
	state.dispose()
	warrior.clear_traits()


func test_warrior_uses_four_offensive_profiles_with_calibrated_durations() -> void:
	var visual := WARRIOR_VISUAL_SCENE.instantiate() as WarriorVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	var data := load(WARRIOR_PATH) as UnitData
	var expected_actions := {
		&"warrior_shove": WarriorVisual3D.ANIM_ATTACK,
		&"warrior_hook": WarriorVisual3D.ANIM_PARRY,
		&"warrior_shoulder_charge": WarriorVisual3D.ANIM_SPIN_ATTACK,
		&"warrior_shockwave": WarriorVisual3D.ANIM_SPIN_ATTACK,
		&"warrior_war_mark": WarriorVisual3D.ANIM_ATTACK,
		&"warrior_execution": WarriorVisual3D.ANIM_HEAVY_ATTACK,
		&"warrior_stomp": WarriorVisual3D.ANIM_SPIN_ATTACK,
		&"warrior_corrupted_ground": WarriorVisual3D.ANIM_HEAVY_ATTACK,
	}
	var used_actions := {}
	for spell in data.spells:
		var action := visual.get_animation_for_spell(spell)
		used_actions[action] = true
		assert_eq(action, expected_actions[spell.spell_id], spell.spell_name)
		assert_gt(visual.get_playback_speed_for_spell(spell), 0.0)
		assert_gte(visual.get_impact_normalized_for_spell(spell), 0.0)
		assert_lte(visual.get_impact_normalized_for_spell(spell), 1.0)
	assert_eq(used_actions.size(), 4)
	_assert_duration(visual, WarriorVisual3D.ANIM_ATTACK, 0.70, 0.90)
	_assert_duration(visual, WarriorVisual3D.ANIM_SPIN_ATTACK, 0.85, 1.10)
	_assert_duration(visual, WarriorVisual3D.ANIM_HEAVY_ATTACK, 0.95, 1.25)
	_assert_duration(visual, WarriorVisual3D.ANIM_PARRY, 0.50, 0.75)
	_assert_duration(visual, WarriorVisual3D.ANIM_HIT, 0.35, 0.60)
	_assert_duration(visual, WarriorVisual3D.ANIM_DEATH, 1.10, 1.60)


func test_compact_hud_fits_eight_slots_at_all_required_resolutions() -> void:
	var data := load(WARRIOR_PATH) as UnitData
	for resolution in [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		add_child_autofree(viewport)
		var hud = HUD_SCENE.instantiate()
		hud.skin_variant = 2
		hud.layout_data = COMPACT_LAYOUT
		viewport.add_child(hud)
		await wait_process_frames(2)
		var warrior := Unit.from_data(data)
		hud.update_info(warrior)
		hud.build_spell_buttons(warrior)
		hud._apply_layout_metrics()
		await wait_process_frames(1)
		var panel_size: Vector2 = hud.get_character_panel_size()
		assert_eq(hud.get("_spell_buttons").size(), 8, str(resolution))
		assert_lte(panel_size.x, float(resolution.x), str(resolution))
		assert_lte(panel_size.y / float(resolution.y), 0.1201, str(resolution))
		assert_false(hud.get_node("%EnergyBar").visible, str(resolution))
		assert_false(hud.get_node("%EnergyNameLabel").visible, str(resolution))
		assert_false(hud.get_node("%AwakeningButton").visible, str(resolution))
		assert_false(hud.get_node("%ReactionButton").visible, str(resolution))
		var character_anchor := hud.get_node("%CharacterAnchor") as Control
		var spell_anchor := hud.get_node("%SpellAnchor") as Control
		var turn_anchor := hud.get_node("%TurnAnchor") as Control
		assert_lte(character_anchor.position.x + character_anchor.size.x, spell_anchor.position.x, str(resolution))
		assert_lte(spell_anchor.position.x + spell_anchor.size.x, turn_anchor.position.x, str(resolution))
		assert_lte(turn_anchor.position.x + turn_anchor.size.x, float(resolution.x), str(resolution))
		warrior.clear_traits()


func test_compact_hud_handles_720p_edge_cases_and_real_keyboard_shortcuts() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var hud = HUD_SCENE.instantiate()
	hud.skin_variant = 2
	hud.layout_data = COMPACT_LAYOUT
	viewport.add_child(hud)
	await wait_process_frames(2)

	var warrior := Unit.from_data(load(WARRIOR_PATH) as UnitData)
	warrior.unit_name = "Guerrier de la Garde des Frontieres du Nord"
	hud.update_info(warrior)
	hud.build_spell_buttons(warrior)
	hud._apply_layout_metrics()
	await wait_process_frames(1)

	var name_label := hud.get_node("%CharacterName") as Label
	assert_eq(name_label.text, warrior.unit_name)
	assert_true(name_label.clip_text)
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	var buttons: Array = hud.get("_spell_buttons")
	assert_eq(buttons.size(), 8)
	var expected_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	for index in buttons.size():
		var button: Button = buttons[index]
		assert_not_null(button.shortcut, "shortcut %d" % (index + 1))
		assert_eq(button.shortcut.events.size(), 1, "shortcut %d" % (index + 1))
		assert_eq(
			(button.shortcut.events[0] as InputEventKey).physical_keycode,
			expected_keys[index],
			"shortcut %d" % (index + 1)
		)

	var first_button: Button = buttons[0]
	first_button.configure(warrior.spells[0], 12, 0.0, "", "1", false)
	assert_eq(first_button.get_node("%CostLabel").text, "12 PA")
	assert_gte(first_button.get_node("%CostLabel").get_theme_font_size("font_size"), 9)
	first_button.set_visual_state(RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	assert_true(first_button.disabled)
	first_button.mouse_entered.emit()
	await wait_process_frames(2)
	var tooltip = get_tree().get_first_node_in_group("keyword_tooltip_layer")
	assert_not_null(tooltip)
	assert_true((tooltip.get("_panel") as Control).visible)
	assert_string_contains((tooltip.get("_label") as RichTextLabel).text, warrior.spells[0].spell_name)
	tooltip.queue_free()
	warrior.clear_traits()


func _assert_duration(
		visual: WarriorVisual3D,
		animation_name: StringName,
		minimum: float,
		maximum: float
	) -> void:
	var duration := visual.get_calibrated_duration(animation_name)
	assert_gte(duration, minimum, "%s = %.3f" % [animation_name, duration])
	assert_lte(duration, maximum, "%s = %.3f" % [animation_name, duration])
