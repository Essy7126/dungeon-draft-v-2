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
	var contract_passed := runtime_hero_contract_is_valid(selected_run, hero_data)
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
	var odyssey_run_index := panel.find_run_index(RUN)
	if odyssey_run_index < 0:
		_fail("Le hub n'expose pas le parcours Odyssée canonique.")
		hub.queue_free()
		await _settle(3)
		return null
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
	panel.run_selector.select(odyssey_run_index)
	panel._on_run_selected(odyssey_run_index)
	if panel.run_selector.get_item_text(odyssey_run_index) != RUN.run_name \
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
		add_child(battle)
		await _settle(8)
		# Le runner ne simule aucune entrée réelle. Les événements souris/clavier
		# de la machine hôte sont donc neutralisés dès que la scène est prête.
		_disable_capture_grid_input(battle)
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
		# Le dernier placement appelle _start_battle() synchroniquement. On ferme
		# ensuite le cycle logique via le contrat de shutdown de Battle : les
		# signaux/timers/IA sont invalidés, tandis que le Node, les SubViewport et
		# les AnimationPlayer continuent de traiter pour la capture.
		var capture_logic_state := _neutralize_capture_battle_logic(battle)
		var capture_logic_neutralized := bool(
			capture_logic_state.get("neutralized", false)
		)
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
			and capture_logic_neutralized
			and battle.can_process()
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
		var capture_logic_before := _capture_battle_logic_fingerprint(battle)
		# Laisse le bandeau de debut de tour terminer son animation et donne aux
		# backends SubViewport le temps d'atteindre leur pose de repos. Contrairement
		# a l'ancien gel du noeud Battle, les animations continuent ici a traiter.
		await get_tree().create_timer(2.2).timeout
		var capture_logic_after := _capture_battle_logic_fingerprint(battle)
		var capture_logic_stable := capture_logic_before == capture_logic_after
		capture_logic_neutralized = (
			capture_logic_neutralized and capture_logic_stable
		)
		room_passed = room_passed and capture_logic_stable
		var visual_states := _collect_unit_visual_states(battle)
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
			"battle_can_process": battle.can_process(),
			"capture_logic_neutralized": capture_logic_neutralized,
			"capture_logic_state": capture_logic_state,
			"capture_logic_stable": capture_logic_stable,
			"capture_logic_before": capture_logic_before,
			"capture_logic_after": capture_logic_after,
			"unit_visual_states": visual_states,
			"passed": room_passed,
		})
		if not room_passed:
			_fail("La vraie Battle de la salle %d est invalide." % (room_index + 1))
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


func _disable_capture_grid_input(battle) -> bool:
	if not is_instance_valid(battle):
		return false
	var grid_view = battle.get("grid_view")
	if not is_instance_valid(grid_view):
		return false
	grid_view.set_process_input(false)
	grid_view.set_process_unhandled_input(false)
	grid_view.set_process_unhandled_key_input(false)
	return not grid_view.is_processing_input() \
		and not grid_view.is_processing_unhandled_input() \
		and not grid_view.is_processing_unhandled_key_input()


