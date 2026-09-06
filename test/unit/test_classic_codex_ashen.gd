extends GutTest
## Material layers must be neutral to layout/input; navigation stays consultative.

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
const SCREEN := preload("res://ui/progression/screens/skill_tree_screen.tscn")
const MAIN_CONTENT: RunContentProfile = preload("res://data/runs/profiles/main_content_profile.tres")

var _state: CharacterRunState
var _screen: SkillTreeScreen
var _reduced_motion_before := false


func before_each() -> void:
	_reduced_motion_before = GameManager.is_reduced_motion_enabled()


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.close_for_run_cleanup()
	if _state != null:
		_state.dispose()
		_state = null
	GameManager.set_reduced_motion_enabled(_reduced_motion_before)
	await wait_process_frames(2)


func test_panel_material_does_not_change_container_measurement_and_follows_resize() -> void:
	var panel := PanelContainer.new()
	panel.size = Vector2(420, 180)
	var content := Label.new()
	content.text = "Une maîtrise à explorer"
	panel.add_child(content)
	panel.add_theme_stylebox_override("panel", STYLE.box(Color.TRANSPARENT, STYLE.BORDER, 7, 12))
	add_child_autofree(panel)
	await wait_process_frames(3)
	var old_minimum := panel.get_combined_minimum_size()
	var old_content_rect := content.get_rect()
	STYLE.panel(panel, STYLE.SURFACE, STYLE.BORDER, 7, 12)
	STYLE.panel(panel, STYLE.INK, STYLE.BORDER, 7, 12)
	await wait_process_frames(3)
	assert_eq(panel.get_combined_minimum_size(), old_minimum, "Material cannot enlarge a container")
	assert_eq(content.get_rect(), old_content_rect, "Content keeps its layout and margins")
	assert_eq(panel.get_child_count(), 2, "Repeated skin application reuses its decorative bridge")
	var surface := panel.get_node("AshenMaterialLayer/MaterialSurface") as Control
	assert_true(panel.get_node("AshenMaterialLayer") is Node2D)
	assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(surface.focus_mode, Control.FOCUS_NONE)
	for target in [Vector2(320, 160), Vector2(720, 260)]:
		panel.size = target
		await wait_process_frames(2)
		assert_eq(surface.size, panel.size)
		assert_eq(surface.global_position, panel.global_position)


func test_material_created_before_ready_still_fits_its_real_panel() -> void:
	var panel := PanelContainer.new()
	panel.size = Vector2(340, 130)
	STYLE.panel(panel, STYLE.SURFACE, STYLE.BORDER, 7, 9)
	add_child_autofree(panel)
	await wait_process_frames(3)
	var surface := panel.get_node("AshenMaterialLayer/MaterialSurface") as Control
	assert_eq(surface.size, panel.size, "The viewport size must not override this panel's material")
	assert_eq(surface.position, Vector2.ZERO)
	assert_eq(surface.anchor_right, 0.0)
	assert_eq(surface.anchor_bottom, 0.0)


func test_classic_navigation_shortcuts_preserve_the_progression_snapshot() -> void:
	await _open_warrior()
	var snapshot := _state.get_progression_snapshot()
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F
	event.ctrl_pressed = true
	_screen._unhandled_input(event)
	var search := _screen.get("_search_field") as LineEdit
	assert_true(search.has_focus(), "Ctrl+F targets search")
	_screen.set_search_query("sort inexistant")
	assert_true(_screen.get_visible_tab_buttons().is_empty())
	_screen.set_search_query("")
	assert_eq(_screen.get_visible_tab_buttons().size(), 4)
	GameManager.set_reduced_motion_enabled(true)
	_screen.get_close_button().grab_focus()
	event.ctrl_pressed = false
	_screen._unhandled_input(event)
	assert_null(_screen.get("_recenter_tween"), "Reduced motion recenters without starting animation")
	assert_eq(_state.get_progression_snapshot(), snapshot, "Search and camera navigation cannot change progression")


func test_manual_panning_and_close_cancel_an_in_progress_recentering() -> void:
	await _open_warrior()
	GameManager.set_reduced_motion_enabled(false)
	_screen.center_on_inspected_node()
	assert_not_null(_screen.get("_recenter_tween"))
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.position = Vector2(60, 60)
	_screen._on_graph_scroll_gui_input(middle)
	assert_null(_screen.get("_recenter_tween"), "Manual navigation takes precedence over the animated camera")
	middle.pressed = false
	_screen._on_graph_scroll_gui_input(middle)
	_screen.center_on_inspected_node()
	assert_not_null(_screen.get("_recenter_tween"))
	_screen.close_screen()
	assert_null(_screen.get("_recenter_tween"), "A hidden screen cannot keep moving its camera")


func _open_warrior() -> void:
	var fixture := RunData.new()
	fixture.content_profile = MAIN_CONTENT
	var resolution := RunHeroResolver.resolve_runtime_hero_data(fixture, false)
	assert_true(resolution.is_valid())
	var hero_data: UnitData
	for candidate in resolution.heroes:
		if candidate.get_effective_unit_id() == &"warrior":
			hero_data = candidate
	assert_not_null(hero_data)
	_state = CharacterRunState.new()
	assert_true(_state.initialize(Unit.from_data(hero_data), hero_data))
	_screen = SCREEN.instantiate() as SkillTreeScreen
	add_child_autofree(_screen)
	assert_true(_screen.open_for_state(_state))
	await wait_process_frames(4)
