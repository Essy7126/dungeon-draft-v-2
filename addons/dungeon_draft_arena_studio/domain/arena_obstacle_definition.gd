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
@export var wall_id: StringName = &""
@export var wall_config: WallConfig = null
@export var visual_variant: StringName = &""
@export var orientation := Vector2i.DOWN
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
		"wall_id": str(wall_id),
		"wall_config_path": wall_config.resource_path if wall_config != null else "",
		"visual_variant": str(visual_variant),
		"orientation": [orientation.x, orientation.y],
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
	definition.wall_id = StringName(data.get("wall_id", ""))
	var config_path := str(data.get("wall_config_path", ""))
	definition.wall_config = load(config_path) as WallConfig \
		if not config_path.is_empty() and ResourceLoader.exists(config_path) else null
	if definition.wall_config == null and definition.wall_id != &"":
		definition.wall_config = ArenaWallRegistry.config_for(definition.wall_id)
	definition.visual_variant = StringName(data.get("visual_variant", ""))
	var orientation_data: Array = data.get("orientation", [0, 1])
	definition.orientation = Vector2i(int(orientation_data[0]), int(orientation_data[1]))
	definition.preset = clampi(
		int(data.get("preset", Preset.FULL_WALL)), Preset.FULL_WALL, Preset.CLIFF
	)
	definition.blocks_movement = bool(data.get("blocks_movement", true))
	definition.blocks_line_of_sight = bool(data.get("blocks_line_of_sight", true))
	definition.blocks_projectiles = bool(data.get("blocks_projectiles", true))
	definition.blocks_push = bool(data.get("blocks_push", true))
	return definition
