class_name TraitChassisGardien
extends Trait

func _trait_name() -> String:
	return "chassis_gardien"

func _activate() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.shield_absorbed.connect(_on_shield_absorbed)

func _deactivate() -> void:
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)
	if EventBus.shield_absorbed.is_connected(_on_shield_absorbed):
		EventBus.shield_absorbed.disconnect(_on_shield_absorbed)

func _on_spell_cast(caster, spell: Spell, report: Dictionary) -> void:
	if caster != owner or spell == null or not _can_generate():
		return
	var verb := spell.charge_verb.strip_edges().to_upper()
	if _verb_happened(verb, report):
		_generate(verb, spell.spell_name)

func _on_shield_absorbed(unit, amount: int) -> void:
	if not _can_generate():
		return
	if unit == null or unit.team != owner.team or amount <= 0:
		return
	_generate(EnergyTypeData.VERB_TAKE_DAMAGE, "bouclier")

func _verb_happened(verb: String, report: Dictionary) -> bool:
	match verb:
		EnergyTypeData.VERB_PROTECT:
			return not report.get("shielded_units", []).is_empty() or not report.get("controlled_enemies", []).is_empty() or not report.get("terrain_changed", []).is_empty()
		EnergyTypeData.VERB_HIT:
			return not report.get("damaged_enemies", []).is_empty()
		EnergyTypeData.VERB_HEAL:
			return not report.get("healed_units", []).is_empty()
		EnergyTypeData.VERB_EXPLOIT:
			return not report.get("affected_units", []).is_empty() or not report.get("terrain_changed", []).is_empty()
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
