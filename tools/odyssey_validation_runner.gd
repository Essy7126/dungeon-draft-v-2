extends Node

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")
const POST_COMBAT_SCENE: PackedScene = preload(
	"res://ui/post_combat/PostCombatScreen.tscn"
)
const RUN_RESULT_SCENE: PackedScene = preload("res://ui/RunResultScreen.tscn")
const GameManagerScript = preload("res://core/game_manager.gd")
const OUTPUT_DIR := "res://artifacts/odyssey_validation/captures"
const REPORT_PATH := "res://artifacts/odyssey_validation/runtime_report.json"
const VIEWPORT_SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]

var _report := {
	"passed": true,
	"seed": 0,
	"hub_path": {},
	"run_contract": {},
	"battle_rooms": [],
	"post_combat_and_result": {},
	"forced_transition": {},
	"captures": [],
	"failures": [],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIR)
	)
	GameManager.cleanup_run_state()
	var selected_run := await _exercise_real_hub_selection()
	if selected_run == null:
		_finish()
		return
	var resolution := RunHeroResolver.resolve_runtime_hero_data(
		selected_run, false
	)
	if not resolution.is_valid() or resolution.heroes.size() != 1:
		_fail("Le resolver runtime ne produit pas exactement Achille.")
		_finish()
		return
	var hero_data := resolution.heroes[0] as UnitData
	var spell_ids: Array[StringName] = []
	for spell in hero_data.spells:
		spell_ids.append(spell.get_effective_spell_id())
	var contract_passed := (
		selected_run.resource_path == "res://data/runs/odyssey.tres"
		and selected_run.content_profile.profile_id == &"odyssey"
		and hero_data.get_effective_unit_id() == &"achilles"
		and hero_data.max_ap == 6
		and hero_data.max_mp == 3
		and spell_ids == [
			&"achilles_spear_thrust",
			&"achilles_advance",
			&"achilles_sweep",
			&"achilles_guard",
		]
		and not hero_data.basic_attack_enabled
	)
	_report.run_contract = {
		"run_data_path": selected_run.resource_path,
		"profile_id": str(selected_run.content_profile.profile_id),
		"hero_count": resolution.heroes.size(),
		"unit_id": str(hero_data.get_effective_unit_id()),
		"max_ap": hero_data.max_ap,
		"max_mp": hero_data.max_mp,
		"spell_ids": spell_ids.map(func(value): return str(value)),
		"basic_attack_enabled": hero_data.basic_attack_enabled,
		"passed": contract_passed,
	}
	if not contract_passed:
		_fail("Le contrat runtime exporté d'Achille est invalide.")
	if not GameManager._prepare_preconfigured_run(
			selected_run, resolution.heroes
		):
		_fail("La préparation runtime globale de L'Odyssée échoue.")
		_finish()
		return
	_report.seed = GameManager.get_run_seed()
	await _exercise_real_battle_scenes(selected_run)
	await _exercise_post_combat_and_result_captures()
	GameManager.cleanup_run_state()
	_exercise_forced_transitions(selected_run, resolution.heroes)
	_finish()


