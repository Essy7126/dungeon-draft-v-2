class_name ObservatoryExporter
extends RefCounted

const SCHEMA_VERSION := "2.0.0"
const GENERATOR_VERSION := "2.0.0"
const DEFAULT_MANIFEST_PATH := "res://docs/observatory/data_source_manifest.json"
const DEFAULT_CONTRACT_PATH := "res://docs/observatory/design_contract.json"
const FIRST_RUN_PATH := "res://data/runs/first_run.tres"
const ITEM_CATALOG_PATH := "res://data/items/catalogs/default_item_catalog.tres"
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]
const GENERIC_REWARD_PATHS := [
	"res://data/post_combat/rewards/team_heal_percent.tres",
	"res://data/post_combat/rewards/hero_max_hp.tres",
	"res://data/post_combat/rewards/next_combat_shield.tres",
]
const EQUIPMENT_POOL_TAG := "first_run_equipment_reward"


func build_snapshot(
		manifest_path: String = DEFAULT_MANIFEST_PATH,
		contract_path: String = DEFAULT_CONTRACT_PATH
	) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var source_audits: Array[Dictionary] = []
	var manifest := _read_json_object(manifest_path, errors)
	var contract_document := _read_json_object(contract_path, errors)
	if not errors.is_empty():
		return {"snapshot": {}, "errors": errors, "warnings": warnings}

	var run_data := _load_resource(FIRST_RUN_PATH, "RunData", source_audits) as RunData
	var run_graph := ObservatoryRunDataExporter.new().export_graph(run_data, FIRST_RUN_PATH)
	source_audits.append_array(run_graph.get("audits", []) as Array)
	var characters: Array[Dictionary] = []
	var character_resources: Array[UnitData] = []
	for path in HERO_PATHS:
		var character := _load_resource(path, "UnitData", source_audits) as UnitData
		if character != null:
			character_resources.append(character)
			characters.append(ObservatoryResourceExporters.export_character(character))
	characters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	var spell_resources := {}
	var spell_character_ids := {}
	var discipline_resources := {}
	var discipline_character_ids := {}
	for character in character_resources:
		var character_id := str(character.get_effective_unit_id())
		for spell in character.spells:
			if spell == null:
				source_audits.append(_source_reference_audit(
					"spells", "character", character_id, ObservatorySerializer.resource_path(character)
				))
				continue
			var spell_id := str(spell.get_effective_spell_id())
			if not spell_resources.has(spell_id):
				spell_resources[spell_id] = spell
				spell_character_ids[spell_id] = []
			(spell_character_ids[spell_id] as Array).append(character_id)
		for discipline in character.disciplines:
			if discipline == null:
				source_audits.append(_source_reference_audit(
					"disciplines", "character", character_id,
					ObservatorySerializer.resource_path(character)
				))
				continue
			var discipline_id := str(discipline.discipline_id)
			if not discipline_resources.has(discipline_id):
				discipline_resources[discipline_id] = discipline
				discipline_character_ids[discipline_id] = character_id

	var spells: Array[Dictionary] = []
	var spell_ids: Array[String] = []
	for key in spell_resources:
		spell_ids.append(str(key))
	spell_ids.sort()
	for spell_id in spell_ids:
		var owners: Array[String] = []
		for owner_value in spell_character_ids[spell_id] as Array:
			owners.append(str(owner_value))
		owners.sort()
		spells.append(ObservatoryResourceExporters.export_spell(
			spell_resources[spell_id] as Spell,
			owners,
		))

	var disciplines: Array[Dictionary] = []
	var discipline_ids: Array[String] = []
	for key in discipline_resources:
		discipline_ids.append(str(key))
	discipline_ids.sort()
	for discipline_id in discipline_ids:
		disciplines.append(ObservatoryResourceExporters.export_discipline(
			discipline_resources[discipline_id] as DisciplineData,
			str(discipline_character_ids[discipline_id]),
		))

	var item_catalog := _load_resource(
		ITEM_CATALOG_PATH, "ItemCatalog", source_audits
	) as ItemCatalog
	var item_resources: Array[ItemDefinition] = []
	if item_catalog != null:
		var catalog_validation := item_catalog.validate_catalog()
		if not bool(catalog_validation.get("valid", false)):
			source_audits.append(_audit(
				"ITEM.CATALOG_INVALID", "blocking", "items", "catalog", "default",
				"Le catalogue de production ne passe pas sa validation interne.",
				ITEM_CATALOG_PATH, str(catalog_validation.get("errors", [])),
				"Corriger les définitions du catalogue sans modifier l’exporteur.",
			))
		else:
			item_resources = item_catalog.get_definitions()
	item_resources.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool:
		return str(a.item_id) < str(b.item_id)
	)

	var eligible_item_ids: Array[String] = []
	for item in item_resources:
		if item.is_equippable() and EQUIPMENT_POOL_TAG in _string_array(item.tags):
			eligible_item_ids.append(str(item.item_id))
	eligible_item_ids.sort()

	var items: Array[Dictionary] = []
	for item in item_resources:
		var pool_ids: Array[String] = []
		if str(item.item_id) in eligible_item_ids:
			pool_ids.append("first_run_equipment")
		items.append(ObservatoryResourceExporters.export_item(item, pool_ids))

	var generic_rewards: Array[Dictionary] = []
	for path in GENERIC_REWARD_PATHS:
		var reward := _load_resource(path, "PostCombatRewardData", source_audits) \
			as PostCombatRewardData
		if reward != null:
			generic_rewards.append(ObservatoryResourceExporters.export_reward(reward))
	generic_rewards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	var reward_pools: Array[Dictionary] = [
		{
			"id": "generic_post_combat_declared",
			"name": "Récompenses génériques déclarées",
			"kind": "generic_declared",
			"mechanism": "three_static_service_preloads",
			"status": "declared_and_referenced",
			"required_tag": "",
			"minimum_options": 0,
			"item_ids": [],
			"rewards": generic_rewards,
			"source_path": "res://data/post_combat/post_combat_reward_service.gd",
		},
		{
			"id": "first_run_equipment",
			"name": "Équipements de la première run",
			"kind": "equipment_first_run",
			"mechanism": "seeded_deck_without_replacement",
			"status": "eligible_catalog",
			"required_tag": EQUIPMENT_POOL_TAG,
			"minimum_options": 2,
			"item_ids": eligible_item_ids,
			"rewards": [],
			"source_path": "res://data/post_combat/first_run_equipment_reward_service.gd",
		},
	]

	var contract_checks := _build_contract_checks(
		contract_document.get("decisions", []) as Array,
		characters,
		run_data,
		eligible_item_ids,
	)
	var snapshot := {
		"meta": _build_meta(manifest, contract_document),
		"scope": _build_scope(manifest),
		"summary": {},
		"contract": {
			"version": str(contract_document.get("contract_version", "")),
			"decisions": ObservatorySerializer.sanitize(
				contract_document.get("decisions", [])
			),
		},
		"characters": characters,
		"disciplines": disciplines,
		"spells": spells,
		"items": items,
		"reward_pools": reward_pools,
		"runs": run_graph.get("runs", []),
		"rooms": run_graph.get("rooms", []),
		"waves": run_graph.get("waves", []),
		"encounters": run_graph.get("encounters", []),
		"enemies": run_graph.get("enemies", []),
		"enemy_spells": run_graph.get("enemy_spells", []),
		"ai_profiles": run_graph.get("ai_profiles", []),
		"contract_checks": contract_checks,
		"audit_results": [],
	}
	var audits := source_audits
	audits.append_array(ObservatoryAuditRules.run(snapshot))
	_sort_audits(audits)
	snapshot["audit_results"] = audits
	snapshot["summary"] = _build_summary(snapshot)
	return {"snapshot": snapshot, "errors": errors, "warnings": warnings}


