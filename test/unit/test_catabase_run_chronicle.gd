extends GutTest

const NarrativeService := preload("res://core/run_result_narrative_service.gd")
const ResultScene := preload("res://ui/RunResultScreen.tscn")
const GameManagerScript := preload("res://core/game_manager.gd")
const CatabaseRun: RunData = preload("res://data/runs/odyssey.tres")


func test_catabase_victory_records_only_real_progress_seed_and_health() -> void:
	var snapshot := NarrativeService.build_snapshot(
		true,
		"Catabase",
		&"SINGLE_ENCOUNTER",
		3,
		PackedStringArray([
			"Catabase I — L’Ombre de Paris",
			"Catabase II — La Porte des Cendres",
			"Catabase III — Le Jugement de Paris",
		]),
		424242,
		true,
		[{"name": "Achille", "current_hp": 58, "max_hp": 110, "alive": true}],
	)

	assert_true(snapshot.victory)
	assert_true(snapshot.is_catabase)
	assert_eq(snapshot.rooms_cleared, 3)
	assert_eq(snapshot.room_total, 3)
	assert_eq(snapshot.reached_room_number, 3)
	assert_eq(snapshot.reached_room_name, "Catabase III — Le Jugement de Paris")
	assert_true(snapshot.seed_available)
	assert_eq(snapshot.seed, 424242)
	assert_eq(snapshot.featured_hero_name, "Achille")
	assert_string_contains(snapshot.epitaph, "3/3 salles franchies")
	assert_string_contains(snapshot.epitaph, "Achille : 58/110 PV")


func test_catabase_defeat_records_reached_room_and_prior_clears() -> void:
	var snapshot := NarrativeService.build_snapshot(
		false,
		"Catabase",
		&"SINGLE_ENCOUNTER",
		1,
		PackedStringArray([
			"Catabase I — L’Ombre de Paris",
			"Catabase II — La Porte des Cendres",
			"Catabase III — Le Jugement de Paris",
		]),
		81,
		true,
		[{"name": "Achille", "current_hp": 0, "max_hp": 110, "alive": false}],
	)

	assert_false(snapshot.victory)
	assert_eq(snapshot.rooms_cleared, 1)
	assert_eq(snapshot.reached_room_number, 2)
	assert_eq(snapshot.reached_room_name, "Catabase II — La Porte des Cendres")
	assert_string_contains(snapshot.epitaph, "La Porte des Cendres")
	assert_string_contains(snapshot.epitaph, "1/3 salles franchies")
	assert_string_contains(snapshot.epitaph, "Achille : 0/110 PV")


func test_missing_seed_and_unknown_run_do_not_create_fake_facts() -> void:
	var snapshot := NarrativeService.build_snapshot(
		false,
		"",
		&"SINGLE_ENCOUNTER",
		-1,
		PackedStringArray(),
		0,
		false,
		[],
	)

	assert_false(snapshot.seed_available)
	assert_eq(snapshot.rooms_cleared, 0)
	assert_eq(snapshot.reached_room_number, 0)
	assert_eq(
		snapshot.epitaph,
		"L’Archiviste ne dispose d’aucun fait sur cette tentative.",
	)


func test_game_manager_records_the_live_catabase_state() -> void:
	var manager = GameManagerScript.new()
	var resolution := RunHeroResolver.resolve_runtime_hero_data(
		CatabaseRun, false
	)
	assert_true(resolution.is_valid())
	assert_true(manager._prepare_preconfigured_run(
		CatabaseRun, resolution.heroes
	))
	manager.current_room_index = 1
	manager.run_seed = 123456
	var achilles := manager.heroes[0] as Unit
	achilles.current_hp = 37
	manager._record_run_result(false)
	var result := manager.get_last_run_result()

	assert_false(result.victory)
	assert_eq(result.rooms_cleared, 1)
	assert_eq(result.reached_room_number, 2)
	assert_eq(result.reached_room_name, CatabaseRun.rooms[1].room_name)
	assert_eq(result.seed, 123456)
	assert_true(result.seed_available)
	assert_eq(result.featured_hero_name, "Achille")
	assert_eq(result.hero_states[0].current_hp, 37)
	assert_eq(result.hero_states[0].max_hp, 110)
	manager.cleanup_run_state()
	manager.free()


func test_result_screen_renders_chronicle_and_hides_missing_seed() -> void:
	var screen := ResultScene.instantiate()
	add_child_autofree(screen)
	var result := {
		"victory": false,
		"run_name": "Catabase",
		"is_catabase": true,
		"featured_hero_name": "Achille",
		"rooms_cleared": 1,
		"room_total": 3,
		"reached_room_number": 2,
		"reached_room_name": "Catabase II — La Porte des Cendres",
		"seed_available": false,
		"epitaph": "L’Archiviste consigne un fait vérifié.",
	}
	screen._apply_result(result)

	assert_eq(screen.result_label.text, "Défaite")
	assert_eq(screen.register_label.text, "REGISTRE DE L’ARCHIVISTE · CATABASE")
	assert_eq(screen.run_name_label.text, "Catabase — Achille")
	assert_string_contains(screen.progression_label.text, "Salles franchies : 1/3")
	assert_string_contains(screen.progression_label.text, "Salle atteinte : 2/3")
	assert_string_contains(screen.progression_label.text, "La Porte des Cendres")
	assert_false(screen.seed_label.visible)
	assert_eq(screen.epitaph_label.text, "L’Archiviste consigne un fait vérifié.")
	assert_eq(screen.return_button.text, "Retourner auprès de l’Archiviste")
	result["seed_available"] = true
	result["seed"] = 987654
	screen._apply_result(result)
	assert_true(screen.seed_label.visible)
	assert_eq(screen.seed_label.text, "Graine du destin : 987654")


func test_catabase_result_can_return_directly_to_the_archivist_hub() -> void:
	var manager = GameManagerScript.new()
	var requested_paths: Array[String] = []
	manager.scene_change_requested.connect(func(path): requested_paths.append(path))
	manager.return_to_hub()
	assert_eq(requested_paths, ["res://hub/StartHub.tscn"])
	assert_true(manager.get_last_run_result().is_empty())
	manager.free()
