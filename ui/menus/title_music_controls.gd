extends PanelContainer
const Catalog := preload("res://core/audio/title_music_catalog.gd")
const BODY := preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)
var soundtrack: Node
var selector: OptionButton
var volume: HSlider
var credits_button: Button
var _author: Label
var _volume_value: Label
var _credits: AcceptDialog


func _ready() -> void:
	add_theme_font_override("font", BODY)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var label := Label.new()
	label.text = "MUSIQUE"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	credits_button = Button.new()
	credits_button.name = "MusicCredits"
	credits_button.text = "Crédits"
	credits_button.flat = true
	credits_button.pressed.connect(_show_credits)
	heading.add_child(credits_button)
	selector = OptionButton.new()
	selector.name = "MusicSelection"
	selector.tooltip_text = "Choisir la musique de l’écran titre. Le morceau choisi joue en boucle."
	for track in Catalog.TRACKS:
		selector.add_item(track.title)
	selector.item_selected.connect(
		func(index: int):
			soundtrack.select_track(index),
	)
	box.add_child(selector)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	box.add_child(bottom)
	_author = Label.new()
	_author.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_author)
	volume = HSlider.new()
	volume.name = "MusicVolume"
	volume.min_value = 0.0
	volume.max_value = 100.0
	volume.step = 1.0
	volume.custom_minimum_size.x = 95
	volume.tooltip_text = "Volume de la musique du titre — 0 pour couper le son."
	volume.value = float(soundtrack.level) * 100.0
	volume.value_changed.connect(
		func(value: float):
			soundtrack.set_level(value / 100.0)
			_volume_value.text = "%d %%" % roundi(value),
	)
	bottom.add_child(volume)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size.x = 38
	_volume_value.text = "%d %%" % roundi(volume.value)
	bottom.add_child(_volume_value)
	_credits = AcceptDialog.new()
	_credits.name = "TitleMusicCredits"
	_credits.title = "Crédits musicaux — Catabase"
	_credits.min_size = Vector2i(520, 360)
	_credits.ok_button_text = "Fermer"
	add_child(_credits)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 18
	text.offset_top = 15
	text.offset_right = -18
	text.offset_bottom = -55
	text.add_theme_font_override("normal_font", BODY)
	text.add_theme_font_size_override("normal_font_size", 15)
	text.text = "[b]Les huit musiques de l’écran titre[/b]\n\n"
	for track in Catalog.TRACKS:
		text.text += "[b]%s[/b] — %s\n[url=%s]Source et licence[/url]\n\n" % [
			track.title,
			track.author,
			track.source,
		]
	text.text += "Licence : [url=https://creativecommons.org/licenses/by/4.0/]Creative Commons Attribution 4.0 International[/url].\n\n"
	text.text += "Adaptations : ajustement du niveau, fondus aux extrémités et conversion Ogg Vorbis. Tempo, hauteur et stéréo conservés.\nLes auteurs ne cautionnent pas ces adaptations."
	text.meta_clicked.connect(
		func(url: Variant):
			OS.shell_open(str(url)),
	)
	_credits.add_child(text)
	soundtrack.selection_changed.connect(_sync_selection)
	_sync_selection(int(soundtrack.selected_index))


func _sync_selection(index: int) -> void:
	selector.select(index)
	_author.text = Catalog.TRACKS[index].author


func _show_credits() -> void:
	_credits.popup_centered(Vector2i(640, 500))


func focus_controls() -> Array[Control]:
	return [selector, volume, credits_button]


func apply_layout(viewport_size: Vector2, scale_factor: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.048, 0.88)
	style.border_color = Color("6e5940")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14 * scale_factor
	style.content_margin_right = 14 * scale_factor
	style.content_margin_top = 7 * scale_factor
	style.content_margin_bottom = 10 * scale_factor
	add_theme_stylebox_override("panel", style)
	_theme_children(self, maxi(11, roundi(15 * scale_factor)))
	volume.custom_minimum_size.x = 100 * scale_factor
	selector.get_popup().add_theme_font_override("font", BODY)
	selector.get_popup().add_theme_font_size_override(
		"font_size",
		maxi(13, roundi(17 * scale_factor)),
	)
	_place_panel.call_deferred(viewport_size, scale_factor)


func _place_panel(viewport_size: Vector2, scale_factor: float) -> void:
	# Container minimum sizes settle after font changes; anchor using the actual size.
	size = Vector2(495, 145) * scale_factor
	position = viewport_size - size - Vector2(45, 70) * scale_factor


func _theme_children(node: Node, font_size: int) -> void:
	for child in node.get_children():
		if child is Window:
			continue
		if child is Control:
			child.add_theme_font_override("font", BODY)
			child.add_theme_font_size_override("font_size", font_size)
			child.add_theme_color_override("font_color", Color("dccaa7"))
		_theme_children(child, font_size)
