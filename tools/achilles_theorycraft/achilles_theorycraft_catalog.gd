class_name AchillesTheorycraftCatalog
extends RefCounted

const ODYSSEY_PATH := "res://data/runs/odyssey.tres"
const BASELINE_ID := "ACHILLES_CURRENT_PROTOTYPE_BASELINE"
const SWORD_SHIELD_TEMPLATE_ID := "ACHILLES_SWORD_SHIELD_CONCEPT_TEMPLATE"
const BOW_TEMPLATE_ID := "ACHILLES_BOW_CONCEPT_TEMPLATE"


func create_current_baseline(snapshot_sha: String) -> AchillesTheorycraftBuild:
	var run := load(ODYSSEY_PATH) as RunData
	if run == null:
		return null
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		return null
	var hero: UnitData = null
	var profile: RunHeroProfile = null
	for index in range(resolution.heroes.size()):
		if resolution.heroes[index].get_effective_unit_id() == &"achilles":
			hero = resolution.heroes[index]
			profile = resolution.hero_profiles[index]
			break
	if hero == null or profile == null:
		return null
	var build := AchillesTheorycraftBuild.new()
	build.build_id = BASELINE_ID
	build.display_name = "Prototype actuel (Resources live)"
	build.status = AchillesTheorycraftBuild.STATUS_BASELINE
	build.source_snapshot_sha = snapshot_sha
	build.character_id = "achilles"
	build.ap_budget = hero.max_ap
	build.weapon_family = AchillesTheorycraftBuild.FAMILY_SPEAR_LEGACY
	for spell in hero.spells:
		if spell == null:
			continue
		build.action_slots.append(TheorycraftActionSpec.from_spell(spell))
		build.real_resource_refs.append(spell.resource_path)
	build.design_tags = ["OBSERVED_RUNTIME_BASELINE", "NOT_A_FUTURE_IDENTITY_DECISION"]
	build.author_notes = (
		"Exact live prototype resolved through Odyssey content and progression. "
		+ "It is a technical baseline, not an approved future build."
	)
	for field in ["action_slots", "real_resource_refs", "weapon_family"]:
		build.provenance[field] = AchillesTheorycraftProvenance.observed(
			profile.progression_profile.resource_path
		)
	build.provenance["ap_budget"] = AchillesTheorycraftProvenance.observed(
		"%s#max_ap via RunHeroResolver" % profile.base_unit_data.resource_path
	)
	build.provenance["source_snapshot_sha"] = AchillesTheorycraftProvenance.derived(
		"Link to canonical theorycraft snapshot"
	)
	for field in [
		"weapon_mastery", "universal_tactic", "divine_influence", "relic_or_card",
		"draft_effects", "assumptions",
	]:
		build.provenance[field] = AchillesTheorycraftProvenance.not_measured(
			"The live prototype exposes no approved value for this theorycraft axis."
		)
	for field in [
		"schema_version", "build_id", "display_name", "status", "character_id",
		"design_tags", "author_notes",
	]:
		build.provenance[field] = AchillesTheorycraftProvenance.derived(
			"Isolated baseline descriptor"
		)
	return build


func create_sword_shield_template(snapshot_sha: String) -> AchillesTheorycraftBuild:
	return _concept_template(
		SWORD_SHIELD_TEMPLATE_ID,
		"Concept epee-bouclier (intentions uniquement)",
		AchillesTheorycraftBuild.FAMILY_SWORD_SHIELD_CONCEPT,
		[
			[&"CONTACT_ENTRY_AND_ORIENTATION", ["entree au contact", "orientation"]],
			[&"ACTIVE_PROTECTION", ["blocage", "protection active"]],
			[&"COUNTER_AND_TEMPO", ["contre", "gestion du tempo"]],
			[&"ERROR_RECOVERY", ["recuperation apres erreur"]],
		],
		snapshot_sha,
	)


func create_bow_template(snapshot_sha: String) -> AchillesTheorycraftBuild:
	return _concept_template(
		BOW_TEMPLATE_ID,
		"Concept arc (intentions uniquement)",
		AchillesTheorycraftBuild.FAMILY_BOW_CONCEPT,
		[
			[&"LINE_OF_SIGHT_AND_PRIORITY", ["ligne de vue", "cible prioritaire"]],
			[&"SPATIAL_PREPARATION", ["preparation spatiale"]],
			[&"DISTANCE_AND_REPOSITION", ["maintien de distance", "repositionnement"]],
			[&"PROXIMITY_COUNTERPLAY", ["risque de kite", "contreparties de proximite"]],
		],
		snapshot_sha,
	)


