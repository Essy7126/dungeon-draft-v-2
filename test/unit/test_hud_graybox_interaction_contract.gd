extends GutTest

const HUD_SCENE := preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)
const FIXTURE_UNIT := preload(
	"res://tools/ui_snapshots/hud_graybox_fixture_unit.gd"
)
const PREMIUM_SKIN: HudVisualSkinData = preload(
	"res://data/ui/hud_visual_skin_achilles_v1.tres"
)
const PREMIUM_THEME: CharacterHUDThemeData = preload(
	"res://data/ui/achilles_hud_theme_refined.tres"
)
const PREMIUM_LAYOUT: CombatHUDLayoutData = preload(
	"res://data/ui/combat_hud_layout_run_v1_compact.tres"
)
const SPELLS: Array[Spell] = [
	preload("res://data/spells/achilles/spear_thrust.tres"),
	preload("res://data/spells/achilles/sweep.tres"),
	preload("res://data/spells/achilles/advance.tres"),
	preload("res://data/spells/achilles/guard.tres"),
]


func test_snapshot_keeps_action_causality_from_targeting_to_resolution() -> void:
	var presentation := CombatPresentationState.new()
	assert_eq(presentation.get_snapshot().interaction_step, &"choose")

	presentation.begin_targeting(&"spell")
	var targeting := presentation.get_snapshot()
	assert_eq(targeting.interaction_step, &"target")
	assert_eq(targeting.selection_mode, &"spell")
	assert_true(targeting.selection_active)
	assert_true(targeting.selection_cancellable)

	presentation.begin_resolution(&"spell")
	var resolving := presentation.get_snapshot()
	assert_eq(resolving.interaction_step, &"resolve")
	assert_eq(resolving.selection_mode, &"spell")
	assert_true(resolving.selection_active)
	assert_false(resolving.selection_cancellable)
	assert_true(resolving.input_locked)
	assert_false(resolving.controls_enabled)

	presentation.begin_player_turn()
	var returned := presentation.get_snapshot()
	assert_eq(returned.interaction_step, &"choose")
	assert_eq(returned.selection_mode, &"")
	assert_false(returned.selection_active)


func test_targeting_keeps_identity_visible_and_prefixes_feedback() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	var presentation := CombatPresentationState.new()

	hud.set_active_mode("spell", SPELLS[0])
	presentation.begin_targeting(&"spell")
	presentation.set_feedback("La ligne de vue est bloquée", &"error")
	hud.apply_presentation_snapshot(presentation.get_snapshot())

	assert_eq(hud.get_node("%CharacterSection").modulate.a, 1.0)
	assert_eq(hud.get_node("%TurnSection").modulate.a, 1.0)
	assert_lt(hud.get_node("%UtilityDock").modulate.a, 1.0)
	assert_string_contains(hud.get_node("%SelectedSpellPlate").text, "CIBLAGE")
	assert_string_contains(hud.get_node("%SelectedSpellPlate").text, "FRAPPE")
	var feedback := hud.get_node("%ContextFeedback") as Label
	assert_true(feedback.text.begins_with("[X] ACTION REFUSÉE ·"))
	assert_string_contains(feedback.accessibility_name, "ACTION REFUSÉE")
	assert_string_contains(feedback.accessibility_name, "ligne de vue")


func test_resolution_keeps_selected_spell_locked_and_reduced_motion_propagated() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	var presentation := CombatPresentationState.new()
	var active_spell := SPELLS[1]

	hud.set_active_mode("spell", active_spell)
	presentation.begin_targeting(&"spell")
	hud.apply_presentation_snapshot(presentation.get_snapshot())
	presentation.begin_resolution(&"spell")
	hud.apply_presentation_snapshot(presentation.get_snapshot())

	var slots: Array = hud.get("_spell_buttons")
	assert_eq(slots.size(), SPELLS.size())
	var selected_slot := slots[1] as RecraftSpellSlotView
	assert_eq(
		selected_slot.visual_state,
		RecraftSpellSlotView.VisualState.SELECTED_LOCKED,
	)
	assert_true(selected_slot.disabled)
	var selected_cues := selected_slot.get_visual_cue_snapshot()
	assert_true(selected_cues.selected)
	assert_true(selected_cues.locked_rails)
	assert_string_contains(selected_slot.accessibility_name, "résolution en cours")
	assert_string_contains(hud.get_node("%SelectedSpellPlate").text, "RÉSOLUTION")

	for node_path in ["%MoveButton", "%AttackButton", "%EndTurnButton"]:
		var primary = hud.get_node(node_path)
		assert_true(primary.is_reduced_motion_enabled(), node_path)
		assert_eq(primary.scale, Vector2.ONE, node_path)
	for slot_value in slots:
		var spell_slot := slot_value as RecraftSpellSlotView
		assert_true(spell_slot.is_reduced_motion_enabled())
		assert_eq(spell_slot.scale, Vector2.ONE)
		assert_eq(spell_slot.get_node("%VisualArea").position.y, 0.0)
	for item_value in hud.get("_item_buttons"):
		var item_slot := item_value as RecraftItemSlotView
		assert_true(item_slot.is_reduced_motion_enabled())
		assert_eq(item_slot.scale, Vector2.ONE)


func test_premium_achilles_layout_keeps_exactly_four_actions_and_clean_identity() -> void:
	var context := _spawn_hud_context(true)
	var hud = context.hud
	var slots: Array = hud.get("_spell_buttons")

	assert_eq(slots.size(), 4)
	assert_false(hud.get_node("%AttackButton").visible)
	assert_false(hud.get_node("%SelectedSpellPlate").visible)
	assert_eq(
		hud.get_node("%ResourceBadges").get_parent(),
		hud.get_node("%CharacterRow"),
	)
	assert_true(hud.get_node("%InventoryButton").visible)
	assert_false(hud.get_node("%MapButton").visible)
	assert_true(hud.get_node("%SkillsButton").visible)
	for slot_value in slots:
		assert_true((slot_value as RecraftSpellSlotView).visible)


func _spawn_hud_context(premium: bool = false) -> Dictionary:
	var fixture = FIXTURE_UNIT.new()
	fixture.configure_for_state(&"idle", SPELLS)
	var hud = HUD_SCENE.instantiate()
	hud.skin_variant = 2
	if premium:
		var themes: Array[CharacterHUDThemeData] = [PREMIUM_THEME]
		hud.visual_skin = PREMIUM_SKIN
		hud.character_themes = themes
		hud.layout_data = PREMIUM_LAYOUT
	add_child_autofree(hud)
	hud.set_ui_mode(0)
	hud.update_info(fixture)
	hud.build_spell_buttons(fixture)
	hud.set_reduced_motion(true)
	return {
		"hud": hud,
		"fixture": fixture,
	}
