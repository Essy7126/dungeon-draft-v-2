class_name CombatTargetFeedback
extends RefCounted

## Traduit un refus de ciblage existant en explication joueur.
## Les décisions restent dans Pathfinder, GridData, Unit et SpellCaster.

var _grid: GridData
var _pathfinder: Pathfinder
var _spell_caster: SpellCaster


func _init(
		grid: GridData,
		pathfinder: Pathfinder,
		spell_caster: SpellCaster
	) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_spell_caster = spell_caster


func movement_rejection_reason(unit: Unit, cell: Vector2i) -> String:
	if unit == null:
		return "Aucun personnage actif."
	if _grid == null or not _grid.is_valid(cell) \
			or not _grid.is_terrain_interactable(cell):
		return "Cette case n'est pas accessible."
	if _grid.get_unit(cell) != null:
		return "Cette case est occupée."
	if not _pathfinder.get_engaging_controllers(unit).is_empty():
		var without_control: Array = _pathfinder.get_reachable(
			unit.grid_pos,
			unit.current_mp,
			unit,
			Pathfinder.MovementType.FORCED,
		)
		if without_control.has(cell):
			return "Déplacement bloqué par l'engagement."
	return "Case hors de portée ou PM insuffisants."


func spell_rejection_reason(
		unit: Unit,
		spell: Spell,
		cell: Vector2i
	) -> String:
	if unit == null or spell == null:
		return "Cette capacité n'est plus disponible."
	var ap_cost := unit.get_spell_ap_cost(spell)
	if unit.current_ap < ap_cost:
		return "PA insuffisants (%d / %d)." % [unit.current_ap, ap_cost]
	if _grid == null or not _grid.is_valid(cell) \
			or not _grid.is_terrain_interactable(cell):
		return "Cette case ne peut pas être ciblée."
	var distance := _grid.manhattan(unit.grid_pos, cell)
	var maximum_range := _spell_caster.get_effective_spell_range(unit, spell)
	if distance > maximum_range:
		return "Cible hors de portée (%d cases maximum)." % maximum_range
	if distance < spell.minimum_range:
		return "Cible trop proche (%d cases minimum)." % spell.minimum_range
	if spell.line_from_caster:
		var delta := cell - unit.grid_pos
		if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0):
			return "Cette capacité doit être lancée en ligne droite."
	if spell.needs_line_of_sight \
			and not _pathfinder.has_line_of_sight(unit.grid_pos, cell):
		return "Ligne de vue bloquée."
	var occupant = _grid.get_unit(cell)
	if occupant == null and not spell.can_target_free_cell:
		return "Cette capacité exige une unité comme cible."
	if occupant != null:
		if occupant == unit and not spell.can_target_self \
				and not spell.can_target_ally:
			return "Cette capacité ne peut pas cibler son lanceur."
		if occupant.team == unit.team and occupant != unit \
				and not spell.can_target_ally:
			return "Cette capacité ne cible pas les alliés."
		if occupant.team != unit.team and not spell.can_target_enemy:
			return "Cette capacité ne cible pas les ennemis."
	return "Cible incompatible avec cette capacité."
