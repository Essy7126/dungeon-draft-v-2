extends GutTest

const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
)
const PRIMARY_BUTTON_SCENE := preload(
	"res://ui/recraft_hud_v1/components/primary_button/primary_button_view.tscn"
)
const RESOURCE_BAR_SCENE := preload(
	"res://ui/recraft_hud_v1/components/resource_bar/resource_bar_view.tscn"
)
const PORTRAIT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/portrait/portrait_view.tscn"
)
const VISUAL_SKIN := preload("res://data/ui/hud_visual_skin_neutral_v1.tres")


func test_spell_slot_states_have_distinct_non_color_cues() -> void:
	var slot := _spawn_spell_slot()

	slot.set_visual_state(RecraftSpellSlotView.VisualState.SELECTED)
	var selected_cues := slot.get_visual_cue_snapshot()
	assert_true(selected_cues.selected)
	assert_false(selected_cues.unavailable_cross)
	var selected_marker := slot.get_node("%SelectedMarker") as ColorRect
	assert_not_null(selected_marker)
	assert_true(selected_marker.visible)
	assert_eq(selected_marker.color, VISUAL_SKIN.border_selected_color)
	var cost_icon := slot.get_node("%CostIcon") as TextureRect
	assert_not_null(cost_icon)
	assert_true(cost_icon.visible)
	assert_same(cost_icon.texture, VISUAL_SKIN.icon_action_points)

	slot.set_visual_state(RecraftSpellSlotView.VisualState.DISABLED)
	var disabled_cues := slot.get_visual_cue_snapshot()
	assert_true(disabled_cues.disabled_bar)
	var disabled_bar := slot.get_node("%DisabledBar") as ColorRect
	assert_not_null(disabled_bar)
	assert_true(disabled_bar.visible)
	assert_eq(disabled_bar.color, VISUAL_SKIN.border_unavailable_color)
	assert_string_contains(slot.accessibility_name, "indisponible")

	slot.set_visual_state(RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	var unavailable_cues := slot.get_visual_cue_snapshot()
	assert_true(unavailable_cues.unavailable_cross)
	assert_false(unavailable_cues.disabled_bar)
	var state_glyph := slot.get_node("%StateGlyph") as TextureRect
	assert_not_null(state_glyph)
	assert_true(state_glyph.visible)
	assert_same(state_glyph.texture, VISUAL_SKIN.icon_unavailable)
	var cross_rotations := {
		"%UnavailableCrossA": PI / 4.0,
		"%UnavailableCrossB": -PI / 4.0,
	}
	for cross_path in cross_rotations:
		var cross := slot.get_node(cross_path) as ColorRect
		assert_not_null(cross, cross_path)
		assert_true(cross.visible, cross_path)
		assert_eq(cross.color, VISUAL_SKIN.border_unavailable_color, cross_path)
		assert_almost_eq(
			cross.rotation,
			float(cross_rotations[cross_path]),
			0.001,
			cross_path
		)
	assert_string_contains(slot.accessibility_name, "PA insuffisants")

	slot.set_visual_state(RecraftSpellSlotView.VisualState.COOLDOWN, 3)
	var cooldown_cues := slot.get_visual_cue_snapshot()
	assert_true(cooldown_cues.cooldown_disc)
	var cooldown_glyph := slot.get_node("%CooldownGlyph") as TextureRect
	assert_not_null(cooldown_glyph)
	assert_true(cooldown_glyph.visible)
	assert_same(cooldown_glyph.texture, VISUAL_SKIN.icon_cooldown)
	assert_eq(slot.get_node("%CooldownLabel").text, "3")
	assert_string_contains(slot.accessibility_name, "3 tour(s)")

	slot.set_visual_state(RecraftSpellSlotView.VisualState.LOCKED)
	var locked_cues := slot.get_visual_cue_snapshot()
	assert_true(locked_cues.locked_rails)
	var lock_icon := slot.get_node("%LockIcon") as TextureRect
	assert_not_null(lock_icon)
	assert_true(lock_icon.visible)
	assert_same(lock_icon.texture, VISUAL_SKIN.icon_locked)
	for rail_path in ["%LockRailLeft", "%LockRailRight"]:
		var rail := slot.get_node(rail_path) as ColorRect
		assert_not_null(rail, rail_path)
		assert_true(rail.visible, rail_path)
		assert_eq(rail.color, VISUAL_SKIN.border_locked_color, rail_path)
	assert_string_contains(slot.accessibility_name, "verrouillé")

	slot.set_selected_locked(true)
	var resolving_cues := slot.get_visual_cue_snapshot()
	assert_true(slot.disabled)
	assert_true(resolving_cues.selected)
	assert_true(resolving_cues.locked_rails)
	assert_string_contains(slot.accessibility_name, "résolution en cours")


func test_spell_slot_hover_focus_and_selection_are_not_conflated() -> void:
	var slot := _spawn_spell_slot()
	slot._on_mouse_entered()
	assert_true(slot.get_visual_cue_snapshot().hover)
	assert_eq(slot.visual_state, RecraftSpellSlotView.VisualState.HOVER)

	slot._on_mouse_exited()
	slot.grab_focus()
	await get_tree().process_frame
	var focus_cues := slot.get_visual_cue_snapshot()
	assert_true(focus_cues.focus)
	assert_false(focus_cues.selected)

	slot.set_visual_state(RecraftSpellSlotView.VisualState.SELECTED)
	var selected_cues := slot.get_visual_cue_snapshot()
	assert_true(selected_cues.focus)
	assert_true(selected_cues.selected)


func test_spell_slot_reduced_motion_keeps_state_cues_without_transform() -> void:
	var slot := _spawn_spell_slot()
	slot.set_reduced_motion(true)
	slot.set_visual_state(RecraftSpellSlotView.VisualState.SELECTED)

	assert_true(slot.is_reduced_motion_enabled())
	assert_eq(slot.scale, Vector2.ONE)
	assert_eq(slot.get_node("%VisualArea").position.y, 0.0)
	assert_true(slot.get_visual_cue_snapshot().selected)


func test_primary_button_distinguishes_hover_focus_selection_and_disabled() -> void:
	var button := _spawn_primary_button()
	button._on_mouse_entered()
	assert_true(button.get_visual_cue_snapshot().hover)
	var hover_rail := button.get_node("%HoverRail") as ColorRect
	assert_not_null(hover_rail)
	assert_true(hover_rail.visible)
	assert_eq(hover_rail.color, VISUAL_SKIN.border_focus_color)

	button._on_mouse_exited()
	button.grab_focus()
	await get_tree().process_frame
	var focus_cues := button.get_visual_cue_snapshot()
	assert_true(focus_cues.focus)
	assert_false(focus_cues.selected)
	var focus_overlay := button.get_node("%FocusOverlay") as Panel
	assert_not_null(focus_overlay)
	assert_true(focus_overlay.visible)

	button.set_active(true)
	var selected_cues := button.get_visual_cue_snapshot()
	assert_true(selected_cues.selected)
	var selection_overlay := button.get_node("%SelectionOverlay") as Panel
	assert_not_null(selection_overlay)
	assert_true(selection_overlay.visible)

	button.disabled = true
	button.refresh_visual_state(false)
	var disabled_cues := button.get_visual_cue_snapshot()
	assert_true(disabled_cues.disabled_bar)
	assert_false(disabled_cues.selected)
	var disabled_bar := button.get_node("%DisabledBar") as ColorRect
	assert_not_null(disabled_bar)
	assert_true(disabled_bar.visible)
	assert_eq(disabled_bar.color, VISUAL_SKIN.border_unavailable_color)


func test_primary_button_reduced_motion_disables_scale_feedback() -> void:
	var button := _spawn_primary_button()
	button.set_reduced_motion(true)
	button._on_mouse_entered()

	assert_true(button.is_reduced_motion_enabled())
	assert_eq(button.scale, Vector2.ONE)
	assert_true(button.get_visual_cue_snapshot().hover)


func test_resource_bar_uses_neutral_tokens_and_stops_delayed_motion() -> void:
	var bar := RESOURCE_BAR_SCENE.instantiate() as RecraftResourceBarView
	add_child_autofree(bar)
	bar.set_refined_style(true)
	bar.apply_visual_skin(VISUAL_SKIN)
	bar.set_resource(8.0, 10.0, Color.RED, null, "PV", true, false)
	assert_eq(bar.main_fill.color, VISUAL_SKIN.border_selected_color)
	assert_eq(bar.trough.color, VISUAL_SKIN.surface_recessed)
	assert_same(
		bar.value_label.get_theme_font("font"),
		VISUAL_SKIN.font_numeric,
	)
	bar.set_resource(2.0, 10.0, Color.RED, null, "PV", true, true)
	assert_eq(bar.main_fill.color, VISUAL_SKIN.text_primary)
	bar.set_reduced_motion(true)
	assert_true(bar.is_reduced_motion_enabled())
	assert_almost_eq(bar._delayed_value, bar.current_value, 0.001)
	assert_null(bar._delayed_tween)


func test_portrait_skin_keeps_active_state_readable_without_color() -> void:
	var portrait := PORTRAIT_SCENE.instantiate() as RecraftPortraitView
	add_child_autofree(portrait)
	portrait.apply_visual_skin(VISUAL_SKIN)
	portrait.set_portrait(null, "Achille")
	portrait.set_active(true)
	assert_true(portrait.active_indicator.visible)
	assert_eq(portrait.placeholder_label.text, "A")
	assert_same(
		portrait.placeholder_label.get_theme_font("font"),
		VISUAL_SKIN.font_emphasis,
	)
	var active_style := (
		portrait.active_indicator.get_theme_stylebox("panel") as StyleBoxFlat
	)
	assert_not_null(active_style)
	assert_eq(active_style.border_color, VISUAL_SKIN.border_focus_color)


func _spawn_spell_slot() -> RecraftSpellSlotView:
	var slot := SPELL_SLOT_SCENE.instantiate() as RecraftSpellSlotView
	add_child_autofree(slot)
	slot.set_refined_style(true)
	slot.apply_visual_skin(VISUAL_SKIN)
	slot.configure(null, 3, "1")
	return slot


func _spawn_primary_button() -> RecraftPrimaryButtonView:
	var button := PRIMARY_BUTTON_SCENE.instantiate() as RecraftPrimaryButtonView
	add_child_autofree(button)
	button.set_refined_style(true)
	button.apply_visual_skin(VISUAL_SKIN)
	button.set_label("Action")
	return button
