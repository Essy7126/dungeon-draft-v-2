class_name RelicEffectRegistry
extends RefCounted

const KIND_TRIGGER: StringName = &"trigger"
const KIND_CONDITION: StringName = &"condition"
const KIND_TARGET: StringName = &"target"
const KIND_RESULT: StringName = &"result"
const KIND_FREQUENCY: StringName = &"frequency"

var _descriptors := {
	KIND_TRIGGER: {}, KIND_CONDITION: {}, KIND_TARGET: {},
	KIND_RESULT: {}, KIND_FREQUENCY: {},
}


func _init() -> void:
	_register_defaults()


func register_descriptor(kind: StringName, data: Dictionary) -> bool:
	if not _descriptors.has(kind):
		return false
	var descriptor := data.duplicate(true)
	var descriptor_id := StringName(descriptor.get("id", &""))
	if descriptor_id == &"" or str(descriptor.get("label", "")).is_empty():
		return false
	if (_descriptors[kind] as Dictionary).has(descriptor_id):
		return false
	descriptor["id"] = descriptor_id
	(_descriptors[kind] as Dictionary)[descriptor_id] = descriptor
	return true


func descriptor(kind: StringName, descriptor_id: StringName) -> Dictionary:
	return (_descriptors.get(kind, {}) as Dictionary).get(descriptor_id, {}) as Dictionary


