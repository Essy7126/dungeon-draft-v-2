extends RefCounted


static func describe(unit: Unit) -> Dictionary:
	if unit == null or unit.unit_id != &"catabase_shadow_paris" or unit.combat_form_change == null:
		return {}
	var form := unit.combat_form_change
	if unit.combat_form_id == form.target_form:
		return {"subtitle": "Ennemi · Démon de feu", "heading": "Métamorphose accomplie",
			"description": "Paris a abandonné son arc pour son fouet de feu. Sa forme est définitive ; il conserve ses PV et ne reçoit aucun soin.",
			"future_spells": ""}
	var names: PackedStringArray = []
	for spell: Spell in form.spells:
		if spell != null and spell.required_combat_form == form.target_form:
			names.append(spell.spell_name)
	return {"subtitle": "Ennemi · Archer spectral", "heading": "Métamorphose — sous %d %% de PV" % form.below_hp_percent,
		"description": "Lorsqu’il survit à un coup sous %d %% de ses PV initiaux, Paris devient un démon de feu et reçoit %d bouclier. Une seule fois, sans soin. Un coup fatal le tue normalement." % [form.below_hp_percent, form.shield_grant],
		"future_spells": "Forme démoniaque : " + ", ".join(names)}