func _neutralize_capture_battle_logic(battle) -> Dictionary:
	var state := {
		"neutralized": false,
		"battle_closing": false,
		"enemy_runner_closing": false,
		"turn_handler_disconnected": false,
		"round_handler_disconnected": false,
		"grid_input_disabled": false,
		"battle_process_mode_enabled": false,
	}
	if not is_instance_valid(battle):
		return state
	# Cette méthode invalide aussi toute coroutine de tour déjà suspendue. Elle
	# ne désactive pas le processing visuel du Node Battle.
	if battle.has_method("_begin_battle_shutdown"):
		battle._begin_battle_shutdown()
	var enemy_turn = battle.get("_enemy_turn")
	if is_instance_valid(enemy_turn) \
			and enemy_turn.has_method("cancel_pending_actions"):
		enemy_turn.cancel_pending_actions()
	state.battle_closing = bool(battle.get("_closing"))
	state.enemy_runner_closing = is_instance_valid(enemy_turn) \
		and enemy_turn.has_method("is_closing") \
		and bool(enemy_turn.is_closing())
	var turn_queue = battle.get("turn_queue")
	var turn_callback := Callable(battle, "_on_turn_started")
	var round_callback := Callable(battle, "_on_round_started")
	state.turn_handler_disconnected = turn_queue != null \
		and not turn_queue.turn_started.is_connected(turn_callback)
	state.round_handler_disconnected = turn_queue != null \
		and not turn_queue.round_started.is_connected(round_callback)
	state.grid_input_disabled = _disable_capture_grid_input(battle)
	state.battle_process_mode_enabled = (
		battle.process_mode != Node.PROCESS_MODE_DISABLED
	)
	state.neutralized = state.battle_closing \
		and state.enemy_runner_closing \
		and state.turn_handler_disconnected \
		and state.round_handler_disconnected \
		and state.grid_input_disabled \
		and state.battle_process_mode_enabled
	return state


func _capture_battle_logic_fingerprint(battle) -> Dictionary:
	if not is_instance_valid(battle):
		return {}
	var unit_states: Array[Dictionary] = []
	for unit_value in battle.units:
		var unit := unit_value as Unit
		if unit == null:
			continue
		unit_states.append({
			"unit_id": str(unit.unit_id),
			"team": unit.team,
			"grid_pos": [unit.grid_pos.x, unit.grid_pos.y],
			"hp": unit.current_hp,
			"shield": unit.current_shield,
			"ap": unit.current_ap,
			"mp": unit.current_mp,
			"alive": unit.is_alive,
		})
	var turn_queue = battle.get("turn_queue")
	var active_unit = turn_queue.get_current_unit() if turn_queue != null else null
	return {
		"units": unit_states,
		"round": turn_queue.round_number if turn_queue != null else 0,
		"active_unit_id": str(active_unit.unit_id) if active_unit is Unit else "",
	}


func _collect_unit_visual_states(battle) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if not is_instance_valid(battle):
		return states
	var views := battle.get("_unit_views") as Dictionary
	for unit_value in battle.units:
		states.append(_unit_visual_state(battle, unit_value, views.get(unit_value)))
	return states


