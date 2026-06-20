# units/unit.gd
# ============================================================
# UNIT — Un combattant (héros ou ennemi). Logique pure.
# ============================================================

class_name Unit
extends RefCounted

# --- Identité ---
var unit_name: String = "Sans nom"
var team: int = 0
var ai_behavior: int = 0

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
# Liste de dictionnaires : { "data": StatusData, "remaining": int }
var active_statuses: Array = []

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
	u.ai_behavior = data.ai_behavior
	for spell in data.spells:
		u.add_spell(spell)
	return u

func add_spell(spell: Spell) -> void:
	spells.append(spell)

# ============================================================
# STATUTS
# ============================================================

# Applique un statut (StatusData) à l'unité.
# Si le statut est déjà présent, on rafraîchit sa durée (pas de cumul).
func apply_status(status_data: StatusData) -> void:
	if status_data == null:
		return
	# Cherche si ce statut est déjà actif.
	for entry in active_statuses:
		if entry["data"].status_name == status_data.status_name:
			# Déjà présent : on rafraîchit la durée (la plus longue gagne).
			entry["remaining"] = max(entry["remaining"], status_data.duration)
			return
	# Nouveau statut.
	active_statuses.append({ "data": status_data, "remaining": status_data.duration })

# L'unité a-t-elle un statut qui la fait sauter son tour ?
func is_stunned() -> bool:
	for entry in active_statuses:
		if entry["data"].skips_turn:
			return true
	return false

# Applique les effets de tous les statuts en début de tour.
# Retourne true si l'unité doit sauter son tour (stun).
# (à appeler APRÈS start_turn qui recharge PA/PM)
func process_statuses() -> bool:
	var skip = false

	for entry in active_statuses:
		var data: StatusData = entry["data"]

		# Dégâts par tour (poison, saignement, brûlure).
		if data.damage_per_turn > 0:
			take_damage(data.damage_per_turn)
			print("%s subit %d dégâts de %s." % [unit_name, data.damage_per_turn, data.status_name])

		# Soin par tour (régénération).
		if data.heal_per_turn > 0:
			heal(data.heal_per_turn)

		# Réduction de PM / PA (slow).
		if data.mp_reduction > 0:
			current_mp = max(0, current_mp - data.mp_reduction)
		if data.ap_reduction > 0:
			current_ap = max(0, current_ap - data.ap_reduction)

		# Stun.
		if data.skips_turn:
			skip = true

	stats_changed.emit(self)
	return skip

# Fait vieillir les statuts d'un tour, retire les expirés.
# (à appeler en FIN de tour de l'unité)
func tick_statuses() -> void:
	for i in range(active_statuses.size() - 1, -1, -1):
		active_statuses[i]["remaining"] -= 1
		if active_statuses[i]["remaining"] <= 0:
			active_statuses.remove_at(i)

# Retourne la liste des statuts actifs (pour l'UI).
func get_active_statuses() -> Array:
	return active_statuses

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
