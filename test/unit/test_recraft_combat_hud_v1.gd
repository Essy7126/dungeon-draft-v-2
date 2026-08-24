extends GutTest

const HUD_SCENE := "res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
const FIRST_ROOM_SCENE := "res://data/rooms/maps/painted_battle.tscn"
const PROCESSED_DIR := "res://asset/ui/recraft_hud_v1/processed"
const PARTY := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]

func after_each() -> void:
	GameManager.set_reduced_motion_enabled(false)
	GameManager.cleanup_run_state()

func test_recraft_components_and_processed_assets_load() -> void:
	for path in [
		"%s/spell_slot_base.png" % PROCESSED_DIR,
		"%s/spellbar_panel.png" % PROCESSED_DIR,
		"%s/resource_bar_frame.png" % PROCESSED_DIR,
		"%s/portrait_frame.png" % PROCESSED_DIR,
		HUD_SCENE,
	]:
		assert_true(ResourceLoader.exists(path), path)
		assert_not_null(load(path), path)

func test_first_room_binds_the_persistent_recraft_hud() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, PARTY))
	GameManager.current_room_index = 0
	var battle := (load(FIRST_ROOM_SCENE) as PackedScene).instantiate()
	add_child_autofree(battle)
	assert_not_null(battle.action_bar)
	assert_eq(battle.action_bar.scene_file_path, HUD_SCENE)
	assert_same(battle.action_bar, GameManager.get_persistent_run_ui().get_combat_hud())
	assert_not_null(battle.get("_hud_port"))
	assert_true(bool(battle.get("_hud_port").audit_contract()["valid"]))
	assert_true(battle.action_bar.end_turn_pressed.is_connected(
		Callable(battle, "_on_end_turn_pressed")
	))
	assert_not_null(battle.turn_order_timeline)
	assert_false(battle.units.is_empty())
	var inspected_unit := battle.units[0] as Unit
	battle._on_turn_order_unit_selected(inspected_unit)
	assert_true(battle.inspect_panel.visible)
	assert_same(battle.inspect_panel.get("_displayed_unit"), inspected_unit)
	assert_true(battle.inspect_panel.is_locked())
	battle.inspect_panel.release_lock()
	await get_tree().process_frame

func test_hud_builds_four_real_slots_for_every_fixed_hero() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, PARTY))
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	for hero in GameManager.get_ordered_heroes():
		hud.update_info(hero)
		hud.build_spell_buttons(hero)
		assert_eq(hud.get("_spell_buttons").size(), 4)
		assert_eq(hud.get("_current_unit"), hero)

func test_item_bar_reserves_its_space_and_survives_a_turn_change() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, PARTY))
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	await get_tree().process_frame
	var hero = GameManager.get_ordered_heroes()[0]
	hud.update_info(hero)
	hud.build_spell_buttons(hero)
	assert_eq(hud.get("_item_buttons").size(), 4, "Quatre emplacements d’objets")
	assert_eq(hud.get_active_bar_mode(), "spell")

	var spell_anchor := hud.get_node("%SpellAnchor") as Control
	var toggle_anchor := hud.get_node("%BarToggleAnchor") as Control
	var turn_anchor := hud.get_node("%TurnAnchor") as Control
	assert_gte(toggle_anchor.offset_left, spell_anchor.offset_right)
	assert_lte(toggle_anchor.offset_right, turn_anchor.offset_left)
	var turn_left_with_spells := turn_anchor.offset_left

	hud._set_active_bar_mode("item")
	await get_tree().process_frame
	assert_false((hud.get_node("%SpellSlotsCenter") as Control).visible)
	assert_true((hud.get_node("%ItemSlotsCenter") as Control).visible)
	assert_true(
		(hud.get_node("%BasicAttackHost") as Control).visible == hud.get("_attack_grouped_with_spells"),
		"L’attaque de base ne change pas de visibilité selon la barre affichée",
	)
	assert_eq(
		turn_anchor.offset_left,
		turn_left_with_spells,
		"L’espace des flèches est réservé en permanence : « Fin de tour » ne bouge pas",
	)

	EventBus.turn_started.emit(hero)
	hud.update_info(hero)
	hud.build_spell_buttons(hero)
	assert_eq(
		hud.get_active_bar_mode(),
		"item",
		"La vue choisie par le joueur n’est pas réinitialisée entre les tours",
	)


