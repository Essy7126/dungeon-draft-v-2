extends Node
## Production-flow QA, not a balance simulation and not an OS-input test.
## All player actions start at real HUD buttons and GridView public endpoints.
## Battle._end_battle is the sole forced outcome; it is recorded after real actions.

const SELECTION := "res://ui/selection/CharacterSelectionScreen.tscn"
const INTRO := "res://cinematics/intro/intro_cinematic.tscn"
const HUB := "res://hub/StartHub.tscn"
const RUN := "res://data/runs/odyssey.tres"
const MAGE_SOURCE := "res://data/units/enemies/philosopher_mage.tres"
const CANONICAL := ["achilles_peleid_strike", "achilles_fulminant_dash", "achilles_pelion_shot", "achilles_bronze_guard"]
const MAX_ACTIVATIONS := 6
const INVALID_CELL := Vector2i(-1, -1)

var _output := ""
var _resolution := Vector2i(1600, 900)
var _seed := 2401
var _capture_sizes: Array[Vector2i] = []
var _finished := false
var _hud_id := 0
var _ui_id := 0
var _cast_events: Array[Dictionary] = []
var _turn_events: Array[Dictionary] = []
var _action_events: Array[Dictionary] = []
var _successful_spells: Dictionary = {}
var _selection_icons: Dictionary = {}
var _old_battles: Array[WeakRef] = []
var _run_data: RunData
var _report: Dictionary = {
	"schema": 1, "ok": false, "assertions": [], "errors": [], "milestones": [],
	"rooms": [], "casts": [], "moves": [], "transitions": [], "captures": [],
	"forced_outcomes": [], "os_input_verified": false, "balance_verified": false,
	"limits": [
		"HUD Button.pressed and public GridView.click_at endpoints; no OS pointer or window-input certification.",
		"Room victories are QA-forced only after real actions; no complete organic combat victory or balance claim.",
		"No AP/HP boost, enemy teleport, direct SpellCaster call, canonical resource write or room-index assignment.",
		"Six real player activations maximum per room; an unavailable action is a failure, not a fixture override."
	]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	_output = _argument("--output-root=")
	if _output.is_empty():
		_output = _argument("--output=")
	var requested := _parse_size(_argument("--resolution="))
	if _output.is_empty() or not _output.is_absolute_path() or requested == Vector2i.ZERO:
		push_error("Run integration QA requires --output-root=ABSOLUTE_DIRECTORY --resolution=WIDTHxHEIGHT")
		get_tree().quit(2)
		return
	_output = ProjectSettings.globalize_path(_output)
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Cannot create QA output directory: " + _output)
		get_tree().quit(2)
		return
	_resolution = requested
	var seed_text := _argument("--seed=")
	if not seed_text.is_empty():
		if not seed_text.is_valid_int():
			push_error("QA --seed must be an integer")
			get_tree().quit(2)
			return
		_seed = int(seed_text)
	_report["started_at_utc"] = Time.get_datetime_string_from_system(true)
	_report["engine"] = Engine.get_version_info()
	_report["rendering"] = {
		"method": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"driver": str(RenderingServer.call("get_current_rendering_driver_name")) if RenderingServer.has_method("get_current_rendering_driver_name") else "unavailable_see_native_log"
	}
	_report["run_source"] = RUN
	_report["run_source_sha256"] = FileAccess.get_sha256(RUN)
	_report["evidence_head_supplied"] = _argument("--evidence-head=")
	_report["evidence_head_verified_by_runner"] = false
	_report["requested_resolution"] = [requested.x, requested.y]
	if DisplayServer.get_name() == "headless":
		_report["parse_smoke_reached_gpu_guard"] = true
		_check(false, "gpu_renderer_required", "Headless parse smoke only; no gameplay or rendering exercised")
		_finish(2)
		return
	var sizes := _argument("--capture-resolutions=")
	if sizes.is_empty():
		_capture_sizes.append(requested)
	else:
		for value in sizes.split(",", false):
			var parsed := _parse_size(value)
			if not _check(parsed != Vector2i.ZERO, "valid_capture_resolution", value):
				_finish(2)
				return
			if not _capture_sizes.has(parsed):
				_capture_sizes.append(parsed)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = requested
	get_tree().create_timer(720.0, true).timeout.connect(_on_timeout)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.action_resolved.connect(_on_action_resolved)
	GameManager.scene_change_requested.connect(_on_scene_requested)
	# Keep this observer under SceneTree.root while the real current_scene changes.
	get_tree().current_scene = null
	GameManager.cleanup_run_state()
	if not await _begin_from_selection("victory"):
		_finish()
		return
	for room_index in range(5):
		var battle = await _enter_room(room_index)
		if battle == null:
			_finish()
			return
		if not await _exercise_room(battle, room_index):
			await _capture("room_%02d_failure" % (room_index + 1))
			_finish()
			return
		if not await _finish_room(battle, room_index):
			_finish()
			return
	_check(_successful_spells.size() == 4, "all_four_canonical_spells_resolved", _successful_spells.keys())
	if not await _verify_result_and_return(true):
		_finish()
		return
	if OS.get_cmdline_user_args().has("--include-loss"):
		_hud_id = 0
		_ui_id = 0
		if await _begin_from_selection("loss"):
			var battle = await _enter_room(0)
			if battle != null:
				var hero = _hero(battle)
				var hud = GameManager.get_persistent_run_ui().get_combat_hud()
				var acted := await _try_cast(battle, hero, hud, "achilles_bronze_guard", false)
				if _check(acted, "loss_route_real_action_before_forced_loss"):
					_force_outcome(battle, false, "optional cleanup route, after real guard")
					await _verify_result_and_return(false)
	_report["run_source_unchanged"] = FileAccess.get_sha256(RUN) == _report.run_source_sha256
	_check(bool(_report.run_source_unchanged), "canonical_run_resource_unchanged")
	_finish()

func _begin_from_selection(label: String) -> bool:
	if not _check(get_tree().change_scene_to_file(SELECTION) == OK, label + "_selection_scene_open"):
		return false
	if not await _wait_for_scene(SELECTION, 15000):
		return false
	var screen = get_tree().current_scene
	var chosen := -1
	var entries: Array = screen.get_entries()
	for index in range(entries.size()):
		var run = entries[index].get("run") as RunData
		if run != null and run.resource_path == RUN:
			chosen = index
			break
	if not _check(chosen >= 0 and screen.select_character(chosen), label + "_public_selection_catabase"):
		return false
	_run_data = screen.get_selected_entry().get("run") as RunData
	if not _check(_run_data != null and _run_data.rooms.size() == 5, "canonical_five_room_run"):
		return false
	_report["source_default_seed"] = _run_data.default_seed
	_report["source_randomize_seed_each_run"] = _run_data.randomize_seed_each_run
	# Keep the selection -> intro -> manager route intact. Only the selected
	# in-memory RunData copy receives a fixed QA seed; all content stays shared.
	var run_copy = _run_data.duplicate(false) as RunData
	run_copy.default_seed = _seed
	run_copy.randomize_seed_each_run = false
	screen.get_selected_entry()["run"] = run_copy
	_run_data = run_copy
	_report["qa_seed_override"] = {"seed": _seed, "memory_copy_only": true, "source_resource_unchanged": true}
	var selected_unit: UnitData = screen.get_selected_entry().get("unit")
	_check(_spell_ids(selected_unit.spells) == CANONICAL, "selection_canonical_spell_order")
	var selected_buttons: Array = screen.get("_spell_buttons")
	for index in range(selected_unit.spells.size()):
		var icon: Texture2D = selected_buttons[index].get_node("Icon").texture
		_selection_icons[str(selected_unit.spells[index].get_effective_spell_id())] = _texture_path(icon)
	_report["selection_icons"] = _selection_icons.duplicate()
	await _capture(label + "_selection")
	if not _press(screen.start_button, label + "_start_adventure_button"):
		return false
	if not await _wait_for_scene(INTRO, 15000):
		return false
	var intro = get_tree().current_scene
	_check(GameManager.has_next_run_configuration(), label + "_intro_has_configured_run")
	await _capture(label + "_intro")
	intro.request_skip()
	if not await _wait_until(func(): return GameManager.run_active and not GameManager.has_next_run_configuration(), 15000):
		return _check(false, label + "_intro_consumed_configuration")
	_check(GameManager.current_room_index == 0, label + "_starts_at_room_zero")
	_report["actual_seed"] = GameManager.get_run_seed()
	_check(GameManager.get_run_seed() == _seed, label + "_fixed_qa_seed_applied")
	_mark(label + "_run_started", {"seed": GameManager.get_run_seed()})
	return true

func _enter_room(index: int):
	if not _check(GameManager.current_room_index == index, "room_index_%d" % index):
		return null
	if not await _wait_until(func():
		var scene = get_tree().current_scene
		return scene != null and scene.get_node_or_null("Contenu/BoutonContinuer") != null, 20000):
		_check(false, "transition_screen_ready_%d" % index)
		return null
	var transition = get_tree().current_scene
	await _capture("room_%02d_transition" % (index + 1))
	if not _press(transition.get_node("Contenu/BoutonContinuer"), "transition_continue_%d" % index):
		return null
	var expected: String = _run_data.rooms[index].battle_scene.resource_path
	if not await _wait_until(func():
		var scene = get_tree().current_scene
		return scene != null and scene.scene_file_path == expected and bool(scene.get("runtime_ready_state")) and bool(scene.get("registered_terrain_ready")), 40000):
		_check(false, "registered_battle_ready_%d" % index)
		return null
	var battle = get_tree().current_scene
	var deployment = battle.get("_deployment") as DeploymentController
	var grid = battle.get("grid") as GridData
	if deployment != null and deployment.is_active():
		for cell: Vector2i in GameManager.get_current_room().hero_spawn_zone:
			if not deployment.is_active():
				break
			if grid.is_walkable(cell) and not grid.has_unit(cell):
				deployment.on_cell_clicked(cell)
	if not await _wait_player(battle, 35000):
		_check(false, "player_ready_after_deployment_%d" % index)
		return null
	for previous in _old_battles:
		_check(previous.get_ref() == null, "previous_battle_freed_before_room_%d" % index)
	_old_battles.clear()
	var ui = GameManager.get_persistent_run_ui()
	var hud = ui.get_combat_hud() if ui != null else null
	if not _check(hud != null and hud.get_combat_context() == battle, "real_persistent_hud_bound_%d" % index):
		return null
	if _hud_id == 0:
		_hud_id = hud.get_instance_id()
		_ui_id = ui.get_instance_id()
	_check(hud.get_instance_id() == _hud_id and ui.get_instance_id() == _ui_id, "hud_identity_persists_%d" % index)
	var lifecycle: Dictionary = ui.get_combat_hud_lifecycle_snapshot()
	_check(bool(lifecycle.get("contract_valid", false)), "hud_port_contract_%d" % index, lifecycle)
	_check(_intent_binding_count(hud, battle) == 5, "five_unique_hud_intents_%d" % index)
	var hero = _hero(battle)
	if not _check(hero != null, "achilles_present_%d" % index):
		return null
	var state = GameManager.get_character_state_for_unit(hero)
	var live_ids := _spell_ids(hero.spells)
	_check(live_ids == CANONICAL, "canonical_live_loadout_%d" % index, live_ids)
	_check(state != null and state.loadout != null and _spell_ids(state.loadout.get_equipped_spells()) == live_ids, "state_unit_loadout_synced_%d" % index)
	_check(_spell_ids_from_hud(hud) == live_ids, "live_hud_loadout_synced_%d" % index)
	var visuals := _visual_snapshot(battle)
	_report.rooms.append({"index": index, "room_path": GameManager.get_current_room().resource_path,
		"battle_scene": battle.scene_file_path, "battle_instance_id": battle.get_instance_id(),
		"ui_instance_id": _ui_id, "hud_instance_id": _hud_id, "lifecycle": lifecycle,
		"visuals": visuals, "icons": _icon_snapshot(hud), "hero_state_id": state.get_instance_id() if state != null else 0})
	_check(_has_visual(visuals, "achilles_iso_unit_view.gd", 0), "achilles_canonical_visual_%d" % index)
	if index == 3:
		_check(_mage_enemy(battle) != null, "room_iv_canonical_dialectician_visual", {"source": MAGE_SOURCE, "visuals": visuals})
	_mark("room_%02d_ready" % (index + 1), {"room_resource": GameManager.get_current_room().resource_path})
	await _capture("room_%02d_combat" % (index + 1))
	var banner = hud.get_turn_intro_banner()
	if banner != null:
		var banner_gone := await _wait_until(func(): return not banner.visible, 5000)
		_check(banner_gone, "room_%d_turn_intro_finished_naturally" % index)
	await _capture("room_%02d_idle" % (index + 1))
	return battle

func _exercise_room(battle, index: int) -> bool:
	var hero = _hero(battle)
	var ui = GameManager.get_persistent_run_ui()
	var hud = ui.get_combat_hud()
	if index == 0 and not await _exercise_modals_and_tabs(battle, hero, ui, hud):
		return false
	var action_before: int = _report.casts.size()
	var seen_activations: Array[int] = []
	var mage = _mage_enemy(battle) if index == 3 else null
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and not _finished and is_instance_valid(battle) and GameManager.run_active:
		if not await _wait_player(battle, 35000):
			break
		if not seen_activations.has(hero.activation_index):
			seen_activations.append(hero.activation_index)
		if seen_activations.size() > MAX_ACTIVATIONS:
			break
		# Missing spells first. Guard follows attacks; real AP/MP and turns are preserved.
		for spell_id: String in ["achilles_pelion_shot", "achilles_peleid_strike", "achilles_fulminant_dash", "achilles_bronze_guard"]:
			if not _player_ready(battle):
				break
			if _successful_spells.has(spell_id) and index == 0 and _successful_spells.size() < 4:
				continue
			await _try_cast(battle, hero, hud, spell_id, true)
			if _room_action_goal(index, action_before, mage):
				break
		if _room_action_goal(index, action_before, mage):
			await _capture("room_%02d_after_real_actions" % (index + 1))
			_mark("room_%02d_actions_complete" % (index + 1), {"activations": seen_activations, "mage_ai": _mage_activation_snapshot(mage)})
			return true
		if _player_ready(battle):
			await _move_toward_enemy(battle, hero, hud)
		# Close-range strike may become available after a real move.
		if _player_ready(battle) and not _successful_spells.has("achilles_peleid_strike"):
			await _try_cast(battle, hero, hud, "achilles_peleid_strike", true)
		if _room_action_goal(index, action_before, mage):
			await _capture("room_%02d_after_real_actions" % (index + 1))
			return true
		if _player_ready(battle) and not await _end_player_turn(battle, hud):
			break
	return _check(false, "room_%d_real_action_goal_within_six_activations" % index,
		{"successful_spells": _successful_spells.keys(), "mage": _mage_activation_snapshot(mage), "activations": seen_activations})

func _room_action_goal(index: int, cast_start: int, mage) -> bool:
	var player_cast_succeeded := false
	for cast_index in range(cast_start, _report.casts.size()):
		if bool(_report.casts[cast_index].get("ok", false)):
			player_cast_succeeded = true
	if not player_cast_succeeded:
		return false
	if index == 0 and _successful_spells.size() != 4:
		return false
	if index == 3:
		return bool(_mage_activation_snapshot(mage).get("completed", false))
	return true

func _try_cast(battle, hero: Unit, hud, spell_id: String, capture: bool) -> bool:
	if not _player_ready(battle) or hero == null or not hero.is_alive:
		return false
	var button = _spell_button(hud, spell_id)
	if button == null or button.disabled or not button.is_visible_in_tree():
		return false
	var spell = button.get_meta("spell") as Spell
	if spell == null or not hero.can_use_spell(spell):
		return false
	var view = battle.get("grid_view")
	var state = battle.get("turn_state") as TurnState
	var before_count := _cast_events.size()
	var ap_before := hero.current_ap
	var cost := hero.get_spell_ap_cost(spell)
	var before_effect := _combat_snapshot(battle)
	button.pressed.emit()
	await _settle(2)
	if state.current != TurnState.State.TARGET_SPELL:
		_check(false, "hud_button_entered_spell_targeting", spell_id)
		return false
	var highlights: Dictionary = view.get_highlight_snapshot()
	var target := _choose_spell_target(battle, hero, spell, highlights)
	if target == INVALID_CELL:
		battle.cancel_active_selection()
		return false
	var point: Vector2 = view.grid_to_local(target)
	_check(view.update_hover(point) == target, "spell_hover_maps_to_cell", {"spell_id": spell_id, "cell": str(target)})
	var routed: Vector2i = view.click_at(point)
	if not _check(routed == target, "spell_click_public_grid_route", spell_id):
		return false
	var resolved := await _wait_until(func():
		return not is_instance_valid(battle) or (_cast_events.size() > before_count and not bool(battle.get("_spell_resolution_pending"))), 15000)
	await _settle(4)
	var matching: Array = []
	for index in range(before_count, _cast_events.size()):
		var event := _cast_events[index]
		if int(event.actor_instance) == hero.get_instance_id() and str(event.spell_id) == spell_id:
			matching.append(event)
	var effect_changed := is_instance_valid(battle) and _combat_snapshot(battle) != before_effect
	var record := {"room": GameManager.current_room_index, "spell_id": spell_id,
		"target": [target.x, target.y], "input_api": "HUD.Button.pressed -> GridView.update_hover/click_at",
		"ap_before": ap_before, "ap_after": hero.current_ap, "cost": cost,
		"matching_spell_cast_events": matching.size(), "resolved": resolved,
		"effect_changed": effect_changed, "activation": hero.activation_index,
		"icon_path": _texture_path(button.get_displayed_icon())}
	record["ok"] = resolved and matching.size() == 1 and hero.current_ap == ap_before - cost and effect_changed
	_report.casts.append(record)
	_check(bool(record.ok), "single_real_cast_" + spell_id, record)
	if bool(record.ok):
		_successful_spells[spell_id] = true
	if capture and is_instance_valid(battle):
		await _capture("room_%02d_%s_resolved" % [GameManager.current_room_index + 1, spell_id])
	return bool(record.ok)

func _choose_spell_target(battle, hero: Unit, spell: Spell, highlights: Dictionary) -> Vector2i:
	if spell.is_self_only():
		return hero.grid_pos if highlights.has(hero.grid_pos) else INVALID_CELL
	var grid = battle.get("grid") as GridData
	var candidates: Array[Vector2i] = []
	for key in highlights:
		var cell: Vector2i = key
		var occupant = grid.get_unit(cell)
		if spell.can_target_enemy and occupant != null and occupant.team != hero.team and occupant.is_alive:
			candidates.append(cell)
		elif spell.can_target_free_cell and occupant == null:
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := _nearest_enemy_distance(battle, a)
		var db := _nearest_enemy_distance(battle, b)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	return candidates[0] if not candidates.is_empty() else INVALID_CELL

func _move_toward_enemy(battle, hero: Unit, hud) -> bool:
	if hero.current_mp <= 0:
		return false
	var move = hud.get_node_or_null("%MoveButton") as Button
	if move == null or move.disabled:
		return false
	var pathfinder = battle.get("pathfinder") as Pathfinder
	var best := hero.grid_pos
	var best_distance := _nearest_enemy_distance(battle, best)
	for cell: Vector2i in pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero):
		var distance := _nearest_enemy_distance(battle, cell)
		if distance < best_distance:
			best = cell
			best_distance = distance
	if best == hero.grid_pos:
		return false
	var before := hero.grid_pos
	var mp_before := hero.current_mp
	var ap_before := hero.current_ap
	var path: Array = pathfinder.find_path(before, best, hero)
	var expected := int(pathfinder.path_cost_breakdown(path, hero).get("total", 0))
	move.pressed.emit()
	var view = battle.get("grid_view")
	view.click_at(view.grid_to_local(best))
	var moved := await _wait_until(func(): return not is_instance_valid(battle) or (hero.grid_pos == best and _player_ready(battle)), 15000)
	var record := {"room": GameManager.current_room_index, "from": str(before), "to": str(best),
		"mp_before": mp_before, "mp_after": hero.current_mp, "expected_cost": expected,
		"ok": moved and hero.grid_pos == best and hero.current_mp == mp_before - expected and hero.current_ap == ap_before}
	_report.moves.append(record)
	return _check(bool(record.ok), "real_hud_movement", record)

