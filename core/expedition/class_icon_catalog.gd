extends RefCounted
## Presentation assets only. Stable IDs map to atlas cells, independent of stats.
const ROOT := "res://assets/catabase/class_icons_painted_v1/"
const FAMILIES := {
	"assassin": [
		"a_open",
		"a_finish",
		"a_cut",
		"a_step",
		"a_parry",
		"a_dagger",
		"a_ambush",
		"a_sweep",
		"a_hamstring",
		"a_push",
		"a_execute",
		"a_pull",
		"a_blind",
		"a_pierce",
		"a_escape",
	],
	"gardien": [
		"g_guard",
		"g_push",
		"g_hit",
		"g_step",
		"g_slow",
		"g_pull",
		"g_wall",
		"g_sweep",
		"g_crush",
		"g_mark",
		"g_riposte",
		"g_shot",
		"g_weaken",
		"g_charge",
		"g_punish",
	],
	"arpenteur": [
		"r_shot",
		"r_step",
		"r_slow",
		"r_push",
		"r_guard",
		"r_mark",
		"r_hunt",
		"r_fan",
		"r_close",
		"r_bleed",
		"r_long",
		"r_move",
		"r_escape",
		"r_pull",
		"r_weak",
	],
	"thaumaturge": [
		"t_frost",
		"t_fire",
		"t_mark",
		"t_guard",
		"t_step",
		"t_bolt",
		"t_hex",
		"t_weak",
		"t_pull",
		"t_push",
		"t_burn",
		"t_ice",
		"t_storm",
		"t_touch",
		"t_escape",
	],
}
const RUNES := ["class_rune_edge", "class_rune_stone", "class_rune_veil", "class_rune_blood"]
const ARMORS := ["armor_airain", "armor_sceau", "armor_mixte", "armor_legere"]
const PREPARATION := [
	"relic_clou",
	"relic_urne",
	"relic_fil",
	"relic_coupe",
	"relic_meche",
	"relic_obole",
	"supply_onguent",
	"supply_souffle",
	"supply_plaque",
	"supply_sel",
	"weapon_marteau",
	"weapon_xiphos",
	"weapon_disque",
	"weapon_hampe",
	"weapon_lame",
	"weapon_arc",
]
const ACCENTS := {
	"assassin": Color("e6a89e"),
	"gardien": Color("e2bd78"),
	"arpenteur": Color("a8ce9b"),
	"thaumaturge": Color("c8b4ed"),
}
static var _icons: Dictionary = { }
static var _sheets: Dictionary = { }


static func empty_slot(index: int) -> Texture2D:
	if index < 0 or index >= 6:
		return null
	var id := "empty_%d" % index
	if not _icons.has(id):
		_icons[id] = load(ROOT + id + ".svg")
	return _icons[id]


static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	for profession in FAMILIES:
		var index: int = FAMILIES[profession].find(id)
		if id == profession:
			index = 15
		if index >= 0:
			return _cell(id, profession, index, 4, 4)
	if id in RUNES:
		return _cell(id, "runes", RUNES.find(id), 2, 2)
	if id in ARMORS:
		return _cell(id, "armors", ARMORS.find(id), 2, 2)
	if id in PREPARATION:
		return _cell(id, "relics", PREPARATION.find(id), 4, 4)
	var parts := id.split("_")
	if parts.size() == 3 and parts[0] == "gear":
		if parts[1].is_valid_int() and parts[2].is_valid_int():
			var slot := int(parts[1])
			var affinity := int(parts[2])
			if slot >= 0 and slot < 6 and affinity >= 0 and affinity < 4:
				return _cell(id, "equipment", affinity * 6 + slot, 6, 4)
	return null


static func _cell(id: String, sheet: String, index: int, columns: int, rows: int) -> AtlasTexture:
	# Lazy loading keeps autoload parsing independent from the first editor import.
	if not _sheets.has(sheet):
		_sheets[sheet] = load(ROOT + sheet + ".png")
	var texture: Texture2D = _sheets[sheet]
	if texture == null:
		return null
	var size := texture.get_size()
	var x := index % columns
	var y := index / columns
	# Generated dimensions need not divide evenly. Snap shared boundaries to pixels.
	var start := Vector2(floorf(x * size.x / columns), floorf(y * size.y / rows))
	var end := Vector2(floorf((x + 1) * size.x / columns), floorf((y + 1) * size.y / rows))
	if sheet == "relics":
		# This painted sheet has slightly uneven row spacing. These measured quiet
		# bands retain whole objects while excluding the next row's spear/handles.
		var bands := [0.0, 300.0 / 1254.0, 594.0 / 1254.0, 880.0 / 1254.0, 1.0]
		start.y = floorf(bands[y] * size.y)
		end.y = floorf(bands[y + 1] * size.y)
	var result := AtlasTexture.new()
	result.atlas = texture
	# Keep a quiet gutter around generated cells. Decorative trails near a seam
	# must not appear as fragments of the next icon at inventory size.
	var vertical_ratio := .03 if sheet == "relics" else .08 if sheet == "equipment" else .05
	var gutter := Vector2(
		floorf((end.x - start.x) * .05),
		floorf((end.y - start.y) * vertical_ratio),
	)
	result.region = Rect2(start + gutter, end - start - gutter * 2)
	result.filter_clip = true
	result.resource_name = id
	_icons[id] = result
	return result


static func accent(class_id: String) -> Color:
	return ACCENTS.get(class_id, Color("c8c3ab"))
