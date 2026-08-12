@tool
class_name ArenaBackdropCatalogService
extends RefCounted

const MANIFEST_ROOT := "res://addons/dungeon_draft_arena_studio/catalog/backdrops"


static func discover() -> Array[ArenaBackdropSourceDefinition]:
	var result: Array[ArenaBackdropSourceDefinition] = []
	var seen := {}
	_discover_resources(MANIFEST_ROOT, result, seen)
	_discover_resources("res://data/arenas", result, seen)
	_discover_rooms("res://data/rooms", result, seen)
	_discover_runs("res://data/runs", result, seen)
	result.sort_custom(func(a, b): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return result


static func _discover_resources(
		root: String,
		result: Array[ArenaBackdropSourceDefinition],
		seen: Dictionary
	) -> void:
	for path in _resource_paths(root):
		if path.begins_with("res://data/arenas/produced/"):
			continue
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var source: ArenaBackdropSourceDefinition = null
		if resource is ArenaBackdropSourceDefinition:
			source = resource as ArenaBackdropSourceDefinition
		elif resource is ArenaDefinition:
			source = ArenaBackdropSourceDefinition.from_arena(resource, path)
		_add(source, result, seen)


static func _discover_rooms(
		root: String,
		result: Array[ArenaBackdropSourceDefinition],
		seen: Dictionary
	) -> void:
	for path in _resource_paths(root):
		var room := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomData
		if room == null or room.painted_map_visual_data == null:
			continue
		var visual := room.painted_map_visual_data
		if visual.background_texture_path.is_empty():
			continue
		var source := ArenaBackdropSourceDefinition.new()
		source.source_id = visual.map_id
		source.display_name = room.room_name
		source.source_arena_path = path
		source.background_path = visual.background_texture_path
		source.source_image_size = visual.source_image_size
		source.grid_size = visual.logical_grid_size
		source.grid_origin = visual.grid_origin
		source.axis_x = visual.axis_x
		source.axis_y = visual.axis_y
		source.image_offset = visual.image_offset
		source.image_scale = visual.image_scale
		source.camera_offset = visual.camera_offset
		source.camera_zoom = visual.camera_zoom
		source.foreground_path = visual.foreground_texture_path
		source.occlusion_mask_path = visual.occlusion_mask_path
		source.foreground_offset = visual.foreground_offset
		source.foreground_scale = visual.foreground_scale
		source.foreground_occluder_polygon = visual.foreground_occluder_polygon.duplicate()
		source.foreground_occluder_sort_y = visual.foreground_occluder_sort_y
		source.foreground_full_hide_rect = visual.foreground_full_hide_rect
		source.foreground_available = not source.foreground_path.is_empty()
		_add(source, result, seen)


static func _discover_runs(
		root: String,
		result: Array[ArenaBackdropSourceDefinition],
		seen: Dictionary
	) -> void:
	for path in _resource_paths_shallow(root):
		# Un bundle produced incomplet ou un profil de test ne peut pas devenir
		# une source artistique canonique par simple découverte de catalogue.
		var source_text := FileAccess.get_file_as_string(path)
		if "/produced/" in source_text or "/profiles/test_" in source_text:
			continue
		var run := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as RunData
		if run == null:
			continue
		for room_index in range(run.rooms.size()):
			var room := run.rooms[room_index]
			if room == null or room.painted_map_visual_data == null:
				continue
			var visual := room.painted_map_visual_data
			if visual.background_texture_path.is_empty():
				continue
			var source := ArenaBackdropSourceDefinition.new()
			source.source_id = StringName("%s_room_%02d" % [
				path.get_file().get_basename(), room_index + 1,
			])
			source.display_name = "%s — salle %d — %s" % [
				run.run_name, room_index + 1, room.room_name,
			]
			source.source_run_path = path
			source.source_room_index = room_index
			source.background_path = visual.background_texture_path
			source.source_image_size = visual.source_image_size
			source.grid_size = visual.logical_grid_size
			source.grid_origin = visual.grid_origin
			source.axis_x = visual.axis_x
			source.axis_y = visual.axis_y
			source.image_offset = visual.image_offset
			source.image_scale = visual.image_scale
			source.camera_offset = visual.camera_offset
			source.camera_zoom = visual.camera_zoom
			source.foreground_path = visual.foreground_texture_path
			source.occlusion_mask_path = visual.occlusion_mask_path
			source.foreground_offset = visual.foreground_offset
			source.foreground_scale = visual.foreground_scale
			source.foreground_occluder_polygon = visual.foreground_occluder_polygon.duplicate()
			source.foreground_occluder_sort_y = visual.foreground_occluder_sort_y
			source.foreground_full_hide_rect = visual.foreground_full_hide_rect
			source.foreground_available = not source.foreground_path.is_empty()
			_add(source, result, seen)


static func _add(
		source: ArenaBackdropSourceDefinition,
		result: Array[ArenaBackdropSourceDefinition],
		seen: Dictionary
	) -> void:
	if source == null or not source.is_loadable():
		return
	var key := "%s|%s" % [source.source_id, source.background_path]
	if seen.has(key):
		return
	seen[key] = true
	result.append(source)


static func _resource_paths(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var path := root.path_join(name)
		if directory.current_is_dir() and not name.begins_with("."):
			result.append_array(_resource_paths(path))
		elif name.get_extension().to_lower() == "tres":
			result.append(path)
		name = directory.get_next()
	directory.list_dir_end()
	return result


static func _resource_paths_shallow(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	for name in directory.get_files():
		if name.get_extension().to_lower() == "tres":
			result.append(root.path_join(name))
	return result
