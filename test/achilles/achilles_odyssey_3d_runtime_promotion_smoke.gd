extends Node

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")
const RUN_RESULT_SCENE: PackedScene = preload("res://ui/RunResultScreen.tscn")
const GAME_MANAGER_SCRIPT = preload("res://core/game_manager.gd")
const WINDOW_SIZE := Vector2i(1600, 1000)
const BACKEND_DEADLINE_MSEC := 8000
const ACTION_DEADLINE_MSEC := 10000
const LEGACY_BACKEND_PATH := (
	"res://characters/achilles/3d/AchillesLegacy2DBackend.tscn"
)
const LEGACY_VISUAL_PATH := (
	"res://assets/characters/Achilles/AchillesVisual2D.tscn"
)

var _artifact_dir := ""
var _capture_dir := ""
var _report := {
	"schema": "dd.achilles.odyssey-3d-runtime-promotion-smoke.v1",
	"status": "FAIL",
	"run_path": "res://data/runs/odyssey.tres",
	"evidence_head": "",
	"scope": {
		"owner_selection": "B_SUBVIEWPORT_384_APPROVED_2026-08-20",
		"hub_selection": "PRODUCTION_HUB_CONTROLS_CALLED_PROGRAMMATICALLY",
		"battle_scenes": "THREE_PRODUCTION_ROOM_BATTLE_SCENES",
		"player_actions": "PRODUCTION_BATTLE_UI_HANDLERS_CALLED_PROGRAMMATICALLY",
		"transitions": "FORCED_MANAGER_STATE_ADVANCE_WITHOUT_ENEMY_DEFEAT_SIMULATION",
		"physical_manual_input": false,
	},
	"hub": {},
	"runtime_contract": {},
	"rooms": [],
	"player_action_probe": {},
	"visual_reload_probe": {},
	"forced_transitions": {},
	"result_screen": {},
	"global_checks": {},
	"captures": [],
	"failures": [],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_artifact_dir = _argument_value("--artifact-dir=")
	_report.evidence_head = _argument_value("--evidence-head=")
	if _artifact_dir.is_empty() or not _artifact_dir.is_absolute_path():
		_fail("An absolute --artifact-dir is required; res:// output is forbidden.")
		_finish()
		return
	if not _is_full_git_sha(_report.evidence_head):
		_fail("A full 40-character --evidence-head is required.")
		_finish()
		return
	_capture_dir = _artifact_dir.path_join("captures")
	if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
		_fail("The external artifact directory could not be created.")
		_finish()
		return

	get_window().size = WINDOW_SIZE
	RenderingServer.set_default_clear_color(Color(0.018, 0.023, 0.034, 1.0))
	GameManager.cleanup_run_state()
	var selected_run: RunData = await _exercise_real_hub_selection()
	if selected_run == null:
		GameManager.cleanup_run_state()
		_finish()
		return

	var resolution = RunHeroResolver.resolve_runtime_hero_data(selected_run, false)
	if resolution == null or not resolution.is_valid() \
			or resolution.heroes.size() != 1:
		_fail("RunHeroResolver did not resolve exactly one Achilles.")
		GameManager.cleanup_run_state()
		_finish()
		return
	var hero_data := resolution.heroes[0] as UnitData
	var runtime_contract := {
		"selected_run_is_real_odyssey": selected_run == RUN,
		"unit_id": String(hero_data.get_effective_unit_id()),
		"single_hero": resolution.heroes.size() == 1,
		"visual_scene_path": (
			hero_data.visual_scene.resource_path
			if hero_data.visual_scene != null else ""
		),
		"achilles_3d_adapter_selected": (
			hero_data.visual_scene != null
			and hero_data.visual_scene.resource_path
			== "res://characters/achilles/AchillesIsoUnitView.tscn"
		),
		"basic_attack_disabled": not hero_data.basic_attack_enabled,
	}
	runtime_contract["passed"] = _all_boolean_checks_pass(runtime_contract)
	_report.runtime_contract = runtime_contract
	if not runtime_contract.passed:
		_fail("The Odyssey runtime contract does not select the Achilles 3D adapter.")

	if not GameManager._prepare_preconfigured_run(
			selected_run, resolution.heroes
		):
		_fail("The real Odyssey RunData could not be prepared.")
		GameManager.cleanup_run_state()
		_finish()
		return

	await _exercise_three_real_rooms(selected_run)
	await _exercise_forced_transitions_and_result(resolution.heroes)
	_report.global_checks = {
		"legacy_backend_scene_never_cached": not ResourceLoader.has_cached(
			LEGACY_BACKEND_PATH
		),
		"legacy_achilles_visual_never_cached": not ResourceLoader.has_cached(
			LEGACY_VISUAL_PATH
		),
		"three_real_rooms_loaded": _report.rooms.size() == 3,
		"all_room_checks_passed": _all_room_records_pass(),
	}
	for check_name in _report.global_checks:
		if not bool(_report.global_checks[check_name]):
			_fail("Global runtime promotion check failed: %s" % check_name)
	GameManager.cleanup_run_state()
	await _settle(4)
	_finish()


func _exercise_real_hub_selection() -> RunData:
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await _settle(8)
	var controller := hub.get_node_or_null("HubController") as StartHubController
	if controller == null or controller.archivist_panel == null:
		_fail("The production hub controller or archivist panel is missing.")
		hub.queue_free()
		await _settle(3)
		return null
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
	await _settle(3)
	var odyssey_item_index := -1
	for item_index in range(panel.run_selector.item_count):
		if panel.run_selector.get_item_text(item_index) == RUN.run_name:
			odyssey_item_index = item_index
			break
	if odyssey_item_index < 0:
		_fail("L'Odyssée is not present in the real hub run selector.")
		hub.queue_free()
		await _settle(3)
		return null
	panel.run_selector.select(odyssey_item_index)
	panel._on_run_selected(odyssey_item_index)
	await _settle(3)
	await _capture("hub_odyssey_selected.png")
	var selector_room_count: int = panel.room_selector.item_count
	panel._confirm_run()
	await _settle(3)
	var selected := GameManager.take_next_run_data(RUN)
	var hub_ref: WeakRef = weakref(hub)
	_report.hub = {
		"run_item_count": panel.run_selector.item_count,
		"odyssey_item_index": odyssey_item_index,
		"room_item_count": selector_room_count,
		"selected_path": selected.resource_path if selected != null else "",
		"cinematic_calls": cinematic_probe.calls,
		"cinematic_path": cinematic_probe.path,
		"passed": (
			selected == RUN
			and selector_room_count == RUN.rooms.size()
			and cinematic_probe.calls == 1
		),
	}
	hub.queue_free()
	await _settle(5)
	_report.hub["cleanup_released"] = hub_ref.get_ref() == null
	if not _report.hub.passed or not _report.hub.cleanup_released:
		_fail("The production hub did not preserve the Odyssey selection cleanly.")
	return selected


func _exercise_three_real_rooms(run_data: RunData) -> void:
	for room_index in range(run_data.rooms.size()):
		GameManager.current_room_index = room_index
		var room := run_data.rooms[room_index] as RoomData
		var room_record := {
			"room_number": room_index + 1,
			"room_name": room.room_name,
			"room_path": room.resource_path,
			"battle_scene_path": (
				room.battle_scene.resource_path
				if room.battle_scene != null else ""
			),
			"scene_traversal": "INDEX_SET_BY_GRAPHICAL_SMOKE_AFTER_REAL_HUB_PREPARATION",
			"checks": {},
			"initiative_portrait": {},
			"cleanup": {},
			"passed": false,
		}
		if room.battle_scene == null:
			_fail("Room %d has no production Battle scene." % (room_index + 1))
			_report.rooms.append(room_record)
			continue
		var battle = room.battle_scene.instantiate()
		add_child(battle)
		await _settle(10)
		if battle.grid == null or battle._deployment == null \
				or not battle._deployment.is_active():
			_fail("Room %d did not enter real deployment." % (room_index + 1))
			await _release_battle(battle, room_record)
			_report.rooms.append(room_record)
			continue
		var deployment_cell := _first_legal_spawn(
			room.hero_spawn_zone, battle.grid
		)
		if deployment_cell == Vector2i(-1, -1):
			_fail("Room %d has no legal Achilles deployment cell." % (room_index + 1))
			await _release_battle(battle, room_record)
			_report.rooms.append(room_record)
			continue
		battle._deployment.on_cell_clicked(deployment_cell)
		await _settle(12)
		var resolved := await _wait_for_room_achilles(battle)
		var hero := resolved.get("hero") as Unit
		var unit_view = resolved.get("unit_view")
		var adapter := resolved.get("adapter") as AchillesIsoUnitView
		if hero == null or unit_view == null or adapter == null:
			_fail("Room %d did not produce the 3D Achilles UnitView." % (room_index + 1))
			await _release_battle(battle, room_record)
			_report.rooms.append(room_record)
			continue

		var enemies: Array = battle.units.filter(func(value):
			return value != null and (value as Unit).team == 1
		)
		var heroes: Array = battle.units.filter(func(value):
			return value != null and (value as Unit).team == 0
		)
		room_record.checks = _inspect_runtime_visual(
			battle, room, hero, unit_view, adapter, heroes, enemies
		)
		room_record.initiative_portrait = _inspect_initiative_portrait(
			battle, hero
		)
		if not bool(room_record.initiative_portrait.get("non_empty", false)):
			_fail("Room %d Achilles initiative portrait is empty." % (room_index + 1))
		for check_name in room_record.checks:
			if room_record.checks[check_name] is bool \
					and not bool(room_record.checks[check_name]):
				_fail("Room %d visual check failed: %s" % [room_index + 1, check_name])

		battle._on_turn_order_unit_selected(hero)
		await _settle(2)
		room_record.checks["initiative_card_selection_inspects_achilles"] = (
			battle.inspect_panel != null and battle.inspect_panel.visible
		)
		if not room_record.checks.initiative_card_selection_inspects_achilles:
			_fail("Room %d initiative selection did not open inspection." % (room_index + 1))

		room_record.checks["turn_intro_banner_hidden_for_capture"] = (
			await _wait_for_turn_intro_banner_hidden(battle)
		)
		if not room_record.checks.turn_intro_banner_hidden_for_capture:
			_fail("Room %d turn banner did not clear before capture." % (room_index + 1))
		await _capture("room_%02d_achilles_3d.png" % (room_index + 1))
		if room_index == 0:
			_report.player_action_probe = await _exercise_real_player_actions(
				battle, hero, unit_view, adapter
			)
			if not _report.player_action_probe.passed:
				_fail("The production movement/spell handler probe failed.")
			await _capture("room_01_after_player_actions.png")
		elif room_index == 1:
			var reloaded := await _exercise_visual_instance_reload(
				battle, hero, unit_view, adapter
			)
			unit_view = reloaded.get("unit_view")
			adapter = reloaded.get("adapter") as AchillesIsoUnitView
			reloaded.erase("unit_view")
			reloaded.erase("adapter")
			_report.visual_reload_probe = reloaded
			if not reloaded.passed:
				_fail("The Achilles visual instance reload left a duplicate or leak.")
			await _capture("room_02_after_visual_reload.png")
		if unit_view == null or adapter == null:
			_fail("Room %d lost Achilles during the visual reload." % (room_index + 1))
			await _release_battle(battle, room_record)
			_report.rooms.append(room_record)
			continue

		var adapter_ref: WeakRef = weakref(adapter)
		var viewport_ref: WeakRef = weakref(
			adapter.viewport_backend.character_viewport
		)
		var battle_ref: WeakRef = weakref(battle)
		battle.queue_free()
		await _settle(10)
		room_record.cleanup = {
			"battle_released": battle_ref.get_ref() == null,
			"adapter_released": adapter_ref.get_ref() == null,
			"subviewport_released": viewport_ref.get_ref() == null,
		}
		room_record.passed = (
			_all_boolean_checks_pass(room_record.checks)
			and bool(room_record.initiative_portrait.get("non_empty", false))
			and _all_boolean_checks_pass(room_record.cleanup)
		)
		if not room_record.passed:
			_fail("Room %d did not pass its complete 3D runtime audit." % (room_index + 1))
		_report.rooms.append(room_record)


func _inspect_runtime_visual(
		battle,
		room: RoomData,
		hero: Unit,
		unit_view,
		adapter: AchillesIsoUnitView,
		heroes: Array,
		enemies: Array
	) -> Dictionary:
	var backend := adapter.viewport_backend
	var visual_3d := backend.get_achilles_visual()
	var subviewports := adapter.find_children("*", "SubViewport", true, false)
	var skeletons := adapter.find_children("*", "Skeleton3D", true, false)
	var forbidden_nodes := _forbidden_equipment_nodes(adapter)
	var shadow := _find_descendant_in_group(unit_view, &"iso_ground_shadow")
	var footprint_size := 0
	if shadow != null and shadow.has_method("get_footprint"):
		footprint_size = shadow.get_footprint().size()
	var viewport_image := backend.character_viewport.get_texture().get_image()
	var opaque_samples := _count_opaque_samples(viewport_image)
	return {
		"real_room_data_bound": battle.room_data == room,
		"real_encounter_enemy_count": (
			enemies.size()
			== room.encounter_definition.get_initial_enemy_count()
		),
		"one_runtime_achilles": (
			heroes.size() == 1 and hero.unit_id == &"achilles"
		),
		"viewport_backend_active": (
			adapter.get_active_backend_name() == &"Viewport3DBackend"
			and backend.is_backend_active()
		),
		"viewport_exactly_384": (
			backend.character_viewport.size == Vector2i(384, 384)
			and adapter.visual_profile != null
			and adapter.visual_profile.viewport_size == Vector2i(384, 384)
		),
		"single_subviewport_in_achilles": subviewports.size() == 1,
		"single_skeleton_in_achilles": skeletons.size() == 1,
		"character_mesh_visible": (
			visual_3d != null
			and not visual_3d.get_mesh_instances().is_empty()
			and visual_3d.has_visible_character_materials()
		),
		"render_contains_opaque_character_pixels": opaque_samples > 0,
		"transparent_subviewport": backend.character_viewport.transparent_bg,
		"zero_achilles_visual_2d_in_adapter": adapter.find_children(
			"*", "AchillesVisual2D", true, false
		).is_empty(),
		"zero_animated_sprite_2d_in_adapter": adapter.find_children(
			"*", "AnimatedSprite2D", true, false
		).is_empty(),
		"zero_legacy_backend_in_adapter": adapter.find_children(
			"*", "AchillesLegacy2DBackend", true, false
		).is_empty(),
		"safe_fallback_is_invisible": (
			adapter.fallback_backend != null
			and not adapter.fallback_backend.visible
		),
		"zero_weapon_or_equipment_named_nodes": forbidden_nodes.is_empty(),
		"equipment_disabled_in_profile": (
			adapter.visual_profile != null
			and not adapter.visual_profile.equipment_enabled
			and adapter.visual_profile.weapon_profile == null
		),
		"readable_ground_shadow": (
			shadow is CanvasItem
			and shadow.visible
			and footprint_size >= 3
		),
		"unit_view_visible": unit_view.visible,
		"legacy_backend_resource_not_cached": not ResourceLoader.has_cached(
			LEGACY_BACKEND_PATH
		),
		"legacy_visual_resource_not_cached": not ResourceLoader.has_cached(
			LEGACY_VISUAL_PATH
		),
	}


func _inspect_initiative_portrait(battle, hero: Unit) -> Dictionary:
	var timeline := battle.turn_order_timeline as TurnOrderTimeline
	if timeline == null:
		return {"available": false, "non_empty": false, "mode": "MISSING"}
	var cards := timeline.get("_cards") as Dictionary
	var card := cards.get(hero) as TurnOrderCard
	if card == null:
		return {"available": false, "non_empty": false, "mode": "MISSING"}
	var fallback_non_empty := (
		card.fallback_portrait.visible
		and card.fallback_portrait.texture != null
		and card.fallback_portrait.texture.get_width() > 0
		and card.fallback_portrait.texture.get_height() > 0
	)
	var preview_non_empty := (
		card.preview.visible
		and card.preview.get_visual_instance() != null
		and card.preview.preview_viewport.get_texture() != null
	)
	return {
		"available": true,
		"card_count": timeline.get_card_count(),
		"fallback_texture_non_empty": fallback_non_empty,
		"preview_non_empty": preview_non_empty,
		"mode": "FALLBACK_PORTRAIT" if fallback_non_empty else "3D_PREVIEW",
		"non_empty": fallback_non_empty or preview_non_empty,
	}


func _exercise_real_player_actions(
		battle,
		hero: Unit,
		unit_view,
		adapter: AchillesIsoUnitView
	) -> Dictionary:
	var record := {
		"boundary": "PROGRAMMATIC_CALLS_TO_PRODUCTION_BATTLE_UI_HANDLERS",
		"physical_manual_input": false,
		"bounded_wait_for_real_achilles_turn": true,
		"movement": {},
		"spell": {},
		"passed": false,
	}
	var active_turn_ready := await _wait_for_achilles_turn(battle, hero)
	var active_before = battle.get_active_unit()
	var reachable: Array = battle.pathfinder.get_reachable(
		hero.grid_pos, hero.current_mp, hero
	)
	var destination := _nearest_reachable_destination(hero.grid_pos, reachable)
	var move_from := hero.grid_pos
	var mp_before := hero.current_mp
	var view_position_before: Vector2 = unit_view.position
	var move_mode_entered := false
	var move_feedback_observed := false
	if active_before == hero and destination != move_from:
		battle._on_move_pressed()
		move_mode_entered = battle.turn_state.current == TurnState.State.MOVE
		battle._on_cell_clicked(destination)
		await _settle(1)
		var visual_3d := adapter.viewport_backend.get_achilles_visual()
		move_feedback_observed = (
			visual_3d != null and visual_3d.get_active_semantic() == &"MOVE"
		)
		var move_deadline := Time.get_ticks_msec() + ACTION_DEADLINE_MSEC
		while hero.grid_pos != destination \
				and Time.get_ticks_msec() < move_deadline:
			await get_tree().process_frame
		while battle.turn_state.current == TurnState.State.ANIMATING \
				and Time.get_ticks_msec() < move_deadline:
			await get_tree().process_frame
	var movement := {
		"bounded_real_turn_wait_succeeded": active_turn_ready,
		"active_unit_was_achilles": active_before == hero,
		"from": [move_from.x, move_from.y],
		"to": [destination.x, destination.y],
		"mode_entered": move_mode_entered,
		"feedback_move_semantic_observed": move_feedback_observed,
		"cell_changed": hero.grid_pos == destination and destination != move_from,
		"mp_spent": hero.current_mp < mp_before,
		"unit_view_moved": unit_view.position != view_position_before,
		"returned_to_idle": battle.turn_state.current == TurnState.State.IDLE,
	}
	movement["passed"] = _all_boolean_checks_pass(movement)
	record.movement = movement

	var guard_spell := _find_spell(hero, &"achilles_guard")
	var signal_counts := {"release": 0, "finish": 0}
	adapter.cast_release_reached.connect(func() -> void:
		signal_counts.release += 1
	)
	adapter.animation_finished.connect(func(_name: StringName) -> void:
		signal_counts.finish += 1
	)
	var ap_before := hero.current_ap
	var shield_before := hero.current_shield
	var valid_before: bool = (
		guard_spell != null
		and battle.spell_caster.can_cast(hero, guard_spell, hero.grid_pos)
	)
	var spell_mode_entered := false
	if valid_before:
		battle._on_spell_pressed(guard_spell)
		spell_mode_entered = (
			battle.turn_state.current == TurnState.State.TARGET_SPELL
		)
		battle._on_cell_clicked(hero.grid_pos)
		var spell_deadline := Time.get_ticks_msec() + ACTION_DEADLINE_MSEC
		while (battle.get("_spell_resolution_pending") \
				or signal_counts.finish < 1) \
				and Time.get_ticks_msec() < spell_deadline:
			await get_tree().process_frame
		await _settle(6)
	var spell_record := {
		"spell_id": (
			String(guard_spell.get_effective_spell_id())
			if guard_spell != null else ""
		),
		"uses_real_spell_caster": battle.spell_caster != null,
		"valid_self_target_before_cast": valid_before,
		"target_mode_entered": spell_mode_entered,
		"release_count": signal_counts.release,
		"finish_count": signal_counts.finish,
		"release_exactly_once": signal_counts.release == 1,
		"finish_exactly_once": signal_counts.finish == 1,
		"ap_cost_applied": (
			guard_spell != null
			and hero.current_ap == ap_before - guard_spell.ap_cost
		),
		"shield_effect_applied": hero.current_shield > shield_before,
		"resolution_not_pending": not battle.get("_spell_resolution_pending"),
		"returned_to_idle": battle.turn_state.current == TurnState.State.IDLE,
		"viewport_backend_still_active": (
			adapter.get_active_backend_name() == &"Viewport3DBackend"
		),
	}
	spell_record["passed"] = _all_boolean_checks_pass(spell_record, [
		"spell_id", "release_count", "finish_count",
	])
	record.spell = spell_record
	record.passed = movement.passed and spell_record.passed
	return record


func _exercise_visual_instance_reload(
		battle,
		hero: Unit,
		old_unit_view,
		old_adapter: AchillesIsoUnitView
	) -> Dictionary:
	var old_unit_view_ref: WeakRef = weakref(old_unit_view)
	var old_adapter_ref: WeakRef = weakref(old_adapter)
	var old_viewport_ref: WeakRef = weakref(
		old_adapter.viewport_backend.character_viewport
	)
	var views := battle.get("_unit_views") as Dictionary
	views.erase(hero)
	old_unit_view.queue_free()
	await _settle(6)
	battle._create_unit_view(hero)
	await _settle(6)
	var new_unit_view = views.get(hero)
	var new_adapter := (
		new_unit_view.get_optional_visual() as AchillesIsoUnitView
		if new_unit_view != null else null
	)
	if new_adapter != null:
		await _wait_for_backend(new_adapter)
	var adapter_count: int = battle.find_children(
		"*", "AchillesIsoUnitView", true, false
	).size()
	var subviewport_count := (
		new_adapter.find_children("*", "SubViewport", true, false).size()
		if new_adapter != null else 0
	)
	var record := {
		"old_unit_view_released": old_unit_view_ref.get_ref() == null,
		"old_adapter_released": old_adapter_ref.get_ref() == null,
		"old_subviewport_released": old_viewport_ref.get_ref() == null,
		"new_unit_view_created": new_unit_view != null,
		"new_adapter_created": new_adapter != null,
		"new_viewport_backend_active": (
			new_adapter != null
			and new_adapter.get_active_backend_name() == &"Viewport3DBackend"
		),
		"single_achilles_adapter_after_reload": adapter_count == 1,
		"single_subviewport_after_reload": subviewport_count == 1,
		"zero_legacy_backend_after_reload": (
			new_adapter != null
			and new_adapter.find_children(
				"*", "AchillesLegacy2DBackend", true, false
			).is_empty()
		),
		"unit_view": new_unit_view,
		"adapter": new_adapter,
	}
	record["passed"] = _all_boolean_checks_pass(record, [
		"unit_view", "adapter",
	])
	return record


func _exercise_forced_transitions_and_result(hero_sources: Array) -> void:
	var manager = GAME_MANAGER_SCRIPT.new()
	var prepared: bool = manager._prepare_preconfigured_run(RUN, hero_sources)
	var completed_rooms := 0
	var reward_options_seen := 0
	if prepared:
		for room_index in range(RUN.rooms.size()):
			manager.current_room_index = room_index
			manager._room_outcome_resolved = false
			manager.begin_combat_report()
			manager.on_battle_won()
			var report = manager.get_current_combat_report()
			reward_options_seen += manager.get_post_combat_reward_options().size()
			if report == null \
					or manager.can_claim_post_combat_equipment(report.report_id) \
					or not manager.complete_post_combat_transition(report.report_id):
				break
			completed_rooms += 1
	var result := manager.get_last_run_result()
	var passed := (
		prepared
		and completed_rooms == RUN.rooms.size()
		and reward_options_seen == 0
		and bool(result.get("victory", false))
	)
	_report.forced_transitions = {
		"classification": "FORCED_MANAGER_STATE_ADVANCE_WITHOUT_ENEMY_DEFEAT_SIMULATION",
		"not_claimed_as_manual_playthrough": true,
		"prepared": prepared,
		"completed_rooms": completed_rooms,
		"reward_options_seen": reward_options_seen,
		"result": result,
		"passed": passed,
	}
	if not passed:
		_fail("Forced production manager transitions did not traverse all rooms.")
	manager.cleanup_run_state()
	manager.free()

	GameManager.cleanup_run_state()
	var ui_prepared := GameManager._prepare_preconfigured_run(RUN, hero_sources)
	if ui_prepared:
		GameManager._record_run_result(true)
	var result_screen := RUN_RESULT_SCENE.instantiate()
	add_child(result_screen)
	await _settle(6)
	var result_label := result_screen.get_node_or_null(
		"Background/Center/Panel/Content/Result"
	) as Label
	var run_name_label := result_screen.get_node_or_null(
		"Background/Center/Panel/Content/RunName"
	) as Label
	await _capture("run_result_odyssey_victory.png")
	var result_ref: WeakRef = weakref(result_screen)
	var result_passed := (
		ui_prepared
		and result_label != null
		and run_name_label != null
		and result_label.text == "Victoire"
		and run_name_label.text.contains(RUN.run_name)
	)
	_report.result_screen = {
		"classification": "PRODUCTION_UI_WITH_SYNTHETIC_RECORDED_VICTORY",
		"result_text": result_label.text if result_label != null else "",
		"run_name_text": run_name_label.text if run_name_label != null else "",
		"passed": result_passed,
	}
	result_screen.queue_free()
	await _settle(5)
	_report.result_screen["cleanup_released"] = result_ref.get_ref() == null
	if not result_passed or not _report.result_screen.cleanup_released:
		_fail("The production Odyssey result screen or its cleanup failed.")
	GameManager.cleanup_run_state()


func _wait_for_room_achilles(battle) -> Dictionary:
	var deadline := Time.get_ticks_msec() + BACKEND_DEADLINE_MSEC
	while Time.get_ticks_msec() < deadline:
		var heroes: Array = battle.units.filter(func(value):
			return value != null and (value as Unit).team == 0
		)
		if heroes.size() == 1:
			var hero := heroes[0] as Unit
			var views := battle.get("_unit_views") as Dictionary
			var unit_view = views.get(hero)
			var adapter := (
				unit_view.get_optional_visual() as AchillesIsoUnitView
				if unit_view != null else null
			)
			if adapter != null \
					and adapter.get_active_backend_name() == &"Viewport3DBackend":
				await _settle(4)
				return {
					"hero": hero,
					"unit_view": unit_view,
					"adapter": adapter,
				}
		await get_tree().process_frame
	return {}


func _wait_for_backend(adapter: AchillesIsoUnitView) -> bool:
	var deadline := Time.get_ticks_msec() + BACKEND_DEADLINE_MSEC
	while is_instance_valid(adapter) \
			and adapter.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return is_instance_valid(adapter) \
		and adapter.get_active_backend_name() == &"Viewport3DBackend"


func _wait_for_achilles_turn(battle, hero: Unit) -> bool:
	var deadline := Time.get_ticks_msec() + ACTION_DEADLINE_MSEC
	while is_instance_valid(battle) \
			and is_instance_valid(hero) \
			and Time.get_ticks_msec() < deadline:
		if battle.get_active_unit() == hero \
				and battle.turn_state != null \
				and battle.turn_state.current == TurnState.State.IDLE:
			return true
		await get_tree().process_frame
	return false


func _wait_for_turn_intro_banner_hidden(battle) -> bool:
	if battle.action_bar == null \
			or not battle.action_bar.has_method("get_turn_intro_banner"):
		return true
	var banner: CharacterTurnIntroBanner = battle.action_bar.call(
		"get_turn_intro_banner"
	) as CharacterTurnIntroBanner
	if banner == null:
		return true
	var deadline := Time.get_ticks_msec() + 4000
	while banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not banner.visible


func _release_battle(battle, room_record: Dictionary) -> void:
	var battle_ref: WeakRef = weakref(battle)
	battle.queue_free()
	await _settle(8)
	room_record.cleanup = {"battle_released": battle_ref.get_ref() == null}


func _first_legal_spawn(cells: Array[Vector2i], grid: GridData) -> Vector2i:
	for cell in cells:
		if grid.is_valid(cell) and grid.is_walkable(cell) \
				and not grid.has_unit(cell):
			return cell
	return Vector2i(-1, -1)


func _nearest_reachable_destination(
		origin: Vector2i,
		reachable: Array
	) -> Vector2i:
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var candidate: Vector2i = origin + direction
		if reachable.has(candidate):
			return candidate
	for cell_value in reachable:
		var cell := cell_value as Vector2i
		if cell != origin:
			return cell
	return origin


func _find_spell(hero: Unit, spell_id: StringName) -> Spell:
	for spell_value in hero.spells:
		var spell := spell_value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _forbidden_equipment_nodes(root_node: Node) -> Array[String]:
	const TOKENS: Array[String] = [
		"weapon", "sword", "blade", "shield", "bow", "quiver",
		"equipment", "equipement", "arme", "lance",
	]
	var result: Array[String] = []
	var nodes: Array[Node] = [root_node]
	nodes.append_array(root_node.find_children("*", "Node", true, false))
	for node in nodes:
		var lowered := String(node.name).to_lower()
		for token in TOKENS:
			if token in lowered:
				result.append(String(node.get_path()))
				break
	return result


func _find_descendant_in_group(
		root_node: Node,
		group_name: StringName
	) -> Node:
	if root_node.is_in_group(group_name):
		return root_node
	for child in root_node.find_children("*", "Node", true, false):
		if child.is_in_group(group_name):
			return child
	return null


func _count_opaque_samples(image: Image) -> int:
	if image == null or image.is_empty():
		return 0
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).a > 0.02:
				count += 1
	return count


