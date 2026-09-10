extends VBoxContainer
## A focused route view. Selection previews a destination; only the footer commits it.

signal destination_selected(node_id: String)
signal destination_committed(node_id: String)
signal preparation_requested

const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const OVERVIEW := preload("res://ui/expedition/expedition_route_overview.gd")
const MAP_CANVAS := preload("res://ui/expedition/expedition_map_canvas.gd")
const TITLE_FONT := preload("res://asset/ui/character_selection/selection_title_font.tres")
const ENCOUNTER_PREVIEW := preload("res://ui/expedition/expedition_encounter_preview.gd")
const TYPE_NAMES := {
	"normal": "Combat", "elite": "Épreuve élite", "hub": "Refuge", "merchant": "Marchand",
	"sanctuary": "Sanctuaire", "lore": "Mémoire", "event": "Rencontre", "cache": "Cache",
	"hidden": "Passage secret", "unknown": "Destination inconnue", "boss": "Gardien final",
}
const REWARD_NAMES := {
	"melee": "Contact et contrôle", "ranged": "Tir et préparation", "armor": "Armure et garde",
	"mobility": "Mouvement et esquive", "control": "Contrôle", "healing": "Soin et endurance",
	"elemental": "Feu, givre ou foudre", "discovery": "Découverte", "vitality": "PV et sacrifice",
	"signature": "Transformation", "victory": "Fin de la traversée", "unknown": "À découvrir",
}

var _session: ExpeditionSession
var _selected_node_id := ""
var _inspection_only := false
var _visible_nodes: Dictionary = {}
var _map_scroll: ScrollContainer
var _canvas: ExpeditionMapCanvas
var _heading: Label
var _progress: Label
var _destination_title: Label
var _destination_meta: Label
var _destination_hint: Label
var _destination_promise: Label
var _destination_icon: TextureRect
var _encounter_panel: VBoxContainer
var _encounter_name: Label
var _encounter_threat: Label
var _encounter_counterplay: Label
var _encounter_inspect: Button
var _encounter_dialog: AcceptDialog
var _encounter_details: RichTextLabel
var _guidance: Label
var _commit: Button
var _preparation: Button
var _scroll_restore_revision := 0
var _overview_layer: CanvasLayer


func configure(session: ExpeditionSession, selected_node_id: String, inspection_only: bool, scroll_position: int = -1) -> void:
	_session = session
	_inspection_only = inspection_only
	if not is_instance_valid(_map_scroll):
		_build()
	_visible_nodes.clear()
	if _session != null:
		for node in _session.route.get_visible_nodes():
			_visible_nodes[str(node.id)] = node
	_canvas.set_route(_session.route if _session != null else null)
	_selected_node_id = selected_node_id if _visible_nodes.has(selected_node_id) else ""
	if _selected_node_id.is_empty() and _session != null:
		for node in _session.route.get_available_nodes():
			if _visible_nodes.has(str(node.id)):
				_selected_node_id = str(node.id)
				break
		if _selected_node_id.is_empty() and _visible_nodes.has(_session.route.current_node_id):
			_selected_node_id = _session.route.current_node_id
	if _selected_node_id.is_empty() and not _visible_nodes.is_empty():
		_selected_node_id = str(_visible_nodes.keys()[0])
	_canvas.select_node(_selected_node_id)
	_heading.text = "Le parchemin de la descente" if inspection_only else "Choisissez votre chemin"
	_progress.text = "%d / 20 étapes franchies" % _session.route.completed_node_ids.size() if _session != null else ""
	_preparation.visible = not inspection_only
	_update_destination()
	_restore_scroll.call_deferred(scroll_position)


func get_scroll_position() -> int:
	return _map_scroll.scroll_vertical if is_instance_valid(_map_scroll) else 0