func _exercise_real_hub_selection() -> RunData:
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await _settle(8)
	var controller := hub.get_node("HubController") as StartHubController
	var panel := controller.archivist_panel
	controller.transition_fade_duration = 0.0
	var cinematic_probe := {"calls": 0, "path": ""}
	controller.cinematic_open_callable = func(path: String) -> bool:
		cinematic_probe.calls += 1
		cinematic_probe.path = path
		return true
	panel.open_panel(controller.archivist.data)
	controller._set_state(StartHubController.HubState.UI_LOCKED)
	panel._show_room_selection()
	if panel.run_selector.item_count != 3:
		_fail("Le hub n'affiche pas exactement les trois runs officiels.")
	for viewport_size in VIEWPORT_SIZES:
		get_window().size = viewport_size
		await _settle(3)
		panel.run_selector.show_popup()
		await _settle(2)
		await _capture(
			"hub_three_runs_%dx%d.png" % [
				viewport_size.x, viewport_size.y,
			]
		)
		panel.run_selector.get_popup().hide()
		await _settle(2)
	panel.run_selector.select(2)
	panel._on_run_selected(2)
	if panel.run_selector.get_item_text(2) != RUN.run_name \
			or panel.room_selector.item_count != 1 \
			or panel.room_selector.get_selected_id() != RUN.hub_forced_start_room_index:
		_fail("La sélection Catabase ou son départ imposé en salle I est invalide.")
	for viewport_size in VIEWPORT_SIZES:
		get_window().size = viewport_size
		await _settle(3)
		await _capture(
			"hub_odyssey_selected_%dx%d.png" % [
				viewport_size.x, viewport_size.y,
			]
		)
	panel._confirm_run()
	await _settle(2)
	var selected := GameManager.take_next_run_data(RUN)
	_report.hub_path = {
		"run_count": panel.run_selector.item_count,
		"selected_run": selected.run_name if selected != null else "",
		"run_data_path": selected.resource_path if selected != null else "",
		"room_count": panel.room_selector.item_count,
		"cinematic_calls": cinematic_probe.calls,
		"cinematic_path": cinematic_probe.path,
		"passed": selected == RUN and cinematic_probe.calls == 1,
	}
	if not _report.hub_path.passed:
		_fail("Le chemin hub -> cinématique ne conserve pas L'Odyssée.")
	hub.queue_free()
	await _settle(3)
	return selected


func _exercise_real_battle_scenes(run_data: RunData) -> void:
	for room_index in range(run_data.rooms.size()):
		GameManager.current_room_index = room_index
		var room := run_data.rooms[room_index]
		var battle = room.battle_scene.instantiate()
		battle.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(battle)
		await _settle(8)
		if room_index == 0:
			for viewport_size in VIEWPORT_SIZES:
				get_window().size = viewport_size
				await _settle(3)
				await _capture(
					"deployment_room_01_%dx%d.png" % [
						viewport_size.x, viewport_size.y,
					]
				)
		# Le runner choisit la première case légale via le vrai contrôleur de
		# déploiement. Le combat reste donc représentatif du chemin joueur.
		if battle._deployment != null and battle._deployment.is_active():
			for cell in room.hero_spawn_zone:
				if battle.grid.is_valid(cell) \
						and battle.grid.is_walkable(cell) \
						and not battle.grid.has_unit(cell):
					battle._deployment.on_cell_clicked(cell)
					break
		await _settle(3)
		var enemies: Array = battle.units.filter(func(value):
			return value != null and (value as Unit).team == 1
		)
		var heroes: Array = battle.units.filter(func(value):
			return value != null and (value as Unit).team == 0
		)
		var views := battle.get("_unit_views") as Dictionary
		var achilles_view = views.get(heroes[0]) if heroes.size() == 1 else null
		var optional_visual = (
			achilles_view.get_optional_visual()
			if achilles_view != null else null
		)
		var room_passed: bool = (
			heroes.size() == 1
			and heroes[0].unit_id == &"achilles"
			and enemies.size()
			== room.encounter_definition.get_initial_enemy_count()
			and optional_visual is AchillesIsoUnitView
		)
		var viewport_rect := Rect2(
			Vector2.ZERO, get_viewport().get_visible_rect().size
		)
		var all_unit_anchors_visible := true
		for unit_value in battle.units:
			var unit_view := views.get(unit_value) as Node2D
			if unit_view == null or not unit_view.visible \
					or not viewport_rect.has_point(
						unit_view.get_global_transform_with_canvas().origin
					):
				all_unit_anchors_visible = false
				break
		room_passed = room_passed and all_unit_anchors_visible
		var enemy_unit_ids: Array[String] = []
		for enemy_value in enemies:
			enemy_unit_ids.append(str((enemy_value as Unit).unit_id))
		_report.battle_rooms.append({
			"room": room_index + 1,
			"room_name": room.room_name,
			"hero_count": heroes.size(),
			"enemy_count": enemies.size(),
			"enemy_unit_ids": enemy_unit_ids,
			"room_data_path": room.resource_path,
			"encounter_path": room.encounter_definition.resource_path,
			"formation": str(
				battle.encounter_formation_snapshot.get("formation_id", &"")
			),
			"achilles_visual": optional_visual is AchillesIsoUnitView,
			"all_unit_anchors_visible": all_unit_anchors_visible,
			"passed": room_passed,
		})
		if not room_passed:
			_fail("La vraie Battle de la salle %d est invalide." % (room_index + 1))
		# Laisse le bandeau de début de tour terminer son animation afin que les
		# captures de revue montrent le terrain, Achille et le HUD sans occlusion.
		await get_tree().create_timer(2.2).timeout
		var sizes := VIEWPORT_SIZES if room_index == 0 else [VIEWPORT_SIZES[0]]
		for viewport_size in sizes:
			get_window().size = viewport_size
			await _settle(3)
			await _capture(
				"battle_room_%02d_%dx%d.png" % [
					room_index + 1, viewport_size.x, viewport_size.y,
				]
			)
		battle.queue_free()
		await _settle(4)


