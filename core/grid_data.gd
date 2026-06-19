# core/grid_data.gd
# ============================================================
# DONNÉES DE LA GRILLE — Logique pure, AUCUN visuel.
# Ne dessine rien, ne gère pas les clics, ne connaît pas les pixels.
# Raisonne uniquement en coordonnées de grille (Vector2i).
#
# C'est la "source de vérité" de l'état spatial du combat :
# où sont les unités, quels types de cases, quels effets actifs.
# ============================================================

class_name GridData
extends RefCounted
# RefCounted = objet léger sans présence dans la scène (pas un Node).
# Parfait pour de la donnée pure qui n'a pas besoin d'être affichée.

# ============================================================
# DIMENSIONS
# ============================================================

var cols: int
var rows: int

# ============================================================
# TYPES DE CASES
# Pour ajouter un type : ajoute-le ici ET dans PROPERTIES ci-dessous.
# ============================================================

enum CellType {
	NORMAL,   # Sol standard, marchable, transparent
	WALL,     # Mur : infranchissable, bloque la ligne de vue
	HOLE,     # Trou : infranchissable, mais laisse passer la vue
	LAVA,     # Marchable, infligera des dégâts (géré plus tard)
	ICE,      # Marchable, glissant (géré plus tard)
	SHADOW,   # Marchable, bloque la vue (brouillard/ombre)
	RUNE,     # Marchable, déclenchera un effet magique (géré plus tard)
}

# Propriétés mécaniques de chaque type.
# walkable    : une unité peut-elle s'y arrêter / marcher dessus ?
# transparent : laisse-t-elle passer la ligne de vue ?
const PROPERTIES = {
	CellType.NORMAL : { "walkable": true,  "transparent": true  },
	CellType.WALL   : { "walkable": false, "transparent": false },
	CellType.HOLE   : { "walkable": false, "transparent": true  },
	CellType.LAVA   : { "walkable": true,  "transparent": true  },
	CellType.ICE    : { "walkable": true,  "transparent": true  },
	CellType.SHADOW : { "walkable": true,  "transparent": false },
	CellType.RUNE   : { "walkable": true,  "transparent": true  },
}

# ============================================================
# ÉTAT DES CASES
# Trois dictionnaires séparés plutôt qu'un gros objet par case.
# Plus simple à lire, plus rapide à interroger.
# Clé = Vector2i(col, row) dans tous les cas.
# ============================================================

var _types: Dictionary = {}     # Vector2i -> CellType
var _units: Dictionary = {}     # Vector2i -> Unit (ou absent si vide)
var _effects: Dictionary = {}   # Vector2i -> { "name": String, "data": Dictionary }

# ============================================================
# CONSTRUCTION
# Appelé avec GridData.new(15, 10) par exemple.
# ============================================================

func _init(grid_cols: int, grid_rows: int) -> void:
	cols = grid_cols
	rows = grid_rows
	# Toutes les cases démarrent en NORMAL.
	for x in cols:
		for y in rows:
			_types[Vector2i(x, y)] = CellType.NORMAL

# ============================================================
# VALIDITÉ ET PROPRIÉTÉS
# ============================================================

# La position est-elle dans les limites de la grille ?
func is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < cols and pos.y >= 0 and pos.y < rows

# Type de la case (NORMAL par défaut si hors grille).
func get_type(pos: Vector2i) -> CellType:
	return _types.get(pos, CellType.NORMAL)

# Peut-on marcher sur cette case ? (bon type ET aucune unité dessus)
func is_walkable(pos: Vector2i) -> bool:
	if not is_valid(pos):
		return false
	if has_unit(pos):
		return false
	return PROPERTIES[get_type(pos)]["walkable"]

# La case laisse-t-elle passer la ligne de vue ?
func is_transparent(pos: Vector2i) -> bool:
	if not is_valid(pos):
		return false
	return PROPERTIES[get_type(pos)]["transparent"]

# ============================================================
# MODIFICATION DES TYPES (sorts de terrain, génération de map)
# ============================================================

func set_type(pos: Vector2i, type: CellType) -> void:
	if is_valid(pos):
		_types[pos] = type

# ============================================================
# GESTION DES UNITÉS
# On stocke juste QUI est où. Le déplacement visuel est géré ailleurs.
# ============================================================

func has_unit(pos: Vector2i) -> bool:
	return _units.has(pos)

func get_unit(pos: Vector2i):
	return _units.get(pos, null)

func set_unit(pos: Vector2i, unit) -> void:
	if is_valid(pos):
		_units[pos] = unit

func clear_unit(pos: Vector2i) -> void:
	_units.erase(pos)

# Déplace une unité d'une case à une autre dans les données.
func move_unit(from: Vector2i, to: Vector2i) -> void:
	if not _units.has(from):
		return
	var unit = _units[from]
	_units.erase(from)
	_units[to] = unit

# Retourne la position d'une unité donnée (ou Vector2i(-1,-1) si absente).
func find_unit(unit) -> Vector2i:
	for pos in _units:
		if _units[pos] == unit:
			return pos
	return Vector2i(-1, -1)

# ============================================================
# EFFETS DE TERRAIN (sorts actifs avec durée, dégâts, etc.)
# Stockés à part. Le contenu de "data" est libre.
# ============================================================

func set_effect(pos: Vector2i, effect_name: String, data: Dictionary = {}) -> void:
	if is_valid(pos):
		_effects[pos] = { "name": effect_name, "data": data }

func get_effect(pos: Vector2i):
	return _effects.get(pos, null)

func clear_effect(pos: Vector2i) -> void:
	_effects.erase(pos)

# ============================================================
# UTILITAIRES DE DISTANCE
# ============================================================

# Distance de Manhattan : nombre de pas orthogonaux entre deux cases.
# C'est la distance "Dofus" (pas de diagonale).
func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return manhattan(a, b) == 1