func _end_player_turn(battle, hud) -> bool:
	var before = battle.get_active_unit()
	var activation: int = before.activation_index
	if not _press(hud.get_node_or_null("%EndTurnButton"), "hud_end_turn"):
		return false
	await _settle(2)
	var modal = battle.get("_end_turn_confirmation") as EndTurnConfirmation
	if modal != null and modal.is_open():
		_check(not _player_ready(battle), "end_turn_modal_locks_controller")
		var confirm = modal.get("_confirm_button") as Button
		if not _press(confirm, "end_turn_confirm_button"):
			return false
	return await _wait_until(func():
		return not is_instance_valid(battle) or battle.get_active_unit() != before or before.activation_index != activation, 15000)

func _exercise_modals_and_tabs(battle, hero: Unit, ui, hud) -> bool:
	var before := _cast_events.size()
	for spec in [["InventoryButton", "inventory"], ["SkillsButton", "skills"]]:
		if not _press(hud.get_node_or_null("%" + str(spec[0])), "hud_open_" + str(spec[1])):
			return false
		await _settle(4)
		_check(ui.has_active_modal() and not _player_ready(battle), str(spec[1]) + "_locks_real_combat")
		await _capture("hud_" + str(spec[1]))
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = true
		get_viewport().push_input(event, true)
		await _settle(4)
		event.pressed = false
		get_viewport().push_input(event, true)
		_check(not ui.has_active_modal() and _player_ready(battle), str(spec[1]) + "_escape_restores_controls")
	_press(hud.get_node_or_null("%ShowItemsButton"), "show_items_button")
	await _settle(2)
	for value in hud.get("_spell_buttons"):
		_check(value.shortcut == null, "spell_shortcut_released_in_items")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.keycode = KEY_1
	key.pressed = true
	get_viewport().push_input(key, true)
	await _settle(3)
	key.pressed = false
	get_viewport().push_input(key, true)
	_check(_cast_events.size() == before and not battle.is_action_selection_active(), "item_key_does_not_select_or_cast_spell")
	_press(hud.get_node_or_null("%ShowSpellsButton"), "show_spells_button")
	await _settle(2)
	var spell_buttons: Array = hud.get("_spell_buttons")
	for index in range(spell_buttons.size()):
		var shortcut = spell_buttons[index].shortcut as Shortcut
		_check(shortcut != null and shortcut.events.size() == 1 and shortcut.events[0].physical_keycode == KEY_1 + index, "canonical_shortcut_%d" % index)
	key.pressed = true
	get_viewport().push_input(key, true)
	await _settle(3)
	key.pressed = false
	get_viewport().push_input(key, true)
	_check(battle.is_action_selection_active() and _cast_events.size() == before, "spell_key_selects_without_premature_cast")
	battle.cancel_active_selection()
	_check(hero.current_ap == hero.max_ap.get_int(), "modal_and_tab_probes_spent_no_ap")
	return _report.errors.is_empty()

