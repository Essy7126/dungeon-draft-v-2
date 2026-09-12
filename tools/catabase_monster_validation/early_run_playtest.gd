extends Node
## Controlled combat playtest: production grids, formations, AI, turn timing and
## SpellCaster. Hero is a bounded greedy policy, not a human or a win oracle.
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
const Progression = preload(
	"res://data/runs/progression/odyssey/achilles_champion_progression_v0.tres"
)
var results: Array[Dictionary] = []
var errors: Array[String] = []
var label := "baseline"
var seeds: Array[int] = [2401]
var max_depth := 6
var only_depth := 0
var output := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("label="):
			label = arg.trim_prefix("label=")
		if arg.begins_with("seeds="):
			seeds.clear()
			for value in arg.trim_prefix("seeds=").split(","):
				seeds.append(int(value))
		if arg.begins_with("depth="):
			only_depth = int(arg.trim_prefix("depth="))
	output = "res://artifacts/dev/early_run_playtest/" + label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for seed_value in seeds:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if (
				not ExpeditionRouteCatalog.is_combat(str(node.kind))
				or int(node.depth) < 2 or int(node.depth) > max_depth
			):
				continue
			if only_depth > 0 and int(node.depth) != only_depth:
				continue
			for kit in ["briseur", "chasseur", "airain"]:
				var result := _fight(node, seed_value, kit)
				if not result.has("won"):
					errors.append("Incomplete case: " + str(node.title))
				results.append(result)
				print("PLAYTEST ", JSON.stringify(result))
				_write_report()
				await get_tree().process_frame
	_write_report()
	print(
		"EARLY_RUN_PLAYTEST cases=%d errors=%d output=%s" % [results.size(), errors.size(), output]
	)
	get_tree().quit(0 if errors.is_empty() and not results.is_empty() else 1)


func _write_report() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"label": label,
				"errors": errors,
				"cases": results,
				"scope": "Independent full-health rooms II–VI; legal first two mastery purchases, later points/attributes unspent; no equipment. Real engine rules and enemy AI; greedy hero policy, not human balance validation or continuous run.",
			},
			"\t",
		)
	)


func _fight(node: Dictionary, seed_value: int, kit: String) -> Dictionary:
	seed(seed_value * 100 + int(node.depth))
	var room := ExpeditionRunFactory.make_room(node, seed_value)
	var grid := EncounterGridFactory.build_from_room(room)
	var pathfinder := Pathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	terrain.capture_base_state(room, grid)
	var caster := SpellCaster.new(grid, pathfinder, terrain)
	var run := ExpeditionRunFactory.create(seed_value)
	caster.set_action_classification_catalog(run.action_classification_catalog)
	var plan := EncounterFormationPlanner.new(grid, pathfinder).build_plan(
		room.encounter_definition,
		room.hero_spawn_zone,
		room.enemy_spawn_zone,
		seed_value,
	)
	if not bool(plan.get("valid", false)):
		errors.append(str(node.title) + ": invalid formation")
		terrain.dispose()
		return { "title": node.title, "error": "formation" }
	var data := load("res://data/units/allies/achilles.tres").duplicate(false) as UnitData
	var xp := 0
	for depth in range(1, int(node.depth)):
		xp += ExpeditionRunFactory.XP_BY_DEPTH[depth - 1]
	var level := Progression.level_for_xp(xp)
	data.max_hp = Progression.base_hp_for_level(level)
	data.attack_power = Progression.base_prowess_for_level(level)
	var hero := Unit.from_data(data)
	var catalog := ExpeditionBuildCatalog.new()
	var ids: Array = {
		"briseur": [
			"exp_frappe_ouverte",
			"exp_crochet",
			"achilles_fulminant_dash",
			"achilles_bronze_guard",
		],
		"chasseur": [
			"achilles_peleid_strike",
			"exp_tir_de_guet",
			"exp_marque",
			"achilles_bronze_guard",
		],
		"airain": [
			"achilles_peleid_strike",
			"exp_heurt",
			"achilles_fulminant_dash",
			"exp_garde_eaque",
		],
	}[kit]
	hero.spells.clear()
	for id: String in ids:
		var spell := catalog.get_spell(id)
		if spell == null:
			errors.append("Missing hero spell: " + id)
		else:
			hero.spells.append(spell)
	grid.place_unit(hero, room.hero_spawn_zone[0])
	var units: Array = [hero]
	var roster: Array = []
	for placement: Dictionary in plan.placements:
		var enemy := Unit.from_data(placement.unit_data)
		grid.place_unit(enemy, placement.cell)
		units.append(enemy)
		roster.append(
			{
				"name": enemy.unit_name,
				"hp": enemy.current_hp,
				"attack": enemy.attack_power.get_int(),
				"cell": str(enemy.grid_pos),
			}
		)
	var ai := EnemyAI.new(grid, pathfinder, caster)
	var queue := TurnQueue.new()
	queue.setup(units)
	queue.start()
	var casts := { }
	var enemy_casts := { }
	var turns := 0
	var moves := 0
	var blocked := 0
	var idle := 0
	for activation in 500:
		var actor: Unit = queue.get_current_unit()
		var skip := ArenaTerrainStatusTimingService.resolve_activation_start(actor, terrain)
		if actor == hero:
			turns += 1
		var pending: Dictionary = { }
		if actor.is_alive and not skip:
			pending = caster.resolve_pending_activation(actor, units, queue)
			if bool(pending.get("blocked", false)):
				blocked += 1
		var actions := 0
		if actor.is_alive and not skip and not bool(pending.get("consume_activation", false)):
			for attempt in 20:
				if not hero.is_alive or not _enemies_alive(units) or not actor.is_alive:
					break
				var action: Dictionary = { }
				if actor == hero:
					action = _hero_action(hero, units, grid, pathfinder, caster)
				else:
					var decisions: Array = ai.decide(actor, units)
					if not decisions.is_empty():
						action = decisions[0]
				if action.is_empty():
					break
				if str(action.type) == "cast":
					var spell: Spell = action.spell
					if not caster.can_cast(actor, spell, action.cell):
						break
					var report := caster.cast(actor, spell, action.cell)
					if bool(report.get("failed", false)):
						errors.append("Legal cast failed: " + str(spell.spell_id))
						break
					var counts: Dictionary = casts if actor == hero else enemy_casts
					counts[str(spell.spell_id)] = int(counts.get(str(spell.spell_id), 0)) + 1
				elif str(action.type) == "move":
					var path: Array = action.path
					if (
						path.size() < 2
						or not actor.spend_mp(pathfinder.path_movement_cost(path, actor))
					):
						break
					terrain.begin_unit_resolution(actor)
					for index in range(1, path.size()):
						if not actor.is_alive:
							break
						grid.relocate_unit(actor, path[index])
					terrain.end_unit_resolution(actor)
					if actor == hero:
						moves += 1
				else:
					errors.append("Unsupported AI action: " + str(action.type))
					break
				actions += 1
				for participant: Unit in units:
					if not participant.is_alive:
						grid.remove_unit(participant)
				if actor.activation_consumed:
					break
		if actor == hero and actions == 0:
			idle += 1
		ArenaTerrainStatusTimingService.resolve_activation_end(actor)
		if not hero.is_alive or not _enemies_alive(units) or turns >= 35:
			break
		var previous_round := queue.round_number
		queue.advance()
		if queue.round_number != previous_round:
			terrain.tick_all_effects()
	var result := {
		"title": node.title,
		"node": node.id,
		"depth": node.depth,
		"seed": seed_value,
		"kit": kit,
		"level": level,
		"start_hp": data.max_hp,
		"end_hp": hero.current_hp,
		"won": hero.is_alive and not _enemies_alive(units),
		"turns": turns,
		"idle": idle,
		"moves": moves,
		"blocked_preparations": blocked,
		"casts": casts,
		"enemy_casts": enemy_casts,
		"roster": roster,
	}
	for unit: Unit in units:
		unit.clear_combat_effect_history()
		unit.active_statuses.clear()
		unit.pending_ability.clear()
		grid.remove_unit(unit)
	queue.setup([])
	terrain.dispose()
	Cleanup.dispose_grid(grid)
	return result


