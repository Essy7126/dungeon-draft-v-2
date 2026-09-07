extends RefCounted

const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const KITS := {
	"base": {"level": 1, "scenario": "combo", "nodes": []},
	"wrath": {"level": 10, "scenario": "combo", "nodes": [
		"achilles_wrath_focused_fury", "achilles_wrath_murderous_momentum", "achilles_wrath_execution",
		"achilles_wrath_break_formation", "achilles_wrath_scourge_of_troy"]},
	"chiron": {"level": 10, "scenario": "shot", "nodes": [
		"achilles_chiron_centaur_eye", "achilles_chiron_pelion_reach", "achilles_chiron_stopping_arrow",
		"achilles_chiron_piercing_arrow", "achilles_chiron_death_line"]},
	"volley": {"level": 13, "scenario": "shot", "nodes": [
		"achilles_chiron_centaur_eye", "achilles_chiron_pelion_reach", "achilles_chiron_stopping_arrow",
		"achilles_chiron_piercing_arrow", "achilles_chiron_centaur_volley"]},
	"aeacus": {"level": 13, "scenario": "bastion", "nodes": [
		"achilles_aeacus_active_guard", "achilles_aeacus_directional_guard", "achilles_aeacus_arrow_wall",
		"achilles_aeacus_mobile_bastion", "achilles_aeacus_myrmidon_rampart"]},
	"counter": {"level": 10, "scenario": "counter", "nodes": [
		"achilles_aeacus_active_guard", "achilles_aeacus_directional_guard", "achilles_aeacus_arrow_wall",
		"achilles_aeacus_mobile_bastion", "achilles_aeacus_counter"]},
}


static func prepare_progression(kit_id: String) -> Dictionary:
	var report := {"ok": false, "kit_id": kit_id, "purchases": [],
		"scope": "Pre-battle progression fixture using XP and legal mastery purchases; not a claimed campaign playthrough"}
	if not KITS.has(kit_id) or not GameManager.can_edit_champion_build():
		report["error"] = "kit_missing_or_build_locked"
		return report
	var state := GameManager.get_character_state(&"achilles") as CharacterRunState
	if state == null or not state.uses_champion_progression():
		report["error"] = "canonical_champion_state_missing"
		return report
	var kit: Dictionary = KITS[kit_id]
	var level := int(kit.level)
	if level > 1:
		var xp := state.champion_progression.profile.xp_for_level(level)
		var award := state.award_encounter_xp(StringName("visual_validation_fixture_" + kit_id), xp, true)
		report["preparation_xp_award"] = award
		if not bool(award.get("granted", false)):
			report["error"] = "fixture_xp_award_failed"
			return report
	for node_id: String in kit.nodes:
		var decision := GameManager.purchase_champion_mastery(&"achilles", StringName(node_id))
		(report.purchases as Array).append({"node_id": node_id, "decision": decision})
		if not bool(decision.get("purchased", false)):
			report["error"] = "legal_mastery_purchase_failed:" + node_id
			return report
	report["snapshot"] = state.champion_progression.to_snapshot()
	report["selected_node_ids"] = state.champion_progression.selected_node_ids.duplicate()
	report["spells"] = []
	for spell: Spell in state.unit.spells:
		(report.spells as Array).append(MasteryStaticModifierResolver.resolve_spell_profile(spell, state.get_selected_mastery_nodes()))
	report["ok"] = true
	return report


