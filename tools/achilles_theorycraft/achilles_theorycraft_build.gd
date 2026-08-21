class_name AchillesTheorycraftBuild
extends RefCounted

const STATUS_BASELINE := "BASELINE"
const STATUS_DRAFT := "DRAFT"
const STATUS_PROPOSED := "PROPOSED"
const STATUS_APPROVED_FOR_FUTURE_TEST := "APPROVED_FOR_FUTURE_TEST"
const ALLOWED_STATUSES := [
	STATUS_BASELINE,
	STATUS_DRAFT,
	STATUS_PROPOSED,
	STATUS_APPROVED_FOR_FUTURE_TEST,
]

const FAMILY_NONE := "NONE"
const FAMILY_SPEAR_LEGACY := "SPEAR_LEGACY"
const FAMILY_SWORD_SHIELD_CONCEPT := "SWORD_SHIELD_CONCEPT"
const FAMILY_BOW_CONCEPT := "BOW_CONCEPT"
const ALLOWED_FAMILIES := [
	FAMILY_NONE,
	FAMILY_SPEAR_LEGACY,
	FAMILY_SWORD_SHIELD_CONCEPT,
	FAMILY_BOW_CONCEPT,
]

var schema_version := 1
var build_id := ""
var display_name := ""
var status := STATUS_DRAFT
var source_snapshot_sha := ""
var character_id := "achilles"
var ap_budget: Variant = null
var weapon_family := FAMILY_NONE
var action_slots: Array[TheorycraftActionSpec] = []
var weapon_mastery: Variant = null
var universal_tactic: Variant = null
var divine_influence: Variant = null
var relic_or_card: Variant = null
var real_resource_refs: Array[String] = []
var draft_effects: Array = []
var assumptions: Array = []
var design_tags: Array[String] = []
var author_notes := ""
var provenance := {}


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != 1:
		errors.append("Unsupported theorycraft build schema.")
	if build_id.strip_edges().is_empty():
		errors.append("build_id is required.")
	if status not in ALLOWED_STATUSES:
		errors.append("Unsupported build status: %s" % status)
	if weapon_family not in ALLOWED_FAMILIES:
		errors.append("Unsupported concept family: %s" % weapon_family)
	if character_id != "achilles":
		errors.append("This isolated lab only accepts character_id=achilles.")
	if ap_budget != null and int(ap_budget) <= 0:
		errors.append("ap_budget must be positive when measured.")
	if action_slots.size() > 4:
		errors.append("Achilles keeps four active action slots.")
	if status == STATUS_BASELINE:
		if ap_budget == null:
			errors.append("Baseline AP budget must be resolved from live Achilles data.")
		for action in action_slots:
			if not action.is_runtime_backed():
				errors.append("Baseline action is not backed by a live Resource: %s" % action.semantic_id)
	return errors


func is_runtime_loadable() -> bool:
	# The lab is deliberately one-way: even its runtime-backed baseline is only
	# an observed comparison input and can never be activated by game code.
	return false


func is_runtime_backed() -> bool:
	return status == STATUS_BASELINE \
		and not action_slots.is_empty() \
		and action_slots.all(func(action): return action.is_runtime_backed())


func to_dict() -> Dictionary:
	var actions: Array = []
	for action in action_slots:
		actions.append(action.to_dict())
	var output_provenance := provenance.duplicate(true)
	output_provenance["runtime_backed"] = AchillesTheorycraftProvenance.derived(
		"True only when the BASELINE action slots all reference live Spell Resources."
	)
	output_provenance["runtime_loadable"] = AchillesTheorycraftProvenance.derived(
		"Isolation invariant: no lab build is runtime-loadable."
	)
	output_provenance["active_in_game"] = AchillesTheorycraftProvenance.derived(
		"Isolation invariant: a lab build never activates gameplay state."
	)
	for field in [
		"schema_version", "build_id", "display_name", "status",
		"source_snapshot_sha", "character_id", "ap_budget", "weapon_family",
		"action_slots", "weapon_mastery", "universal_tactic", "divine_influence",
		"relic_or_card", "real_resource_refs", "draft_effects", "assumptions",
		"design_tags", "author_notes",
	]:
		if not output_provenance.has(field) \
				or not output_provenance[field] is Dictionary \
				or not AchillesTheorycraftProvenance.is_valid(output_provenance[field]):
			output_provenance[field] = AchillesTheorycraftProvenance.not_measured(
				"No valid provenance record was supplied for this build field."
			)
	return {
		"schema_version": schema_version,
		"build_id": build_id,
		"display_name": display_name,
		"status": status,
		"source_snapshot_sha": source_snapshot_sha,
		"character_id": character_id,
		"ap_budget": ap_budget,
		"runtime_backed": is_runtime_backed(),
		"runtime_loadable": false,
		"active_in_game": false,
		"weapon_family": weapon_family,
		"action_slots": actions,
		"weapon_mastery": weapon_mastery,
		"universal_tactic": universal_tactic,
		"divine_influence": divine_influence,
		"relic_or_card": relic_or_card,
		"real_resource_refs": real_resource_refs.duplicate(),
		"draft_effects": draft_effects.duplicate(true),
		"assumptions": assumptions.duplicate(true),
		"design_tags": design_tags.duplicate(),
		"author_notes": author_notes,
		"provenance": output_provenance,
	}


static func from_dict(data: Dictionary) -> AchillesTheorycraftBuild:
	var build := AchillesTheorycraftBuild.new()
	build.schema_version = int(data.get("schema_version", 1))
	build.build_id = str(data.get("build_id", ""))
	build.display_name = str(data.get("display_name", ""))
	build.status = str(data.get("status", STATUS_DRAFT))
	build.source_snapshot_sha = str(data.get("source_snapshot_sha", ""))
	build.character_id = str(data.get("character_id", "achilles"))
	build.ap_budget = data.get("ap_budget")
	build.weapon_family = str(data.get("weapon_family", FAMILY_NONE))
	for entry in data.get("action_slots", []):
		if entry is Dictionary:
			build.action_slots.append(TheorycraftActionSpec.from_dict(entry))
	for field in [
		"weapon_mastery", "universal_tactic", "divine_influence",
		"relic_or_card", "draft_effects", "assumptions", "author_notes",
		"provenance",
	]:
		build.set(field, data.get(field, build.get(field)))
	for value in data.get("real_resource_refs", []):
		build.real_resource_refs.append(str(value))
	for value in data.get("design_tags", []):
		build.design_tags.append(str(value))
	return build


func mark_owner_editable_fields_as_draft() -> void:
	for field in [
		"weapon_mastery", "universal_tactic", "divine_influence",
		"relic_or_card", "draft_effects", "author_notes",
	]:
		provenance[field] = AchillesTheorycraftProvenance.draft(
			"Edited in Achilles Theorycraft Lab"
		)
	provenance["assumptions"] = AchillesTheorycraftProvenance.assumption(
		"Owner-entered theorycraft assumptions; the containing build remains DRAFT_DESIGN_INPUT"
	)
	for action in action_slots:
		if action.is_runtime_backed():
			continue
		for field in [
			"semantic_id", "conditions", "effect_notes", "ap_cost", "range",
			"area", "mobility", "defense", "control", "recovery", "frequency",
		]:
			var value: Variant = action.get(field)
			if value is Dictionary and value.get("value") == null \
					and value.get("provenance", {}).get("kind", "") \
					== AchillesTheorycraftProvenance.NOT_MEASURED:
				continue
			action.provenance[field] = AchillesTheorycraftProvenance.draft(
				"Edited in Achilles Theorycraft Lab"
			)
