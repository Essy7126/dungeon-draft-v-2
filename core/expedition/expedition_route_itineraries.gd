extends RefCounted
## Ordered, planar itineraries. A choice commits to a different halt before reunion.
const HALTS := ["hub", "merchant", "sanctuary", "lore", "cache", "event"]
const POSITIONS := [
	[0.50], [0.19, 0.47, 0.81], [0.09, 0.31, 0.56, 0.86], [0.24, 0.51, 0.77],
	[0.36, 0.65], [0.18, 0.44, 0.73], [0.56], [0.22, 0.55, 0.84],
	[0.11, 0.34, 0.64, 0.89], [0.23, 0.49, 0.77], [0.33, 0.66],
	[0.17, 0.46, 0.80], [0.23, 0.49, 0.82], [0.10, 0.39, 0.63, 0.86],
	[0.43], [0.13, 0.46, 0.79], [0.18, 0.39, 0.66, 0.89],
	[0.24, 0.58, 0.81], [0.37, 0.66], [0.53],
]
const HINTS := {
	"normal": "Combat · 35 oboles à la victoire, puis un butin au choix.",
	"elite": "Combat renforcé · 65 oboles à la victoire et une offre de technique.",
	"hub": "Repos offert · récupérer 30 % des PV maximum, une fois. Aucun étal.",
	"merchant": "Trois équipements à acheter. Aucun soin ni passage révélé ici.",
	"sanctuary": "Découvrir une branche (70 ou 110 oboles), ou accepter un tribut.",
	"lore": "Révéler un passage secret à venir et recevoir 20 oboles. Aucun soin.",
	"boss": "Pâris · épreuve finale de la descente.",
}


