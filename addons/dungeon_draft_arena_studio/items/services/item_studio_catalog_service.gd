@tool
class_name ItemStudioCatalogService
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/items/catalogs/default_item_catalog.tres"
const DRAFT_DIRECTORY := "res://data/items/drafts"
const PRODUCTION_STATUS := &"SHARED"
const DRAFT_STATUS := &"DRAFT"
const LEGACY_STATUS := &"LEGACY"
const INVALID_STATUS := &"INVALID"

var production_catalog: ItemCatalog = null
var catalog_path := DEFAULT_CATALOG_PATH
var draft_directory := DRAFT_DIRECTORY


func configure(p_catalog_path := DEFAULT_CATALOG_PATH, p_draft_directory := DRAFT_DIRECTORY) -> void:
	catalog_path = p_catalog_path
	draft_directory = p_draft_directory
	production_catalog = null


func rebuild() -> Dictionary:
	production_catalog = ResourceLoader.load(catalog_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemCatalog
	if production_catalog == null:
		return {"ok": false, "error": "Catalogue d’objets introuvable."}
	var validation := production_catalog.validate_catalog()
	if not validation.get("valid", false):
		return {"ok": false, "error": "Catalogue d’objets invalide.", "validation": validation}
	return {
		"ok": true,
		"production": production_catalog.get_definitions(),
		"drafts": discover_drafts(),
		"validation": validation,
	}


func production_definitions() -> Array[ItemDefinition]:
	if production_catalog == null and not rebuild().get("ok", false):
		return []
	return production_catalog.get_definitions()


func discover_drafts() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var paths: Array[String] = []
	_collect_resource_paths(draft_directory, paths)
	paths.sort()
	for path in paths:
		var resource := load(path)
		if resource is ItemDefinition:
			result.append(resource as ItemDefinition)
	return result


func entries(include_drafts := true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in production_definitions():
		result.append(_entry(definition, PRODUCTION_STATUS))
	if include_drafts:
		for definition in discover_drafts():
			result.append(_entry(
				definition,
				DRAFT_STATUS if definition.is_valid() else INVALID_STATUS,
			))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(
			str(b.get("display_name", ""))
		) < 0
	)
	return result


func auto_discovery_directories() -> PackedStringArray:
	if production_catalog == null:
		rebuild()
	return production_catalog.auto_discovery_directories.duplicate() \
		if production_catalog != null else PackedStringArray()


func is_path_auto_discovered(resource_path: String) -> bool:
	for directory in auto_discovery_directories():
		var normalized_directory := str(directory).trim_suffix("/")
		if resource_path == normalized_directory or resource_path.begins_with(normalized_directory + "/"):
			return true
	return false


func has_item_id(item_id: StringName, excluded_path := "") -> bool:
	for entry in entries(true):
		if StringName(entry.get("item_id", &"")) == item_id \
				and str(entry.get("path", "")) != excluded_path:
			return true
	return false


func reward_eligible(definition: ItemDefinition) -> bool:
	return definition != null and definition.is_equippable() \
		and definition.tags.has(FirstRunEquipmentRewardService.POOL_TAG)


func _entry(definition: ItemDefinition, status: StringName) -> Dictionary:
	return {
		"definition": definition,
		"path": definition.resource_path if definition != null else "",
		"item_id": definition.item_id if definition != null else &"",
		"display_name": definition.display_name if definition != null else "<invalide>",
		"category": int(definition.category) if definition != null else -1,
		"rarity": definition.rarity if definition != null else &"",
		"slot": int(definition.equipment_slot) if definition != null else -1,
		"compatible_character_ids": definition.compatible_character_ids.duplicate() if definition != null else [],
		"tags": definition.tags.duplicate() if definition != null else [],
		"reward_eligible": reward_eligible(definition),
		"status": status,
		"fingerprint": ItemFingerprintService.semantic_fingerprint(definition),
	}


func _collect_resource_paths(directory_path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_resource_paths(path, result)
			elif entry.get_extension().to_lower() in ["tres", "res"]:
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
