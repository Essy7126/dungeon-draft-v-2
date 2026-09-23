extends "res://tools/catabase_monster_validation/first_six_playtest.gd"
## Continuous Catabase probe. It reuses the bounded headless combat policy but
## preserves the production hero/session/inventory across all route boundaries.

const Contract = preload("res://tools/catabase_run_balance_validation/run_validation_contract.gd")
const BattlefieldCleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
const MAX_HERO_TURNS := 60
const MAX_ACTIVATIONS := 1400
const RESUME_AFTER_COMBATS: Array[int] = [4, 8]
const ROOT_BY_WEAPON := {
	"marteau": "ct_masse",
	"xiphos": "ct_salve",
	"disque": "ct_retour",
	"hampe": "ct_braise",
	"lame": "ct_entaille",
	"arc": "ct_peage",
}

var _difficulties: Array[String] = ["normal", "easy"]
var _policies: Array[String] = ["balanced"]
var _weapons: Array[String] = []
var _active_policy := "balanced"
var _active_hero: Unit = null
var _active_metrics: Dictionary = { }
var _planned_routes: Dictionary = { }
var _fallback_objective_enemy_id := ""
var _last_offensive_turn := 0
var _cards_mode := false


class HarnessManager:
	extends "res://core/game_manager.gd"
	var suppressed_battle_requests := 0


	func start_next_battle() -> void:
		suppressed_battle_requests += 1


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _run() -> void:
	_parse_arguments()
	output = "res://artifacts/catabase_run_balance_validation/" + label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_connect_metric_signals()
	for seed_value: int in seeds:
		for difficulty: String in _difficulties:
			var route_key := "%d:%s" % [seed_value, difficulty]
			_planned_routes[route_key] = _planned_route(seed_value, difficulty)
			for policy: String in _policies:
				for weapon: String in _weapons:
					var run_result := await _simulate_run(seed_value, difficulty, weapon, policy)
					results.append(run_result)
					print("CATABASE_FULL_RUN ", JSON.stringify(run_result))
					_write_report()
					await get_tree().process_frame
	_disconnect_metric_signals()
	_write_report()
	var expected := seeds.size() * _difficulties.size() * _policies.size() * _weapons.size()
	print(
		"CATABASE_FULL_RUN_VALIDATION cases=%d expected=%d errors=%d output=%s"
		% [results.size(), expected, errors.size(), output]
	)
	get_tree().quit(0 if errors.is_empty() and results.size() == expected else 1)


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "cards=true":
			_cards_mode = true
		elif argument.begins_with("label="):
			label = argument.trim_prefix("label=").validate_filename()
		elif argument.begins_with("seeds="):
			seeds.clear()
			for value: String in argument.trim_prefix("seeds=").split(",", false):
				var parsed := int(value)
				if parsed >= 0 and parsed <= 0x7fffffff and parsed not in seeds:
					seeds.append(parsed)
		elif argument.begins_with("difficulties="):
			_difficulties.clear()
			for value: String in argument.trim_prefix("difficulties=").split(",", false):
				if value in Contract.DIFFICULTIES and value not in _difficulties:
					_difficulties.append(value)
		elif argument.begins_with("policies="):
			_policies.clear()
			for value: String in argument.trim_prefix("policies=").split(",", false):
				if Contract.POLICIES.has(value) and value not in _policies:
					_policies.append(value)
		elif argument.begins_with("weapons="):
			_weapons.clear()
			for value: String in argument.trim_prefix("weapons=").split(",", false):
				if value in Contract.weapon_ids() and value not in _weapons:
					_weapons.append(value)
	if label.is_empty():
		label = "full_run"
	if seeds.is_empty():
		errors.append("At least one valid seed is required")
		seeds.assign(Contract.DEFAULT_SEEDS)
	if _difficulties.is_empty():
		errors.append("At least one valid difficulty is required")
		_difficulties.assign(Contract.DIFFICULTIES)
	if _policies.is_empty():
		errors.append("At least one valid policy is required")
		_policies.assign(["balanced"])
	if _weapons.is_empty():
		_weapons.assign(Contract.weapon_ids())


func _planned_route(seed_value: int, difficulty: String) -> Dictionary:
	var route := ExpeditionRouteState.new()
	route.initialize(seed_value, ExpeditionRouteCatalog.REVISION, difficulty)
	var path: Array[Dictionary] = []
	var combat_depths: Array[int] = []
	for transition in 24:
		if route.phase == "complete":
			break
		var next := Contract.choose_route_node(
			route.get_available_nodes(),
			seed_value,
			route.completed_node_ids.size() + 1,
		)
		if next.is_empty() or not route.choose_node(str(next.id)):
			errors.append("Planned route cannot enter depth %d" % (path.size() + 1))
			break
		var actual := route.get_current_node()
		path.append(_route_entry(actual))
		if ExpeditionRouteCatalog.is_combat(str(actual.kind)):
			combat_depths.append(int(actual.depth))
			if not route.mark_combat_won():
				errors.append("Planned route cannot resolve " + str(actual.id))
				break
		if not route.complete_current_node():
			errors.append("Planned route cannot complete " + str(actual.id))
			break
	if combat_depths != Contract.EXPECTED_COMBAT_DEPTHS:
		errors.append(
			"Revision %d route has combat depths %s instead of %s"
			% [ExpeditionRouteCatalog.REVISION, combat_depths, Contract.EXPECTED_COMBAT_DEPTHS]
		)
	return {
		"seed": seed_value,
		"difficulty": difficulty,
		"catalog_revision": route.get_catalog_revision(),
		"balance_revision": route.get_balance_revision(),
		"route_policy": Contract.ROUTE_POLICY_ID,
		"combat_depths": combat_depths,
		"path": path,
	}


