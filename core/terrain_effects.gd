# core/terrain_effects.gd
# ============================================================
# TERRAIN EFFECTS — Moteur d'effets de terrain. Logique pure.
# Applique dégâts + statuts (StatusData) selon le déclencheur.
# Gère aussi les RÉACTIONS quand deux effets se rencontrent.
# ============================================================

class_name TerrainEffects
extends RefCounted

var _grid: GridData

# ============================================================
# TABLE DES RÉACTIONS
# Clé = paire de noms d'effets triée alphabétiquement (String).
# On trie pour que [lave, glace] et [glace, lave] donnent la même clé.
# Valeur = identifiant de la réaction, géré dans _trigger_reaction().
#
# IMPORTANT : ces noms doivent correspondre EXACTEMENT au champ
# effect_name de tes .tres (lave.tres, glace.tres, etc.).
# ============================================================

const REACTION_DAMAGE := 25   # dégâts d'une réaction explosive

const REACTIONS := {
	"glace|lave": "explosion",      # choc thermique
	"eau|foudre": "electrocution",  # décharge
	"eau|lave": "solidification",   # la lave durcit en mur
}

func _init(grid: GridData) -> void:
	_grid = grid

# ============================================================
# POSE D'UN EFFET (avec détection de réaction)
# ============================================================

func place_effect(cell: Vector2i, effect: TerrainEffectData) -> void:
	if not _grid.is_valid(cell):
		return

	# Y a-t-il déjà un effet sur cette case ?
	var existing = get_effect_data(cell)
	if existing != null:
		var reaction = _find_reaction(existing.effect_name, effect.effect_name)
		if reaction != "":
			_trigger_reaction(cell, reaction)
			return   # la réaction remplace la pose normale

	# Pas de réaction : pose normale.
	_grid.set_effect(cell, effect.effect_name, {
		"data": effect,
		"duration": effect.duration,
	})

# Cherche une réaction entre deux effets. Retourne "" si aucune.
func _find_reaction(name_a: String, name_b: String) -> String:
	var names = [name_a, name_b]
	names.sort()   # tri alphabétique pour une clé stable
	var key = "%s|%s" % [names[0], names[1]]
	return REACTIONS.get(key, "")

# ============================================================
# DÉCLENCHEMENT DES RÉACTIONS
# ============================================================

func _trigger_reaction(cell: Vector2i, reaction: String) -> void:
	match reaction:
		"explosion":
			print("RÉACTION : explosion thermique en %s !" % str(cell))
			_damage_area(cell, REACTION_DAMAGE)
			_clear_both(cell)
		"electrocution":
			print("RÉACTION : électrocution en %s !" % str(cell))
			_damage_area(cell, REACTION_DAMAGE)
			_clear_both(cell)
		"solidification":
			print("RÉACTION : solidification en %s !" % str(cell))
			_grid.clear_effect(cell)
			_grid.set_type(cell, GridData.CellType.WALL)

# Inflige des dégâts à la case + ses 4 voisines orthogonales.
func _damage_area(center: Vector2i, amount: int) -> void:
	var cells = [center]
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		cells.append(center + dir)
	for c in cells:
		if not _grid.is_valid(c):
			continue
		var unit = _grid.get_unit(c)
		if unit != null and unit.is_alive:
			unit.take_damage(amount)
			print("  %s subit %d dégâts de la réaction." % [unit.unit_name, amount])

# Nettoie l'effet de la case et la remet en NORMAL.
func _clear_both(cell: Vector2i) -> void:
	_grid.clear_effect(cell)
	_grid.set_type(cell, GridData.CellType.NORMAL)

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
