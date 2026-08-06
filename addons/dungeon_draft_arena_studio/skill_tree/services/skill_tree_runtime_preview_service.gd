@tool
class_name SkillTreeRuntimePreviewService
extends RefCounted

const DEFAULT_SCENARIOS := [
	{"id": "enemy_defense_0", "target_team": 1, "defense": 0},
	{"id": "enemy_defense_25", "target_team": 1, "defense": 25},
	{"id": "enemy_defense_50", "target_team": 1, "defense": 50},
	{"id": "enemy_defense_100", "target_team": 1, "defense": 100},
	{"id": "ally", "target_team": 0, "defense": 0},
	{"id": "weakened_enemy", "target_team": 1, "defense": 0, "hp": 25},
	{"id": "backstab", "target_team": 1, "defense": 0, "backstab": true},
	{"id": "multiple_targets", "target_team": 1, "defense": 0, "multiple": true},
	{"id": "free_cell", "free_cell": true},
]


static func preview(
		base_spell: Spell,
		modifiers: Array[SpellModifier],
		scenarios: Array = DEFAULT_SCENARIOS
	) -> Dictionary:
	if base_spell == null:
		return {"ok": false, "error": "Sort de base absent."}
	var started := Time.get_ticks_usec()
	var scenario_results: Array[Dictionary] = []
	var warnings := PackedStringArray()
	for scenario_value in scenarios:
		var scenario := (scenario_value as Dictionary).duplicate(true)
		var base_result := _run_sandbox(base_spell, [], scenario)
		var path_result := _run_sandbox(base_spell, modifiers, scenario)
		if not base_result.get("ok", false) or not path_result.get("ok", false):
			warnings.append(
				"Scénario %s non exécutable par le runtime : base=%s, chemin=%s" % [
					scenario.get("id", "scenario"),
					base_result.get("failure_reason", base_result.get("error", "inconnu")),
					path_result.get("failure_reason", path_result.get("error", "inconnu")),
				]
			)
		scenario_results.append({
			"scenario": scenario,
			"base": base_result,
			"result": path_result,
			"delta": _numeric_delta(
				base_result.get("facts", {}) as Dictionary,
				path_result.get("facts", {}) as Dictionary
			),
			"source": "runtime",
		})
	var trace: Array[Dictionary] = []
	for modifier in modifiers:
		if modifier == null:
			continue
		trace.append({
			"modifier": modifier,
			"modifier_name": modifier.modifier_name,
			"modifier_type": modifier.get_script().get_global_name() \
				if modifier.get_script() is Script else modifier.get_class(),
			"applies": modifier.applies_to(base_spell),
			"summary": SkillTreeEffectSummaryService.summarize_modifier(modifier),
			"authority": "SpellCaster hooks",
			"capability": modifier_capability(modifier, base_spell),
		})
	return {
		"ok": true,
		"base_spell": _spell_facts(base_spell),
		"selected_modifier_count": modifiers.size(),
		"resulting_spell": _static_resulting_spell(base_spell, modifiers),
		"scenarios": scenario_results,
		"trace": trace,
		"warnings": warnings,
		"duration_usec": Time.get_ticks_usec() - started,
		"deterministic": true,
		"runtime_authority": "SpellCaster",
		"writes_run_progression": false,
	}


static func modifier_capability(modifier: SpellModifier, spell: Spell) -> Dictionary:
	if modifier == null:
		return {"static": false, "sandbox": false, "unsupported": true}
	var static_fields := PackedStringArray()
	if modifier.get_range_bonus(null, spell) != 0:
		static_fields.append("spell_range")
	if modifier.allows_free_cell_target(null, spell):
		static_fields.append("can_target_free_cell")
	return {
		"static": not static_fields.is_empty(),
		"static_fields": static_fields,
		"sandbox": true,
		"unsupported": false,
		"scenario_required": true,
	}


