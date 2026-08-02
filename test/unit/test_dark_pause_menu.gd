extends GutTest

const MENU_SCENE := preload("res://ui/menus/dark_pause_menu.tscn")
const BUTTON_SCENE := preload("res://ui/components/dark_menu_button.tscn")
const RUN_UI_SCENE := preload("res://ui/run/PersistentRunUI.tscn")
const RUN_DATA := preload("res://data/runs/first_run.tres")
const THEME := preload("res://ui/themes/dark_pause_menu_theme.tres")
const GENERATED_DIRECTORY := "res://asset/ui/dark_menu/generated/"
const GENERATED_ASSETS := [
	"button_normal.png",
	"button_hover.png",
	"button_pressed.png",
	"close_button.png",
	"bottom_section.png",
	"title_header.png",
	"main_frame.png",
]


class FakeCombatContext:
	extends Node

	var active_unit = null

	func get_active_unit():
		return active_unit

	func _on_move_pressed() -> void:
		pass

	func _on_attack_pressed() -> void:
		pass

	func _on_spell_pressed(_spell) -> void:
		pass

	func _on_end_turn_pressed() -> void:
		pass


func after_each() -> void:
	get_tree().paused = false
	GameManager.cleanup_run_state()


func test_generated_assets_load_with_import_sidecars() -> void:
	for asset_name in GENERATED_ASSETS:
		var path: String = GENERATED_DIRECTORY + asset_name
		assert_true(FileAccess.file_exists(path), path)
		assert_true(FileAccess.file_exists(path + ".import"), path + ".import")
		assert_not_null(load(path), path)


func test_generated_assets_have_real_and_progressive_alpha() -> void:
	for asset_name in GENERATED_ASSETS:
		var path: String = GENERATED_DIRECTORY + asset_name
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image, path)
		image.convert(Image.FORMAT_RGBA8)
		var counts := _alpha_counts(image)
		assert_gt(counts[0], 0, path + " transparent")
		assert_gt(counts[1], 0, path + " progressive")
		assert_gt(counts[2], 0, path + " opaque")


func test_generated_assets_have_a_fully_transparent_outer_margin() -> void:
	for asset_name in GENERATED_ASSETS:
		var path: String = GENERATED_DIRECTORY + asset_name
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		image.convert(Image.FORMAT_RGBA8)
		for x in range(image.get_width()):
			assert_eq(image.get_pixel(x, 0).a, 0.0, path)
			assert_eq(
				image.get_pixel(x, image.get_height() - 1).a,
				0.0,
				path
			)
		for y in range(image.get_height()):
			assert_eq(image.get_pixel(0, y).a, 0.0, path)
			assert_eq(
				image.get_pixel(image.get_width() - 1, y).a,
				0.0,
				path
			)


func test_generated_imports_are_lossless_without_mipmaps() -> void:
	for asset_name in GENERATED_ASSETS:
		var path: String = GENERATED_DIRECTORY + asset_name + ".import"
		var import_text := FileAccess.get_file_as_string(path)
		assert_true("compress/mode=0" in import_text, path)
		assert_true("mipmaps/generate=false" in import_text, path)
		assert_true("process/fix_alpha_border=true" in import_text, path)


func test_pipeline_is_exterior_connected_and_preserves_sources() -> void:
	var script := FileAccess.get_file_as_string(
		"res://tools/ui/prepare_dark_menu_assets.py"
	)
	assert_true("queue: deque[int]" in script)
	assert_true("source_hashes" in script)
	assert_true("_unmix_background" in script)
	assert_true("Visual classification only" in script)
	assert_false("remove white" in script.to_lower())


func test_theme_uses_distinct_texture_states_and_focus_style() -> void:
	var normal := THEME.get_stylebox(
		&"normal",
		&"DarkMenuButton"
	) as StyleBoxTexture
	var hover := THEME.get_stylebox(
		&"hover",
		&"DarkMenuButton"
	) as StyleBoxTexture
	var pressed := THEME.get_stylebox(
		&"pressed",
		&"DarkMenuButton"
	) as StyleBoxTexture
	assert_not_null(normal)
	assert_not_null(hover)
	assert_not_null(pressed)
	assert_ne(normal.texture, hover.texture)
	assert_ne(hover.texture, pressed.texture)
	assert_not_null(THEME.get_stylebox(&"focus", &"DarkMenuButton"))


