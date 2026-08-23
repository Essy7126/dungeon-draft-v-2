extends Node

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")
const RUN_RESULT_SCENE: PackedScene = preload("res://ui/RunResultScreen.tscn")
const GAME_MANAGER_SCRIPT = preload("res://core/game_manager.gd")
const WINDOW_SIZE := Vector2i(1600, 1000)
const BACKEND_DEADLINE_MSEC := 8000
const ACTION_DEADLINE_MSEC := 10000
const EXPECTED_WALK_CLIP := &"achilles_v2__Walking"
const EXPECTED_RUN_CLIP := &"achilles_v2__run_fast_3_inplace"
const EXPECTED_HIT_CLIP := &"achilles_v2__Hit_Reaction_1"
const ANIMATION_SET_PATH := "res://data/characters/achilles/animations.tres"
const V2_PREVIEW_PATH := (
	"res://assets/characters/Achilles/3d/achilles_rig_animation_pool_v2.glb"
)
const EXPECTED_SPELL_CLIPS := {
	&"achilles_spear_thrust": &"achilles_v2__Left_Slash",
	&"achilles_advance": &"achilles_v2__run_fast_3_inplace",
	&"achilles_sweep": &"achilles_v2__Charged_Upward_Slash",
	&"achilles_guard": &"achilles_v2__Sword_Parry_Backward_2",
}

