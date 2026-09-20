extends RefCounted
## Explicit acquisition tiers; initiation is never part of the reward pool.
const CLASS_COLORS := {
	"assassin": Color("be78de"),
	"gardien": Color("e4b76a"),
	"arpenteur": Color("73c89c"),
	"thaumaturge": Color("69bdf0"),
}
const TIER_COLORS := [Color("aaa99e"), Color("81c999"), Color("78aaf5"), Color("da91ed")]
const TIER_NAMES := ["Initiation", "Usuelle", "Rare", "Épique"]
const ADVANCED := [
	["a_venom", "assassin", "Venin du Styx", 2, 1, 2, .6, "bleed", .45, "Usure"],
	["a_disarm", "assassin", "Sectionner les tendons", 2, 1, 2, .6, "disrupt", 1, "Contrôle"],
	["a_lure", "assassin", "Murmure trompeur", 2, 2, 4, .3, "lure", 2, "Placement"],
	["a_stasis", "assassin", "Sommeil de l'oubli", 3, 1, 2, 0., "stasis", 1, "Contrôle"],
	["a_reap", "assassin", "Moisson des condamnés", 3, 1, 2, 1.1, "execute", 1.2, "Exécution"],
	["a_phantom", "assassin", "Traversée spectrale", 2, 1, 4, 0., "blink", 4, "Mobilité"],
	["g_bastion", "gardien", "Bastion vivant", 3, 0, 0, 0., "guard", 1.8, "Défense"],
	["g_prison", "gardien", "Entrave de bronze", 2, 1, 3, .6, "root", 2, "Contrôle"],
	["g_fault", "gardien", "Faille ardente", 3, 1, 3, .5, "fire_field", .45, "Terrain"],
	["g_crash", "gardien", "Sentence du rempart", 3, 1, 2, 1.1, "guarded", 1., "Riposte"],
	["g_hook", "gardien", "Chaînes du Tartare", 2, 2, 4, .8, "pull", 3, "Placement"],
	["g_silence", "gardien", "Briser l'incantation", 2, 1, 3, .5, "disrupt", 2, "Contrôle"],
	["r_caltrop", "arpenteur", "Piège de givre", 2, 1, 4, .25, "ice_field", 1, "Terrain"],
	["r_embers", "arpenteur", "Flèche incendiaire", 3, 2, 5, .7, "fire_field", .35, "Terrain"],
	["r_net", "arpenteur", "Filet du chasseur", 2, 2, 5, .55, "root", 2, "Contrôle"],
	["r_scatter", "arpenteur", "Volée du crépuscule", 3, 2, 5, 1.2, "cross", 1, "Zone"],
	["r_horizon", "arpenteur", "Au-delà de la ligne", 2, 1, 4, 0., "blink", 4, "Mobilité"],
	["r_bounty", "arpenteur", "Prime de la traque", 3, 2, 6, 1.1, "marked", 1.1, "Exécution"],
	["t_flamewall", "thaumaturge", "Bûcher des ombres", 3, 1, 4, .65, "fire_field", .5, "Terrain"],
	["t_glacier", "thaumaturge", "Jardin de givre", 3, 1, 4, .45, "ice_field", 2, "Terrain"],
	["t_charm", "thaumaturge", "Chant du Léthé", 2, 2, 4, .4, "lure", 2, "Placement"],
	["t_hourglass", "thaumaturge", "Sablier brisé", 3, 1, 3, 0., "stasis", 1, "Contrôle"],
	["t_disrupt", "thaumaturge", "Dissonance", 2, 1, 4, .55, "disrupt", 2, "Contrôle"],
	["t_cataclysm", "thaumaturge", "Couronne de cendres", 3, 1, 4, 1.35, "fire", 1, "Zone"],
]
const EPIC := [
	"a_stasis",
	"a_reap",
	"g_bastion",
	"g_crash",
	"r_scatter",
	"r_bounty",
	"t_hourglass",
	"t_cataclysm",
]


static func initiation_rows() -> Array:
	var result: Array = []
	for pair in [["a", "assassin"], ["g", "gardien"], ["r", "arpenteur"], ["t", "thaumaturge"]]:
		var p: String = pair[0]
		var c: String = pair[1]
		var reach := 3 if p in ["r", "t"] else 1
		result.append_array(
			[
				[
					"s_" + p + "_hit",
					c,
					"Frappe novice" if reach == 1 else "Trait novice",
					2,
					1,
					reach,
					.65,
					"hit",
					0,
					"Dégâts",
				],
				["s_" + p + "_mark", c, "Repérer une faille", 1, 1, 2, .1, "mark", 1, "Préparation"],
				["s_" + p + "_guard", c, "Garde fragile", 1, 0, 0, 0., "guard", .25, "Défense"],
				["s_" + p + "_step", c, "Pas mesuré", 1, 1, 1, 0., "move", 1, "Mobilité"],
				["s_" + p + "_push", c, "Bousculade", 2, 1, 1, .25, "push", 1, "Placement"],
				["s_" + p + "_cut", c, "Éraflure", 2, 1, reach, .25, "bleed", .1, "Usure"],
				[
					"s_" + p + "_finish",
					c,
					"Saisir la faille",
					2,
					1,
					reach,
					.35,
					"marked",
					.2,
					"Exécution",
				],
			]
		)
	return result


static func rows() -> Array:
	return initiation_rows() + ADVANCED


static func tier(id: String) -> int:
	if id.begins_with("s_"):
		return 0
	if id in EPIC:
		return 3
	for r in ADVANCED:
		if r[0] == id:
			return 2
	return 1


static func icon_alias(id: String, class_id: String, effect: String) -> String:
	var p: String = { "assassin": "a", "gardien": "g", "arpenteur": "r", "thaumaturge": "t" }.get(
		class_id,
		"a",
	)
	if id.begins_with("s_") or tier(id) >= 2:
		var common: Dictionary = {
			"guard": "a_parry",
			"move": "a_step",
			"blink": "a_escape",
			"mark": "a_open",
			"bleed": "a_cut",
			"push": "g_push",
			"pull": "g_pull",
			"lure": "t_pull",
			"root": "r_slow",
			"disrupt": "t_weak",
			"stasis": "t_ice",
			"fire_field": "t_fire",
			"ice_field": "t_frost",
			"cross": "r_fan",
			"fire": "t_fire",
			"execute": "a_execute",
			"marked": "a_finish",
			"guarded": "g_hit",
		}
		return str(
			common.get(effect, { "a": "a_pierce", "g": "g_hit", "r": "r_shot", "t": "t_bolt" }[p])
		)
	return id


static func role_color(role: String) -> Color:
	return Color("ee8e78") if role in ["Dégâts", "Exécution", "Riposte"] else Color("81cbea") if role in [
		"Contrôle",
		"Terrain",
		"Placement",
	] else Color("a1d18e")
