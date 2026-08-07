@tool
class_name ItemCharacterizationService
extends RefCounted

const SOURCE_EXTENSIONS := ["gd", "tres", "tscn"]
const SKIPPED_PREFIXES := [
	"res://.godot", "res://artifacts", "res://output", "res://addons/gut",
]
const RUNTIME_AUTHORITIES := {
	"ItemDefinition": "res://data/items/item_definition.gd",
	"ItemCatalog": "res://data/items/item_catalog.gd",
	"ItemStatModifierData": "res://data/items/item_stat_modifier_data.gd",
	"ItemSpellModifierData": "res://data/items/item_spell_modifier_data.gd",
	"ItemInstance": "res://items/item_instance.gd",
	"RunInventory": "res://items/run_inventory.gd",
	"EquipmentLoadout": "res://items/equipment_loadout.gd",
	"EquipmentService": "res://items/equipment_service.gd",
	"EquipmentStatService": "res://items/equipment_stat_service.gd",
	"ItemUseService": "res://items/item_use_service.gd",
	"FirstRunEquipmentRewardService": "res://data/post_combat/first_run_equipment_reward_service.gd",
	"InventoryScreen": "res://ui/inventory/inventory_screen.gd",
	"EquipmentRewardOverlay": "res://ui/post_combat/equipment_reward_overlay.gd",
}

var catalog_service := ItemStudioCatalogService.new()
var registry := ItemEffectRegistry.new()
var copy_service := ItemDeepCopyService.new()


func characterize(metadata := {}) -> Dictionary:
	var rebuilt := catalog_service.rebuild()
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if not rebuilt.get("ok", false):
		errors.append(str(rebuilt.get("error", "Catalogue invalide.")))
	var definitions := catalog_service.production_definitions()
	var coverage := registry.coverage_report(definitions)
	if not coverage.get("valid", false):
		errors.append("Des classes d’effet atteignables ne possèdent aucun descripteur.")
	var sharing := copy_service.audit_catalog(definitions)
	if not sharing.get("valid", false):
		warnings.append("Des sous-ressources mutables sont partagées entre définitions.")
	var source_paths: Array[String] = []
	_collect_source_paths("res://", source_paths)
	var definition_entries: Array[Dictionary] = []
	var references := {}
	var fingerprints := {}
	for definition in definitions:
		if definition == null:
			continue
		var incoming := _incoming_references(definition, source_paths)
		references[str(definition.item_id)] = incoming
		var fingerprint := ItemFingerprintService.semantic_fingerprint(definition)
		fingerprints[definition.resource_path] = fingerprint
		definition_entries.append(_definition_entry(definition, incoming, fingerprint))
	definition_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("path", "")) < str(b.get("path", ""))
	)
	var result := {
		"schema_version": 1,
		"branch": str(metadata.get("branch", OS.get_environment("ITEM_STUDIO_BRANCH"))),
		"commit": str(metadata.get("commit", OS.get_environment("ITEM_STUDIO_HEAD"))),
		"date": str(metadata.get("date", Time.get_datetime_string_from_system(true))),
		"godot_version": Engine.get_version_info().get("string", ""),
		"definition_count": definitions.size(),
		"catalogs": [{
			"path": ItemStudioCatalogService.DEFAULT_CATALOG_PATH,
			"explicit_definition_count": catalog_service.production_catalog.definitions.size() \
				if catalog_service.production_catalog != null else 0,
			"auto_discovery_directories": Array(catalog_service.auto_discovery_directories()),
			"deduplication": "resource_path for explicit + discovered; item_id rejected by rebuild_index",
			"deterministic_order": "explicit order, then discovered paths sorted",
		}],
		"runtime_authorities": RUNTIME_AUTHORITIES.duplicate(true),
		"effect_classes": coverage,
		"definitions": definition_entries,
		"references": references,
		"errors": errors,
		"warnings": warnings,
		"mutable_sharing": sharing,
		"legacy_resources": _legacy_resources(),
		"semantic_fingerprints": fingerprints,
		"production_catalog_fingerprint": ItemFingerprintService.catalog_fingerprint(definitions),
		"draft_directory": ItemStudioCatalogService.DRAFT_DIRECTORY,
		"draft_is_auto_discovered": catalog_service.is_path_auto_discovered(
			ItemStudioCatalogService.DRAFT_DIRECTORY.path_join("probe.tres")
		),
		"reward_tag": str(FirstRunEquipmentRewardService.POOL_TAG),
	}
	result["valid"] = errors.is_empty()
	return result


