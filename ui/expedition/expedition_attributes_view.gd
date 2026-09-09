extends VBoxContainer
## A presentation-only character sheet. The screen owns spending and navigation.

signal attribute_requested(attribute_id: StringName)

const ART := preload("res://ui/expedition/catabase_ui_theme.gd")
const TEXT := Color("f3ead7")
const MUTED := Color("b7c5c0")
const GOLD := Color("e0ba76")
const TEAL := Color("74d5cb")
const ATTRIBUTES := [
	["vitality", "Vitalité", "Survivre plus longtemps", "Augmente vos PV maximum et vos PV actuels.", "max_hp", Color("dfa194")],
	["power", "Puissance", "Renforcer vos techniques", "Augmente la prouesse utilisée par vos techniques.", "attack_power", Color("e0ba76")],
	["resolve", "Résolution", "Mieux encaisser les coups", "Renforce l’armure et les boucliers que vous créez.", "armure", Color("88c8db")],
	["wisdom", "Sagesse", "Progresser plus vite", "Plus d’expérience gagnée aux prochaines rencontres.", "", Color("bba8e0")],
]

var _session: ExpeditionSession
var _read_only := false
var _built := false
var _reduced_motion := false
var _points: Label
var _guidance: Label
var _turn_resources: Label
var _stat_grid: GridContainer
var _attribute_grid: GridContainer
var _hp_bar: ProgressBar
var _stat_labels: Dictionary = {}
var _tiles: Dictionary = {}
var _previous_values: Dictionary = {}
var _tweens: Dictionary = {}
var _stat_tiles: Dictionary = {}
var _content: VBoxContainer
var _badge: PanelContainer
var _note: Label
var _compact := false
var _density_applied := false


func configure(session: ExpeditionSession, read_only: bool = false) -> void:
	_session = session
	_read_only = read_only
	_reduced_motion = GameManager.is_reduced_motion_enabled()
	if not _built:
		_build()
	refresh()


func _ready() -> void:
	if not GameManager.reduced_motion_changed.is_connected(_on_reduced_motion_changed):
		GameManager.reduced_motion_changed.connect(_on_reduced_motion_changed)
	resized.connect(_update_columns)
	_update_columns()


func _exit_tree() -> void:
	if GameManager.reduced_motion_changed.is_connected(_on_reduced_motion_changed):
		GameManager.reduced_motion_changed.disconnect(_on_reduced_motion_changed)
	_finish_motion()


func _build() -> void:
	_built = true
	name = "ExpeditionAttributesView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	ART.apply(self)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	add_child(heading)
	_guidance = _label(heading, "", 16, TEXT)
	_guidance.name = "AttributeGuidance"
	_guidance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := PanelContainer.new()
	_badge = badge
	badge.add_theme_stylebox_override("panel", _flat_panel(Color("29413d"), TEAL.darkened(0.48), 12, 9))
	heading.add_child(badge)
	_points = _label(badge, "", 17, TEAL)
	_points.name = "AttributePointsRemaining"
	_points.autowrap_mode = TextServer.AUTOWRAP_OFF
	_points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.name = "AttributeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var content := VBoxContainer.new()
	_content = content
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	_stat_grid = GridContainer.new()
	_stat_grid.name = "CurrentRunStats"
	_stat_grid.columns = 4
	_stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_grid.add_theme_constant_override("h_separation", 10)
	_stat_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(_stat_grid)
	_make_stat("health", "Vie · PV", "Vos réserves avant de tomber", "max_hp", Color("dfa194"))
	_make_stat("power", "Prouesse", "Puissance de vos techniques", "attack_power", GOLD)
	_make_stat("armor", "Armure", "Réduit les dégâts physiques", "armure", Color("88c8db"))
	_make_stat("dodge", "Esquive", "Chance d’éviter une attaque", "esquive", TEAL)
	_turn_resources = _label(content, "", 15, MUTED)
	_turn_resources.name = "AttributeTurnResources"
	_attribute_grid = GridContainer.new()
	_attribute_grid.name = "AttributeUpgradeCards"
	_attribute_grid.columns = 2
	_attribute_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attribute_grid.add_theme_constant_override("h_separation", 12)
	_attribute_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(_attribute_grid)
	for spec in ATTRIBUTES:
		_make_attribute(spec)
	var note := _label(content, "Les valeurs incluent votre équipement. Chaque point est conservé pour toute cette expédition.\nSurvolez une caractéristique pour consulter tous ses effets.", 14, MUTED)
	note.name = "AttributeRunExplanation"
	_note = note
	_points.tooltip_text = note.text
	_update_columns()


