@tool
class_name PaintedHaltDocument
extends RefCounted

## Normalized working copy. Studio history stores complete gestures, never pixels.
signal changed

const LAYERS := [
	"outline",
	"obstacles",
	"water",
	"exclusions",
	"cascades",
	"foliage",
	"bounce",
	"foreground",
	"torches",
	"spawn",
	"landmarks",
]
const LABELS := [
	"Allées",
	"Obstacles",
	"Eau",
	"Exclusions eau",
	"Cascades",
	"Feuillage",
	"Reflets",
	"Premiers plans",
	"Torches",
	"Arrivée",
	"Interactions",
]

var manifest: Dictionary = { }
var source_path := ""
var source_hash := ""
var history := StudioHistoryController.new()


func _init() -> void:
	history.configure(_restore, fingerprint)


func load_working_copy(value: Dictionary, path := "", hash_value := "") -> void:
	manifest = value.duplicate(true)
	source_path = path
	source_hash = hash_value
	history.clear()
	history.set_saved_fingerprint(fingerprint())
	changed.emit()


func fingerprint() -> String:
	return JSON.stringify(manifest, "", true).sha256_text()


func is_dirty() -> bool:
	return fingerprint() != history.get_saved_fingerprint()


func commit(before: Dictionary, action: String) -> void:
	# A current authored for a whole pool follows its edited outline.
	var previous_pools: Array = before.get("water", { }).get("polygons", [])
	var pools: Array = manifest.get("water", { }).get("polygons", [])
	for region: Dictionary in manifest.get("water", { }).get("regions", []):
		var index := previous_pools.find(region.get("polygon", []))
		if index >= 0 and index < pools.size() and previous_pools.size() == pools.size():
			region.polygon = pools[index].duplicate(true)
	history.record(
		action,
		before,
		manifest,
		true,
		"",
		JSON.stringify(before, "", true).sha256_text(),
		fingerprint(),
	)
	changed.emit()


func _restore(value: Dictionary) -> void:
	manifest = value.duplicate(true)
	changed.emit()


func shapes(layer: String) -> Array:
	match layer:
		"outline":
			return [manifest.get("navigation", { }).get("outline", [])]
		"obstacles":
			return manifest.get("navigation", { }).get("obstacles", [])
		"water":
			return manifest.get("water", { }).get("polygons", [])
		"exclusions":
			return manifest.get("water", { }).get("exclusions", [])
		"spawn":
			return [manifest.get("world", { }).get("spawn", [0.5, 0.8])]
	return manifest.get(layer, [])


func is_anchor(layer: String) -> bool:
	return layer in ["torches", "spawn", "landmarks"]


func points(layer: String, index: int) -> Array:
	var entries := shapes(layer)
	if index < 0 or index >= entries.size():
		return []
	var entry: Variant = entries[index]
	if layer == "spawn":
		return [entry] if entry.size() == 2 else []
	if is_anchor(layer):
		return [entry.get("point", [0.5, 0.5])]
	if entry is Dictionary:
		return entry.get("polygon", [])
	return entry


func set_point(layer: String, shape_index: int, point_index: int, value: Vector2) -> void:
	var normalized := [
		snappedf(clampf(value.x, 0.0, 1.0), 0.000001),
		snappedf(clampf(value.y, 0.0, 1.0), 0.000001),
	]
	if layer == "spawn":
		manifest.world.spawn = normalized
	elif is_anchor(layer):
		shapes(layer)[shape_index]["point"] = normalized
	else:
		points(layer, shape_index)[point_index] = normalized


func add_shape(layer: String, polygon: Array) -> int:
	var before := manifest.duplicate(true)
	var index := shapes(layer).size()
	match layer:
		"outline":
			manifest.navigation.outline = polygon.duplicate(true)
			index = 0
		"spawn":
			manifest.world.spawn = polygon[0].duplicate()
			index = 0
		"cascades":
			manifest.cascades.append(
				{
					"polygon": polygon.duplicate(true),
					"splash": polygon[-1].duplicate(),
					"width": 20,
				}
			)
		"foreground":
			manifest.foreground.append(
				{ "polygon": polygon.duplicate(true), "anchor": polygon[-1].duplicate() }
			)
		"torches":
			if index >= 12:
				return -1
			manifest.torches.append(
				{
					"id": _unique_id(layer, "torch"),
					"point": polygon[0].duplicate(),
					"radius": [0.007, 0.03],
					"phase": index * 0.7,
				}
			)
		"landmarks":
			manifest.landmarks.append(
				{
					"id": _unique_id(layer, "place"),
					"title": "Nouveau lieu",
					"point": polygon[0].duplicate(),
					"action": "dialogue",
					"description": "Un lieu à découvrir.",
					"focus": [polygon[0][0], maxf(0.0, polygon[0][1] - 0.06)],
					"radius": 0.045,
				}
			)
		_:
			shapes(layer).append(polygon.duplicate(true))
	commit(before, "Créer « %s »" % LABELS[LAYERS.find(layer)])
	return index


func _unique_id(layer: String, prefix: String) -> String:
	var candidate := 1
	var ids: Array = shapes(layer).map(
		func(entry):
			return str(entry.get("id", "")),
	)
	while "%s_%d" % [prefix, candidate] in ids:
		candidate += 1
	return "%s_%d" % [prefix, candidate]


func remove_shape(layer: String, index: int) -> bool:
	if layer in ["outline", "spawn"] or index < 0 or index >= shapes(layer).size():
		return false
	var before := manifest.duplicate(true)
	if layer == "water":
		var regions: Array = manifest.get("water", { }).get("regions", [])
		for region_index in range(regions.size() - 1, -1, -1):
			if regions[region_index].get("polygon", []) == shapes(layer)[index]:
				regions.remove_at(region_index)
	shapes(layer).remove_at(index)
	commit(before, "Supprimer la zone")
	return true


func insert_point(layer: String, index: int, after: int, value: Vector2) -> bool:
	if is_anchor(layer) or index < 0:
		return false
	var before := manifest.duplicate(true)
	points(layer, index).insert(after + 1, [clampf(value.x, 0, 1), clampf(value.y, 0, 1)])
	commit(before, "Ajouter un sommet")
	return true


func remove_point(layer: String, index: int, vertex: int) -> bool:
	if is_anchor(layer) or index < 0 or vertex < 0:
		return false
	var polygon := points(layer, index)
	if polygon.size() <= 3:
		return false
	var before := manifest.duplicate(true)
	polygon.remove_at(vertex)
	commit(before, "Supprimer un sommet")
	return true


func set_property(path: Array, value: Variant) -> void:
	var before := manifest.duplicate(true)
	var owner: Variant = manifest
	for i in path.size() - 1:
		if owner is Dictionary and not owner.has(path[i]):
			owner[path[i]] = { }
		owner = owner[path[i]]
	owner[path[-1]] = value
	commit(before, "Régler %s" % str(path[-1]))


func water_region_index(pool_index: int) -> int:
	if pool_index < 0 or pool_index >= shapes("water").size():
		return -1
	var regions: Array = manifest.get("water", { }).get("regions", [])
	for index in regions.size():
		if regions[index].get("polygon", []) == shapes("water")[pool_index]:
			return index
	return -1


func create_water_region(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= shapes("water").size() or water_region_index(pool_index) >= 0:
		return
	var before := manifest.duplicate(true)
	if not manifest.water.has("regions"):
		manifest.water.regions = []
	manifest.water.regions.append(
		{
			"polygon": shapes("water")[pool_index].duplicate(true),
			"direction": [1, 0],
			"speed": 1.0,
		}
	)
	commit(before, "Définir le courant du bassin")