func _build() -> void:
	name = "ExpeditionRouteView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	ART_THEME.apply(self)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	add_child(heading_row)
	_heading = _label(heading_row, "", 24, ART_THEME.TEXT, true)
	_heading.name = "RouteHeading"
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress = _label(heading_row, "", 14, ART_THEME.MUTED)
	_progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	var expand := _button(heading_row, "Déplier toute la carte")
	expand.name = "ExpandFullRoute"
	expand.add_theme_font_size_override("font_size", 14)
	expand.custom_minimum_size.y = 36
	expand.tooltip_text = "Voir les vingt seuils et la légende en plein écran."
	expand.pressed.connect(_open_overview)
	var recenter := _button(heading_row, "Position actuelle")
	recenter.name = "RecenterRoute"
	recenter.add_theme_font_size_override("font_size", 14)
	recenter.custom_minimum_size.y = 36
	recenter.tooltip_text = "Revenir à votre position et aux prochains chemins accessibles."
	recenter.pressed.connect(func(): _restore_scroll(-1))
	var legend := _label(self, "Rouge : parcours accompli  ·  Vert : voies sélectionnées  ·  Pointillés : chemins possibles", 13, ART_THEME.MUTED)
	legend.name = "RouteLegend"
	_map_scroll = ScrollContainer.new()
	_map_scroll.name = "RouteMapScroll"
	_map_scroll.follow_focus = true
	_map_scroll.custom_minimum_size.y = 160
	_map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_map_scroll)
	_canvas = MAP_CANVAS.new()
	_canvas.name = "RouteMapCanvas"
	_canvas.custom_minimum_size.x = 580
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scroll.add_child(_canvas)
	_canvas.node_selected.connect(_on_destination_selected)
	_build_destination_card()
	_guidance = _label(self, "", 14, ART_THEME.MUTED)
	_guidance.name = "RouteGuidance"
	var footer := HBoxContainer.new()
	footer.name = "RouteActions"
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)
	_preparation = _button(footer, "←  Retour à la préparation")
	_preparation.name = "ReturnToPreparation"
	_preparation.pressed.connect(func(): preparation_requested.emit())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_commit = _button(footer, "Confirmer ce chemin  →", true)
	_commit.name = "CommitDestination"
	_commit.custom_minimum_size.x = 280
	_commit.pressed.connect(_commit_destination)


func _open_overview() -> void:
	if is_instance_valid(_overview_layer):
		return
	var layer := CanvasLayer.new()
	layer.name = "FullRouteLayer"
	layer.layer = 110
	_overview_layer = layer
	var overview := OVERVIEW.new()
	overview.route = _session.route if _session != null else null
	overview.selected_id = _selected_node_id
	overview.destination_selected.connect(_on_destination_selected)
	overview.closed.connect(func():
		remove_child(layer)
		layer.queue_free()
		_overview_layer = null
	)
	add_child(layer)
	layer.add_child(overview)


