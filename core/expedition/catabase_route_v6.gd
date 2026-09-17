extends RefCounted
## Fixed contracts, seeded presentation. Never observes the player's build.
const FAMILIES := ["airain", "styx", "lethe"]
const BRANCH_DEPTHS := [2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 14, 15, 17, 18]
const COMBAT_DEPTHS := [1, 2, 3, 5, 6, 8, 10, 12, 13, 15, 17, 20]
const ELITE_DEPTHS := [6, 10, 15]
const REFUGE_DEPTHS := [7, 11, 16]
const COMPARISON_DEPTHS := [2, 6, 10, 12, 15, 17]
const XP := [100, 125, 145, 175, 195, 215, 245, 265, 295, 325, 355, 345]
const ROOMS := { 1: 0, 2: 5, 3: 1, 5: 6, 6: 7, 8: 8, 10: 9, 12: 3, 13: 10, 15: 12, 17: 13, 20: 4 }
const COMBAT_TITLES := {
	1: ["Le seuil de Catabase"],
	2: ["Le portique des oboles", "La sente des oliviers", "Les traces du Léthé"],
	3: ["Les percepteurs d'airain", "Les guetteurs du bosquet", "Les lances oubliées"],
	5: ["Le gué des serments", "Le gué des serments", "Les roseaux du tireur"],
	6: ["L'atrium des cendres", "Les gardiens du foyer", "Les duellistes du gué"],
	8: ["Les porteurs d'airain", "Les pas sans retour", "Les braises du cloître"],
	10: ["Les chaînes sous les arches", "Les arches du poursuivant", "Les veilleurs des stèles"],
	12: ["La fosse des revenants", "La sente des derniers souffles", "Le rempart des terrasses"],
	13: ["Le rempart des terrasses", "Les terrasses de l'orage", "La sente des derniers souffles"],
	15: ["L'épreuve des obélisques", "L'épreuve des obélisques", "L'épreuve des obélisques"],
	17: ["Les porteurs du jardin", "Le jardin des dalles fendues", "Les ombres du serment"],
	20: ["Pâris — le seuil de la Catabase"],
}
const HALTS := {
	4: [
		["merchant", "L'étal du passeur", "etal_passeur"],
		["sanctuary", "L'autel des serments", "autel_serments"],
		["lore", "La stèle des noms", "stele_noms"],
	],
	7: [["hub", "Le camp des compagnons", "camp_compagnons"]],
	9: [
		["sanctuary", "L'autel des serments", "autel_serments"],
		["merchant", "La forge des cuirasses", "forge_cuirasses"],
		["sanctuary", "Le pacte du sixième geste", "pacte_sixieme_geste"],
	],
	11: [["hub", "Le bivouac des six mémoires", "bivouac_memoires"]],
	14: [
		["lore", "La bibliothèque engloutie", "bibliotheque_engloutie"],
		["sanctuary", "L'ultime offrande", "ultime_offrande"],
		["merchant", "Le marché du dernier feu", "marche_dernier_feu"],
	],
	16: [["hub", "Le foyer des revenants", "foyer_revenants"]],
	18: [
		["merchant", "L'obole du dernier passage", "obole_dernier_passage"],
		["lore", "La mémoire de Chiron", "memoire_chiron"],
		["merchant", "Le marché du dernier feu", "marche_dernier_feu"],
	],
	19: [["hub", "Devant Pâris — préparer son dernier combat", "feu_avant_paris"]],
}
const THREATS := {
	1: "Premier duel : mouvement, portée et priorité de cible.",
	2: "Garde et ligne de tir : choisissez votre approche.",
	3: "Un tireur et deux gardes ou poursuivants : isolez une aile.",
	5: "Portée et poursuite se combinent. Gardez une sortie pour l'épreuve du gué.",
	6: "Garde, tireur, molosse et soutien : brisez un flanc avant l'encerclement.",
	8: "Le conducteur marque pour ses chasseurs : coupez sa vue ou sa meute.",
	10: "Chaîne et Sentence : neutralisez la combinaison avant la phase ennemie.",
	12: "Le collecteur soigne près des porteurs : séparez ou éliminez le convoi.",
	13: "Fournaise et déplacement : préparez une sortie hors des braises.",
	15: "Égide, visée et poussée : choisissez la liaison à briser.",
	17: "Feu, déplacement et givre : conservez vos secours pour Pâris.",
	20: "Pâris : sous 20 % après un coup non fatal, une métamorphose rend tous ses PV et 30 bouclier. Un coup fatal le tue.",
}


