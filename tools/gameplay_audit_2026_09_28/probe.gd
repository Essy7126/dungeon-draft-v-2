extends "res://tools/consumable_cards/audit_live_integration.gd"
## Read-only observations on real scenes. Inherited progression skips victories;
## this is a composition/geometry probe, never a played balance campaign.


func mount(snapshot: Dictionary) -> bool:
	if not await super.mount(snapshot):
		return false
	if not result.probes.has("geometry"):
		result.probes["geometry"] = []
		result.probes["all_native_rosters"] = []
		for node in GameManager.expedition.route.nodes:
			if node.kind not in ["normal", "elite", "boss"]:
				continue
			var native_room := ExpeditionRunFactory.make_room(node, 33)
			if not check(
				native_room != null and not native_room.enemies.is_empty(),
				"native roster %s" % node.id,
			):
				return false
			var rows := []
			for unit in native_room.enemies:
				var spells := []
				for spell in unit.spells:
					spells.append({ "id": str(spell.spell_id), "name": spell.spell_name })
				rows.append(
					{
						"id": str(unit.unit_id),
						"name": unit.unit_name,
						"role": str(unit.tactical_role_id),
						"spells": spells,
						"maximum_range": unit.maximum_range,
						"preferred_range": unit.preferred_range,
						"ai_profile": unit.ai_profile != null,
						"transformation": unit.combat_form_change != null,
					}
				)
			result.probes.all_native_rosters.append(
				{ "depth": node.depth, "branch": node.route_family, "roster": rows }
			)
	if not result.probes.has("route_previews"):
		result.probes["route_previews"] = []
	var preview_node: Dictionary = GameManager.expedition.route.get_current_node().duplicate(true)
	preview_node["knowledge"] = "near"
	var preview := ExpeditionEncounterPreview.describe(preview_node, 33)
	result.probes.route_previews.append(
		{ "depth": preview_node.depth, "hint": preview_node.hint, "preview": preview }
	)
	var hero: Unit = GameManager.expedition.character.unit
	var distances := []
	var pathfinder := Pathfinder.new(battle.grid)
	for unit in battle.units:
		if unit.team == hero.team:
			continue
		var steps := 10000
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var destination: Vector2i = unit.grid_pos + direction
			if not battle.grid.is_walkable(destination, hero):
				continue
			var path := pathfinder.find_path(hero.grid_pos, destination, hero)
			if not path.is_empty():
				steps = mini(steps, path.size() - 1)
		distances.append(
			{
				"name": unit.unit_name,
				"position": [unit.grid_pos.x, unit.grid_pos.y],
				"manhattan": battle.grid.manhattan(hero.grid_pos, unit.grid_pos),
				"steps_to_contact": steps if steps < 10000 else -1,
			}
		)
	var room = battle._cards_runtime.room_rules
	var mechanism_distance := -1
	var interaction := { }
	if room != null and not room.room_id.is_empty():
		var path := pathfinder.find_path(hero.grid_pos, room.layout.lever, hero)
		if not path.is_empty():
			mechanism_distance = path.size() - 1
		var empty_grid := GridData.new(battle.grid.cols, battle.grid.rows)
		for key in [
			"_types",
			"_terrain_properties",
			"_surface_properties",
			"_vortex_links",
			"_vortex_network_by_cell",
			"_dynamic_blockers",
		]:
			empty_grid.set(key, battle.grid.get(key).duplicate(true))
		for command in room.commands():
			interaction[command.id] = {
				"with_occupancy": interaction_cost(battle.grid, hero, command.cell),
				"without_occupancy": interaction_cost(empty_grid, hero, command.cell),
			}
	result.probes.geometry.append(
		{
			"depth": GameManager.expedition.route.get_current_node().depth,
			"cols": battle.grid.cols,
			"rows": battle.grid.rows,
			"hero": [hero.grid_pos.x, hero.grid_pos.y],
			"enemies": distances,
			"steps_to_mechanism": mechanism_distance,
			"interaction_movement_cost": interaction,
			"note": "First legal deployment cell; enemies stationary; not a minimum over deployments.",
		}
	)
	return true


func interaction_cost(board: GridData, hero: Unit, target: Vector2i) -> int:
	var finder := Pathfinder.new(board)
	var best := 10000
	for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var destination: Vector2i = target + offset
		if not board.is_walkable(destination, hero):
			continue
		var path := finder.find_path(hero.grid_pos, destination, hero)
		if not path.is_empty():
			best = mini(best, finder.path_movement_cost(path, hero))
	return best if best < 10000 else -1
