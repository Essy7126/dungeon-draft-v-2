@tool
class_name RunContentIsolationAuditService
extends RefCounted


static func compare_runs(first: RunData, second: RunData) -> Dictionary:
	var report := {
		"first_run_path": first.resource_path if first != null else "",
		"second_run_path": second.resource_path if second != null else "",
		"shared_base_unit_data": [],
		"shared_visual_assets": [],
		"shared_progression": [],
		"progression_shared_count": 0,
		"fingerprints": {},
		"conflicts": PackedStringArray(),
		"verdict": "INVALID",
	}
	if first == null or second == null:
		report.conflicts.append("Une RunData est absente.")
		return report
	if first.content_profile == null or second.content_profile == null:
		report.conflicts.append("Une RunData ne possede aucun content_profile.")
		return report

	var first_resources := _progression_index(first.content_profile)
	var second_resources := _progression_index(second.content_profile)
	for key in first_resources:
		if second_resources.has(key):
			report.shared_progression.append(key)
			report.conflicts.append("Progression partagee interdite : %s" % key)
	report.progression_shared_count = report.shared_progression.size()

	var second_bases := {}
	for hero in second.content_profile.hero_profiles:
		if hero != null and hero.base_unit_data != null:
			second_bases[_identity_key(hero.base_unit_data)] = true
	for hero in first.content_profile.hero_profiles:
		if hero != null and hero.base_unit_data != null \
				and second_bases.has(_identity_key(hero.base_unit_data)):
			report.shared_base_unit_data.append(_identity_key(hero.base_unit_data))

	var first_assets := _asset_index(first.content_profile)
	var second_assets := _asset_index(second.content_profile)
	for key in first_assets:
		if second_assets.has(key):
			report.shared_visual_assets.append(key)
	report.shared_base_unit_data.sort()
	report.shared_visual_assets.sort()
	report.shared_progression.sort()

	for content in [first.content_profile, second.content_profile]:
		for hero in content.hero_profiles:
			if hero == null or hero.progression_profile == null:
				continue
			report.fingerprints["%s/%s" % [content.profile_id, hero.character_id]] = (
				RunProgressionCloneService.semantic_fingerprint(hero.progression_profile)
			)
	report.verdict = "VALID" if report.conflicts.is_empty() else "INVALID"
	return report


static func deterministic_manifest(run_data: RunData) -> Dictionary:
	var manifest := {
		"run_path": run_data.resource_path if run_data != null else "",
		"content_profile_path": "",
		"heroes": [],
		"verdict": "INVALID",
	}
	if run_data == null or run_data.content_profile == null:
		return manifest
	manifest.content_profile_path = run_data.content_profile.resource_path
	for hero in run_data.content_profile.hero_profiles:
		if hero == null or hero.progression_profile == null:
			continue
		var resources: Array[Dictionary] = []
		for resource in RunProgressionCloneService.progression_resources(hero.progression_profile):
			resources.append({
				"type": RunProgressionCloneService.resource_type_name(resource),
				"path": resource.resource_path,
			})
		resources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.path) < str(b.path)
		)
		manifest.heroes.append({
			"character_id": str(hero.character_id),
			"base_unit_data_path": hero.base_unit_data.resource_path,
			"progression_profile_path": hero.progression_profile.resource_path,
			"fingerprint": RunProgressionCloneService.semantic_fingerprint(hero.progression_profile),
			"progression_resources": resources,
		})
	manifest.verdict = "VALID"
	return manifest


static func _progression_index(content: RunContentProfile) -> Dictionary:
	var index := {}
	for hero in content.hero_profiles:
		if hero == null or hero.progression_profile == null:
			continue
		for resource in RunProgressionCloneService.progression_resources(hero.progression_profile):
			index[_identity_key(resource)] = resource
	return index


static func _asset_index(content: RunContentProfile) -> Dictionary:
	var index := {}
	for hero in content.hero_profiles:
		if hero == null or hero.progression_profile == null:
			continue
		for resource in RunProgressionCloneService.shared_assets(hero.progression_profile):
			index[_identity_key(resource)] = resource
	return index


static func _identity_key(resource: Resource) -> String:
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return "instance://%d" % resource.get_instance_id()