func _simulate_run(
	seed_value: int,
	difficulty: String,
	weapon: String,
	policy: String,
) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var manager := HarnessManager.new()
	manager.name = "Harness_%d_%s_%s_%s" % [seed_value, difficulty, weapon, policy]
	manager.expedition_save_path = ProjectSettings.globalize_path(
		output.path_join("resume_%d_%s_%s_%s.json" % [seed_value, difficulty, weapon, policy])
	)
	add_child(manager)
	var start_ok := manager.start_expedition(seed_value, { }, false, true, difficulty, _cards_mode)
	if not start_ok:
		var message := "Run setup failed: %d/%s/%s/%s" % [seed_value, difficulty, weapon, policy]
		errors.append(message)
		manager.queue_free()
		await get_tree().process_frame
		return _failed_run(seed_value, difficulty, weapon, policy, message)
	var session: ExpeditionSession = manager.expedition
	var selection := _run_preparation(weapon)
	selection["difficulty_id"] = difficulty
	var preparation := session.prepare_start(selection, manager.run_inventory, manager.item_catalog)
	if not bool(preparation.get("success", false)) or not session.enter("d01_0"):
		var message := "Preparation failed: %s" % str(preparation)
		errors.append(message)
		manager.cleanup_run_state()
		manager.queue_free()
		await get_tree().process_frame
		return _failed_run(seed_value, difficulty, weapon, policy, message)
	var run_result := {
		"variant": "cards" if _cards_mode else "classic",
		"deck_policy": "starter deck, no retain/recompose or card transactions" if _cards_mode else "not applicable",
		"seed": seed_value,
		"difficulty": difficulty,
		"weapon": weapon,
		"policy": policy,
		"route_policy": Contract.ROUTE_POLICY_ID,
		"catalog_revision": session.route.get_catalog_revision(),
		"balance_revision": session.route.get_balance_revision(),
		"combat_rng_contract": "seed * 1000 + depth * 37 + 11",
		"human_win_rate_claim": false,
		"combats": [] as Array[Dictionary],
		"route": [_route_entry(session.route.get_current_node())] as Array[Dictionary],
		"resumes": [] as Array[Dictionary],
		"halts": [] as Array[Dictionary],
		"outcome": "incomplete",
		"death_depth": 0,
		"structural_errors": [] as Array[String],
	}
	_active_policy = policy
	for transition in 80:
		session = manager.expedition
		if session == null:
			run_result.structural_errors.append("Session disappeared")
			break
		var hero: Unit = session.character.unit
		match session.route.phase:
			"combat":
				var node := session.route.get_current_node()
				var combat := await _fight_continuous(node, manager, seed_value, weapon, policy)
				(run_result.combats as Array).append(combat)
				print(
					"CATABASE_COMBAT seed=%d difficulty=%s weapon=%s policy=%s depth=%d won=%s hp=%d turns=%d idle=%d fallback=%d termination=%s"
					% [
						seed_value,
						difficulty,
						weapon,
						policy,
						int(combat.get("depth", 0)),
						str(combat.get("won", false)),
						int(combat.get("hp_after_combat", -1)),
						int(combat.get("turns", 0)),
						int(combat.get("idle_turns", 0)),
						int(combat.get("fallback_path_moves", 0)),
						str(combat.get("termination", "")),
					]
				)
				if not bool(combat.get("won", false)):
					run_result.outcome = str(combat.get("bot_diagnostic", "bot_combat_loss"))
					run_result.death_depth = int(node.depth)
					break
				if not session.combat_won():
					run_result.structural_errors.append(
						"Victory boundary refused at " + str(node.id)
					)
					break
				combat["hp_after_level"] = hero.current_hp
				combat["level_after"] = hero_level(hero, session)
				_resolve_advancement(session, policy)
				combat["hp_after_level_choices"] = hero.current_hp
				var build_update := _spend_build_points(session, weapon)
				combat["build_purchases"] = build_update.purchases
				combat["build_equips"] = build_update.equipped
				combat["build_snapshot"] = build_update.snapshot
				var reward := _claim_combat_reward(session, manager, policy)
				combat["reward"] = reward
				combat["hp_after_provisions"] = hero.current_hp
				if not bool(reward.get("success", false)):
					run_result.structural_errors.append("Reward boundary failed at " + str(node.id))
					break
				if (
					session.route.phase == "map"
					and (run_result.combats as Array).size() in RESUME_AFTER_COMBATS
				):
					var resumed := _roundtrip_resume(manager, int(node.depth))
					(run_result.resumes as Array).append(resumed)
					if not bool(resumed.get("success", false)):
						run_result.structural_errors.append(
							"Resume failed after depth %d" % int(node.depth)
						)
						break
			"reward":
				var node := session.route.get_current_node()
				_resolve_advancement(session, policy)
				var halt_result := _resolve_halt(session, manager, policy, weapon)
				(run_result.halts as Array).append(halt_result)
				var combats := run_result.combats as Array
				if not combats.is_empty() and bool(halt_result.get("is_refuge", false)):
					var previous := combats[combats.size() - 1] as Dictionary
					previous["hp_after_refuge"] = halt_result.get("hp_after", hero.current_hp)
					previous["refuge_depth"] = int(node.depth)
					previous["refuge_heal"] = int(halt_result.get("healed", 0))
				if not bool(halt_result.get("success", false)):
					run_result.structural_errors.append("Halt boundary failed at " + str(node.id))
					break
			"map":
				var next := Contract.choose_route_node(
					session.route.get_available_nodes(),
					seed_value,
					session.route.completed_node_ids.size() + 1,
				)
				if next.is_empty() or not session.enter(str(next.id)):
					run_result.structural_errors.append(
						"No deterministic destination at depth %d"
						% (session.route.completed_node_ids.size() + 1)
					)
					break
				(run_result.route as Array).append(_route_entry(session.route.get_current_node()))
			"complete":
				run_result.outcome = "bot_completed_route"
				break
			_:
				run_result.structural_errors.append("Unknown route phase: " + session.route.phase)
				break
		if not (run_result.structural_errors as Array).is_empty() \
				or run_result.outcome != "incomplete":
			break
	if run_result.outcome == "incomplete" and not (run_result.structural_errors as Array).is_empty():
		run_result.outcome = "harness_error"
	for value in run_result.structural_errors:
		errors.append("%d/%s/%s/%s: %s" % [seed_value, difficulty, weapon, policy, value])
	run_result["combats_reached"] = (run_result.combats as Array).size()
	run_result["deepest_depth"] = _deepest_depth(run_result.combats)
	run_result["seconds"] = float(Time.get_ticks_usec() - started_usec) / 1_000_000.0
	_active_hero = null
	_active_metrics = { }
	manager.cleanup_run_state()
	manager.queue_free()
	await get_tree().process_frame
	return run_result


func _run_preparation(weapon: String) -> Dictionary:
	return CatabasePreparationCatalog.preset(weapon)


