extends GutTest

const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
)
const ITEM_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/item_slot/item_slot_view.tscn"
)
const NEUTRAL_SKIN := preload("res://data/ui/hud_visual_skin_neutral_v1.tres")
const ACHILLES_SKIN := preload("res://data/ui/hud_visual_skin_achilles_v1.tres")


func test_corner_badges_scale_without_covering_the_illustration_center() -> void:
	var slot := _spawn_slot()
	slot.configure(null, 12, "4")
	for visual_size: float in [48.0, 64.0, 80.0]:
		slot.apply_calibrated_layout(visual_size, visual_size * 0.75, 14.0, 1.0)
		slot.size = Vector2.ONE * visual_size
		await get_tree().process_frame
		var center := Vector2.ONE * visual_size * 0.5
		var cost_rect := slot.cost_badge.get_rect()
		var shortcut_rect := slot.shortcut_label.get_rect()
		assert_false(cost_rect.has_point(center), str(visual_size))
		assert_false(shortcut_rect.has_point(center), str(visual_size))
		assert_lte(cost_rect.size.x, ceilf(visual_size * 0.6))
		assert_lte(cost_rect.size.y, ceilf(visual_size * 0.34))
		assert_lte(shortcut_rect.size.x, ceilf(visual_size * 0.38))
		assert_gte(cost_rect.position.x, 0.0)
		assert_gte(cost_rect.position.y, 0.0)
		assert_lte(cost_rect.end.x, visual_size)
		assert_lte(cost_rect.end.y, visual_size)
		assert_eq(slot.cost_label.text, "12")
		assert_gte(
			slot.cost_label.get_theme_font_size("font_size"),
			slot.shortcut_label.get_theme_font_size("font_size")
		)
		assert_eq(slot.custom_minimum_size, Vector2.ONE * visual_size)
		assert_eq(slot.scale, Vector2.ONE)


func test_empty_shortcut_has_no_empty_plate_and_can_be_restored() -> void:
	var slot := _spawn_slot()
	slot.configure(null, 3, "")
	assert_false(slot.shortcut_label.visible)
	slot.configure(null, 3, "2")
	assert_true(slot.shortcut_label.visible)
	assert_same(slot.shortcut_label.get_theme_font("font"), NEUTRAL_SKIN.font_numeric)


func test_frame_override_visibility_is_independent_of_setter_order() -> void:
	var slot := _spawn_slot()
	var texture := NEUTRAL_SKIN.icon_action_points
	slot.set_frame_override(texture)
	assert_true(slot.frame.visible)
	assert_false(slot.refined_frame.visible)
	assert_same(slot.frame.texture, texture)
	slot.set_frame_override(null)
	assert_false(slot.frame.visible)
	assert_true(slot.refined_frame.visible)
	slot.set_refined_style(false)
	slot.set_frame_override(texture)
	slot.set_refined_style(true)
	assert_true(slot.frame.visible)
	assert_false(slot.refined_frame.visible)


func test_cooldown_respects_opacity_tuning_and_keeps_the_count_readable() -> void:
	var slot := _spawn_slot(ACHILLES_SKIN)
	slot.set_polish_tuning(1.0, 0.62, 0.3)
	slot.set_visual_state(RecraftSpellSlotView.VisualState.COOLDOWN, 3)
	assert_almost_eq(slot.cooldown_overlay.color.a, 0.3, 0.001)
	assert_almost_eq(slot.cooldown_overlay.color.r, ACHILLES_SKIN.surface_scrim.r, 0.001)
	var shader_material := slot.spell_icon.material as ShaderMaterial
	assert_gt(float(shader_material.get_shader_parameter("brightness")), 0.8)
	assert_true(slot.get_visual_cue_snapshot().cooldown_disc)
	assert_eq(slot.cooldown_label.text, "3")
	assert_true(slot.cost_badge.visible)
	assert_true(slot.shortcut_label.visible)
	assert_true(slot.disabled)


func test_selected_locked_keeps_selection_but_not_available_icon_brightness() -> void:
	var slot := _spawn_slot(ACHILLES_SKIN)
	var shader_material := slot.spell_icon.material as ShaderMaterial
	slot.set_visual_state(RecraftSpellSlotView.VisualState.SELECTED)
	var selected_brightness := float(shader_material.get_shader_parameter("brightness"))
	slot.set_selected_locked(true)
	var locked_brightness := float(shader_material.get_shader_parameter("brightness"))
	assert_lt(locked_brightness, selected_brightness)
	assert_gte(locked_brightness, 0.75)
	assert_true(slot.get_visual_cue_snapshot().selected)
	assert_true(slot.get_visual_cue_snapshot().locked_rails)
	assert_true(slot.disabled)
	assert_string_contains(slot.accessibility_name, "résolution en cours")


