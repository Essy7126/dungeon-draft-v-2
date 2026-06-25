class_name TerrainEffects
extends RefCounted

var _grid: GridData

const CAT := DebugLogger.LogCategory.TERRAIN
const REACTION_DAMAGE := 20

const REACTIONS := {
	"eau|foudre": "shock",
	"eau|glace": "freeze",
	"eau|lave": "steam",
	"feu|eau": "steam",
	"feu|glace": "melt",
	"glace|lave": "melt",
}

func _init(grid: GridData) -> void:
	_grid = grid

func place_effect(cell: Vector2i, effect: TerrainEffectData, caster = null, source_spell: Spell = null) -> Dictionary:
	var result := { "changed": false, "reaction": "", "same": false }
	if effect == null or not _grid.is_valid(cell):
		return result

	var existing = get_effect_data(cell)
	if existing != null:
		if existing.effect_name == effect.effect_name:
			result["same"] = true
			DebugLogger.trace(CAT, "%s deja present en %s : pose ignoree" % [effect.effect_name, str(cell)])
			return result
		var reaction = _find_reaction(existing.effect_name, effect.effect_name)
		if reaction != "":
			DebugLogger.info(CAT, "Rencontre %s + %s en %s -> reaction '%s'" % [existing.effect_name, effect.effect_name, str(cell), reaction])
			_trigger_reaction(cell, reaction, caster)
			result["changed"] = true
			result["reaction"] = reaction
			return result
		DebugLogger.trace(CAT, "%s remplace %s en %s" % [effect.effect_name, existing.effect_name, str(cell)])

	_set_effect_cell(cell, effect, _modified_duration(effect, caster))
	result["changed"] = true
	DebugLogger.debug(CAT, "Pose %s en %s" % [effect.effect_name, str(cell)], {
		"duree": effect.duration,
		"declencheur": effect.trigger,
		"degats": effect.damage,
	})
	return result

func _set_effect_cell(cell: Vector2i, effect: TerrainEffectData, duration_override: int = -999999) -> void:
	_grid.set_effect(cell, effect.effect_name, {
		"data": effect,
		"duration": duration_override if duration_override != -999999 else effect.duration,
	})
	var type_id := effect.cell_type
	if type_id < 0:
		type_id = _cell_type_for_effect(effect.effect_name)
	if type_id >= 0:
		_grid.set_type(cell, type_id)

func _modified_duration(effect: TerrainEffectData, caster = null) -> int:
	if effect == null or effect.duration <= 0:
		return effect.duration if effect != null else 0
	if caster == null or not caster.has_method("has_charge_threshold") or not caster.has_charge_threshold():
		return effect.duration
	if not caster.has_energy():
		return effect.duration
	var multiplier: float = caster.energy_type.awakening_terrain_duration_multiplier
	if multiplier <= 1.0:
		return effect.duration
	return maxi(1, int(round(float(effect.duration) * multiplier)))
func _cell_type_for_effect(effect_name: String) -> int:
	match effect_name.strip_edges().to_lower():
		"lave", "feu": return GridData.CellType.LAVA
		"glace": return GridData.CellType.ICE
		"ombre": return GridData.CellType.SHADOW
		"rune", "rune_soin", "sanctuaire": return GridData.CellType.RUNE
	return GridData.CellType.NORMAL

func _find_reaction(name_a: String, name_b: String) -> String:
	var names = [name_a.strip_edges().to_lower(), name_b.strip_edges().to_lower()]
	names.sort()
	var key = "%s|%s" % [names[0], names[1]]
	return REACTIONS.get(key, "")

func _trigger_reaction(cell: Vector2i, reaction: String, caster = null) -> void:
	match reaction:
		"shock":
			DebugLogger.warn(CAT, "REACTION : choc electrique en %s" % str(cell))
			_damage_area(cell, REACTION_DAMAGE, caster)
			_clear_to_normal(cell)
		"steam":
			DebugLogger.warn(CAT, "REACTION : vapeur en %s" % str(cell))
			var steam = load("res://data/terrain/vapeur.tres") as TerrainEffectData
			if steam != null:
				_set_effect_cell(cell, steam)
			else:
				_clear_to_normal(cell)
		"freeze":
			DebugLogger.warn(CAT, "REACTION : eau gelee en %s" % str(cell))
			var ice = load("res://data/terrain/glace.tres") as TerrainEffectData
			if ice != null:
				_set_effect_cell(cell, ice)
			else:
				_clear_to_normal(cell)
		"melt":
			DebugLogger.warn(CAT, "REACTION : fonte en eau en %s" % str(cell))
			var water = load("res://data/terrain/eau.tres") as TerrainEffectData
			if water != null:
				_set_effect_cell(cell, water)
			else:
				_clear_to_normal(cell)

