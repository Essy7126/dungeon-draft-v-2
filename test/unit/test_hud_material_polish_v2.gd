extends GutTest

const HUD_SCENE := preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)
const FIXTURE_UNIT := preload("res://tools/ui_snapshots/hud_graybox_fixture_unit.gd")
const PREMIUM_SKIN: HudVisualSkinData = preload("res://data/ui/hud_visual_skin_achilles_v1.tres")
const NEUTRAL_SKIN: HudVisualSkinData = preload("res://data/ui/hud_visual_skin_neutral_v1.tres")
const PREMIUM_THEME: CharacterHUDThemeData = preload("res://data/ui/achilles_hud_theme_refined.tres")
const PREMIUM_LAYOUT: CombatHUDLayoutData = preload("res://data/ui/combat_hud_layout_run_v1_compact.tres")
const SPELLS: Array[Spell] = [
	preload("res://data/spells/achilles/spear_thrust.tres"),
	preload("res://data/spells/achilles/sweep.tres"),
	preload("res://data/spells/achilles/advance.tres"),
	preload("res://data/spells/achilles/guard.tres"),
]


func test_achilles_material_preset_is_complete_and_valid() -> void:
	assert_true(PREMIUM_SKIN.material_enabled)
	assert_not_null(PREMIUM_SKIN.material_texture)
	assert_false(PREMIUM_SKIN.neutral_grayscale)
	var issues := PREMIUM_SKIN.validation_issues()
	assert_eq(issues.size(), 0, "\n".join(issues))


func test_material_surface_is_a_decorative_shader_under_hud_band() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	await get_tree().process_frame
	var band := hud.get_node("%HudBand") as Control
	var surface := band.get_node_or_null("MaterialSurface") as Control
	assert_not_null(surface)
	if surface == null:
		return
	assert_same(surface.get_parent(), band)
	assert_true(surface.visible)
	assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(surface.focus_mode, Control.FOCUS_NONE)
	var shader_material := surface.material as ShaderMaterial
	assert_not_null(shader_material)
	if shader_material == null:
		return
	assert_not_null(shader_material.shader)
	assert_same(shader_material.get_shader_parameter("material_texture"), PREMIUM_SKIN.material_texture)
	assert_true(bool(shader_material.get_shader_parameter("has_texture")))


func test_neutral_skin_hides_the_material_after_a_premium_skin_switch() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	await get_tree().process_frame
	var surface := hud.get_node("%HudBand").get_node_or_null("MaterialSurface") as Control
	assert_not_null(surface)
	if surface == null:
		return
	hud.apply_visual_skin(NEUTRAL_SKIN)
	await get_tree().process_frame
	assert_false(surface.visible)
	hud.apply_visual_skin(PREMIUM_SKIN)
	await get_tree().process_frame
	assert_true(surface.visible)


func test_premium_tabs_are_named_radio_choices_without_disabled_active_tab() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	await get_tree().process_frame
	var spells_button := hud.get_node("%ShowSpellsButton") as Button
	var items_button := hud.get_node("%ShowItemsButton") as Button
	assert_true((hud.get_node("%BarToggleAnchor") as Control).visible)
	assert_eq(spells_button.text, "SORTS")
	assert_eq(items_button.text, "OBJETS")
	assert_true(spells_button.toggle_mode)
	assert_true(items_button.toggle_mode)
	assert_false(spells_button.disabled)
	assert_false(items_button.disabled)
	assert_true(spells_button.button_pressed)
	assert_false(items_button.button_pressed)
	items_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(hud.get_active_bar_mode(), "item")
	assert_false(spells_button.button_pressed)
	assert_true(items_button.button_pressed)
	assert_false(spells_button.disabled)
	assert_false(items_button.disabled)
	assert_false((hud.get_node("%SpellSlotsCenter") as Control).visible)
	assert_true((hud.get_node("%ItemSlotsCenter") as Control).visible)
	spells_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(hud.get_active_bar_mode(), "spell")
	assert_true(spells_button.button_pressed)
	assert_false(items_button.button_pressed)


func test_tab_switch_keeps_move_and_end_turn_at_the_same_positions() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	await get_tree().process_frame
	await get_tree().process_frame
	var end_turn := hud.get_node("%EndTurnButton") as Control
	var move := hud.get_node("%MoveButton") as Control
	var end_turn_rect := end_turn.get_global_rect()
	var move_rect := move.get_global_rect()
	for mode in ["item", "spell"]:
		hud._set_active_bar_mode(mode)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(end_turn.get_global_rect().is_equal_approx(end_turn_rect), mode)
		assert_true(move.get_global_rect().is_equal_approx(move_rect), mode)


