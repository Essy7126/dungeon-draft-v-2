extends GutTest

const HUD_SCENE := "res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
const FIRST_ROOM_SCENE := "res://data/rooms/maps/battle_salle1_iso.tscn"
const LEGACY_HUD_SCRIPT := "res://ui/action_bar.gd"
const PROCESSED_DIR := "res://asset/ui/recraft_hud_v1/processed"


func test_recraft_components_and_processed_assets_load() -> void:
	for path in [
		"%s/spell_slot_base.png" % PROCESSED_DIR,
		"%s/spellbar_panel.png" % PROCESSED_DIR,
		"%s/resource_bar_frame.png" % PROCESSED_DIR,
		"%s/portrait_frame.png" % PROCESSED_DIR,
		"%s/resource_badge_base.png" % PROCESSED_DIR,
		"%s/primary_button_base.png" % PROCESSED_DIR,
		HUD_SCENE,
	]:
		assert_true(ResourceLoader.exists(path), path)
		assert_not_null(load(path), path)


func test_first_room_selects_recraft_hud_and_battle_keeps_legacy_fallback() -> void:
	var packed := load(FIRST_ROOM_SCENE) as PackedScene
	assert_not_null(packed)
	var battle := packed.instantiate()
	assert_not_null(battle.get("action_bar_scene"))
	assert_eq(battle.get("action_bar_scene").resource_path, HUD_SCENE)
	battle.free()
	var battle_source := FileAccess.get_file_as_string("res://battle/battle.gd")
	assert_true("action_bar_scene" in battle_source)
	assert_true(LEGACY_HUD_SCRIPT in battle_source)


func test_first_room_launches_with_only_the_recraft_hud_active() -> void:
	GameManager.cleanup_run_state()
	var run := load("res://data/runs/run_default.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, [
		"res://data/units/alliés/elfe.tres",
		"res://data/units/alliés/mage.tres",
		"res://data/units/alliés/Gardien.tres",
	]))
	GameManager.current_room_index = 0
	var battle := (load(FIRST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(battle)
	assert_not_null(battle.action_bar)
	assert_eq(
		battle.action_bar.scene_file_path,
		HUD_SCENE
	)
	assert_eq(
		battle.action_bar.get_script().resource_path,
		"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd"
	)
	assert_true(battle.action_bar.end_turn_pressed.is_connected(
		Callable(battle, "_on_end_turn_pressed")
	))
	battle.free()
	GameManager.cleanup_run_state()


func test_hud_reads_real_unit_resources_and_builds_real_spell_slots() -> void:
	var guardian_data := load("res://data/units/alliés/Gardien.tres") as UnitData
	assert_not_null(guardian_data)
	var guardian := Unit.from_data(guardian_data)
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	hud.update_info(guardian)
	hud.build_spell_buttons(guardian)
	assert_eq(hud.get("_current_unit"), guardian)
	assert_eq(hud.get("_spell_buttons").size(), guardian.spells.size() + guardian.spells.filter(
		func(spell): return spell.can_imprint()
	).size())
	assert_eq(hud.get_node("%ActionPointsBadge/ValueLabel").text, str(guardian.current_ap))
	assert_eq(hud.get_node("%MovementPointsBadge/ValueLabel").text, str(guardian.current_mp))
	assert_eq(
		hud.get_node("%HealthBar/ValueLabel").text,
		"%d / %d" % [guardian.current_hp, guardian.max_hp.get_int()]
	)
	guardian.current_hp -= 9
	guardian.current_ap -= 1
	guardian.current_mp -= 1
	guardian.current_energy += 7.0
	guardian.hp_changed.emit(guardian)
	guardian.stats_changed.emit(guardian)
	guardian.energy_changed.emit(guardian)
	assert_eq(
		hud.get_node("%HealthBar/ValueLabel").text,
		"%d / %d" % [guardian.current_hp, guardian.max_hp.get_int()]
	)
	assert_eq(hud.get_node("%ActionPointsBadge/ValueLabel").text, str(guardian.current_ap))
	assert_eq(hud.get_node("%MovementPointsBadge/ValueLabel").text, str(guardian.current_mp))
	assert_eq(
		hud.get_node("%EnergyBar/ValueLabel").text,
		"%d / %d" % [int(guardian.current_energy), int(guardian.energy_type.max_energy)]
	)
	guardian.clear_traits()


func test_hud_selection_unaffordable_controls_and_end_turn_signal() -> void:
	var guardian := Unit.from_data(load("res://data/units/alliés/Gardien.tres"))
	guardian.current_ap = guardian.max_ap.get_int()
	guardian.current_energy = guardian.energy_type.max_energy
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	hud.update_info(guardian)
	hud.build_spell_buttons(guardian)
	var first_button: RecraftSpellSlotView = hud.get("_spell_buttons")[0]
	var first_spell: Spell = first_button.get_meta("spell")
	hud.set_active_mode("spell", first_spell, first_button.get_meta("imprinted", false))
	assert_eq(first_button.visual_state, RecraftSpellSlotView.VisualState.SELECTED)
	guardian.current_ap = 0
	guardian.stats_changed.emit(guardian)
	assert_eq(first_button.visual_state, RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	hud.set_player_controls_enabled(false)
	assert_true(hud.get_node("%MoveButton").disabled)
	assert_true(hud.get_node("%EndTurnButton").disabled)
	hud.set_player_controls_enabled(true)
	var end_turn_received := [false]
	hud.end_turn_pressed.connect(func() -> void: end_turn_received[0] = true)
	hud.get_node("%EndTurnButton").pressed.emit()
	assert_true(end_turn_received[0])
	guardian.clear_traits()


func test_hud_switch_disconnects_all_resource_signals() -> void:
	var guardian := Unit.from_data(load("res://data/units/alliés/Gardien.tres"))
	var warrior := Unit.from_data(load("res://data/units/alliés/Guerrier.tres"))
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	var callback := Callable(hud, "_on_resource_changed")
	hud.update_info(guardian)
	assert_true(guardian.hp_changed.is_connected(callback))
	assert_true(guardian.stats_changed.is_connected(callback))
	assert_true(guardian.energy_changed.is_connected(callback))
	hud.update_info(warrior)
	assert_false(guardian.hp_changed.is_connected(callback))
	assert_false(guardian.stats_changed.is_connected(callback))
	assert_false(guardian.energy_changed.is_connected(callback))
	assert_true(warrior.hp_changed.is_connected(callback))
	guardian.clear_traits()
	warrior.clear_traits()


func test_spell_slot_exposes_all_required_visual_states() -> void:
	var slot: RecraftSpellSlotView = load(
		"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
	).instantiate()
	add_child_autofree(slot)
	for state in RecraftSpellSlotView.VisualState.values():
		slot.set_visual_state(state, 2)
		assert_eq(slot.visual_state, state)