static func configure_placement_fixture(arena: ArenaDefinition, scenario: String,
		kit_id: String, facing: String) -> Dictionary:
	var result := {"ok": false, "scenario": scenario, "direction": facing,
		"scope": "Authored test spawns and three canonical spectres on a memory-only copy of the real terrain. Normal deployment, stats, turns and spell resolution; no post-spawn teleport or HP/AP/MP edits."}
	if not DIRECTIONS.has(facing) or scenario not in ["combo", "shot", "bastion", "counter", "hit_death"]:
		result["error"] = "invalid_scenario_or_direction"
		return result
	if scenario == "hit_death" and kit_id != "base":
		result["error"] = "hit_death_requires_unmodified_level_one_base_kit"
		return result
	var grid := ArenaRuntimeBridge.build_grid_from_synced_resources(arena)
	if grid == null:
		result["error"] = "fixture_grid_missing"
		return result
	var pathfinder := Pathfinder.new(grid)
	var direction: Vector2i = DIRECTIONS[facing]
	var side := Vector2i(-direction.y, direction.x)
	var selected := Vector2i(-1, -1)
	var score := INF
	var targets: Array[Vector2i] = []
	for y in grid.rows:
		for x in grid.cols:
			var start := Vector2i(x, y)
			var candidate_targets: Array[Vector2i] = []
			match scenario:
				"shot":
					if kit_id == "volley":
						candidate_targets.assign([start + direction * 3, start + direction * 3 - side, start + direction * 3 + side])
					else:
						candidate_targets.assign([start + direction * 3, start + direction * 4, start + direction * 5])
				"hit_death":
					candidate_targets.assign([start + direction, start + side, start - side])
				"counter":
					candidate_targets.assign([start + direction, start + direction * 5, start - side * 3])
				"bastion":
					candidate_targets.assign([start + direction * 4, start + direction * 3 + side, start - side * 3])
				_:
					candidate_targets.assign([start + direction * 4, start + direction * 5, start - side * 3])
			var clear := true
			# Validate the actual lanes and reaction destinations, not an
			# artificial empty rectangle the irregular real map may not have.
			var required_cells: Array[Vector2i] = []
			for forward in range(-1, 7):
				required_cells.append(start + direction * forward)
			for lateral in [-1, 0, 1]:
				required_cells.append(start + direction + side * lateral)
			if scenario == "bastion":
				required_cells.append(start + direction * 3 + side * 2)
			for cell: Vector2i in required_cells:
				if not grid.is_walkable(cell) or grid.get_type(cell) != GridData.CellType.NORMAL:
					clear = false
			for cell: Vector2i in candidate_targets:
				clear = clear and grid.is_walkable(cell)
				if scenario == "shot":
					clear = clear and pathfinder.has_line_of_sight(start, cell)
			if not clear:
				continue
			var center := Vector2(start + direction * 3)
			var candidate_score := center.distance_to(Vector2(grid.cols, grid.rows) * 0.5)
			if candidate_score < score:
				selected = start
				targets = candidate_targets
				score = candidate_score
	if selected == Vector2i(-1, -1):
		result["error"] = "no_clear_scenario_footprint_on_real_map"
		return result
	var template := load("res://data/units/enemies/spectre_greatsword.tres") as UnitData
	if template == null:
		result["error"] = "canonical_enemy_missing"
		return result
	arena.encounter_definition = null
	arena.waves.clear()
	arena.enemies.assign([template, template, template])
	arena.spawns.clear()
	var hero_spawn := ArenaSpawnDefinition.new()
	hero_spawn.spawn_id = &"kit_validation_hero"
	hero_spawn.kind = ArenaSpawnDefinition.Kind.HERO_1
	hero_spawn.cell = selected - direction
	arena.spawns.append(hero_spawn)
	for index in targets.size():
		var spawn := ArenaSpawnDefinition.new()
		spawn.spawn_id = StringName("kit_validation_enemy_%d" % index)
		spawn.kind = ArenaSpawnDefinition.Kind.ENEMY
		spawn.cell = targets[index]
		arena.spawns.append(spawn)
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		result["error"] = "fixture_projection_failed"
		return result
	result["deployment_cell"] = selected - direction
	result["hero_cell"] = selected
	result["enemy_cells"] = targets
	result["dash_cell"] = selected + direction * 3
	result["shot_cell"] = selected + direction * 3
	result["direction_vector"] = direction
	result["ok"] = true
	return result
