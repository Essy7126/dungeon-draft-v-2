# units/unit.gd
# ============================================================
# UNIT — Un combattant (héros ou ennemi). Logique pure.
#
# Émet des logs de COMBAT (dégâts, soins, mort) et de STATS (statuts),
# pour que la console de debug serve de vrai suivi de combat.
# ============================================================

class_name Unit
extends RefCounted

# --- Identite ---
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

# --- Stats defensives ---
var armure: Stat
var resist_magique: Stat
var esquive: Stat

# --- Stats de critique ---
var crit_chance: Stat
var crit_multi: Stat

# --- Resistances elementaires ---
var resistances: Dictionary = {}

const RESIST_MIN := -0.75
const RESIST_MAX := 0.75
const ESQUIVE_MAX := 0.50
const DEFENSE_MAX := 1000.0

# --- Etat courant ---
var current_hp: int = 0
var current_ap: int = 0
var current_mp: int = 0
var current_shield: int = 0
var is_alive: bool = true
var grid_pos: Vector2i = Vector2i(-1, -1)
# --- Ressources de combat ---
# Elan paie les actions du tour. Ferveur (current_energy) est la jauge
# d'identite liee au type choisi au draft : Rage, Foi, Nature...
const ELAN_MAX := 90.0
const ELAN_START := 50.0
const ELAN_BASE_INCOME := 50.0
const ELAN_INCOME_PER_TIER := 5.0
const ELAN_BASIC_ATTACK_COST := 10.0

var energy_type: EnergyTypeData = null
var current_energy: float = 0.0 # Ferveur. Nom conserve pour compatibilite.
var current_elan: float = ELAN_START
var max_elan: float = ELAN_MAX
var charge_threshold_active: bool = false
var awakening_turns_remaining: int = 0
var next_turn_elan_bonus: float = 0.0
var current_terrain_effect: TerrainEffectData = null
var terrain_elan_discount_used: bool = false
var taunt_source = null
var taunt_turns: int = 0

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
signal energy_changed(unit)
signal elan_changed(unit)
signal shield_changed(unit)

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
	# Énergie : on récupère le type défini sur l'UnitData (ex: Rage) et on
	# initialise la réserve à start_energy (la machine démarre tiède).
	if data.energy_type != null:
		u.energy_type = data.energy_type
		u.current_energy = data.energy_type.start_energy
	if data.chassis_trait != null:
		u.add_trait_from_data(data.chassis_trait)
	for trait_data in data.starting_traits:
		if trait_data != null:
			u.add_trait_from_data(trait_data)
	u.ensure_energy_traits()
	u.sync_charge_state(false)
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
			EventBus.status_applied.emit(self, status_data)
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
func apply_taunt(source, duration: int = 1) -> void:
	taunt_source = source
	taunt_turns = maxi(1, duration)
	var source_name: String = source.unit_name if source != null else "une force inconnue"
	DebugLogger.info(CAT_STATS, "%s est provoque par %s" % [unit_name, source_name])

func get_forced_target():
	if taunt_source != null and taunt_turns > 0 and taunt_source.is_alive:
		return taunt_source
	return null

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

	if taunt_turns > 0:
		taunt_turns -= 1
		if taunt_turns <= 0:
			taunt_source = null
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
	_tick_awakening()

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
	terrain_elan_discount_used = false
	_refresh_turn_elan_budget()
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
# ÉNERGIE — l'économie d'action (remplace les PA)
# ============================================================

# L'unité a-t-elle une énergie configurée ? (les ennemis simples peuvent ne
# pas en avoir ; dans ce cas les sorts à coût d'énergie ne s'appliquent pas).
func has_energy() -> bool:
	return energy_type != null

func ensure_energy_traits() -> void:
	if energy_type == null or energy_type.threshold_trait == null:
		return
	for t in traits:
		if t != null and t.has_method("_trait_name") and t._trait_name() == "trait_threshold":
			return
	add_trait_from_data(energy_type.threshold_trait)

func reset_combat_resources() -> void:
	charge_threshold_active = false
	awakening_turns_remaining = 0
	next_turn_elan_bonus = 0.0
	max_elan = _compute_elan_income()
	current_elan = max_elan
	current_energy = energy_type.start_energy if has_energy() else 0.0
	sync_charge_state(true)
	elan_changed.emit(self)
	energy_changed.emit(self)
	EventBus.elan_changed.emit(self, current_elan, max_elan)
	if has_energy():
		EventBus.fervor_changed.emit(self, current_energy, energy_type.max_energy, charge_threshold_active)

func set_current_terrain_effect(effect: TerrainEffectData) -> void:
	current_terrain_effect = effect

func _terrain_matches_energy() -> bool:
	return current_terrain_effect != null and has_energy() and current_terrain_effect.matches_energy(energy_type.energy_id)