func _build_destination_card() -> void:
	var panel := PanelContainer.new()
	panel.name = "RouteDestinationDetails"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := ART_THEME.style("card")
	style.set_content_margin(SIDE_TOP, 10)
	style.set_content_margin(SIDE_BOTTOM, 10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	_destination_icon = TextureRect.new()
	_destination_icon.name = "RouteDestinationIcon"
	_destination_icon.custom_minimum_size = Vector2(44, 44)
	_destination_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_destination_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_destination_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_destination_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_destination_icon)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_stretch_ratio = 1.0
	identity.add_theme_constant_override("separation", 4)
	row.add_child(identity)
	_destination_meta = _label(identity, "", 13, ART_THEME.GOLD)
	_destination_meta.name = "RouteDestinationMeta"
	_destination_title = _label(identity, "", 22, ART_THEME.TEXT, true)
	_destination_title.name = "RouteDestinationTitle"
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_stretch_ratio = 1.45
	description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	description.add_theme_constant_override("separation", 5)
	row.add_child(description)
	_destination_hint = _label(description, "", 16, ART_THEME.TEXT)
	_destination_hint.name = "RouteDestinationHint"
	_destination_promise = _label(description, "", 15, ART_THEME.TEAL)
	_destination_promise.name = "RouteDestinationPromise"
	_encounter_panel = VBoxContainer.new()
	_encounter_panel.name = "RouteEncounterPreview"
	_encounter_panel.add_theme_constant_override("separation", 3)
	add_child(_encounter_panel)
	var encounter_heading := HBoxContainer.new()
	_encounter_panel.add_child(encounter_heading)
	_encounter_name = _label(encounter_heading, "", 16, ART_THEME.GOLD)
	_encounter_name.name = "RouteEncounterName"
	_encounter_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_encounter_inspect = _button(encounter_heading, "Forces et techniques")
	_encounter_inspect.name = "InspectEncounter"
	_encounter_inspect.custom_minimum_size.y = 30
	_encounter_inspect.add_theme_font_size_override("font_size", 13)
	_encounter_inspect.pressed.connect(_show_encounter_details)
	_encounter_threat = _label(_encounter_panel, "", 14, ART_THEME.TEXT)
	_encounter_threat.name = "RouteEncounterThreat"
	_encounter_counterplay = _label(_encounter_panel, "", 14, ART_THEME.TEAL)
	_encounter_counterplay.name = "RouteEncounterCounterplay"
	_encounter_dialog = AcceptDialog.new()
	_encounter_dialog.name = "EncounterDetailsDialog"
	_encounter_dialog.theme = ART_THEME.get_theme()
	_encounter_dialog.ok_button_text = "Revenir au chemin"
	_encounter_dialog.min_size = Vector2i(460, 320)
	add_child(_encounter_dialog)
	_encounter_details = RichTextLabel.new()
	_encounter_details.name = "EncounterTechniques"
	_encounter_details.add_theme_font_size_override("normal_font_size", 17)
	_encounter_details.add_theme_color_override("default_color", ART_THEME.TEXT)
	_encounter_details.selection_enabled = true
	_encounter_dialog.add_child(_encounter_details)


func _on_destination_selected(node_id: String) -> void:
	if not _visible_nodes.has(node_id):
		return
	_selected_node_id = node_id
	_canvas.select_node(node_id)
	_update_destination()
	destination_selected.emit(node_id)


func _update_destination() -> void:
	var selected: Dictionary = _visible_nodes.get(_selected_node_id, {})
	_update_encounter_preview(selected)
	_commit.disabled = true
	_commit.text = "Confirmer ce chemin  →"
	if selected.is_empty():
		_destination_icon.visible = false
		_destination_meta.text = "VOTRE PROCHAINE DESTINATION"
		_destination_title.text = "Le chemin vous attend"
		_destination_hint.text = "Sélectionnez une destination sur le parchemin."
		_destination_promise.text = ""
		_guidance.text = "Consultez une destination pour préparer votre départ."
		return
	var kind := CatabasePaintedIconCatalog.route_presentation_kind(selected)
	_destination_icon.texture = CatabasePaintedIconCatalog.map_node_icon(selected)
	_destination_icon.modulate = ART_THEME.GOLD
	_destination_icon.visible = _destination_icon.texture != null
	_destination_title.text = str(selected.get("title", "Destination inconnue"))
	_destination_meta.text = "SEUIL %02d  ·  %s" % [int(selected.get("depth", 0)), str(TYPE_NAMES.get(kind, "Destination inconnue")).to_upper()]
	_destination_hint.text = str(selected.get("hint", "Une part du chemin reste à découvrir."))
	var reward := str(selected.get("reward", ""))
	_destination_promise.text = "Promesse : " + str(REWARD_NAMES.get(reward, "À découvrir")) if not reward.is_empty() else ""
	if _session != null:
		var consequence := str(_session.route.get_choice_preview(_selected_node_id).get("summary", ""))
		if not consequence.is_empty():
			_destination_promise.text += "\n" + consequence
	_destination_promise.visible = not _destination_promise.text.is_empty()
	var available := _session != null and _session.route.phase == "map" and bool(selected.get("available", false))
	_commit.disabled = _inspection_only or not available
	_guidance.add_theme_color_override("font_color", ART_THEME.MUTED)
	if _inspection_only:
		_commit.text = "Consultation en combat"
		_guidance.text = "Le choix du prochain chemin sera disponible après cette rencontre."
	elif _session != null and _session.route.phase == "reward":
		_guidance.text = "Terminez cette étape avant de choisir votre prochain chemin."
	elif bool(selected.get("completed", false)):
		_guidance.text = "Cette étape est accomplie. Sélectionnez une destination marquée « À choisir »."
	elif not available:
		_guidance.text = "Cette destination est en consultation. Sélectionnez un chemin marqué « À choisir »."
	elif kind == "elite":
		_guidance.text = "Épreuve élite · victoire : 65 oboles. Confirmez pour entrer avec votre préparation actuelle."
		_guidance.add_theme_color_override("font_color", ART_THEME.DANGER)
	elif kind in ["normal", "boss"]:
		_guidance.text = "Confirmer lance le combat avec votre préparation actuelle."
	else:
		_guidance.text = "Votre destination est sélectionnée. Confirmez pour vous y rendre."
	_commit.tooltip_text = _guidance.text