static func _run_sandbox(
		spell: Spell,
		modifiers: Array[SpellModifier],
		scenario: Dictionary
	) -> Dictionary:
	var grid := GridData.new(9, 7)
	var pathfinder := Pathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	var caster_service := SpellCaster.new(grid, pathfinder, terrain)
	var caster := Unit.new("Studio Caster", 0, 100, 10, 99, 99, 20)
	caster.crit_chance.base_value = 0.0
	caster.set_progression_spell_modifiers(modifiers)
	var target_team := int(scenario.get("target_team", 1))
	var target := Unit.new("Studio Target", target_team, 100, 5, 6, 3, 20)
	target.armure.base_value = float(scenario.get("defense", 0))
	target.resist_magique.base_value = float(scenario.get("defense", 0))
	target.esquive.base_value = 0.0
	target.current_hp = clampi(int(scenario.get("hp", 100)), 1, 100)
	var target_cell := Vector2i(4, 3)
	var caster_cell := Vector2i(1, 3)
	if bool(scenario.get("backstab", false)):
		target.facing_dir = Vector2i(1, 0)
		caster_cell = Vector2i(3, 3)
	grid.place_unit(caster, caster_cell)
	if not bool(scenario.get("free_cell", false)):
		grid.place_unit(target, target_cell)
	var secondary_units: Array[Unit] = []
	if bool(scenario.get("multiple", false)):
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
			var secondary := Unit.new("Studio Secondary", target_team, 100, 5, 6, 3, 20)
			secondary.armure.base_value = float(scenario.get("defense", 0))
			secondary.resist_magique.base_value = float(scenario.get("defense", 0))
			secondary.esquive.base_value = 0.0
			if grid.place_unit(secondary, target_cell + offset):
				secondary_units.append(secondary)
	var hp_before := target.current_hp
	var caster_hp_before := caster.current_hp
	var caster_ap_before := caster.current_ap
	var report := caster_service.cast(caster, spell, target_cell)
	var failed := bool(report.get("failed", false))
	var facts := {
		"failed": failed,
		"failure_reason": str(report.get("reason", "")),
		"ap_cost": caster_ap_before - caster.current_ap,
		"primary_hp_before": hp_before,
		"primary_hp_after": target.current_hp,
		"primary_hp_damage": maxi(0, hp_before - target.current_hp),
		"primary_healing": maxi(0, target.current_hp - hp_before),
		"primary_shield": target.current_shield,
		"caster_hp_delta": caster.current_hp - caster_hp_before,
		"caster_shield": caster.current_shield,
		"primary_position": target.grid_pos,
		"caster_position": caster.grid_pos,
		"primary_status_count": target.get_active_statuses().size(),
		"secondary_hp_damage": _secondary_damage(secondary_units),
		"affected_unit_count": (report.get("affected_units", []) as Array).size(),
		"terrain_cell_count": (report.get("terrain_changed", []) as Array).size(),
		"pushed": bool(report.get("pushed", false)),
		"collision": bool(report.get("collision", false)),
	}
	return {
		"ok": not failed,
		"failure_reason": facts.failure_reason,
		"facts": facts,
		"report_keys": report.keys(),
		"source": "runtime",
	}


static func _secondary_damage(units: Array[Unit]) -> int:
	var result := 0
	for unit in units:
		result += maxi(0, 100 - unit.current_hp)
	return result


static func _static_resulting_spell(
		spell: Spell,
		modifiers: Array[SpellModifier]
	) -> Dictionary:
	var result := _spell_facts(spell)
	var range_bonus := 0
	var free_target := spell.can_target_free_cell
	for modifier in modifiers:
		if modifier == null or not modifier.applies_to(spell):
			continue
		range_bonus += modifier.get_range_bonus(null, spell)
		free_target = free_target or modifier.allows_free_cell_target(null, spell)
	result["spell_range"] = spell.spell_range + range_bonus
	result["can_target_free_cell"] = free_target
	return result


static func _spell_facts(spell: Spell) -> Dictionary:
	return {
		"spell_id": spell.get_effective_spell_id(),
		"spell_name": spell.spell_name,
		"ap_cost": spell.ap_cost,
		"minimum_range": spell.minimum_range,
		"spell_range": spell.spell_range,
		"needs_line_of_sight": spell.needs_line_of_sight,
		"can_target_enemy": spell.can_target_enemy,
		"can_target_ally": spell.can_target_ally,
		"can_target_self": spell.can_target_self,
		"can_target_free_cell": spell.can_target_free_cell,
		"aoe_shape": spell.aoe_shape,
		"aoe_size": spell.aoe_size,
		"damage": spell.damage,
		"heal": spell.heal,
		"shield": spell.shield_grant,
		"damage_type": spell.damage_type,
		"element": spell.element,
		"crit_chance": spell.crit_chance,
		"push_distance": spell.push_distance,
		"pull_distance": spell.pull_distance,
		"collision_damage": spell.collision_damage,
		"terrain": spell.terrain_effect,
		"status": spell.applied_status,
		"cooldown": spell.cooldown_activations,
		"max_uses": spell.max_uses_per_combat,
		"delayed_resolution": spell.delayed_resolution,
		"summon": spell.summon_unit_data,
	}


static func _numeric_delta(base: Dictionary, result: Dictionary) -> Dictionary:
	var delta := {}
	for key_value in base:
		var key := str(key_value)
		if not result.has(key):
			continue
		var before: Variant = base[key_value]
		var after: Variant = result[key]
		if before is int or before is float:
			delta[key] = after - before
		elif before is Vector2i and after is Vector2i:
			delta[key] = after - before
	return delta