func _build_meta(manifest: Dictionary, contract: Dictionary) -> Dictionary:
	var version_info := Engine.get_version_info()
	return {
		"schema_version": SCHEMA_VERSION,
		"generator_version": GENERATOR_VERSION,
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source_game_commit": str(manifest.get("source_game_commit", "")),
		"source_branch": _git_output(["rev-parse", "--abbrev-ref", "HEAD"]),
		"source_worktree_dirty_before_export": not _git_output(
			["status", "--porcelain"]
		).is_empty(),
		"godot_version": str(version_info.get("string", "")),
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"contract_version": str(contract.get("contract_version", "")),
		"manifest_version": str(manifest.get("manifest_version", "")),
	}


func _build_scope(manifest: Dictionary) -> Dictionary:
	var included: Array[String] = []
	for domain_value in manifest.get("domains", []) as Array:
		var domain := domain_value as Dictionary
		if bool(domain.get("include_in_snapshot", false)):
			included.append(str(domain.get("domain", "")))
	included.sort()
	return {
		"included_domains": included,
		"deferred_domains": ObservatorySerializer.sanitize(
			manifest.get("deferred_domains", [])
		),
		"excluded_domains": ObservatorySerializer.sanitize(
			manifest.get("exclusions", [])
		),
	}


func _build_contract_checks(
		decisions: Array,
		characters: Array[Dictionary],
		run_data: RunData,
		eligible_item_ids: Array[String]
	) -> Array[Dictionary]:
	var ids: Array[String] = []
	for character in characters:
		ids.append(str(character.get("id", "")))
	ids.sort()
	var observed := {
		"party.required_character_ids": ids,
		"party.size": characters.size(),
		"combat.base_ap": _uniform_character_value(characters, "max_ap"),
		"combat.base_mp": _uniform_character_value(characters, "max_mp"),
		"combat.starting_active_spell_slots": _uniform_character_value(
			characters, "active_spell_slots"
		),
		"progression.discipline_count_per_character": _uniform_collection_size(
			characters, "discipline_ids"
		),
		"run.first_run_room_count": run_data.rooms.size() if run_data != null else null,
		"rewards.equipment_rewards_enabled": not eligible_item_ids.is_empty(),
		"observatory.mode": "static_versioned_snapshot",
		"observatory.realtime_reporting_enabled": false,
	}
	var evidence := {
		"party.required_character_ids": "Manifeste et UnitData du trio de production.",
		"party.size": "Nombre de UnitData chargés depuis les références de production.",
		"combat.base_ap": "Champ UnitData.max_ap des héros de production.",
		"combat.base_mp": "Champ UnitData.max_mp des héros de production.",
		"combat.starting_active_spell_slots": "Champ UnitData.active_spell_slots.",
		"progression.discipline_count_per_character": "Références UnitData.disciplines.",
		"run.first_run_room_count": "Taille de RunData.rooms dans first_run.tres.",
		"rewards.equipment_rewards_enabled": "Catalogue filtré par first_run_equipment_reward.",
		"observatory.mode": "Architecture de l’exporteur versionné.",
		"observatory.realtime_reporting_enabled": "Aucun mécanisme de reporting temps réel.",
	}
	var checks: Array[Dictionary] = []
	for decision_value in decisions:
		var decision := decision_value as Dictionary
		var key := str(decision.get("key", ""))
		var target: Variant = decision.get("value")
		var observed_value: Variant = observed.get(key)
		var status := "not_evaluated"
		var message := "La source statique actuelle ne permet pas de conclure."
		if observed.has(key):
			status = "conform" if _values_equal(target, observed_value) else "difference"
			message = "La valeur observée correspond à la cible." if status == "conform" \
				else "La valeur observée diffère de la cible versionnée."
		checks.append({
			"key": key,
			"target": ObservatorySerializer.sanitize(target),
			"observed_value": ObservatorySerializer.sanitize(observed_value),
			"status": status,
			"evidence": str(evidence.get(key, "Aucune preuve statique exportée.")),
			"message": message,
		})
	checks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", ""))
	)
	return checks


