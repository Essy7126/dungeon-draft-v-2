class_name RelicEffectRegistry
extends RefCounted

const KIND_TRIGGER: StringName = &"trigger"
const KIND_CONDITION: StringName = &"condition"
const KIND_TARGET: StringName = &"target"
const KIND_RESULT: StringName = &"result"
const KIND_FREQUENCY: StringName = &"frequency"
const KIND_REACTION_GROUP: StringName = &"reaction_group"

const EXECUTION_RUNTIME: StringName = &"runtime"
const EXECUTION_INTENT: StringName = &"intent"

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
	KIND_RESULT: {}, KIND_FREQUENCY: {}, KIND_REACTION_GROUP: {},
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
	if effect.reaction_group != &"" \
			and descriptor(KIND_REACTION_GROUP, effect.reaction_group).is_empty():
		errors.append({
			"code": &"REACTION_GROUP_UNKNOWN",
			"field": &"reaction_group",
			"message": "Le groupe de réaction '%s' n'est pas enregistré." % effect.reaction_group,
		})
	var result_descriptor := descriptor(KIND_RESULT, effect.result_id)
	var required_group := StringName(result_descriptor.get("reaction_group", &""))
	if required_group != &"" and effect.reaction_group != required_group:
		errors.append({
			"code": &"REACTION_GROUP_REQUIRED",
			"field": &"reaction_group",
			"message": "Le résultat exige le groupe de réaction '%s'." % required_group,
		})
	var group_policy := reaction_group_policy(effect.reaction_group)
	if bool(group_policy.get("exclusive", false)) and effect.stackable:
		errors.append({
			"code": &"REACTION_GROUP_MUST_NOT_STACK",
			"field": &"stackable",
			"message": "Ce groupe de réaction est exclusif et doit être non stackable.",
		})
	errors.append_array(_validate_parameters(effect, result_descriptor))
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
	return "trigger=%s target=%s result=%s value=%s threshold=%s frequency=%s max=%d recharge=%d group=%s stackable=%s priority=%d" % [
		effect.trigger_id, effect.target_id, effect.result_id, effect.value,
		effect.threshold, effect.frequency_id, effect.max_activations,
		effect.recharge_turns, effect.reaction_group, effect.stackable,
		effect.priority,
	]


func parameter_values(effect: ItemReactiveEffectData) -> Dictionary:
	var values := {}
	if effect == null:
		return values
	for parameter in effect.parameters:
		if parameter != null:
			values[parameter.parameter_id] = parameter.resolved_value()
	return values


func build_tactical_intent(
		effect: ItemReactiveEffectData,
		source: Dictionary = {}
	) -> Dictionary:
	if effect == null:
		return {}
	var result_descriptor := descriptor(KIND_RESULT, effect.result_id)
	if StringName(result_descriptor.get("execution", EXECUTION_RUNTIME)) \
			!= EXECUTION_INTENT:
		return {}
	var intent := {
		"intent_id": StringName(result_descriptor.get("intent_id", effect.result_id)),
		"result_id": effect.result_id,
		"trigger_id": effect.trigger_id,
		"reaction_group": effect.reaction_group,
		"stackable": effect.stackable,
		"priority": effect.priority,
		"parameters": parameter_values(effect),
	}
	intent.merge(source, true)
	return intent


func reaction_group_policy(group_id: StringName) -> Dictionary:
	if group_id == &"":
		return {}
	return descriptor(KIND_REACTION_GROUP, group_id)