static func create_nodes(seed_value: int, maps: Dictionary, preserve_mirrored_paths := false) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layers: Array = [
		[["normal", "Le seuil de Catabase", "melee"]],
		[["normal", "La sente des oliviers", "healing"], ["normal", "Le portique des oboles", "armor"], ["normal", "Les traces du Léthé", "control"]],
		[["normal", "Les guetteurs du bosquet", "mobility"], ["normal", "La garde des sources", "healing"], ["elite", "Les percepteurs d'airain", "armor"], ["normal", "Les lances oubliées", "ranged"]],
		[["hub", "Le camp des compagnons", "healing"], ["merchant", "L'étal du passeur", "armor"], ["lore", "La stèle des noms", "discovery"]],
		[["normal", "Le gué des serments", "control"], ["normal", "Les roseaux du tireur", "ranged"]],
		[["normal", "L'atrium des cendres", "vitality"], ["unknown_fight", "Les gardiens du foyer", "elemental"], ["elite", "Les duellistes du gué", "melee"]],
		[["elite", "L'épreuve du bronze", "signature"]],
		[["sanctuary", "L'autel des serments", "discovery"], ["merchant", "La forge des cuirasses", "armor"], ["lore", "La mémoire de Chiron", "elemental"]],
		[["normal", "Les braises du cloître", "elemental"], ["elite", "Les gardes du pacte", "control"], ["normal", "Les porteurs d'airain", "armor"], ["normal", "Les pas sans retour", "mobility"]],
		[["normal", "Les arches du poursuivant", "ranged"], ["elite", "Les chaînes sous les arches", "control"], ["normal", "Les veilleurs des stèles", "healing"]],
		[["normal", "La fosse des revenants", "vitality"], ["unknown_halt", "La bibliothèque engloutie", "discovery"]],
		[["hub", "Le bivouac des six mémoires", "healing"], ["sanctuary", "Le pacte du sixième geste", "elemental"], ["merchant", "Le comptoir des offrandes", "armor"]],
		[["normal", "La sente des derniers souffles", "healing"], ["normal", "Les terrasses de l'orage", "elemental"], ["normal", "Le rempart des terrasses", "armor"]],
		[["normal", "Le pont des longs traits", "ranged"], ["normal", "Les fers de la terrasse", "melee"], ["elite", "Les gardes de la foudre", "elemental"], ["elite", "Le péage du dernier bronze", "armor"]],
		[["elite", "L'épreuve des obélisques", "signature"]],
		[["merchant", "Le marché du dernier feu", "armor"], ["hub", "Le foyer des revenants", "healing"], ["unknown_trial", "Le défi sans repos", "signature"]],
		[["normal", "Les porteurs du jardin", "armor"], ["elite", "Les lances du dernier tribut", "melee"], ["normal", "Le jardin des dalles fendues", "mobility"], ["normal", "Les ombres du serment", "control"]],
		[["elite", "Le vestibule des lances noires", "ranged"], ["normal", "Les gardiens du souffle", "healing"], ["normal", "Le vestibule des derniers noms", "control"]],
		[["hub", "Le feu avant Pâris", "healing"], ["sanctuary", "L'ultime offrande", "discovery"]],
		[["boss", "Pâris — le seuil de la Catabase", "victory"]],
	]
	# A whole section may mirror; neighboring layers never shuffle independently.
	var mirrored := rng.randi_range(0, 1) == 1
	var result: Array[Dictionary] = []
	var rows: Array = []
	for depth_index in layers.size():
		var entries: Array = layers[depth_index].duplicate(true)
		var positions: Array = POSITIONS[depth_index].duplicate()
		if mirrored:
			entries.reverse()
			positions.reverse()
			for index in positions.size():
				positions[index] = 1.0 - float(positions[index])
		var row: Array[Dictionary] = []
		for lane in entries.size():
			var entry: Array = entries[lane]
			var kind := str(entry[0])
			var uncertain := kind.begins_with("unknown_")
			if uncertain:
				kind = "normal" if kind == "unknown_fight" else ("lore" if kind == "unknown_halt" else "elite")
				if depth_index + 1 == 11 and rng.randi_range(0, 1) == 1:
					kind = "normal"
				if depth_index + 1 == 16 and rng.randi_range(0, 1) == 1:
					kind = "sanctuary"
			var node := {
				"id": "d%02d_%d" % [depth_index + 1, lane], "depth": depth_index + 1,
				"lane": lane, "kind": kind, "title": str(entry[1]), "reward": str(entry[2]),
				"room_index": -1 if kind in HALTS else int(maps[depth_index + 1]),
				"hint": "Nature inconnue · combat ou halte possible" if uncertain else str(HINTS.get(kind, "")),
				"uncertain": uncertain, "hidden": false, "edges": [] as Array[String],
				"map_x": clampf(float(positions[lane]) + rng.randf_range(-0.018, 0.018), 0.04, 0.92),
				"service_profile": kind if kind in HALTS else "",
			}
			row.append(node)
			result.append(node)
		rows.append(row)
	for depth_index in rows.size() - 1:
		var current: Array = rows[depth_index]
		var following: Array = rows[depth_index + 1]
		# Partition a split or a merge into neighboring groups. No all-to-all ladders.
		for lane in current.size():
			for target in following.size():
				# Mirror the authored connections with their destinations. Rounding
				# the displayed lanes changes who joins whom on asymmetric layers.
				var source_lane := current.size() - 1 - lane if mirrored and preserve_mirrored_paths else lane
				var target_lane := following.size() - 1 - target if mirrored and preserve_mirrored_paths else target
				var linked := floori(float(target_lane) * current.size() / following.size()) == source_lane if following.size() >= current.size() else floori(float(source_lane) * following.size() / current.size()) == target_lane
				if linked:
					current[lane].edges.append(str(following[target].id))
	for depth in [8, 16]:
		var secret_kind := "sanctuary" if depth == 8 else "lore"
		var secret := {
			"id": "d%02d_secret" % depth, "depth": depth, "lane": 3, "hidden": true,
			"kind": secret_kind, "title": "L'atelier sous la racine" if depth == 8 else "Le tombeau du serment intact",
			"reward": "elemental" if depth == 8 else "discovery", "room_index": -1,
			"hint": str(HINTS[secret_kind]), "uncertain": false,
			"edges": [str(rows[depth].back().id)] as Array[String],
			"map_x": 0.97, "service_profile": secret_kind,
		}
		result.append(secret)
		for parent in rows[depth - 2]:
			parent.edges.append(str(secret.id))
	return result
