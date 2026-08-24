@tool
class_name TerrainFloorPalette
extends VBoxContainer

## Palette visuelle des sols. Chaque sol est un bouton avec son apercu de
## texture (ou sa couleur d'editeur), son nom francais, un pictogramme de
## danger quand le sol applique un effet, et un resume de comportement en
## infobulle.
##
## La palette separe visuellement deux familles qui ne vivent pas au meme
## endroit : les sols permanents, enregistres dans le terrain, et les surfaces
## temporaires, creees pendant le combat par un sort. Ces dernieres ne sont pas
## peignables ici.

signal terrain_selected(terrain_id: StringName)
signal brush_size_changed(size: int)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const DANGER_GLYPH := "⚠"

## Resume de comportement affiche en infobulle et sous le nom.
const BEHAVIOUR := {
	&"stone": "Praticable — aucun effet.",
	&"neutral": "Praticable — aucun effet.",
	&"water": "Praticable — rend Mouillé.",
	&"ice": "Praticable — rend Gelé.",
	&"lava": "Praticable — inflige Brûlure.",
	&"poison": "Praticable — inflige Poison.",
	&"steam": "Praticable — bloque la vision.",
	&"electrified_water": "Praticable — rend Mouillé puis inflige un Choc.",
	&"void": "Case retirée du terrain — utilisez l'outil Retirer des cases.",
}

var buttons := {}
var brush_size_option: OptionButton = null
var recent_label: Label = null
var permanent_box: HFlowContainer = null
var temporary_label: Label = null

var _selected: StringName = &"stone"
var _recents: Array[StringName] = []
var _built := false
var _entries_signature := ""


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainFloorPalette"
	add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.text = "SOLS PERMANENTS — enregistrés dans le terrain"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", ACCENT)
	add_child(title)
	permanent_box = HFlowContainer.new()
	permanent_box.name = "TerrainFloorButtons"
	permanent_box.add_theme_constant_override("h_separation", 4)
	permanent_box.add_theme_constant_override("v_separation", 4)
	add_child(permanent_box)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 6)
	add_child(options)
	var brush_label := Label.new()
	brush_label.text = "Taille du pinceau"
	brush_label.add_theme_color_override("font_color", MUTED)
	options.add_child(brush_label)
	brush_size_option = OptionButton.new()
	brush_size_option.name = "TerrainBrushSize"
	brush_size_option.tooltip_text = "Nombre de cases peintes d'un seul clic."
	brush_size_option.focus_mode = Control.FOCUS_ALL
	for size in [1, 2, 3]:
		brush_size_option.add_item("%d × %d" % [size, size])
		brush_size_option.set_item_metadata(brush_size_option.item_count - 1, size)
	brush_size_option.item_selected.connect(func(index):
		brush_size_changed.emit(int(brush_size_option.get_item_metadata(index)))
	)
	options.add_child(brush_size_option)
	recent_label = Label.new()
	recent_label.name = "TerrainFloorRecents"
	recent_label.text = "Récents : —"
	recent_label.add_theme_color_override("font_color", MUTED)
	options.add_child(recent_label)
	temporary_label = Label.new()
	temporary_label.name = "TerrainTemporarySurfacesNote"
	temporary_label.text = (
		"SURFACES TEMPORAIRES — créées pendant le combat par un sort, "
		+ "jamais peintes ici."
	)
	temporary_label.add_theme_font_size_override("font_size", 11)
	temporary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	temporary_label.add_theme_color_override("font_color", MUTED)
	add_child(temporary_label)


## `entries` provient de ArenaPermanentTerrainPaintService. La palette est
## rafraichie a chaque trait de pinceau : les boutons ne sont reconstruits que
## si la liste des sols disponibles a reellement change.
func set_entries(entries: Array[Dictionary]) -> void:
	_build()
	var signature := PackedStringArray()
	for entry in entries:
		signature.append("%s:%s" % [entry.get("stable_id", ""), entry.get("enabled", false)])
	var joined := "|".join(signature)
	if joined == _entries_signature:
		return
	_entries_signature = joined
	for child in permanent_box.get_children():
		permanent_box.remove_child(child)
		child.queue_free()
	buttons.clear()
	for entry in entries:
		var terrain_id := StringName(entry.get("stable_id", &""))
		if terrain_id == &"void":
			continue
		permanent_box.add_child(_terrain_button(entry, terrain_id))
	_refresh_pressed()


func select_terrain(terrain_id: StringName, remember := true) -> void:
	_build()
	if not buttons.has(terrain_id):
		return
	_selected = terrain_id
	if remember:
		_recents.erase(terrain_id)
		_recents.push_front(terrain_id)
		while _recents.size() > 3:
			_recents.pop_back()
		_refresh_recents()
	_refresh_pressed()


func selected_terrain() -> StringName:
	return _selected


func set_brush_size(size: int) -> void:
	_build()
	for index in range(brush_size_option.item_count):
		if int(brush_size_option.get_item_metadata(index)) == size:
			brush_size_option.select(index)
			return


func _terrain_button(entry: Dictionary, terrain_id: StringName) -> Button:
	var button := Button.new()
	button.name = "TerrainFloor_%s" % terrain_id
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(112, 26)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Les textures de sol sont des tuiles pleine résolution : les borner évite
	# qu'une palette de huit sols mange la place du canvas.
	button.add_theme_constant_override("icon_max_width", 16)
	var enabled := bool(entry.get("enabled", false))
	button.disabled = not enabled
	var definition := ArenaCatalogService.terrain(terrain_id)
	var behaviour := str(BEHAVIOUR.get(terrain_id, "Praticable."))
	var dangerous := definition != null \
		and (definition.ai_danger_weight > 0.0 or definition.unit_effect != null)
	var label := str(entry.get("display_name", terrain_id))
	button.text = "%s %s" % [DANGER_GLYPH, label] if dangerous else label
	if definition != null and definition.base_texture != null:
		button.icon = definition.base_texture
	elif definition != null:
		var preview := PlaceholderTexture2D.new()
		preview.size = Vector2(18, 18)
		button.icon = preview
		button.add_theme_color_override("icon_normal_color", definition.editor_color)
	var reason := str(entry.get("reason", ""))
	button.tooltip_text = "%s\n%s%s" % [
		label, behaviour,
		"" if enabled else "\nIndisponible : %s" % reason,
	]
	button.pressed.connect(func():
		select_terrain(terrain_id)
		terrain_selected.emit(terrain_id)
	)
	buttons[terrain_id] = button
	return button


func _refresh_pressed() -> void:
	for terrain_id in buttons:
		(buttons[terrain_id] as Button).set_pressed_no_signal(terrain_id == _selected)


func _refresh_recents() -> void:
	if recent_label == null:
		return
	if _recents.is_empty():
		recent_label.text = "Récents : —"
		return
	var names := PackedStringArray()
	for terrain_id in _recents:
		var definition := ArenaCatalogService.terrain(terrain_id)
		names.append(definition.display_name if definition != null else str(terrain_id))
	recent_label.text = "Récents : %s" % ", ".join(names)
