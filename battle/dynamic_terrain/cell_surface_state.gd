class_name CellSurfaceState
extends RefCounted

## Donnees d'une cellule de surface. Le terrain de base reste immuable : les
## sorts ne modifient que la couche dynamique et ses metadonnees temporaires.

enum BaseSurface {
	NORMAL,
	## Alias conservé pour les contrats Forest Dynamic Grid antérieurs au Studio 2.0.
	FOREST_NEUTRAL = 0,
	WATER,
	ICE,
	LAVA,
	POISON,
	STEAM,
	ELECTRIFIED_WATER,
	VOID,
	WALL,
	OBSTACLE,
}

enum DynamicSurface {
	NONE,
	FIRE,
	WATER,
	ICE,
}

var base_surface: BaseSurface = BaseSurface.NORMAL
var base_cell_type: int = GridData.CellType.NORMAL
var base_terrain_id: StringName = &"normal"
var base_walkable := true
var base_transparent := true
var base_projectile_passable := true
var base_movement_cost := 1
var base_effect: TerrainEffectData = null
var base_apply_on_enter := false
var base_apply_on_turn_start := false
var base_refresh_status_while_standing := false
var base_ai_danger_weight := 0.0
var dynamic_surface: DynamicSurface = DynamicSurface.NONE
var duration_turns := 0
var remaining_duration := 0
var active_effect: TerrainEffectData = null
var surface_id: StringName = &"none"
var visual_terrain_id: StringName = &""
var source_unit = null
var source_spell: Spell = null
var gameplay_flags: Dictionary = {}


func configure_base(cell_type: int, has_obstacle := false) -> void:
	base_cell_type = cell_type
	var properties: Dictionary = GridData.PROPERTIES.get(
		cell_type, {"walkable": false, "transparent": false}
	)
	base_walkable = bool(properties.get("walkable", false)) and not has_obstacle
	base_transparent = bool(properties.get("transparent", false))
	if has_obstacle:
		base_surface = BaseSurface.OBSTACLE
		return
	match cell_type:
		GridData.CellType.ICE:
			base_surface = BaseSurface.ICE
		GridData.CellType.LAVA:
			base_surface = BaseSurface.LAVA
		GridData.CellType.HOLE:
			base_surface = BaseSurface.VOID
		GridData.CellType.WALL:
			base_surface = BaseSurface.WALL
		_:
			base_surface = BaseSurface.NORMAL


func configure_base_terrain(
		terrain_id: StringName,
		cell_type: int,
		has_obstacle := false
	) -> void:
	base_terrain_id = terrain_id
	configure_base(cell_type, has_obstacle)
	if has_obstacle:
		return
	match terrain_id:
		&"water":
			base_surface = BaseSurface.WATER
		&"ice":
			base_surface = BaseSurface.ICE
		&"lava":
			base_surface = BaseSurface.LAVA
		&"poison":
			base_surface = BaseSurface.POISON
		&"steam":
			base_surface = BaseSurface.STEAM
		&"electrified_water":
			base_surface = BaseSurface.ELECTRIFIED_WATER
		&"void", &"hole":
			base_surface = BaseSurface.VOID
		&"wall":
			base_surface = BaseSurface.WALL


func configure_permanent_behavior(
		definition: ArenaTerrainDefinition,
		properties: Dictionary
	) -> void:
	base_walkable = bool(properties.get("walkable", base_walkable))
	base_transparent = bool(properties.get("transparent", base_transparent))
	base_projectile_passable = bool(properties.get(
		"projectile_passable", base_transparent
	))
	base_movement_cost = maxi(1, int(properties.get("movement_cost", 1)))
	if definition == null:
		return
	base_effect = definition.unit_effect
	base_apply_on_enter = definition.apply_on_enter
	base_apply_on_turn_start = definition.apply_on_turn_start
	base_refresh_status_while_standing = definition.refresh_status_while_standing
	base_ai_danger_weight = definition.ai_danger_weight


func configure(
		surface: DynamicSurface,
		duration: int,
		source,
		flags: Dictionary,
		effect: TerrainEffectData = null,
		stable_surface_id: StringName = &"none",
		visual_id: StringName = &"",
		spell: Spell = null
	) -> void:
	dynamic_surface = surface
	set_remaining_duration(duration)
	source_unit = source
	source_spell = spell
	active_effect = effect
	surface_id = stable_surface_id
	visual_terrain_id = visual_id
	gameplay_flags = flags.duplicate(true)


func set_remaining_duration(value: int) -> void:
	remaining_duration = value
	duration_turns = value


func clear_dynamic() -> void:
	dynamic_surface = DynamicSurface.NONE
	set_remaining_duration(0)
	active_effect = null
	surface_id = &"none"
	visual_terrain_id = &""
	source_unit = null
	source_spell = null
	gameplay_flags.clear()


func is_dynamic() -> bool:
	return surface_id != &"none"