func write_artifact(
		resource_path := "res://artifacts/item_studio/characterization.json",
		metadata := {}
	) -> Dictionary:
	var report := characterize(metadata)
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if error != OK:
		return {"ok": false, "error": "Création du dossier impossible : %s" % error}
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Ouverture de l’artefact impossible."}
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	return {"ok": report.get("valid", false), "path": resource_path, "report": report}


func _definition_entry(
		definition: ItemDefinition,
		incoming: Array[String],
		fingerprint: String
	) -> Dictionary:
	var stat_modifiers: Array[Dictionary] = []
	for modifier in definition.stat_modifiers:
		stat_modifiers.append(ItemFingerprintService._resource_snapshot(modifier))
	var spell_modifiers: Array[Dictionary] = []
	for modifier in definition.spell_modifiers:
		spell_modifiers.append(ItemFingerprintService._resource_snapshot(modifier))
	return {
		"path": definition.resource_path,
		"item_id": str(definition.item_id),
		"display_name": definition.display_name,
		"category": int(definition.category),
		"rarity": str(definition.rarity),
		"equipment_slot": int(definition.equipment_slot),
		"compatible_character_ids": _string_array(definition.compatible_character_ids),
		"tags": _string_array(definition.tags),
		"stat_modifiers": stat_modifiers,
		"spell_modifiers": spell_modifiers,
		"use_effect": int(definition.use_effect),
		"use_value": definition.use_value,
		"incoming_references": incoming,
		"reward_eligible": catalog_service.reward_eligible(definition),
		"starting_inventory": _is_starting_inventory_id(definition.item_id),
		"status": "SHARED" if definition.is_valid() else "INVALID",
		"semantic_fingerprint": fingerprint,
	}


func _incoming_references(
		definition: ItemDefinition,
		source_paths: Array[String]
	) -> Array[String]:
	var result: Array[String] = []
	var needles := [definition.resource_path, str(definition.item_id)]
	for path in source_paths:
		if path == definition.resource_path:
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		if needles.any(func(needle): return not str(needle).is_empty() and text.contains(str(needle))):
			result.append(path)
	result.sort()
	return result


func _collect_source_paths(directory_path: String, result: Array[String]) -> void:
	if SKIPPED_PREFIXES.any(func(prefix): return directory_path.begins_with(prefix)):
		return
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_source_paths(path, result)
			elif entry.get_extension().to_lower() in SOURCE_EXTENSIONS:
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _is_starting_inventory_id(item_id: StringName) -> bool:
	var game_manager_source := FileAccess.get_file_as_string(
		"res://core/game_manager.gd"
	)
	return game_manager_source.contains(
		"{\"item_id\": &\"%s\"" % str(item_id)
	)


func _legacy_resources() -> Array[Dictionary]:
	return [
		{
			"path": "res://data/equipment/**",
			"status": "HISTORIQUE",
			"runtime_usage": false,
			"evidence": "Absent du HEAD; suppression qualifiée par docs/audits/project_cleanup/candidate_deletions.md",
		},
		{
			"path": "res://data/relics/**",
			"status": "HISTORIQUE",
			"runtime_usage": false,
			"evidence": "Absent du HEAD; aucun runtime RelicDefinition actif",
		},
	]


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
