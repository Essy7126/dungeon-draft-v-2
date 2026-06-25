class_name TraitChassisAssassin
extends Trait

func _trait_name() -> String:
	return "chassis_assassin"

func _activate() -> void:
	EventBus.basic_attack_performed.connect(_on_basic_attack_performed)
	EventBus.spell_cast.connect(_on_spell_cast)

func _deactivate() -> void:
	if EventBus.basic_attack_performed.is_connected(_on_basic_attack_performed):
		EventBus.basic_attack_performed.disconnect(_on_basic_attack_performed)
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)

func _on_basic_attack_performed(attacker, _target) -> void:
	if attacker == owner:
		_generate(EnergyTypeData.VERB_HIT, "attaque")

func _on_spell_cast(caster, spell: Spell, report: Dictionary) -> void:
	if caster != owner or spell == null or not _can_generate():
		return
	var verb := spell.charge_verb.strip_edges().to_upper()
	if _verb_happened(verb, report):
		_generate(verb, spell.spell_name)
	if report.get("angle_advantage", false) or _any_marked(report.get("affected_units", [])):
		_generate(EnergyTypeData.VERB_EXPLOIT, "faille")

func _verb_happened(verb: String, report: Dictionary) -> bool:
	match verb:
		EnergyTypeData.VERB_HIT:
			return not report.get("damaged_enemies", []).is_empty()
		EnergyTypeData.VERB_EXPLOIT:
			return not report.get("affected_units", []).is_empty() or not report.get("terrain_changed", []).is_empty()
		EnergyTypeData.VERB_PROTECT:
			return not report.get("shielded_units", []).is_empty() or not report.get("controlled_enemies", []).is_empty() or not report.get("terrain_changed", []).is_empty()
		EnergyTypeData.VERB_HEAL:
			return not report.get("healed_units", []).is_empty()
	return false

func _generate(verb: String, reason: String) -> void:
	if verb == "":
		return
	var amount: float = owner.generate_fervor_from_verb(verb, source_id)
	if amount > 0.0:
		DebugLogger.debug(DebugLogger.LogCategory.STATS,
			"%s genere %.0f %s (%s)" % [owner.unit_name, amount, owner.energy_type.energy_name, reason])

func _can_generate() -> bool:
	return owner != null and owner.is_alive and owner.has_energy()

func _any_marked(targets: Array) -> bool:
	for target in targets:
		if target != null and _has_status(target, "Marque"):
			return true
		if target != null and _has_status(target, "Marqué"):
			return true
	return false

func _has_status(unit, status_name: String) -> bool:
	if unit == null or not unit.has_method("get_active_statuses"):
		return false
	for entry in unit.get_active_statuses():
		var sd: StatusData = entry.get("data")
		if sd != null and sd.status_name == status_name:
			return true
	return false