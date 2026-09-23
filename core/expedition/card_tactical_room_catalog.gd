extends RefCounted
## Authored topology projected by Arena Studio; # blocks movement and sight, ~ is a pit.
const IDS := ["forge", "garden", "convoy", "hourglass", "reservoir"]
const DESTINATIONS := {
	"5:airain": "forge",
	"8:lethe": "garden",
	"12:styx": "convoy",
	"6:lethe": "hourglass",
	"13:airain": "reservoir",
	"6:styx": "hourglass",
	"8:airain": "garden",
	"8:styx": "garden",
	"13:lethe": "reservoir",
}
const CHIEF_ROLES := {
	"forge": "brute",
	"hourglass": "brute",
	"garden": "conducteur",
	"convoy": "collecteur",
	"reservoir": "fondeur",
}


static func create_rules(id: String):
	if id in ["hourglass", "reservoir"]:
		return load("res://core/expedition/card_tactical_resource_rules.gd").new()
	return load("res://core/expedition/card_tactical_room_rules.gd").new()


const ROOMS := {
	"hourglass": {
		"name": "Le sablier des représailles",
		"hint": "Une croix verrouillée explose en fin de tour : 32 dégâts à tous. Retardez-la pour 1 PA, mais elle passe à 48 dégâts.",
		"rows": [
			"...~~~...",
			".........",
			"...#.#...",
			".........",
			"...#.#...",
			".........",
			"...~~~...",
		],
		"rule": "La croix rouge, de portée 2 dans les quatre directions, reste fixe même si vous bougez. Elle inflige 32 dégâts physiques à tous en fin de tour, puis la prochaine croix se verrouille sur votre position finale. Les murs arrêtent les bras de la croix. Au levier L ou à une case : retarder coûte 1 PA et reporte l'explosion d'un tour, avec 48 dégâts ; chaque croix ne peut être retardée qu'une fois. Recentrer coûte 2 PA et verrouille la croix sur la position actuelle du chef. Une commande par tour. Déplacez-vous après le verrouillage ou attirez les ennemis dans la zone. Le sablier reste actif après la mort du chef tant que le combat continue.",
		"inspiration": "Télégraphie fixe, appât et arbitrage entre gagner un tour et renforcer le danger.",
	},
	"reservoir": {
		"name": "Les réservoirs de Tantale",
		"hint": "Terminez près de H ou B : vos PA restants deviennent des charges. Décharge : 22 dégâts par charge au chef. Les ennemis peuvent voler l'énergie.",
		"rows": [
			".........",
			".........",
			"...#.#...",
			"....~....",
			"...#.#...",
			".........",
			".........",
		],
		"rule": "En fin de tour, à distance 0 ou 1 de H ou B, vos PA restants sont consommés et stockés : 1 PA = 1 charge, maximum 6 par réservoir. À proximité du réservoir choisi, décharger coûte 1 PA et consomme toute sa réserve : 22 dégâts physiques par charge au chef, sans contrainte de portée ni de ligne de vue. Une décharge par tour. Chaque ennemi vivant à distance 0 ou 1 d'un réservoir vole une charge au début de son activation et récupère jusqu'à 12 PV ; il joue ensuite normalement. Écartez les ennemis, stockez une mauvaise main, puis revenez déclencher la décharge. Les charges disparaissent après le combat.",
		"inspiration": "Report d'une ressource de deckbuilding, contrôle d'un objectif spatial et alimentation disputée.",
	},
	"forge": {
		"name": "La forge des condamnés",
		"hint": "Presse annoncée : 32 dégâts au héros, 60 aux ennemis. Choisir son rail au levier coûte 1 PA.",
		"rows": [
			"~~.....~~",
			".........",
			"..#...#..",
			".........",
			"..#...#..",
			".........",
			"~~.....~~",
		],
		"rule": "La presse frappe la rangée ! à chaque fin de tour : 32 dégâts à Achille, 60 aux ennemis. Son rail avance de 1 → 3 → 5. Au levier L, 1 PA permet de choisir le prochain rail, une fois par tour. Les piliers coupent les tirs ; les passages latéraux permettent de contourner. La presse reste active après la mort du chef tant que le combat continue.",
		"inspiration": "Grym : attirer un adversaire dans une machine de salle ; Divinity : exploiter un danger commun.",
	},
	"garden": {
		"name": "Le jardin des distances",
		"hint": "Un anneau de 28 dégâts suit le chef : distance 2, puis 3, puis 1. Déplacez son origine ou rejoignez une case sûre.",
		"rows": [
			"...~~~...",
			".........",
			"..#...#..",
			".........",
			"..#...#..",
			".........",
			"...~~~...",
		],
		"rule": "L'anneau ! suit le boss et frappe à distance Manhattan exacte 2, puis 3, puis 1 : 28 dégâts à toute autre unité. Pousser ou attirer le boss déplace immédiatement l'anneau. Au levier L, 1 PA le téléporte vers le socle haut ou bas si libre, une fois par tour. L'anneau traverse les piliers.",
		"inspiration": "Kimbo : déplacer l'origine d'une règle spatiale ; les zones sûres dépendent d'une position manipulable.",
	},
	"convoy": {
		"name": "Le convoi des dernières âmes",
		"hint": "Interceptez les âmes avant l'autel (+35 PV et +8 attaque au chef), ou scellez-le pour 2 PA : les porteurs reprennent leurs attaques.",
		"rows": [
			".........",
			".........",
			"...#.#...",
			".........",
			"...#.#...",
			".........",
			".........",
		],
		"rule": "Seuls les deux Porteurs portent une âme ; le Molosse conserve ses attaques. À leur activation, ils avancent de 1 case vers O au lieu d'attaquer. S'ils commencent à côté, ils se sacrifient : +35 PV au chef et +8 attaque permanente. Chaque porteur à distance ≤ 2 du chef lui donne 12 garde au début de son tour. Au sceau L, 2 PA ferment l'autel : les porteurs reprennent alors leurs attaques normales. Tuer un porteur laisse une âme : la ramasser donne 12 garde. Le chef est le Collecteur, indépendamment des PV des autres ennemis.",
		"inspiration": "Myrkul : intercepter les renforts avant leur conversion ; Raphael : supprimer une alimentation de puissance.",
	},
}


