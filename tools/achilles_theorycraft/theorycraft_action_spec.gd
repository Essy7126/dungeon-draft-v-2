class_name TheorycraftActionSpec
extends RefCounted

const DRAFT_RUNTIME := "RUNTIME_RESOURCE"
const DRAFT_CONCEPT := "DRAFT_DESIGN_INPUT"
const ALLOWED_LIVE_SPELL_ROOT := "res://data/spells/achilles/"

var semantic_id: StringName = &""
var real_spell_resource := ""
var draft_status := DRAFT_CONCEPT
var ap_cost: Variant = null
var range: Variant = null
var area: Variant = null
var mobility: Variant = null
var defense: Variant = null
var control: Variant = null
var recovery: Variant = null
var frequency: Variant = null
var conditions: Variant = null
var effect_notes := ""
var provenance := {}


static func from_spell(spell: Spell) -> TheorycraftActionSpec:
	var spec := TheorycraftActionSpec.new()
	if spell == null:
		return spec
	var source := spell.resource_path
	spec.semantic_id = spell.get_effective_spell_id()
	spec.real_spell_resource = source
	spec.draft_status = DRAFT_RUNTIME
	spec.ap_cost = spell.ap_cost
	spec.range = {
		"minimum": spell.minimum_range,
		"maximum": spell.spell_range,
		"needs_line_of_sight": spell.needs_line_of_sight,
	}
	spec.area = {
		"shape": Spell.AoeShape.keys()[spell.aoe_shape],
		"size": spell.aoe_size,
		"line_from_caster": spell.line_from_caster,
		"exclude_caster": spell.exclude_caster_from_area_effects,
	}
	var movement := _read_mobility(spell)
	spec.mobility = movement.value
	spec.defense = {
		"shield": spell.shield_grant,
		"heal": spell.heal,
	}
	spec.control = {
		"push_distance": spell.push_distance,
		"pull_distance": spell.pull_distance,
		"ap_drain": spell.ap_drain,
		"forces_taunt": spell.forces_taunt,
	}
	spec.recovery = AchillesTheorycraftProvenance.not_measured_value(
		"Recovery depends on position, map and post-action state."
	)
	spec.frequency = {
		"once_per_activation": spell.once_per_activation,
		"max_uses_per_combat": spell.max_uses_per_combat,
		"cooldown_activations": spell.cooldown_activations,
		"initial_cooldown": spell.initial_cooldown,
	}
	spec.conditions = {
		"can_target_enemy": spell.can_target_enemy,
		"can_target_ally": spell.can_target_ally,
		"can_target_free_cell": spell.can_target_free_cell,
		"can_target_self": spell.can_target_self,
	}
	spec.effect_notes = spell.description
	for field in [
		"semantic_id", "real_spell_resource", "ap_cost", "range", "area",
		"defense", "control", "frequency", "conditions", "effect_notes",
	]:
		spec.provenance[field] = AchillesTheorycraftProvenance.observed(
			"%s#%s" % [source, field]
		)
	spec.provenance["mobility"] = movement.provenance
	spec.provenance["recovery"] = (spec.recovery as Dictionary).provenance
	spec.provenance["draft_status"] = AchillesTheorycraftProvenance.derived(
		"RUNTIME_RESOURCE classification follows a successfully loaded live Spell Resource",
		[source],
	)
	return spec


static func draft_concept(id: StringName, intentions: Array) -> TheorycraftActionSpec:
	var spec := TheorycraftActionSpec.new()
	spec.semantic_id = id
	spec.draft_status = DRAFT_CONCEPT
	spec.conditions = intentions.duplicate()
	spec.effect_notes = "DESIGN_CONCEPT_ONLY"
	for field in ["semantic_id", "draft_status", "conditions", "effect_notes"]:
		spec.provenance[field] = AchillesTheorycraftProvenance.draft()
	spec.provenance["real_spell_resource"] = AchillesTheorycraftProvenance.not_measured(
		"Concept action intentionally has no live Spell Resource reference."
	)
	for field in [
		"ap_cost", "range", "area", "mobility", "defense", "control",
		"recovery", "frequency",
	]:
		spec.set(field, AchillesTheorycraftProvenance.not_measured_value(
			"Concept template intentionally contains no final balance value."
		))
		spec.provenance[field] = AchillesTheorycraftProvenance.not_measured(
			"Concept template intentionally contains no final balance value."
		)
	return spec


func to_dict() -> Dictionary:
	var output_provenance := provenance.duplicate(true)
	for field in [
		"semantic_id", "real_spell_resource", "draft_status", "ap_cost", "range",
		"area", "mobility", "defense", "control", "recovery", "frequency",
		"conditions", "effect_notes",
	]:
		if not output_provenance.has(field) \
				or not output_provenance[field] is Dictionary \
				or not AchillesTheorycraftProvenance.is_valid(output_provenance[field]):
			output_provenance[field] = AchillesTheorycraftProvenance.not_measured(
				"No valid provenance record was supplied for this action field."
			)
	return {
		"semantic_id": str(semantic_id),
		"real_spell_resource": real_spell_resource,
		"draft_status": draft_status,
		"ap_cost": ap_cost,
		"range": range,
		"area": area,
		"mobility": mobility,
		"defense": defense,
		"control": control,
		"recovery": recovery,
		"frequency": frequency,
		"conditions": conditions,
		"effect_notes": effect_notes,
		"provenance": output_provenance,
	}


static func from_dict(data: Dictionary) -> TheorycraftActionSpec:
	var resource_path := str(data.get("real_spell_resource", ""))
	if resource_path.begins_with(ALLOWED_LIVE_SPELL_ROOT) \
			and ResourceLoader.exists(resource_path):
		var live_spell := load(resource_path) as Spell
		if live_spell != null:
			return from_spell(live_spell)
	var spec := TheorycraftActionSpec.new()
	spec.semantic_id = StringName(data.get("semantic_id", ""))
	spec.real_spell_resource = resource_path
	spec.draft_status = str(data.get("draft_status", DRAFT_CONCEPT))
	for field in [
		"ap_cost", "range", "area", "mobility", "defense", "control",
		"recovery", "frequency", "conditions", "effect_notes", "provenance",
	]:
		spec.set(field, data.get(field, spec.get(field)))
	return spec


func is_runtime_backed() -> bool:
	if not real_spell_resource.begins_with(ALLOWED_LIVE_SPELL_ROOT) \
			or not ResourceLoader.exists(real_spell_resource):
		return false
	return load(real_spell_resource) is Spell


func resolved_ap_cost() -> Variant:
	if is_runtime_backed():
		var spell := load(real_spell_resource) as Spell
		return spell.ap_cost if spell != null else null
	if ap_cost is int or ap_cost is float:
		return int(ap_cost)
	return null


static func _read_mobility(spell: Spell) -> Dictionary:
	var movement := {
		"moves_caster_to_target": false,
		"requires_clear_path": false,
	}
	for modifier in spell.modifiers:
		if modifier is SpellModSkillTreeEffect:
			var effect := modifier as SpellModSkillTreeEffect
			if effect.effect_type == SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET:
				movement.moves_caster_to_target = true
				movement.requires_clear_path = effect.movement_requires_clear_path
	return {
		"value": movement,
		"provenance": AchillesTheorycraftProvenance.observed(
			"%s#modifiers" % spell.resource_path
		),
	}
