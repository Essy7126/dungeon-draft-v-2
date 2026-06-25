class_name TraitThreshold
extends Trait

var _modifier_source: String = ""
var _threshold_active: bool = false

func _trait_name() -> String:
	return "trait_threshold"

func _activate() -> void:
	_modifier_source = "%s:threshold" % source_id
	EventBus.fervor_threshold_changed.connect(_on_fervor_threshold_changed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	if owner != null and owner.charge_threshold_active:
		_apply_threshold()

func _deactivate() -> void:
	if EventBus.fervor_threshold_changed.is_connected(_on_fervor_threshold_changed):
		EventBus.fervor_threshold_changed.disconnect(_on_fervor_threshold_changed)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	_remove_threshold()

func _on_fervor_threshold_changed(unit, active: bool) -> void:
	if unit != owner:
		return
	if active:
		_apply_threshold()
	else:
		_remove_threshold()

func _on_damage_dealt(target, _attacker, _amount, _category, _element, _is_crit) -> void:
	if target != owner or not _threshold_active:
		return
	if owner == null or not owner.has_energy():
		return
	var gain: float = owner.energy_type.threshold_take_damage_gain
	if gain > 0.0:
		owner.generate_energy(gain, source_id)

func _apply_threshold() -> void:
	if owner == null or not owner.has_energy() or _threshold_active:
		return
	_threshold_active = true
	var et: EnergyTypeData = owner.energy_type
	if et.threshold_attack_bonus_pct != 0.0:
		owner.attack_power.add_modifier(et.threshold_attack_bonus_pct, Stat.ModType.PERCENT, _modifier_source, -1)
	if et.threshold_armure_bonus != 0.0:
		owner.armure.add_modifier(et.threshold_armure_bonus, Stat.ModType.FLAT, _modifier_source, -1)
	if et.threshold_resist_bonus != 0.0:
		owner.resist_magique.add_modifier(et.threshold_resist_bonus, Stat.ModType.FLAT, _modifier_source, -1)
	if et.threshold_esquive_bonus != 0.0:
		owner.esquive.add_modifier(et.threshold_esquive_bonus, Stat.ModType.FLAT, _modifier_source, -1)
	owner.stats_changed.emit(owner)
	DebugLogger.info(DebugLogger.LogCategory.STATS,
		"%s entre en %s" % [owner.unit_name, et.threshold_name])

func _remove_threshold() -> void:
	if owner == null or not _threshold_active:
		return
	_threshold_active = false
	if owner.has_method("_all_durational_stats"):
		for stat in owner._all_durational_stats():
			stat.remove_modifiers_from(_modifier_source)
	owner.stats_changed.emit(owner)
	if owner.has_energy():
		DebugLogger.info(DebugLogger.LogCategory.STATS,
			"%s sort de %s" % [owner.unit_name, owner.energy_type.threshold_name])