func _current_terrain_elan_discount() -> float:
	if terrain_elan_discount_used or not _terrain_matches_energy():
		return 0.0
	return maxf(0.0, current_terrain_effect.elan_discount)

func _current_terrain_fervor_multiplier() -> float:
	if not _terrain_matches_energy():
		return 1.0
	return maxf(0.0, current_terrain_effect.fervor_generation_multiplier)

func can_afford_elan(amount: float) -> bool:
	var cost: float = maxf(0.0, amount)
	return current_elan >= cost

func generate_elan(amount: float, source: String = "") -> float:
	var gain: float = maxf(0.0, amount)
	if gain <= 0.0:
		return 0.0
	var before: float = current_elan
	current_elan = minf(current_elan + gain, max_elan)
	var real: float = current_elan - before
	if real <= 0.0:
		return 0.0
	EventBus.elan_generated.emit(self, real)
	EventBus.elan_changed.emit(self, current_elan, max_elan)
	elan_changed.emit(self)
	return real

func spend_elan(amount: float, source: String = "") -> bool:
	var cost: float = maxf(0.0, amount)
	if cost <= 0.0:
		return true
	if not can_afford_elan(cost):
		return false
	current_elan = maxf(0.0, current_elan - cost)
	if source != "" and _current_terrain_elan_discount() > 0.0:
		terrain_elan_discount_used = true
	EventBus.elan_spent.emit(self, cost)
	EventBus.elan_changed.emit(self, current_elan, max_elan)
	elan_changed.emit(self)
	return true

func _compute_elan_income() -> float:
	var tier := GameManager.get_elan_tier() if GameManager.has_method("get_elan_tier") else GameManager.get_charge_tier()
	var amount := ELAN_BASE_INCOME + float(maxi(1, tier) - 1) * ELAN_INCOME_PER_TIER
	if has_charge_threshold() and energy_type.awakening_elan_income_penalty > 0.0:
		amount -= energy_type.awakening_elan_income_penalty
	amount += next_turn_elan_bonus
	next_turn_elan_bonus = 0.0
	return clampf(amount, 0.0, ELAN_MAX)

func _refresh_turn_elan_budget() -> void:
	max_elan = _compute_elan_income()
	current_elan = max_elan
	EventBus.elan_changed.emit(self, current_elan, max_elan)
	elan_changed.emit(self)

func can_afford_energy(amount: float) -> bool:
	var cost: float = maxf(0.0, amount)
	if cost <= 0.0:
		return true
	if not has_energy():
		return false
	return current_energy >= cost

func has_charge_threshold() -> bool:
	return has_energy() and charge_threshold_active

func get_basic_attack_elan_cost() -> float:
	var cost := ELAN_BASIC_ATTACK_COST - _current_terrain_elan_discount()
	return maxf(0.0, cost)

func get_basic_attack_cost() -> float:
	return get_basic_attack_elan_cost()

func get_spell_elan_cost(spell: Spell) -> float:
	if spell == null:
		return 0.0
	var cost := maxf(0.0, spell.energy_cost - _current_terrain_elan_discount())
	return maxf(0.0, cost)

func get_spell_energy_cost(spell: Spell) -> float:
	return get_spell_elan_cost(spell)

func get_spell_imprint_fervor_cost(spell: Spell) -> float:
	if spell == null or not spell.can_imprint():
		return 0.0
	var cost: float = spell.imprint_fervor_cost
	if has_charge_threshold() and energy_type.awakening_imprint_discount > 0.0:
		cost -= energy_type.awakening_imprint_discount
	return maxf(0.0, cost)

func get_spell_fervor_cost(spell: Spell, imprinted: bool = false) -> float:
	if spell == null:
		return 0.0
	var cost := maxf(0.0, spell.fervor_cost)
	if imprinted:
		cost += get_spell_imprint_fervor_cost(spell)
	return maxf(0.0, cost)

func can_afford_spell_resources(spell: Spell, imprinted: bool = false) -> bool:
	if spell == null:
		return false
	return can_afford_elan(get_spell_elan_cost(spell)) and can_afford_energy(get_spell_fervor_cost(spell, imprinted))

func get_modified_spell_damage(spell: Spell, amount: int) -> int:
	if spell == null or amount <= 0:
		return amount
	if has_charge_threshold():
		if energy_type.awakening_blocks_direct_damage:
			return 0
		if energy_type.awakening_damage_multiplier > 0.0:
			return maxi(0, int(round(float(amount) * energy_type.awakening_damage_multiplier)))
	return amount

func get_modified_spell_heal(spell: Spell, amount: int) -> int:
	if spell == null or amount <= 0:
		return amount
	if has_charge_threshold() and energy_type.awakening_heal_multiplier > 0.0:
		return maxi(0, int(round(float(amount) * energy_type.awakening_heal_multiplier)))
	return amount

