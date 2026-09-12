class_name ExpeditionRouteState
extends RefCounted

const Catalog = preload("res://core/expedition/expedition_route_catalog.gd")
const SNAPSHOT_VERSION := 2
const VALID_PHASES: Array[String] = ["map", "combat", "reward", "complete"]

var seed: int = 0
## Catalogue for authoring/integration. UI must use get_visible_nodes instead.
var nodes: Array[Dictionary] = []
var current_node_id: String = ""
var completed_node_ids: Array[String] = []
var revealed_node_ids: Array[String] = []
var phase: String = "map"
var last_restore_error: String = ""

var _canonical_nodes: Array[Dictionary] = []
var _nodes_by_id: Dictionary = {}
var _graph_fingerprint: String = ""
var _catalog_revision: int = Catalog.REVISION


func initialize(seed_value: int, catalog_revision: int = Catalog.REVISION) -> void:
	# A 31-bit seed survives JSON number round trips without precision loss.
	seed = seed_value & 0x7fffffff
	_catalog_revision = catalog_revision
	_canonical_nodes = Catalog.create_nodes(seed, _catalog_revision)
	nodes = _canonical_nodes.duplicate(true)
	_nodes_by_id.clear()
	for node in _canonical_nodes:
		_nodes_by_id[String(node["id"])] = node
	_graph_fingerprint = JSON.stringify(_canonical_nodes).sha256_text()
	current_node_id = ""
	completed_node_ids.clear()
	revealed_node_ids.clear()
	phase = "map"
	last_restore_error = ""


## These are safe previews, not resolved unknown content.
func get_available_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if phase != "map":
		return result
	for node_id in _available_ids():
		result.append(_preview(_nodes_by_id[node_id]))
	return result


func get_visible_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in _canonical_nodes:
		if _is_discovered(node):
			result.append(_preview(node))
	return result


## Opportunity costs use only discovered previews, never resolved unknown content.
func get_choice_preview(node_id: String) -> Dictionary:
	var options := get_available_nodes()
	if options.size() < 2 or node_id not in _available_ids():
		return {}
	var visible := {}
	for node in get_visible_nodes():
		visible[str(node.id)] = node
	var branches := {}
	for option in options:
		branches[str(option.id)] = _visible_descendants(str(option.id), visible)
	var selected: Dictionary = branches[node_id]
	var join_depth := Catalog.DEPTH_COUNT + 1
	for id in selected:
		var shared := true
		for branch in branches.values():
			if not branch.has(id):
				shared = false
		if shared:
			join_depth = mini(join_depth, int(visible[id].depth))
	var accessible: Array[String] = []
	var foregone: Array[String] = []
	var path_ids: Array[String] = []
	var names := {"hub": "refuge", "merchant": "marchand", "sanctuary": "sanctuaire", "lore": "mémoire", "cache": "cache", "event": "rencontre"}
	for id in selected:
		if int(visible[id].depth) <= join_depth:
			path_ids.append(str(id))
		if int(visible[id].depth) < join_depth and names.has(str(visible[id].kind)):
			var label := str(names[str(visible[id].kind)])
			if label not in accessible:
				accessible.append(label)
	for branch in branches.values():
		for id in branch:
			if selected.has(id) or int(visible[id].depth) >= join_depth:
				continue
			var kind := str(visible[id].kind)
			if names.has(kind) and str(names[kind]) not in accessible and str(names[kind]) not in foregone:
				foregone.append(str(names[kind]))
	accessible.sort()
	foregone.sort()
	var lines: Array[String] = []
	if not accessible.is_empty():
		lines.append("Haltes accessibles : " + ", ".join(accessible) + ".")
	if not foregone.is_empty():
		lines.append("Haltes écartées : " + ", ".join(foregone) + ".")
	if join_depth <= Catalog.DEPTH_COUNT:
		lines.append("Jonction au seuil %02d." % join_depth)
	return {"join_depth": join_depth, "accessible_halts": accessible, "foregone_halts": foregone,
		"path_ids": path_ids, "summary": "\n".join(lines)}


