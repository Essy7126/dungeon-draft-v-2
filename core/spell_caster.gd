# core/spell_caster.gd
# ============================================================
# SPELL CASTER — Moteur d'exécution des sorts. Logique pure.
# Ciblage flexible (cases à cocher) + AOE.
# ============================================================

class_name SpellCaster
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder

func _init(grid: GridData, pathfinder: Pathfinder) -> void:
	_grid = grid
	_pathfinder = pathfinder

# ============================================================
# 1. CASES CIBLABLES (portée)
# ============================================================

func get_targetable_cells(caster: Unit, spell: Spell) -> Array:
	var result: Array = []

	# Sort sur soi uniquement : seule la case du lanceur.
	if spell.is_self_only():
		return [caster.grid_pos]

	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			# On peut inclure la case du lanceur si le sort se cible soi.
			if pos == caster.grid_pos and not spell.can_target_self:
				continue
			if _grid.manhattan(caster.grid_pos, pos) > spell.spell_range:
				continue
			if spell.needs_line_of_sight:
				if not _pathfinder.has_line_of_sight(caster.grid_pos, pos):
					continue
			# La case doit correspondre à au moins un type de cible autorisé.
			if _matches_target(caster, spell, pos):
				result.append(pos)
	return result

# ============================================================
# 2. ZONE D'EFFET (AOE)
# ============================================================

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

# ============================================================
# 3. VALIDATION DE CIBLE
# ============================================================

# Vérifie qu'une case correspond à un des types de cibles cochés du sort.
func _matches_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	var occupant = _grid.get_unit(cell)

	# Case avec une unité ennemie.
	if occupant != null and occupant.team != caster.team:
		return spell.can_target_enemy

	# Case avec un allié (ou soi).
	if occupant != null and occupant.team == caster.team:
		if occupant == caster:
			return spell.can_target_self or spell.can_target_ally
		return spell.can_target_ally

	# Case vide.
	if occupant == null:
		return spell.can_target_free_cell

	return false

# Cible valide = dans la portée ET correspond à un type coché.
func is_valid_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	if not get_targetable_cells(caster, spell).has(cell):
		return false
	return _matches_target(caster, spell, cell)

# ============================================================
# 4. EXÉCUTION (avec AOE)
# ============================================================

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
			_apply_terrain(target_cell, spell)
			report["terrain_changed"].append(target_cell)
	return report

func _apply_terrain(cell: Vector2i, spell: Spell) -> void:
	var cell_type = _terrain_to_cell_type(spell.terrain_effect)
	if cell_type != -1:
		_grid.set_type(cell, cell_type)
		_grid.set_effect(cell, _terrain_name(spell.terrain_effect), {
			"duration": spell.terrain_duration,
			"original_type": GridData.CellType.NORMAL,
		})

func _terrain_to_cell_type(effect: Spell.TerrainEffect) -> int:
	match effect:
		Spell.TerrainEffect.LAVA:   return GridData.CellType.LAVA
		Spell.TerrainEffect.ICE:    return GridData.CellType.ICE
		Spell.TerrainEffect.SHADOW: return GridData.CellType.SHADOW
		Spell.TerrainEffect.RUNE:   return GridData.CellType.RUNE
		_: return -1

func _terrain_name(effect: Spell.TerrainEffect) -> String:
	match effect:
		Spell.TerrainEffect.LAVA:   return "lava"
		Spell.TerrainEffect.ICE:    return "ice"
		Spell.TerrainEffect.SHADOW: return "shadow"
		Spell.TerrainEffect.RUNE:   return "rune"
		_: return ""