func _fight_continuous(
	node: Dictionary,
	manager: HarnessManager,
	seed_value: int,
	weapon: String,
	policy: String,
) -> Dictionary:
	var combat_rng_seed := seed_value * 1000 + int(node.depth) * 37 + 11
	seed(combat_rng_seed)
	var started_usec := Time.get_ticks_usec()
	var room := ExpeditionRunFactory.make_room(node, seed_value, manager.expedition.cards != null and manager.expedition.cards.rules_revision == 3 and manager.expedition.cards.ecosystem_revision > 0)
	if room == null:
		return _combat_failure(node, combat_rng_seed, "room_missing")
	var grid := EncounterGridFactory.build_from_room(room)
	if grid == null:
		return _combat_failure(node, combat_rng_seed, "grid_missing")
	var pathfinder := Pathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	terrain.capture_base_state(room, grid)
	var caster := SpellCaster.new(grid, pathfinder, terrain)
	caster.set_action_classification_catalog(
		manager.get_active_run_data().action_classification_catalog
	)
	var encounter_state := EncounterRuntimeState.new()
	if not encounter_state.initialize(room.encounter_definition):
		errors.append(str(node.id) + ": invalid encounter runtime state")
	else:
		caster.set_encounter_runtime_state(encounter_state)
	var plan := EncounterFormationPlanner.new(grid, pathfinder).build_plan(
		room.encounter_definition,
		room.hero_spawn_zone,
		room.enemy_spawn_zone,
		seed_value,
	)
	if not bool(plan.get("valid", false)):
		errors.append(str(node.id) + ": invalid formation")
		terrain.dispose()
		BattlefieldCleanup.dispose_grid(grid)
		return _combat_failure(node, combat_rng_seed, "formation_invalid")
	var hero: Unit = manager.expedition.character.unit
	hero.reset_combat_resources()
	if not grid.place_unit(hero, room.hero_spawn_zone[0]):
		errors.append(str(node.id) + ": hero placement failed")
		terrain.dispose()
		BattlefieldCleanup.dispose_grid(grid)
		return _combat_failure(node, combat_rng_seed, "hero_placement")
	var units: Array = [hero]
	var roster: Array[Dictionary] = []
	for placement: Dictionary in plan.placements:
		var enemy := Unit.from_data(placement.unit_data)
		grid.place_unit(enemy, placement.cell)
		units.append(enemy)
		roster.append(
			{
				"id": str(enemy.unit_id),
				"name": enemy.unit_name,
				"hp": enemy.current_hp,
				"attack": enemy.attack_power.get_int(),
				"cell": [enemy.grid_pos.x, enemy.grid_pos.y],
			}
		)
	var runtime: RelicRuntimeService = manager.get_relic_runtime_service()
	var adapter := MasteryCombatAdapter.new()
	adapter.configure(grid, caster, terrain, pathfinder, units, runtime)
	pathfinder.set_voluntary_cost_modifier(adapter.modify_movement_cost)
	var ai := EnemyAI.new(grid, pathfinder, caster)
	var queue := TurnQueue.new()
	queue.setup(units)
	var tactical_rules = null
	if room.has_meta("card_tactical_room_id"):
		var room_id := str(room.get_meta("card_tactical_room_id"))
		tactical_rules = preload("res://core/expedition/card_tactical_room_catalog.gd").create_rules(room_id)
		tactical_rules.bind(room_id, grid, terrain, units, func(): return queue.get_current_unit() == hero and hero.is_alive)
		var tactical_ai = preload("res://core/ai/tactical_room_enemy_ai.gd").new(grid, pathfinder, caster)
		tactical_ai.room_rules = tactical_rules
		ai = tactical_ai
	var metrics := {
		"title": str(node.title),
		"node_id": str(node.id),
		"encounter_profile_id": str(node.get("encounter_profile_id", "")),
		"route_family": str(node.get("route_family", "")),
		"depth": int(node.depth),
		"kind": str(node.kind),
		"seed": seed_value,
		"combat_rng_seed": combat_rng_seed,
		"difficulty": str(node.get("difficulty_id", manager.expedition.route.difficulty_id)),
		"weapon": weapon,
		"policy": policy,
		"hp_entry": hero.current_hp,
		"max_hp_entry": hero.max_hp.get_int(),
		"hp_after_combat": hero.current_hp,
		"hp_after_level": hero.current_hp,
		"hp_after_level_choices": hero.current_hp,
		"hp_after_provisions": hero.current_hp,
		"hp_after_refuge": null,
		"level_entry": hero_level(hero, manager.expedition),
		"level_after": hero_level(hero, manager.expedition),
		"raw_damage_received_known": 0,
		"known_raw_hit_count": 0,
		"resolved_damage_before_shield": 0,
		"resolved_hit_count": 0,
		"resolved_damage_by_ability": { },
		"hp_damage_received": 0,
		"healing_received_in_combat": 0,
		"health_cost_paid": 0,
		"turns": 0,
		"rounds": 0,
		"idle_turns": 0,
		"max_consecutive_idle_turns": 0,
		"idle_turn_trace": [] as Array[Dictionary],
		"hero_turn_positions": [] as Array[Array],
		"hero_turn_position_repeats": 0,
		"moves": 0,
		"fallback_path_moves": 0,
		"fallback_path_trace": [] as Array[Dictionary],
		"forced_detour_breaks": 0,
		"blocked_preparations": 0,
		"hero_casts": { },
		"enemy_casts": { },
		"manual_items": [] as Array[String],
		"roster": roster,
		"won": false,
		"termination": "",
		"death_cause": { },
		"seconds": 0.0,
	}
	metrics["deployment_diagnostic"] = _deployment_diagnostic(
		room.hero_spawn_zone,
		hero,
		units,
		grid,
		pathfinder,
	)
	_active_hero = hero
	_active_metrics = metrics
	_fallback_objective_enemy_id = ""
	_last_offensive_turn = 0
	EventBus.combat_started.emit(units.duplicate(), grid)
	queue.start()
	var consecutive_idle := 0
	for activation in MAX_ACTIVATIONS:
		var actor := queue.get_current_unit() as Unit
		if actor == null:
			metrics.termination = "empty_queue"
			break
		var courier: bool = tactical_rules != null and tactical_rules.room_id == "convoy" and actor in tactical_rules.carriers and not tactical_rules.altar_sealed and tactical_rules.boss.is_alive
		if tactical_rules != null and actor != hero and not courier:
			tactical_rules.begin_enemy_turn(actor)
		var skip := ArenaTerrainStatusTimingService.resolve_activation_start(actor, terrain)
		if courier and actor.is_alive and not skip:
			tactical_rules.begin_enemy_turn(actor)
		if actor == hero:
			metrics.turns = int(metrics.turns) + 1
			var position := _cell_array(hero.grid_pos)
			if position in (metrics.hero_turn_positions as Array):
				metrics.hero_turn_position_repeats = int(metrics.hero_turn_position_repeats) + 1
			(metrics.hero_turn_positions as Array).append(position)
		var pending: Dictionary = { }
		if courier:
			pending = {"consume_activation": true}
		elif actor.is_alive and not skip:
			pending = caster.resolve_pending_activation(actor, units, queue, adapter.attach_unit)
			if bool(pending.get("blocked", false)):
				metrics.blocked_preparations = int(metrics.blocked_preparations) + 1
		var actions := 0
		if actor == hero and actor.is_alive and not skip \
				and not bool(pending.get("consume_activation", false)):
			if manager.expedition.cards != null:
				manager.expedition.cards.start_turn()
			_maybe_use_manual_item(manager, hero, metrics)
		if actor.is_alive and not skip and not bool(pending.get("consume_activation", false)):
			for attempt in 24:
				if not hero.is_alive or not _enemies_alive(units) or not actor.is_alive:
					break
				var action: Dictionary = { }
				if actor == hero:
					if manager.expedition.cards != null:
						var available_cards: Array[Spell] = manager.expedition.cards.weapon_spells()
						for card_id in manager.expedition.cards.hand:
							for card_spell in manager.expedition.cards.spells_for(card_id):
								if card_spell not in available_cards: available_cards.append(card_spell)
						hero.spells = available_cards
					if tactical_rules != null:
						action = _tactical_hero_action(tactical_rules, hero, grid, pathfinder)
					if action.is_empty():
						action = _hero_action(hero, units, grid, pathfinder, caster)
				else:
					var decisions: Array = ai.decide(actor, units)
					if not decisions.is_empty():
						action = decisions[0]
				if action.is_empty():
					break
				if str(action.type) == "room":
					if not tactical_rules.use_terminal(str(action.command)):
						break
					metrics["room_commands"] = int(metrics.get("room_commands", 0)) + 1
				elif str(action.type) == "cast":
					var spell := action.spell as Spell
					if not caster.can_cast(actor, spell, action.cell):
						break
					var context := caster.begin_cast(actor, spell, action.cell)
					var report := caster.resolve_cast(context)
					if bool(report.get("failed", false)):
						errors.append("Legal cast failed: " + str(spell.spell_id))
						break
					_record_known_raw_damage(context, hero, metrics)
					var counts: Dictionary = metrics.hero_casts if actor == hero else metrics.enemy_casts
					var spell_id := str(spell.get_effective_spell_id())
					counts[spell_id] = int(counts.get(spell_id, 0)) + 1
					var action_id := StringName(report.get("action_id", &""))
					if action_id != &"":
						EventBus.ap_after_action_changed.emit(
							actor,
							int(report.get("ap_before", actor.current_ap)),
							int(report.get("ap_after", actor.current_ap)),
							action_id,
						)
						EventBus.action_resolved.emit(
							actor,
							action_id,
							&"spell",
							report.duplicate(false),
						)
				elif str(action.type) == "move":
					var path: Array = action.path
					var cost := pathfinder.path_movement_cost(path, actor)
					if path.size() < 2 or not actor.spend_mp(cost):
						break
					var action_id := StringName(
						"harness_move_%d_%d_%d" % [int(node.depth), activation, attempt]
					)
					EventBus.voluntary_movement_prepared.emit(
						actor,
						path.duplicate(),
						cost,
						cost,
						action_id,
					)
					terrain.begin_unit_resolution(actor)
					for index in range(1, path.size()):
						if not actor.is_alive:
							break
						grid.relocate_unit(actor, path[index])
					terrain.end_unit_resolution(actor)
					EventBus.voluntary_movement_resolved.emit(
						actor,
						path.duplicate(),
						cost,
						action_id,
					)
					EventBus.action_resolved.emit(
						actor,
						action_id,
						&"voluntary_movement",
						{ "distance": path.size() - 1, "paid_mp": cost },
					)
					if actor == hero:
						metrics.moves = int(metrics.moves) + 1
				else:
					errors.append("Unsupported AI action: " + str(action.type))
					break
				actions += 1
				for participant: Unit in units:
					if not participant.is_alive:
						grid.remove_unit(participant)
				if actor.activation_consumed:
					break
		if actor == hero:
			if actions == 0:
				metrics.idle_turns = int(metrics.idle_turns) + 1
				consecutive_idle += 1
				(metrics.idle_turn_trace as Array).append(
					_idle_turn_diagnostic(hero, units, grid, pathfinder, caster)
				)
				metrics.max_consecutive_idle_turns = maxi(
					int(metrics.max_consecutive_idle_turns),
					consecutive_idle,
				)
			else:
				consecutive_idle = 0
		ArenaTerrainStatusTimingService.resolve_activation_end(actor)
		if actor == hero and manager.expedition.cards != null:
			manager.expedition.cards.end_turn()
		EventBus.turn_ended.emit(actor, &"harness_policy")
		if tactical_rules != null and actor == hero and hero.is_alive:
			tactical_rules.finish_hero_turn()
		if not hero.is_alive:
			metrics.termination = "hero_dead"
			break
		if not _enemies_alive(units):
			metrics.termination = "victory"
			break
		if int(metrics.turns) >= MAX_HERO_TURNS:
			metrics.termination = "turn_cap"
			break
		var previous_round := queue.round_number
		if not queue.advance():
			metrics.termination = "empty_queue"
			break
		if queue.round_number != previous_round:
			terrain.tick_all_effects()
			metrics.rounds = queue.round_number
	if str(metrics.termination).is_empty():
		metrics.termination = "activation_cap"
	metrics.won = hero.is_alive and not _enemies_alive(units)
	metrics.hp_after_combat = hero.current_hp
	metrics.seconds = float(Time.get_ticks_usec() - started_usec) / 1_000_000.0
	metrics.raw_damage_coverage = (
		1.0
		if int(metrics.resolved_hit_count) == 0
		else float(metrics.known_raw_hit_count) / float(metrics.resolved_hit_count)
	)
	if not hero.is_alive:
		metrics.death_cause = metrics.get("last_incoming_fact", { }).duplicate(true)
	metrics.erase("last_incoming_fact")
	metrics.bot_diagnostic = Contract.classify_bot_outcome(bool(metrics.won), metrics)
	var missing := Contract.missing_metric_keys(metrics)
	if not missing.is_empty():
		errors.append(str(node.id) + ": missing metrics " + str(missing))
	if tactical_rules != null:
		metrics["tactical_room"] = {"id": tactical_rules.room_id, "hero_turns": metrics.turns, "environmental_hits": tactical_rules.environmental_hits, "deliveries": tactical_rules.deliveries, "altar_sealed": tactical_rules.altar_sealed}
		if tactical_rules.room_id == "reservoir":
			metrics.tactical_room["charges"] = tactical_rules.charges.duplicate()
			metrics.tactical_room["charges_stored"] = tactical_rules.charges_stored
			metrics.tactical_room["charges_siphoned"] = tactical_rules.charges_siphoned
			metrics.tactical_room["discharges"] = tactical_rules.discharges
		tactical_rules.dispose()
	EventBus.combat_ended.emit(bool(metrics.won))
	adapter.dispose()
	_active_hero = null
	_active_metrics = { }
	_fallback_objective_enemy_id = ""
	_last_offensive_turn = 0
	for unit: Unit in units:
		unit.clear_combat_effect_history()
		if unit != hero:
			unit.active_statuses.clear()
			unit.pending_ability.clear()
		grid.remove_unit(unit)
	queue.setup([])
	terrain.dispose()
	BattlefieldCleanup.dispose_grid(grid)
	return metrics