func _visible_descendants(start_id: String, visible: Dictionary) -> Dictionary:
	var reached := {}
	var pending: Array[String] = [start_id]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if reached.has(id) or not visible.has(id):
			continue
		reached[id] = true
		for edge in visible[id].edges:
			pending.append(str(edge))
	return reached


func get_current_node() -> Dictionary:
	return _nodes_by_id.get(current_node_id, {}).duplicate(true)


func choose_node(node_id: String) -> bool:
	if phase != "map" or node_id not in _available_ids():
		return false
	var node: Dictionary = _nodes_by_id[node_id]
	current_node_id = node_id
	phase = "combat" if Catalog.is_combat(String(node["kind"])) else "reward"
	return true


func mark_combat_won() -> bool:
	if phase != "combat" or not Catalog.is_combat(String(get_current_node().get("kind", ""))):
		return false
	phase = "reward"
	return true


func complete_current_node() -> bool:
	if phase != "reward" or current_node_id.is_empty() or current_node_id in completed_node_ids:
		return false
	var node := get_current_node()
	if node.is_empty() or int(node["depth"]) != completed_node_ids.size() + 1:
		return false
	completed_node_ids.append(current_node_id)
	phase = "complete" if int(node["depth"]) == Catalog.DEPTH_COUNT else "map"
	return true


func reveal_hidden_node(node_id: String) -> bool:
	var node: Dictionary = _nodes_by_id.get(node_id, {})
	if node.is_empty() or not bool(node["hidden"]) or node_id in revealed_node_ids:
		return false
	if int(node["depth"]) <= completed_node_ids.size() or phase == "complete":
		return false
	revealed_node_ids.append(node_id)
	return true


## Returns an identifier so an event can name the passage it actually discovered.
func reveal_next_hidden_node() -> String:
	for node in _canonical_nodes:
		if bool(node["hidden"]) and reveal_hidden_node(String(node["id"])):
			return String(node["id"])
	return ""


func to_snapshot() -> Dictionary:
	return {"version": SNAPSHOT_VERSION, "catalog_revision": _catalog_revision,
		"seed": seed, "graph_fingerprint": _graph_fingerprint, "phase": phase,
		"current_node_id": current_node_id, "completed_node_ids": completed_node_ids.duplicate(),
		"revealed_node_ids": revealed_node_ids.duplicate()}