func _finish_room(battle, index: int) -> bool:
	_old_battles.append(weakref(battle))
	_force_outcome(battle, true, "after real HUD cast(s); room IV additionally after real Mage AI activation")
	if not await _wait_until(func():
		var scene = get_tree().current_scene
		return scene != null and scene.has_method("get_phase_name") and GameManager.get_current_combat_report() != null, 25000):
		return _check(false, "post_combat_ready_%d" % index)
	var screen = get_tree().current_scene
	var screen_ref: WeakRef = weakref(screen)
	var report = GameManager.get_current_combat_report()
	var record := {"from_index": index, "report_id": str(report.report_id), "phases": [], "reward_applied": false}
	_report.transitions.append(record)
	var hud = GameManager.get_persistent_run_ui().get_combat_hud()
	_check(hud.get_combat_context() == null, "hud_unbound_during_postcombat_%d" % index)
	await _capture("room_%02d_postcombat" % (index + 1))
	for step in range(32):
		if not is_instance_valid(screen) or get_tree().current_scene != screen:
			break
		var phase := str(screen.get_phase_name())
		if not record.phases.has(phase):
			record.phases.append(phase)
		if phase == "REWARD_SELECTION":
			_check(not GameManager.complete_post_combat_transition(report.report_id), "unclaimed_reward_blocks_progression_%d" % index)
			var options: Array = GameManager.get_post_combat_reward_options()
			var claimed := false
			for option: Dictionary in options:
				var reward_id := StringName(option.get("reward_id", option.get("item_id", &"")))
				if screen.select_reward_by_id(reward_id) and screen.confirm_selected_reward():
					claimed = true
					record["reward_id"] = str(reward_id)
					break
			if not _check(claimed, "reward_claimed_through_real_screen_%d" % index):
				return false
			record["reward_applied"] = true
			await _capture("room_%02d_reward" % (index + 1))
		else:
			screen.advance_or_skip()
		await _settle(8)
	if not await _wait_until(func(): return screen_ref.get_ref() == null or get_tree().current_scene != screen_ref.get_ref(), 15000):
		return _check(false, "postcombat_transition_completed_%d" % index)
	if index < 4:
		_check(bool(record.reward_applied), "nonfinal_reward_observed_%d" % index)
		_check(GameManager.current_room_index == index + 1, "room_advanced_without_runner_index_write_%d" % index)
	else:
		_check(not bool(record.reward_applied), "final_room_no_extra_equipment_reward")
	return _report.errors.is_empty()

