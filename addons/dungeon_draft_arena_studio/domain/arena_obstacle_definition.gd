@tool
class_name ArenaObstacleDefinition
extends Resource

enum Preset {
	FULL_WALL,
	LOW_OBSTACLE,
	PASSABLE_DECOR,
	CLIFF,
}

@export var obstacle_id: StringName = &"obstacle"
@export var cell := Vector2i.ZERO
@export_enum("Mur complet:0", "Obstacle bas:1", "Decor traversable:2", "Falaise:3")
var preset: int = Preset.FULL_WALL
@export var blocks_movement := true
@export var blocks_line_of_sight := true
@export var blocks_projectiles := true
@export var blocks_push := true


func apply_preset(value: int) -> void:
	preset = clampi(value, Preset.FULL_WALL, Preset.CLIFF)
	match preset:
		Preset.FULL_WALL:
			blocks_movement = true
			blocks_line_of_sight = true
			blocks_projectiles = true
			blocks_push = true
		Preset.LOW_OBSTACLE:
			blocks_movement = true
			blocks_line_of_sight = false
			blocks_projectiles = false
			blocks_push = true
		Preset.PASSABLE_DECOR:
			blocks_movement = false
			blocks_line_of_sight = false
			blocks_projectiles = false
			blocks_push = false
		Preset.CLIFF:
			blocks_movement = true
			blocks_line_of_sight = false
			blocks_projectiles = false
			blocks_push = true


func to_dict() -> Dictionary:
	return {
		"obstacle_id": str(obstacle_id),
		"cell": [cell.x, cell.y],
		"preset": preset,
		"blocks_movement": blocks_movement,
		"blocks_line_of_sight": blocks_line_of_sight,
		"blocks_projectiles": blocks_projectiles,
		"blocks_push": blocks_push,
	}


static func from_dict(data: Dictionary) -> ArenaObstacleDefinition:
	var definition := ArenaObstacleDefinition.new()
	definition.obstacle_id = StringName(data.get("obstacle_id", "obstacle"))
	var cell_data: Array = data.get("cell", [0, 0])
	definition.cell = Vector2i(int(cell_data[0]), int(cell_data[1]))
	definition.preset = clampi(
		int(data.get("preset", Preset.FULL_WALL)), Preset.FULL_WALL, Preset.CLIFF
	)
	definition.blocks_movement = bool(data.get("blocks_movement", true))
	definition.blocks_line_of_sight = bool(data.get("blocks_line_of_sight", true))
	definition.blocks_projectiles = bool(data.get("blocks_projectiles", true))
	definition.blocks_push = bool(data.get("blocks_push", true))
	return definition