## No mutation is committed before the regenerated graph and whole path validate.
func restore_snapshot(snapshot: Dictionary) -> bool:
	last_restore_error = ""
	if not _is_integer(snapshot.get("version")) or int(snapshot["version"]) != SNAPSHOT_VERSION:
		return _reject("Version de sauvegarde d'expédition inconnue.")
	if not _is_integer(snapshot.get("catalog_revision")) or int(snapshot["catalog_revision"]) not in [2, 3, 4, Catalog.REVISION]:
		return _reject("Le catalogue de cette expédition n'est plus compatible.")
	if not _is_integer(snapshot.get("seed")) or int(snapshot["seed"]) < 0 or int(snapshot["seed"]) > 0x7fffffff:
		return _reject("Graine d'expédition invalide.")
	if not snapshot.get("phase") is String or String(snapshot["phase"]) not in VALID_PHASES:
		return _reject("Phase d'expédition invalide.")
	if not snapshot.get("current_node_id") is String:
		return _reject("Destination courante invalide.")
	if not _is_string_array(snapshot.get("completed_node_ids")) or not _is_string_array(snapshot.get("revealed_node_ids")):
		return _reject("Historique ou révélations invalides.")
	var candidate := ExpeditionRouteState.new()
	candidate.initialize(int(snapshot["seed"]), int(snapshot["catalog_revision"]))
	if snapshot.get("graph_fingerprint", "") != candidate._graph_fingerprint:
		return _reject("Le graphe ne correspond pas à sa graine.")
	for revealed_id in snapshot["revealed_node_ids"]:
		if not candidate.reveal_hidden_node(String(revealed_id)):
			return _reject("Passage secret invalide ou dupliqué.")
	for completed_id in snapshot["completed_node_ids"]:
		if not candidate.choose_node(String(completed_id)):
			return _reject("L'historique emprunte une connexion inaccessible.")
		if candidate.phase == "combat":
			candidate.mark_combat_won()
		if not candidate.complete_current_node():
			return _reject("L'historique contient une étape incohérente.")
	var restored_phase := String(snapshot["phase"])
	var restored_current := String(snapshot["current_node_id"])
	if restored_phase in ["combat", "reward"]:
		if not candidate.choose_node(restored_current):
			return _reject("La destination engagée n'est pas accessible.")
		if restored_phase == "reward" and candidate.phase == "combat":
			candidate.mark_combat_won()
	if candidate.phase != restored_phase or candidate.current_node_id != restored_current:
		return _reject("La phase et la destination ne correspondent pas au parcours.")
	seed = candidate.seed
	_catalog_revision = candidate._catalog_revision
	_canonical_nodes = candidate._canonical_nodes
	_nodes_by_id = candidate._nodes_by_id
	_graph_fingerprint = candidate._graph_fingerprint
	nodes = _canonical_nodes.duplicate(true)
	current_node_id = candidate.current_node_id
	completed_node_ids = candidate.completed_node_ids.duplicate()
	revealed_node_ids = candidate.revealed_node_ids.duplicate()
	phase = candidate.phase
	return true


func _available_ids() -> Array[String]:
	var result: Array[String] = []
	if completed_node_ids.is_empty():
		for node in _canonical_nodes:
			if int(node["depth"]) == 1 and _is_discovered(node):
				result.append(String(node["id"]))
		return result
	var previous: Dictionary = _nodes_by_id.get(completed_node_ids.back(), {})
	for next_id in previous.get("edges", []):
		if _is_discovered(_nodes_by_id[next_id]):
			result.append(String(next_id))
	return result


func _preview(node: Dictionary) -> Dictionary:
	var result := node.duplicate(true)
	result.erase("service_profile")
	var node_id := String(node["id"])
	var visited := node_id == current_node_id or node_id in completed_node_ids
	var in_horizon := int(node["depth"]) <= completed_node_ids.size() + 2
	var landmark := int(node["depth"]) in [7, 15, 20] or Catalog.is_halt(String(node["kind"]))
	var uncertain := bool(node["uncertain"]) and not visited
	result["visited"] = visited
	result["completed"] = node_id in completed_node_ids
	result["available"] = phase == "map" and node_id in _available_ids()
	result["knowledge"] = "revealed" if visited else ("unknown" if uncertain else ("near" if in_horizon else "distant"))
	result["presentation_kind"] = "hidden" if bool(node["hidden"]) else String(node["kind"])
	var visible_edges: Array[String] = []
	for edge in node["edges"]:
		if _is_discovered(_nodes_by_id[edge]):
			visible_edges.append(String(edge))
	result["edges"] = visible_edges
	if not visited:
		# Source map choice is never useful player information before engagement.
		result["room_index"] = -1
		if uncertain:
			result["kind"] = "unknown"
			result["presentation_kind"] = "unknown"
			result["title"] = "Rencontre inconnue" if in_horizon else "Échos incertains"
		if not in_horizon:
			result["reward"] = "unknown"
			result["hint"] = "Récompense encore inconnue"
			if not landmark:
				result["kind"] = "unknown"
				result["presentation_kind"] = "unknown"
				result["title"] = "Destination lointaine"
	return result


func _is_discovered(node: Dictionary) -> bool:
	return not bool(node["hidden"]) or String(node["id"]) in revealed_node_ids


func _reject(message: String) -> bool:
	last_restore_error = message
	return false


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry in value:
		if not entry is String:
			return false
	return true