func _verify_result_and_return(victory: bool) -> bool:
	if not await _wait_until(func():
		var scene = get_tree().current_scene
		return scene != null and scene.get_node_or_null("Background/Center/Panel/Content/ReturnButton") != null, 20000):
		return _check(false, "run_result_scene_ready")
	var result: Dictionary = GameManager.get_last_run_result()
	var label := "victory" if victory else "loss"
	_check(bool(result.get("victory", not victory)) == victory and not GameManager.run_active, label + "_result_recorded", result)
	if victory:
		_check(int(result.get("rooms_cleared", 0)) == 5, "victory_result_five_of_five", result)
	_report[label + "_result"] = result
	await _capture(label + "_result")
	var old_ui = weakref(GameManager.get_persistent_run_ui())
	var old_states: Array[WeakRef] = []
	for state in GameManager.get_ordered_character_states():
		old_states.append(weakref(state))
	var screen = get_tree().current_scene
	if not _press(screen.get_node("Background/Center/Panel/Content/ReturnButton"), label + "_return_button"):
		return false
	if not await _wait_for_scene(HUB, 20000):
		return false
	await _settle(8)
	_check(not GameManager.run_active and GameManager.get_ordered_heroes().is_empty(), label + "_hub_has_no_active_run")
	_check(not GameManager.has_persistent_run_ui() and old_ui.get_ref() == null, label + "_old_persistent_ui_freed")
	for state_ref in old_states:
		var state = state_ref.get_ref()
		_check(state == null or state.loadout == null, label + "_old_character_loadout_disposed")
	_check(not GameManager.has_next_run_configuration(), label + "_next_run_configuration_cleared")
	await _capture(label + "_clean_hub")
	return _report.errors.is_empty()

