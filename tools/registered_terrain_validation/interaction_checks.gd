extends Node

const GEOMETRY := preload("res://tools/registered_terrain_validation/geometry_checks.gd")
var observed_clicks: Array[Vector2i] = []
var observed_hovers: Array[Vector2i] = []

func run(battle: Node, hero: Unit, grid: GridData, pathfinder: Pathfinder, view: Node2D, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var events: Array = []
	if hero == null:
		return {"errors": ["interaction_hero_missing"], "ok": false}
	view.cell_clicked.connect(_observe_click)
	view.cell_hovered.connect(_observe_hover)
	var state := battle.get("turn_state") as TurnState
	if not await _wait_for_player(battle, 8000):
		errors.append("player_intent_not_ready_for_test")
	# Route sprite-derived coordinates through the real GridView endpoints.
	# Window.get_mouse_position still polls the desktop pointer when synthetic
	# viewport events are pushed, so OS/window event routing is not claimed.
	var open_cells: Array[Vector2i] = []
	var rejected_cells: Array[Vector2i] = []
	var obstacle_sampled := false
	var void_sampled := false
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			if grid.is_terrain_interactable(cell):
				open_cells.append(cell)
			elif renderer.node_for_cell(cell) != null and not obstacle_sampled:
				rejected_cells.append(cell)
				obstacle_sampled = true
			elif renderer.node_for_cell(cell) == null and not void_sampled:
				rejected_cells.append(cell)
				void_sampled = true
	var sampled_cells: Array[Vector2i] = []
	for fraction: float in [0.0, 0.33, 0.66, 1.0]:
		if open_cells.is_empty():
			break
		var cell := open_cells[roundi(fraction * (open_cells.size() - 1))]
		if not sampled_cells.has(cell):
			sampled_cells.append(cell)
	for cell: Vector2i in sampled_cells:
		var sprite := _sprite(renderer, cell)
		if sprite == null or not grid.is_terrain_interactable(cell):
			continue
		var polygon := GEOMETRY.sprite_polygon(sprite)
		var center := (polygon[0] + polygon[2]) * 0.5
		var result := _route_local_pointer(view, center, true)
		result["expected_cell"] = [cell.x, cell.y]
		events.append(result)
		if view.get_hovered_cell() != cell or result.clicked_cells.size() != 1 or result.clicked_cells[0] != str(cell):
			errors.append("gridview_hover_click_route_failed:%s" % cell)
	battle._on_move_pressed()
	var initial_cell := hero.grid_pos
	var initial_mp := hero.current_mp
	var initial_ap := hero.current_ap
	# An obstacle has a physical floor but must reject input. A pit has neither.
	for blocked: Vector2i in rejected_cells:
		var arena := battle.get("room_data") as ArenaDefinition
		var polygon := GEOMETRY.analytic_polygon(arena, view, blocked)
		var result := _route_local_pointer(view, (polygon[0] + polygon[2]) * 0.5, true)
		result["expected_rejected_cell"] = [blocked.x, blocked.y]
		events.append(result)
		if not result.clicked_cells.is_empty() or view.get_hovered_cell() != Vector2i(-1, -1):
			errors.append("gridview_blocker_or_pit_input_accepted:%s" % blocked)
	if hero.grid_pos != initial_cell or hero.current_mp != initial_mp:
		errors.append("rejected_click_changed_unit")
	var target := initial_cell
	var move_path: Array = []
	for candidate: Vector2i in pathfinder.get_reachable(initial_cell, initial_mp, hero):
		if candidate == initial_cell:
			continue
		var candidate_path := pathfinder.find_path(initial_cell, candidate, hero)
		if candidate_path.size() >= 2 and (move_path.is_empty() or abs(candidate_path.size() - 3) < abs(move_path.size() - 3)):
			move_path = candidate_path
			target = candidate
	var expected_cost := int(pathfinder.path_cost_breakdown(move_path, hero).get("total", 0))
	if target == initial_cell or expected_cost <= 0 or expected_cost > initial_mp:
		errors.append("real_move_test_path_invalid")
	else:
		var sprite := _sprite(renderer, target)
		var polygon := GEOMETRY.sprite_polygon(sprite)
		var result := _route_local_pointer(view, (polygon[0] + polygon[2]) * 0.5, true)
		result["movement_destination"] = [target.x, target.y]
		events.append(result)
		var deadline := Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if hero.grid_pos == target and state.current != TurnState.State.ANIMATING and bool(battle._can_accept_player_intent()):
				break
	var movement := {
		"from": [initial_cell.x, initial_cell.y], "requested": [target.x, target.y],
		"actual": [hero.grid_pos.x, hero.grid_pos.y], "path_cells": move_path.size(),
		"mp_before": initial_mp, "mp_after": hero.current_mp, "expected_paid_mp": expected_cost,
		"actual_grid_occupancy": str(grid.find_unit(hero)),
		"source_cell_vacated": grid.get_unit(initial_cell) == null,
		"destination_contains_hero": grid.get_unit(target) == hero,
		"ap_before": initial_ap, "ap_after": hero.current_ap,
		"controller_returned_idle": state.current == TurnState.State.IDLE,
	}
	if hero.grid_pos != target or grid.find_unit(hero) != target or grid.get_unit(target) != hero or grid.get_unit(initial_cell) != null or hero.current_mp != initial_mp - expected_cost or hero.current_ap != initial_ap or state.current != TurnState.State.IDLE:
		errors.append("real_controller_movement_failed")
	var post_move_geometry := GEOMETRY.check_unit_footprints(battle, renderer)
	errors.append_array(post_move_geometry.errors)
	movement["footprints_after_move"] = post_move_geometry
	var guard: Spell = null
	for spell: Spell in hero.spells:
		if spell.is_self_only() and spell.get_scaled_shield(hero) > 0 and hero.can_use_spell(spell):
			guard = spell
			if spell.shield_tags.has(&"guard"):
				break
	var spell_result := {}
	if guard == null:
		errors.append("shield_guard_spell_missing")
	elif not await _wait_for_player(battle, 8000):
		errors.append("player_not_ready_after_movement")
	else:
		var before_ap := hero.current_ap
		var before_shield := hero.current_shield
		var before_uses := hero.get_spell_uses(guard)
		var expected_ap_cost: int = hero.get_spell_ap_cost(guard)
		var shield_source: StringName = guard.get_effective_spell_id()
		var before_source_shield: int = hero.get_shield_value(shield_source)
		var scaled_shield: int = guard.get_scaled_shield(hero)
		var expected_minimum_source_shield: int = maxi(before_source_shield, int(round(float(scaled_shield) * hero.shield_creation_multiplier)))
		var before_activation: int = hero.activation_index
		battle._on_spell_pressed(guard)
		var sprite := _sprite(renderer, hero.grid_pos)
		var polygon := GEOMETRY.sprite_polygon(sprite)
		var result := _route_local_pointer(view, (polygon[0] + polygon[2]) * 0.5, true)
		result["spell_target"] = [hero.grid_pos.x, hero.grid_pos.y]
		events.append(result)
		var deadline := Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if hero.current_ap != before_ap and not bool(battle.get("_spell_resolution_pending")) and state.current == TurnState.State.IDLE:
				break
		var after_source_shield: int = hero.get_shield_value(shield_source)
		var source_shield_delta: int = after_source_shield - before_source_shield
		var total_shield_delta: int = hero.current_shield - before_shield
		var expected_availability: StringName = &""
		if guard.cooldown_activations > 0:
			expected_availability = &"cooldown"
		elif guard.max_uses_per_combat > 0 and before_uses + 1 >= guard.max_uses_per_combat:
			expected_availability = &"max_uses"
		elif guard.once_per_activation:
			expected_availability = &"once_per_activation"
		elif not hero.can_afford_spell_resources(guard):
			expected_availability = &"pa"
		spell_result = {
			"spell_id": str(guard.get_effective_spell_id()),
			"ap_before": before_ap, "ap_after": hero.current_ap, "expected_ap_cost": expected_ap_cost,
			"shield_before": before_shield, "shield_after": hero.current_shield,
			"scaled_shield": scaled_shield, "shield_creation_multiplier": hero.shield_creation_multiplier,
			"source_shield_before": before_source_shield, "source_shield_after": after_source_shield,
			"expected_minimum_source_shield": expected_minimum_source_shield,
			"source_shield_delta": source_shield_delta, "total_shield_delta": total_shield_delta,
			"expected_availability": str(expected_availability), "expected_cooldown": guard.cooldown_activations,
			"activation_before": before_activation, "activation_after": hero.activation_index,
			"availability_after": str(hero.get_spell_availability_reason(guard)),
			"uses_before": before_uses, "uses_after": hero.get_spell_uses(guard),
			"cooldown_after": hero.get_spell_cooldown_remaining(guard),
			"controller_returned_idle": state.current == TurnState.State.IDLE,
		}
		if hero.current_ap != before_ap - expected_ap_cost or after_source_shield < expected_minimum_source_shield \
				or total_shield_delta < source_shield_delta or source_shield_delta < 0 \
				or hero.get_spell_uses(guard) != before_uses + 1 or hero.activation_index != before_activation \
				or hero.get_spell_cooldown_remaining(guard) != guard.cooldown_activations \
				or hero.get_spell_availability_reason(guard) != expected_availability or state.current != TurnState.State.IDLE:
			errors.append("real_controller_guard_cast_failed")
	view.cell_clicked.disconnect(_observe_click)
	view.cell_hovered.disconnect(_observe_hover)
	# Clear only probe hover/selection through existing presentation APIs.
	view.clear_selection()
	view.update_hover(Vector2(-100000, -100000))
	await get_tree().create_timer(0.5).timeout
	return {
		"ok": errors.is_empty(), "errors": errors,
		"input_api": "GridView.update_hover/click_at(sprite_viewport_point transformed by inverse GridView canvas)",
		"window_event_route_verified": false,
		"window_event_limitation": "Window mouse polling ignores positions injected with Viewport.push_input; no OS pointer warp used",
		"os_pointer_warped": false, "gridview_routing_cases": events,
		"observed_cell_click_signals": observed_clicks.size(), "observed_hover_signals": observed_hovers.size(),
		"movement": movement, "guard_cast": spell_result,
	}

func _route_local_pointer(view: Node2D, position: Vector2, click: bool) -> Dictionary:
	var before := observed_clicks.size()
	var local_point := view.get_global_transform_with_canvas().affine_inverse() * position
	var hover: Vector2i = view.update_hover(local_point)
	var clicked := Vector2i(-1, -1)
	if click:
		clicked = view.click_at(local_point)
	var emitted: Array[String] = []
	for index in range(before, observed_clicks.size()):
		emitted.append(str(observed_clicks[index]))
	return {
		"source_sprite_viewport_px": [position.x, position.y],
		"gridview_local_px": [local_point.x, local_point.y],
		"hovered_cell": str(hover), "clicked_cell": str(clicked), "clicked_cells": emitted,
	}
func _wait_for_player(battle: Node, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var state := battle.get("turn_state") as TurnState
		if state != null and state.current in [TurnState.State.IDLE, TurnState.State.MOVE, TurnState.State.TARGET_SPELL] \
				and bool(battle._can_accept_player_intent()) and not bool(battle.get("_spell_resolution_pending")):
			return true
		await get_tree().process_frame
	return false

func _sprite(renderer: ArenaTerrainVisualRenderer, cell: Vector2i) -> Sprite2D:
	var root := renderer.node_for_cell(cell)
	return root.get_node_or_null("Visual") as Sprite2D if root != null else null

func _observe_click(cell: Vector2i) -> void:
	observed_clicks.append(cell)

func _observe_hover(cell: Vector2i) -> void:
	observed_hovers.append(cell)



