extends GutTest

const TRANSITION_SCENE := preload("res://ui/Transitionsalle.tscn")


func _odyssey_snapshot(room_number := 2) -> Dictionary:
	return {
		"available": true,
		"run_name": "Catabase",
		"room_name": "Catabase II — La Porte des Cendres",
		"room_number": room_number,
		"room_total": 3,
		"enemy_count": 3,
		"wave_count": 1,
		"heroes": [{
			"name": "Achille",
			"current_hp": 64,
			"max_hp": 110,
		}],
		"background": null,
	}


func _spawn_screen():
	var screen = TRANSITION_SCENE.instantiate()
	add_child_autofree(screen)
	return screen


func test_odyssey_dossier_exposes_room_threat_achilles_and_progress() -> void:
	var screen = _spawn_screen()
	screen.apply_runtime_snapshot_for_test(_odyssey_snapshot(), true)
	await wait_process_frames(2)
	var snapshot: Dictionary = screen.get_presentation_snapshot_for_test()
	assert_eq(snapshot.room_number, "SALLE II / III")
	assert_eq(snapshot.room_name, "LA PORTE DES CENDRES")
	assert_eq(snapshot.run_eyebrow, "DOSSIER DE L’ARCHIVISTE · CATABASE")
	assert_eq(snapshot.hero_count, 1)
	assert_eq(snapshot.threat, "MENACE · ÉLEVÉE")
	assert_eq(snapshot.threat_detail, "3 adversaires · 1 engagement")
	assert_eq(snapshot.progress, "2 / 3")
	assert_eq(snapshot.progress_step_count, 3)
	assert_eq(snapshot.cta, "ENTRER DANS LA SALLE II")
	var hero_row := screen.heroes_container.get_child(0) as HBoxContainer
	assert_eq((hero_row.get_child(0) as Label).text, "Achille")
	assert_eq((hero_row.get_child(1) as ProgressBar).value, 64.0)
	assert_eq((hero_row.get_child(1) as ProgressBar).max_value, 110.0)
	assert_eq((hero_row.get_child(2) as Label).text, "64 / 110 PV")
	assert_eq(screen.get_viewport().gui_get_focus_owner(), screen.bouton)


func test_generic_runs_keep_a_neutral_multi_hero_fallback() -> void:
	var screen = _spawn_screen()
	screen.apply_runtime_snapshot_for_test({
		"available": true,
		"run_name": "Première aventure",
		"room_name": "Salle 2 - Avant-poste montagneux",
		"room_number": 2,
		"room_total": 4,
		"enemy_count": 0,
		"wave_count": 0,
		"heroes": [
			{"name": "Guerrier", "current_hp": 80, "max_hp": 100},
			{"name": "Mage", "current_hp": 45, "max_hp": 75},
			{"name": "Elfe", "current_hp": 62, "max_hp": 70},
		],
	}, true)
	var snapshot: Dictionary = screen.get_presentation_snapshot_for_test()
	assert_eq(snapshot.room_name, "AVANT-POSTE MONTAGNEUX")
	assert_eq(snapshot.run_eyebrow, "DOSSIER DE ROUTE · PREMIÈRE AVENTURE")
	assert_eq(snapshot.hero_count, 3)
	assert_false(snapshot.threat_visible)
	assert_eq(snapshot.progress_step_count, 4)


func test_reference_resolutions_keep_a_safe_readable_dossier() -> void:
	var screen = _spawn_screen()
	var compact: Dictionary = screen.apply_viewport_size_for_test(
		Vector2(1280.0, 720.0)
	)
	assert_eq(compact.profile, &"compact")
	assert_lte(compact.dossier_minimum.x, 1240.0)
	assert_lte(compact.dossier_minimum.y, 688.0)
	assert_gte(compact.dossier_minimum.x, 720.0)
	assert_eq(compact.background_stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_gte(compact.overlay_alpha, 0.70)
	var wide: Dictionary = screen.apply_viewport_size_for_test(
		Vector2(1920.0, 1080.0)
	)
	assert_eq(wide.profile, &"wide")
	assert_lte(wide.dossier_minimum.x, 1824.0)
	assert_lte(wide.dossier_minimum.y, 1012.0)
	assert_gt(wide.title_font_size, compact.title_font_size)
	assert_gt(wide.cta_minimum.y, compact.cta_minimum.y)


func test_rendered_dossier_stays_inside_safe_area_at_reference_sizes() -> void:
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var screen = _spawn_screen()
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		screen.position = Vector2.ZERO
		screen.size = viewport_size
		var layout: Dictionary = screen.apply_viewport_size_for_test(viewport_size)
		screen.apply_runtime_snapshot_for_test(_odyssey_snapshot(), true)
		await wait_process_frames(2)

		var safe_origin := Vector2(layout.safe_left, layout.safe_top)
		var safe_rect := Rect2(
			safe_origin,
			viewport_size - safe_origin * 2.0,
		)
		var dossier_rect: Rect2 = screen.dossier.get_global_rect()
		var content_rect: Rect2 = screen.content.get_global_rect()
		assert_true(
			safe_rect.encloses(dossier_rect),
			"Le dossier rendu doit rester dans la zone sûre à %s." % viewport_size,
		)
		assert_true(
			dossier_rect.encloses(content_rect),
			"Le contenu ne doit pas déborder du dossier à %s." % viewport_size,
		)
		assert_gte(dossier_rect.size.x, 720.0)
		assert_gte(screen.bouton.get_global_rect().size.y, layout.cta_minimum.y)
		screen.queue_free()
		await wait_process_frames(1)


func test_ui_accept_confirms_once_and_reduced_motion_is_immediate() -> void:
	var screen = _spawn_screen()
	var calls := {"count": 0}
	screen.set_start_battle_callable_for_test(func(): calls.count += 1)
	screen.apply_runtime_snapshot_for_test(_odyssey_snapshot(), true)
	assert_eq(screen.dossier.modulate.a, 1.0)
	assert_eq(screen.dossier.scale, Vector2.ONE)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	screen._unhandled_input(accept)
	assert_false(screen.request_continue())
	assert_eq(calls.count, 1)
	var snapshot: Dictionary = screen.get_presentation_snapshot_for_test()
	assert_true(snapshot.transition_committed)
	assert_true(snapshot.battle_start_invoked)
	assert_true(snapshot.cta_disabled)
	assert_true(screen.status_label.visible)


func test_standard_motion_uses_a_short_non_blocking_entry() -> void:
	var screen = _spawn_screen()
	screen.apply_runtime_snapshot_for_test(_odyssey_snapshot(), false)
	assert_lt(screen.dossier.modulate.a, 1.0)
	assert_lt(screen.dossier.scale.x, 1.0)
