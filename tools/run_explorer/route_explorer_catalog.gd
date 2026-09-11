extends RefCounted
## Read-only joins against the production route, map and halt authorities.
const HaltCatalog = preload("res://core/expedition/painted_halt_catalog.gd")
const Encounters = preload("res://core/expedition/catabase_monster_encounter_catalog.gd")
const KINDS := {
	"normal": "Combat",
	"elite": "Élite",
	"boss": "Boss",
	"hub": "Repos",
	"merchant": "Marchand",
	"sanctuary": "Sanctuaire",
	"lore": "Mémoire",
	"entry": "Entrée",
}


class AuditRoute extends ExpeditionRouteState:
	func get_visible_nodes() -> Array[Dictionary]:
		var result: Array[Dictionary] = nodes.duplicate(true)
		for node in result:
			node.merge(
				{ "completed": false, "visited": false, "available": true, "uncertain": false },
				true,
			)
		return result


	func get_available_nodes() -> Array[Dictionary]:
		return get_visible_nodes()


	func get_choice_preview(node_id: String) -> Dictionary:
		var visible := { }
		for node in nodes:
			visible[str(node.id)] = node
		return { "path_ids": _visible_descendants(node_id, visible).keys() }


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { }
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else { }


static func describe(node: Dictionary) -> Dictionary:
	var result := {
		"node": node.duplicate(true),
		"title": str(node.title),
		"kind": KINDS.get(str(node.kind), str(node.kind)),
		"room": "",
		"plan": "",
		"image": "",
		"geometry": { },
		"intent": "",
		"decor": "Écran de halte générique",
		"pack": { },
		"manifest": "",
	}
	if str(node.kind) == "entry":
		result.manifest = "res://data/halts/underworld_threshold_v1.json"
	elif ExpeditionRouteCatalog.is_combat(str(node.kind)):
		var index := int(node.room_index)
		if index < 0 or index >= ExpeditionMapCatalog.ROOM_COUNT:
			return { }
		var room := ExpeditionMapCatalog.get_room_for_node(node) as ArenaDefinition
		if room == null:
			return { }
		result.room = room.resource_path
		result.plan = room.registered_terrain_plan_path
		var plan := read_json(str(result.plan))
		var geometry_path := str(plan.get("geometry_manifest_path", "geometry_manifest.json"))
		if not geometry_path.begins_with("res://"):
			geometry_path = str(result.plan).get_base_dir().path_join(geometry_path)
		result.geometry = read_json(geometry_path)
		result.decor = str(result.geometry.get("title", room.room_name))
		result.image = str(plan.get("land", { }).get("texture_path", ""))
		result.intent = str(plan.get("metadata", { }).get("tactical_intent", ""))
		result.pack = Encounters.encounter_preview(node)
		if result.pack.is_empty():
			var encounter := room.get_encounter_for_wave(0)
			var roster: Array[String] = []
			for unit in encounter.expanded_roster():
				roster.append(str(unit.unit_name))
			result.pack = { "name": "Rencontre canonique", "summary": ", ".join(roster) }
	else:
		result.manifest = HaltCatalog.manifest_for(node)
		if str(node.id) == "d04_1" and str(node.kind) == "merchant":
			result.decor = "La Halle sous les racines"
			result.image = "res://asset/map/painted/merchant/hall_v1/hall.png"
	if not str(result.manifest).is_empty():
		var manifest := read_json(str(result.manifest))
		result.decor = str(manifest.get("title", node.title))
		result.image = str(manifest.get("source", { }).get("image", ""))
	return result


static func entry() -> Dictionary:
	return {
		"id": "entry",
		"depth": 0,
		"kind": "entry",
		"title": "Le Seuil des Ombres",
		"room_index": -1,
		"hidden": false,
		"uncertain": false,
		"edges": ["d01_0"],
	}


static func path_to(nodes: Array[Dictionary], target: String) -> Array[String]:
	var previous := { "d01_0": "" }
	var pending: Array[String] = ["d01_0"]
	var by_id := { }
	for node in nodes:
		by_id[str(node.id)] = node
	while not pending.is_empty():
		var id: String = pending.pop_front()
		if id == target:
			var result: Array[String] = []
			while not id.is_empty():
				result.push_front(id)
				id = str(previous[id])
			return result
		for edge in by_id[id].edges:
			if not previous.has(str(edge)):
				previous[str(edge)] = id
				pending.append(str(edge))
	return []
