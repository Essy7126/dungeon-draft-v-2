@tool
class_name ItemReferenceService
extends RefCounted

const CHARACTERIZATION_PATH := "res://artifacts/item_studio/characterization.json"

var _cached_report := {}
var _cached_modified_time := -1


func incoming_references(definition: ItemDefinition) -> Array[String]:
	if definition == null:
		return []
	var report := load_report()
	var references := report.get("references", {}) as Dictionary
	return _strings(references.get(str(definition.item_id), []) as Array)


func load_report() -> Dictionary:
	var modified_time := int(FileAccess.get_modified_time(CHARACTERIZATION_PATH)) \
		if FileAccess.file_exists(CHARACTERIZATION_PATH) else 0
	if not _cached_report.is_empty() and modified_time == _cached_modified_time:
		return _cached_report
	if not FileAccess.file_exists(CHARACTERIZATION_PATH):
		_cached_report = ItemCharacterizationService.new().characterize()
		_cached_modified_time = modified_time
		return _cached_report
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERIZATION_PATH))
	_cached_report = parsed as Dictionary if parsed is Dictionary else {}
	_cached_modified_time = modified_time
	return _cached_report


func invalidate_cache() -> void:
	_cached_report.clear()
	_cached_modified_time = -1


func readonly_starting_inventory_reference(definition: ItemDefinition) -> bool:
	if definition == null:
		return false
	var report := load_report()
	for value in report.get("definitions", []) as Array:
		var entry := value as Dictionary
		if StringName(entry.get("item_id", &"")) == definition.item_id:
			return bool(entry.get("starting_inventory", false))
	return false


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
