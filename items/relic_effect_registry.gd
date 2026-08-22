class_name RelicEffectRegistry
extends RefCounted

const KIND_TRIGGER: StringName = &"trigger"
const KIND_CONDITION: StringName = &"condition"
const KIND_TARGET: StringName = &"target"
const KIND_RESULT: StringName = &"result"
const KIND_FREQUENCY: StringName = &"frequency"

const VALUE_FLAT: StringName = &"flat"
const VALUE_PERCENT: StringName = &"percent"
const VALUE_SIGNED: StringName = &"signed"
const VALUE_NONE: StringName = &"none"

const TEAM_LABELS := ["Ton équipe", "Les ennemis"]

const COMPARISONS := [
	["=", &"equal"],
	["<", &"less"],
	["≤", &"less_or_equal"],
	[">", &"greater"],
	["≥", &"greater_or_equal"],
]

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
			result.append(_contextualize_label(kind, candidate, effect))
	return result


func is_manual_trigger_id(trigger_id: StringName) -> bool:
	return trigger_id == ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION


# Le déclenchement manuel n'est pas un « moment » du combat comme les autres :
# il est choisi par un bouton dédié dans l'éditeur, pas dans la liste des
# moments automatiques. On le retire donc de cette liste pour ne pas proposer
# deux chemins différents vers le même réglage.
func automatic_trigger_descriptors(
		effect: ItemReactiveEffectData
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in compatible_descriptors(KIND_TRIGGER, effect):
		if not is_manual_trigger_id(StringName(candidate.get("id", &""))):
			result.append(candidate)
	return result


# Certains descripteurs partagent un même id technique ('active_unit') mais
# désignent une unité différente selon le déclencheur : sur
# adjacent_enemy_turn_end, active_unit est l'ennemi qui vient de terminer son
# tour, pas le héros. On adapte le libellé affiché pour rester compréhensible
# sans connaissance technique, sans changer l'id stocké dans la ressource.
func _contextualize_label(
		kind: StringName,
		candidate: Dictionary,
		effect: ItemReactiveEffectData
	) -> Dictionary:
	if effect != null:
		candidate["label"] = label(kind, StringName(candidate.get("id", &"")), effect.trigger_id)
	return candidate


func validate_effect(effect: ItemReactiveEffectData) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	if effect == null:
		return [{
			"code": &"REACTIVE_EFFECT_NULL",
			"field": &"",
			"message": "Le bloc d’effet est nul.",
		}]
	for pair in [
		[KIND_TRIGGER, effect.trigger_id], [KIND_TARGET, effect.target_id],
		[KIND_RESULT, effect.result_id], [KIND_FREQUENCY, effect.frequency_id],
	]:
		if descriptor(pair[0], pair[1]).is_empty():
			errors.append({
				"code": &"REACTIVE_DESCRIPTOR_UNKNOWN",
				"field": pair[0],
				"message": "Le descripteur %s '%s' n’est pas enregistré." % [pair[0], pair[1]],
			})
	for condition_index in range(effect.conditions.size()):
		var condition := effect.conditions[condition_index]
		if condition == null or descriptor(KIND_CONDITION, condition.condition_id).is_empty():
			errors.append({
				"code": &"REACTIVE_CONDITION_UNKNOWN",
				"field": KIND_CONDITION,
				"condition_index": condition_index,
				"message": "Une condition n’est pas enregistrée.",
			})
		elif not _is_descriptor_compatible(
				KIND_CONDITION, descriptor(KIND_CONDITION, condition.condition_id), effect
			):
			errors.append({
				"code": &"REACTIVE_CONDITION_INCOMPATIBLE",
				"field": KIND_CONDITION,
				"condition_index": condition_index,
				"message": "La condition '%s' n’est pas produite par ce déclencheur." % label(KIND_CONDITION, condition.condition_id),
			})
	if not descriptor(KIND_TARGET, effect.target_id).is_empty() \
			and not _is_descriptor_compatible(
				KIND_TARGET, descriptor(KIND_TARGET, effect.target_id), effect
			):
		errors.append({
			"code": &"REACTIVE_TARGET_INCOMPATIBLE",
			"field": KIND_TARGET,
			"message": "La cible '%s' n’existe pas dans le contexte de ce déclencheur." % label(KIND_TARGET, effect.target_id),
		})
	if not descriptor(KIND_RESULT, effect.result_id).is_empty() \
			and not _is_descriptor_compatible(
				KIND_RESULT, descriptor(KIND_RESULT, effect.result_id), effect
			):
		errors.append({
			"code": &"REACTIVE_RESULT_INCOMPATIBLE",
			"field": KIND_RESULT,
			"message": "Le résultat '%s' ne peut pas intercepter ce déclencheur." % label(KIND_RESULT, effect.result_id),
		})
	if not effect.is_structurally_valid():
		errors.append({
			"code": &"REACTIVE_STRUCTURE_INVALID",
			"field": &"",
			"message": "Valeur, seuil ou fréquence invalide.",
		})
	return errors


func label(kind: StringName, descriptor_id: StringName, trigger_id: StringName = &"") -> String:
	var candidate := descriptor(kind, descriptor_id)
	if kind == KIND_TARGET and descriptor_id == ItemReactiveEffectData.TARGET_ACTIVE_UNIT \
			and trigger_id == ItemReactiveEffectData.TRIGGER_ADJACENT_ENEMY_TURN_END:
		return "L’ennemi concerné"
	return str(candidate.get("label", descriptor_id))


func summarize(effect: ItemReactiveEffectData) -> String:
	if effect == null:
		return "Effet réactif invalide"
	var sentence := "%s → %s → %s" % [
		_trigger_text(effect), _result_text(effect),
		label(KIND_TARGET, effect.target_id, effect.trigger_id),
	]
	var conditions_text := _conditions_text(effect)
	if not conditions_text.is_empty():
		sentence += " · Seulement si : %s" % conditions_text
	return "%s · %s" % [sentence, _frequency_text(effect)]


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
		[ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, "Une action vient de se terminer", [&"trigger_hero", &"active_unit", &"action", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_AP_AFTER_ACTION, "PA gagnés ou perdus après une action", [&"trigger_hero", &"active_unit", &"action", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, "Avant un déplacement libre (pas une poussée)", [&"trigger_hero", &"active_unit", &"action", &"voluntary", &"distance", &"interceptable", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_RESOLVED, "Après un déplacement libre (pas une poussée)", [&"trigger_hero", &"active_unit", &"action", &"voluntary", &"distance", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_HP_LOST, "Vie perdue après tes protections", [&"trigger_hero", &"damage_source", &"hp_loss", &"enemy_source", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED, "Ta vie passe sous un certain niveau", [&"trigger_hero", &"damage_source", &"hp_loss", &"enemy_source", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_UNIT_KILLED, "Tu élimines un ennemi", [&"trigger_hero", &"killed_unit", &"kill", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_ADJACENT_ENEMY_TURN_END, "Fin de tour d’un ennemi juste à côté", [&"trigger_hero", &"active_unit", &"adjacent_enemy", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION, "Quand le joueur décide de l’utiliser", [&"trigger_hero", &"active_unit", &"resources"]],
	]:
		register_descriptor(KIND_TRIGGER, {"id": value[0], "label": value[1], "provides": value[2]})
	for value in [
		[&"trigger_team", "Seulement pour une équipe précise", [&"trigger_hero"]],
		[&"enemy_source_required", "L’ennemi doit être à l’origine", [&"enemy_source"]],
		[&"real_hp_loss_positive", "Il y a vraiment eu une perte de vie", [&"hp_loss"]],
		[&"hp_percent", "Selon ton pourcentage de vie", [&"resources"]],
		[&"ap", "Selon le nombre de PA restants", [&"resources"]],
		[&"mp", "Selon le nombre de PM restants", [&"resources"]],
		[&"adjacent_unit", "Un ennemi juste à côté", [&"active_unit"]],
		[&"voluntary_only", "Seulement si c’est un déplacement libre", [&"voluntary"]],
		[&"minimum_distance", "Distance minimale parcourue", [&"distance"]],
		[&"kill_by_hero", "C’est bien toi qui l’as éliminé", [&"kill", &"trigger_hero"]],
		[&"first_in_frequency", "Seulement au tout premier déclenchement", []],
	]:
		register_descriptor(KIND_CONDITION, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.TARGET_TRIGGER_HERO, "Le héros concerné", [&"trigger_hero"]],
		[ItemReactiveEffectData.TARGET_DAMAGE_SOURCE, "L’ennemi qui a attaqué", [&"damage_source"]],
		[ItemReactiveEffectData.TARGET_KILLED_UNIT, "L’ennemi éliminé", [&"killed_unit"]],
		[ItemReactiveEffectData.TARGET_ACTIVE_UNIT, "Le héros qui joue en ce moment", [&"active_unit"]],
		[ItemReactiveEffectData.TARGET_ALL_CONTROLLED_HEROES, "Toute ton équipe", [&"trigger_hero"]],
	]:
		register_descriptor(KIND_TARGET, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.RESULT_CURRENT_AP, "Donner ou enlever des PA ce tour", []],
		[ItemReactiveEffectData.RESULT_NEXT_TURN_AP, "Donner ou enlever des PA au tour suivant", []],
		[ItemReactiveEffectData.RESULT_CURRENT_MP, "Donner ou enlever des PM ce tour", []],
		[ItemReactiveEffectData.RESULT_NEXT_TURN_MP, "Donner ou enlever des PM au tour suivant", []],
		[ItemReactiveEffectData.RESULT_HEAL_FLAT, "Soigner un nombre de PV fixe", []],
		[ItemReactiveEffectData.RESULT_HEAL_MAX_HP_PERCENT, "Soigner un pourcentage de ta vie maximum", []],
		[ItemReactiveEffectData.RESULT_PAY_HP_FLAT, "Perdre un nombre de PV fixe (sans jamais mourir)", []],
		[ItemReactiveEffectData.RESULT_PAY_HP_PERCENT, "Perdre un pourcentage de ta vie (sans jamais mourir)", []],
		[ItemReactiveEffectData.RESULT_REDUCE_VOLUNTARY_MOVE_COST, "Rendre un déplacement libre moins cher", [&"voluntary", &"interceptable"]],
		[ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS, "Bloquer l’action avant qu’elle se produise", [&"interceptable"]],
	]:
		register_descriptor(KIND_RESULT, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.FREQUENCY_UNLIMITED, "Sans limite"],
		[ItemReactiveEffectData.FREQUENCY_ACTION, "Une fois par action"],
		[ItemReactiveEffectData.FREQUENCY_TURN, "Une fois par tour"],
		[ItemReactiveEffectData.FREQUENCY_ROUND, "Une fois par manche"],
		[ItemReactiveEffectData.FREQUENCY_COMBAT, "Une fois par combat"],
		[ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS, "Recharge après plusieurs tours"],
	]:
		register_descriptor(KIND_FREQUENCY, {"id": value[0], "label": value[1]})


func result_value_kind(result_id: StringName) -> StringName:
	match result_id:
		ItemReactiveEffectData.RESULT_HEAL_MAX_HP_PERCENT, ItemReactiveEffectData.RESULT_PAY_HP_PERCENT:
			return VALUE_PERCENT
		ItemReactiveEffectData.RESULT_CURRENT_AP, ItemReactiveEffectData.RESULT_NEXT_TURN_AP, ItemReactiveEffectData.RESULT_CURRENT_MP, ItemReactiveEffectData.RESULT_NEXT_TURN_MP:
			return VALUE_SIGNED
		ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS:
			return VALUE_NONE
	return VALUE_FLAT


func condition_value_kind(condition_id: StringName) -> StringName:
	match condition_id:
		&"hp_percent":
			return VALUE_PERCENT
		&"ap", &"mp", &"minimum_distance":
			return VALUE_FLAT
	return VALUE_NONE


func condition_uses_comparison(condition_id: StringName) -> bool:
	return condition_id in [&"hp_percent", &"ap", &"mp"]


func condition_uses_team(condition_id: StringName) -> bool:
	return condition_id == &"trigger_team"


func team_label(team: int) -> String:
	return str(TEAM_LABELS[clampi(team, 0, TEAM_LABELS.size() - 1)])


func trigger_uses_threshold(trigger_id: StringName) -> bool:
	return trigger_id == ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED


func comparison_symbol(comparison: StringName) -> String:
	for pair in COMPARISONS:
		if StringName(pair[1]) == comparison:
			return str(pair[0])
	return "="


func percent_text(ratio: float) -> String:
	return "%d %%" % int(round(ratio * 100.0))


func _trigger_text(effect: ItemReactiveEffectData) -> String:
	var text := label(KIND_TRIGGER, effect.trigger_id)
	if trigger_uses_threshold(effect.trigger_id):
		return "%s (%s)" % [text, percent_text(effect.threshold)]
	return text


func _result_text(effect: ItemReactiveEffectData) -> String:
	var text := label(KIND_RESULT, effect.result_id)
	match result_value_kind(effect.result_id):
		VALUE_NONE:
			return text
		VALUE_PERCENT:
			return "%s (%s)" % [text, percent_text(effect.value)]
		VALUE_SIGNED:
			return "%s (%+d)" % [text, int(round(effect.value))]
	return "%s (%d)" % [text, int(round(effect.value))]


func _conditions_text(effect: ItemReactiveEffectData) -> String:
	var parts: Array[String] = []
	for condition in effect.conditions:
		if condition != null:
			parts.append(_condition_text(condition))
	return ", ".join(parts)


func _condition_text(condition: ItemReactiveConditionData) -> String:
	var text := label(KIND_CONDITION, condition.condition_id)
	if condition_uses_team(condition.condition_id):
		return "%s (%s)" % [text, team_label(condition.team)]
	var kind := condition_value_kind(condition.condition_id)
	if kind == VALUE_NONE:
		return text
	var value_text := percent_text(condition.value) if kind == VALUE_PERCENT \
		else str(int(round(condition.value)))
	if not condition_uses_comparison(condition.condition_id):
		return "%s (%s)" % [text, value_text]
	return "%s %s %s" % [text, comparison_symbol(condition.comparison), value_text]


func _frequency_text(effect: ItemReactiveEffectData) -> String:
	var text := label(KIND_FREQUENCY, effect.frequency_id)
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_UNLIMITED:
		return text
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS:
		text += " (%d tours)" % effect.recharge_turns
	if effect.max_activations > 1:
		text += ", %d fois maximum" % effect.max_activations
	return text