func _exercise_post_combat_and_result_captures() -> void:
	GameManager.current_room_index = 0
	GameManager._room_outcome_resolved = true
	GameManager._room_exit_selected = true
	GameManager.begin_combat_report()
	GameManager._last_combat_report = (
		GameManager._finalize_current_combat_report(true)
	)
	var screen := POST_COMBAT_SCENE.instantiate() as PostCombatScreen
	screen.victory_reveal_duration = 0.0
	screen.stats_reveal_duration = 0.0
	screen.progression_step_duration = 0.0
	screen.threshold_pause_duration = 0.0
	add_child(screen)
	await _settle(4)
	var guard := 0
	while screen.get_phase_name() != &"PROGRESSION" and guard < 12:
		guard += 1
		screen.advance_or_skip()
		await _settle(2)
	var reward_options := GameManager.get_post_combat_reward_options()
	var progression_passed := (
		screen.get_phase_name() == &"PROGRESSION"
		and screen.get_reward_card_count() == 0
		and reward_options.size() == 2
		and screen.continue_button.text == "CHOISIR UNE RELIQUE"
	)
	guard = 0
	while screen.get_phase_name() != &"REWARD_SELECTION" and guard < 8:
		guard += 1
		screen.advance_or_skip()
		await _settle(2)
	var reward_passed := (
		screen.get_phase_name() == &"REWARD_SELECTION"
		and screen.get_reward_card_count() == 2
	)
	var post_combat_phase := str(screen.get_phase_name())
	var post_combat_button := screen.continue_button.text
	var reward_card_count := screen.get_reward_card_count()
	for viewport_size in VIEWPORT_SIZES:
		get_window().size = viewport_size
		screen.apply_viewport_size_for_test(viewport_size)
		await _settle(3)
		await _capture(
			"post_combat_relic_choice_%dx%d.png" % [
				viewport_size.x, viewport_size.y,
			]
		)
	screen.queue_free()
	await _settle(3)
	GameManager._record_run_result(true)
	var result_screen := RUN_RESULT_SCENE.instantiate()
	add_child(result_screen)
	await _settle(4)
	var result_label := result_screen.get_node(
		"Background/Center/Panel/Content/Result"
	) as Label
	var run_name_label := result_screen.get_node(
		"Background/Center/Panel/Content/RunName"
	) as Label
	var result_passed := (
		result_label.text == "Victoire"
		and run_name_label.text.contains(RUN.run_name)
	)
	var result_text := result_label.text
	var run_name_text := run_name_label.text
	for viewport_size in VIEWPORT_SIZES:
		get_window().size = viewport_size
		await _settle(3)
		await _capture(
			"run_result_victory_%dx%d.png" % [
				viewport_size.x, viewport_size.y,
			]
		)
	result_screen.queue_free()
	await _settle(3)
	_report.post_combat_and_result = {
		"post_combat_phase": post_combat_phase,
		"continue_button": post_combat_button,
		"reward_card_count": reward_card_count,
		"reward_options_seen": reward_options.size(),
		"result_label": result_text,
		"run_name_label": run_name_text,
		"passed": progression_passed and reward_passed and result_passed,
	}
	if not _report.post_combat_and_result.passed:
		_fail("Le choix de relique post-combat ou le résultat final est invalide.")


