extends GutTest

const PANEL_SCENE := preload("res://hub/ui/ArchivistPanel.tscn")
const ARCHIVIST_DATA := preload("res://hub/data/lanternbound_archivist.tres")
const ODYSSEY_RUN := preload("res://data/runs/odyssey.tres")
const ODYSSEY_ART_PATH := "res://asset/map/painted/greece/map2-_achilles.png"


func test_odyssey_selection_exposes_the_complete_french_dossier() -> void:
	var panel := await _make_panel(Vector2(1920, 1080))
	_select_run(panel, panel.find_run_index(ODYSSEY_RUN))
	var snapshot := panel.get_run_dossier_snapshot()
	var resolution := RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)
	assert_true(resolution.is_valid())
	assert_eq(resolution.heroes.size(), 1)
	var achilles := resolution.heroes[0] as UnitData
	assert_true(snapshot["odyssey"])
	assert_eq(snapshot["title"], ARCHIVIST_DATA.display_name)
	assert_eq(snapshot["run_name"], "CATABASE — L’ODYSSÉE D’ACHILLE")
	assert_eq(snapshot["hero_name"], achilles.unit_name.to_upper())
	assert_eq(snapshot["hero_stats"], "%d PV   ◆   %d PA   ◆   %d PM" % [
		achilles.max_hp,
		achilles.max_ap,
		achilles.max_mp,
	])
	assert_true((snapshot["run_meta"] as String).contains("3 SALLES"))
	assert_eq(snapshot["flow"], [
		"1  COMBAT",
		"2  RELIQUE",
		"3  SALLE SUIVANTE",
	])
	assert_true(snapshot["illustration_visible"])
	assert_true(snapshot["hero_portrait_visible"])
	assert_false(snapshot["room_selector_visible"])
	assert_eq(panel.run_illustration.texture.resource_path, ODYSSEY_ART_PATH)
	assert_eq(panel.confirm_run_button.text, "ENTRER DANS CATABASE")


func test_odyssey_dossier_is_contained_and_split_at_supported_resolutions() -> void:
	var panel := await _make_panel(Vector2(1280, 720))
	_select_run(panel, panel.find_run_index(ODYSSEY_RUN))
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080)]:
		panel.apply_viewport_size_for_test(viewport_size)
		await get_tree().process_frame
		var snapshot := panel.get_run_dossier_snapshot()
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		var panel_rect := snapshot["panel_rect"] as Rect2
		var dossier_rect := snapshot["dossier_rect"] as Rect2
		var illustration_rect := snapshot["illustration_rect"] as Rect2
		var details_rect := snapshot["details_rect"] as Rect2
		assert_true(_rect_contains(viewport_rect, panel_rect), str(viewport_size))
		assert_true(_rect_contains(panel_rect, dossier_rect), str(viewport_size))
		assert_true(_rect_contains(dossier_rect, illustration_rect), str(viewport_size))
		assert_true(_rect_contains(dossier_rect, details_rect), str(viewport_size))
		assert_lte(illustration_rect.end.x, details_rect.position.x, str(viewport_size))
		assert_gte(illustration_rect.size.x, 375.0, str(viewport_size))
		assert_gte(details_rect.size.x, 390.0, str(viewport_size))
		assert_lte(panel_rect.size.x, 1080.0, str(viewport_size))
		assert_lte(panel_rect.size.y, 700.0, str(viewport_size))


func test_non_odyssey_runs_keep_a_generic_selection_fallback() -> void:
	var panel := await _make_panel(Vector2(1280, 720))
	_select_run(panel, 0)
	var snapshot := panel.get_run_dossier_snapshot()
	assert_false(snapshot["odyssey"])
	assert_eq(snapshot["run_name"], "PRINCIPAL")
	assert_true((snapshot["run_meta"] as String).contains("6 SALLES"))
	assert_eq(snapshot["hero_name"], "ÉQUIPE D’EXPÉDITION")
	assert_eq(snapshot["flow"], [
		"1  COMBAT",
		"2  PROGRESSION",
		"3  SALLE SUIVANTE",
	])
	assert_false(snapshot["illustration_visible"])
	assert_false(snapshot["hero_portrait_visible"])
	assert_true(panel.illustration_fallback.visible)
	assert_true(panel.hero_glyph.visible)
	assert_true(snapshot["room_selector_visible"])
	assert_eq(panel.confirm_run_button.text, "LANCER LA RUN")


func test_focus_chain_skips_the_hidden_odyssey_room_selector() -> void:
	var panel := await _make_panel(Vector2(1280, 720))
	_select_run(panel, panel.find_run_index(ODYSSEY_RUN))
	assert_eq(
		panel.run_selector.focus_neighbor_bottom,
		panel.confirm_run_button.get_path(),
	)
	assert_eq(
		panel.confirm_run_button.focus_neighbor_top,
		panel.run_selector.get_path(),
	)
	_select_run(panel, 0)
	assert_eq(panel.run_selector.focus_neighbor_bottom, panel.room_selector.get_path())
	assert_eq(panel.room_selector.focus_neighbor_bottom, panel.confirm_run_button.get_path())


func test_run_identity_survives_catalog_reordering_and_profile_only_copies() -> void:
	var panel := await _make_panel(Vector2(1280, 720))
	var runs := ARCHIVIST_DATA.get_available_runs()
	var reordered: Array[RunData] = [ODYSSEY_RUN, runs[0], runs[1]]
	panel.set("_available_runs", reordered)
	assert_eq(panel.find_run_index(ODYSSEY_RUN), 0)
	var runtime_copy := ODYSSEY_RUN.duplicate(false) as RunData
	runtime_copy.set_path_cache("")
	assert_eq(panel.find_run_index(runtime_copy), 0)
	assert_true(panel.call("_is_odyssey_run", runtime_copy))


func test_archivist_title_uses_data_with_a_french_fallback() -> void:
	var panel := await _make_panel(Vector2(1280, 720))
	assert_eq(panel.title_label.text, ARCHIVIST_DATA.display_name)
	var fallback_data := LanternboundArchivistData.new()
	fallback_data.display_name = "  "
	panel.open_panel(fallback_data)
	assert_eq(panel.title_label.text, "ARCHIVISTE DES LANTERNES")


func _make_panel(viewport_size: Vector2) -> ArchivistPanel:
	var panel := PANEL_SCENE.instantiate() as ArchivistPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.apply_viewport_size_for_test(viewport_size)
	panel.open_panel(ARCHIVIST_DATA)
	panel._show_room_selection()
	await get_tree().process_frame
	return panel


func _select_run(panel: ArchivistPanel, item_index: int) -> void:
	panel.run_selector.select(item_index)
	panel.run_selector.item_selected.emit(item_index)


func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	const TOLERANCE := 1.0
	return inner.position.x >= outer.position.x - TOLERANCE \
		and inner.position.y >= outer.position.y - TOLERANCE \
		and inner.end.x <= outer.end.x + TOLERANCE \
		and inner.end.y <= outer.end.y + TOLERANCE