func _build_summary(snapshot: Dictionary) -> Dictionary:
	var contract_counts := {"conform": 0, "difference": 0, "unknown": 0,
		"not_evaluated": 0}
	for value in snapshot.get("contract_checks", []) as Array:
		var status := str((value as Dictionary).get("status", "unknown"))
		contract_counts[status] = int(contract_counts.get(status, 0)) + 1
	var audit_counts := {"info": 0, "warning": 0, "blocking": 0}
	for value in snapshot.get("audit_results", []) as Array:
		var severity := str((value as Dictionary).get("severity", "info"))
		audit_counts[severity] = int(audit_counts.get(severity, 0)) + 1
	var reward_count := 0
	var eligible_count := 0
	for pool_value in snapshot.get("reward_pools", []) as Array:
		var pool := pool_value as Dictionary
		reward_count += (pool.get("rewards", []) as Array).size()
		if str(pool.get("kind", "")) == "equipment_first_run":
			eligible_count = (pool.get("item_ids", []) as Array).size()
	return {
		"characters": (snapshot.get("characters", []) as Array).size(),
		"disciplines": (snapshot.get("disciplines", []) as Array).size(),
		"spells": (snapshot.get("spells", []) as Array).size(),
		"items": (snapshot.get("items", []) as Array).size(),
		"generic_rewards": reward_count,
		"reward_pools": (snapshot.get("reward_pools", []) as Array).size(),
		"runs": (snapshot.get("runs", []) as Array).size(),
		"rooms": (snapshot.get("rooms", []) as Array).size(),
		"waves": (snapshot.get("waves", []) as Array).size(),
		"encounters": (snapshot.get("encounters", []) as Array).size(),
		"enemies": (snapshot.get("enemies", []) as Array).size(),
		"enemy_spells": (snapshot.get("enemy_spells", []) as Array).size(),
		"ai_profiles": (snapshot.get("ai_profiles", []) as Array).size(),
		"eligible_first_run_equipment": eligible_count,
		"contract_conform": int(contract_counts["conform"]),
		"contract_difference": int(contract_counts["difference"]),
		"contract_unknown": int(contract_counts["unknown"]),
		"contract_not_evaluated": int(contract_counts["not_evaluated"]),
		"audit_info": int(audit_counts["info"]),
		"audit_warning": int(audit_counts["warning"]),
		"audit_blocking": int(audit_counts["blocking"]),
	}


