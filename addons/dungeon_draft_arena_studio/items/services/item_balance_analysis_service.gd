@tool
class_name ItemBalanceAnalysisService
extends RefCounted

const PRODUCTION_HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]

var preview_service := ItemRuntimePreviewService.new()


func spell_choices(definition: ItemDefinition) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if definition == null:
		return choices
	for path in PRODUCTION_HERO_PATHS:
		var unit_data := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if unit_data == null:
			continue
		var character_id := StringName(unit_data.get("unit_id"))
		if not definition.is_compatible_with(character_id):
			continue
		var spells_value: Variant = unit_data.get("spells")
		var spells: Array = spells_value if spells_value is Array else []
		var spell_choices: Array[Dictionary] = []
		for index in spells.size():
			var spell := spells[index] as Resource
			if spell == null:
				continue
			var spell_id := StringName(spell.get("spell_id"))
			if spell_id == &"":
				spell_id = StringName(spell.resource_path)
			spell_choices.append({
				"index": index,
				"spell_id": spell_id,
				"display_name": str(spell.get("spell_name")),
			})
		choices.append({
			"character_id": character_id,
			"display_name": str(unit_data.get("unit_name")),
			"path": path,
			"spells": spell_choices,
		})
	return choices


func project_selected_spell(
		definition: ItemDefinition,
		hero_path: String,
		spell_index: int,
		target_hp_ratio := 1.0
	) -> Dictionary:
	if definition == null or hero_path.is_empty():
		return {"ok": false, "error": "Sélection de sort incomplète."}
	var unit_resource := ResourceLoader.load(hero_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if unit_resource == null:
		return {"ok": false, "error": "Héros de projection introuvable."}
	var character_id := StringName(unit_resource.get("unit_id"))
	if not definition.is_compatible_with(character_id):
		return {"ok": false, "error": "Objet incompatible avec ce héros."}
	var spells_value: Variant = unit_resource.get("spells")
	var spells: Array = spells_value if spells_value is Array else []
	if spell_index < 0 or spell_index >= spells.size():
		return {"ok": false, "error": "Sort de projection introuvable."}
	var spell := spells[spell_index] as Spell
	if spell == null:
		return {"ok": false, "error": "Ressource de sort invalide."}
	var result := _project_spell_values(spell, definition, target_hp_ratio)
	result["character_id"] = character_id
	result["hero_name"] = str(unit_resource.get("unit_name"))
	if not Engine.is_editor_hint():
		var unit_data := unit_resource as UnitData
		if unit_data != null:
			result["runtime_projection"] = preview_service.project_spell(unit_data, spell, definition)
			result["runtime_service"] = "ItemRuntimePreviewService.project_spell"
	else:
		result["runtime_service"] = "Projection pure éditeur ; parité runtime couverte par GUT"
	return result


func _project_spell_values(
		spell: Spell, definition: ItemDefinition, target_hp_ratio: float
	) -> Dictionary:
	var damage_after := spell.damage
	var heal_after := spell.heal
	var shield_after := spell.shield_grant
	var push_after := spell.push_distance
	var range_after := spell.spell_range
	var battle_context_required := false
	var modifiers: Array[Dictionary] = []
	for value in definition.spell_modifiers:
		if not value is ItemSpellModifierData:
			continue
		var modifier := value as ItemSpellModifierData
		var applies_to_spell := modifier.applies_to(spell)
		var target_condition_passes := modifier.target_hp_at_or_below < 0.0 \
			or target_hp_ratio <= modifier.target_hp_at_or_below
		battle_context_required = battle_context_required or modifier.damage_percent > 0.0 \
			or modifier.healing_and_shield_percent > 0.0 or modifier.push_bonus > 0
		if applies_to_spell:
			range_after += modifier.get_range_bonus(null, spell)
			if modifier.damage_percent > 0.0 and spell.damage > 0 and target_condition_passes:
				damage_after += maxi(1, int(round(float(damage_after) * modifier.damage_percent)))
			if modifier.healing_and_shield_percent > 0.0:
				if spell.heal > 0:
					heal_after += maxi(1, int(round(float(spell.heal) * modifier.healing_and_shield_percent)))
				if spell.shield_grant > 0:
					shield_after += maxi(1, int(round(float(spell.shield_grant) * modifier.healing_and_shield_percent)))
			if modifier.push_bonus > 0 and spell.push_distance > 0:
				push_after = maxi(push_after, spell.push_distance + modifier.push_bonus)
		modifiers.append({
			"name": modifier.modifier_name,
			"applies_to_spell": applies_to_spell,
			"target_condition_passes": target_condition_passes,
			"target_hp_at_or_below": modifier.target_hp_at_or_below,
		})
	return {
		"ok": true,
		"spell_id": str(spell.get_effective_spell_id()),
		"spell_name": spell.spell_name,
		"target_hp_ratio": target_hp_ratio,
		"range_before": spell.spell_range, "range_after": range_after,
		"damage_before": spell.damage, "damage_after": damage_after,
		"heal_before": spell.heal, "heal_after": heal_after,
		"shield_before": spell.shield_grant, "shield_after": shield_after,
		"push_before": spell.push_distance, "push_after": push_after,
		"damage_type_label": "Physique" if spell.damage_type == Spell.DamageType.PHYSICAL else "Magique",
		"element_label": ["Aucun", "Feu", "Glace", "Foudre", "Ombre", "Sacré", "Terre"][spell.element],
		"modifiers": modifiers,
		"battle_context_required": battle_context_required,
	}


func analyze(definition: ItemDefinition) -> Dictionary:
	if definition == null:
		return {"ok": false, "error": "Aucun objet à analyser."}
	if Engine.is_editor_hint():
		return _analyze_editor_projection(definition)
	var heroes: Array[Dictionary] = []
	for path in PRODUCTION_HERO_PATHS:
		var unit_data := load(path) as UnitData
		if unit_data == null or not definition.is_compatible_with(unit_data.get_effective_unit_id()):
			continue
		var preview := preview_service.preview_equipment(unit_data, definition) \
			if definition.is_equippable() else preview_service.preview_consumable(unit_data, definition)
		if definition.is_equippable() and preview.get("ok", false):
			preview["ehp"] = _ehp_projection(
				preview.get("before", {}) as Dictionary,
				preview.get("after", {}) as Dictionary,
			)
		preview["character_id"] = unit_data.get_effective_unit_id()
		preview["display_name"] = unit_data.unit_name
		heroes.append(preview)
	var diagnostic_breakpoints := breakpoints(definition)
	diagnostic_breakpoints.append_array(_runtime_breakpoints(definition, heroes))
	return {
		"ok": not heroes.is_empty(),
		"heroes": heroes,
		"breakpoints": diagnostic_breakpoints,
		"assumptions": [
			"Projection isolée sur le trio de production au HEAD.",
			"EHP estimé avec DamageResolver.mitigation, sans statuts conditionnels ni esquive.",
			"Les effets nécessitant une grille de bataille sont signalés, pas simulés silencieusement.",
		],
		"budget": {"status": "ESTIMATION_EXPLORATOIRE", "score": _exploratory_budget(definition)},
	}


func _analyze_editor_projection(definition: ItemDefinition) -> Dictionary:
	var heroes: Array[Dictionary] = []
	for path in PRODUCTION_HERO_PATHS:
		var unit_data := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if unit_data == null:
			continue
		var character_id := StringName(unit_data.get("unit_id"))
		if not definition.is_compatible_with(character_id):
			continue
		var before := _editor_unit_snapshot(unit_data)
		var after := _apply_editor_stat_projection(before, definition)
		var hero := {
			"ok": true,
			"character_id": character_id,
			"display_name": str(unit_data.get("unit_name")),
			"before": before,
			"after": after,
			"delta": _numeric_delta(before, after),
			"canonical_unchanged": true,
			"runtime_service": "Projection éditeur pure ; parité EquipmentService couverte par GUT",
			"editor_projection": true,
		}
		if definition.is_equippable():
			hero["ehp"] = _ehp_projection(before, after)
		heroes.append(hero)
	var diagnostic_breakpoints := breakpoints(definition)
	diagnostic_breakpoints.append_array(_runtime_breakpoints(definition, heroes))
	return {
		"ok": not heroes.is_empty(),
		"heroes": heroes,
		"breakpoints": diagnostic_breakpoints,
		"assumptions": [
			"Dans l’éditeur, les UnitData runtime non-tool sont lus comme Resources exportées.",
			"La parité apply/remove et ItemUseService est exécutée par le smoke et GUT hors editor_hint.",
			"Aucune Resource canonique ni run active n’est mutée.",
		],
		"budget": {"status": "ESTIMATION_EXPLORATOIRE", "score": _exploratory_budget(definition)},
	}


func _editor_unit_snapshot(unit_data: Resource) -> Dictionary:
	var resistances := unit_data.get("resistances") as Dictionary
	return {
		"max_hp": float(unit_data.get("max_hp")),
		"armure": float(unit_data.get("armure")),
		"resist_magique": float(unit_data.get("resist_magique")),
		"initiative": float(unit_data.get("initiative")),
		"max_ap": float(unit_data.get("max_ap")),
		"max_mp": float(unit_data.get("max_mp")),
		"attack_power": float(unit_data.get("attack_power")),
		"crit_chance": float(unit_data.get("crit_chance")),
		"crit_multi": float(unit_data.get("crit_multi")),
		"esquive": float(unit_data.get("esquive")),
		"force": float(unit_data.get("force")),
		"resistance_ice": float(resistances.get(Spell.Element.ICE, 0.0)),
	}


func _apply_editor_stat_projection(before: Dictionary, definition: ItemDefinition) -> Dictionary:
	var after := before.duplicate(true)
	var flat := {}
	var percent := {}
	for modifier in definition.stat_modifiers:
		if modifier == null:
			continue
		var target := percent if modifier.modifier_type == ItemStatModifierData.ModifierType.PERCENT else flat
		target[modifier.stat_id] = float(target.get(modifier.stat_id, 0.0)) + modifier.value
	for key in before:
		after[key] = (float(before[key]) + float(flat.get(StringName(key), 0.0))) \
			* (1.0 + float(percent.get(StringName(key), 0.0)))
	after["armure"] = maxf(0.0, float(after.armure))
	after["resist_magique"] = maxf(0.0, float(after.resist_magique))
	after["esquive"] = clampf(float(after.esquive), 0.0, 0.5)
	after["crit_chance"] = clampf(float(after.crit_chance), 0.0, 1.0)
	after["crit_multi"] = maxf(1.0, float(after.crit_multi))
	after["force"] = maxf(0.0, float(after.force))
	after["resistance_ice"] = clampf(float(after.resistance_ice), -0.75, 0.75)
	return after


func _numeric_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in before:
		result[key] = float(after.get(key, 0.0)) - float(before[key])
	return result


func breakpoints(definition: ItemDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier in definition.stat_modifiers:
		if modifier == null:
			continue
		if modifier.stat_id in [&"max_ap", &"max_mp"] and not is_zero_approx(modifier.value):
			result.append({
				"severity": "FORTE",
				"code": "AP_BREAKPOINT" if modifier.stat_id == &"max_ap" else "MP_BREAKPOINT",
				"message": "%+.0f %s maximum" % [modifier.value, "PA" if modifier.stat_id == &"max_ap" else "PM"],
			})
			if modifier.stat_id == &"max_ap":
				result.append({
					"severity": "FORTE", "code": "CAST_COUNT_BREAKPOINT",
					"message": "Le nombre de sorts lançables par tour peut changer.",
				})
	var has_hp := definition.stat_modifiers.any(func(value):
		return value != null and value.stat_id == &"max_hp" and value.value > 0.0
	)
	var has_defense := definition.stat_modifiers.any(func(value):
		return value != null and value.stat_id in [&"armure", &"resist_magique"] and value.value > 0.0
	)
	if has_hp and has_defense:
		result.append({
			"severity": "FORTE", "code": "HP_DEFENSE_COMBINATION",
			"message": "La combinaison PV + défense amplifie l’endurance effective.",
		})
	for modifier in definition.spell_modifiers:
		if not modifier is ItemSpellModifierData:
			continue
		var item_modifier := modifier as ItemSpellModifierData
		if item_modifier.range_bonus != 0:
			result.append({"severity": "FORTE", "code": "RANGE_BREAKPOINT", "message": "+%d portée" % item_modifier.range_bonus})
		if item_modifier.damage_percent > 0.0 and item_modifier.target_spell_id == &"" \
				and item_modifier.target_spell_name.is_empty() and item_modifier.damage_type_filter < 0 \
				and not item_modifier.require_elemental_damage:
			result.append({"severity": "FORTE", "code": "GLOBAL_MULTIPLIER", "message": "Multiplicateur applicable à tous les sorts offensifs."})
		if item_modifier.push_bonus > 0:
			result.append({"severity": "ATTENTION", "code": "PUSH_BREAKPOINT", "message": "+%d poussée ; vérifier un bénéficiaire réel." % item_modifier.push_bonus})
		if item_modifier.healing_and_shield_percent > 0.0:
			result.append({"severity": "ATTENTION", "code": "SUPPORT_BREAKPOINT", "message": "Vérifier un sort de soin ou bouclier compatible."})
		result.append_array(_spell_beneficiary_breakpoints(definition, item_modifier))
	return result


func _runtime_breakpoints(
		definition: ItemDefinition, heroes: Array[Dictionary]
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier in definition.stat_modifiers:
		if modifier == null:
			continue
		var observed := false
		var full_flat_delta := false
		for hero in heroes:
			var delta := hero.get("delta", {}) as Dictionary
			var value := float(delta.get(str(modifier.stat_id), 0.0))
			observed = observed or not is_zero_approx(value)
			if modifier.modifier_type == ItemStatModifierData.ModifierType.FLAT:
				full_flat_delta = full_flat_delta or is_equal_approx(value, modifier.value)
		if not observed:
			result.append({
				"severity": "FORTE", "code": "NOOP_EFFECT",
				"message": "%s ne produit aucun delta sur les héros compatibles." % modifier.stat_id,
			})
		elif modifier.value < 0.0 \
				and modifier.modifier_type == ItemStatModifierData.ModifierType.FLAT \
				and not full_flat_delta:
			result.append({
				"severity": "ATTENTION", "code": "DRAWBACK_CLAMPED",
				"message": "La contrepartie %s est partiellement neutralisée par le runtime." % modifier.stat_id,
			})
	return result


func _spell_beneficiary_breakpoints(
		definition: ItemDefinition, modifier: ItemSpellModifierData
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var applicable: Array[Spell] = []
	for spell in _compatible_spells(definition):
		if modifier.applies_to(spell):
			applicable.append(spell)
	if applicable.is_empty():
		result.append({
			"severity": "FORTE", "code": "EFFECT_WITHOUT_BENEFICIARY",
			"message": "Aucun sort réel des héros compatibles ne satisfait les filtres.",
		})
		return result
	if modifier.range_bonus > 0 and not applicable.any(func(spell): return spell.spell_range > 0):
		result.append({"severity": "ATTENTION", "code": "RANGE_NO_BENEFICIARY", "message": "Le bonus de portée ne possède aucun sort bénéficiaire."})
	if modifier.push_bonus > 0 and not applicable.any(func(spell): return spell.push_distance > 0):
		result.append({"severity": "ATTENTION", "code": "PUSH_NO_BENEFICIARY", "message": "Le bonus de poussée ne possède aucun sort bénéficiaire."})
	if modifier.healing_and_shield_percent > 0.0 \
			and not applicable.any(func(spell): return spell.heal > 0 or spell.shield_grant > 0):
		result.append({"severity": "ATTENTION", "code": "SUPPORT_NO_BENEFICIARY", "message": "Le bonus de soin/bouclier ne possède aucun sort bénéficiaire."})
	return result


func _compatible_spells(definition: ItemDefinition) -> Array[Spell]:
	var result: Array[Spell] = []
	for path in PRODUCTION_HERO_PATHS:
		var unit_data := load(path) as UnitData
		if unit_data == null or not definition.is_compatible_with(unit_data.get_effective_unit_id()):
			continue
		for spell in unit_data.spells:
			if spell != null and spell not in result:
				result.append(spell)
	return result


func _ehp_projection(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"physical": _ehp_pair(before, after, "armure"),
		"magical": _ehp_pair(before, after, "resist_magique"),
		"status": "ESTIMATION",
	}


func _ehp_pair(before: Dictionary, after: Dictionary, defense_key: String) -> Dictionary:
	var base := _ehp(float(before.get("max_hp", 0.0)), float(before.get(defense_key, 0.0)))
	var equipped := _ehp(float(after.get("max_hp", 0.0)), float(after.get(defense_key, 0.0)))
	return {
		"base": base,
		"after": equipped,
		"delta": equipped - base,
		"delta_percent": (equipped / base - 1.0) if base > 0.0 else 0.0,
	}


func _ehp(hit_points: float, defense: float) -> float:
	var remaining_damage := 1.0 - DamageResolver.mitigation(defense)
	return hit_points / remaining_damage if remaining_damage > 0.0 else INF


func _exploratory_budget(definition: ItemDefinition) -> float:
	var score := 0.0
	for modifier in definition.stat_modifiers:
		if modifier != null:
			score += absf(modifier.value) * (100.0 if modifier.modifier_type == ItemStatModifierData.ModifierType.PERCENT else 1.0)
	for modifier in definition.spell_modifiers:
		if modifier is ItemSpellModifierData:
			var item_modifier := modifier as ItemSpellModifierData
			score += item_modifier.damage_percent * 100.0 + item_modifier.healing_and_shield_percent * 100.0
			score += float(item_modifier.range_bonus * 20 + item_modifier.push_bonus * 10)
	return score