func _make_stat(id: String, title: String, description: String, icon_id: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _flat_panel(Color("172d34"), accent.darkened(0.55), 12, 10))
	_stat_grid.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	box.add_child(row)
	_icon(row, CatabasePaintedIconCatalog.stat_icon(icon_id), 28)
	_label(row, title, 15, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _label(box, "", 25, accent)
	value.name = "CurrentStat_" + id
	_stat_labels[id] = value
	var explanation := _label(box, description, 13, MUTED)
	_stat_tiles[id] = {"panel": panel, "box": box, "row": row, "value": value, "explanation": explanation, "accent": accent}
	panel.tooltip_text = description
	if id == "health":
		_hp_bar = ProgressBar.new()
		_hp_bar.name = "CurrentHealthBar"
		_hp_bar.custom_minimum_size.y = 5
		_hp_bar.show_percentage = false
		_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_bar.add_theme_stylebox_override("background", _flat_panel(Color("0d1b23"), Color.TRANSPARENT, 0, 0))
		_hp_bar.add_theme_stylebox_override("fill", _flat_panel(accent, Color.TRANSPARENT, 0, 0))
		box.add_child(_hp_bar)


func _make_attribute(spec: Array) -> void:
	var id := str(spec[0])
	var accent: Color = spec[5]
	var panel := PanelContainer.new()
	panel.name = "AttributeCard_" + id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ART.style("card"))
	_attribute_grid.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 9)
	box.add_child(heading)
	_icon(heading, ART.icon("resources", "level") if id == "wisdom" else CatabasePaintedIconCatalog.stat_icon(str(spec[4])), 39)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	heading.add_child(titles)
	var title := _label(titles, str(spec[1]), 21, accent)
	var purpose := _label(titles, str(spec[2]), 14, TEXT)
	var allocated := _label(heading, "", 13, MUTED)
	allocated.name = "Allocated_" + id
	allocated.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	allocated.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	allocated.autowrap_mode = TextServer.AUTOWRAP_OFF
	var description := _label(box, str(spec[3]), 15, MUTED)
	var preview := _label(box, "", 19, TEXT)
	preview.name = "AttributePreview_" + id
	var secondary := _label(box, "", 14, MUTED)
	secondary.name = "AttributeDetail_" + id
	secondary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.hide()
	box.add_child(footer)
	var button := Button.new()
	button.name = "Attribute_" + id
	button.custom_minimum_size.y = 40
	button.text = "Attribuer 1 point"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ART.apply_button(button)
	box.add_child(button)
	button.pressed.connect(func(): attribute_requested.emit(StringName(id)))
	button.mouse_entered.connect(_highlight_tile.bind(id, true))
	button.mouse_exited.connect(_highlight_tile.bind(id, false))
	button.focus_entered.connect(_highlight_tile.bind(id, true))
	button.focus_exited.connect(_highlight_tile.bind(id, false))
	_tiles[id] = {"panel": panel, "box": box, "title": title, "purpose": purpose, "description": description, "footer": footer, "allocated": allocated, "preview": preview, "secondary": secondary, "button": button, "accent": accent}