func _tactical_hero_action(rules, hero: Unit, grid: GridData, pathfinder: Pathfinder) -> Dictionary:
	# Explicit bounded policy, not an optimal player: escape, seal, or discharge stored energy.
	if hero.grid_pos in rules.danger_cells() and hero.current_mp > 0:
		var best: Array = []
		var lowest := 999
		for y in grid.rows:
			for x in grid.cols:
				var cell := Vector2i(x, y)
				if not grid.is_walkable(cell, hero) or cell in rules.danger_cells():
					continue
				var path := pathfinder.find_path(hero.grid_pos, cell, hero)
				var cost := pathfinder.path_movement_cost(path, hero)
				if path.size() > 1 and cost <= hero.current_mp and cost < lowest:
					best = path
					lowest = cost
		if not best.is_empty():
			return {"type": "move", "path": best}
	if rules.room_id == "convoy" and rules.terminal_failure("gate").is_empty():
		return {"type": "room", "command": "gate"}
	if rules.room_id == "reservoir":
		for command in ["left", "right"]:
			if rules.terminal_failure(command).is_empty():
				return {"type": "room", "command": command}
	return {}


func _hero_action(
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
	caster: SpellCaster,
) -> Dictionary:
	if _active_policy == "survival" and hero.get_hp_ratio() <= 0.50:
		for spell: Spell in hero.spells:
			if spell.get_scaled_shield(hero) > hero.current_shield \
					and caster.can_cast(hero, spell, hero.grid_pos):
				return { "type": "cast", "spell": spell, "cell": hero.grid_pos }
	var action: Dictionary = super._hero_action(hero, units, grid, pathfinder, caster)
	if not action.is_empty() and str(action.get("type", "")) == "cast":
		var chosen_spell := action.get("spell") as Spell
		if chosen_spell != null and chosen_spell.deals_damage():
			_fallback_objective_enemy_id = ""
			_last_offensive_turn = int(_active_metrics.get("turns", 0))
		return action
	if not _fallback_objective_enemy_id.is_empty():
		var objective_alive := units.any(
			func(unit: Unit):
				return unit.is_alive and str(unit.unit_id) == _fallback_objective_enemy_id,
		)
		if not objective_alive:
			_fallback_objective_enemy_id = ""
	var force_detour := _has_nonprogress_position_loop(hero)
	if force_detour:
		# The greedy score can legally alternate between two cells forever while
		# a repeatable guard keeps `idle_turns` at zero. Preserve the guard cast,
		# but replace the following voluntary move with a real edge-path prefix.
		_fallback_objective_enemy_id = ""
	if not action.is_empty() and _fallback_objective_enemy_id.is_empty() and not force_detour:
		return action
	var fallback := _fallback_path_to_enemy_edge(
		hero,
		units,
		grid,
		pathfinder,
		_fallback_objective_enemy_id,
	)
	if fallback.is_empty() and not _fallback_objective_enemy_id.is_empty():
		_fallback_objective_enemy_id = ""
		fallback = _fallback_path_to_enemy_edge(hero, units, grid, pathfinder)
	if fallback.is_empty():
		return action
	if force_detour:
		_active_metrics.forced_detour_breaks = int(_active_metrics.get("forced_detour_breaks", 0)) + 1
	_fallback_objective_enemy_id = str(fallback.enemy_id)
	_active_metrics.fallback_path_moves = int(_active_metrics.get("fallback_path_moves", 0)) + 1
	(_active_metrics.fallback_path_trace as Array).append(
		{
			"turn": int(_active_metrics.get("turns", 0)),
			"from": _cell_array(hero.grid_pos),
			"to": _cell_array((fallback.path as Array)[-1]),
			"enemy_id": str(fallback.enemy_id),
			"enemy_cell": fallback.enemy_cell,
			"full_path_cost": int(fallback.full_path_cost),
			"paid_path_cost": int(fallback.paid_path_cost),
			"full_path_length": int(fallback.full_path_length),
			"objective_enemy_id": _fallback_objective_enemy_id,
		}
	)
	return { "type": "move", "path": fallback.path }


