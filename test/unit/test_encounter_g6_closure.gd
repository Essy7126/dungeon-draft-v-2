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


func test_shell_uses_full_title_at_1280_and_safe_fallback_when_logically_narrow() -> void:
	assert_false(DungeonDraftStudioMain.uses_compact_title(1280.0))
	assert_true(DungeonDraftStudioMain.uses_compact_title(1024.0))
	assert_eq(StudioVersion.display_name(false), "DUNGEON DRAFT STUDIO 2.0.0")
	assert_eq(StudioVersion.display_name(true), "DD STUDIO 2.0.0")