func refresh() -> void:
	if not _built or _session == null or _session.character == null:
		return
	var state := _session.character
	var champion := state.champion_progression
	if champion == null or champion.profile == null:
		return
	var unit := state.unit
	var available := champion.unspent_attribute_points
	var editable := not _read_only and _session.is_editable()
	_update_text(_points, "%d %s" % [available, "point disponible" if available == 1 else "points disponibles"], "points")
	_refresh_guidance()
	_update_text(_stat_labels.health, "%d / %d" % [unit.current_hp, unit.max_hp.get_int()], "health")
	_update_text(_stat_labels.power, str(unit.attack_power.get_int()), "power")
	_update_text(_stat_labels.armor, str(unit.armure.get_int()), "armor")
	_update_text(_stat_labels.dodge, "%d %%" % roundi(unit.esquive.get_value() * 100.0), "dodge")
	_stat_labels.power.tooltip_text = "La prouesse sert au calcul des dégâts et de certains boucliers. Chaque technique précise son propre effet."
	_stat_labels.armor.tooltip_text = "L’armure réduit les dégâts physiques. La résistance magique protège des dégâts magiques."
	_stat_labels.dodge.tooltip_text = "Chance d’esquiver une attaque qui peut être esquivée ; certains effets ne le permettent pas."
	var health_ratio := float(unit.current_hp) / float(maxi(1, unit.max_hp.get_int())) * 100.0
	_animate(_hp_bar, "value", health_ratio, 0.26)
	for row in state.get_champion_attribute_rows():
		var id := str(row.id)
		if not _tiles.has(id):
			continue
		var tile: Dictionary = _tiles[id]
		var count := int(row.points)
		var capped := id == "wisdom" and count >= champion.profile.wisdom_cap
		var button: Button = tile.button
		button.disabled = not editable or not bool(row.can_spend)
		button.visible = editable and available > 0
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		button.text = "Plafond atteint" if capped else "Aucun point disponible" if available == 0 else "Entre les rencontres" if not editable else "Attribuer 1 point"
		button.tooltip_text = "%s : %s. Ce choix est conservé pour cette expédition." % [str(row.name), str(row.effect)]
		var count_text := "%d / %d\npoints" % [count, champion.profile.wisdom_cap] if id == "wisdom" else "%d %s" % [count, "point" if count == 1 else "points"]
		_update_text(tile.allocated, count_text, "allocated_" + id)
		var display := _preview_text(row, not button.disabled)
		_update_text(tile.preview, display, "preview_" + id)
		tile.preview.tooltip_text = "Avec 1 point supplémentaire : %s → %s %s." % [str(row.current), str(row.next), str(row.unit)] if not capped else "Le plafond de Sagesse est atteint."
		tile.secondary.text = _detail_text(row, champion, not button.disabled)
		var details := "%s\n%s\n%s\n%s" % [tile.description.text, str(row.effect), tile.preview.tooltip_text, tile.secondary.text]
		for control in [tile.panel, tile.title, tile.purpose, tile.preview]:
			control.tooltip_text = details
		button.tooltip_text += "\n" + details
		_highlight_tile(id, button.has_focus() or button.is_hovered())


func _preview_text(row: Dictionary, can_spend: bool) -> String:
	var id := str(row.id)
	var label_text := str({"vitality": "PV maximum", "power": "Prouesse", "resolve": "Armure", "wisdom": "Bonus d’XP"}[id])
	var current := str(row.current) + (" %" if id == "wisdom" else "")
	var next := str(row.next) + (" %" if id == "wisdom" else "")
	return "%s : %s → %s" % [label_text, current, next] if can_spend else "%s : %s" % [label_text, current]


