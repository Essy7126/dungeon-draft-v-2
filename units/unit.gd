# units/unit.gd
# ============================================================
# UNIT — Un combattant (héros ou ennemi). Logique pure.
#
# Émet des logs de COMBAT (dégâts, soins, mort) et de STATS (statuts),
# pour que la console de debug serve de vrai suivi de combat.
# ============================================================

class_name Unit
extends RefCounted

# --- Identité ---
var unit_name: String = "Sans nom"
var team: int = 0
var ai_behavior: int = 0
var boss_behavior = null

# --- Stats max (modifiables) ---
var max_hp: Stat
var initiative: Stat
var max_ap: Stat
var max_mp: Stat
var attack_power: Stat

# --- Stats défensives (Couche 1) ---
# Armure : mitigation des dégâts PHYSIQUES (formule LoL, valeur/(valeur+100)).
# Resist_magique : idem pour les dégâts MAGIQUES.
# Esquive : proba (0.0–1.0) d'annuler totalement un coup.
var armure: Stat
var resist_magique: Stat
var esquive: Stat

# --- Stats de critique (Couche 1) ---
# Crit_chance : proba de base de l'attaquant (0.0–1.0).
# Crit_multi : multiplicateur de dégâts en cas de critique.
var crit_chance: Stat
var crit_multi: Stat

# --- Résistances élémentaires ---
# Dictionnaire { Spell.Element → float } en POURCENTAGE (0.5 = -50%).
# Valeur négative = vulnérabilité (dégâts augmentés). Absent = 0.
# Léger : on ne renseigne que les éléments qui concernent l'unité.
var resistances: Dictionary = {}

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

# Raccourcis de catégories de log (combat = vu par le joueur).
const CAT_COMBAT := DebugLogger.LogCategory.COMBAT
const CAT_STATS := DebugLogger.LogCategory.STATS

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
	# Stats défensives : neutres par défaut (renseignées via from_data).
	armure         = Stat.new(0.0)
	resist_magique = Stat.new(0.0)
	esquive        = Stat.new(0.0)
	crit_chance    = Stat.new(0.0)
	crit_multi     = Stat.new(1.5)
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
	# Stats défensives : on règle la valeur de BASE de chaque Stat.
	u.armure.base_value = data.armure
	u.resist_magique.base_value = data.resist_magique
	u.esquive.base_value = data.esquive
	u.crit_chance.base_value = data.crit_chance
	u.crit_multi.base_value = data.crit_multi
	# Résistances élémentaires : copie défensive du dictionnaire.
	u.resistances = data.resistances.duplicate()
	# On DUPLIQUE le comportement : chaque boss a son propre état (compteur
	# de tours, enrage...), sinon deux boss partageraient le même.
	u.boss_behavior = data.boss_behavior.duplicate() if data.boss_behavior != null else null
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
			DebugLogger.debug(CAT_STATS, "%s : %s rafraîchi (%d tours)" % [
				unit_name, status_data.status_name, entry["remaining"]])
			return
	# Nouveau statut.
	active_statuses.append({ "data": status_data, "remaining": status_data.duration })
	DebugLogger.info(CAT_STATS, "%s subit %s (%d tours)" % [
		unit_name, status_data.status_name, status_data.duration])

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
		# Dégâts "vrais" : un poison ignore l'armure et ne s'esquive pas.
		# (quand StatusData portera un élément, on le passera ici)
		if data.damage_per_turn > 0:
			take_damage(data.damage_per_turn, null,
				Spell.DamageType.MAGICAL, Spell.Element.NONE,
				{ "ignore_defense": true, "cannot_be_dodged": true })
			DebugLogger.info(CAT_STATS, "%s subit %d dégâts de %s" % [
				unit_name, data.damage_per_turn, data.status_name], {
				"PV_restants": current_hp,
			})

		# Soin par tour (régénération).
		if data.heal_per_turn > 0:
			heal(data.heal_per_turn)
			DebugLogger.info(CAT_STATS, "%s récupère %d PV de %s" % [
				unit_name, data.heal_per_turn, data.status_name], {
				"PV": current_hp,
			})

		# Réduction de PM / PA (slow).
		if data.mp_reduction > 0:
			current_mp = max(0, current_mp - data.mp_reduction)
			DebugLogger.debug(CAT_STATS, "%s : -%d PM (%s)" % [
				unit_name, data.mp_reduction, data.status_name])
		if data.ap_reduction > 0:
			current_ap = max(0, current_ap - data.ap_reduction)
			DebugLogger.debug(CAT_STATS, "%s : -%d PA (%s)" % [
				unit_name, data.ap_reduction, data.status_name])

		# Stun.
		if data.skips_turn:
			skip = true
			DebugLogger.info(CAT_STATS, "%s est neutralisé par %s (passe son tour)" % [
				unit_name, data.status_name])

	stats_changed.emit(self)
	return skip

