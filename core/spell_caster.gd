# core/spell_caster.gd
# ============================================================
# SPELL CASTER — Moteur d'exécution des sorts. Logique pure.
# Ciblage flexible + AOE + pose d'effets de terrain via TerrainEffects.
# ============================================================

class_name SpellCaster
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder
var _terrain: TerrainEffects

func _init(grid: GridData, pathfinder: Pathfinder, terrain: TerrainEffects) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_terrain = terrain

# --- Cases ciblables (portée) ---
func get_targetable_cells(caster: Unit, spell: Spell) -> Array:
	var result: Array = []
	if spell.is_self_only():
		return [caster.grid_pos]
	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			if pos == caster.grid_pos and not spell.can_target_self:
				continue
			if _grid.manhattan(caster.grid_pos, pos) > spell.spell_range:
				continue
			if spell.needs_line_of_sight:
				if not _pathfinder.has_line_of_sight(caster.grid_pos, pos):
					continue
			if _matches_target(caster, spell, pos):
				result.append(pos)
	return result

# --- Zone d'effet (AOE) ---
func get_aoe_cells(spell: Spell, center: Vector2i) -> Array:
	var result: Array = []
	match spell.aoe_shape:
		Spell.AoeShape.SINGLE:
			result.append(center)
		Spell.AoeShape.CROSS:
			result.append(center)
			for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				for i in range(1, spell.aoe_size + 1):
					var pos = center + dir * i
					if _grid.is_valid(pos):
						result.append(pos)
		Spell.AoeShape.SQUARE:
			for dx in range(-spell.aoe_size, spell.aoe_size + 1):
				for dy in range(-spell.aoe_size, spell.aoe_size + 1):
					var pos = center + Vector2i(dx, dy)
					if _grid.is_valid(pos):
						result.append(pos)
		Spell.AoeShape.LINE:
			result.append(center)
	return result

# --- Validation de cible ---
func _matches_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	var occupant = _grid.get_unit(cell)
	if occupant != null and occupant.team != caster.team:
		return spell.can_target_enemy
	if occupant != null and occupant.team == caster.team:
		if occupant == caster:
			return spell.can_target_self or spell.can_target_ally
		return spell.can_target_ally
	if occupant == null:
		return spell.can_target_free_cell
	return false

func is_valid_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	if not get_targetable_cells(caster, spell).has(cell):
		return false
	return _matches_target(caster, spell, cell)

# --- Exécution (avec AOE) ---
func cast(caster: Unit, spell: Spell, cell: Vector2i) -> Dictionary:
	var report = {
		"caster": caster, "spell": spell, "cell": cell,
		"affected_units": [], "terrain_changed": [],
	}
	var affected_cells = get_aoe_cells(spell, cell)
	for target_cell in affected_cells:
		var target = _grid.get_unit(target_cell)
		if target != null:
			if spell.deals_damage():
				target.take_damage(spell.damage)
				report["affected_units"].append(target)
			if spell.is_healing():
				target.heal(spell.heal)
				report["affected_units"].append(target)
		if spell.has_terrain_effect():
			_terrain.place_effect(target_cell, spell.terrain_effect)
			report["terrain_changed"].append(target_cell)
	return report