func _detail_text(row: Dictionary, champion: ChampionProgressionState, can_spend: bool) -> String:
	var id := str(row.id)
	if id == "wisdom":
		return "Accélère les niveaux, sans donner de points de destin."
	if id == "resolve":
		var current := roundi(100.0 * (champion.get_shield_creation_multiplier() - 1.0))
		var next := roundi(100.0 * (champion.get_shield_creation_multiplier() + champion.profile.resolve_shield_percent_per_point - 1.0))
		return "Bonus aux boucliers : +%d %% → +%d %%" % [current, next] if can_spend else "Bonus aux boucliers créés : +%d %%" % current
	if can_spend:
		var impacts: Array = row.get("spell_impacts", [])
		for impact in impacts:
			if StringName(impact.get("spell_id", &"")) not in _session.character.loadout.get_spell_slot_ids():
				continue
			return "%s : %d → %d %s" % [str(impact.name), int(impact.current), int(impact.next), "dégâts" if StringName(impact.kind) == &"damage" else "bouclier"]
		if id == "vitality":
			return "Vous récupérez aussi %d PV en attribuant ce point." % maxi(0, int(row.next) - int(row.current))
		return str(row.effect).capitalize() + "."
	return "Votre santé pour les prochaines rencontres." if id == "vitality" else "Consultez vos compétences pour voir leurs dégâts."


func _update_columns() -> void:
	if not _built:
		return
	_stat_grid.columns = 4 if size.x >= 760.0 else 2
	_attribute_grid.columns = 2 if size.x >= 630.0 else 1
	var compact := size.y < 560.0 if size.y > 0.0 else get_viewport_rect().size.y <= 800.0
	if _density_applied and compact == _compact:
		return
	_compact = compact
	_density_applied = true
	_apply_density()


func _apply_density() -> void:
	add_theme_constant_override("separation", 6 if _compact else 12)
	_content.add_theme_constant_override("separation", 6 if _compact else 12)
	_badge.add_theme_stylebox_override("panel", _flat_panel(Color("29413d"), TEAL.darkened(0.48), 12, 5 if _compact else 9))
	_points.add_theme_font_size_override("font_size", 15 if _compact else 17)
	_guidance.add_theme_font_size_override("font_size", 14 if _compact else 16)
	_turn_resources.add_theme_font_size_override("font_size", 14 if _compact else 15)
	_note.show()
	_attribute_grid.add_theme_constant_override("v_separation", 8 if _compact else 12)
	for stat in _stat_tiles.values():
		var value: Label = stat.value
		var destination: Control = stat.row if _compact else stat.box
		if value.get_parent() != destination:
			value.reparent(destination, false)
			if not _compact:
				stat.box.move_child(value, 1)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF if _compact else TextServer.AUTOWRAP_WORD_SMART
		value.add_theme_font_size_override("font_size", 22 if _compact else 25)
		stat.explanation.add_theme_font_size_override("font_size", 12 if _compact else 13)
		stat.box.add_theme_constant_override("separation", 2 if _compact else 3)
		stat.panel.add_theme_stylebox_override("panel", _flat_panel(Color("172d34"), (stat.accent as Color).darkened(0.55), 10 if _compact else 12, 6 if _compact else 10))
	for tile in _tiles.values():
		var preview: Label = tile.preview
		var button: Button = tile.button
		var destination: Control = tile.footer if _compact else tile.box
		if preview.get_parent() != destination:
			preview.reparent(destination, false)
			button.reparent(destination, false)
			if not _compact:
				tile.box.move_child(preview, 2)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview.add_theme_font_size_override("font_size", 18 if _compact else 19)
		tile.footer.visible = _compact
		tile.description.visible = not _compact
		tile.secondary.visible = not _compact
		tile.title.add_theme_font_size_override("font_size", 19 if _compact else 21)
		tile.purpose.add_theme_font_size_override("font_size", 13 if _compact else 14)
		tile.box.add_theme_constant_override("separation", 5 if _compact else 7)
		var style := ART.style("card").duplicate() as StyleBox
		style.content_margin_top = 5 if _compact else 16
		style.content_margin_bottom = 5 if _compact else 16
		style.content_margin_left = 12 if _compact else 18
		style.content_margin_right = 12 if _compact else 18
		tile.panel.add_theme_stylebox_override("panel", style)
		button.add_theme_font_size_override("font_size", 15 if _compact else 16)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var button_style := ART.style("button", "pressed" if state == "hover_pressed" else state).duplicate() as StyleBox
			button_style.content_margin_left = 10 if _compact else 14
			button_style.content_margin_right = 10 if _compact else 14
			button_style.content_margin_top = 5 if _compact else 9
			button_style.content_margin_bottom = 5 if _compact else 9
			button.add_theme_stylebox_override(state, button_style)
	_refresh_guidance()