func test_restyled_layers_do_not_intercept_input_or_change_action_state() -> void:
	var slot := _spawn_slot()
	for child in slot.find_children("*", "Control", true, false):
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, child.name)
	var enabled_states := [
		RecraftSpellSlotView.VisualState.NORMAL,
		RecraftSpellSlotView.VisualState.HOVER,
		RecraftSpellSlotView.VisualState.SELECTED,
	]
	for state: int in RecraftSpellSlotView.VisualState.values():
		slot.set_visual_state(state as RecraftSpellSlotView.VisualState, 2)
		assert_eq(slot.disabled, not state in enabled_states)


func test_item_reuses_the_polish_without_inventing_a_pa_cost_or_reason() -> void:
	var slot := ITEM_SLOT_SCENE.instantiate() as RecraftItemSlotView
	add_child_autofree(slot)
	slot.set_refined_style(true)
	slot.apply_visual_skin(ACHILLES_SKIN)
	var definition := ItemDefinition.new()
	definition.display_name = "Amulette de bronze"
	slot.configure_item(&"item_polish_test", definition, "5")
	slot.apply_availability({"available": false, "message": "Déjà utilisé ce tour"}, true)
	assert_false(slot.cost_badge.visible)
	assert_true(slot.shortcut_label.visible)
	assert_string_contains(slot.accessibility_name, definition.display_name)
	assert_string_contains(slot.accessibility_name, "Déjà utilisé ce tour")
	assert_false(slot.accessibility_name.contains("PA"))
	assert_eq(slot.visual_state, RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	slot.clear_item()
	assert_eq(slot.accessibility_name, "Emplacement d’objet vide")
	assert_false(slot.shortcut_label.visible)
	assert_true(slot.disabled)


func test_empty_item_slot_is_inert_without_the_unavailable_action_cues() -> void:
	var slot := ITEM_SLOT_SCENE.instantiate() as RecraftItemSlotView
	add_child_autofree(slot)
	slot.set_refined_style(true)
	slot.apply_visual_skin(ACHILLES_SKIN)
	slot.clear_item()
	assert_eq(slot.visual_state, RecraftSpellSlotView.VisualState.DISABLED)
	assert_true(slot.disabled)
	assert_false(slot.get_visual_cue_snapshot().disabled_bar)
	assert_false(slot.get_visual_cue_snapshot().unavailable_cross)
	assert_false(slot.disabled_overlay.visible)
	assert_false(slot.state_glyph.visible)
	assert_eq(slot.tooltip_text, "Emplacement d’objet vide")
	assert_eq(slot.accessibility_name, "Emplacement d’objet vide")
	var quiet_style := slot.refined_frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(quiet_style.border_color, ACHILLES_SKIN.border_subtle_color)
	var definition := ItemDefinition.new()
	definition.display_name = "Amulette de bronze"
	slot.configure_item(&"item_empty_cue_test", definition, "5")
	slot.apply_availability({"available": false, "message": "Déjà utilisé"}, true)
	assert_eq(slot.visual_state, RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	assert_true(slot.get_visual_cue_snapshot().unavailable_cross)
	assert_true(slot.disabled_overlay.visible)
	slot.apply_availability({"available": true}, false)
	assert_eq(slot.visual_state, RecraftSpellSlotView.VisualState.DISABLED)
	assert_true(slot.get_visual_cue_snapshot().disabled_bar)


func test_frame_and_selection_never_repaint_the_illustration_center() -> void:
	for skin: HudVisualSkinData in [NEUTRAL_SKIN, ACHILLES_SKIN]:
		var slot := _spawn_slot(skin)
		for state: int in RecraftSpellSlotView.VisualState.values():
			slot.set_visual_state(state as RecraftSpellSlotView.VisualState, 2)
			var frame_style := slot.refined_frame.get_theme_stylebox("panel") as StyleBoxFlat
			assert_false(frame_style.draw_center)
		var selection_style := slot.selection_overlay.get_theme_stylebox("panel") as StyleBoxFlat
		assert_false(selection_style.draw_center)


func test_icon_shader_does_not_multiply_the_source_texture_twice() -> void:
	var slot := _spawn_slot()
	var shader_material := slot.spell_icon.material as ShaderMaterial
	var shader_code := shader_material.shader.code
	assert_string_contains(shader_code, "icon_modulate = COLOR;")
	assert_string_contains(shader_code, "COLOR = source * icon_modulate;")
	assert_false(shader_code.contains("COLOR = source * COLOR;"))
	assert_string_contains(shader_code, "uniform float saturation")
	assert_string_contains(shader_code, "uniform float brightness")


func _spawn_slot(skin: HudVisualSkinData = NEUTRAL_SKIN) -> RecraftSpellSlotView:
	var slot := SPELL_SLOT_SCENE.instantiate() as RecraftSpellSlotView
	add_child_autofree(slot)
	slot.set_refined_style(true)
	slot.set_reduced_motion(true)
	slot.apply_visual_skin(skin)
	slot.configure(null, 3, "1")
	return slot
