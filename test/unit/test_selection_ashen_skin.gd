extends GutTest
## Interaction guarantees for decorative selection materials.

const SCREEN := preload("res://ui/selection/CharacterSelectionScreen.tscn")

var screen: CharacterSelectionScreen
var input_viewport: SubViewport


func before_each() -> void:
	# GUT owns an overlay in the root viewport. Isolate actual input picking from that test UI.
	input_viewport = SubViewport.new()
	input_viewport.size = Vector2i(1600, 900)
	add_child_autofree(input_viewport)
	screen = SCREEN.instantiate() as CharacterSelectionScreen
	input_viewport.add_child(screen)
	await wait_process_frames(4)
	await _move_pointer(Vector2(2, 2))


func after_each() -> void:
	# Do not leave a held synthetic button for the next test.
	await _mouse_button(Vector2(2, 2), false)


func test_material_layers_do_not_obscure_focus_or_intercept_their_controls() -> void:
	var controls: Array[Control] = []
	controls.assign(screen.find_children("*", "Button", true, false))
	controls.append_array(screen.find_children("*", "Panel", true, false))
	assert_gt(controls.size(), 20, "Review the real selection controls rather than a detached material sample")
	for control in controls:
		var surface := control.get_node_or_null("AshenSurface") as Control
		assert_not_null(surface, "%s has its material attached directly" % control.name)
		if surface == null:
			continue
		assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s cannot swallow mouse input" % control.name)
		assert_true(surface.show_behind_parent, "%s keeps native text and focus above the material" % control.name)
		assert_eq(surface.focus_mode, Control.FOCUS_NONE, "%s cannot steal keyboard focus" % control.name)
		assert_almost_eq(surface.size.x, control.size.x, 0.01)
		assert_almost_eq(surface.size.y, control.size.y, 0.01)
		if control is Button:
			for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				assert_true(control.has_theme_stylebox_override(state), "%s owns its %s style" % [control.name, state])
			var focus := control.get_theme_stylebox("focus") as StyleBoxFlat
			assert_not_null(focus, "Keyboard focus remains an independent frame")
			if focus != null:
				assert_eq(focus.bg_color.a, 0.0, "Focus never paints over the textured control")
				assert_gt(focus.border_width_top, 0, "Focus has a visible top edge")
				assert_gt(focus.border_width_bottom, 0, "Focus has a visible bottom edge")


func test_clicking_the_material_selects_the_real_hero_and_preserves_selected_state() -> void:
	var mage: Button = screen._roster_buttons[2]
	var achilles: Button = screen._roster_buttons[0]
	await _click(mage)
	assert_eq(screen.selected_index, 2, "A click through the decorative surface reaches Mage")
	assert_eq(screen.get_selected_entry().get("id"), &"mage")
	assert_true(mage.button_pressed)
	assert_true(_state(mage).get("selected", false))
	assert_false(_state(achilles).get("selected", true))
	await _move_pointer(Vector2(2, 2))
	assert_true(_state(mage).get("selected", false), "Moving the cursor away does not clear selection")
	assert_false(_state(mage).get("hovered", true))
	assert_eq(screen.get_selected_entry().get("run").resource_path, "res://data/runs/first_run.tres")


func test_button_surface_follows_hover_press_and_disabled_without_a_false_selection() -> void:
	var button := screen.find_child("RotateRight", true, false) as Button
	assert_not_null(button)
	if button == null:
		return
	var point := button.get_global_rect().get_center()
	await _move_pointer(point)
	assert_true(_state(button).get("hovered", false))
	assert_false(_state(button).get("selected", true))
	await _mouse_button(point, true)
	assert_true(_state(button).get("depressed", false), "A held mouse button uses the pressed material")
	await _mouse_button(point, false)
	assert_false(_state(button).get("depressed", true))
	await _mouse_button(point, true)
	button.disabled = true
	await wait_process_frames(2)
	assert_true(_state(button).get("disabled", false))
	assert_false(_state(button).get("depressed", true), "Disabling during a held press clears the depressed material")
	button.disabled = false
	await wait_process_frames(2)
	assert_false(_state(button).get("depressed", true), "Re-enabling before release cannot revive the interrupted press")
	button.disabled = true
	await wait_process_frames(2)
	await _mouse_button(point, false)
	var orientation := screen.orientation_index
	await _click(button)
	assert_eq(screen.orientation_index, orientation, "Disabled material does not imply an active control")
	assert_false(_state(button).get("depressed", true))
	button.disabled = false
	await wait_process_frames(2)
	assert_false(_state(button).get("disabled", true))
	assert_false(_state(button).get("depressed", true), "Re-enabling never restores a stale held press")


func test_selected_hover_keeps_both_states_and_does_not_take_keyboard_focus() -> void:
	var selected: Button = screen._roster_buttons[0]
	await _move_pointer(selected.get_global_rect().get_center())
	assert_true(_state(selected).get("selected", false))
	assert_true(_state(selected).get("hovered", false))
	selected.grab_focus()
	await wait_process_frames(2)
	assert_same(screen.get_viewport().gui_get_focus_owner(), selected)
	assert_ne(screen.get_viewport().gui_get_focus_owner(), selected.get_node("AshenSurface"))


func test_codex_opened_by_a_real_click_restores_its_visible_opening_button() -> void:
	for tab in range(2):
		screen.show_details(tab)
		await wait_process_frames(2)
		var opening_button: Button = screen._details.get_node("ExploreMasteries") if tab == 0 else screen._lore.get_node("ExploreMasteriesFromLore")
		await _click(opening_button)
		var codex := screen.get_spell_tree()
		assert_not_null(codex, "A click through the new material opens the codex")
		if codex == null:
			return
		codex.close_screen()
		await wait_process_frames(4)
		assert_same(screen.get_viewport().gui_get_focus_owner(), opening_button, "Closing returns focus to the visible control that opened the codex")
		assert_true(opening_button.is_visible_in_tree())


func _state(button: Button) -> Dictionary:
	var surface := button.get_node_or_null("AshenSurface")
	assert_not_null(surface)
	if surface == null or not surface.has_method("get_surface_state"):
		return {}
	return surface.get_surface_state()


func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	input_viewport.push_input(motion, true)
	await wait_process_frames(2)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	input_viewport.push_input(event, true)
	await wait_process_frames(2)


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	await _move_pointer(point)
	await _mouse_button(point, true)
	await _mouse_button(point, false)
