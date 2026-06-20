# core/terrain_effects.gd
# ============================================================
# TERRAIN EFFECTS — Moteur d'effets de terrain. Logique pure.
# Applique dégâts + statuts (StatusData) selon le déclencheur.
# ============================================================

class_name TerrainEffects
extends RefCounted

var _grid: GridData

func _init(grid: GridData) -> void:
	_grid = grid

# --- Pose d'un effet ---
func place_effect(cell: Vector2i, effect: TerrainEffectData) -> void:
	if not _grid.is_valid(cell):
		return
	_grid.set_effect(cell, effect.effect_name, {
		"data": effect,
		"duration": effect.duration,
	})

func get_effect_data(cell: Vector2i) -> TerrainEffectData:
	var stored = _grid.get_effect(cell)
	if stored == null:
		return null
	if stored.has("data") and stored["data"].has("data"):
		return stored["data"]["data"]
	return null

# --- Déclencheur : début de tour ---
func on_turn_start(unit: Unit) -> void:
	var effect = get_effect_data(unit.grid_pos)
	if effect == null:
		return
	if effect.trigger == TerrainEffectData.Trigger.TURN_START:
		_apply_effect_to_unit(unit, effect)

# --- Déclencheur : entrée sur une case ---
func on_enter_cell(unit: Unit, cell: Vector2i) -> void:
	var effect = get_effect_data(cell)
	if effect == null:
		return
	if effect.trigger == TerrainEffectData.Trigger.ON_ENTER:
		_apply_effect_to_unit(unit, effect)

# --- Application à une unité ---
func _apply_effect_to_unit(unit: Unit, effect: TerrainEffectData) -> void:
	# Dégâts directs.
	if effect.damage > 0:
		unit.take_damage(effect.damage)
		print("%s subit %d dégâts de %s." % [unit.unit_name, effect.damage, effect.effect_name])

	# Statut appliqué (StatusData : poison, stun, slow...).
	if effect.applied_status != null:
		unit.apply_status(effect.applied_status)
		print("%s est affecté par %s." % [unit.unit_name, effect.applied_status.status_name])

# --- Vieillissement des effets de case ---
func tick_all_effects() -> void:
	for x in _grid.cols:
		for y in _grid.rows:
			var cell = Vector2i(x, y)
			var stored = _grid.get_effect(cell)
			if stored == null:
				continue
			var dur = stored["data"]["duration"]
			if dur == -1:
				continue
			dur -= 1
			if dur <= 0:
				_grid.clear_effect(cell)
				_grid.set_type(cell, GridData.CellType.NORMAL)
			else:
				stored["data"]["duration"] = dur