var _artifact_dir := ""
var _capture_dir := ""
var _report := {
	"schema": "dd.achilles.odyssey-3d-runtime-promotion-smoke.v2",
	"status": "FAIL",
	"run_path": "res://data/runs/odyssey.tres",
	"evidence_head": "",
	"runtime_provenance": {},
	"final_runtime_provenance": {},
	"scope": {
		"presentation_profile": "SUBVIEWPORT_384_PRODUCTION_PROFILE",
		"hub_selection": "PRODUCTION_HUB_CONTROLS_CALLED_PROGRAMMATICALLY",
		"battle_scenes": "THREE_PRODUCTION_ROOM_BATTLE_SCENES",
		"player_actions": "MOVE_PLUS_FOUR_PRODUCTION_SPELL_HANDLERS_CALLED_PROGRAMMATICALLY",
		"movement_threshold": "REAL_SHORT_MOVE_PLUS_FIVE_WALK_SIX_RUN_PRESENTATION_PROBES",
		"damage_and_death": "REAL_UNIT_DAMAGE_AND_LETHAL_DAMAGE_IN_PRODUCTION_BATTLE",
		"transitions": "FORCED_MANAGER_STATE_ADVANCE_WITHOUT_ENEMY_DEFEAT_SIMULATION",
		"physical_manual_input": false,
	},
	"hub": {},
	"runtime_contract": {},
	"rooms": [],
	"player_action_probe": {},
	"death_probe": {},
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
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var git_root := _derive_git_value(
		project_path, PackedStringArray(["rev-parse", "--show-toplevel"])
	)
	var actual_head := _derive_git_value(
		project_path, PackedStringArray(["rev-parse", "HEAD"])
	).to_lower()
	var git_status := _derive_git_value(
		project_path,
		PackedStringArray(["status", "--porcelain", "--untracked-files=all"]),
	)
	var version_info := Engine.get_version_info()
	_report.runtime_provenance = {
		"project_path": project_path,
		"git_root": git_root,
		"actual_head": actual_head,
		"worktree_clean": git_status.is_empty(),
		"git_status": git_status,
		"godot_version": Engine.get_version_info().get("string", ""),
	}
	if _normalize_path(git_root) != _normalize_path(project_path):
		_fail("The launched project is not the resolved Git worktree root.")
	if actual_head != _report.evidence_head.to_lower():
		_fail("The launched Git HEAD does not match --evidence-head.")
	if not git_status.is_empty():
		_fail("The launched Git worktree is dirty; evidence is not SHA-exact.")
	if (
		int(version_info.get("major", 0)) != 4
		or int(version_info.get("minor", 0)) != 7
		or int(version_info.get("patch", 0)) != 1
		or String(version_info.get("status", "")) != "stable"
	):
		_fail("The runtime must use Godot 4.7.1 stable.")
	if not _report.failures.is_empty():
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
	var spell_ids: Array[StringName] = []
	for spell_value in hero_data.spells:
		var spell := spell_value as Spell
		if spell != null:
			spell_ids.append(spell.get_effective_spell_id())
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
		"v2_preview_selected": (
			hero_data.preview_visual_scene != null
			and hero_data.preview_visual_scene.resource_path == V2_PREVIEW_PATH
		),
		"animation_pool_selected": (
			hero_data.animation_set != null
			and hero_data.animation_set.resource_path == ANIMATION_SET_PATH
		),
		"four_expected_spells": spell_ids == [
			&"achilles_spear_thrust",
			&"achilles_advance",
			&"achilles_sweep",
			&"achilles_guard",
		],
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
		"three_real_rooms_loaded": _report.rooms.size() == 3,
		"all_room_checks_passed": _all_room_records_pass(),
		"all_four_spells_exercised": (
			_report.player_action_probe.get("spells", []).size() == 4
		),
		"real_hit_feedback_passed": bool(
			_report.player_action_probe.get("hit", {}).get("passed", false)
		),
		"real_death_feedback_passed": bool(
			_report.death_probe.get("passed", false)
		),
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
		if not _all_boolean_checks_pass(room_record.initiative_portrait):
			_fail(
				"Room %d Achilles initiative portrait is not the live V2 preview."
				% (room_index + 1)
			)
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
		if room_index == 2:
			_report.death_probe = await _exercise_real_death_feedback(
				battle, hero, unit_view, adapter, enemies
			)
			if not bool(_report.death_probe.get("passed", false)):
				_fail("The production Achilles death feedback probe failed.")
			var defeated_battle_ref: WeakRef = weakref(battle)
			battle.queue_free()
			await _settle(10)
			# Cancels the production delayed defeat navigation after the fade has
			# been observed, so this isolated runner remains owner of its scene.
			GameManager.cleanup_run_state()
			room_record.cleanup = {
				"battle_released": defeated_battle_ref.get_ref() == null,
			}
			room_record.passed = (
				_all_boolean_checks_pass(room_record.checks)
				and _all_boolean_checks_pass(room_record.initiative_portrait)
				and bool(_report.death_probe.get("passed", false))
				and _all_boolean_checks_pass(room_record.cleanup)
			)
			if not room_record.passed:
				_fail("Room 3 did not pass its complete death/cleanup audit.")
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
			and _all_boolean_checks_pass(room_record.initiative_portrait)
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
	var opaque_bounds := _opaque_bounds(viewport_image)
	var painted_visual_scale := (
		float(unit_view.get_painted_visual_scale())
		if unit_view.has_method("get_painted_visual_scale")
		else absf(adapter.scale.y)
	)
	var adapter_canvas_scale := absf(adapter.scale.y)
	var displayed_character_height := (
		float(opaque_bounds.size.y)
		* absf(backend.rendered_sprite.scale.y)
		* adapter_canvas_scale
	)
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
		# The verified-error fallback resource is part of the profile dependency
		# graph, so cache presence is not a nominal-runtime signal. The production
		# contract is that no fallback instance exists while Viewport3D is healthy.
		"nominal_fallback_not_instantiated": adapter.fallback_backend == null,
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
		"painted_visual_scale": painted_visual_scale,
		"adapter_canvas_scale": adapter_canvas_scale,
		"painted_scale_matches_three_hero_reference_band": (
			painted_visual_scale >= 1.8 and painted_visual_scale <= 2.0
		),
		"adapter_received_painted_scale": is_equal_approx(
			adapter_canvas_scale, painted_visual_scale
		),
		"displayed_character_height_px": displayed_character_height,
		"character_has_nonzero_projected_height": (
			displayed_character_height > 1.0
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
	var fallback_hidden := not card.fallback_portrait.visible
	var preview_visual := card.preview.get_visual_instance()
	var preview_non_empty := (
		card.preview.visible
		and preview_visual != null
		and card.preview.preview_viewport.get_texture() != null
	)
	var preview_pixels := 0
	if preview_non_empty:
		preview_pixels = _count_opaque_samples(
			card.preview.preview_viewport.get_texture().get_image()
		)
	var pool_clips_present := false
	if preview_visual != null:
		var players := preview_visual.find_children(
			"*", "AnimationPlayer", true, false
		)
		if not players.is_empty():
			var player := players[0] as AnimationPlayer
			pool_clips_present = (
				player.has_animation(EXPECTED_WALK_CLIP)
				and player.has_animation(EXPECTED_RUN_CLIP)
				and player.has_animation(EXPECTED_HIT_CLIP)
			)
	return {
		"available": true,
		"card_count": timeline.get_card_count(),
		"fallback_portrait_hidden": fallback_hidden,
		"preview_non_empty": preview_non_empty,
		"preview_contains_visible_pixels": preview_pixels > 0,
		"v2_pool_clips_present_in_preview": pool_clips_present,
		"mode": "3D_PREVIEW" if preview_non_empty else "MISSING",
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
		"spells": [],
		"hit": {},
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
	var move_clip_observed: StringName = &""
	if active_before == hero and destination != move_from:
		battle._on_move_pressed()
		move_mode_entered = battle.turn_state.current == TurnState.State.MOVE
		battle._on_cell_clicked(destination)
		await _settle(1)
		var visual_3d := adapter.viewport_backend.get_achilles_visual()
		move_feedback_observed = (
			visual_3d != null
			and visual_3d.get_active_semantic() == &"WALK"
		)
		if visual_3d != null and visual_3d.get_animation_player() != null:
			move_clip_observed = StringName(
				visual_3d.get_animation_player().current_animation
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
		"feedback_walk_semantic_observed": move_feedback_observed,
		"production_move_uses_walk_clip": move_clip_observed == EXPECTED_WALK_CLIP,
		"cell_changed": hero.grid_pos == destination and destination != move_from,
		"mp_spent": hero.current_mp < mp_before,
		"unit_view_moved": unit_view.position != view_position_before,
		"returned_to_idle": battle.turn_state.current == TurnState.State.IDLE,
	}
	var visual_3d := adapter.viewport_backend.get_achilles_visual()
	var animation_player := (
		visual_3d.get_animation_player() if visual_3d != null else null
	)
	adapter.begin_path_movement_feedback(_straight_path(5))
	movement["five_cell_path_selects_walk"] = (
		adapter._movement_action_id == &"walk"
		and visual_3d != null
		and visual_3d.get_active_semantic() == &"WALK"
		and animation_player != null
		and StringName(animation_player.current_animation) == EXPECTED_WALK_CLIP
	)
	adapter.cancel_movement_feedback()
	adapter.begin_path_movement_feedback(_straight_path(6))
	movement["six_cell_path_selects_run"] = (
		adapter._movement_action_id == &"run"
		and visual_3d != null
		and visual_3d.get_active_semantic() == &"RUN"
		and animation_player != null
		and StringName(animation_player.current_animation) == EXPECTED_RUN_CLIP
	)
	movement["six_cell_run_scope"] = (
		"PRESENTATION_THRESHOLD_PROBE_MAX_MP_REMAINS_THREE"
	)
	adapter.cancel_movement_feedback()
	movement["passed"] = _all_boolean_checks_pass(movement)
	record.movement = movement

	var enemies: Array = battle.units.filter(func(value):
		return value != null and (value as Unit).team == 1
	)
	var all_spells_passed := true
	for spell_id: StringName in [
		&"achilles_spear_thrust",
		&"achilles_advance",
		&"achilles_sweep",
		&"achilles_guard",
	]:
		var spell_record := await _exercise_real_spell_handler(
			battle, hero, unit_view, adapter, enemies, spell_id
		)
		record.spells.append(spell_record)
		if not bool(spell_record.get("passed", false)):
			all_spells_passed = false
			_fail("Production spell handler failed for %s." % spell_id)

	record.hit = await _exercise_real_hit_feedback(
		hero, adapter, enemies
	)
	record.passed = (
		movement.passed
		and record.spells.size() == 4
		and all_spells_passed
		and bool(record.hit.get("passed", false))
	)
	return record


func _exercise_real_spell_handler(
		battle,
		hero: Unit,
		unit_view,
		adapter: AchillesIsoUnitView,
		enemies: Array,
		spell_id: StringName
	) -> Dictionary:
	var spell := _find_spell(hero, spell_id)
	var expected_clip := StringName(EXPECTED_SPELL_CLIPS.get(spell_id, &""))
	var record := {
		"spell_id": String(spell_id),
		"expected_clip": String(expected_clip),
		"target": [-1, -1],
		"release_count": 0,
		"finish_count": 0,
		"started_count": 0,
		"passed": false,
	}
	if spell == null or expected_clip == &"":
		return record
	# Each spell gets a fresh production activation budget. This does not alter
	# RunData: it emulates four successive Achilles turns inside one real room.
	hero.start_turn()
	if battle.turn_state != null:
		battle.turn_state.begin_player_turn()
	if battle.action_bar != null:
		battle.action_bar.set_player_controls_enabled(true)
		battle.action_bar.update_info(hero)
	var banner_hidden_before_cast := await _wait_for_turn_intro_banner_hidden(
		battle
	)
	var controls_enabled_before_cast := (
		battle.action_bar != null
		and bool(battle.action_bar.get("_player_controls_enabled"))
	)
	var target := _prepare_spell_target(
		battle, hero, spell, enemies
	)
	record.target = [target.x, target.y]
	var targetables: Array = battle.spell_caster.get_targetable_cells(
		hero, spell
	)
	var can_cast_before: bool = (
		target != Vector2i(-1, -1)
		and targetables.has(target)
		and battle.spell_caster.can_cast(hero, spell, target)
	)
	var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
		spell_id
	)
	var signal_state := {
		"started": 0,
		"release": 0,
		"finish": 0,
		"started_action": &"",
		"finished_actions": [],
		"clip": &"",
	}
	var on_started := func(started_action: StringName) -> void:
		signal_state.started += 1
		signal_state.started_action = started_action
		var visual := adapter.viewport_backend.get_achilles_visual()
		if visual != null and visual.get_animation_player() != null:
			signal_state.clip = StringName(
				visual.get_animation_player().current_animation
			)
	var on_release := func() -> void:
		signal_state.release += 1
	var on_finish := func(finished_action: StringName) -> void:
		signal_state.finish += 1
		signal_state.finished_actions.append(finished_action)
	adapter.viewport_backend.action_started.connect(on_started)
	adapter.cast_release_reached.connect(on_release)
	adapter.animation_finished.connect(on_finish)
	var ap_before := hero.current_ap
	var shield_before := hero.current_shield
	var hero_cell_before := hero.grid_pos
	var unit_view_position_before: Vector2 = unit_view.position
	var enemy_state_before := _unit_combat_snapshots(enemies)
	var target_mode_entered := false
	if can_cast_before:
		battle._on_spell_pressed(spell)
		target_mode_entered = (
			battle.turn_state.current == TurnState.State.TARGET_SPELL
		)
		battle._on_cell_clicked(target)
		await _capture("room_01_%s_action.png" % String(spell_id))
		var deadline := Time.get_ticks_msec() + ACTION_DEADLINE_MSEC
		while (bool(battle.get("_spell_resolution_pending")) \
				or int(signal_state.finish) < 1) \
				and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		await _settle(3)
	if adapter.viewport_backend.action_started.is_connected(on_started):
		adapter.viewport_backend.action_started.disconnect(on_started)
	if adapter.cast_release_reached.is_connected(on_release):
		adapter.cast_release_reached.disconnect(on_release)
	if adapter.animation_finished.is_connected(on_finish):
		adapter.animation_finished.disconnect(on_finish)
	var effect_changed := (
		hero.current_shield != shield_before
		or hero.grid_pos != hero_cell_before
		or _unit_combat_snapshots(enemies) != enemy_state_before
	)
	var is_advance := spell_id == &"achilles_advance"
	var expected_view_position: Vector2 = battle.grid_cell_to_parent_local(
		hero.grid_pos, unit_view.get_parent()
	)
	record.merge({
		"uses_real_spell_caster": battle.spell_caster != null,
		"turn_intro_banner_hidden_before_cast": banner_hidden_before_cast,
		"player_controls_enabled_before_cast": controls_enabled_before_cast,
		"target_listed_by_spell_caster": targetables.has(target),
		"can_cast_before": can_cast_before,
		"target_mode_entered": target_mode_entered,
		"started_count": int(signal_state.started),
		"release_count": int(signal_state.release),
		"finish_count": int(signal_state.finish),
		"started_exactly_once": int(signal_state.started) == 1,
		"release_exactly_once": int(signal_state.release) == 1,
		"finish_exactly_once": int(signal_state.finish) == 1,
		"exact_action_id_started": (
			StringName(signal_state.started_action) == action_id
		),
		"exact_action_id_finished": (
			signal_state.finished_actions == [action_id]
		),
		"exact_mapped_clip_played": (
			StringName(signal_state.clip) == expected_clip
		),
		"ap_cost_applied": hero.current_ap == ap_before - spell.ap_cost,
		"combat_effect_applied": effect_changed,
		"advance_grid_position_changed": (
			not is_advance or hero.grid_pos != hero_cell_before
		),
		"advance_unit_view_position_changed": (
			not is_advance or unit_view.position != unit_view_position_before
		),
		"advance_unit_view_matches_resolved_grid_cell": (
			not is_advance
			or unit_view.position.is_equal_approx(expected_view_position)
		),
		"resolution_not_pending": not bool(
			battle.get("_spell_resolution_pending")
		),
		"returned_to_idle": (
			battle.turn_state.current == TurnState.State.IDLE
		),
		"viewport_backend_still_active": (
			adapter.get_active_backend_name() == &"Viewport3DBackend"
			and adapter.fallback_backend == null
		),
	}, true)
	record.passed = _all_boolean_checks_pass(record, [
		"passed",
	])
	return record


func _prepare_spell_target(
		battle,
		hero: Unit,
		spell: Spell,
		enemies: Array
	) -> Vector2i:
	if spell == null:
		return Vector2i(-1, -1)
	if spell.is_self_only():
		if spell.get_effective_spell_id() == &"achilles_sweep":
			_relocate_enemy_for_targeting(
				battle, hero, spell, enemies, [1]
			)
		return hero.grid_pos
	if spell.get_effective_spell_id() == &"achilles_advance":
		return _relocate_enemy_for_targeting(
			battle, hero, spell, enemies, [2, 3, 1]
		)
	for target_value in battle.spell_caster.get_targetable_cells(hero, spell):
		var target := target_value as Vector2i
		var occupant = battle.grid.get_unit(target)
		if occupant != null and occupant.team != hero.team:
			return target
	var preferred_distances: Array[int] = [1, 2]
	return _relocate_enemy_for_targeting(
		battle, hero, spell, enemies, preferred_distances
	)


func _relocate_enemy_for_targeting(
		battle,
		hero: Unit,
		spell: Spell,
		enemies: Array,
		preferred_distances: Array[int]
	) -> Vector2i:
	var enemy: Unit = null
	for enemy_value in enemies:
		var candidate_enemy := enemy_value as Unit
		if candidate_enemy != null and candidate_enemy.is_alive:
			enemy = candidate_enemy
			break
	if enemy == null:
		return Vector2i(-1, -1)
	for distance in preferred_distances:
		for direction in [
			Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
		]:
			var cell: Vector2i = hero.grid_pos + direction * distance
			if not battle.grid.is_valid(cell) \
					or not battle.grid.is_walkable(cell) \
					or battle.grid.has_unit(cell):
				continue
			var old_cell := enemy.grid_pos
			if not battle.grid.relocate_unit(enemy, cell):
				continue
			var views := battle.get("_unit_views") as Dictionary
			var enemy_view = views.get(enemy)
			if enemy_view != null:
				enemy_view.position = battle.grid_cell_to_parent_local(
					cell, enemy_view.get_parent()
				)
			if spell.is_self_only() \
					or battle.spell_caster.is_valid_target(hero, spell, cell):
				return cell
			battle.grid.relocate_unit(enemy, old_cell)
	return Vector2i(-1, -1)


func _unit_combat_snapshots(units: Array) -> Array:
	var result: Array = []
	for unit_value in units:
		var unit := unit_value as Unit
		if unit == null:
			continue
		result.append({
			"id": String(unit.unit_id),
			"hp": unit.current_hp,
			"cell": [unit.grid_pos.x, unit.grid_pos.y],
			"alive": unit.is_alive,
		})
	return result


func _exercise_real_hit_feedback(
		hero: Unit,
		adapter: AchillesIsoUnitView,
		enemies: Array
	) -> Dictionary:
	var attacker: Unit = enemies[0] as Unit if not enemies.is_empty() else null
	var visual := adapter.viewport_backend.get_achilles_visual()
	var player := visual.get_animation_player() if visual != null else null
	var counters := {"release": 0, "finish": 0}
	var on_release := func() -> void: counters.release += 1
	var on_finish := func(_action: StringName) -> void: counters.finish += 1
	adapter.cast_release_reached.connect(on_release)
	adapter.animation_finished.connect(on_finish)
	hero.current_shield = 0
	var hp_before := hero.current_hp
	hero.take_damage(
		4, attacker, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "ignore_defense": true}
	)
	var hit_started := (
		visual != null
		and visual.get_active_semantic() == &"HIT"
		and player != null
		and StringName(player.current_animation) == EXPECTED_HIT_CLIP
	)
	await _capture("room_01_achilles_hit.png")
	var deadline := Time.get_ticks_msec() + ACTION_DEADLINE_MSEC
	while visual != null and visual.get_active_semantic() == &"HIT" \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if adapter.cast_release_reached.is_connected(on_release):
		adapter.cast_release_reached.disconnect(on_release)
	if adapter.animation_finished.is_connected(on_finish):
		adapter.animation_finished.disconnect(on_finish)
	var record := {
		"hp_damage_applied": hero.current_hp == hp_before - 4,
		"hit_semantic_and_clip_started": hit_started,
		"returned_to_idle": (
			visual != null and visual.get_active_semantic() == &"IDLE"
		),
		"cast_release_not_emitted": counters.release == 0,
		"cast_finish_not_emitted": counters.finish == 0,
		"viewport_backend_still_active": (
			adapter.get_active_backend_name() == &"Viewport3DBackend"
			and adapter.fallback_backend == null
		),
	}
	record["passed"] = _all_boolean_checks_pass(record)
	return record


func _exercise_real_death_feedback(
		battle,
		hero: Unit,
		unit_view,
		adapter: AchillesIsoUnitView,
		enemies: Array
	) -> Dictionary:
	var attacker: Unit = enemies[0] as Unit if not enemies.is_empty() else null
	var signal_state := {"death": 0}
	var on_death_finished := func() -> void: signal_state.death += 1
	adapter.death_animation_finished.connect(on_death_finished)
	var unit_view_ref: WeakRef = weakref(unit_view)
	var adapter_ref: WeakRef = weakref(adapter)
	var viewport_ref: WeakRef = weakref(
		adapter.viewport_backend.character_viewport
	)
	var backend_nominal_before := (
		adapter.get_active_backend_name() == &"Viewport3DBackend"
		and adapter.fallback_backend == null
	)
	hero.current_shield = 0
	hero.take_damage(
		hero.current_hp + 9999,
		attacker,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{"cannot_be_dodged": true, "ignore_defense": true}
	)
	await _capture("room_03_achilles_death.png")
	var deadline := Time.get_ticks_msec() + ACTION_DEADLINE_MSEC
	while (int(signal_state.death) < 1 or unit_view_ref.get_ref() != null) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _settle(3)
	var record := {
		"scope": "REAL_ROOM_UNIT_DEATH_WITH_ADAPTER_FADE_FALLBACK",
		"viewport_backend_nominal_before_death": backend_nominal_before,
		"hero_is_dead": not hero.is_alive and hero.current_hp == 0,
		"death_signal_exactly_once": int(signal_state.death) == 1,
		"battle_registered_defeat": bool(battle.get("_battle_over")),
		"unit_view_released": unit_view_ref.get_ref() == null,
		"adapter_released": adapter_ref.get_ref() == null,
		"subviewport_released": viewport_ref.get_ref() == null,
	}
	record["passed"] = _all_boolean_checks_pass(record)
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


func _straight_path(step_count: int) -> Array:
	var path: Array = []
	for x in range(step_count + 1):
		path.append(Vector2i(x, 0))
	return path


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


func _opaque_bounds(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


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


func _derive_git_value(
	project_path: String,
	arguments: PackedStringArray
	) -> String:
	var output: Array = []
	var git_arguments := PackedStringArray(["-C", project_path])
	git_arguments.append_array(arguments)
	var exit_code := OS.execute("git", git_arguments, output, true)
	if exit_code != 0 or output.is_empty():
		return ""
	return "\n".join(PackedStringArray(output)).strip_edges()


func _normalize_path(value: String) -> String:
	return value.replace("\\", "/").trim_suffix("/").to_lower()


func _revalidate_runtime_provenance() -> void:
	if not _is_full_git_sha(_report.evidence_head):
		return
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var git_root := _derive_git_value(
		project_path, PackedStringArray(["rev-parse", "--show-toplevel"])
	)
	var actual_head := _derive_git_value(
		project_path, PackedStringArray(["rev-parse", "HEAD"])
	).to_lower()
	var git_status := _derive_git_value(
		project_path,
		PackedStringArray(["status", "--porcelain", "--untracked-files=all"]),
	)
	_report.final_runtime_provenance = {
		"project_path": project_path,
		"git_root": git_root,
		"actual_head": actual_head,
		"worktree_clean": git_status.is_empty(),
		"git_status": git_status,
	}
	if _normalize_path(git_root) != _normalize_path(project_path):
		_fail("Final Git root no longer matches the launched project.")
	if actual_head != _report.evidence_head.to_lower():
		_fail("Git HEAD changed while the runtime smoke was executing.")
	if not git_status.is_empty():
		_fail("The worktree changed while the runtime smoke was executing.")


func _fail(message: String) -> void:
	if not _report.failures.has(message):
		_report.failures.append(message)
	push_error("ACHILLES ODYSSEY 3D PROMOTION: %s" % message)


func _finish() -> void:
	_revalidate_runtime_provenance()
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