func test_reusable_button_supports_dynamic_text_disabled_and_size() -> void:
	var button := BUTTON_SCENE.instantiate() as DarkMenuButton
	add_child_autofree(button)
	await get_tree().process_frame
	button.minimum_button_size = Vector2(420.0, 62.0)
	button.configure("NOUVELLE ACTION", false)
	assert_eq(button.text, "NOUVELLE ACTION")
	assert_true(button.disabled)
	assert_eq(button.custom_minimum_size, Vector2(420.0, 62.0))
	button.configure("ACTION ACTIVE", true)
	assert_false(button.disabled)


func test_menu_contains_exact_labels_and_only_real_actions_enabled() -> void:
	var menu := await _spawn_menu()
	var expected := {
		&"resume": "REPRENDRE",
		&"characters": "PERSONNAGES",
		&"equipment": "ÉQUIPEMENTS",
		&"compendium": "COMPENDIUM",
		&"options": "OPTIONS",
		&"abandon": "ABANDONNER LA RUN",
		&"return_to_title": "RETOUR AU MENU PRINCIPAL",
	}
	for action_id in expected:
		var button := menu.get_action_button(action_id)
		assert_eq(button.text, expected[action_id], str(action_id))
	for action_id in [&"characters", &"equipment", &"compendium", &"options"]:
		assert_true(menu.get_action_button(action_id).disabled, str(action_id))
	for action_id in [&"resume", &"abandon", &"return_to_title"]:
		assert_false(menu.get_action_button(action_id).disabled, str(action_id))


func test_opening_focuses_resume_and_close_requests_resume() -> void:
	var menu := await _spawn_menu()
	var resume_count := [0]
	menu.resume_requested.connect(func(): resume_count[0] += 1)
	menu.open_menu()
	await get_tree().process_frame
	assert_true(menu.is_open())
	assert_same(
		menu.get_viewport().gui_get_focus_owner(),
		menu.get_action_button(&"resume")
	)
	var resume := menu.get_action_button(&"resume")
	assert_eq(resume.focus_mode, Control.FOCUS_ALL)
	assert_eq(
		resume.mouse_default_cursor_shape,
		Control.CURSOR_POINTING_HAND
	)
	assert_same(
		resume.get_node(resume.focus_neighbor_bottom),
		menu.get_action_button(&"abandon")
	)
	assert_same(
		resume.get_node(resume.focus_neighbor_top),
		menu.get_action_button(&"return_to_title")
	)
	assert_same(
		resume.get_theme_stylebox(&"normal"),
		THEME.get_stylebox(&"hover", &"DarkMenuButton")
	)
	menu.get_close_button().pressed.emit()
	assert_eq(resume_count[0], 1)


func test_dangerous_actions_require_confirmation() -> void:
	var menu := await _spawn_menu()
	var reasons: Array[StringName] = []
	menu.return_to_title_requested.connect(
		func(reason: StringName): reasons.append(reason)
	)
	menu.open_menu()
	menu.get_action_button(&"abandon").pressed.emit()
	assert_true(menu.has_open_confirmation())
	assert_true(menu.dismiss_confirmation())
	assert_true(reasons.is_empty())
	menu.get_action_button(&"return_to_title").pressed.emit()
	menu.get_confirmation_dialog().confirmed.emit()
	assert_eq(reasons, [&"return_to_title"])


func test_compact_layout_fits_1280_by_720_without_overlap() -> void:
	var menu := await _spawn_menu_in_viewport(Vector2i(1280, 720))
	_assert_layout(menu, Vector2(1280.0, 720.0), &"compact")


func test_medium_layout_fits_1920_by_1080_without_overlap() -> void:
	var menu := await _spawn_menu_in_viewport(Vector2i(1920, 1080))
	_assert_layout(menu, Vector2(1920.0, 1080.0), &"medium")


func test_large_layout_fits_2560_by_1440_without_overlap() -> void:
	var menu := await _spawn_menu_in_viewport(Vector2i(2560, 1440))
	_assert_layout(menu, Vector2(2560.0, 1440.0), &"large")


