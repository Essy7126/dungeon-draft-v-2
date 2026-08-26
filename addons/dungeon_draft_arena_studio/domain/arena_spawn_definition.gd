@tool
class_name ArenaSpawnDefinition
extends Resource

enum Kind {
	HERO_1,
	HERO_2,
	HERO_3,
	ENEMY,
	ENEMY_GROUP,
	SUMMON_ZONE,
}

@export var spawn_id: StringName = &"spawn"
@export_enum("Héros 1:0", "Héros 2:1", "Héros 3:2", "Ennemi:3", "Groupe ennemi:4", "Zone d'invocation:5")
var kind: int = Kind.ENEMY
@export var unit_id: StringName = &""
@export var cell := Vector2i.ZERO
@export var facing := Vector2i.LEFT
@export var required := true
@export var group_id: StringName = &""


func is_hero() -> bool:
	return kind in [Kind.HERO_1, Kind.HERO_2, Kind.HERO_3]


func is_enemy() -> bool:
	return kind in [Kind.ENEMY, Kind.ENEMY_GROUP]


func display_label() -> String:
	return [
		"Zone de départ des héros", "Zone de départ des héros", "Zone de départ des héros", "Ennemi", "Groupe ennemi",
		"Zone d'invocation",
	][kind]


func to_dict() -> Dictionary:
	return {
		"spawn_id": str(spawn_id),
		"kind": kind,
		"unit_id": str(unit_id),
		"cell": [cell.x, cell.y],
		"facing": [facing.x, facing.y],
		"required": required,
		"group_id": str(group_id),
	}


static func from_dict(data: Dictionary) -> ArenaSpawnDefinition:
	var definition := ArenaSpawnDefinition.new()
	definition.spawn_id = StringName(data.get("spawn_id", "spawn"))
	definition.kind = clampi(int(data.get("kind", Kind.ENEMY)), Kind.HERO_1, Kind.SUMMON_ZONE)
	definition.unit_id = StringName(data.get("unit_id", ""))
	var cell_data: Array = data.get("cell", [0, 0])
	definition.cell = Vector2i(int(cell_data[0]), int(cell_data[1]))
	var facing_data: Array = data.get("facing", [-1, 0])
	definition.facing = Vector2i(int(facing_data[0]), int(facing_data[1]))
	definition.required = bool(data.get("required", true))
	definition.group_id = StringName(data.get("group_id", ""))
	return definition
