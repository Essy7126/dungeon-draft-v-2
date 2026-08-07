@tool
class_name ItemReferenceService
extends RefCounted

const CHARACTERIZATION_PATH := "res://artifacts/item_studio/characterization.json"


func incoming_references(definition: ItemDefinition) -> Array[String]:
	if definition == null:
		return []
	var report := load_report()
	var references := report.get("references", {}) as Dictionary
	return _strings(references.get(str(definition.item_id), []) as Array)


func load_report() -> Dictionary:
	if not FileAccess.file_exists(CHARACTERIZATION_PATH):
		return ItemCharacterizationService.new().characterize()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERIZATION_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


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
