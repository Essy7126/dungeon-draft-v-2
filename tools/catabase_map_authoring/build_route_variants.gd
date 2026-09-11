extends Node
## Offline authoring: connected cuts inside the existing painted footprint.
const ROOT := "res://data/rooms/catabase_routes/"
var entries := { }


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	if "--repair-duplicates" in OS.get_cmdline_user_args():
		_repair_duplicates()
		get_tree().quit()
		return
	if DirAccess.dir_exists_absolute(ROOT):
		push_error("Output directory already exists; refusing to overwrite authored content.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	for seed_value in [2401, 1, 2, 9]:
		for node in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(node.kind) or int(node.depth) in [1, 7, 15, 20]:
				continue
			if entries.has(node.title):
				continue
			_build_room(node)
	_write(ROOT + "catalog.json", entries)
	_repair_duplicates()
	print("ROUTE_VARIANTS: ", entries.size())
	get_tree().quit()


func _build_room(node: Dictionary) -> void:
	var source := ExpeditionMapCatalog.get_room(node.room_index) as ArenaDefinition
	var arena := source.duplicate(true) as ArenaDefinition
	var key := "route_" + str(node.title).sha256_text().substr(0, 12)
	var folder := ROOT + key + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	arena.set_identity(node.title, key)
	var occupied := { }
	for item in arena.spawns:
		occupied[item.cell] = true
	for item in arena.obstacles:
		occupied[item.cell] = true
	for item in arena.decorations:
		occupied[item.cell] = true
	for cell in arena.calibration_cells:
		occupied[cell] = true
	var grid := EncounterGridFactory.build_from_room(source)
	var walkable := { }
	var candidates: Array[Vector2i] = []
	for definition in arena.cells:
		var cell: Vector2i = definition.coordinate
		if grid.is_walkable(cell):
			walkable[cell] = true
			if not occupied.has(cell) and grid.get_type(cell) == GridData.CellType.NORMAL:
				candidates.append(cell)
	# Stable identity, independent of lane mirroring and encounter seed.
	var variant := int(str(node.title).sha256_text().substr(0, 6).hex_to_int())
	var center := Vector2(arena.grid_size) * Vector2(
		0.3 + 0.2 * (variant % 3),
		0.35 + 0.25 * ((variant / 3) % 2),
	)
	var vertical := variant % 2 == 0
	candidates.sort_custom(
		func(a, b):
			return _cut_score(a, center, vertical) < _cut_score(b, center, vertical),
	)
	var removed: Array[Vector2i] = []
	var budget := maxi(8, walkable.size() / 7) + variant % 5
	for cell in candidates:
		if removed.size() >= budget:
			break
		walkable.erase(cell)
		if _connected(walkable):
			removed.append(cell)
		else:
			walkable[cell] = true
	arena.cells = arena.cells.filter(
		func(cell):
			return not removed.has(cell.coordinate),
	)
	var output_room := folder + "room.tres"
	assert(output_room.begins_with(ROOT) and not FileAccess.file_exists(output_room))
	assert(output_room != source.resource_path)
	arena.source_room_path = output_room
	arena.registered_terrain_plan_path = folder + "terrain_plan.json"
	arena.production_notes = "Disposition de trajet : " + str(node.title) + ". Décor et adversaires conservés."
	assert(ArenaRuntimeBridge.sync_runtime_resources(arena))
	var plan: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(source.registered_terrain_plan_path)
	)
	var manifest_path: String = plan.get("geometry_manifest_path", "geometry_manifest.json")
	if not manifest_path.begins_with("res://"):
		manifest_path = source.registered_terrain_plan_path.get_base_dir().path_join(manifest_path)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	manifest.title = node.title
	manifest.arena_id = key
	manifest.floor_cells = arena.cells.map(
		func(cell):
			return [cell.coordinate.x, cell.coordinate.y],
	)
	manifest.expected_floor_count = arena.cells.size()
	manifest.erase("ascii_rows")
	manifest.erase("expected_void_count")
	manifest.authoring_source = "res://tools/catabase_map_authoring/build_route_variants.gd"
	manifest.pits.append(
		{
			"id": "route_cut",
			"cells": removed.map(
				func(cell):
					return [cell.x, cell.y],
			),
		}
	)
	plan.geometry_manifest_path = "geometry_manifest.json"
	plan.metadata = plan.get("metadata", { })
	plan.metadata.tactical_intent = "Passage longitudinal avec contournement." if vertical else "Passage transversal avec contournement."
	_write(folder + "terrain_plan.json", plan)
	_write(folder + "geometry_manifest.json", manifest)
	assert(ResourceSaver.save(arena, output_room) == OK)
	entries[node.title] = {
		"room": arena.source_room_path,
		"base_room": source.resource_path,
		"removed_cells": removed.size(),
	}


func _cut_score(cell: Vector2i, center: Vector2, vertical: bool) -> float:
	var delta := (Vector2(cell) - center).abs()
	return delta.x * 5.0 + delta.y if vertical else delta.y * 5.0 + delta.x


func _connected(cells: Dictionary) -> bool:
	if cells.is_empty():
		return false
	var pending: Array = [cells.keys()[0]]
	var seen := { pending[0]: true }
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				pending.append(next)
	return seen.size() == cells.size()


func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t") + "\n")


func _repair_duplicates() -> void:
	var catalog: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(ROOT + "catalog.json")
	)
	var seen := { }
	for title in catalog:
		var path: String = catalog[title].room
		assert(path.begins_with(ROOT) and path.ends_with("/room.tres"))
		var arena := load(path) as ArenaDefinition
		var signature := str(
			arena.cells.map(
				func(cell):
					return cell.coordinate,
			)
		)
		if seen.has(signature):
			var grid := EncounterGridFactory.build_from_room(arena)
			var walkable := { }
			var occupied := { }
			for item in arena.spawns + arena.obstacles + arena.decorations:
				occupied[item.cell] = true
			for cell in arena.calibration_cells:
				occupied[cell] = true
			for definition in arena.cells:
				if grid.is_walkable(definition.coordinate):
					walkable[definition.coordinate] = true
			for definition in arena.cells.duplicate():
				var cell: Vector2i = definition.coordinate
				if occupied.has(cell) or grid.get_type(cell) != GridData.CellType.NORMAL:
					continue
				walkable.erase(cell)
				if not _connected(walkable):
					walkable[cell] = true
					continue
				arena.cells.erase(definition)
				var manifest_path := path.get_base_dir().path_join("geometry_manifest.json")
				var manifest: Dictionary = JSON.parse_string(
					FileAccess.get_file_as_string(manifest_path)
				)
				manifest.floor_cells = arena.cells.map(
					func(item):
						return [item.coordinate.x, item.coordinate.y],
				)
				manifest.expected_floor_count = arena.cells.size()
				manifest.pits.append({ "id": "route_distinction", "cells": [[cell.x, cell.y]] })
				_write(manifest_path, manifest)
				assert(ArenaRuntimeBridge.sync_runtime_resources(arena))
				assert(ResourceSaver.save(arena, path) == OK)
				catalog[title].removed_cells += 1
				print("Distinct route repaired: ", title)
				break
		seen[
			str(
				arena.cells.map(
					func(cell):
						return cell.coordinate,
				)
			)
		] = true
	_write(ROOT + "catalog.json", catalog)
