# core/spell_caster.gd
# ============================================================
# SPELL CASTER — Moteur d'exécution des sorts. Logique pure.
# Ciblage flexible + AOE + pose d'effets de terrain via TerrainEffects.
#
# Émet des logs SPELL (lancement, cibles, résumé). Le DÉTAIL des dégâts
# et soins est déjà loggé par Unit (take_damage / heal / apply_status) :
# on ne le duplique pas ici, on annonce le sort et on résume.
# ============================================================

class_name SpellCaster
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder
var _terrain: TerrainEffects

const CAT_SPELL := DebugLogger.LogCategory.SPELL

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

# Le caster a-t-il de quoi PAYER ce sort ? (vérif sans dépenser, pour l'UI/IA :
# griser un sort trop cher, empêcher l'IA de le choisir). La dépense réelle a
# lieu dans cast(). Une unité sans énergie n'est pas soumise au coût (rétrocompat).
func can_afford(caster: Unit, spell: Spell) -> bool:
	if spell.is_generator():
		return true
	if not caster.has_energy():
		return true
	return caster.can_afford_energy(spell.energy_cost)

# --- Exécution (avec AOE) ---
func cast(caster: Unit, spell: Spell, cell: Vector2i) -> Dictionary:
	# --- GARDE DE COÛT EN ÉNERGIE ---
	# L'énergie remplace les PA : un consommateur ne se lance que si l'unité
	# peut payer. La dépense vit ICI = loi du cast, aucun chemin ne la contourne.
	# Rétrocompat : une unité SANS énergie configurée (ennemi simple) n'est pas
	# soumise au coût — le système ne s'active que pour les unités à énergie.
	if spell.is_consumer() and caster.has_energy():
		if not caster.spend_energy(spell.energy_cost, spell.spell_name):
			DebugLogger.info(CAT_SPELL, "%s ne peut pas lancer %s (énergie insuffisante : %d/%d)" % [
				caster.unit_name, spell.spell_name,
				int(caster.current_energy), int(spell.energy_cost)])
			return {
				"caster": caster, "spell": spell, "cell": cell, "failed": true,
				"reason": "energy", "affected_units": [], "terrain_changed": [],
				"crits": [], "dodges": [],
			}

	# Annonce du sort (vu par le joueur).
	DebugLogger.info(CAT_SPELL, "%s lance %s sur %s" % [
		caster.unit_name, spell.spell_name, str(cell)], {
		"PA": spell.ap_cost,
		"énergie": int(spell.energy_cost) if spell.is_consumer() else 0,
		"portée": spell.spell_range,
		"zone": spell.aoe_size if spell.aoe_shape != Spell.AoeShape.SINGLE else 0,
	})

	var report = {
		"caster": caster, "spell": spell, "cell": cell,
		"affected_units": [], "terrain_changed": [], "crits": [], "dodges": [],
	}
	var affected_cells = get_aoe_cells(spell, cell)
	for target_cell in affected_cells:
		var target = _grid.get_unit(target_cell)
		if target != null:
			var affected = false
			# Dégâts : passent par le resolver (armure, résist, crit, esquive).
			# On transmet l'attaquant + le type du sort. Le crit du sort
			# s'ajoute au crit de l'attaquant via bonus_crit_chance.
			if spell.deals_damage():
				var result = target.take_damage(
					spell.damage, caster,
					spell.damage_type, spell.element,
					{ "bonus_crit_chance": spell.crit_chance })
				if result != null:
					if result.is_crit:
						report["crits"].append(target)
					if result.dodged:
						report["dodges"].append(target)
				affected = true
			if spell.is_healing():
				target.heal(spell.heal)
				affected = true
			if spell.applied_status != null:
				target.apply_status(spell.applied_status)
				affected = true
			if affected and not report["affected_units"].has(target):
				report["affected_units"].append(target)
		if spell.has_terrain_effect():
			_terrain.place_effect(target_cell, spell.terrain_effect)
			report["terrain_changed"].append(target_cell)

	# Résumé du sort (combien d'unités touchées, combien de cases de terrain).
	var hit_names: Array = []
	for u in report["affected_units"]:
		hit_names.append(u.unit_name)
	DebugLogger.debug(CAT_SPELL, "%s : %d unité(s) touchée(s), %d case(s) de terrain" % [
		spell.spell_name, report["affected_units"].size(), report["terrain_changed"].size()], {
		"cibles": hit_names,
	})

	return report