func _enemies_alive(units: Array) -> bool:
	return units.any(
		func(unit: Unit):
			return unit.team == 1 and unit.is_alive,
	)


func _hero_action(
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
	caster: SpellCaster,
) -> Dictionary:
	var best := { }
	var score := 0.0
	for spell: Spell in hero.spells:
		if not spell.deals_damage():
			continue
		for enemy: Unit in units:
			if (
				enemy.team == 0 or not enemy.is_alive
				or not caster.can_cast(hero, spell, enemy.grid_pos)
			):
				continue
			var damage := spell.get_scaled_damage(hero)
			var value := float(mini(damage, enemy.current_hp)) / maxi(1, spell.ap_cost)
			if damage >= enemy.current_hp:
				value += 15.0
			if spell.applied_status != null and hero.current_ap >= 5:
				value += 2.0
			if spell.pull_distance > 0 and grid.manhattan(hero.grid_pos, enemy.grid_pos) == 2:
				value += 3.0
			if value > score:
				score = value
				best = { "type": "cast", "spell": spell, "cell": enemy.grid_pos }
	if not best.is_empty():
		return best
	var current := _position_score(hero.grid_pos, hero, units, grid, pathfinder)
	var destination := hero.grid_pos
	for cell: Vector2i in pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero):
		var value := _position_score(cell, hero, units, grid, pathfinder)
		if value > current + 0.1:
			current = value
			destination = cell
	if destination != hero.grid_pos:
		return { "type": "move", "path": pathfinder.find_path(hero.grid_pos, destination, hero) }
	for spell: Spell in hero.spells:
		if (
			spell.get_scaled_shield(hero) > hero.current_shield
			and caster.can_cast(hero, spell, hero.grid_pos)
		):
			return { "type": "cast", "spell": spell, "cell": hero.grid_pos }
	return { }


func _position_score(
	cell: Vector2i,
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
) -> float:
	var nearest := 1000
	var access := 0.0
	var danger := 0.0
	for enemy: Unit in units:
		if enemy.team == 0 or not enemy.is_alive:
			continue
		var distance := grid.manhattan(cell, enemy.grid_pos)
		nearest = mini(nearest, distance)
		for spell: Spell in hero.spells:
			if (
				not spell.deals_damage() or hero.current_ap < spell.ap_cost
				or not hero.can_use_spell(spell)
			):
				continue
			if (
				distance >= spell.minimum_range and distance <= spell.spell_range
				and (
					not spell.needs_line_of_sight
					or pathfinder.has_line_of_sight(cell, enemy.grid_pos)
				)
			):
				if (
					not spell.line_from_caster or cell.x == enemy.grid_pos.x
					or cell.y == enemy.grid_pos.y
				):
					access = maxf(access, 12.0)
		if distance <= enemy.max_mp.get_int() + 1:
			danger += 0.6
		if (
			not enemy.pending_ability.is_empty()
			and pathfinder.has_line_of_sight(cell, enemy.grid_pos)
		):
			danger += 2.0
	return access - float(nearest) - danger
