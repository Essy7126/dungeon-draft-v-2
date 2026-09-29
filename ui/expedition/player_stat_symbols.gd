extends RefCounted
## Shared visual vocabulary. Values and elemental weights remain owned by the rules.
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")
const COLORS := {
	"earth": "cba273",
	"water": "70c6e3",
	"fire": "ef9362",
	"wind": "91d4b0",
	"night": "b49ee7",
	"sun": "eacb70",
	"hp": "ed8092",
	"ap": "74c7ed",
	"mp": "9dd18b",
	"power": "efbd73",
	"physical": "a8c3d2",
	"magic": "b49ee7",
	"hand": "eacb70",
	"range": "83c9c3",
	"contact": "ef9362",
}
const ALIASES := { "vitality": "hp", "protection": "physical", "distance": "range" }
static var _textures: Dictionary = { }


static func color(id: String) -> Color:
	return Color(COLORS.get(ALIASES.get(id, id), "dbb98f"))


static func icon(id: String) -> Texture2D:
	var key: String = ALIASES.get(id, id)
	if not _textures.has(key):
		_textures[key] = load("res://asset/ui/player_symbols/%s.svg" % key)
	return _textures[key]


static func elements(row: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in Rules.ELEMENTS:
		for weights in row.get("elements", { }).values():
			if float(weights.get(id, 0)) > 0:
				result.append(id)
				break
	return result


static func element_strip(parent: Node, row: Dictionary, compact := false) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.name = "CardElements"
	strip.add_theme_constant_override("separation", 5)
	parent.add_child(strip)
	var ids := elements(row)
	for id in ids:
		var art := D.image(strip, icon(id), 18 if compact else 22)
		art.tooltip_text = Rules.ELEMENT_NAMES[id]
		if not compact:
			D.label(strip, Rules.ELEMENT_NAMES[id], 14, color(id)).autowrap_mode = TextServer.AUTOWRAP_OFF
	if ids.is_empty():
		D.label(strip, "Neutre", 12 if compact else 14, D.MUTED).autowrap_mode = TextServer.AUTOWRAP_OFF
	return strip


static func stat_tile(parent: Node, id: String, title: String, value: String, hint := "") -> void:
	var panel := PanelContainer.new()
	panel.name = "Stat_" + id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := D.surface(false, 6)
	style.border_color = color(id).darkened(.45)
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = hint
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var art := D.image(row, icon(id), 26)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	D.label(words, title, 12, D.MUTED)
	D.label(words, value, 18, color(id))