func _refresh_guidance() -> void:
	if _session == null or _session.character == null:
		return
	var champion := _session.character.champion_progression
	if champion == null:
		return
	var available := champion.unspent_attribute_points
	var editable := not _read_only and _session.is_editable()
	if available > 0 and editable:
		_guidance.text = "Choisissez une amélioration. Un clic dépense 1 point." if _compact else "Choisissez ce que vous voulez améliorer. Chaque bouton dépense 1 point."
	elif available > 0:
		_guidance.text = "Vos points s’attribuent entre les rencontres."
	else:
		_guidance.text = "Tous vos points sont attribués. Retrouvez ici vos forces à tout moment."
	_guidance.tooltip_text = "Survolez une caractéristique pour lire tous ses effets et le détail des techniques améliorées.\n" + _note.text
	var unit := _session.character.unit
	_turn_resources.tooltip_text = "À chaque tour : %d points d’action (PA) pour vos techniques · %d points de mouvement (PM) pour vous déplacer." % [unit.max_ap.get_int(), unit.max_mp.get_int()]
	_turn_resources.text = "%d PA : techniques · %d PM : déplacements · Renouvelés à chaque tour." % [unit.max_ap.get_int(), unit.max_mp.get_int()] if _compact else _turn_resources.tooltip_text


func _highlight_tile(id: String, highlighted: bool) -> void:
	if not _tiles.has(id):
		return
	var tile: Dictionary = _tiles[id]
	var button: Button = tile.button
	var active := (highlighted or button.has_focus() or button.is_hovered()) and not button.disabled
	_animate(tile.panel, "self_modulate", Color(1.10, 1.10, 1.06) if active else Color.WHITE, 0.14)
	tile.preview.add_theme_color_override("font_color", tile.accent if active else TEXT)


func _update_text(label: Label, value: String, key: String) -> void:
	var changed := _previous_values.has(key) and str(_previous_values[key]) != value
	label.text = value
	_previous_values[key] = value
	if changed and not _reduced_motion:
		label.modulate = Color(1.14, 1.36, 1.20)
		_animate(label, "modulate", Color.WHITE, 0.46)


func _animate(control: Control, property: String, target: Variant, duration: float) -> void:
	var key := "%d:%s" % [control.get_instance_id(), property]
	if _tweens.has(key):
		var previous: Tween = _tweens[key].tween
		if previous != null and previous.is_valid():
			previous.kill()
		_tweens.erase(key)
	if _reduced_motion or not is_inside_tree():
		control.set(property, target)
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, property, target, duration)
	_tweens[key] = {"tween": tween, "control": control, "property": property, "target": target}
	tween.finished.connect(func(): _tweens.erase(key))


func _on_reduced_motion_changed(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_finish_motion()
		ART.finish_motion(self)


func _finish_motion() -> void:
	for entry in _tweens.values():
		var tween: Tween = entry.tween
		if tween != null and tween.is_valid():
			tween.kill()
		if is_instance_valid(entry.control):
			entry.control.set(entry.property, entry.target)
	_tweens.clear()


func _label(parent: Control, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(label)
	return label


func _icon(parent: Control, texture: Texture2D, extent: int) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


func _flat_panel(background: Color, border: Color, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(6)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style
