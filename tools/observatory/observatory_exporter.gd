class_name ObservatoryExporter
extends RefCounted

const SCHEMA_VERSION := "2.1.0"
const GENERATOR_VERSION := "2.1.0"
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

var _git_executable := "git"
var _git_working_directory := ""


func build_snapshot(
		manifest_path: String = DEFAULT_MANIFEST_PATH,
		contract_path: String = DEFAULT_CONTRACT_PATH,
		documentary_mode: bool = false
	) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var source_audits: Array[Dictionary] = []
	var manifest := _read_json_object(manifest_path, errors)
	var contract_document := _read_json_object(contract_path, errors)
	if manifest.has("source_game_commit"):
		warnings.append(
			"Le champ manifeste source_game_commit est obsolète et ignoré au profit de Git."
		)
	var provenance := read_git_provenance(documentary_mode)
	warnings.append_array(provenance.get("warnings", []) as Array)
	if not bool(provenance.get("source_git_available", false)) and not documentary_mode:
		errors.append("Git est indisponible : l’export release refuse d’inventer sa provenance.")
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
		"meta": _build_meta(manifest, contract_document, provenance),
		"scope": _build_scope(manifest),
		"summary": {},
		"contract": {
			"version": str(contract_document.get("contract_version", "")),
			"decisions": _export_contract_decisions(
				contract_document.get("decisions", []) as Array
			),
		},
		"runtime_facts": _build_runtime_facts(),
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


func configure_git_for_tests(executable: String, working_directory: String) -> void:
	_git_executable = executable
	_git_working_directory = working_directory


func read_git_provenance(documentary_mode: bool = false) -> Dictionary:
	var head_result := _git_result(["rev-parse", "HEAD"])
	if int(head_result.get("exit_code", -1)) != 0:
		return {
			"source_game_commit": "unknown" if documentary_mode else "",
			"source_branch": "unknown",
			"source_worktree_dirty_before_export": false,
			"source_git_available": false,
			"source_generated_from_clean_checkout": false,
			"warnings": ["Git indisponible : provenance non certifiée."],
		}
	var branch_result := _git_result(["rev-parse", "--abbrev-ref", "HEAD"])
	var status_result := _git_result(["status", "--porcelain"])
	var dirty := int(status_result.get("exit_code", -1)) != 0 \
		or not str(status_result.get("output", "")).is_empty()
	return {
		"source_game_commit": str(head_result.get("output", "")),
		"source_branch": str(branch_result.get("output", "unknown")),
		"source_worktree_dirty_before_export": dirty,
		"source_git_available": true,
		"source_generated_from_clean_checkout": not dirty,
		"warnings": [],
	}


func _build_meta(
		manifest: Dictionary,
		contract: Dictionary,
		provenance: Dictionary
	) -> Dictionary:
	var version_info := Engine.get_version_info()
	return {
		"schema_version": SCHEMA_VERSION,
		"generator_version": GENERATOR_VERSION,
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source_game_commit": str(provenance.get("source_game_commit", "")),
		"source_branch": str(provenance.get("source_branch", "unknown")),
		"source_worktree_dirty_before_export": bool(provenance.get(
			"source_worktree_dirty_before_export", false
		)),
		"source_git_available": bool(provenance.get("source_git_available", false)),
		"source_generated_from_clean_checkout": bool(provenance.get(
			"source_generated_from_clean_checkout", false
		)),
		"godot_version": str(version_info.get("string", "")),
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"contract_version": str(contract.get("contract_version", "")),
		"manifest_version": str(manifest.get("manifest_version", "")),
	}


func _export_contract_decisions(decisions: Array) -> Array[Dictionary]:
	var exported: Array[Dictionary] = []
	for decision_value in decisions:
		var decision := ObservatorySerializer.sanitize(decision_value) as Dictionary
		decision["truth_status"] = "design_decision"
		exported.append(decision)
	return exported


