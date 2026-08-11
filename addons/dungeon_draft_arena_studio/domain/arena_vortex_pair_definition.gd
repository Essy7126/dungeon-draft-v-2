@tool
class_name ArenaVortexPairDefinition
extends Resource

## Donnée d'authoring uniquement tant que le runtime, Pathfinder et l'IA ne
## certifient pas le contrat de traversée.

const CURRENT_SCHEMA_VERSION := 1

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var pair_id: StringName = &"vortex_pair"
@export var entry_cell := Vector2i.ZERO
@export var exit_cell := Vector2i.ONE
@export var traversal_contract: StringName = &"enter_cell"
@export var bidirectional := true
@export var runtime_enabled := false


func contains(cell: Vector2i) -> bool:
	return cell == entry_cell or cell == exit_cell


func other_cell(cell: Vector2i) -> Vector2i:
	if cell == entry_cell:
		return exit_cell
	if cell == exit_cell:
		return entry_cell
	return GridTransformService.INVALID_CELL


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"pair_id": str(pair_id),
		"entry_cell": [entry_cell.x, entry_cell.y],
		"exit_cell": [exit_cell.x, exit_cell.y],
		"traversal_contract": str(traversal_contract),
		"bidirectional": bidirectional,
		"runtime_enabled": runtime_enabled,
	}


static func from_dict(data: Dictionary) -> ArenaVortexPairDefinition:
	var result := ArenaVortexPairDefinition.new()
	result.schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	result.pair_id = StringName(data.get("pair_id", "vortex_pair"))
	result.entry_cell = _vector2i(data.get("entry_cell", [0, 0]))
	result.exit_cell = _vector2i(data.get("exit_cell", [1, 1]))
	result.traversal_contract = StringName(data.get("traversal_contract", "enter_cell"))
	result.bidirectional = bool(data.get("bidirectional", true))
	# Une ancienne ou future donnée ne peut jamais activer implicitement le
	# runtime tant que cette version ne possède pas de consommateur certifié.
	result.runtime_enabled = false
	return result


static func _vector2i(value) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) \
		if value is Array and value.size() >= 2 else Vector2i.ZERO