func _force_outcome(battle, victory: bool, reason: String) -> void:
	_report.forced_outcomes.append({"room": GameManager.current_room_index, "victory": victory,
		"method": "Battle._end_battle", "reason": reason, "at_utc": Time.get_datetime_string_from_system(true)})
	battle.call("_end_battle", victory)

func _player_ready(battle) -> bool:
	if not is_instance_valid(battle) or get_tree().current_scene != battle:
		return false
	var active = battle.get_active_unit()
	var state = battle.get("turn_state") as TurnState
	var snapshot: Dictionary = battle.get_combat_presentation_snapshot()
	return active != null and active.team == 0 and state != null and state.current == TurnState.State.IDLE \
		and not bool(snapshot.get("input_locked", true)) and not bool(battle.get("_spell_resolution_pending"))

func _wait_player(battle, timeout: int) -> bool:
	return await _wait_until(func(): return _player_ready(battle), timeout)

func _hero(battle) -> Unit:
	for unit in GameManager.get_ordered_heroes():
		if unit.unit_id == &"achilles" and unit.is_alive:
			return unit
	return null

func _mage_enemy(battle) -> Unit:
	var expected = load(MAGE_SOURCE) as UnitData
	if expected == null or expected.visual_scene == null:
		return null
	var views: Dictionary = battle.get("_unit_views")
	for unit in views:
		var view = views[unit].get_optional_visual()
		if unit.team == 1 and unit.unit_id == expected.unit_id and view != null and view.scene_file_path == expected.visual_scene.resource_path:
			return unit
	return null