func _load_resource(
		path: String,
		expected_type: String,
		audits: Array[Dictionary]
	) -> Resource:
	if not ResourceLoader.exists(path):
		audits.append(_audit("SOURCE.ROOT_LOAD_FAILURE", "blocking", "sources", "resource",
			path, "Une racine de production est absente.", path,
			"ResourceLoader.exists retourne false.", "Rétablir la ressource de production."))
		return null
	var resource := ResourceLoader.load(path)
	if resource == null:
		audits.append(_audit("SOURCE.ROOT_LOAD_FAILURE", "blocking", "sources", "resource",
			path, "Une racine de production ne peut pas être chargée.", path,
			"ResourceLoader.load retourne null.", "Corriger la ressource source."))
		return null
	if expected_type != "" and ObservatorySerializer.resource_type_name(resource) != expected_type:
		audits.append(_audit("SOURCE.ROOT_LOAD_FAILURE", "blocking", "sources", "resource",
			path, "Le type de la racine de production est inattendu.", path,
			"Type attendu : %s ; observé : %s." % [expected_type,
				ObservatorySerializer.resource_type_name(resource)],
			"Vérifier le manifeste et la Resource."))
		return null
	return resource


func _read_json_object(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Fichier JSON absent : %s." % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("Objet JSON invalide : %s." % path)
		return {}
	return parsed as Dictionary


func _git_output(arguments: Array[String]) -> String:
	var output: Array = []
	var executable := "git"
	var args := PackedStringArray(arguments)
	var exit_code := OS.execute(executable, args, output, true)
	return str(output[0]).strip_edges() if exit_code == 0 and not output.is_empty() else ""


func _uniform_character_value(characters: Array[Dictionary], key: String) -> Variant:
	if characters.is_empty():
		return null
	var value: Variant = characters[0].get(key)
	for character in characters:
		if character.get(key) != value:
			return null
	return value


func _uniform_collection_size(characters: Array[Dictionary], key: String) -> Variant:
	if characters.is_empty():
		return null
	var size := (characters[0].get(key, []) as Array).size()
	for character in characters:
		if (character.get(key, []) as Array).size() != size:
			return null
	return size


func _values_equal(first: Variant, second: Variant) -> bool:
	if (first is int or first is float) and (second is int or second is float):
		return is_equal_approx(float(first), float(second))
	return JSON.stringify(first) == JSON.stringify(second)


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _source_reference_audit(
		domain: String,
		entity_type: String,
		entity_id: String,
		source_path: String
	) -> Dictionary:
	return _audit("SOURCE.REFERENCE_UNRESOLVED", "blocking", domain, entity_type,
		entity_id, "Une référence de production ne peut pas être résolue.", source_path,
		"Référence nulle dans la Resource source.", "Réparer la référence source.")


func _audit(
		rule_id: String,
		severity: String,
		domain: String,
		entity_type: String,
		entity_id: String,
		message: String,
		source_path: String,
		evidence: String,
		action: String
	) -> Dictionary:
	return {"rule_id": rule_id, "severity": severity, "status": "open",
		"domain": domain, "entity_type": entity_type, "entity_id": entity_id,
		"message": message, "source_path": source_path, "evidence": evidence,
		"suggested_action": action}


func _sort_audits(audits: Array[Dictionary]) -> void:
	var order := {"blocking": 0, "warning": 1, "info": 2}
	audits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%d|%s|%s|%s" % [order.get(a.get("severity"), 9),
			a.get("rule_id"), a.get("domain"), a.get("entity_id")]
		var b_key := "%d|%s|%s|%s" % [order.get(b.get("severity"), 9),
			b.get("rule_id"), b.get("domain"), b.get("entity_id")]
		return a_key < b_key
	)
