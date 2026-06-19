# core/terrain_effects.gd
# ============================================================
# TERRAIN EFFECTS — Moteur qui applique les effets de terrain.
# Logique pure. Lit les TerrainEffectData posés sur les cases
# et exécute leur comportement selon leur déclencheur.
#
# Écrit UNE fois. Gère tous les effets présents et futurs :
# il suffit de créer de nouvelles Resources TerrainEffectData.
# ============================================================

class_name TerrainEffects
extends RefCounted

var _grid: GridData

func _init(grid: GridData) -> void:
	_grid = grid

# ============================================================
# POSE D'UN EFFET
# Appelé par les sorts (ou cartes, décor, aléatoire...) pour
# placer un effet de terrain sur une case.
# ============================================================

func place_effect(cell: Vector2i, effect: TerrainEffectData) -> void:
	if not _grid.is_valid(cell):
		return
	# On stocke l'effet et sa durée restante dans la grille.
	_grid.set_effect(cell, effect.effect_name, {
		"data": effect,
		"duration": effect.duration,
	})

# Récupère le TerrainEffectData posé sur une case (ou null).
func get_effect_data(cell: Vector2i) -> TerrainEffectData:
	var stored = _grid.get_effect(cell)
	if stored == null:
		return null
	return stored["data"]["data"] if stored.has("data") and stored["data"].has("data") else null

# ============================================================
# DÉCLENCHEUR : DÉBUT DE TOUR
# Appelé quand une unité commence son tour.
# Applique les effets de type TURN_START sur sa case.
# Retourne true si l'unité doit sauter son tour (stun).
# ============================================================

func on_turn_start(unit: Unit) -> bool:
	var effect = get_effect_data(unit.grid_pos)
	if effect == null:
		return false

	if effect.trigger == TerrainEffectData.Trigger.TURN_START:
		_apply_effect_to_unit(unit, effect)

	# L'unité est-elle stun (par un effet passé) ? Elle saute son tour.
	# tick_statuses gère le vieillissement et retourne si elle était stun.
	return unit.has_status("stun")

# ============================================================
# DÉCLENCHEUR : ENTRÉE SUR UNE CASE
# Appelé quand une unité arrive sur une case (déplacement).
# Applique les effets de type ON_ENTER.
# ============================================================

func on_enter_cell(unit: Unit, cell: Vector2i) -> void:
	var effect = get_effect_data(cell)
	if effect == null:
		return
	if effect.trigger == TerrainEffectData.Trigger.ON_ENTER:
		_apply_effect_to_unit(unit, effect)

# ============================================================
# APPLICATION DE L'EFFET À UNE UNITÉ
# Le cœur : dégâts + statut selon ce que déclare la Resource.
# ============================================================

func _apply_effect_to_unit(unit: Unit, effect: TerrainEffectData) -> void:
	# Dégâts (directs ou sur la durée — pour l'instant on applique le montant).
	if effect.damage > 0:
		unit.take_damage(effect.damage)
		print("%s subit %d dégâts de %s." % [unit.unit_name, effect.damage, effect.effect_name])

	# Statut (stun, slow...).
	if effect.status != TerrainEffectData.StatusEffect.NONE:
		var status_name = _status_to_string(effect.status)
		if status_name != "":
			unit.apply_status(status_name, effect.status_duration)
			print("%s est affecté par %s (%d tours)." % [unit.unit_name, status_name, effect.status_duration])

func _status_to_string(status: TerrainEffectData.StatusEffect) -> String:
	match status:
		TerrainEffectData.StatusEffect.STUN: return "stun"
		TerrainEffectData.StatusEffect.SLOW: return "slow"
		_: return ""

# ============================================================
# VIEILLISSEMENT DES EFFETS DE CASE
# Appelé en fin de round : décrémente la durée des effets,
# retire ceux qui ont expiré (la case redevient normale).
# ============================================================

func tick_all_effects() -> void:
	# On parcourt toutes les cases pour faire vieillir les effets.
	for x in _grid.cols:
		for y in _grid.rows:
			var cell = Vector2i(x, y)
			var stored = _grid.get_effect(cell)
			if stored == null:
				continue
			var dur = stored["data"]["duration"]
			if dur == -1:
				continue   # permanent
			dur -= 1
			if dur <= 0:
				# L'effet expire : la case redevient normale.
				_grid.clear_effect(cell)
				_grid.set_type(cell, GridData.CellType.NORMAL)
			else:
				stored["data"]["duration"] = dur
