@tool
class_name ArenaLegacyImporter
extends RefCounted

const PRODUCTION_ROOMS := {
	&"room_01_forest": "res://data/rooms/first_run_room_01.tres",
	&"room_05_volcano": "res://data/rooms/room_05_volcano.tres",
	&"room_06_space": "res://data/rooms/room_06_space.tres",
}


static func import_production(arena_id: StringName) -> ArenaDefinition:
	return import_room(str(PRODUCTION_ROOMS.get(arena_id, "")))


static func import_room(room_path: String) -> ArenaDefinition:
	if not ResourceLoader.exists(room_path):
		return null
	var room := load(room_path) as RoomData
	if room == null or room.grid_layout == null or room.painted_map_visual_data == null:
		return null
	var layout: RoomGridLayout = room.grid_layout
	var visual: PaintedMapVisualData = room.painted_map_visual_data
	var arena := ArenaDefinition.new()
	arena.set_identity(room.room_name, str(layout.layout_id))
	arena.source_room_path = room_path
	arena.background_path = visual.background_texture_path
	arena.source_image_size = visual.source_image_size
	arena.grid_size = layout.logical_size
	arena.grid_origin = visual.grid_origin
	arena.axis_x = visual.axis_x
	arena.axis_y = visual.axis_y
	arena.image_offset = visual.image_offset
	arena.image_scale = visual.image_scale
	arena.foreground_path = visual.foreground_texture_path
	arena.foreground_offset = visual.foreground_offset
	arena.foreground_scale = visual.foreground_scale
	arena.foreground_occluder_polygon = visual.foreground_occluder_polygon.duplicate()
	arena.foreground_occluder_sort_y = visual.foreground_occluder_sort_y
	arena.foreground_full_hide_rect = visual.foreground_full_hide_rect
	arena.camera_offset = visual.camera_offset
	arena.camera_zoom = visual.camera_zoom
	arena.calibration_cells = visual.calibration_cells.duplicate()
	arena.calibration_pixels = visual.calibration_pixels.duplicate()
	arena.presentation_profile_path = visual.presentation_profile.resource_path \
		if visual.presentation_profile != null else ArenaDefinition.DEFAULT_PRESENTATION
	arena.source_visual_path = visual.resource_path
	arena.encounter_definition = room.encounter_definition
	arena.battle_scene = room.battle_scene
	arena.enemies = room.enemies.duplicate()
	for y in range(layout.logical_size.y):
		for x in range(layout.logical_size.x):
			var cell := Vector2i(x, y)
			var symbol := layout.symbol_at(cell)
			if symbol == RoomGridLayout.VOID:
				continue
			var definition := arena.ensure_cell(cell)
			definition.cell_type = layout.resolved_cell_type(cell)
			definition.playable = bool(
				GridData.PROPERTIES[definition.cell_type]["walkable"]
			)
			if definition.cell_type != GridData.CellType.NORMAL or not definition.playable:
				definition.production_note = (
					"Override explicite preserve depuis RoomGridLayout '%s' (%s)." % [
						layout.layout_id, symbol,
					]
				)
			if symbol in [RoomGridLayout.BLOCKED, RoomGridLayout.LANDMARK]:
				var obstacle := ArenaObstacleDefinition.new()
				obstacle.cell = cell
				obstacle.obstacle_id = StringName("legacy_%d_%d" % [x, y])
				obstacle.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
				arena.obstacles.append(obstacle)
	_import_spawn_zone(arena, room.hero_spawn_zone, true)
	_import_spawn_zone(arena, room.enemy_spawn_zone, false)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


static func copy_template(template: ArenaDefinition, new_name: String) -> ArenaDefinition:
	if template == null:
		return null
	var copied := ArenaDefinition.new()
	var snapshot := template.to_snapshot()
	snapshot["display_name"] = new_name
	snapshot["arena_id"] = ArenaDefinition.sanitize_id(new_name)
	snapshot["source_room_path"] = ""
	snapshot["source_visual_path"] = ""
	copied.restore_snapshot(snapshot)
	ArenaRuntimeBridge.sync_runtime_resources(copied)
	return copied


static func _import_spawn_zone(
		arena: ArenaDefinition,
		zone: Array[Vector2i],
		heroes: bool
	) -> void:
	for index in range(zone.size()):
		var spawn := ArenaSpawnDefinition.new()
		spawn.cell = zone[index]
		spawn.spawn_id = StringName(
			"legacy_%s_%d" % ["hero" if heroes else "enemy", index]
		)
		if heroes:
			spawn.kind = index % 3
			spawn.unit_id = ArenaEditingService.HERO_IDS[index % 3]
			spawn.required = index < 3
		else:
			spawn.kind = ArenaSpawnDefinition.Kind.ENEMY_GROUP
			spawn.unit_id = &"encounter_enemy"
			spawn.group_id = &"legacy_enemy_pool"
		arena.spawns.append(spawn)