## Arbitre commun aux reliques et aux futures réactions de maîtrise. Les
## candidats ne contiennent que des données de politique ; aucun item_id n'est
## interprété. La priorité décroissante gagne, puis l'ordre persistant tranche.
func resolve_reaction_candidates(candidates: Array[Dictionary]) -> Dictionary:
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_effect := left.get("effect") as ItemReactiveEffectData
		var right_effect := right.get("effect") as ItemReactiveEffectData
		var left_priority := left_effect.priority if left_effect != null else int(left.get("priority", 0))
		var right_priority := right_effect.priority if right_effect != null else int(right.get("priority", 0))
		if left_priority != right_priority:
			return left_priority > right_priority
		var left_order := int(left.get("persistent_order", 0))
		var right_order := int(right.get("persistent_order", 0))
		if left_order != right_order:
			return left_order < right_order
		return str(left.get("stable_id", "")) < str(right.get("stable_id", ""))
	)
	var selected: Array[Dictionary] = []
	var suppressed: Array[Dictionary] = []
	var claimed_groups := {}
	for candidate in ordered:
		var effect := candidate.get("effect") as ItemReactiveEffectData
		var group := effect.reaction_group if effect != null \
			else StringName(candidate.get("reaction_group", &""))
		var stackable := effect.stackable if effect != null \
			else bool(candidate.get("stackable", true))
		var policy := reaction_group_policy(group)
		var exclusive := bool(policy.get("exclusive", false)) or not stackable
		if group != &"" and exclusive and claimed_groups.has(group):
			var rejected: Dictionary = candidate.duplicate(false)
			rejected["suppression_reason"] = &"reaction_group_conflict"
			rejected["winner_stable_id"] = claimed_groups[group]
			suppressed.append(rejected)
			continue
		selected.append(candidate)
		if group != &"" and exclusive:
			claimed_groups[group] = candidate.get("stable_id", &"")
	return {"selected": selected, "suppressed": suppressed}


