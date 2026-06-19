# core/spell_caster.gd
# ============================================================
# SPELL CASTER — Moteur d'exécution des sorts. Logique pure.
#
# Répond à trois questions :
#   1. get_targetable_cells : quelles cases ce sort peut cibler ?
#   2. is_valid_target      : cette case est-elle une cible légale ?
#   3. cast                 : exécute le sort (dégâts, soin, terrain)
#
# Version actuelle : portée + ciblage + dégâts/soin/terrain.
# (AOE, crit, élément, buffs : champs présents, branchés ensuite)
# ============================================================

class_name SpellCaster
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder

func _init(grid: GridData, pathfinder: Pathfinder) -> void:
	_grid = grid
	_pathfinder = pathfinder

# ============================================================
# 1. CASES CIBLABLES
# Toutes les cases à portée du sort (selon spell_range),
# filtrées par ligne de vue si nécessaire.
# ============================================================

func get_targetable_cells(caster: Unit, spell: Spell) -> Array:
	var result: Array = []

	# Cas spécial : un sort sur SOI ne cible que la case du lanceur.
	if spell.target_type == Spell.TargetType.SELF:
		return [caster.grid_pos]

	# On parcourt toutes les cases dans le rayon de portée (distance Manhattan).
	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			if pos == caster.grid_pos:
				continue
			var dist = _grid.manhattan(caster.grid_pos, pos)
			if dist > spell.spell_range:
				continue
			# Ligne de vue si le sort l'exige.
			if spell.needs_line_of_sight:
				if not _pathfinder.has_line_of_sight(caster.grid_pos, pos):
					continue
			result.append(pos)

	return result

# ============================================================
# 2. CIBLE VALIDE ?
# Vérifie qu'une case cliquée est une cible légale pour ce sort.
# ============================================================

func is_valid_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	# La case doit être dans les cases ciblables.
	if not get_targetable_cells(caster, spell).has(cell):
		return false

	var occupant = _grid.get_unit(cell)

	match spell.target_type:
		Spell.TargetType.ENEMY:
			# Il faut une unité ennemie sur la case.
			return occupant != null and occupant.team != caster.team
		Spell.TargetType.ALLY:
			# Il faut une unité alliée (y compris soi-même ? non : un allié).
			return occupant != null and occupant.team == caster.team
		Spell.TargetType.FREE_CELL:
			# Il faut une case libre et marchable (pour poser du terrain).
			return occupant == null and _grid.is_valid(cell)
		Spell.TargetType.SELF:
			return cell == caster.grid_pos
	return false

# ============================================================
# 3. EXÉCUTION DU SORT
# Applique l'effet du sort sur la case ciblée.
# Retourne un dictionnaire décrivant ce qui s'est passé (pour l'UI/animations).
# ============================================================

func cast(caster: Unit, spell: Spell, cell: Vector2i) -> Dictionary:
	var report = {
		"caster": caster,
		"spell": spell,
		"cell": cell,
		"affected_units": [],   # unités touchées
		"terrain_changed": [],  # cases de terrain modifiées
	}

	# Pour l'instant : zone d'effet = la case seule (SINGLE).
	# (l'AOE multi-cases viendra juste après)
	var affected_cells = [cell]

	# --- Application sur chaque case affectée ---
	for target_cell in affected_cells:
		var target = _grid.get_unit(target_cell)

		# Effet sur l'unité présente (dégâts ou soin).
		if target != null:
			if spell.deals_damage():
				target.take_damage(spell.damage)
				report["affected_units"].append(target)
			if spell.is_healing():
				target.heal(spell.heal)
				report["affected_units"].append(target)

		# Effet de terrain (pose lave/glace/ombre/rune).
		if spell.has_terrain_effect():
			_apply_terrain(target_cell, spell)
			report["terrain_changed"].append(target_cell)

	return report

# Applique l'effet de terrain d'un sort sur une case.
func _apply_terrain(cell: Vector2i, spell: Spell) -> void:
	# On traduit le TerrainEffect du sort en CellType de la grille.
	var cell_type = _terrain_to_cell_type(spell.terrain_effect)
	if cell_type != -1:
		_grid.set_type(cell, cell_type)
		# On enregistre aussi l'effet avec sa durée (pour le faire expirer plus tard).
		_grid.set_effect(cell, _terrain_name(spell.terrain_effect), {
			"duration": spell.terrain_duration,
			"original_type": GridData.CellType.NORMAL,
		})

# Correspondance TerrainEffect (Spell) -> CellType (GridData).
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