func initial_builds(snapshot_sha: String) -> Array[AchillesTheorycraftBuild]:
	var builds: Array[AchillesTheorycraftBuild] = []
	var baseline := create_current_baseline(snapshot_sha)
	if baseline != null:
		builds.append(baseline)
	builds.append(create_sword_shield_template(snapshot_sha))
	builds.append(create_bow_template(snapshot_sha))
	return builds


func odyssey_contexts() -> Array[TheorycraftContext]:
	var contexts: Array[TheorycraftContext] = []
	var run := load(ODYSSEY_PATH) as RunData
	if run != null:
		for index in range(run.rooms.size()):
			contexts.append(TheorycraftContext.from_room(run.rooms[index], index))
	contexts.append(TheorycraftContext.abstract_context())
	return contexts


func _concept_template(
		build_id: String,
		display_name: String,
		family: String,
		intentions: Array,
		snapshot_sha: String
	) -> AchillesTheorycraftBuild:
	var build := AchillesTheorycraftBuild.new()
	build.build_id = build_id
	build.display_name = display_name
	build.status = AchillesTheorycraftBuild.STATUS_DRAFT
	build.source_snapshot_sha = snapshot_sha
	build.character_id = "achilles"
	var runtime_ap := _achilles_runtime_ap_budget()
	build.ap_budget = runtime_ap.get("value")
	build.weapon_family = family
	for intention in intentions:
		build.action_slots.append(TheorycraftActionSpec.draft_concept(
			intention[0], intention[1]
		))
	build.design_tags = ["DESIGN_CONCEPT_ONLY", "NOT_RUNTIME_LOADABLE"]
	build.author_notes = (
		"Owner-editable design intentions. No final balance value, runtime ability, "
		+ "visual equipment or production asset is defined."
	)
	for field in [
		"weapon_family", "action_slots", "weapon_mastery", "universal_tactic",
		"divine_influence", "relic_or_card", "draft_effects", "assumptions",
		"design_tags", "author_notes",
	]:
		build.provenance[field] = AchillesTheorycraftProvenance.draft()
	build.provenance["source_snapshot_sha"] = AchillesTheorycraftProvenance.derived(
		"Link to snapshot used when opening template"
	)
	build.provenance["ap_budget"] = runtime_ap.get(
		"provenance",
		AchillesTheorycraftProvenance.not_measured("Odyssey Achilles max_ap could not be resolved"),
	)
	build.provenance["assumptions"] = AchillesTheorycraftProvenance.not_measured(
		"No owner-entered assumptions in the untouched concept template."
	)
	build.provenance["real_resource_refs"] = AchillesTheorycraftProvenance.derived(
		"Isolation invariant: concept templates contain no live Resource references."
	)
	for field in ["schema_version", "build_id", "display_name", "status", "character_id"]:
		build.provenance[field] = AchillesTheorycraftProvenance.derived(
			"Isolated concept-template descriptor"
		)
	return build


func _achilles_runtime_ap_budget() -> Dictionary:
	var run := load(ODYSSEY_PATH) as RunData
	if run == null:
		return {
			"value": null,
			"provenance": AchillesTheorycraftProvenance.not_measured(
				"Odyssey RunData could not be loaded."
			),
		}
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		return {
			"value": null,
			"provenance": AchillesTheorycraftProvenance.not_measured(
				"Odyssey hero resolution failed."
			),
		}
	for index in range(resolution.heroes.size()):
		var hero: UnitData = resolution.heroes[index]
		if hero.get_effective_unit_id() != &"achilles":
			continue
		var profile: RunHeroProfile = resolution.hero_profiles[index]
		return {
			"value": hero.max_ap,
			"provenance": AchillesTheorycraftProvenance.observed(
				"%s#max_ap via RunHeroResolver" % profile.base_unit_data.resource_path
			),
		}
	return {
		"value": null,
		"provenance": AchillesTheorycraftProvenance.not_measured(
			"Achilles was not present in the resolved Odyssey hero roster."
		),
	}