func get_modified_spell_shield(spell: Spell, amount: int) -> int:
	if spell == null or amount <= 0:
		return amount
	if has_charge_threshold() and energy_type.awakening_shield_multiplier > 0.0:
		return maxi(0, int(round(float(amount) * energy_type.awakening_shield_multiplier)))
	return amount

func _get_modified_incoming_damage(amount: int) -> int:
	if amount <= 0:
		return amount
	var modified := float(amount)
	if has_charge_threshold():
		if energy_type.threshold_damage_reduction_pct > 0.0:
			var reduction := clampf(energy_type.threshold_damage_reduction_pct, 0.0, 0.95)
			modified *= (1.0 - reduction)
		if energy_type.awakening_incoming_damage_multiplier > 0.0:
			modified *= energy_type.awakening_incoming_damage_multiplier
	return maxi(0, int(round(modified)))

func generate_fervor_from_verb(verb: String, source: String = "") -> float:
	if not has_energy():
		return 0.0
	var key := verb.strip_edges().to_upper()
	if key == "":
		return 0.0
	var amount := energy_type.gain_for(key)
	amount *= energy_type.gain_multiplier_for(key, charge_threshold_active)
	amount *= _current_terrain_fervor_multiplier()
	amount *= GameManager.get_fervor_multiplier() if GameManager.has_method("get_fervor_multiplier") else GameManager.get_charge_multiplier()
	return generate_energy(amount, source if source != "" else key)

func generate_charge_from_verb(verb: String, source: String = "") -> float:
	return generate_fervor_from_verb(verb, source)

func generate_energy(amount: float, source: String = "") -> float:
	if not has_energy() or amount <= 0.0:
		return 0.0
	var before := current_energy
	current_energy = minf(current_energy + amount, energy_type.max_energy)
	var real := current_energy - before
	if real <= 0.0:
		return 0.0
	EventBus.energy_generated.emit(self, energy_type.energy_id, real)
	sync_charge_state()
	energy_changed.emit(self)
	return real

func spend_energy(amount: float, source: String = "") -> bool:
	var cost := maxf(0.0, amount)
	if cost <= 0.0:
		return true
	if not can_afford_energy(cost):
		return false
	current_energy = maxf(0.0, current_energy - cost)
	EventBus.energy_spent.emit(self, energy_type.energy_id, cost)
	sync_charge_state()
	energy_changed.emit(self)
	return true

func sync_charge_state(emit_events: bool = true) -> void:
	var max_value := energy_type.max_energy if has_energy() else 0.0
	if not emit_events:
		return
	if has_energy():
		EventBus.fervor_changed.emit(self, current_energy, max_value, charge_threshold_active)
	EventBus.charge_changed.emit(self, current_energy, max_value, charge_threshold_active)


func can_activate_awakening() -> bool:
	return has_energy() and is_alive and not charge_threshold_active and current_energy >= energy_type.awakening_cost

func activate_awakening() -> bool:
	if not can_activate_awakening():
		return false
	if not spend_energy(energy_type.awakening_cost, "eveil"):
		return false
	charge_threshold_active = true
	awakening_turns_remaining = maxi(1, energy_type.awakening_duration_turns)
	EventBus.fervor_threshold_changed.emit(self, true)
	EventBus.charge_threshold_changed.emit(self, true)
	EventBus.awakening_activated.emit(self, energy_type.energy_id, awakening_turns_remaining)
	sync_charge_state(true)
	stats_changed.emit(self)
	DebugLogger.info(CAT_STATS, "%s declenche %s (%d tours)" % [unit_name, energy_type.threshold_name, awakening_turns_remaining])
	return true

func _tick_awakening() -> void:
	if not charge_threshold_active:
		return
	awakening_turns_remaining -= 1
	if awakening_turns_remaining <= 0:
		_end_awakening()

func _end_awakening() -> void:
	if not charge_threshold_active:
		return
	charge_threshold_active = false
	awakening_turns_remaining = 0
	if has_energy():
		EventBus.fervor_threshold_changed.emit(self, false)
		EventBus.charge_threshold_changed.emit(self, false)
		EventBus.awakening_ended.emit(self, energy_type.energy_id)
	sync_charge_state(true)
	stats_changed.emit(self)
func get_energy_ratio() -> float:
	if not has_energy() or energy_type.max_energy <= 0.0:
		return 0.0
	return current_energy / energy_type.max_energy

func get_elan_ratio() -> float:
	if max_elan <= 0.0:
		return 0.0
	return current_elan / max_elan
# ============================================================
# BOUCLIER — couche défensive entre l'énergie et les PV
# Le bouclier absorbe les dégâts AVANT les PV. Il n'expire pas
# naturellement : il tient jusqu'à être épuisé ou remplacé.
# Design : on ne cumule pas les boucliers — un nouveau remplace
# l'ancien s'il est plus élevé, sinon il est ignoré. Évite le
# spam de boucliers qui empilement indéfiniment.
# ============================================================