func _exercise_forced_transitions(
		run_data: RunData,
		hero_sources: Array
	) -> void:
	var manager = GameManagerScript.new()
	var prepared: bool = manager._prepare_preconfigured_run(
		run_data, hero_sources
	)
	var completed_rooms := 0
	var reward_options_seen := 0
	var relics_claimed := 0
	if prepared:
		for room_index in range(run_data.rooms.size()):
			manager.current_room_index = room_index
			manager._room_outcome_resolved = false
			manager.begin_combat_report()
			manager.on_battle_won()
			var report := manager.get_current_combat_report()
			var options := manager.get_post_combat_reward_options()
			reward_options_seen += options.size()
			if report == null:
				break
			if room_index < run_data.rooms.size() - 1:
				if options.size() != 2:
					break
				var reward_result := manager.confirm_post_combat_equipment(
					StringName(options[0].get("item_id", &"")),
					&"",
				)
				if not reward_result.get("success", false):
					break
				relics_claimed += 1
			elif not options.is_empty():
				break
			if manager.can_claim_post_combat_equipment(report.report_id) \
					or not manager.complete_post_combat_transition(report.report_id):
				break
			completed_rooms += 1
	var result := manager.get_last_run_result()
	var victory_passed := prepared \
		and completed_rooms == 3 \
		and reward_options_seen == 4 \
		and relics_claimed == 2 \
		and bool(result.get("victory", false))
	manager.cleanup_run_state()
	var defeat_prepared: bool = manager._prepare_preconfigured_run(
		run_data, hero_sources
	)
	if defeat_prepared:
		manager.current_room_index = 0
		manager.begin_combat_report()
		manager.on_battle_lost()
	var defeat_result := manager.get_last_run_result()
	var defeat_passed := defeat_prepared \
		and not bool(defeat_result.get("victory", true))
	var passed := victory_passed and defeat_passed
	_report.forced_transition = {
		"prepared": prepared,
		"completed_rooms": completed_rooms,
		"reward_options_seen": reward_options_seen,
		"relics_claimed": relics_claimed,
		"run_result": result,
		"defeat_prepared": defeat_prepared,
		"defeat_result": defeat_result,
		"passed": passed,
	}
	if not passed:
		_fail("Le runner de victoires forcées ne traverse pas les trois salles.")
	manager.cleanup_run_state()
	manager.free()


func _capture(file_name: String) -> void:
	# Le signal frame_post_draw n'est pas garanti avec le renderer headless.
	# Deux frames rendent la capture déterministe sans attente non bornée.
	await _settle(2)
	var image := get_viewport().get_texture().get_image()
	var path := OUTPUT_DIR.path_join(file_name)
	if image == null or image.is_empty() \
			or image.save_png(ProjectSettings.globalize_path(path)) != OK:
		_fail("Capture impossible : %s" % path)
		return
	_report.captures.append({
		"path": path,
		"size": [image.get_width(), image.get_height()],
	})


func _settle(frame_count: int = 2) -> void:
	for _index in frame_count:
		await get_tree().process_frame


func _fail(message: String) -> void:
	_report.passed = false
	_report.failures.append(message)
	push_error("ODYSSEY VALIDATION: %s" % message)


func _finish() -> void:
	var output := FileAccess.open(
		ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE
	)
	if output == null:
		_fail("Impossible d'écrire le rapport runtime.")
	else:
		output.store_string(JSON.stringify(_report, "\t"))
		output.close()
	print("ODYSSEY_RUNTIME_VALIDATION=" + JSON.stringify(_report))
	get_tree().quit(0 if _report.passed else 1)
