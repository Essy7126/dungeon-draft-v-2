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
# Dictionnaire { Spell.Element → Stat } en POURCENTAGE (0.5 = -50% de dégâts).
# Chaque résistance est une VRAIE Stat (modifiable par reliques/équipement,
# avec durée, source, clamp), exactement comme l'armure. Une relique
# "+30% résist feu pour la run" se branche donc proprement dessus.
# Valeur négative = vulnérabilité (dégâts augmentés). Élément absent = 0.
# Création PARESSEUSE via get_resistance() : on ne crée le Stat que si besoin.
# Bornes : chaque résistance est clampée dans [RESIST_MIN, RESIST_MAX].
var resistances: Dictionary = {}

# Bornes des résistances élémentaires (symétriques) :
# +0.75 = au plus -75% de dégâts (jamais l'immunité totale).
# -0.75 = au plus +75% de dégâts subis (vulnérabilité bornée, pas x4).
const RESIST_MIN := -0.75
const RESIST_MAX := 0.75

# Borne haute de l'esquive : 50% max, peu importe l'empilement de bonus.
# (Choix tactique : l'esquive reste un bonus, jamais une invincibilité.)
const ESQUIVE_MAX := 0.50

# Borne haute des défenses (armure / résist magique).
# La formule LoL ne sature jamais à 100%, donc cette borne sert juste à
# empêcher des valeurs absurdes (nombres qui explosent). Généreuse.
const DEFENSE_MAX := 1000.0

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

# --- Traits actifs ---
# Liste de Trait attachés à cette unité (reliques, sources d'énergie,
# détournements, scars...). Chacun s'abonne au bus et réagit. Ajout/retrait
# via add_trait / remove_trait, qui gèrent l'activation/désactivation propre.
var traits: Array = []

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
	# Bornes posées dès la construction = garde-fou permanent.
	armure         = Stat.new(0.0).set_bounds(0.0, DEFENSE_MAX)
	resist_magique = Stat.new(0.0).set_bounds(0.0, DEFENSE_MAX)
	esquive        = Stat.new(0.0).set_bounds(0.0, ESQUIVE_MAX)
	crit_chance    = Stat.new(0.0).set_min(0.0)
	crit_multi     = Stat.new(1.5).set_min(1.0)
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
	# Résistances élémentaires : le .tres porte des float simples
	# { Element → float }. On les convertit en Stat clampées via le helper,
	# pour que designer = nombres simples, runtime = stats modifiables.
	for element in data.resistances:
		var stat := u.get_resistance(element)   # crée le Stat (clampé) si absent
		stat.base_value = data.resistances[element]
	# On DUPLIQUE le comportement : chaque boss a son propre état (compteur
	# de tours, enrage...), sinon deux boss partageraient le même.
	u.boss_behavior = data.boss_behavior.duplicate() if data.boss_behavior != null else null
	for spell in data.spells:
		u.add_spell(spell)
	return u

func add_spell(spell: Spell) -> void:
	spells.append(spell)

# ============================================================
# ACCÈS AUX STATS
# ============================================================

# Renvoie le Stat de résistance pour un élément donné, en le CRÉANT
# paresseusement (clampé) s'il n'existe pas encore. Toujours non-null.
# C'est par ici que reliques/équipement modifient une résistance :
#   unit.get_resistance(Spell.Element.FIRE).add_modifier(0.3, FLAT, "relique_x")
func get_resistance(element: int) -> Stat:
	if not resistances.has(element):
		resistances[element] = Stat.new(0.0).set_bounds(RESIST_MIN, RESIST_MAX)
	return resistances[element]

# Renvoie la valeur effective d'une résistance (0.0 si l'élément n'est pas géré).
# Lecture seule : ne crée PAS de Stat (utilisé en boucle par le resolver).
func get_resistance_value(element: int) -> float:
	if resistances.has(element):
		return resistances[element].get_value()
	return 0.0

# Liste centralisée de TOUTES les stats à durée (hors résistances, ajoutées
# dynamiquement). Source unique de vérité : tout ce qui doit "tick" est ici.
# Ajouter une stat future = l'ajouter à cette liste, et tick_durations
# la couvrira automatiquement. Plus aucun oubli possible.
func _all_durational_stats() -> Array:
	var list := [
		max_hp, initiative, max_ap, max_mp, attack_power,
		armure, resist_magique, esquive, crit_chance, crit_multi,
	]
	# Les résistances sont des Stat à part entière : elles ticktent aussi.
	for element in resistances:
		list.append(resistances[element])
	return list