func test_menu_assets_use_linear_filtering_with_repeat_disabled() -> void:
	var menu := await _spawn_menu()
	var root := menu.get_node("%PauseRoot") as Control
	assert_eq(root.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(root.texture_repeat, CanvasItem.TEXTURE_REPEAT_DISABLED)


func test_persistent_run_ui_owns_exactly_one_pause_menu() -> void:
	assert_true(_prepare_run())
	var first := GameManager.get_persistent_run_ui()
	var second := GameManager._ensure_persistent_run_ui()
	assert_same(first, second)
	assert_not_null(first.get_pause_menu())
	assert_eq(
		first.get_children().filter(
			func(child: Node): return child is DarkPauseMenu
		).size(),
		1
	)


func test_pause_open_close_toggles_tree_and_combat_controls() -> void:
	assert_true(_prepare_run())
	var run_ui := GameManager.get_persistent_run_ui()
	var context := FakeCombatContext.new()
	add_child_autofree(context)
	run_ui.bind_combat_context(context)
	var hud := run_ui.get_combat_hud()
	hud.set_player_controls_enabled(true)

	assert_true(run_ui.open_pause_menu())
	assert_true(get_tree().paused)
	assert_false(bool(hud.get("_player_controls_enabled")))
	run_ui.get_pause_menu().get_action_button(&"resume").pressed.emit()
	assert_false(get_tree().paused)
	assert_true(bool(hud.get("_player_controls_enabled")))
	assert_true(run_ui.open_pause_menu())
	run_ui.get_pause_menu().get_close_button().pressed.emit()
	assert_false(run_ui.is_pause_menu_open())
	assert_false(get_tree().paused)


func test_ui_cancel_toggles_pause_and_transition_clears_it() -> void:
	assert_true(_prepare_run())
	var run_ui := GameManager.get_persistent_run_ui()
	var context := FakeCombatContext.new()
	add_child_autofree(context)
	run_ui.bind_combat_context(context)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true

	run_ui._unhandled_input(cancel)
	assert_true(run_ui.is_pause_menu_open())
	assert_true(get_tree().paused)
	run_ui._unhandled_input(cancel)
	assert_false(run_ui.is_pause_menu_open())
	assert_false(get_tree().paused)
	assert_true(run_ui.open_pause_menu())
	run_ui.set_ui_mode(PersistentRunUI.RunUIMode.TRANSITION)
	assert_false(run_ui.is_pause_menu_open())
	assert_false(get_tree().paused)


func test_pause_is_blocked_on_title_and_while_skill_tree_is_open() -> void:
	var standalone := RUN_UI_SCENE.instantiate() as PersistentRunUI
	add_child_autofree(standalone)
	await get_tree().process_frame
	standalone.set_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	assert_false(standalone.open_pause_menu())
	assert_false(get_tree().paused)

	assert_true(_prepare_run())
	var run_ui := GameManager.get_persistent_run_ui()
	var context := FakeCombatContext.new()
	add_child_autofree(context)
	run_ui.bind_combat_context(context)
	run_ui.get_skill_tree_screen().show()
	assert_false(run_ui.open_pause_menu())
	assert_false(get_tree().paused)


func _spawn_menu() -> DarkPauseMenu:
	var menu := MENU_SCENE.instantiate() as DarkPauseMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func _spawn_menu_in_viewport(viewport_size: Vector2i) -> DarkPauseMenu:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	add_child_autofree(viewport)
	var menu := MENU_SCENE.instantiate() as DarkPauseMenu
	viewport.add_child(menu)
	await get_tree().process_frame
	return menu


func _prepare_run() -> bool:
	return GameManager._prepare_preconfigured_run(
		RUN_DATA,
		[
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		]
	)


func _alpha_counts(image: Image) -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	var bytes := image.get_data()
	for index in range(3, bytes.size(), 4):
		var alpha := bytes[index]
		if alpha == 0:
			result[0] += 1
		elif alpha == 255:
			result[2] += 1
		else:
			result[1] += 1
	return result


func _assert_layout(
		menu: DarkPauseMenu,
		viewport_size: Vector2,
		expected_profile: StringName
	) -> void:
	var snapshot := menu.get_layout_snapshot()
	assert_eq(snapshot["profile"], expected_profile)
	var viewport := Rect2(Vector2.ZERO, viewport_size)
	var panel: Rect2 = snapshot["panel"]
	var header: Rect2 = snapshot["header"]
	var buttons: Rect2 = snapshot["main_buttons"]
	var bottom: Rect2 = snapshot["bottom"]
	assert_true(viewport.encloses(panel), str(snapshot))
	assert_true(panel.encloses(header), str(snapshot))
	assert_true(panel.encloses(buttons), str(snapshot))
	assert_true(panel.encloses(bottom), str(snapshot))
	assert_true(panel.encloses(snapshot["close"]), str(snapshot))