func test_number_shortcuts_follow_the_displayed_bar() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, PARTY))
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	await get_tree().process_frame
	var hero = GameManager.get_ordered_heroes()[0]
	hud.update_info(hero)
	hud.build_spell_buttons(hero)
	var spell_button := (hud.get("_spell_buttons") as Array)[0] as Button
	var item_button := (hud.get("_item_buttons") as Array)[0] as Button
	assert_not_null(spell_button.shortcut, "En vue sorts, la touche 1 lance le premier sort")
	assert_null(item_button.shortcut)

	hud._set_active_bar_mode("item")
	assert_null(spell_button.shortcut, "Les deux barres ne peuvent pas répondre à la même touche")
	assert_not_null(item_button.shortcut, "En vue objets, la touche 1 vise le premier objet")

	hud._set_active_bar_mode("spell")
	assert_not_null(spell_button.shortcut)
	assert_null(item_button.shortcut)


func test_primary_and_utility_actions_have_stable_keyboard_shortcuts() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	await get_tree().process_frame
	assert_eq(_shortcut_key(hud.get_node("%MoveButton")), KEY_M)
	assert_eq(_shortcut_key(hud.get_node("%AttackButton")), KEY_A)
	assert_eq(_shortcut_key(hud.get_node("%EndTurnButton")), KEY_F)
	assert_eq(_shortcut_key(hud.get_node("%InventoryButton")), KEY_I)
	assert_eq(_shortcut_key(hud.get_node("%SkillsButton")), KEY_K)

	hud.set_reduced_motion(true)
	assert_true(hud.is_reduced_motion_enabled())
	assert_true(hud.get_turn_intro_banner().is_reduced_motion_enabled())
	assert_almost_eq(hud.get_turn_intro_banner().total_animation_duration(), 0.72, 0.001)


func test_hud_switch_disconnects_hp_and_stats_signals() -> void:
	var first := Unit.from_data(load(PARTY[0]) as UnitData)
	var second := Unit.from_data(load(PARTY[1]) as UnitData)
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	var callback := Callable(hud, "_on_resource_changed")
	await get_tree().process_frame
	hud.update_info(first)
	assert_true(first.hp_changed.is_connected(callback))
	assert_true(first.stats_changed.is_connected(callback))
	hud.update_info(second)
	assert_false(first.hp_changed.is_connected(callback))
	assert_false(first.stats_changed.is_connected(callback))
	assert_true(second.hp_changed.is_connected(callback))
	assert_true(second.stats_changed.is_connected(callback))


func test_presentation_snapshot_controls_focus_ownership_and_feedback() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	await get_tree().process_frame
	hud.apply_presentation_snapshot({
		"phase_name": &"PLAYER_TARGETING",
		"ownership": &"player",
		"controls_enabled": true,
		"focus_active": true,
		"feedback_text": "Cible hors de portée.",
		"feedback_kind": &"warning",
	})
	assert_true(bool(hud.get("_player_controls_enabled")))
	assert_eq((hud.get_node("%TurnLabel") as Label).text, "VOTRE TOUR")
	assert_lt((hud.get_node("%CharacterSection") as Control).modulate.a, 1.0)
	assert_true((hud.get_node("%ContextFeedback") as Label).visible)

	hud.apply_presentation_snapshot({
		"phase_name": &"RESOLVING_ACTION",
		"ownership": &"system",
		"controls_enabled": false,
		"focus_active": false,
	})
	assert_false(bool(hud.get("_player_controls_enabled")))
	assert_eq((hud.get_node("%TurnLabel") as Label).text, "RÉSOLUTION")
	assert_false(
		(hud.get_node("%ContextFeedback") as Label).visible,
		"Un ancien refus de cible ne doit pas survivre a la resolution.",
	)


func _shortcut_key(button: Button) -> Key:
	if button.shortcut == null or button.shortcut.events.is_empty():
		return KEY_NONE
	var event := button.shortcut.events[0] as InputEventKey
	return event.physical_keycode if event != null else KEY_NONE