func test_selected_spell_feedback_stays_above_tabs_and_context_feedback() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	var presentation := CombatPresentationState.new()
	hud.set_active_mode("spell", SPELLS[0])
	for phase in ["target", "resolve"]:
		if phase == "target":
			presentation.begin_targeting(&"spell")
		else:
			presentation.begin_resolution(&"spell")
		presentation.set_feedback("La ligne de vue est bloquée", &"error")
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		await get_tree().process_frame
		await get_tree().process_frame
		var plate := hud.get_node("%SelectedSpellPlate") as Control
		assert_true(plate.visible, phase)
		var plate_rect := plate.get_global_rect()
		for node_path in ["%ShowSpellsButton", "%ShowItemsButton", "%ContextFeedback"]:
			var other := hud.get_node(node_path) as Control
			assert_true(other.visible, "%s: %s" % [phase, node_path])
			assert_false(
				plate_rect.intersects(other.get_global_rect()),
				"%s: selected spell must not overlap %s" % [phase, node_path]
			)


func test_premium_layout_exposes_its_calibrated_offsets() -> void:
	assert_eq(PREMIUM_LAYOUT.premium_action_offset, 504.0)
	assert_eq(PREMIUM_LAYOUT.premium_turn_offset, 1072.0)
	assert_eq(PREMIUM_LAYOUT.premium_ability_offset, 110.0)
	assert_eq(PREMIUM_LAYOUT.premium_ability_width, 430.0)


func test_material_surface_tracks_configured_overall_size() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	var layout := context.layout as CombatHUDLayoutData
	await get_tree().process_frame
	var surface := hud.get_node("%HudBand").get_node_or_null("MaterialSurface") as Control
	assert_not_null(surface)
	if surface == null:
		return
	var viewport_width: float = hud.get_viewport().get_visible_rect().size.x
	var visual_scale: float = hud._base_chassis_visual_scale(viewport_width)
	_assert_surface_size(surface, layout, visual_scale)
	layout.overall_width = 1280.0
	layout.overall_height = 160.0
	hud._apply_layout_metrics()
	await get_tree().process_frame
	_assert_surface_size(surface, layout, visual_scale)
	var shader_material := surface.material as ShaderMaterial
	assert_not_null(shader_material)
	if shader_material != null:
		var shader_size: Vector2 = shader_material.get_shader_parameter("surface_size")
		assert_true(shader_size.is_equal_approx(surface.size))


func test_premium_offsets_reposition_only_their_configured_modules() -> void:
	var context := _spawn_hud_context()
	var hud = context.hud
	var layout := context.layout as CombatHUDLayoutData
	await get_tree().process_frame
	var move_host := hud.get_node("%MoveActionHost") as Control
	var spell_anchor := hud.get_node("%SpellAnchor") as Control
	var turn_anchor := hud.get_node("%TurnAnchor") as Control
	var move_x := move_host.position.x
	var spell_x := spell_anchor.position.x
	var turn_x := turn_anchor.position.x
	var spell_width := spell_anchor.size.x
	var viewport_width: float = hud.get_viewport().get_visible_rect().size.x
	var visual_scale: float = hud._chassis_visual_scale(viewport_width)
	layout.premium_action_offset += 24.0
	layout.premium_turn_offset += 20.0
	layout.premium_ability_offset += 8.0
	layout.premium_ability_width += 18.0
	hud._apply_layout_metrics()
	await get_tree().process_frame
	assert_almost_eq(move_host.position.x, move_x + 24.0 * visual_scale, 0.01)
	assert_almost_eq(spell_anchor.position.x, spell_x + 32.0 * visual_scale, 0.01)
	assert_almost_eq(turn_anchor.position.x, turn_x + 20.0 * visual_scale, 0.01)
	assert_almost_eq(spell_anchor.size.x, spell_width + 18.0 * visual_scale, 0.01)
	assert_eq(PREMIUM_LAYOUT.premium_action_offset, 504.0, "Only the duplicated fixture layout changes")


func _assert_surface_size(
		surface: Control,
		layout: CombatHUDLayoutData,
		visual_scale: float
	) -> void:
	assert_almost_eq(
		surface.size.x,
		layout.overall_width * visual_scale,
		0.01
	)
	assert_almost_eq(surface.size.y, layout.overall_height * visual_scale, 0.01)


func _spawn_hud_context() -> Dictionary:
	var fixture = FIXTURE_UNIT.new()
	fixture.configure_for_state(&"idle", SPELLS)
	var hud = HUD_SCENE.instantiate()
	var layout := PREMIUM_LAYOUT.duplicate(true) as CombatHUDLayoutData
	var themes: Array[CharacterHUDThemeData] = [PREMIUM_THEME]
	hud.skin_variant = 2
	hud.visual_skin = PREMIUM_SKIN
	hud.character_themes = themes
	hud.layout_data = layout
	add_child_autofree(hud)
	hud.set_ui_mode(0)
	hud.update_info(fixture)
	hud.build_spell_buttons(fixture)
	hud.set_reduced_motion(true)
	return {"hud": hud, "fixture": fixture, "layout": layout}