# Fait vieillir les statuts d'un tour, retire les expirés.
# (à appeler en FIN de tour de l'unité)
func tick_statuses() -> void:
	for i in range(active_statuses.size() - 1, -1, -1):
		active_statuses[i]["remaining"] -= 1
		if active_statuses[i]["remaining"] <= 0:
			var ended = active_statuses[i]["data"].status_name
			active_statuses.remove_at(i)
			DebugLogger.debug(CAT_STATS, "%s : %s expire" % [unit_name, ended])

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

# take_damage INTELLIGENT (Couche 1).
# Toute la mitigation (esquive, résist, armure, crit) vit ICI : c'est la
# loi physique du combat, aucune source ne peut y échapper.
#
# Rétrocompatible : take_damage(15) marche toujours (coup brut, sans
# attaquant, traité comme physique sans défense calculée → dégâts pleins).
# Les nouveaux appels passent un HitContext complet via take_hit().
#
# Renvoie le DamageResult (montant réel, crit, esquive) pour que
# l'appelant puisse afficher les retours visuels.
func take_damage(
		amount: int,
		attacker = null,
		category: int = Spell.DamageType.PHYSICAL,
		element: int = Spell.Element.NONE,
		options: Dictionary = {}
	) -> DamageResolver.DamageResult:
	if not is_alive:
		return null

	# Construit le contexte du coup.
	var ctx := DamageResolver.HitContext.new()
	ctx.attacker = attacker
	ctx.raw_damage = amount
	ctx.category = category
	ctx.element = element
	# Options éventuelles (terrain, sorts spéciaux, futurs traits).
	ctx.ignore_defense = options.get("ignore_defense", false)
	ctx.cannot_be_dodged = options.get("cannot_be_dodged", false)
	ctx.bonus_crit_chance = options.get("bonus_crit_chance", 0.0)
	ctx.force_crit = options.get("force_crit", false)
	ctx.pen_pct = options.get("pen_pct", 0.0)
	ctx.pen_flat = options.get("pen_flat", 0.0)

	var result := DamageResolver.compute(self, ctx)
	_apply_damage_result(result)
	return result

# take_hit : variante explicite quand on a déjà un HitContext construit
# (utile pour les futurs traits qui veulent pousser des crochets).
func take_hit(ctx: DamageResolver.HitContext) -> DamageResolver.DamageResult:
	if not is_alive:
		return null
	var result := DamageResolver.compute(self, ctx)
	_apply_damage_result(result)
	return result

# Applique le résultat calculé aux PV + logs.
func _apply_damage_result(result: DamageResolver.DamageResult) -> void:
	if result.dodged:
		DebugLogger.info(CAT_COMBAT, "%s esquive l'attaque" % unit_name)
		hp_changed.emit(self)
		return

	current_hp -= result.amount
	if result.is_crit:
		DebugLogger.info(CAT_COMBAT, "%s subit %d dégâts (CRITIQUE)" % [
			unit_name, result.amount], {
			"PV": "%d/%d" % [max(current_hp, 0), max_hp.get_int()],
		})
	else:
		DebugLogger.info(CAT_COMBAT, "%s subit %d dégâts" % [unit_name, result.amount], {
			"PV": "%d/%d" % [max(current_hp, 0), max_hp.get_int()],
		})
	hp_changed.emit(self)
	if current_hp <= 0:
		current_hp = 0
		_die()

func heal(amount: int) -> void:
	if not is_alive:
		return
	var before = current_hp
	current_hp = min(current_hp + amount, max_hp.get_int())
	var real = current_hp - before
	DebugLogger.info(CAT_COMBAT, "%s récupère %d PV" % [unit_name, real], {
		"PV": "%d/%d" % [current_hp, max_hp.get_int()],
	})
	hp_changed.emit(self)

func _die() -> void:
	is_alive = false
	DebugLogger.info(CAT_COMBAT, "%s est vaincu" % unit_name)
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