func _validate_parameters(
		effect: ItemReactiveEffectData,
		result_descriptor: Dictionary
	) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	if effect == null:
		return errors
	var schemas := {}
	for schema_value in result_descriptor.get("parameters", []) as Array:
		var schema := schema_value as Dictionary
		var parameter_id := StringName(schema.get("id", &""))
		if parameter_id != &"":
			schemas[parameter_id] = schema
	var seen := {}
	for parameter in effect.parameters:
		if parameter == null:
			continue
		seen[parameter.parameter_id] = true
		if not schemas.has(parameter.parameter_id):
			errors.append({
				"code": &"REACTIVE_PARAMETER_UNKNOWN",
				"field": &"parameters",
				"message": "Le paramètre '%s' n'est pas déclaré par le résultat." % parameter.parameter_id,
			})
			continue
		var error := parameter.validation_error(schemas[parameter.parameter_id])
		if not error.is_empty():
			errors.append({
				"code": &"REACTIVE_PARAMETER_INVALID",
				"field": &"parameters",
				"message": "Paramètre '%s' : %s" % [parameter.parameter_id, error],
			})
	for parameter_id in schemas:
		var schema := schemas[parameter_id] as Dictionary
		if bool(schema.get("required", false)) and not seen.has(parameter_id):
			errors.append({
				"code": &"REACTIVE_PARAMETER_REQUIRED",
				"field": &"parameters",
				"message": "Le paramètre '%s' est obligatoire." % parameter_id,
			})
	return errors


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
		[ItemReactiveEffectData.TRIGGER_SHIELD_ABSORPTION, "La Garde absorbe des dégâts", [&"trigger_hero", &"event_target", &"damage_source", &"shield_absorption", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_HIT_RESOLVED, "Un impact est entièrement résolu", [&"trigger_hero", &"event_target", &"damage_source", &"full_absorption", &"projectile", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_COLLISION_IMPACT, "Une collision provoquée est résolue", [&"trigger_hero", &"active_unit", &"event_target", &"collision", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_SPELL_CAST, "Une technique est résolue", [&"trigger_hero", &"active_unit", &"spell", &"resources"]],
		[ItemReactiveEffectData.TRIGGER_LETHAL_HIT, "Un coup devrait être mortel", [&"trigger_hero", &"damage_source", &"lethal", &"resources"]],
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
		[&"minimum_hp_loss_ratio", "Perte minimale en pourcentage des PV max", [&"hp_loss", &"resources"]],
		[&"fully_absorbed", "L'impact est entièrement absorbé par la Garde", [&"full_absorption"]],
		[&"projectile", "L'impact provient d'un projectile", [&"projectile"]],
		[&"ability_id", "La technique possède l'identifiant demandé", [&"spell"]],
		[&"guard_active", "Une Garde est encore active", [&"resources"]],
		[&"first_in_frequency", "Seulement au tout premier déclenchement", []],
	]:
		register_descriptor(KIND_CONDITION, {"id": value[0], "label": value[1], "requires": value[2]})
	for value in [
		[ItemReactiveEffectData.TARGET_TRIGGER_HERO, "Le héros concerné", [&"trigger_hero"]],
		[ItemReactiveEffectData.TARGET_DAMAGE_SOURCE, "L’ennemi qui a attaqué", [&"damage_source"]],
		[ItemReactiveEffectData.TARGET_KILLED_UNIT, "L’ennemi éliminé", [&"killed_unit"]],
		[ItemReactiveEffectData.TARGET_ACTIVE_UNIT, "Le héros qui joue en ce moment", [&"active_unit"]],
		[ItemReactiveEffectData.TARGET_ALL_CONTROLLED_HEROES, "Toute ton équipe", [&"trigger_hero"]],
		[ItemReactiveEffectData.TARGET_EVENT_TARGET, "La cible de l'événement", [&"event_target"]],
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
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_MARK_VENGEANCE,
		"label": "Émettre la désignation de Vengeance",
		"requires": [&"hp_loss", &"damage_source"],
		"execution": EXECUTION_INTENT,
		"intent_id": &"vengeance_mark",
		"parameters": [
			{"id": &"damage_bonus", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 5.0},
			{"id": &"guard_bonus", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 5.0},
		],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_COLLISION_ARMOR_FOLLOWUP,
		"label": "Émettre la rupture d'armure et la frappe derrière",
		"requires": [&"collision", &"event_target"],
		"execution": EXECUTION_INTENT,
		"intent_id": &"collision_armor_followup",
		"parameters": [
			{"id": &"armor_loss", "type": ItemReactiveParameterData.ValueType.INTEGER, "required": true, "minimum": 0, "maximum": 999},
			{"id": &"followup_ratio", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 5.0},
			{"id": &"behind_cells", "type": ItemReactiveParameterData.ValueType.INTEGER, "required": true, "minimum": 1, "maximum": 10},
			{"id": &"followup_ability_id", "type": ItemReactiveParameterData.ValueType.STRING_NAME, "required": true},
		],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_DASH_NEXT_SHOT,
		"label": "Émettre le prochain Tir après Percée",
		"requires": [&"spell"],
		"execution": EXECUTION_INTENT,
		"intent_id": &"dash_next_shot",
		"parameters": [
			{"id": &"next_ability_id", "type": ItemReactiveParameterData.ValueType.STRING_NAME, "required": true, "non_empty": true},
			{"id": &"ignore_minimum_range", "type": ItemReactiveParameterData.ValueType.BOOLEAN, "required": true},
			{"id": &"damage_bonus", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 5.0},
		],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_REFLECT_ABSORBED_PROJECTILE,
		"label": "Émettre le renvoi du projectile absorbé",
		"requires": [&"full_absorption", &"projectile"],
		"execution": EXECUTION_INTENT,
		"intent_id": &"projectile_counter",
		"reaction_group": &"projectile_counter",
		"parameters": [
			{"id": &"reflect_ratio", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 1.0},
		],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_DUAL_TECHNIQUE,
		"label": "Émettre le bonus de seconde technique",
		"requires": [&"spell"],
		"execution": EXECUTION_INTENT,
		"intent_id": &"dual_technique",
		"parameters": [
			{"id": &"first_ability_id", "type": ItemReactiveParameterData.ValueType.STRING_NAME, "required": true, "non_empty": true},
			{"id": &"second_ability_id", "type": ItemReactiveParameterData.ValueType.STRING_NAME, "required": true, "non_empty": true},
			{"id": &"damage_bonus", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 5.0},
			{"id": &"armor_ignore", "type": ItemReactiveParameterData.ValueType.INTEGER, "required": true, "minimum": 0, "maximum": 999},
		],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_GUARD_DASH_CONVERSION,
		"label": "Émettre la conversion de Garde à l'arrivée de Percée",
		"requires": [&"spell", &"resources"],
		"execution": EXECUTION_INTENT,
		"intent_id": &"guard_dash_conversion",
		"reaction_group": &"guard_dash_conversion",
		"parameters": [
			{"id": &"guard_consume_ratio", "type": ItemReactiveParameterData.ValueType.FLOAT, "required": true, "minimum": 0.0, "maximum": 1.0},
			{"id": &"damage_equals_consumed", "type": ItemReactiveParameterData.ValueType.BOOLEAN, "required": true},
			{"id": &"push_distance", "type": ItemReactiveParameterData.ValueType.INTEGER, "required": true, "minimum": 0, "maximum": 10},
		],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_GRANT_SHIELD_MAX_HP,
		"label": "Accorder une Garde selon les PV maximum",
		"requires": [&"resources"],
		"execution": EXECUTION_RUNTIME,
		"parameters": [],
	})
	register_descriptor(KIND_RESULT, {
		"id": ItemReactiveEffectData.RESULT_LETHAL_REPRIEVE_CONSUME,
		"label": "Survivre, recevoir une Garde et détruire la relique",
		"requires": [&"lethal", &"resources"],
		"execution": EXECUTION_RUNTIME,
		"parameters": [
			{"id": &"remaining_hp", "type": ItemReactiveParameterData.ValueType.INTEGER, "required": true, "minimum": 1, "maximum": 1},
			{"id": &"consume_relic", "type": ItemReactiveParameterData.ValueType.BOOLEAN, "required": true},
		],
	})
	for value in [
		[ItemReactiveEffectData.FREQUENCY_UNLIMITED, "Sans limite"],
		[ItemReactiveEffectData.FREQUENCY_ACTION, "Une fois par action"],
		[ItemReactiveEffectData.FREQUENCY_ACTIVATION, "Une fois par activation du héros"],
		[ItemReactiveEffectData.FREQUENCY_TURN, "Une fois par tour"],
		[ItemReactiveEffectData.FREQUENCY_ROUND, "Une fois par manche"],
		[ItemReactiveEffectData.FREQUENCY_COMBAT, "Une fois par combat"],
		[ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS, "Recharge après plusieurs tours"],
	]:
		register_descriptor(KIND_FREQUENCY, {"id": value[0], "label": value[1]})
	register_descriptor(KIND_REACTION_GROUP, {
		"id": &"projectile_counter",
		"label": "Contre de projectile",
		"exclusive": true,
		"requires_explicit_choice": true,
	})
	register_descriptor(KIND_REACTION_GROUP, {
		"id": &"guard_dash_conversion",
		"label": "Conversion de Garde pendant Percée",
		"exclusive": true,
		"requires_explicit_choice": true,
	})


func result_value_kind(result_id: StringName) -> StringName:
	match result_id:
		ItemReactiveEffectData.RESULT_HEAL_MAX_HP_PERCENT, ItemReactiveEffectData.RESULT_PAY_HP_PERCENT, ItemReactiveEffectData.RESULT_GRANT_SHIELD_MAX_HP, ItemReactiveEffectData.RESULT_LETHAL_REPRIEVE_CONSUME:
			return VALUE_PERCENT
		ItemReactiveEffectData.RESULT_CURRENT_AP, ItemReactiveEffectData.RESULT_NEXT_TURN_AP, ItemReactiveEffectData.RESULT_CURRENT_MP, ItemReactiveEffectData.RESULT_NEXT_TURN_MP:
			return VALUE_SIGNED
		ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS, ItemReactiveEffectData.RESULT_MARK_VENGEANCE, ItemReactiveEffectData.RESULT_COLLISION_ARMOR_FOLLOWUP, ItemReactiveEffectData.RESULT_DASH_NEXT_SHOT, ItemReactiveEffectData.RESULT_REFLECT_ABSORBED_PROJECTILE, ItemReactiveEffectData.RESULT_DUAL_TECHNIQUE, ItemReactiveEffectData.RESULT_GUARD_DASH_CONVERSION:
			return VALUE_NONE
	return VALUE_FLAT


func condition_value_kind(condition_id: StringName) -> StringName:
	match condition_id:
		&"hp_percent", &"minimum_hp_loss_ratio":
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
	if condition.condition_id == &"ability_id":
		return "%s (%s)" % [text, condition.string_name_value]
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