func _update_encounter_preview(selected: Dictionary) -> void:
	var preview := ENCOUNTER_PREVIEW.describe(selected, _session.route.seed if _session != null else 0)
	_encounter_panel.visible = not preview.is_empty()
	_encounter_inspect.disabled = preview.is_empty()
	_encounter_details.text = str(preview.get("details", ""))
	_encounter_name.text = "%s · %d adversaire%s" % [str(preview.get("name", "")), int(preview.get("count", 0)), "s" if int(preview.get("count", 0)) > 1 else ""]
	_encounter_threat.text = "Menace : " + str(preview.get("summary", ""))
	_encounter_counterplay.text = "Piste tactique : " + str(preview.get("counterplay", ""))
	_encounter_dialog.title = str(preview.get("name", "Les forces en présence"))
	if _encounter_dialog.visible:
		_encounter_dialog.hide()


func _show_encounter_details() -> void:
	if not _encounter_panel.visible or _encounter_details.text.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	_encounter_dialog.popup_centered(Vector2i(mini(760, int(viewport_size.x) - 60), mini(520, int(viewport_size.y) - 80)))


func _commit_destination() -> void:
	if _inspection_only or _session == null or _session.route.phase != "map":
		return
	# Revalidate against the live route in case a session changed since configuration.
	for node in _session.route.get_available_nodes():
		if str(node.id) == _selected_node_id and _visible_nodes.has(_selected_node_id):
			_commit.disabled = true
			destination_committed.emit(_selected_node_id)
			return


func _current_scroll_position() -> int:
	if _session == null:
		return 0
	var depth := 1
	var available := _session.route.get_available_nodes()
	if not available.is_empty():
		depth = int(available[0].get("depth", 1))
	elif _visible_nodes.has(_session.route.current_node_id):
		depth = int(_visible_nodes[_session.route.current_node_id].get("depth", 1))
	# Keep the incoming path above the choices while showing the complete next row.
	return _canvas.get_depth_scroll_position(depth) + 40


func _restore_scroll(position: int) -> void:
	_scroll_restore_revision += 1
	var revision := _scroll_restore_revision
	if not is_inside_tree():
		return
	# Nested containers need their first layout before the scrollbar can accept a value.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_map_scroll) or revision != _scroll_restore_revision:
		return
	_map_scroll.scroll_vertical = maxi(0, position if position >= 0 else _current_scroll_position())


func _label(parent: Control, value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if heading:
		label.add_theme_font_override("font", TITLE_FONT)
	parent.add_child(label)
	return label


func _button(parent: Control, value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ART_THEME.apply_button(button, primary)
	parent.add_child(button)
	return button