# Accorde un bouclier. Remplace l'ancien s'il est plus faible.
# Un bouclier plus faible est ignoré : on ne perd jamais son bouclier
# parce qu'un sort de soutien a donné moins que ce qu'on a déjà.
func add_shield(amount: int) -> void:
	if has_charge_threshold() and energy_type.awakening_blocks_shield:
		return
	if not is_alive or amount <= 0:
		return
	if amount <= current_shield:
		return                           # bouclier actuel déjà plus fort : ignoré
	current_shield = amount
	EventBus.shield_gained.emit(self, amount)
	shield_changed.emit(self)
	DebugLogger.debug(CAT_STATS,
		"%s reçoit un bouclier de %d" % [unit_name, amount])

# Retire le bouclier complètement (fin de tour, sort ennemi...).
func clear_shield() -> void:
	if current_shield <= 0:
		return
	current_shield = 0
	shield_changed.emit(self)

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
func _apply_defensive_reaction_to_raw(amount: int, attacker, options: Dictionary) -> int:
	if amount <= 0 or not has_energy() or attacker == null:
		return amount
	if options.get("disable_fervor_reaction", false):
		return amount
	if attacker.team == team:
		return amount
	var cost: float = maxf(0.0, energy_type.reaction_cost)
	if cost <= 0.0 or current_energy < cost:
		return amount
	var multiplier: float = clampf(energy_type.reaction_damage_multiplier, 0.0, 1.0)
	if not spend_energy(cost, "reaction"):
		return amount
	var reduced := maxi(0, int(round(float(amount) * multiplier)))
	var mitigated := maxi(0, amount - reduced)
	next_turn_elan_bonus += maxf(0.0, energy_type.reaction_next_turn_elan_bonus)
	EventBus.fervor_reaction_used.emit(self, attacker, cost, mitigated)
	DebugLogger.info(CAT_STATS, "%s brule %.0f Ferveur en reaction (-%d degats)" % [unit_name, cost, mitigated])
	return reduced
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
	ctx.raw_damage = _get_modified_incoming_damage(_apply_defensive_reaction_to_raw(amount, attacker, options))
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

# Applique le résultat calculé aux PV, en absorbant d'abord le bouclier.
# POINT D'ÉMISSION UNIQUE du flux de dégâts.
func _apply_damage_result(result: DamageResolver.DamageResult, attacker = null) -> void:
	if result.dodged:
		EventBus.attack_dodged.emit(self, attacker)
		hp_changed.emit(self)
		return

	# --- Absorption par le bouclier ---
	# Le bouclier prend les dégâts en premier. Si tout est absorbé, les PV ne bougent pas.
	var damage_to_hp := result.amount
	if current_shield > 0 and damage_to_hp > 0:
		var absorbed := mini(current_shield, damage_to_hp)
		current_shield -= absorbed
		damage_to_hp -= absorbed
		EventBus.shield_absorbed.emit(self, absorbed)
		if current_shield <= 0:
			EventBus.shield_broken.emit(self)
		shield_changed.emit(self)
		DebugLogger.debug(CAT_STATS,
			"%s : bouclier absorbe %d (reste %d)" % [unit_name, absorbed, current_shield])

	# Annonce la frappe sur le bus (montant après mitigation armure/résist, avant bouclier).
	# shield_absorbed est émis séparément pour les traits qui y réagissent.
	EventBus.damage_dealt.emit(
		self, attacker, result.amount, result.category, result.element, result.is_crit)
	if result.is_crit:
		EventBus.critical_hit.emit(self, attacker, result.amount)

	# --- Application aux PV ---
	if damage_to_hp > 0:
		current_hp -= damage_to_hp
		hp_changed.emit(self)
		if current_hp <= 0:
			current_hp = 0
			_die()
	else:
		# Tout absorbé : les PV n'ont pas bougé, mais on notifie pour l'UI.
		hp_changed.emit(self)

func heal(amount: int) -> void:
	if has_charge_threshold() and energy_type.awakening_blocks_healing:
		DebugLogger.debug(CAT_STATS, "%s ne peut pas etre soigne pendant %s" % [unit_name, energy_type.threshold_name])
		return
	if not is_alive:
		return
	var max_value := max_hp.get_int()
	var before := current_hp
	current_hp = mini(current_hp + amount, max_value)
	var real := current_hp - before
	var overheal := maxi(0, amount - real)
	if overheal > 0 and has_charge_threshold() and energy_type.threshold_overheal_to_shield:
		var shield_amount := int(round(float(overheal) * energy_type.threshold_overheal_shield_multiplier))
		if shield_amount > 0:
			add_shield(shield_amount)
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
