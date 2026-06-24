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

# ============================================================
# HELPERS TACTIQUES — pour enrichir le rapport de cast
# Utilisés par les traits de châssis (angle avantageux, allié adjacent...).
# ============================================================

# Un allié de l'unité est-il adjacent à elle (dans les 4 directions) ?
func _has_ally_adjacent(unit: Unit) -> bool:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var pos = unit.grid_pos + dir
		if not _grid.is_valid(pos):
			continue
		var occupant = _grid.get_unit(pos)
		if occupant != null and occupant.team == unit.team and occupant != unit:
			return true
	return false

# Angle avantageux : la cible est adjacente à un allié du caster (autre que lui).
# Utilisé par le châssis Assassin. Extension future : attaque de dos.
func _has_angle_advantage(caster: Unit, target_cell: Vector2i) -> bool:
	var target = _grid.get_unit(target_cell)
	if target == null:
		return false
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var pos = target.grid_pos + dir
		if not _grid.is_valid(pos):
			continue
		var occupant = _grid.get_unit(pos)
		if occupant != null and occupant.team == caster.team and occupant != caster:
			return true
	return false

# ============================================================
# POUSSÉE — déplace la cible dans la direction caster→target
# Renvoie un dict avec les résultats tactiques pour le rapport.
# ============================================================

func _push_unit(caster: Unit, target: Unit, cells: int) -> Dictionary:
	var result := { "pushed": false, "collision": false, "pushed_away_from_ally": false }
	if cells <= 0 or target == null:
		return result

	# Direction cardinale caster → target
	var raw_dir := target.grid_pos - caster.grid_pos
	var dir: Vector2i
	if abs(raw_dir.x) >= abs(raw_dir.y):
		dir = Vector2i(sign(raw_dir.x), 0)
	else:
		dir = Vector2i(0, sign(raw_dir.y))
	if dir == Vector2i.ZERO:
		return result

	var from_pos := target.grid_pos
	var landed_pos := from_pos
	var had_collision := false

	for _i in range(cells):
		var next := landed_pos + dir
		if not _grid.is_valid(next) or not _grid.is_walkable(next) or _grid.has_unit(next):
			had_collision = true
			break
		landed_pos = next

	# Applique le déplacement si la cible a bougé
	if landed_pos != from_pos:
		_grid.move_unit(from_pos, landed_pos)
		target.grid_pos = landed_pos
		result["pushed"] = true
		result["collision"] = had_collision
		# Vérifie si la poussée a éloigné d'un allié du caster
		result["pushed_away_from_ally"] = _pushed_away_from_ally(caster, from_pos, landed_pos)
		EventBus.unit_pushed.emit(target, from_pos, landed_pos, had_collision)
		DebugLogger.debug(CAT_SPELL, "%s poussé de %s à %s%s" % [
			target.unit_name, str(from_pos), str(landed_pos),
			" (collision)" if had_collision else ""])
	elif had_collision:
		# Poussée bloquée immédiatement — collision sur place
		result["collision"] = true
		EventBus.unit_pushed.emit(target, from_pos, from_pos, true)

	return result

# La poussée a-t-elle éloigné la cible d'un allié du caster ?
func _pushed_away_from_ally(caster: Unit, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var adj: Vector2i = from_pos + dir
		if not _grid.is_valid(adj):
			continue
		var occupant: Unit = _grid.get_unit(adj)
		if occupant != null and occupant.team == caster.team and occupant != caster:
			return not (to_pos - occupant.grid_pos).length() < 1.5
	return false

# Vérifie si une unité porte un statut par son nom.
func _has_status(unit: Unit, status_name: String) -> bool:
	if not unit.has_method("get_active_statuses"):
		return false
	for entry in unit.get_active_statuses():
		var sd: StatusData = entry.get("data")
		if sd != null and sd.status_name == status_name:
			return true
	return false

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
		"ally_adjacent_to_caster": _has_ally_adjacent(caster),
		"angle_advantage":         _has_angle_advantage(caster, cell),
		"pushed":                  false,
		"collision":               false,
		"pushed_away_from_ally":   false,
	}
	var affected_cells = get_aoe_cells(spell, cell)
	for target_cell in affected_cells:
		var target = _grid.get_unit(target_cell)
		if target != null:
			var affected = false

			# --- Dégâts ---
			if spell.deals_damage():
				var base_dmg := spell.damage
				# Bonus si cible Marquée (Exécution de l'Assassin)
				if spell.bonus_damage_if_marked > 0 and _has_status(target, "Marqué"):
					base_dmg += spell.bonus_damage_if_marked
					DebugLogger.debug(CAT_SPELL, "%s : bonus Marqué +%d sur %s" % [
						spell.spell_name, spell.bonus_damage_if_marked, target.unit_name])
				var result = target.take_damage(
					base_dmg, caster,
					spell.damage_type, spell.element,
					{ "bonus_crit_chance": spell.crit_chance })
				if result != null:
					if result.is_crit:
						report["crits"].append(target)
					if result.dodged:
						report["dodges"].append(target)
				affected = true

			# --- Soin ---
			if spell.is_healing():
				target.heal(spell.heal)
				affected = true

			# --- Statut ---
			if spell.applied_status != null:
				target.apply_status(spell.applied_status)
				affected = true

			# --- Bouclier sur allié (Garde, Rempart) ---
			if spell.shield_grant > 0 and target.team == caster.team:
				target.add_shield(spell.shield_grant)
				affected = true

			if affected and not report["affected_units"].has(target):
				report["affected_units"].append(target)

		if spell.has_terrain_effect():
			_terrain.place_effect(target_cell, spell.terrain_effect)
			report["terrain_changed"].append(target_cell)

	# --- Poussée (après les effets, pour que les dégâts soient appliqués d'abord) ---
	if spell.push_distance > 0:
		var push_target = _grid.get_unit(cell)
		if push_target != null and push_target.team != caster.team:
			var push_result = _push_unit(caster, push_target, spell.push_distance)
			report["pushed"]    = push_result["pushed"]
			report["collision"] = push_result["collision"]
			report["pushed_away_from_ally"] = push_result["pushed_away_from_ally"]

	# Résumé du sort (combien d'unités touchées, combien de cases de terrain).
	var hit_names: Array = []
	for u in report["affected_units"]:
		hit_names.append(u.unit_name)
	DebugLogger.debug(CAT_SPELL, "%s : %d unité(s) touchée(s), %d case(s) de terrain" % [
		spell.spell_name, report["affected_units"].size(), report["terrain_changed"].size()], {
		"cibles": hit_names,
	})

	# --- Génération de base (energy_generated du sort, agnostique du type) ---
	# La génération CONDITIONNELLE selon Rage/Foi/... vit dans le TraitChassis.
	if spell.energy_generated > 0.0 and caster.has_energy():
		caster.generate_energy(spell.energy_generated, spell.spell_name)

	# --- Annonce sur le bus (après tous les effets et la génération de base) ---
	# Les traits de châssis écoutent ce signal pour leur génération conditionnelle.
	EventBus.spell_cast.emit(caster, spell, report)

	return report
