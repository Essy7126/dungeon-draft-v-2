# units/unit.gd
# ============================================================
# UNIT — Un combattant (héros ou ennemi). Logique pure.
# ============================================================

class_name Unit
extends RefCounted

# --- Identité ---
var unit_name: String = "Sans nom"
var team: int = 0

# --- Stats max (modifiables) ---
var max_hp: Stat
var initiative: Stat
var max_ap: Stat
var max_mp: Stat
var attack_power: Stat

# --- État courant ---
var current_hp: int = 0
var current_ap: int = 0
var current_mp: int = 0
var is_alive: bool = true
var grid_pos: Vector2i = Vector2i(-1, -1)

# --- Apparence ---
var sprite_frames: SpriteFrames = null
var sprite_scale: float = 3.0
var idle_animation: String = "default"

# --- Sorts ---
var spells: Array = []

# --- Statuts actifs ---
# Dictionnaire : nom du statut -> nombre de tours restants.
# Ex : { "stun": 1 } = l'unité est stun pour 1 tour.
var statuses: Dictionary = {}

# --- Signaux ---
signal died(unit)
signal hp_changed(unit)
signal stats_changed(unit)

# ============================================================
# CONSTRUCTION
# ============================================================

func _init(
		p_name: String = "Sans nom",
		p_team: int = 0,
		p_hp: float = 100,
		p_initiative: float = 10,
		p_ap: float = 6,
		p_mp: float = 3,
		p_attack: float = 20
	) -> void:
	unit_name = p_name
	team = p_team
	max_hp       = Stat.new(p_hp)
	initiative   = Stat.new(p_initiative)
	max_ap       = Stat.new(p_ap)
	max_mp       = Stat.new(p_mp)
	attack_power = Stat.new(p_attack)
	current_hp = max_hp.get_int()
	current_ap = max_ap.get_int()
	current_mp = max_mp.get_int()

static func from_data(data: UnitData) -> Unit:
	var u = Unit.new(
		data.unit_name, data.team, data.max_hp, data.initiative,
		data.max_ap, data.max_mp, data.attack_power
	)
	u.sprite_frames = data.sprite_frames
	u.sprite_scale = data.sprite_scale
	u.idle_animation = data.idle_animation
	for spell in data.spells:
		u.add_spell(spell)
	return u

func add_spell(spell: Spell) -> void:
	spells.append(spell)

# ============================================================
# STATUTS
# ============================================================

# Applique un statut à l'unité pour une durée donnée (en tours).
func apply_status(status_name: String, duration: int) -> void:
	# Si le statut existe déjà, on garde la durée la plus longue.
	if statuses.has(status_name):
		statuses[status_name] = max(statuses[status_name], duration)
	else:
		statuses[status_name] = duration

# L'unité a-t-elle ce statut actif ?
func has_status(status_name: String) -> bool:
	return statuses.has(status_name) and statuses[status_name] > 0

# Fait vieillir les statuts d'un tour (appelé en début de tour).
# Retourne true si l'unité était stun (et doit donc sauter son tour).
func tick_statuses() -> bool:
	var was_stunned = has_status("stun")

	# On décrémente toutes les durées, on retire les expirés.
	for key in statuses.keys():
		statuses[key] -= 1
		if statuses[key] <= 0:
			statuses.erase(key)

	return was_stunned

# ============================================================
# GESTION DU TOUR
# ============================================================

func start_turn() -> void:
	max_hp.tick_durations()
	initiative.tick_durations()
	max_ap.tick_durations()
	max_mp.tick_durations()
	attack_power.tick_durations()
	current_ap = max_ap.get_int()
	current_mp = max_mp.get_int()
	stats_changed.emit(self)

# ============================================================
# DÉPENSE DE RESSOURCES
# ============================================================

func spend_mp(amount: int) -> bool:
	if amount > current_mp:
		return false
	current_mp -= amount
	stats_changed.emit(self)
	return true

func spend_ap(amount: int) -> bool:
	if amount > current_ap:
		return false
	current_ap -= amount
	stats_changed.emit(self)
	return true

# ============================================================
# COMBAT
# ============================================================

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp -= amount
	hp_changed.emit(self)
	if current_hp <= 0:
		current_hp = 0
		_die()

func heal(amount: int) -> void:
	if not is_alive:
		return
	current_hp = min(current_hp + amount, max_hp.get_int())
	hp_changed.emit(self)

func _die() -> void:
	is_alive = false
	died.emit(self)

# ============================================================
# LECTURE
# ============================================================

func get_initiative() -> int:
	return initiative.get_int()

func get_attack() -> int:
	return attack_power.get_int()

func get_hp_ratio() -> float:
	var max_val = max_hp.get_int()
	if max_val <= 0:
		return 0.0
	return float(current_hp) / float(max_val)