static func build(id: String) -> ArenaDefinition:
	var spec: Dictionary = ROOMS[id]
	var arena := ArenaDefinition.new()
	arena.set_identity(spec.name, "cards_" + id)
	arena.grid_size = Vector2i(9, 7)
	arena.production_notes = spec.rule
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.theme_id = &"dynamic_default"
	for y in 7:
		for x in 9:
			var symbol: String = spec.rows[y][x]
			var terrain: StringName = &"hole" if symbol == "~" else &"neutral"
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), terrain)
			if symbol == "#":
				var pillar := ArenaObstacleDefinition.new()
				pillar.obstacle_id = StringName("pillar_%d_%d" % [x, y])
				pillar.cell = Vector2i(x, y)
				pillar.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
				arena.obstacles.append(pillar)
	for cell in [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)]:
		var spawn := ArenaSpawnDefinition.new()
		spawn.kind = ArenaSpawnDefinition.Kind.HERO_1
		spawn.cell = cell
		arena.spawns.append(spawn)
	for cell in [
		Vector2i(7, 3),
		Vector2i(6, 1),
		Vector2i(6, 5),
		Vector2i(8, 2),
		Vector2i(8, 4),
		Vector2i(7, 1),
	]:
		var spawn := ArenaSpawnDefinition.new()
		spawn.kind = ArenaSpawnDefinition.Kind.ENEMY
		spawn.cell = cell
		arena.spawns.append(spawn)
	return arena


static func id_for(node: Dictionary) -> String:
	if (
		int(node.get("balance_revision", 0)) < 1
		or str(node.get("kind", "")) not in ["normal", "elite"]
	):
		return ""
	return DESTINATIONS.get(
		"%d:%s" % [int(node.get("depth", 0)), str(node.get("route_family", ""))],
		"",
	)


static func replace_room(source: RoomData, id: String) -> RoomData:
	var arena := build(id)
	arena.encounter_definition = source.encounter_definition
	arena.enemies = source.enemies
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	arena.battle_scene = load("res://battle/tactical_rooms/TacticalRoomBattle.tscn")
	# These are candidate zones, never fixed placements; the normal encounter solver owns deployment.
	arena.encounter_definition.forbidden_initial_spawn_cells = []
	arena.set_meta("card_tactical_room_id", id)
	return arena