func _mage_activation_snapshot(mage) -> Dictionary:
	if mage == null:
		return {"present": false, "completed": false}
	var started := 0
	var ended := 0
	var actions := 0
	for event in _turn_events:
		if int(event.actor_instance) == mage.get_instance_id():
			started += 1 if event.kind == "started" else 0
			ended += 1 if event.kind == "ended" else 0
	for event in _action_events:
		if int(event.actor_instance) == mage.get_instance_id():
			actions += 1
	return {"present": true, "id": str(mage.unit_id), "instance": mage.get_instance_id(),
		"started": started, "ended": ended, "action_resolved": actions, "completed": started > 0 and ended > 0}

func _nearest_enemy_distance(battle, cell: Vector2i) -> int:
	var distance := 100000
	var views: Dictionary = battle.get("_unit_views")
	for unit in views:
		if unit.team == 1 and unit.is_alive:
			distance = mini(distance, absi(unit.grid_pos.x - cell.x) + absi(unit.grid_pos.y - cell.y))
	return distance

func _spell_button(hud, id: String):
	for button in hud.get("_spell_buttons"):
		var spell = button.get_meta("spell", null) as Spell
		if spell != null and str(spell.get_effective_spell_id()) == id:
			return button
	return null

func _spell_ids(spells: Array) -> Array[String]:
	var ids: Array[String] = []
	for spell: Spell in spells:
		ids.append(str(spell.get_effective_spell_id()))
	return ids

