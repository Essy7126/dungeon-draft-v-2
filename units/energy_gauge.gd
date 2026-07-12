# units/energy_gauge.gd
# ============================================================
# ENERGY GAUGE — La jauge d'école (Ferveur), extraite de Unit. Logique pure.
#
# Possède TOUT l'état de la jauge : réserve courante, EnergyTypeData (plafond,
# gain_table, coûts d'éveil/réaction), état d'éveil et sa durée. Émet les
# signaux EventBus liés à l'énergie/éveil À L'IDENTIQUE de l'ancien code de
# Unit (mêmes signaux, mêmes arguments, même ordre).
#
# RÈGLE D'ISOLEMENT : la jauge ne lit RIEN de son unité. `owner_unit` ne sert
# QUE de charge utile aux signaux EventBus (qui portent l'unité). Toute
# dépendance de la logique vers les stats de l'unité (Force, terrain,
# multiplicateur global) est PASSÉE EN PARAMÈTRE par l'appelant — c'est ce
# qui rend la jauge testable isolément.
#
# Signaux locaux (relayés par Unit vers ses propres signaux) :
#   changed           → Unit ré-émet energy_changed(unit)
#   awakening_expired → Unit ré-émet stats_changed(unit)
# ============================================================

class_name EnergyGauge
extends RefCounted

# La réserve a changé (gain ou dépense réels). Relayé en energy_changed(unit).
signal changed
# L'éveil vient d'expirer (durée écoulée). Relayé en stats_changed(unit).
signal awakening_expired

# L'unité porteuse — UNIQUEMENT pour les signaux EventBus. Jamais lue.
var owner_unit = null

var energy_type: EnergyTypeData = null
var current_energy: float = 0.0 # Ferveur. Nom conserve pour compatibilite.
var charge_threshold_active: bool = false
var awakening_turns_remaining: int = 0

func _init(p_owner = null) -> void:
	owner_unit = p_owner

# ============================================================
# LECTURE
# ============================================================

func has_energy() -> bool:
	return energy_type != null

func has_charge_threshold() -> bool:
	return has_energy() and charge_threshold_active

func can_afford_energy(amount: float) -> bool:
	var cost: float = maxf(0.0, amount)
	if cost <= 0.0:
		return true
	if not has_energy():
		return false
	return current_energy >= cost

func get_reaction_cost() -> float:
	return maxf(0.0, energy_type.reaction_cost) if has_energy() else 0.0

func get_energy_ratio() -> float:
	if not has_energy() or energy_type.max_energy <= 0.0:
		return 0.0
	return current_energy / energy_type.max_energy

# ============================================================
# COÛTS DE SORT (part jauge : payoff + empreinte)
# ============================================================

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

# ============================================================
# MULTIPLICATEURS D'ÉVEIL (appliqués aux montants des sorts)
# ============================================================

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

func get_modified_incoming_damage(amount: int) -> int:
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

# ============================================================
# GÉNÉRATION
# ============================================================

# Génération par verbe (HIT/PROTECT/HEAL/EXPLOIT/TAKE_DAMAGE). Les facteurs
# qui dépendent de l'UNITÉ arrivent en paramètres, appliqués dans le même
# ordre que l'ancien code de Unit :
#   gain_table → multiplicateur de seuil → terrain → global → exploit (Force).
# `key` doit déjà être normalisé (strip + majuscules) par l'appelant.
func generate_from_verb(
		key: String,
		source: String = "",
		terrain_multiplier: float = 1.0,
		global_multiplier: float = 1.0,
		exploit_multiplier: float = 1.0
	) -> float:
	if not has_energy() or key == "":
		return 0.0
	var amount := energy_type.gain_for(key)
	amount *= energy_type.gain_multiplier_for(key, charge_threshold_active)
	amount *= terrain_multiplier
	amount *= global_multiplier
	if key == EnergyTypeData.VERB_EXPLOIT:
		amount *= exploit_multiplier
	return generate(amount, source if source != "" else key)

# Crédite la jauge, plafonnée à max_energy. Renvoie le gain RÉEL.
func generate(amount: float, source: String = "") -> float:
	if not has_energy() or amount <= 0.0:
		return 0.0
	var before := current_energy
	current_energy = minf(current_energy + amount, energy_type.max_energy)
	var real := current_energy - before
	if real <= 0.0:
		return 0.0
	EventBus.energy_generated.emit(owner_unit, energy_type.energy_id, real)
	sync_charge_state()
	changed.emit()
	return real

# ============================================================
# DÉPENSE (payoffs, empreinte, éveil, réaction)
# ============================================================

func spend(amount: float, source: String = "") -> bool:
	var cost := maxf(0.0, amount)
	if cost <= 0.0:
		return true
	if not can_afford_energy(cost):
		return false
	current_energy = maxf(0.0, current_energy - cost)
	EventBus.energy_spent.emit(owner_unit, energy_type.energy_id, cost)
	sync_charge_state()
	changed.emit()
	return true

func sync_charge_state(emit_events: bool = true) -> void:
	var max_value := energy_type.max_energy if has_energy() else 0.0
	if not emit_events:
		return
	if has_energy():
		EventBus.fervor_changed.emit(owner_unit, current_energy, max_value, charge_threshold_active)
	EventBus.charge_changed.emit(owner_unit, current_energy, max_value, charge_threshold_active)

# ============================================================
# ÉVEIL — franchir le coût rend l'activation POSSIBLE ; l'activation
# dépense la jauge et pose l'état, la durée expire au tick de fin de tour.
# (la condition is_alive reste dans Unit : c'est un état de l'unité)
# ============================================================

func can_activate_awakening() -> bool:
	return has_energy() and not charge_threshold_active and current_energy >= energy_type.awakening_cost

func activate_awakening() -> bool:
	if not can_activate_awakening():
		return false
	if not spend(energy_type.awakening_cost, "eveil"):
		return false
	charge_threshold_active = true
	awakening_turns_remaining = maxi(1, energy_type.awakening_duration_turns)
	EventBus.fervor_threshold_changed.emit(owner_unit, true)
	EventBus.charge_threshold_changed.emit(owner_unit, true)
	EventBus.awakening_activated.emit(owner_unit, energy_type.energy_id, awakening_turns_remaining)
	sync_charge_state(true)
	return true

func tick_awakening() -> void:
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
		EventBus.fervor_threshold_changed.emit(owner_unit, false)
		EventBus.charge_threshold_changed.emit(owner_unit, false)
		EventBus.awakening_ended.emit(owner_unit, energy_type.energy_id)
	sync_charge_state(true)
	awakening_expired.emit()

# ============================================================
# RESET COMBAT — retour à start_energy, éveil purgé.
# ============================================================

func reset() -> void:
	charge_threshold_active = false
	awakening_turns_remaining = 0
	current_energy = energy_type.start_energy if has_energy() else 0.0
	sync_charge_state(true)
