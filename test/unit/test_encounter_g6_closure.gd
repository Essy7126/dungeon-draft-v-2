extends GutTest

## Régressions propres à la clôture G6 : les preuves graphiques restent dans
## le runner, ces tests verrouillent les contrats de disposition qui ont été
## corrigés à 1280 x 720 et à 125 %.


func test_validation_opens_with_room_for_a_complete_diagnostic_card() -> void:
	var ui := EncounterStudioMain.new()
	add_child_autofree(ui)
	await wait_process_frames(3)
	assert_gte(ui._validation_height, 250.0)
	assert_gte(ui.validation_panel.custom_minimum_size.y, 220.0)
	assert_lte(ui.map_preview.custom_minimum_size.y, 100.0)


func test_compact_legend_keeps_all_six_meanings() -> void:
	var text := " ".join(EncounterMapPreview.legend_lines_for_width(330.0))
	for expected in ["zone alliée", "zone ennemie", "case interdite",
			"ennemi placé", "survol", "sélection"]:
		assert_string_contains(text, expected)
	assert_eq(EncounterMapPreview.legend_lines_for_width(330.0).size(), 3)


func test_encounter_buttons_have_a_visible_local_focus_ring() -> void:
	var ui := EncounterStudioMain.new()
	add_child_autofree(ui)
	await wait_process_frames(3)
	var style := ui.forbidden_tool_toggle.get_theme_stylebox("focus") as StyleBoxFlat
	assert_not_null(style)
	assert_eq(style.border_color, Color(1.0, 0.82, 0.2, 1.0))
	assert_eq(style.border_width_left, 2)


func test_shell_title_follows_the_responsive_toolbar() -> void:
	var ui := DungeonDraftStudioMain.new()
	ui.arena_auto_load_enabled = false
	ui.arena_production_planning_enabled = false
	add_child_autofree(ui)
	await wait_process_frames(3)
	for width in [1024.0, 1280.0, 1920.0]:
		ui.size.x = width
		ui._apply_toolbar_responsive()
		assert_eq(ui.studio_title_label.text, StudioVersion.display_name(width < 1500.0))