func _all_boolean_checks_pass(
		dictionary: Dictionary,
		ignored_keys: Array = []
	) -> bool:
	for key in dictionary:
		if key in ignored_keys:
			continue
		if dictionary[key] is bool and not bool(dictionary[key]):
			return false
	return true


func _all_room_records_pass() -> bool:
	if _report.rooms.size() != RUN.rooms.size():
		return false
	for room_record in _report.rooms:
		if not bool(room_record.get("passed", false)):
			return false
	return true


func _capture(file_name: String) -> Dictionary:
	await _settle(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _capture_dir.path_join(file_name)
	var save_error := (
		image.save_png(path)
		if image != null and not image.is_empty() else ERR_CANT_CREATE
	)
	var record := {
		"file": file_name,
		"path": path,
		"save_error": save_error,
		"size": (
			[image.get_width(), image.get_height()]
			if image != null else [0, 0]
		),
		"sha256": (
			FileAccess.get_sha256(path).to_upper()
			if save_error == OK else ""
		),
	}
	_report.captures.append(record)
	if save_error != OK:
		_fail("Capture failed: %s" % file_name)
	return record


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _is_full_git_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value.to_lower():
		if character not in "0123456789abcdef":
			return false
	return true


func _fail(message: String) -> void:
	if not _report.failures.has(message):
		_report.failures.append(message)
	push_error("ACHILLES ODYSSEY 3D PROMOTION: %s" % message)


func _finish() -> void:
	_report.status = "PASS" if _report.failures.is_empty() else "FAIL"
	if not _artifact_dir.is_empty() and _artifact_dir.is_absolute_path():
		var report_path := _artifact_dir.path_join(
			"achilles_odyssey_3d_runtime_promotion_smoke.json"
		)
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		if output == null:
			_fail("The external JSON report could not be written.")
			_report.status = "FAIL"
		else:
			output.store_string(JSON.stringify(_report, "  ", false) + "\n")
			output.close()
	print("ACHILLES_ODYSSEY_3D_PROMOTION=" + JSON.stringify(_report))
	get_tree().quit(0 if _report.status == "PASS" else 1)