func _unit_visual_state(battle, unit_value, unit_view_value) -> Dictionary:
	var unit := unit_value as Unit
	var unit_view := unit_view_value as Node2D
	var current_unit = (
		battle.turn_queue.get_current_unit()
		if battle.turn_queue != null else null
	)
	var state := {
		"unit_id": str(unit.unit_id) if unit != null else "",
		"team": unit.team if unit != null else -1,
		"active_turn": unit != null and unit == current_unit,
		"view_visible": is_instance_valid(unit_view) \
			and unit_view.is_visible_in_tree(),
		"view_can_process": is_instance_valid(unit_view) and unit_view.can_process(),
		"adapter_script": "",
		"backend": "MISSING_VIEW",
		"backend_ready": false,
		"facing": "",
		"clip": "",
		"semantic": "",
		"animation_state": "UNAVAILABLE",
	}
	if not is_instance_valid(unit_view) \
			or not unit_view.has_method("get_optional_visual"):
		return state
	var optional_visual = unit_view.get_optional_visual()
	if not is_instance_valid(optional_visual):
		state.backend = "BASE_UNIT_SPRITE"
		return state
	var adapter_script = optional_visual.get_script()
	if adapter_script is Script:
		state.adapter_script = adapter_script.resource_path
	state.view_visible = optional_visual.is_visible_in_tree()
	state.view_can_process = optional_visual.can_process()
	if optional_visual is AchillesIsoUnitView:
		var achilles := optional_visual as AchillesIsoUnitView
		state.backend = str(achilles.get_active_backend_name())
		var viewport_backend := achilles.viewport_backend
		if not is_instance_valid(viewport_backend):
			return state
		state.backend_ready = viewport_backend.is_ready_for_render()
		state.facing = viewport_backend.get_facing_label()
		var visual := viewport_backend.get_achilles_visual()
		if not is_instance_valid(visual):
			return state
		state.semantic = str(visual.get_active_semantic())
		var player := visual.get_animation_player()
		if not is_instance_valid(player):
			return state
		state.clip = str(player.current_animation)
		state.animation_state = "PLAYING" if player.is_playing() else "STOPPED"
		state["clip_progress_seconds"] = snappedf(
			player.current_animation_position, 0.001,
		)
		return state
	if optional_visual.has_method("get_character_visual"):
		state.backend = "CharacterViewport3D"
		state.backend_ready = true
		if optional_visual.has_method("get_facing_direction"):
			state.facing = str(optional_visual.get_facing_direction())
		var character_visual = optional_visual.get_character_visual()
		if not is_instance_valid(character_visual):
			state.backend_ready = false
			return state
		var clip := StringName(character_visual.get_current_animation())
		state.clip = str(clip)
		state.semantic = "IDLE" if clip != &"" else ""
		state.animation_state = (
			"PLAYING"
			if clip != &"" and character_visual.is_animation_playing(clip)
			else "STOPPED" if clip != &"" else "UNAVAILABLE"
		)
		return state
	state.backend = optional_visual.get_class()
	state.backend_ready = true
	return state


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


static func runtime_hero_contract_is_valid(run_data: RunData, hero_data: UnitData) -> bool:
	if run_data == null or hero_data == null or run_data.content_profile == null:
		return false
	var profile := RunContentCatalogService.progression_profile_for(run_data, &"achilles")
	if profile == null:
		return false
	var expected_spell_ids: Array[StringName] = []
	for spell in profile.spells:
		expected_spell_ids.append(spell.get_effective_spell_id())
	var actual_spell_ids: Array[StringName] = []
	for spell in hero_data.spells:
		actual_spell_ids.append(spell.get_effective_spell_id())
	return (
		run_data.resource_path == "res://data/runs/odyssey.tres"
		and run_data.content_profile.profile_id == &"odyssey"
		and hero_data.get_effective_unit_id() == &"achilles"
		and hero_data.max_ap == 6
		and hero_data.max_mp == 3
		and expected_spell_ids == [
			&"achilles_peleid_strike", &"achilles_fulminant_dash",
			&"achilles_pelion_shot", &"achilles_bronze_guard",
		]
		and actual_spell_ids == expected_spell_ids
		and not hero_data.basic_attack_enabled
	)


static func expected_transition_counts(run_data: RunData) -> Dictionary:
	var room_count := run_data.rooms.size() if run_data != null else 0
	var rewarded_rooms := maxi(0, room_count - 1)
	return {
		"completed_rooms": room_count,
		"reward_options_seen": 2 * rewarded_rooms,
		"relics_claimed": rewarded_rooms,
	}


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
	var expected := expected_transition_counts(run_data)
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
	var victory_passed: bool = prepared \
		and completed_rooms == expected.completed_rooms \
		and reward_options_seen == expected.reward_options_seen \
		and relics_claimed == expected.relics_claimed \
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
	var passed: bool = victory_passed and defeat_passed
	_report.forced_transition = {
		"prepared": prepared,
		"expected": expected,
		"completed_rooms": completed_rooms,
		"reward_options_seen": reward_options_seen,
		"relics_claimed": relics_claimed,
		"run_result": result,
		"defeat_prepared": defeat_prepared,
		"defeat_result": defeat_result,
		"passed": passed,
	}
	if not passed:
		_fail("Le runner de victoires forcées ne valide pas les %d salles et leurs récompenses." % expected.completed_rooms)
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