func _has_nonprogress_position_loop(hero: Unit) -> bool:
	var turn: int = int(_active_metrics.get("turns", 0))
	if turn - _last_offensive_turn < 2:
		return false
	var positions: Array = _active_metrics.get("hero_turn_positions", []) as Array
	if positions.size() < 4:
		return false
	var alternating: bool = positions[-1] == positions[-3] and positions[-2] == positions[-4]
	var visits: int = 0
	var current: Array[int] = _cell_array(hero.grid_pos)
	for position in positions:
		if position == current:
			visits += 1
	return alternating or visits >= 3


func _fallback_path_to_enemy_edge(
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
	preferred_enemy_id: String = "",
) -> Dictionary:
	if hero.current_mp <= 0:
		return { }
	var candidates: Array[Dictionary] = []
	for enemy: Unit in units:
		if enemy.team == hero.team or not enemy.is_alive:
			continue
		if not preferred_enemy_id.is_empty() and str(enemy.unit_id) != preferred_enemy_id:
			continue
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var edge: Vector2i = enemy.grid_pos + offset
			if not grid.is_walkable(edge, hero):
				continue
			var full_path: Array = pathfinder.find_path(hero.grid_pos, edge, hero)
			if full_path.size() < 2:
				continue
			candidates.append(
				{
					"enemy_id": str(enemy.unit_id),
					"enemy_cell": _cell_array(enemy.grid_pos),
					"edge": edge,
					"path": full_path,
					"cost": pathfinder.path_movement_cost(full_path, hero),
				}
			)
	if candidates.is_empty():
		return { }
	candidates.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			if int(left.cost) != int(right.cost):
				return int(left.cost) < int(right.cost)
			if str(left.enemy_id) != str(right.enemy_id):
				return str(left.enemy_id) < str(right.enemy_id)
			var left_edge := left.edge as Vector2i
			var right_edge := right.edge as Vector2i
			return left_edge.y < right_edge.y \
					or (left_edge.y == right_edge.y and left_edge.x < right_edge.x),
	)
	var selected := candidates[0]
	var full_path := selected.path as Array
	var payable_path: Array = [hero.grid_pos]
	for index in range(1, full_path.size()):
		var prefix: Array = full_path.slice(0, index + 1)
		if pathfinder.path_movement_cost(prefix, hero) > hero.current_mp:
			break
		payable_path = prefix
	if payable_path.size() < 2:
		return { }
	return {
		"path": payable_path,
		"enemy_id": selected.enemy_id,
		"enemy_cell": selected.enemy_cell,
		"full_path_cost": int(selected.cost),
		"paid_path_cost": pathfinder.path_movement_cost(payable_path, hero),
		"full_path_length": full_path.size() - 1,
	}