# ============================================================
# TRAITS (le moteur des combos — Couche 3)
# ============================================================

# Attache un trait à cette unité et l'active (il s'abonne au bus).
# Un trait = une relique, une source d'énergie, un détournement, une scar...
func add_trait(t: Trait) -> void:
	if t == null or t in traits:
		return
	traits.append(t)
	t.attach(self)

# Attache un trait à partir d'une fiche TraitData (.tres) : la fabrique
# instancie le bon script, le configure avec ses params, puis on l'attache.
# C'est la voie data-driven : les reliques/équipements porteront des TraitData.
func add_trait_from_data(data: TraitData) -> Trait:
	var t := TraitFactory.create(data)
	if t != null:
		add_trait(t)
	return t

# Retire un trait : le désactive (désabonnement + nettoyage de ses modifiers).
func remove_trait(t: Trait) -> void:
	if t == null or not (t in traits):
		return
	t.deactivate()
	traits.erase(t)

# Désactive tous les traits (ex : unité détruite, fin de combat). Propre.
func clear_traits() -> void:
	for t in traits:
		t.deactivate()
	traits.clear()

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
	# Le CombatLogger écoute status_applied et produit la ligne de log.
	EventBus.status_applied.emit(self, status_data)

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
			# Le CombatLogger écoute status_expired et produit la ligne de log.
			EventBus.status_expired.emit(self, ended)

# Retourne la liste des statuts actifs (pour l'UI).
func get_active_statuses() -> Array:
	return active_statuses

# ============================================================
# GESTION DU TOUR
# ============================================================

func start_turn() -> void:
	# Tick TOUTES les stats à durée d'un coup (défenses et résistances
	# comprises). Avant, seules 5 stats étaient tickées → un buff temporaire
	# "+20 armure 2 tours" ne expirait jamais. Corrigé : liste centralisée.
	for stat in _all_durational_stats():
		stat.tick_durations()
	current_ap = max_ap.get_int()
	current_mp = max_mp.get_int()
	EventBus.turn_started.emit(self)
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
	_apply_damage_result(result, ctx.attacker)
	return result

# take_hit : variante explicite quand on a déjà un HitContext construit
# (utile pour les futurs traits qui veulent pousser des crochets).
func take_hit(ctx: DamageResolver.HitContext) -> DamageResolver.DamageResult:
	if not is_alive:
		return null
	var result := DamageResolver.compute(self, ctx)
	_apply_damage_result(result, ctx.attacker)
	return result

# Applique le résultat calculé aux PV.
# POINT D'ÉMISSION UNIQUE du flux de dégâts : le bus n'est émis QUE d'ici,
# une fois les PV réellement modifiés. Zéro doublon possible.
# Les logs de combat sont produits par le CombatLogger (abonné du bus) :
# unit.gd ne connaît plus le DebugLogger pour le combat, il annonce des faits.
func _apply_damage_result(result: DamageResolver.DamageResult, attacker = null) -> void:
	if result.dodged:
		EventBus.attack_dodged.emit(self, attacker)
		hp_changed.emit(self)
		return

	current_hp -= result.amount

	# Annonce le fait sur le bus (après modification réelle des PV).
	# Le CombatLogger écoute et produit la ligne de log (crit inclus).
	EventBus.damage_dealt.emit(
		self, attacker, result.amount, result.category, result.element, result.is_crit)
	if result.is_crit:
		EventBus.critical_hit.emit(self, attacker, result.amount)

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
	# Le CombatLogger écoute unit_healed et produit la ligne de log.
	EventBus.unit_healed.emit(self, real)
	hp_changed.emit(self)

func _die() -> void:
	# Garde d'idempotence : une unité ne peut mourir qu'UNE fois.
	# Sans ça, si _die est atteint deux fois (deux sources de dégâts dans le
	# même cycle, double appel...), unit_died serait émis deux fois → log et
	# réactions en double. C'est ce qui causait le doublon "est vaincu".
	if not is_alive:
		return
	is_alive = false
	# Le CombatLogger écoute unit_died et produit la ligne "est vaincu".
	EventBus.unit_died.emit(self)
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