func _build_runtime_facts() -> Array[Dictionary]:
	var progression_path := "res://characters/progression/character_progression_service.gd"
	var progression_source := FileAccess.get_file_as_string(progression_path)
	var battle_path := "res://battle/battle.gd"
	var battle_source := FileAccess.get_file_as_string(battle_path)
	var game_manager_path := "res://core/game_manager.gd"
	var game_manager_source := FileAccess.get_file_as_string(game_manager_path)
	var facts: Array[Dictionary] = [
		_runtime_fact(
			"progression.xp_per_effective_cast",
			1 if progression_source.contains(
				"add_discipline_xp(spell.discipline_id, 1)"
			) else null,
			"observed" if progression_source.contains(
				"add_discipline_xp(spell.discipline_id, 1)"
			) else "non_certified",
			[progression_path],
			"CharacterProgressionService crédite la discipline avec la valeur littérale du runtime.",
			"Baseline runtime observée ; ce n’est pas une cible de conception.",
		),
		_runtime_fact(
			"progression.requires_effective_cast",
			progression_source.contains("report.get(\"effective_cast\", false)"),
			"observed",
			[progression_path],
			"grant_cast_xp refuse les rapports sans effective_cast.",
			"Baseline runtime observée ; ce n’est pas une cible de conception.",
		),
		_runtime_fact(
			"progression.same_spell_once_per_activation",
			progression_source.contains("same_spell_already_awarded_this_activation"),
			"observed",
			[progression_path],
			"La clé d’attribution combine unité, activation_index et spell_id.",
			"La restriction porte sur un même sort pendant une même activation.",
		),
		_runtime_fact(
			"progression.cap_per_discipline_per_combat",
			CharacterProgressionService.MAX_DISCIPLINE_XP_PER_COMBAT,
			"verified",
			[progression_path],
			"Constante runtime lue directement et appliquée avant chaque attribution.",
			"Plafond indexé par character_id et discipline_id.",
		),
		_runtime_fact(
			"progression.cap_reset_semantics",
			"begin_combat_clears_combat_xp_and_activation_awards",
			"observed",
			[progression_path, game_manager_path],
			"begin_combat vide les deux dictionnaires ; GameManager l’appelle au début du combat.",
			"reset_run délègue également à begin_combat.",
		),
		_runtime_fact(
			"progression.evolution_timing",
			"in_combat",
			"observed" if battle_source.contains(
				"_process_evolution_queue_at_safe_point"
			) else "non_certified",
			[battle_path, "res://ui/run/persistent_run_ui.gd"],
			"Battle traite la file d’évolution à un point sûr avant de rendre le contrôle.",
			"Ce fait runtime concorde avec la décision de conception distincte.",
		),
		_runtime_fact(
			"run.wave_scene_reload_behavior",
			"same_room_battle_scene_reloaded_between_waves",
			"observed" if game_manager_source.contains(
				"current_wave_index += 1"
			) and game_manager_source.contains(
				"change_scene_to_packed.call_deferred(room.battle_scene)"
			) else "non_certified",
			[game_manager_path],
			"continue_current_room_combat incrémente la vague puis recharge room.battle_scene.",
			"La scène est rechargée ; l’état de run persistant reste dans GameManager.",
		),
		_runtime_fact(
			"combat.damage_mitigation_formula",
			{
				"non_negative_defense": "defense / (defense + K)",
				"negative_defense": "defense / (K - defense)",
				"K": DamageResolver.MITIGATION_K,
			},
			"verified",
			["res://core/damage_resolver.gd"],
			"Formule publique DamageResolver.mitigation avec constante runtime K.",
			"Les résistances élémentaires sont appliquées avant la mitigation de catégorie.",
		),
		_runtime_fact(
			"rewards.equipment_offer_timing",
			"after_victorious_finalized_non_final_room_exit_selection",
			"observed",
			[game_manager_path, "res://ui/post_combat/post_combat_screen.gd"],
			"can_claim_post_combat_equipment exige victoire finalisée, salle non finale et sortie sécurisée.",
			"Une offre déjà appliquée n’est pas reproposée.",
		),
		_runtime_fact(
			"content.production_classification",
			null,
			"non_certified",
			["res://data"],
			"Aucun champ explicite DEBUG, PLACEHOLDER, CHEAT ou TOOL n’a été identifié sur les ressources exportées.",
			"Ne pas déduire une classification depuis les dégâts ou le nom d’une ressource.",
		),
	]
	facts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", ""))
	)
	return facts


