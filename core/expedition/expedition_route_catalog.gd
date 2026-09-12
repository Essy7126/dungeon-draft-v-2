class_name ExpeditionRouteCatalog
extends RefCounted
## Ordinary paths: 15 fights / 5 halts; optional exchanges: 14–16 / 6–4.
const REVISION := 5
const DEPTH_COUNT := 20
const COMBAT_KINDS: Array[String] = ["normal", "elite", "boss"]
const HALT_KINDS: Array[String] = ["hub", "merchant", "sanctuary", "lore", "cache", "event"]
const HALT_DEPTHS := [4, 8, 12, 16, 19]
const MAP_BY_DEPTH := {1: 0, 2: 5, 3: 1, 5: 6, 6: 7, 7: 2, 9: 8, 10: 9, 11: 3, 13: 10, 14: 11, 15: 12, 16: 13, 17: 13, 18: 14, 20: 4}


static func create_nodes(seed_value: int, revision: int = REVISION) -> Array[Dictionary]:
	if revision >= 4:
		return preload("res://core/expedition/expedition_route_itineraries.gd").create_nodes(seed_value, MAP_BY_DEPTH, revision >= 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layers: Array = [
		[_entry("normal", "Le seuil de Catabase", "melee", 0, "Premier combat · le kit d'Achille")],
		[_fight(2, "Le portique des lances", "melee"), _fight(2, "Les éclaireurs du portique", "ranged")],
		[_fight(3, "Les guetteurs du Léthé", "mobility"), _fight(3, "Le tribut du passeur", "armor", true)],
		[_halt("hub", "Le camp des compagnons", "healing"), _halt("merchant", "L'étal du passeur", "armor"), _halt("lore", "La stèle des noms", "discovery")],
		[_fight(5, "Le gué des serments", "control"), _fight(5, "Les roseaux du tireur", "ranged")],
		[_fight(6, "L'atrium des cendres", "vitality"), _fight(6, "Les gardiens du foyer", "elemental", false, true)],
		[_fight(7, "L'épreuve du bronze", "signature", true)],
		[_halt("sanctuary", "L'autel des serments", "discovery"), _halt("merchant", "La forge des cuirasses", "armor"), _halt("lore", "La mémoire de Chiron", "elemental", true)],
		[_fight(9, "Le cloître des absents", "healing"), _fight(9, "Les pas sans retour", "mobility")],
		[_fight(10, "Les arches du poursuivant", "ranged"), _fight(10, "Les chaînes sous les arches", "control", true)],
		[_fight(11, "La fosse des revenants", "vitality"), _halt("lore", "La bibliothèque engloutie", "discovery", true)],
		[_halt("hub", "Le bivouac des six mémoires", "healing"), _halt("sanctuary", "Le pacte du sixième geste", "elemental")],
		[_fight(13, "Les terrasses de l'orage", "elemental"), _fight(13, "Le rempart des terrasses", "armor")],
		[_fight(14, "Le pont des longs traits", "ranged"), _fight(14, "Le pont des fers croisés", "melee", true)],
		[_fight(15, "L'épreuve des obélisques", "signature", true)],
		[_halt("merchant", "Le marché du dernier feu", "armor"), _halt("hub", "Le foyer des revenants", "healing"), _fight(16, "Le défi sans repos", "signature", true, true)],
		[_fight(17, "Le jardin des dalles fendues", "mobility"), _fight(17, "La garde du jardin", "armor")],
		[_fight(18, "Le vestibule des derniers noms", "control"), _fight(18, "Le vestibule des lances noires", "melee", true)],
		[_halt("hub", "Le feu avant Pâris", "healing"), _halt("sanctuary", "L'ultime offrande", "discovery"), _halt("merchant", "L'obole du dernier passage", "armor")],
		[_entry("boss", "Pâris — le seuil de la Catabase", "victory", 4, "Épreuve finale")],
	]
	var nodes: Array[Dictionary] = []
	var layer_ids: Array = []
	for depth_index in layers.size():
		var entries: Array = layers[depth_index]
		if entries.size() > 1 and rng.randi_range(0, 1) == 1:
			entries.reverse()
		var ids: Array[String] = []
		for lane in entries.size():
			var node: Dictionary = entries[lane].duplicate(true)
			# Unknown content is rolled once. Restoring/inspecting never adapts it to the build.
			if bool(node.uncertain) and depth_index + 1 == 11 and rng.randi_range(0, 1) == 1:
				node.kind = "normal"
				node.title = "Les gardiens de la bibliothèque"
				node.room_index = MAP_BY_DEPTH[11]
			if bool(node.uncertain) and depth_index + 1 == 16 and rng.randi_range(0, 1) == 1:
				node.kind = "sanctuary"
				node.title = "Le défi du serment muet"
				node.room_index = -1
			if bool(node.uncertain):
				node.hint = "Nature inconnue · combat ou halte possible"
			node.merge({"id": "d%02d_%d" % [depth_index + 1, lane], "depth": depth_index + 1,
				"lane": lane, "hidden": false, "edges": [] as Array[String]})
			ids.append(String(node.id))
			nodes.append(node)
		layer_ids.append(ids)
	for depth_index in layer_ids.size() - 1:
		var current_ids: Array = layer_ids[depth_index]
		var next_ids: Array = layer_ids[depth_index + 1]
		for lane in current_ids.size():
			var edges: Array[String] = []
			for destination in _destinations(lane, current_ids.size(), next_ids.size()):
				edges.append(String(next_ids[destination]))
			# Join paired lanes with one diagonal; never draw an ambiguous X.
			# Revision 2 stays reproducible for existing saves.
			if revision >= 3 and current_ids.size() == 2 and next_ids.size() == 2:
				if lane == (depth_index + seed_value) % 2:
					edges.append(String(next_ids[1 - lane]))
					edges.sort()
			_find(nodes, String(current_ids[lane])).edges = edges
	_add_secret(nodes, layer_ids, 8, "L'atelier sous la racine", "elemental", "sanctuary")
	_add_secret(nodes, layer_ids, 16, "Le tombeau du serment intact", "discovery", "lore")
	return nodes


static func is_combat(kind: String) -> bool:
	return kind in COMBAT_KINDS


static func is_halt(kind: String) -> bool:
	return kind in HALT_KINDS


static func _fight(depth: int, title: String, reward: String, elite := false, uncertain := false) -> Dictionary:
	return _entry("elite" if elite else "normal", title, reward, int(MAP_BY_DEPTH[depth]),
		"Combat difficile · butin renforcé" if elite else "Combat · technique, objet ou oboles", uncertain)


static func _halt(kind: String, title: String, reward: String, uncertain := false) -> Dictionary:
	return _entry(kind, title, reward, -1, "Halte · services et découvertes" if not uncertain else "Combat ou halte possible · nature inconnue", uncertain)


static func _entry(kind: String, title: String, reward: String, room_index: int, hint: String, uncertain := false) -> Dictionary:
	return {"kind": kind, "title": title, "reward": reward, "room_index": room_index, "hint": hint, "uncertain": uncertain}


static func _destinations(lane: int, current_count: int, next_count: int) -> Array:
	if next_count == 1:
		return [0]
	if current_count == 1:
		return range(next_count)
	if current_count == 2 and next_count == 2:
		return [lane]
	if current_count == 2 and next_count == 3:
		return [0, 1] if lane == 0 else [1, 2]
	if current_count == 3 and next_count == 2:
		return [0, 1] if lane == 1 else [0 if lane == 0 else 1]
	return [0, 1] if lane == 0 else ([1, 2] if lane == 2 else [0, 1, 2])


static func _add_secret(nodes: Array[Dictionary], layer_ids: Array, depth: int, title: String, reward: String, kind: String) -> void:
	var edges: Array[String] = []
	for next_id in layer_ids[depth]:
		edges.append(String(next_id))
	var secret := _entry(kind, title, reward, -1, "Passage découvert · savoir et préparation")
	secret.merge({"id": "d%02d_secret" % depth, "depth": depth, "lane": 3, "hidden": true, "edges": edges})
	nodes.append(secret)
	for previous_id in layer_ids[depth - 2]:
		_find(nodes, String(previous_id)).edges.append(String(secret.id))


static func _find(nodes: Array[Dictionary], node_id: String) -> Dictionary:
	for node in nodes:
		if String(node.id) == node_id:
			return node
	return {}
