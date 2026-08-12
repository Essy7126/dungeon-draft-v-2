@tool
class_name ArenaVortexNetworkDefinition
extends Resource

@export var network_id: StringName = &"vortex_network_001"
@export var display_name := "Réseau de vortex 1"
@export var cells: Array[Vector2i] = []
@export var enabled := true
@export_flags("Héros", "Ennemis") var allowed_teams := 3
@export var editor_color := Color(0.62, 0.32, 1.0, 1.0)
@export var single_vortex_effect_id: StringName = &"void_impulse"
@export var random_destination := true
@export_multiline var production_notes := ""


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


func unique_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if not result.has(cell):
			result.append(cell)
	return result


func allows_team(team: int) -> bool:
	return allowed_teams & (1 << clampi(team, 0, 1)) != 0


func to_dict() -> Dictionary:
	return {
		"network_id": String(network_id),
		"display_name": display_name,
		"cells": unique_cells().map(func(value): return [value.x, value.y]),
		"enabled": enabled,
		"allowed_teams": allowed_teams,
		"editor_color": editor_color.to_html(true),
		"single_vortex_effect_id": String(single_vortex_effect_id),
		"random_destination": random_destination,
		"production_notes": production_notes,
	}


static func from_dict(data: Dictionary) -> ArenaVortexNetworkDefinition:
	var result := ArenaVortexNetworkDefinition.new()
	result.network_id = StringName(data.get("network_id", "vortex_network_001"))
	result.display_name = str(data.get("display_name", "Réseau de vortex"))
	for entry in data.get("cells", []):
		if entry is Array and entry.size() >= 2:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			if not result.cells.has(cell):
				result.cells.append(cell)
	result.enabled = bool(data.get("enabled", true))
	result.allowed_teams = int(data.get("allowed_teams", 3))
	result.editor_color = Color.html(str(data.get("editor_color", "9e52ffff")))
	result.single_vortex_effect_id = StringName(data.get(
		"single_vortex_effect_id", "void_impulse"
	))
	result.random_destination = bool(data.get("random_destination", true))
	result.production_notes = str(data.get("production_notes", ""))
	return result