func _idle_turn_diagnostic(
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
	caster: SpellCaster,
) -> Dictionary:
	var nearest: Unit = null
	var nearest_distance := 2147483647
	var legal_target_ids: Array[String] = []
	var legal_damage_casts := 0
	for enemy: Unit in units:
		if enemy.team == hero.team or not enemy.is_alive:
			continue
		var distance := grid.manhattan(hero.grid_pos, enemy.grid_pos)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
		for spell: Spell in hero.spells:
			if spell.deals_damage() and caster.can_cast(hero, spell, enemy.grid_pos):
				legal_damage_casts += 1
				if str(enemy.unit_id) not in legal_target_ids:
					legal_target_ids.append(str(enemy.unit_id))
	var fallback := _fallback_path_to_enemy_edge(hero, units, grid, pathfinder)
	return {
		"turn": int(_active_metrics.get("turns", 0)),
		"hero_cell": _cell_array(hero.grid_pos),
		"ap": hero.current_ap,
		"mp": hero.current_mp,
		"nearest_enemy_id": str(nearest.unit_id) if nearest != null else "",
		"nearest_enemy_cell": _cell_array(nearest.grid_pos) if nearest != null else [],
		"nearest_manhattan": nearest_distance if nearest != null else -1,
		"legal_damaging_targets": legal_target_ids.size(),
		"legal_damage_casts": legal_damage_casts,
		"reachable_cells": pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero).size(),
		"edge_path_exists": not fallback.is_empty(),
		"edge_path_cost": int(fallback.get("full_path_cost", -1)),
	}


func _deployment_diagnostic(
	spawn_zone: Array,
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
) -> Dictionary:
	var chosen_cell := hero.grid_pos
	var chosen_score := _position_score(chosen_cell, hero, units, grid, pathfinder)
	var best_cell := chosen_cell
	var best_score := chosen_score
	var zone_cells: Array[Array] = []
	for value in spawn_zone:
		var cell := value as Vector2i
		zone_cells.append(_cell_array(cell))
		if not grid.is_walkable(cell, hero):
			continue
		var score := _position_score(cell, hero, units, grid, pathfinder)
		if score > best_score:
			best_score = score
			best_cell = cell
	return {
		"policy": "first_spawn_cell_observed_only",
		"chosen_cell": _cell_array(chosen_cell),
		"zone_cells": zone_cells,
		"chosen_position_score": chosen_score,
		"best_position_score_cell": _cell_array(best_cell),
		"best_position_score": best_score,
		"score_gap": best_score - chosen_score,
		"best_is_chosen": best_cell == chosen_cell,
	}


func _cell_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]


func _maybe_use_manual_item(manager: HarnessManager, hero: Unit, metrics: Dictionary) -> void:
	var threshold := float(Contract.POLICIES[_active_policy].manual_item_hp_ratio)
	if hero.get_hp_ratio() > threshold:
		return
	var runtime: RelicRuntimeService = manager.get_relic_runtime_service()
	for instance in manager.run_inventory.get_slots():
		if instance == null:
			continue
		var state := runtime.manual_activation_state(hero, instance.instance_id)
		if not bool(state.get("available", false)):
			continue
		var result := runtime.activate_relic_manually(hero, instance.instance_id)
		if bool(result.get("success", false)):
			(metrics.manual_items as Array).append(str(instance.definition_id))
			if not metrics.has("relic_manual_items"):
				metrics["relic_manual_items"] = [] as Array[String]
			(metrics.relic_manual_items as Array).append(str(instance.definition_id))
			return
	for instance in manager.run_inventory.get_slots():
		if instance == null or str(instance.definition_id) != "minor_healing_potion":
			continue
		var result := manager.use_inventory_item(
			instance.instance_id,
			manager.expedition.character.character_id,
		)
		if bool(result.get("success", false)):
			(metrics.manual_items as Array).append(str(instance.definition_id))
			if not metrics.has("inventory_consumables"):
				metrics["inventory_consumables"] = [] as Array[String]
			(metrics.inventory_consumables as Array).append(str(instance.definition_id))
		return


func _record_known_raw_damage(context: CastContext, hero: Unit, metrics: Dictionary) -> void:
	if context == null or not context.damage_result_by_unit.has(hero):
		return
	var result := context.damage_result_by_unit[hero] as DamageResolver.DamageResult
	if result == null:
		return
	metrics.raw_damage_received_known = int(metrics.raw_damage_received_known) + result.raw
	metrics.known_raw_hit_count = int(metrics.known_raw_hit_count) + 1


func _resolve_advancement(session: ExpeditionSession, policy: String) -> void:
	for step in 8:
		if session.advancement_step.is_empty():
			return
		if session.advancement_step == "progression":
			var champion := session.character.champion_progression
			var order: Array = Contract.POLICIES[policy].attribute_order
			while champion.unspent_attribute_points > 0:
				var spent := false
				for attribute in order:
					if session.character.spend_champion_attribute(StringName(attribute)):
						spent = true
						break
				if not spent:
					errors.append("Attribute policy cannot spend a point")
					return
		var advanced := session.advance_level_step()
		if not bool(advanced.get("success", false)):
			errors.append("Advancement failed: " + str(advanced))
			return


func _spend_build_points(session: ExpeditionSession, weapon: String) -> Dictionary:
	var purchases: Array[String] = []
	var root := "ct." + str(ROOT_BY_WEAPON.get(weapon, "")) + "_a"
	var weapon_data: Array = CatabasePreparationCatalog.WEAPONS.get(weapon, [])
	var axis := str(weapon_data[4]) if weapon_data.size() >= 5 else ""
	var doctrine := session.build.catalog.doctrine_for_axis(axis)
	var priorities: Array[String] = [
		root,
		root + ".final",
		axis + ".learn_a",
		axis + ".liaison_a",
		axis + ".mutation",
		axis + ".learn_b",
		axis + ".liaison_b",
		axis + ".signature",
		axis + ".legend",
	]
	if not doctrine.is_empty():
		priorities.push_front(doctrine + ".root")
	for iteration in 64:
		var available: Array[String] = []
		for offer: Dictionary in session.build.get_offers():
			if session.cards != null and not session.cards.permanent_offer(offer): continue
			if bool(offer.get("available", false)):
				available.append(str(offer.id))
		if available.is_empty():
			break
		var selected := ""
		for preferred: String in priorities:
			if preferred in available:
				selected = preferred
				break
		# Save points for the next relevant node instead of spending them on the
		# alphabetically first unrelated offer.
		if selected.is_empty():
			break
		var purchase := session.build.purchase(selected)
		if not bool(purchase.get("success", false)):
			break
		purchases.append(selected)
	var equipped := _equip_empty_build_slots(session)
	return {
		"purchases": purchases,
		"equipped": equipped,
		"snapshot": {
			"points_remaining": session.build.points,
			"known_spell_ids": session.character.loadout.to_snapshot().known_spell_ids,
			"equipped_spell_ids": session.character.loadout.to_snapshot().equipped_spell_ids,
		},
	}