func descriptors(kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in (_descriptors.get(kind, {}) as Dictionary).values():
		result.append((value as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("label", "")) < str(b.get("label", ""))
	)
	return result


func compatible_descriptors(
		kind: StringName,
		effect: ItemReactiveEffectData
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in descriptors(kind):
		if _is_descriptor_compatible(kind, candidate, effect):
			result.append(candidate)
	return result


func validate_effect(effect: ItemReactiveEffectData) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	if effect == null:
		return [{"code": &"REACTIVE_EFFECT_NULL", "message": "Le bloc d’effet est nul."}]
	for pair in [
		[KIND_TRIGGER, effect.trigger_id], [KIND_TARGET, effect.target_id],
		[KIND_RESULT, effect.result_id], [KIND_FREQUENCY, effect.frequency_id],
	]:
		if descriptor(pair[0], pair[1]).is_empty():
			errors.append({
				"code": &"REACTIVE_DESCRIPTOR_UNKNOWN",
				"message": "Le descripteur %s '%s' n’est pas enregistré." % [pair[0], pair[1]],
			})
	for condition in effect.conditions:
		if condition == null or descriptor(KIND_CONDITION, condition.condition_id).is_empty():
			errors.append({"code": &"REACTIVE_CONDITION_UNKNOWN", "message": "Une condition n’est pas enregistrée."})
		elif not _is_descriptor_compatible(
				KIND_CONDITION, descriptor(KIND_CONDITION, condition.condition_id), effect
			):
			errors.append({
				"code": &"REACTIVE_CONDITION_INCOMPATIBLE",
				"message": "La condition '%s' n’est pas produite par ce déclencheur." % label(KIND_CONDITION, condition.condition_id),
			})
	if not descriptor(KIND_TARGET, effect.target_id).is_empty() \
			and not _is_descriptor_compatible(
				KIND_TARGET, descriptor(KIND_TARGET, effect.target_id), effect
			):
		errors.append({
			"code": &"REACTIVE_TARGET_INCOMPATIBLE",
			"message": "La cible '%s' n’existe pas dans le contexte de ce déclencheur." % label(KIND_TARGET, effect.target_id),
		})
	if not descriptor(KIND_RESULT, effect.result_id).is_empty() \
			and not _is_descriptor_compatible(
				KIND_RESULT, descriptor(KIND_RESULT, effect.result_id), effect
			):
		errors.append({
			"code": &"REACTIVE_RESULT_INCOMPATIBLE",
			"message": "Le résultat '%s' ne peut pas intercepter ce déclencheur." % label(KIND_RESULT, effect.result_id),
		})
	if not effect.is_structurally_valid():
		errors.append({"code": &"REACTIVE_STRUCTURE_INVALID", "message": "Valeur, seuil ou fréquence invalide."})
	return errors


func label(kind: StringName, descriptor_id: StringName) -> String:
	return str(descriptor(kind, descriptor_id).get("label", descriptor_id))


func summarize(effect: ItemReactiveEffectData) -> String:
	if effect == null:
		return "Effet réactif invalide"
	var condition_labels: Array[String] = []
	for condition in effect.conditions:
		if condition != null:
			condition_labels.append(label(KIND_CONDITION, condition.condition_id))
	var conditions_text := "toujours" if condition_labels.is_empty() \
		else "si %s" % ", ".join(condition_labels)
	return "Quand %s, %s, appliquer %s à %s (%s, max. %d)." % [
		label(KIND_TRIGGER, effect.trigger_id).to_lower(), conditions_text,
		label(KIND_RESULT, effect.result_id).to_lower(),
		label(KIND_TARGET, effect.target_id).to_lower(),
		label(KIND_FREQUENCY, effect.frequency_id).to_lower(),
		effect.max_activations,
	]


func technical_summary(effect: ItemReactiveEffectData) -> String:
	if effect == null:
		return "<null>"
	return "trigger=%s target=%s result=%s value=%s threshold=%s frequency=%s max=%d recharge=%d" % [
		effect.trigger_id, effect.target_id, effect.result_id, effect.value,
		effect.threshold, effect.frequency_id, effect.max_activations,
		effect.recharge_turns,
	]


func _is_descriptor_compatible(
		kind: StringName,
		candidate: Dictionary,
		effect: ItemReactiveEffectData
	) -> bool:
	if effect == null or kind == KIND_TRIGGER or kind == KIND_FREQUENCY:
		return true
	var trigger := descriptor(KIND_TRIGGER, effect.trigger_id)
	var provides := trigger.get("provides", []) as Array
	for requirement in candidate.get("requires", []) as Array:
		if requirement not in provides:
			return false
	var trigger_ids := candidate.get("triggers", []) as Array
	return trigger_ids.is_empty() or effect.trigger_id in trigger_ids


func _register_defaults() -> void:
	for value in [
		[ItemReactiveEffectData.TRIGGER_COMBAT_START, "Début du combat", [&"trigger_hero", &"active_unit"]],
		[ItemReactiveEffectData.TRIGGER_TURN_START, "Début du tour", [&"trigger_hero", &"active_unit", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_TURN_END, "Fin du tour", [&"trigger_hero", &"active_unit", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, "Action résolue", [&"trigger_hero", &"active_unit", &"action", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_AP_AFTER_ACTION, "Changement de PA après une action", [&"trigger_hero", &"active_unit", &"action", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, "Préparation d’un déplacement volontaire", [&"trigger_hero", &"active_unit", &"action", &"voluntary", &"distance", &"interceptable", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_RESOLVED, "Résolution d’un déplacement volontaire", [&"trigger_hero", &"active_unit", &"action", &"voluntary", &"distance", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_HP_LOST, "Perte réelle de PV", [&"trigger_hero", &"damage_source", &"hp_loss", &"enemy_source", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED, "Franchissement d’un seuil de PV", [&"trigger_hero", &"damage_source", &"hp_loss", &"enemy_source", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_UNIT_KILLED, "Élimination attribuée à une unité", [&"trigger_hero", &"killed_unit", &"kill", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_ADJACENT_ENEMY_TURN_END, "Fin de tour d’un ennemi adjacent", [&"trigger_hero", &"active_unit", &"adjacent_enemy", &"resources"]],
	]:
		register_descriptor(KIND_TRIGGER, {"id": value[0], "label": value[1], "provides": value[2]})
	for value in [
		[&"trigger_team", "Équipe du déclencheur", [&"trigger_hero"]],
		[&"enemy_source_required", "Source ennemie obligatoire", [&"enemy_source"]],
		[&"real_hp_loss_positive", "Perte réelle de PV supérieure à zéro", [&"hp_loss"]],
		[&"hp_percent", "Pourcentage de PV comparé au seuil", [&"resources"]],
		[&"ap", "PA comparés à une valeur", [&"resources"]],
		[&"mp", "PM comparés à une valeur", [&"resources"]],
		[&"adjacent_unit", "Unité adjacente", [&"active_unit"]],
		[&"voluntary_only", "Déplacement volontaire uniquement", [&"voluntary"]],
		[&"minimum_distance", "Distance minimale parcourue", [&"distance"]],
		[&"kill_by_hero", "Élimination attribuée au héros", [&"kill", &"trigger_hero"]],
		[&"first_in_frequency", "Première activation dans la fréquence", []],
	]:
		register_descriptor(KIND_CONDITION, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.TARGET_TRIGGER_HERO, "Héros déclencheur", [&"trigger_hero"]],
		[ItemReactiveEffectData.TARGET_DAMAGE_SOURCE, "Source ennemie des dégâts", [&"damage_source"]],
		[ItemReactiveEffectData.TARGET_KILLED_UNIT, "Unité éliminée", [&"killed_unit"]],
		[ItemReactiveEffectData.TARGET_ACTIVE_UNIT, "Unité active", [&"active_unit"]],
		[ItemReactiveEffectData.TARGET_ALL_CONTROLLED_HEROES, "Tous les héros contrôlés", [&"trigger_hero"]],
	]:
		register_descriptor(KIND_TARGET, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.RESULT_CURRENT_AP, "Rendre ou retirer des PA ce tour", []],
		[ItemReactiveEffectData.RESULT_NEXT_TURN_AP, "Bonus ou malus de PA au prochain tour", []],
		[ItemReactiveEffectData.RESULT_CURRENT_MP, "Rendre ou retirer des PM ce tour", []],
		[ItemReactiveEffectData.RESULT_NEXT_TURN_MP, "Bonus ou malus de PM au prochain tour", []],
		[ItemReactiveEffectData.RESULT_HEAL_FLAT, "Soigner une valeur fixe", []],
		[ItemReactiveEffectData.RESULT_HEAL_MAX_HP_PERCENT, "Soigner selon les PV maximum", []],
		[ItemReactiveEffectData.RESULT_PAY_HP_FLAT, "Payer un coût fixe en PV sans mourir", []],
		[ItemReactiveEffectData.RESULT_PAY_HP_PERCENT, "Payer un coût proportionnel en PV sans mourir", []],
		[ItemReactiveEffectData.RESULT_REDUCE_VOLUNTARY_MOVE_COST, "Réduire le coût du déplacement volontaire", [&"voluntary", &"interceptable"]],
		[ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS, "Annuler proprement l’effet en cours", [&"interceptable"]],
	]:
		register_descriptor(KIND_RESULT, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.FREQUENCY_UNLIMITED, "Sans limite"],
		[ItemReactiveEffectData.FREQUENCY_ACTION, "Une fois par action"],
		[ItemReactiveEffectData.FREQUENCY_TURN, "Une fois par tour"],
		[ItemReactiveEffectData.FREQUENCY_ROUND, "Une fois par round"],
		[ItemReactiveEffectData.FREQUENCY_COMBAT, "Une fois par combat"],
		[ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS, "Recharge après plusieurs tours"],
	]:
		register_descriptor(KIND_FREQUENCY, {"id": value[0], "label": value[1]})
