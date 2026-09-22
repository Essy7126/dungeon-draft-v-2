extends RefCounted
## Art direction only: explicit hero shapes and a bounded accent for major casts.
## The short contact flash starts on the confirmed event; tails never delay rules.
const SHAPES := [
	"reaper",
	"bastion",
	"judgement",
	"volley",
	"harpoon",
	"hourglass",
	"oblivion",
	"corona",
	"tempest",
	"discord",
]
const EPIC := {
	"a_reap": [
		"reaper",
		1.55,
		2.90,
		"b95585",
		"fff0d5",
		"Deux grandes faux de lumière pourpre se croisent ; tranchants ivoire, matière pleine puis lambeaux ascendants.",
	],
	"g_bastion": [
		"bastion",
		1.65,
		2.85,
		"d89536",
		"fff0c5",
		"Trois remparts ambrés à créneaux émergent du sol, se verrouillent puis se dissolvent en poussière dorée ; la garde réelle prend le relais.",
	],
	"g_crash": [
		"judgement",
		1.45,
		2.80,
		"cd873a",
		"fff0cc",
		"Un pilon de bronze spectral s'abat sur le point touché, avec un éclat en étoile et des fragments ; aucune poussée fictive.",
	],
	"r_scatter": [
		"volley",
		1.40,
		2.85,
		"69bba4",
		"f2ffd9",
		"Une gerbe de cinq pointes larges ouvre un éventail au contact ; plumes translucides et fragments, uniquement aux impacts confirmés.",
	],
	"r_bounty": [
		"harpoon",
		1.45,
		2.85,
		"5fa98e",
		"fff1c6",
		"Un grand fer de chasse à trois barbes traverse la cible ; noyau ivoire et sillage vert profond, sans flash de bonus non confirmé.",
	],
	"t_hourglass": [
		"hourglass",
		1.70,
		2.85,
		"798fc9",
		"f5e5ff",
		"Un sablier monumental apparaît au-dessus de la cible marquée ; verre spectral, sable suspendu, cadre qui se disloque puis stase réelle.",
	],
	"a_stasis": [
		"oblivion",
		1.60,
		2.75,
		"7654a8",
		"e1ccff",
		"Deux ailes de nuit se referment autour de la cible marquée ; croissant pâle, voile ajouré puis suspension de l'état réel.",
	],
	"t_cataclysm": [
		"corona",
		1.75,
		3.10,
		"ef6526",
		"fff1bc",
		"Une couronne à cinq pointes de feu se déploie au contact ; cœur incandescent, grandes langues et cendres flottantes sur les cibles atteintes.",
	],
}
const MAJOR := [
	"a_execute",
	"a_sweep",
	"g_wall",
	"g_sweep",
	"g_crush",
	"r_long",
	"r_fan",
	"t_storm",
	"t_fire",
	"t_ice",
]
const FIELDS := ["g_fault", "r_embers", "t_flamewall", "t_glacier"]


static func apply(entry: Dictionary, id: String) -> void:
	entry["power"] = 0
	if id in FIELDS:
		entry["power"] = 1
	if id in MAJOR:
		entry["power"] = 1
		entry["duration"] = maxf(float(entry.duration), 1.05)
		entry["width"] = maxf(float(entry.width), 2.35)
	if id == "t_storm":
		entry["power_shape"] = "tempest"
		entry["duration"] = 1.25
		entry["width"] = 2.70
		entry["concept"] = "Une colonne de foudre dentelée frappe le contact confirmé ; branches latérales, flash bref puis fragments électriques décroissants."
	if not EPIC.has(id):
		return
	var brief: Array = EPIC[id]
	if entry.effect == "stasis":
		entry["ranged"] = false
	entry.merge(
		{
			"power": 2,
			"power_shape": brief[0],
			"duration": brief[1],
			"width": brief[2],
			"body_color": brief[3],
			"core_color": brief[4],
			"concept": brief[5],
		},
		true,
	)


static func is_cast(entry: Dictionary, hold: bool) -> bool:
	return not hold and entry.get("feedback_phase", "") not in ["tick", "expire", "break"]


static func shape(entry: Dictionary, hold: bool) -> String:
	if not is_cast(entry, hold):
		return ""
	# Actual Paris status is PA loss: keep the dramatic cast, show shattered shards.
	if (
		entry.get("power_shape", "") in ["hourglass", "oblivion"]
		and entry.get("motif", "") == "discord"
	):
		return "discord"
	return entry.get("power_shape", "")