func _equip_empty_build_slots(session: ExpeditionSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var loadout := session.character.loadout
	var slots := loadout.get_spell_slot_ids()
	var equipped_families: Array[String] = []
	for id in slots:
		if id != &"":
			equipped_families.append(session.build.catalog.get_spell_family(str(id)))
	var candidates: Array[Spell] = loadout.get_known_spells()
	candidates.sort_custom(
		func(left: Spell, right: Spell) -> bool:
			var left_score := (100 if left.deals_damage() else 0) - left.ap_cost
			var right_score := (100 if right.deals_damage() else 0) - right.ap_cost
			if left_score != right_score:
				return left_score > right_score
			return str(left.get_effective_spell_id()) < str(right.get_effective_spell_id()),
	)
	for slot in range(slots.size()):
		if slots[slot] != &"":
			continue
		for spell: Spell in candidates:
			var spell_id := str(spell.get_effective_spell_id())
			var family := session.build.catalog.get_spell_family(spell_id)
			if family in equipped_families:
				continue
			if session.build.equip(spell_id, slot):
				equipped_families.append(family)
				result.append({ "slot": slot, "spell_id": spell_id, "family": family })
				break
	return result


func _claim_combat_reward(
	session: ExpeditionSession,
	manager: HarnessManager,
	policy: String,
) -> Dictionary:
	var capacity_equips: Array[Dictionary] = []
	if session.cards == null and session.build.completed_depth >= ExpeditionBuildState.CAPACITY_DEPTH \
			and str(session.build.to_snapshot().get("depth_eight_choice", "")).is_empty():
		var capacity := session.build.choose_depth_eight("slot")
		if not bool(capacity.get("success", false)):
			return { "success": false, "reason": "capacity", "detail": capacity }
		capacity_equips = _equip_empty_build_slots(session)
	var options := session.reward_options(manager.item_catalog, manager.run_inventory)
	var selected := ""
	if int(session.route.get_current_node().depth) == ExpeditionRouteCatalog.DEPTH_COUNT:
		selected = "finish"
	else:
		for selector: String in Contract.POLICIES[policy].reward_priority:
			for option: Dictionary in options:
				if Contract.reward_matches(str(option.id), selector):
					selected = str(option.id)
					break
			if not selected.is_empty():
				break
	if selected.is_empty() and not options.is_empty():
		selected = str(options[0].id)
	var hp_before := session.character.unit.current_hp
	var result := session.claim(selected, manager.run_inventory, manager.item_catalog)
	return {
		"success": bool(result.get("success", false)),
		"option_id": selected,
		"available_option_ids": options.map(
			func(option):
				return str(option.id),
		),
		"hp_before": hp_before,
		"hp_after": session.character.unit.current_hp,
		"gold_after": session.gold,
		"capacity_equips": capacity_equips,
		"detail": result,
	}


func _resolve_halt(
	session: ExpeditionSession,
	manager: HarnessManager,
	policy: String,
	weapon: String,
) -> Dictionary:
	var node := session.route.get_current_node()
	var hero := session.character.unit
	var hp_before := hero.current_hp
	var rest := { "success": false, "message": "not_a_refuge" }
	var is_refuge := str(node.kind) == "hub" and not bool(node.get("preparation_only", false))
	if is_refuge and hero.current_hp < hero.max_hp.get_int():
		rest = session.use_hub_service("rest", manager.run_inventory, manager.item_catalog)
	var services_used: Array[Dictionary] = []
	var services_skipped: Array[String] = []
	for service: Dictionary in session.hub_services(manager.item_catalog):
		var service_id := str(service.id)
		if service_id == "rest":
			continue
		var should_use := service_id == "lore"
		should_use = should_use or (service_id == "branch:elements" and weapon == "hampe")
		should_use = should_use or (service_id == "memory:plaque" and policy != "pressure")
		should_use = should_use or (service_id == "memory:souffle" and policy == "pressure")
		if should_use and bool(service.get("available", false)):
			var service_result := session.use_hub_service(
				service_id,
				manager.run_inventory,
				manager.item_catalog,
			)
			services_used.append(
				{ "id": service_id, "success": bool(service_result.get("success", false)) }
			)
		else:
			services_skipped.append(service_id)
	var build_update := _spend_build_points(session, weapon)
	var leave := session.claim("leave_hub", manager.run_inventory, manager.item_catalog)
	return {
		"node_id": str(node.id),
		"depth": int(node.depth),
		"kind": str(node.kind),
		"success": bool(leave.get("success", false)),
		"is_refuge": is_refuge,
		"rest": rest,
		"hp_before": hp_before,
		"hp_after": hero.current_hp,
		"healed": hero.current_hp - hp_before,
		"services_used": services_used,
		"services_skipped": services_skipped,
		"build_purchases": build_update.purchases,
		"build_equips": build_update.equipped,
		"leave": leave,
	}


func _roundtrip_resume(manager: HarnessManager, depth: int) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var snapshot := manager.get_expedition_snapshot()
	if snapshot.is_empty():
		return { "success": false, "depth": depth, "reason": "snapshot_empty" }
	var serialized := JSON.stringify(snapshot)
	var save_path := manager.expedition_save_path
	if not ExpeditionSaveService.write_snapshot(snapshot, save_path):
		return { "success": false, "depth": depth, "reason": "save_failed" }
	var loaded := ExpeditionSaveService.read_snapshot(save_path)
	var restored := not loaded.is_empty() and manager.restore_expedition_snapshot(loaded)
	return {
		"success": restored,
		"depth": depth,
		"bytes": serialized.to_utf8_buffer().size(),
		"phase_after": manager.expedition.route.phase if restored else "",
		"hp_after": manager.expedition.character.unit.current_hp if restored else -1,
		"seconds": float(Time.get_ticks_usec() - started_usec) / 1_000_000.0,
	}


func _route_entry(node: Dictionary) -> Dictionary:
	return {
		"id": str(node.get("id", "")),
		"depth": int(node.get("depth", 0)),
		"kind": str(node.get("kind", "")),
		"route_family": str(node.get("route_family", "")),
		"encounter_profile_id": str(node.get("encounter_profile_id", "")),
	}


func hero_level(_hero: Unit, session: ExpeditionSession) -> int:
	return (
		session.character.champion_progression.current_level
		if session != null and session.character.champion_progression != null
		else 1
	)


func _deepest_depth(combats: Variant) -> int:
	var deepest := 0
	for combat: Dictionary in combats as Array:
		deepest = maxi(deepest, int(combat.get("depth", 0)))
	return deepest


func _failed_run(
	seed_value: int,
	difficulty: String,
	weapon: String,
	policy: String,
	reason: String,
) -> Dictionary:
	return {
		"seed": seed_value,
		"difficulty": difficulty,
		"weapon": weapon,
		"policy": policy,
		"human_win_rate_claim": false,
		"outcome": "harness_error",
		"structural_errors": [reason],
		"combats": [],
		"resumes": [],
		"combats_reached": 0,
		"deepest_depth": 0,
		"seconds": 0.0,
	}


func _combat_failure(node: Dictionary, combat_rng_seed: int, reason: String) -> Dictionary:
	return {
		"title": str(node.get("title", "")),
		"node_id": str(node.get("id", "")),
		"depth": int(node.get("depth", 0)),
		"combat_rng_seed": combat_rng_seed,
		"hp_entry": -1,
		"hp_after_combat": -1,
		"hp_after_level": -1,
		"hp_after_provisions": -1,
		"hp_after_refuge": null,
		"level_entry": -1,
		"level_after": -1,
		"raw_damage_received_known": 0,
		"resolved_damage_before_shield": 0,
		"hp_damage_received": 0,
		"turns": 0,
		"seconds": 0.0,
		"won": false,
		"termination": reason,
		"death_cause": { },
		"bot_diagnostic": "harness_error",
	}


func _connect_metric_signals() -> void:
	if not EventBus.hit_resolved.is_connected(_on_metric_hit_resolved):
		EventBus.hit_resolved.connect(_on_metric_hit_resolved)
	if not EventBus.hp_damage_taken.is_connected(_on_metric_hp_damage_taken):
		EventBus.hp_damage_taken.connect(_on_metric_hp_damage_taken)
	if not EventBus.heal_received.is_connected(_on_metric_heal_received):
		EventBus.heal_received.connect(_on_metric_heal_received)
	if not EventBus.health_cost_paid.is_connected(_on_metric_health_cost_paid):
		EventBus.health_cost_paid.connect(_on_metric_health_cost_paid)


func _disconnect_metric_signals() -> void:
	for pair in [
		[EventBus.hit_resolved, _on_metric_hit_resolved],
		[EventBus.hp_damage_taken, _on_metric_hp_damage_taken],
		[EventBus.heal_received, _on_metric_heal_received],
		[EventBus.health_cost_paid, _on_metric_health_cost_paid],
	]:
		var event_signal := pair[0] as Signal
		var callback := pair[1] as Callable
		if event_signal.is_connected(callback):
			event_signal.disconnect(callback)


func _on_metric_hit_resolved(fact: CombatEventFact) -> void:
	if _active_hero == null or fact == null or fact.target != _active_hero:
		return
	_active_metrics.resolved_damage_before_shield = int(
		_active_metrics.resolved_damage_before_shield
	) + fact.amount_resolved
	_active_metrics.resolved_hit_count = int(_active_metrics.resolved_hit_count) + 1
	var ability := str(fact.ability_id)
	if ability.is_empty():
		ability = "status:" + str(fact.status_id) if fact.status_id != &"" else "unattributed"
	var by_ability := _active_metrics.resolved_damage_by_ability as Dictionary
	by_ability[ability] = int(by_ability.get(ability, 0)) + fact.amount_resolved
	_active_metrics["last_incoming_fact"] = {
		"source_id": str((fact.source as Unit).unit_id) if fact.source is Unit else "environment",
		"ability_id": ability,
		"amount_resolved": fact.amount_resolved,
		"amount_applied": fact.amount_applied,
		"periodic": fact.is_periodic,
	}


func _on_metric_hp_damage_taken(fact: CombatEventFact) -> void:
	if _active_hero != null and fact != null and fact.target == _active_hero:
		_active_metrics.hp_damage_received = int(_active_metrics.hp_damage_received) + fact.amount_applied


func _on_metric_heal_received(fact: CombatEventFact) -> void:
	if _active_hero != null and fact != null and fact.target == _active_hero:
		_active_metrics.healing_received_in_combat = int(_active_metrics.healing_received_in_combat) + fact.amount_applied


func _on_metric_health_cost_paid(unit: Unit, amount: int, _metadata: Dictionary) -> void:
	if _active_hero != null and unit == _active_hero:
		_active_metrics.health_cost_paid = int(_active_metrics.health_cost_paid) + maxi(0, amount)


func _write_report() -> void:
	var outcome_counts := { }
	for run: Dictionary in results:
		var outcome := str(run.get("outcome", "unknown"))
		outcome_counts[outcome] = int(outcome_counts.get(outcome, 0)) + 1
	var report := {
		"schema_version": Contract.SCHEMA_VERSION,
		"passed": errors.is_empty(),
		"engine": Engine.get_version_info(),
		"catalog_revision": ExpeditionRouteCatalog.REVISION,
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"label": label,
		"matrix": {
			"seeds": seeds,
			"difficulties": _difficulties,
			"weapons": _weapons,
			"policies": _policies,
		},
		"planned_routes": _planned_routes,
		"outcome_counts": outcome_counts,
		"runs": results,
		"errors": errors,
		"scope": "Continuous production-state Catabase route, actual rooms/formations/EnemyAI/SpellCaster, equipment, relics, XP, attributes, build, rewards, refuges and two save/restore boundaries when reached.",
		"interpretation_guard": "Deterministic heuristic-bot observations only. Not a human win rate, fairness proof, optimal-play estimate or automatic rebalance authority.",
		"known_limitations": [
			"No HUD, animation, telegraph comprehension or input timing is simulated.",
			"raw_damage_received_known covers direct CastContext hits; resolved_damage_before_shield covers all emitted hit facts.",
			"A concentrated damage flag is only a matchup review lead; a bot limitation flag is not evidence that the room is easy or impossible.",
			"The V2 policy buys only weapon-axis nodes, uses deterministic branch/lore/memory choices and deliberately skips merchants and wagers; it is not a complete or optimal economy model.",
		],
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		if "Report file could not be opened" not in errors:
			errors.append("Report file could not be opened")
		return
	file.store_string(JSON.stringify(report, "\t"))
