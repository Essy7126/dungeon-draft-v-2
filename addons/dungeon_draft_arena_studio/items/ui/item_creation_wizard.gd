@tool
class_name ItemCreationWizard
extends PanelContainer

signal finished

const ACCENT_COLOR := Color(0.68, 0.60, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const ERROR_COLOR := Color(1.0, 0.45, 0.35)
const READY_COLOR := Color(0.55, 0.85, 0.55)
const PANEL_BACKGROUND := Color(0.137, 0.153, 0.184)

const STEP_TEMPLATE := 0
const STEP_PRESENTATION := 1
const STEP_EFFECTS := 2
const STEP_AVAILABILITY := 3
const STEP_DONE := 4
const STEP_COUNT := 5

var document: ItemStudioDocument = null
var catalog: ItemStudioCatalogService = null
var validation_service := ItemStudioValidationService.new()

var _tabs: TabContainer = null
var _sections := {}
var _step := STEP_TEMPLATE
var _active := false
var _target_item_id: StringName = &""
var _built := false
var _step_label: Label
var _hint_label: Label
var _previous_button: Button
var _next_button: Button
var _quit_button: Button


func _ready() -> void:
	_build_ui()


func setup(
		p_document: ItemStudioDocument,
		p_catalog: ItemStudioCatalogService,
		p_tabs: TabContainer,
		p_sections: Dictionary
	) -> void:
	document = p_document
	catalog = p_catalog
	_tabs = p_tabs
	_sections = p_sections.duplicate()
	_build_ui()
	visible = false


func is_active() -> bool:
	return _active


func current_step() -> int:
	return _step


func start() -> void:
	if document == null or document.working_copy == null or not document.working_copy.is_relic():
		return
	_active = true
	_target_item_id = document.working_copy.item_id
	_go_to(STEP_PRESENTATION)


func stop() -> void:
	if not _active:
		return
	_active = false
	_step = STEP_TEMPLATE
	visible = false
	_unlock_all_tabs()
	finished.emit()


func refresh() -> void:
	if not _active:
		return
	if document == null or document.working_copy == null or not document.working_copy.is_relic():
		stop()
		return
	if _step < STEP_DONE and document.working_copy.item_id != _target_item_id:
		stop()
		return
	_refresh_controls()


func _build_ui() -> void:
	if _built:
		return
	_built = true
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND
	style.set_corner_radius_all(6)
	style.border_width_left = 3
	style.border_color = ACCENT_COLOR
	style.set_content_margin_all(10)
	style.content_margin_left = 12
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_step_label.clip_text = true
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_step_label)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", MUTED_COLOR)
	texts.add_child(_hint_label)
	_quit_button = Button.new()
	_quit_button.text = "Quitter l’assistant"
	_quit_button.tooltip_text = "Revenir tout de suite à l’accès libre aux onglets"
	_quit_button.pressed.connect(stop)
	row.add_child(_quit_button)
	_previous_button = Button.new()
	_previous_button.text = "Précédent"
	_previous_button.pressed.connect(func(): _go_to(_step - 1))
	row.add_child(_previous_button)
	_next_button = Button.new()
	_next_button.text = "Suivant"
	_next_button.pressed.connect(_on_next_pressed)
	row.add_child(_next_button)
	visible = false


func _on_next_pressed() -> void:
	if _step >= STEP_DONE:
		stop()
		return
	if not _blocking_messages(_step).is_empty():
		return
	_go_to(_step + 1)


func _go_to(step: int) -> void:
	_step = clampi(step, STEP_PRESENTATION, STEP_DONE)
	_unlock_all_tabs()
	var section := int(_sections.get(_step, -1))
	if _tabs != null and section >= 0:
		_tabs.current_tab = clampi(section, 0, _tabs.get_tab_count() - 1)
	_apply_tab_lock()
	_refresh_controls()


func _refresh_controls() -> void:
	if not _built:
		return
	visible = _active
	if not _active:
		return
	var blocking := _blocking_messages(_step)
	_step_label.text = "Assistant relique — étape %d sur %d : %s" % [
		_step + 1, STEP_COUNT, _step_title(_step),
	]
	_previous_button.disabled = _step <= STEP_PRESENTATION
	_next_button.text = "Fermer l’assistant" if _step >= STEP_DONE else "Suivant"
	_next_button.disabled = not blocking.is_empty()
	if _step >= STEP_DONE:
		_hint_label.text = _recap_text()
		_hint_label.add_theme_color_override("font_color", MUTED_COLOR)
	elif blocking.is_empty():
		_hint_label.text = "%s Étape validée." % _step_hint(_step)
		_hint_label.add_theme_color_override("font_color", READY_COLOR)
	else:
		_hint_label.text = "\n".join(blocking)
		_hint_label.add_theme_color_override("font_color", ERROR_COLOR)


func _apply_tab_lock() -> void:
	if _tabs == null:
		return
	var open_section := int(_sections.get(_step, -1))
	for index in range(_tabs.get_tab_count()):
		var locked := _active and _step < STEP_DONE and open_section >= 0 and index != open_section
		_tabs.set_tab_disabled(index, locked)


func _unlock_all_tabs() -> void:
	if _tabs == null:
		return
	for index in range(_tabs.get_tab_count()):
		_tabs.set_tab_disabled(index, false)


func _step_title(step: int) -> String:
	match step:
		STEP_TEMPLATE: return "Modèle et nom"
		STEP_PRESENTATION: return "Présentation"
		STEP_EFFECTS: return "Effets"
		STEP_AVAILABILITY: return "Disponibilité"
	return "Terminé"


func _step_hint(step: int) -> String:
	match step:
		STEP_PRESENTATION: return "Donnez à la relique le nom que le joueur verra dans le jeu."
		STEP_EFFECTS: return "Composez au moins un effet complet."
		STEP_AVAILABILITY: return "Une relique profite à toute l’équipe : laissez les cases héros décochées."
	return ""


func _blocking_codes(step: int) -> Array:
	match step:
		STEP_PRESENTATION: return ["NAME_EMPTY"]
		STEP_EFFECTS: return ["RELIC_WITHOUT_EFFECT", "RELIC_LEGACY_EFFECT"]
		STEP_AVAILABILITY: return ["RELIC_HERO_COMPATIBILITY"]
	return []


func _is_blocking(step: int, code: String) -> bool:
	if code in _blocking_codes(step):
		return true
	return step == STEP_EFFECTS and code.begins_with("REACTIVE_")


func _blocking_messages(step: int) -> Array[String]:
	var result: Array[String] = []
	for message in _validation().get("messages", []):
		if int(message.get("severity", 0)) != ItemStudioValidationMessage.Severity.ERROR:
			continue
		if _is_blocking(step, str(message.get("code", ""))):
			result.append(str(message.get("message", "")))
	return result


func _validation() -> Dictionary:
	if document == null or document.working_copy == null:
		return {"valid": false, "errors": 0, "messages": []}
	return validation_service.validate_interactive(
		document.working_copy, catalog, document.destination_path, document.source_path,
		document.original_item_id if document.status == ItemStudioDocument.STATUS_SHARED else &"",
	)


func _recap_text() -> String:
	var definition := document.working_copy
	if definition == null:
		return ""
	var report := _validation()
	var status := "aucune erreur bloquante" if report.get("valid", false) \
		else "%d point(s) à corriger" % int(report.get("errors", 0))
	return "« %s » · %d effet(s) · %s. Tous les onglets sont de nouveau accessibles." % [
		definition.display_name, definition.reactive_effects.size(), status,
	]