func _spell_ids_from_hud(hud) -> Array[String]:
	var ids: Array[String] = []
	for button in hud.get("_spell_buttons"):
		ids.append(str(button.get_meta("spell").get_effective_spell_id()))
	return ids

func _icon_snapshot(hud) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var theme = hud.get_active_character_theme()
	for button in hud.get("_spell_buttons"):
		var spell = button.get_meta("spell") as Spell
		var icon = button.get_displayed_icon() as Texture2D
		var expected = theme.get_spell_icon_for(spell) if theme != null else spell.icon
		var record := {"spell_id": str(spell.get_effective_spell_id()), "displayed": _texture_path(icon), "source_icon": _texture_path(spell.icon)}
		_check(icon != null and not record.displayed.is_empty(), "canonical_spell_has_visible_icon", record)
		_check(str(_selection_icons.get(record.spell_id, "")) == str(record.displayed), "selection_hud_icon_identity", record)
		if expected != null:
			_check(icon == expected, "icon_identity_matches_character_mapping", record)
		result.append(record)
	return result

func _visual_snapshot(battle) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var views: Dictionary = battle.get("_unit_views")
	for unit in views:
		var view = views[unit]
		var visual = view.get_optional_visual()
		var script_path := ""
		if visual != null and visual.get_script() != null:
			script_path = str(visual.get_script().resource_path)
		var record := {"id": str(unit.unit_id), "team": unit.team, "visual_script": script_path,
			"visual_scene": visual.scene_file_path if visual != null else "", "view_visible": view.is_visible_in_tree()}
		if visual != null and visual.has_method("get_visual_runtime_state"):
			record["backend"] = visual.get_visual_runtime_state()
		result.append(record)
	return result

func _has_visual(records: Array, suffix: String, team: int) -> bool:
	for record in records:
		if int(record.team) == team and str(record.visual_script).ends_with(suffix) and bool(record.view_visible):
			return true
	return false

func _combat_snapshot(battle) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var views: Dictionary = battle.get("_unit_views")
	for unit in views:
		result.append({"instance": unit.get_instance_id(), "hp": unit.current_hp, "shield": unit.current_shield,
			"cell": str(unit.grid_pos), "alive": unit.is_alive})
	return result