static func create_nodes(seed_value: int, difficulty_id: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mirrored := rng.randi_range(0, 1) == 1
	var layouts: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/rooms/catabase_routes/catalog.json")
	)
	var nodes: Array[Dictionary] = []
	var rows: Dictionary = { }
	for depth in range(1, 21):
		var families: Array = FAMILIES.duplicate() if depth in BRANCH_DEPTHS else ["common"]
		if mirrored:
			families.reverse()
		var row: Array[Dictionary] = []
		for lane in families.size():
			var family: String = families[lane]
			var index := maxi(0, FAMILIES.find(family))
			var combat := depth in COMBAT_DEPTHS
			var kind := "boss" if depth == 20 else ("elite" if depth in ELITE_DEPTHS else "normal")
			var title: String = COMBAT_TITLES[depth][index] if combat else HALTS[depth][index][1]
			if not combat:
				kind = HALTS[depth][index][0]
			var preparation := depth == 19
			var reward: String = ["armor", "mobility", "control"][index] if combat else {
				"hub": "healing",
				"merchant": "armor",
				"sanctuary": "elemental",
				"lore": "discovery",
			}.get(kind, "discovery")
			if depth == 20:
				reward = "victory"
			if preparation:
				reward = ""
			var node := {
				"id": "d%02d_%d" % [depth, lane],
				"depth": depth,
				"lane": lane,
				"kind": kind,
				"title": title,
				"reward": reward,
				"room_index": int(ROOMS[depth]) if combat else -1,
				"hint": str(THREATS[depth]) if combat else _halt_hint(
					kind,
					difficulty_id,
					preparation,
				),
				"uncertain": false,
				"hidden": false,
				"edges": [] as Array[String],
				"map_x": 0.5 if families.size() == 1 else 0.17 + lane * 0.33
				+ rng.randf_range(-0.012, 0.012),
				"route_family": family,
				"balance_revision": 1,
				"difficulty_id": difficulty_id,
				"service_profile": "preparation" if preparation else ("" if combat else kind),
				"preparation_only": preparation,
				"highlight_build_reward": depth in COMPARISON_DEPTHS,
			}
			if not combat and kind == "lore" and depth >= 14:
				node.hint = "Mémoire tardive : choisissez une fourniture de garde ou de mobilité pour les combats restants. Aucun soin."
			if combat:
				node["encounter_profile_id"] = "catabase_r6_d%02d_%s" % [depth, family]
				node["encounter_grade"] = 1 if depth <= 6 else (2 if depth <= 12 else 3)
				node["reference_level"] = COMBAT_DEPTHS.find(depth) + 1
				node["xp_reward"] = XP[COMBAT_DEPTHS.find(depth)]
				node["room_resource"] = _room_path(depth, title, layouts)
			else:
				node["halt_art_key"] = str(HALTS[depth][index][2])
			row.append(node)
			nodes.append(node)
		rows[depth] = row
	for depth in range(1, 20):
		for source in rows[depth]:
			for destination in rows[depth + 1]:
				if (
					source.route_family == "common" or destination.route_family == "common"
					or source.route_family == destination.route_family
				):
					source.edges.append(str(destination.id))
	# Two secret places, each with an entrance that preserves its committed branch.
	for depth in [9, 14]:
		for source in rows[depth - 1]:
			var secret := {
				"id": "d%02d_secret_%s" % [depth, source.route_family],
				"depth": depth,
				"lane": int(source.lane),
				"kind": "sanctuary" if depth == 9 else "lore",
				"title": "L'atelier sous la racine" if depth == 9 else "Le tombeau du serment intact",
				"reward": "elemental" if depth == 9 else "discovery",
				"room_index": -1,
				"hint": "Passage découvert : un autre service, sans combat ni XP supplémentaires.",
				"uncertain": false,
				"hidden": true,
				"edges": [] as Array[String],
				"map_x": clampf(float(source.map_x) + 0.10, 0.04, 0.96),
				"route_family": source.route_family,
				"balance_revision": 1,
				"difficulty_id": difficulty_id,
				"service_profile": "sanctuary" if depth == 9 else "lore",
				"preparation_only": false,
				"halt_art_key": "atelier_sous_racine" if depth == 9 else "tombeau_serment_intact",
				"secret_group": "r6_secret_%d" % depth,
			}
			for destination in rows[depth + 1]:
				if destination.route_family == source.route_family:
					secret.edges.append(str(destination.id))
			source.edges.append(str(secret.id))
			nodes.append(secret)
	return nodes


static func _room_path(depth: int, title: String, layouts: Dictionary) -> String:
	if depth == 1:
		return "res://data/rooms/odyssey/room_01.tres"
	if depth == 15:
		return "res://data/rooms/catabase_expansion/room_13_offrandes.tres"
	if depth == 20:
		return "res://data/rooms/odyssey/room_05.tres"
	return str(layouts.get(title, { }).get("room", ""))


static func _halt_hint(kind: String, difficulty_id: String, preparation: bool) -> String:
	if preparation:
		return "Dernier réglage du kit et lecture de Pâris. Aucun soin ni objet offert."
	match kind:
		"hub":
			return "Refuge garanti : %d %% des PV maximum, une fois. Rééquipez votre kit." % (
				40 if difficulty_id == "easy" else 30
			)
		"merchant":
			return "Trois équipements à comparer. Les oboles dépensées manqueront aux prochaines étapes."
		"sanctuary":
			return "Découvrez une branche, ou payez un tribut si les branches sont déjà connues. Aucun soin."
		_:
			return "Un souvenir, 20 oboles et les accès d'un passage secret encore à venir. Aucun soin."