func _damage_area(center: Vector2i, amount: int, caster = null) -> void:
	var cells = [center]
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		cells.append(center + dir)
	var touched := 0
	for c in cells:
		if not _grid.is_valid(c):
			continue
		var unit = _grid.get_unit(c)
		if unit != null and unit.is_alive:
			unit.take_damage(amount, caster, Spell.DamageType.MAGICAL, Spell.Element.LIGHTNING)
			touched += 1
			DebugLogger.debug(CAT, "%s subit %d degats de reaction" % [unit.unit_name, amount], { "case": str(c), "PV_restants": unit.current_hp })
	if touched == 0:
		DebugLogger.trace(CAT, "Reaction sans cible touchee en %s" % str(center))

func _clear_to_normal(cell: Vector2i) -> void:
	_grid.clear_effect(cell)
	_grid.set_type(cell, GridData.CellType.NORMAL)

func get_effect_data(cell: Vector2i) -> TerrainEffectData:
	var stored = _grid.get_effect(cell)
	if stored == null:
		return null
	if stored.has("data") and stored["data"].has("data"):
		return stored["data"]["data"]
	return null

func get_elan_discount_for(unit: Unit) -> float:
	var effect := get_effect_data(unit.grid_pos)
	if effect == null or not unit.has_energy():
		return 0.0
	if effect.matches_energy(unit.energy_type.energy_id):
		return effect.elan_discount
	return 0.0

func get_fervor_multiplier_for(unit: Unit) -> float:
	var effect := get_effect_data(unit.grid_pos)
	if effect == null or not unit.has_energy():
		return 1.0
	if effect.matches_energy(unit.energy_type.energy_id):
		return maxf(0.0, effect.fervor_generation_multiplier)
	return 1.0

func get_ai_danger_weight(cell: Vector2i) -> float:
	var effect := get_effect_data(cell)
	if effect == null or not effect.dangerous_for_ai:
		return 0.0
	return maxf(0.0, effect.ai_danger_weight)

func on_turn_start(unit: Unit) -> void:
	var effect = get_effect_data(unit.grid_pos)
	if effect == null:
		return
	if effect.trigger == TerrainEffectData.Trigger.TURN_START:
		DebugLogger.trace(CAT, "%s commence son tour sur %s" % [unit.unit_name, effect.effect_name])
		_apply_effect_to_unit(unit, effect)

func on_enter_cell(unit: Unit, cell: Vector2i) -> void:
	var effect = get_effect_data(cell)
	if effect == null:
		return
	if effect.trigger == TerrainEffectData.Trigger.ON_ENTER:
		DebugLogger.trace(CAT, "%s entre sur %s en %s" % [unit.unit_name, effect.effect_name, str(cell)])
		_apply_effect_to_unit(unit, effect)

func _apply_effect_to_unit(unit: Unit, effect: TerrainEffectData) -> void:
	if effect.damage > 0:
		unit.take_damage(effect.damage, null, Spell.DamageType.MAGICAL, Spell.Element.FIRE, { "ignore_defense": false })
		DebugLogger.debug(CAT, "%s subit %d degats de %s" % [unit.unit_name, effect.damage, effect.effect_name], { "PV_restants": unit.current_hp })
	if effect.applied_status != null:
		unit.apply_status(effect.applied_status)
		DebugLogger.info(CAT, "%s est affecte par %s via %s" % [unit.unit_name, effect.applied_status.status_name, effect.effect_name])

func tick_all_effects() -> void:
	var expired := 0
	var active := 0
	for x in _grid.cols:
		for y in _grid.rows:
			var cell = Vector2i(x, y)
			var stored = _grid.get_effect(cell)
			if stored == null:
				continue
			var dur = stored["data"]["duration"]
			if dur == -1:
				active += 1
				continue
			dur -= 1
			if dur <= 0:
				_clear_to_normal(cell)
				expired += 1
				DebugLogger.trace(CAT, "Effet expire en %s" % str(cell))
			else:
				stored["data"]["duration"] = dur
				active += 1
	if expired > 0 or active > 0:
		DebugLogger.debug(CAT, "Vieillissement des effets", { "actifs": active, "expires": expired })