func _intent_binding_count(hud, battle) -> int:
	var count := 0
	for signal_name in [&"move_pressed", &"attack_pressed", &"spell_pressed", &"end_turn_pressed", &"item_activation_requested"]:
		for connection in hud.get_signal_connection_list(signal_name):
			if connection.callable.get_object() == battle:
				count += 1
	return count

func _press(button, label: String) -> bool:
	if not _check(button is Button and is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(), label + "_enabled_visible"):
		return false
	button.pressed.emit()
	return true

func _wait_for_scene(path: String, timeout: int) -> bool:
	var ready := await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path, timeout)
	return _check(ready, "scene_ready", path)

func _wait_until(predicate: Callable, timeout: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while Time.get_ticks_msec() < deadline and not _finished:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return false

func _settle(frames: int) -> void:
	for index in range(frames):
		await get_tree().process_frame

func _capture(label: String) -> void:
	if _finished or DisplayServer.get_name() == "headless":
		return
	for size in _capture_sizes:
		get_window().size = size
		await _settle(6)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
		var filename := "%s__%s__%dx%d.png" % [label, stamp, size.x, size.y]
		var path := _output.path_join(filename)
		var actual := image.get_size() if image != null else Vector2i.ZERO
		var saved := image != null and not image.is_empty() and actual == size and image.save_png(path) == OK
		_check(saved, "capture_saved_at_requested_size", {"path": path, "actual": str(actual), "requested": str(size)})
		_report.captures.append({"label": label, "at_utc": Time.get_datetime_string_from_system(true),
			"path": path, "size": [actual.x, actual.y], "ok": saved})
	get_window().size = _resolution
	await _settle(4)
	_write_report()

func _texture_path(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else ""

func _parse_size(value: String) -> Vector2i:
	var parts := value.to_lower().split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	var size := Vector2i(int(parts[0]), int(parts[1]))
	return size if size.x >= 640 and size.y >= 480 else Vector2i.ZERO

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""

func _check(passed: bool, name: String, detail: Variant = null) -> bool:
	_report.assertions.append({"name": name, "ok": passed, "detail": detail,
		"at_utc": Time.get_datetime_string_from_system(true)})
	if not passed:
		_report.errors.append({"name": name, "detail": detail})
		push_error("RUN_INTEGRATION_QA: " + name + " " + str(detail))
	return passed

func _mark(name: String, detail: Dictionary = {}) -> void:
	_report.milestones.append({"name": name, "detail": detail, "at_utc": Time.get_datetime_string_from_system(true)})
	print("RUN_INTEGRATION_QA: ", name)
	_write_report()

func _on_spell_cast(actor, spell, report: Dictionary) -> void:
	_cast_events.append({"actor": str(actor.unit_id), "actor_instance": actor.get_instance_id(),
		"team": actor.team, "spell_id": str(spell.get_effective_spell_id()), "room": GameManager.current_room_index,
		"report_success": report.get("success", true), "at_utc": Time.get_datetime_string_from_system(true)})

func _on_turn_started(actor) -> void:
	_turn_events.append({"kind": "started", "actor": str(actor.unit_id), "actor_instance": actor.get_instance_id(), "team": actor.team})

func _on_turn_ended(actor, reason: StringName) -> void:
	_turn_events.append({"kind": "ended", "actor": str(actor.unit_id), "actor_instance": actor.get_instance_id(), "team": actor.team, "reason": str(reason)})

func _on_action_resolved(actor, action_id: StringName, kind: StringName, _metadata: Dictionary) -> void:
	_action_events.append({"actor": str(actor.unit_id), "actor_instance": actor.get_instance_id(), "team": actor.team, "action_id": str(action_id), "kind": str(kind)})

func _on_scene_requested(path: String) -> void:
	_mark("scene_change_requested", {"path": path, "room": GameManager.current_room_index})

func _write_report() -> void:
	if _output.is_empty():
		return
	_report["spell_events"] = _cast_events
	_report["turn_events"] = _turn_events
	_report["action_events"] = _action_events
	var file := FileAccess.open(_output.path_join("run_integration_report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))

func _on_timeout() -> void:
	if not _finished:
		_check(false, "global_deadline_720_seconds")
		_finish()

func _finish(exit_code: int = -1) -> void:
	if _finished:
		return
	_finished = true
	_report["finished_at_utc"] = Time.get_datetime_string_from_system(true)
	_report["ok"] = _report.errors.is_empty()
	_report["assertion_count"] = _report.assertions.size()
	_write_report()
	print("RUN_INTEGRATION_QA_FINISHED ", JSON.stringify({"ok": _report.ok, "assertions": _report.assertions.size(), "errors": _report.errors.size(), "output": _output}))
	get_tree().quit(exit_code if exit_code >= 0 else (0 if bool(_report.ok) else 1))