func _runtime_fact(
		key: String,
		value: Variant,
		truth_status: String,
		source_paths: Array[String],
		evidence: String,
		notes: String
	) -> Dictionary:
	return {
		"key": key,
		"value": ObservatorySerializer.sanitize(value),
		"truth_status": truth_status,
		"source_paths": source_paths,
		"evidence": evidence,
		"notes": notes,
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
		if str(decision.get("status", "")) == "unknown":
			status = "unknown"
			message = "La décision de conception reste explicitement inconnue."
		elif observed.has(key):
			status = "conform" if _values_equal(target, observed_value) else "difference"
			message = "La valeur observée correspond à la cible." if status == "conform" \
				else "La valeur observée diffère de la cible versionnée."
		var affected_ids := _affected_entity_ids_for_contract(
			key, target, characters, status
		)
		checks.append({
			"key": key,
			"target": ObservatorySerializer.sanitize(target),
			"observed_value": ObservatorySerializer.sanitize(observed_value),
			"status": status,
			"truth_status": "verified" if observed.has(key) else "non_certified",
			"affected_entity_type": "character" if not affected_ids.is_empty() else "",
			"affected_entity_ids": affected_ids,
			"evidence": str(evidence.get(key, "Aucune preuve statique exportée.")),
			"message": message,
		})
	checks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", ""))
	)
	return checks


func _affected_entity_ids_for_contract(
		key: String,
		target: Variant,
		characters: Array[Dictionary],
		status: String
	) -> Array[String]:
	var field_by_key := {
		"combat.base_ap": "max_ap",
		"combat.base_mp": "max_mp",
		"combat.starting_active_spell_slots": "active_spell_slots",
		"progression.discipline_count_per_character": "discipline_ids",
	}
	var result: Array[String] = []
	if status != "difference" or not field_by_key.has(key):
		return result
	var field := str(field_by_key[key])
	for character in characters:
		var observed_value: Variant = character.get(field)
		if observed_value is Array:
			observed_value = (observed_value as Array).size()
		if not _values_equal(target, observed_value):
			result.append(str(character.get("id", "")))
	result.sort()
	return result


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
	var selected_wave_profiles := 0
	for wave_value in snapshot.get("waves", []) as Array:
		if bool((wave_value as Dictionary).get("is_selected_by_default_seed", false)):
			selected_wave_profiles += 1
	var minimum_played_profiles := 0
	var maximum_played_profiles := 0
	for room_value in snapshot.get("rooms", []) as Array:
		var room := room_value as Dictionary
		minimum_played_profiles += int(room.get("minimum_wave_count", 0))
		maximum_played_profiles += int(room.get("maximum_wave_count", 0))
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
		"authored_wave_profiles": (snapshot.get("waves", []) as Array).size(),
		"selected_default_seed_wave_profiles": selected_wave_profiles,
		"minimum_played_wave_profiles": minimum_played_profiles,
		"maximum_played_wave_profiles": maximum_played_profiles,
		"encounters": (snapshot.get("encounters", []) as Array).size(),
		"enemies": (snapshot.get("enemies", []) as Array).size(),
		"enemy_spells": (snapshot.get("enemy_spells", []) as Array).size(),
		"ai_profiles": (snapshot.get("ai_profiles", []) as Array).size(),
		"runtime_facts": (snapshot.get("runtime_facts", []) as Array).size(),
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


func _git_result(arguments: Array[String]) -> Dictionary:
	var output: Array = []
	var args := PackedStringArray(["--no-optional-locks"])
	var working_directory := _git_working_directory
	if working_directory.is_empty():
		working_directory = ProjectSettings.globalize_path("res://")
	args.append_array(PackedStringArray(["-C", working_directory]))
	args.append_array(PackedStringArray(arguments))
	var exit_code := OS.execute(_git_executable, args, output, true)
	return {
		"exit_code": exit_code,
		"output": str(output[0]).strip_edges() if not output.is_empty() else "",
	}


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
	var affected_ids: Array[String] = []
	if not entity_id.is_empty():
		affected_ids.append(entity_id)
	return {"rule_id": rule_id, "severity": severity, "status": "open",
		"truth_status": "observed",
		"suggested_action_truth_status": "recommendation",
		"domain": domain, "entity_type": entity_type, "entity_id": entity_id,
		"affected_entity_type": entity_type,
		"affected_entity_ids": affected_ids,
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
