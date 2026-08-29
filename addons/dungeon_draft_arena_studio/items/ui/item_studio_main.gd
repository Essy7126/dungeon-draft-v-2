@tool
class_name ItemStudioMain
extends Control

signal history_state_changed

const CATEGORY_LABELS := ["Arme", "Armure", "Accessoire", "Consommable", "Parchemin", "Relique"]
const SLOT_LABELS := ["Aucun", "Arme", "Armure", "Accessoire"]
const USE_LABELS := ["Aucun", "Soin fixe", "Restauration de PA fixe"]
const RARITY_VALUES := [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const RARITY_LABELS := ["Commun", "Peu commun", "Rare", "Épique", "Légendaire"]
const REFRESH_LIGHT := 1
const REFRESH_STRUCTURE := 2
const REFRESH_HEAVY := 4
const ANALYSIS_DELAY_SECONDS := 0.25
const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const DIRTY_COLOR := Color(1.0, 0.75, 0.41)
const NARROW_BREAKPOINT := 1080.0
const COLLAPSED_SPLIT_OFFSET := 100000
const SECTION_PRESENTATION := 0
const SECTION_EQUIPMENT := 1
const SECTION_EFFECTS := 2
const SECTION_AVAILABILITY := 3
const SECTION_ADVANCED := 4
const STATUS_PILL_COLORS := {
	&"SHARED": Color(0.36, 0.78, 1.0),
	&"DRAFT": Color(0.98, 0.72, 0.28),
	&"NEW": Color(0.68, 0.60, 1.0),
}
const STATUS_PILL_LABELS := {
	&"SHARED": "PRODUCTION",
	&"DRAFT": "BROUILLON",
	&"NEW": "NOUVEAU",
}

var editor_interface = null
var editor_undo_redo = null
var project_context: StudioProjectContext = null
var reference_graph: StudioReferenceGraphService = null
var guided := true

var catalog := ItemStudioCatalogService.new()
var document := ItemStudioDocument.new()
var validation_service := ItemStudioValidationService.new()
var balance_service := ItemBalanceAnalysisService.new()
var comparison_service := ItemComparisonService.new()
var reference_service := ItemReferenceService.new()
var draft_service := ItemDraftService.new()
var publication_service := ItemPublicationService.new()
var ui_state := ItemStudioUiStateService.new()

var catalog_panel: ItemCatalogPanel
var card_preview: ItemCardPreview
var card_full_preview: ItemCardPreview
var analysis_panel: ItemAnalysisPanel
var effect_composer: ItemEffectComposer
var splitter: HSplitContainer
var analysis_split: VSplitContainer
var _analysis_split_offset := 0
var section_tabs: TabContainer
var catalog_toggle: Button
var header_identity_label: Label
var header_status_label: Label
var status_label: Label
var scope_label: Label
var path_label: Label
var starting_inventory_label: Label
var id_edit: LineEdit
var name_edit: LineEdit
var description_edit: TextEdit
var category_option: OptionButton
var rarity_option: OptionButton
var icon_picker: Control
var inventory_icon_picker: Control
var card_picker: Control
var slot_option: OptionButton
var stack_spin: SpinBox
var tags_edit: LineEdit
var fx_edit: LineEdit
var audio_edit: LineEdit
var use_option: OptionButton
var use_value_spin: SpinBox
var reward_check: CheckBox
var hero_checks := {}
var comparison_option: OptionButton
var analysis_hero_option: OptionButton
var analysis_spell_option: OptionButton
var analysis_target_option: OptionButton
var publish_button: Button
var creation_dialog: ItemCreationDialog
var creation_wizard: ItemCreationWizard
var usage_section: Control
var hero_section: Control
var duplication_dialog: ItemDuplicationDialog
var save_plan_dialog: ItemSavePlanDialog
var conflict_dialog: ItemConflictDialog
var dirty_dialog: ConfirmationDialog

var _pending_catalog_entry := {}
var _field_labels := {}
var _pending_save_mode: StringName = &""
var _updating := false
var _refresh_queued := false
var _pending_refresh := 0
var _text_snapshots := {}
var _analysis_timer: Timer
var _cached_validation := {}
var _cached_analysis := {}
var _cached_references: Array[String] = []
var _cached_fingerprint := ""
var _is_dirty := false
var _status_message := ""
var _narrow_layout := false


func set_guided(value: bool) -> void:
	guided = value
	for control in [path_label, id_edit, tags_edit, fx_edit, audio_edit]:
		if control != null:
			control.visible = not guided
	if section_tabs != null and section_tabs.get_tab_count() > SECTION_ADVANCED:
		section_tabs.set_tab_hidden(SECTION_ADVANCED, guided)
	if analysis_panel != null:
		analysis_panel.set_guided(guided)


func setup(
		host_editor_interface,
		undo_manager,
		shared_context: StudioProjectContext = null,
		shared_reference_graph: StudioReferenceGraphService = null
	) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager
	project_context = shared_context
	reference_graph = shared_reference_graph


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_build_dialogs()
	document.refresh_requested.connect(_on_document_refresh_requested)
	document.dirty_changed.connect(_on_dirty_changed)
	_analysis_timer = Timer.new()
	_analysis_timer.one_shot = true
	_analysis_timer.wait_time = ANALYSIS_DELAY_SECONDS
	_analysis_timer.timeout.connect(_run_heavy_analyses)
	add_child(_analysis_timer)
	if project_context != null:
		project_context.register_transition_handler(
			&"items", _transition_save, _transition_draft, _transition_discard
		)
		project_context.scope_changed.connect(_on_scope_changed)
	_on_scope_changed(project_context.edit_scope if project_context != null else StudioProjectContext.SCOPE_SHARED)
	_refresh_catalog()
	if catalog_panel.item_list.item_count > 0:
		catalog_panel.item_list.select(0)
		_on_catalog_entry_requested(catalog_panel.item_list.get_item_metadata(0) as Dictionary)
	else:
		_queue_refresh()


func _notification(what: int) -> void:
	# Le même Studio est reparenté entre l'hôte intégré et la fenêtre native.
	# Un EXIT_TREE intermédiaire ne doit pas désarmer la protection dirty.
	if what == NOTIFICATION_PREDELETE and project_context != null:
		project_context.unregister_transition_handler(&"items")


func _build_interface() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	root.add_child(_build_action_bar())
	# L'éditeur et le panneau d'analyse se partagent une hauteur fixe : la poignée
	# du VSplitContainer prend de la place à l'un pour la donner à l'autre, au lieu
	# d'allonger le total et de déborder hors de la fenêtre.
	analysis_split = VSplitContainer.new()
	analysis_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	analysis_split.dragged.connect(_on_analysis_split_dragged)
	root.add_child(analysis_split)
	splitter = HSplitContainer.new()
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.size_flags_stretch_ratio = 2.5
	analysis_split.add_child(splitter)
	catalog_panel = ItemCatalogPanel.new()
	catalog_panel.entry_requested.connect(_on_catalog_entry_requested)
	catalog_panel.filters_changed.connect(func(_filters): _remember_ui_state())
	catalog_panel.reward_bulk_apply_requested.connect(_on_reward_bulk_apply_requested)
	splitter.add_child(catalog_panel)
	splitter.add_child(_build_editor_column())
	analysis_panel = ItemAnalysisPanel.new()
	analysis_panel.navigation_resolver = func(path, code): return int(_navigation_target(path, code).get("section", -1)) >= 0
	analysis_panel.message_activated.connect(_on_analysis_message_activated)
	analysis_panel.expanded_changed.connect(_on_analysis_expanded_changed)
	analysis_split.add_child(analysis_panel)
	_build_analysis_controls()
	_on_analysis_expanded_changed(analysis_panel.is_expanded())
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _on_analysis_expanded_changed(expanded: bool) -> void:
	if analysis_split == null:
		return
	# Replié, on pousse le séparateur au maximum vers le bas : le panneau retombe
	# sur sa hauteur minimale (sa barre). La position choisie par l'utilisateur est
	# conservée à part et restaurée à la réouverture.
	analysis_split.split_offset = _analysis_split_offset if expanded else COLLAPSED_SPLIT_OFFSET
	_remember_ui_state()


func _on_analysis_split_dragged(offset: int) -> void:
	if analysis_panel == null or not analysis_panel.is_expanded():
		return
	_analysis_split_offset = offset
	_remember_ui_state()


func _build_editor_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 360
	column.add_theme_constant_override("separation", 8)
	column.add_child(_build_editor_header())
	section_tabs = TabContainer.new()
	section_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_tabs.tab_changed.connect(func(_index): _remember_ui_state())
	column.add_child(section_tabs)
	_build_presentation_section(_add_section_tab("Présentation"))
	_build_equipment_section(_add_section_tab("Équipement"))
	_build_effects_section(_add_section_tab("Effets"))
	_build_availability_section(_add_section_tab("Disponibilité"))
	_build_advanced_section(_add_section_tab("Avancé"))
	creation_wizard = ItemCreationWizard.new()
	creation_wizard.setup(document, catalog, section_tabs, {
		ItemCreationWizard.STEP_PRESENTATION: SECTION_PRESENTATION,
		ItemCreationWizard.STEP_EFFECTS: SECTION_EFFECTS,
		ItemCreationWizard.STEP_AVAILABILITY: SECTION_AVAILABILITY,
	})
	creation_wizard.finished.connect(_queue_refresh)
	column.add_child(creation_wizard)
	return column


func _build_editor_header() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.137, 0.153, 0.184)
	style.set_corner_radius_all(6)
	style.border_width_bottom = 2
	style.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.35)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	catalog_toggle = Button.new()
	catalog_toggle.text = "☰"
	catalog_toggle.tooltip_text = "Afficher ou masquer le catalogue"
	catalog_toggle.visible = false
	catalog_toggle.pressed.connect(_toggle_catalog)
	row.add_child(catalog_toggle)
	card_preview = ItemCardPreview.new()
	card_preview.compact = true
	card_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card_preview)
	var meta := VBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.size_flags_stretch_ratio = 0.6
	meta.add_theme_constant_override("separation", 5)
	row.add_child(meta)
	header_status_label = Label.new()
	header_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_status_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_status_label.add_theme_font_size_override("font_size", 11)
	meta.add_child(header_status_label)
	header_identity_label = Label.new()
	header_identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_identity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_identity_label.clip_text = true
	header_identity_label.custom_minimum_size.x = 120
	header_identity_label.add_theme_color_override("font_color", MUTED_COLOR)
	meta.add_child(header_identity_label)
	return panel


func _add_section_tab(tab_title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	section_tabs.add_child(scroll)
	section_tabs.set_tab_title(section_tabs.get_tab_count() - 1, tab_title)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func _build_analysis_controls() -> void:
	var host := analysis_panel.controls_container
	analysis_hero_option = _inline_option(host, "Héros analysé", [])
	analysis_hero_option.tooltip_text = "Héros compatible utilisé par la projection isolée"
	analysis_hero_option.item_selected.connect(_on_analysis_hero_selected)
	analysis_spell_option = _inline_option(host, "Sort analysé", [])
	analysis_spell_option.tooltip_text = "Sort réel du loadout de production du héros"
	analysis_spell_option.item_selected.connect(_on_analysis_spell_selected)
	analysis_target_option = _inline_option(host, "Profil cible", [
		"Saine · 100 % PV", "Blessée · 50 % PV", "Critique · 35 % PV", "Presque vaincue · 1 % PV",
	])
	for target_index in analysis_target_option.item_count:
		analysis_target_option.set_item_metadata(target_index, [1.0, 0.5, 0.35, 0.01][target_index])
	analysis_target_option.item_selected.connect(_on_analysis_target_selected)
	comparison_option = _inline_option(host, "Comparer avec", [])
	comparison_option.tooltip_text = "Comparer avec un objet de même catégorie, emplacement et audience"
	comparison_option.custom_minimum_size.x = 230
	comparison_option.item_selected.connect(func(_index):
		analysis_panel.open_section(ItemAnalysisPanel.SECTION_COMPARISON)
		_queue_refresh_flags(REFRESH_LIGHT)
	)


func _inline_option(parent: Control, label_text: String, values: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", MUTED_COLOR)
	parent.add_child(label)
	var option := OptionButton.new()
	option.clip_text = true
	option.custom_minimum_size.x = 150
	for value in values:
		option.add_item(str(value))
	parent.add_child(option)
	return option


func open_section(section: int) -> void:
	if section_tabs == null:
		return
	section_tabs.current_tab = clampi(section, 0, section_tabs.get_tab_count() - 1)


func _on_analysis_message_activated(property_path: String, code: String) -> void:
	var target := _navigation_target(property_path, code)
	var section := int(target.get("section", -1))
	if section < 0:
		return
	if creation_wizard != null and creation_wizard.is_active() \
			and creation_wizard.current_section() != section:
		_set_status_message("Terminez l’étape en cours de l’assistant pour corriger ce point.")
		return
	open_section(section)
	var control := target.get("control") as Control
	if control != null:
		_focus_control(control)
	var note := str(target.get("note", ""))
	if not note.is_empty():
		_set_status_message(note)


func _focus_control(control: Control) -> void:
	# Un frame d'attente : le TabContainer et la ScrollContainer viennent de changer
	# d'onglet, leur mise en page n'est pas encore recalculée.
	await get_tree().process_frame
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var scroll := _ancestor_scroll(control)
	if scroll != null:
		scroll.ensure_control_visible(control)
	if control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()
	_flash_control(control)


func _ancestor_scroll(control: Control) -> ScrollContainer:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _flash_control(control: Control) -> void:
	var tween := create_tween()
	tween.tween_property(control, "modulate", ACCENT_COLOR, 0.12)
	tween.tween_property(control, "modulate", Color.WHITE, 0.5)


func _navigation_target(property_path: String, code: String) -> Dictionary:
	if property_path.begins_with("reactive_effects") \
			or property_path.begins_with("stat_modifiers") \
			or property_path.begins_with("spell_modifiers"):
		return {"section": SECTION_EFFECTS}
	match property_path:
		"display_name":
			return {"section": SECTION_PRESENTATION, "control": name_edit}
		"description":
			return {"section": SECTION_PRESENTATION, "control": description_edit}
		"icon":
			return {"section": SECTION_PRESENTATION, "control": icon_picker}
		"inventory_icon":
			return {"section": SECTION_PRESENTATION, "control": inventory_icon_picker}
		"card_texture":
			return {"section": SECTION_PRESENTATION, "control": card_picker}
		"item_id":
			return {"section": SECTION_ADVANCED, "control": id_edit}
		"stack_limit":
			return {"section": SECTION_EQUIPMENT, "control": stack_spin}
		"use_effect":
			return {"section": SECTION_EQUIPMENT, "control": use_option}
		"equipment_slot":
			return {
				"section": SECTION_EQUIPMENT, "control": category_option,
				"note": "L’emplacement découle de la catégorie : corrigez la catégorie.",
			}
		"compatible_character_ids":
			return {"section": SECTION_AVAILABILITY}
		"tags":
			return {"section": SECTION_AVAILABILITY, "control": tags_edit}
	if code in ["PATH_COLLISION", "ITEM_ID_DUPLICATE", "PUBLISHED_ID_IMMUTABLE"]:
		return {"section": SECTION_ADVANCED, "control": id_edit}
	return {"section": -1}


func _toggle_catalog() -> void:
	if catalog_panel != null:
		catalog_panel.visible = not catalog_panel.visible


func _apply_responsive_layout() -> void:
	if catalog_panel == null or catalog_toggle == null:
		return
	var narrow := size.x > 0.0 and size.x < NARROW_BREAKPOINT
	catalog_panel.custom_minimum_size.x = 240 if narrow else 264
	if narrow == _narrow_layout:
		return
	_narrow_layout = narrow
	catalog_toggle.visible = narrow
	catalog_panel.visible = not narrow


func _build_action_bar() -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("separation", 6)
	margin.add_child(bar)
	_action_button(bar, "Nouveau", func(): creation_dialog.open_dialog(), "Créer une version en cours sans écrire sur disque")
	_action_button(bar, "Dupliquer", _show_duplication_dialog, "Dupliquer vers un brouillon isolé")
	publish_button = _action_button(bar, "Publier", publish, "Publier dans un dossier auto-découvert par le catalogue runtime")
	bar.add_child(_build_secondary_menu())
	scope_label = Label.new()
	scope_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scope_label.add_theme_color_override("font_color", MUTED_COLOR)
	bar.add_child(scope_label)
	status_label = Label.new()
	bar.add_child(status_label)
	return panel


func _build_secondary_menu() -> MenuButton:
	var menu := MenuButton.new()
	menu.text = "⋯"
	menu.tooltip_text = "Actions secondaires de l’objet · Sauver, Valider et Tester restent dans la barre du Studio"
	menu.custom_minimum_size.x = 34
	var popup := menu.get_popup()
	popup.add_item("Recharger depuis le disque", 0)
	popup.add_item("Comparer avec un autre objet…", 1)
	popup.add_item("Voir les références entrantes", 2)
	popup.id_pressed.connect(func(id):
		match id:
			0: _reload_document()
			1: _focus_comparison()
			2: _show_references()
	)
	popup.about_to_popup.connect(func():
		popup.set_item_disabled(
			popup.get_item_index(0),
			document.working_copy == null or document.source == null,
		)
	)
	return menu


func _build_presentation_section(parent: VBoxContainer) -> void:
	var identity := _section(parent, "IDENTITÉ")
	var identity_grid := _grid(identity)
	name_edit = _line(identity_grid, "Nom affiché dans le jeu", "Nom affiché en français")
	_bind_text_transaction(name_edit, "Modifier le nom", func(value): document.working_copy.display_name = value)
	rarity_option = _option(identity_grid, "Rareté", RARITY_LABELS, RARITY_VALUES)
	rarity_option.item_selected.connect(func(index): _record("Modifier la rareté", func(): document.working_copy.rarity = StringName(rarity_option.get_item_metadata(index))))
	var description := _section(parent, "DESCRIPTION JOUEUR")
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 110
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_bind_text_edit_transaction(description_edit, "Modifier la description", func(value): document.working_copy.description = value)
	description.add_child(description_edit)
	var visuals := _section(parent, "IMAGES")
	var visuals_grid := _grid(visuals)
	icon_picker = _texture_field(visuals_grid, "Icône", &"icon", "Image principale : sert d’icône d’inventaire et de carte de récompense tant qu’aucune autre image n’est fournie.")
	inventory_icon_picker = _texture_field(visuals_grid, "Icône d’inventaire", &"inventory_icon", "Facultatif : remplace l’icône principale dans l’inventaire uniquement.")
	card_picker = _texture_field(visuals_grid, "Carte de récompense", &"card_texture", "Facultatif : remplace l’icône principale sur l’écran de récompense.")
	var preview := _section(parent, "CARTE DE RÉCOMPENSE")
	card_full_preview = ItemCardPreview.new()
	preview.add_child(card_full_preview)


func _texture_field(
		parent: GridContainer, label_text: String, property: StringName, tooltip: String
	) -> Control:
	var label := _label(label_text)
	label.tooltip_text = tooltip
	parent.add_child(label)
	if not Engine.is_editor_hint():
		var fallback := Label.new()
		fallback.text = "Sélecteur disponible dans l’éditeur Godot."
		fallback.add_theme_color_override("font_color", MUTED_COLOR)
		parent.add_child(fallback)
		_field_labels[fallback.get_instance_id()] = label
		return fallback
	var picker := EditorResourcePicker.new()
	picker.base_type = "Texture2D"
	picker.tooltip_text = tooltip
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.resource_changed.connect(func(resource: Resource):
		if _updating or document.working_copy == null:
			return
		if document.working_copy.get(property) == resource:
			return
		_record("Modifier %s" % label_text.to_lower(), func(): document.working_copy.set(property, resource))
	)
	parent.add_child(picker)
	_field_labels[picker.get_instance_id()] = label
	return picker


func _sync_texture_field(picker: Control, texture: Texture2D) -> void:
	if picker == null or not Engine.is_editor_hint():
		return
	if picker is EditorResourcePicker:
		(picker as EditorResourcePicker).edited_resource = texture


func _build_equipment_section(parent: VBoxContainer) -> void:
	var inventory := _section(parent, "INVENTAIRE ET ÉQUIPEMENT")
	var inventory_grid := _grid(inventory)
	category_option = _option(inventory_grid, "Catégorie", CATEGORY_LABELS)
	category_option.item_selected.connect(_on_category_selected)
	slot_option = _option(inventory_grid, "Emplacement", SLOT_LABELS)
	slot_option.item_selected.connect(func(index): _record("Modifier l’emplacement", func(): document.working_copy.equipment_slot = index - 1))
	# L’emplacement est entièrement déterminé par la catégorie : le champ reste
	# synchronisé mais n’est jamais montré, toute saisie manuelle ne pourrait
	# produire qu’une erreur CATEGORY_SLOT_MISMATCH.
	_set_field_visible(slot_option, false)
	stack_spin = _spin(inventory_grid, "Taille de pile", 1.0, 99.0, 1.0)
	stack_spin.value_changed.connect(func(value): _record("Modifier la pile", func(): document.working_copy.stack_limit = int(value), "stack_limit"))
	var usage := _section(parent, "USAGE")
	usage_section = usage.get_parent() as Control
	var usage_grid := _grid(usage)
	use_option = _option(usage_grid, "Effet d’usage", USE_LABELS)
	use_option.item_selected.connect(func(index): _record("Modifier l’effet d’usage", func(): document.working_copy.use_effect = index))
	use_value_spin = _spin(usage_grid, "Valeur d’usage", 0.0, 9999.0, 1.0)
	use_value_spin.value_changed.connect(func(value): _record("Modifier la valeur d’usage", func(): document.working_copy.use_value = value, "use_value"))


func _build_effects_section(parent: VBoxContainer) -> void:
	effect_composer = ItemEffectComposer.new()
	effect_composer.setup(document)
	effect_composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(effect_composer)


func _build_availability_section(parent: VBoxContainer) -> void:
	var audience := _section(parent, "HÉROS COMPATIBLES")
	hero_section = audience.get_parent() as Control
	var compatibility := HFlowContainer.new()
	compatibility.add_theme_constant_override("h_separation", 14)
	for hero_id in [&"elf", &"mage", &"warrior"]:
		var check := CheckBox.new()
		check.text = {&"elf": "Elfe", &"mage": "Mage", &"warrior": "Guerrier"}[hero_id]
		check.tooltip_text = "Aucune case cochée signifie : tous les héros"
		check.toggled.connect(func(enabled): _set_hero_compatibility(hero_id, enabled))
		hero_checks[hero_id] = check
		compatibility.add_child(check)
	audience.add_child(compatibility)
	var acquisition := _section(parent, "COMMENT L’OBTENIR")
	reward_check = CheckBox.new()
	reward_check.text = "Peut apparaître comme récompense en début de partie"
	reward_check.tooltip_text = "Même réglage que la colonne « Récompense ? » du catalogue : contrôle explicitement le tag first_run_equipment_reward"
	reward_check.toggled.connect(_on_reward_toggled)
	acquisition.add_child(reward_check)
	starting_inventory_label = Label.new()
	starting_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	starting_inventory_label.add_theme_color_override("font_color", MUTED_COLOR)
	acquisition.add_child(starting_inventory_label)
	var tags := _section(parent, "ÉTIQUETTES")
	var tags_grid := _grid(tags)
	tags_edit = _line(tags_grid, "Étiquettes", "Étiquettes séparées par des virgules")
	_bind_text_transaction(tags_edit, "Modifier les tags", func(value): document.working_copy.tags = _parse_string_names(value))


func _build_advanced_section(parent: VBoxContainer) -> void:
	var identity := _section(parent, "IDENTIFIANT TECHNIQUE")
	var identity_grid := _grid(identity)
	id_edit = _line(identity_grid, "item_id", "Identifiant runtime stable")
	_bind_text_transaction(id_edit, "Modifier l’identifiant", func(value): document.working_copy.item_id = StringName(value))
	var profiles := _section(parent, "EFFETS VISUELS ET SONORES")
	var profiles_grid := _grid(profiles)
	fx_edit = _line(profiles_grid, "Effet visuel", "Profil de présentation des récompenses")
	_bind_text_transaction(fx_edit, "Modifier le profil VFX", func(value): document.working_copy.reward_fx_profile = StringName(value))
	audio_edit = _line(profiles_grid, "Effet sonore", "Profil audio des récompenses")
	_bind_text_transaction(audio_edit, "Modifier le profil audio", func(value): document.working_copy.reward_audio_profile = StringName(value))
	var integration := _section(parent, "EMPLACEMENT DU FICHIER")
	path_label = Label.new()
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.add_theme_color_override("font_color", MUTED_COLOR)
	integration.add_child(path_label)
	var note := Label.new()
	note.text = "Les icônes et cartes restent partagées comme assets immuables ; les sous-ressources d’effets sont dupliquées en profondeur. Aucun bouton de suppression n’est exposé en V1."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED_COLOR)
	integration.add_child(note)


func _build_dialogs() -> void:
	creation_dialog = ItemCreationDialog.new()
	creation_dialog.setup(catalog)
	creation_dialog.create_requested.connect(_create_document)
	add_child(creation_dialog)
	duplication_dialog = ItemDuplicationDialog.new()
	duplication_dialog.setup(catalog)
	duplication_dialog.duplicate_requested.connect(_duplicate_document)
	add_child(duplication_dialog)
	save_plan_dialog = ItemSavePlanDialog.new()
	save_plan_dialog.plan_confirmed.connect(_execute_pending_save)
	add_child(save_plan_dialog)
	conflict_dialog = ItemConflictDialog.new()
	add_child(conflict_dialog)
	dirty_dialog = ConfirmationDialog.new()
	dirty_dialog.title = "Changements non enregistrés"
	dirty_dialog.dialog_text = "La version en cours contient des changements. Choisissez explicitement quoi en faire avant d’ouvrir un autre objet."
	dirty_dialog.ok_button_text = "Ignorer et ouvrir"
	dirty_dialog.cancel_button_text = "Annuler"
	dirty_dialog.add_button("Enregistrer en brouillon", true, "save_draft")
	dirty_dialog.confirmed.connect(_discard_and_open_pending)
	dirty_dialog.custom_action.connect(_on_dirty_custom_action)
	add_child(dirty_dialog)


func ensure_initial_content_loaded() -> void:
	if document.working_copy == null:
		_refresh_catalog()
		if catalog_panel.item_list.item_count > 0:
			_on_catalog_entry_requested(catalog_panel.item_list.get_item_metadata(0) as Dictionary)


func _refresh_catalog(selected_path := "") -> void:
	reference_service.invalidate_cache()
	var rebuild := catalog.rebuild()
	if not rebuild.get("ok", false):
		_status_message = "Catalogue invalide : %s" % rebuild.get("error", "erreur")
		_refresh_status_label(document.working_copy != null)
		return
	catalog_panel.set_entries(catalog.entries(true))
	_rebuild_comparison_choices()
	var path := selected_path if not selected_path.is_empty() else document.source_path
	if not path.is_empty():
		catalog_panel.select_path(path)


func _on_catalog_entry_requested(entry: Dictionary) -> void:
	if document.is_dirty() and str(entry.get("path", "")) != document.source_path:
		_pending_catalog_entry = entry.duplicate(false)
		dirty_dialog.popup_centered(Vector2i(580, 220))
		return
	_open_catalog_entry(entry)


func _open_catalog_entry(entry: Dictionary) -> void:
	var definition := entry.get("definition") as ItemDefinition
	if definition == null:
		return
	document.open_definition(definition, StringName(entry.get("status", ItemStudioDocument.STATUS_SHARED)))
	_pending_catalog_entry.clear()
	_status_message = ""
	# Sélectionner un autre objet ne modifie rien sur le disque : on se contente de
	# surligner la ligne. Passer par _refresh_catalog() relirait tout le catalogue
	# avec CACHE_MODE_IGNORE et invaliderait le cache de références, ce qui relance
	# une caractérisation complète du projet à chaque changement d'objet.
	catalog_panel.select_path(definition.resource_path)
	_queue_refresh()


func _create_document(data: Dictionary) -> void:
	if document.is_dirty():
		_set_status_message("Enregistrez ou abandonnez la version en cours avant de créer un objet.")
		return
	var definition := ItemDefinition.new()
	definition.item_id = StringName(data.get("item_id", &""))
	definition.display_name = str(data.get("display_name", "Nouvel objet"))
	definition.description = ""
	definition.rarity = &"common"
	definition.compatible_character_ids = _to_string_names(data.get("compatible_character_ids", []) as Array)
	_apply_template(definition, int(data.get("template", ItemDefinition.Category.ACCESSORY)))
	document.create_new(definition)
	document.destination_path = str(data.get("draft_path", ""))
	if creation_wizard != null and definition.is_relic():
		creation_wizard.start()
	_queue_refresh()


func _duplicate_document(item_id: StringName, copy_acquisition_tags: bool) -> void:
	if document.working_copy == null:
		return
	var source := document.working_copy
	document.duplicate_as_new(source, item_id, copy_acquisition_tags)
	document.destination_path = ItemIdPathService.new().draft_path(item_id)
	_queue_refresh()


func _apply_template(definition: ItemDefinition, template: int) -> void:
	definition.category = clampi(template, ItemDefinition.Category.WEAPON, ItemDefinition.Category.RELIC)
	definition.stack_limit = 1
	match definition.category:
		ItemDefinition.Category.WEAPON:
			definition.equipment_slot = ItemDefinition.EquipmentSlot.WEAPON
		ItemDefinition.Category.ARMOR:
			definition.equipment_slot = ItemDefinition.EquipmentSlot.ARMOR
		ItemDefinition.Category.ACCESSORY:
			definition.equipment_slot = ItemDefinition.EquipmentSlot.ACCESSORY
		ItemDefinition.Category.RELIC:
			definition.equipment_slot = ItemDefinition.EquipmentSlot.NONE
			definition.stack_limit = 1
			definition.use_effect = ItemDefinition.UseEffect.NONE
			definition.compatible_character_ids.clear()
			var effect := ItemReactiveEffectData.new()
			effect.trigger_id = ItemReactiveEffectData.TRIGGER_COMBAT_START
			effect.target_id = ItemReactiveEffectData.TARGET_TRIGGER_HERO
			effect.result_id = ItemReactiveEffectData.RESULT_HEAL_FLAT
			definition.reactive_effects = [effect]
		_:
			definition.equipment_slot = ItemDefinition.EquipmentSlot.NONE
			definition.stack_limit = 5
			definition.use_effect = ItemDefinition.UseEffect.HEAL_FLAT
			definition.use_value = 10.0


func _on_category_selected(index: int) -> void:
	if _updating or document.working_copy == null:
		return
	document.record_edit("Modifier la catégorie", func():
		document.working_copy.category = index
		match index:
			ItemDefinition.Category.WEAPON: document.working_copy.equipment_slot = ItemDefinition.EquipmentSlot.WEAPON
			ItemDefinition.Category.ARMOR: document.working_copy.equipment_slot = ItemDefinition.EquipmentSlot.ARMOR
			ItemDefinition.Category.ACCESSORY: document.working_copy.equipment_slot = ItemDefinition.EquipmentSlot.ACCESSORY
			ItemDefinition.Category.RELIC:
				document.working_copy.equipment_slot = ItemDefinition.EquipmentSlot.NONE
				document.working_copy.stack_limit = 1
				document.working_copy.use_effect = ItemDefinition.UseEffect.NONE
				document.working_copy.compatible_character_ids.clear()
				if document.working_copy.reactive_effects.is_empty():
					document.working_copy.reactive_effects.append(ItemReactiveEffectData.new())
			_: document.working_copy.equipment_slot = ItemDefinition.EquipmentSlot.NONE
	, ItemStudioDocument.CHANGE_STRUCTURE, "category")


func _set_hero_compatibility(hero_id: StringName, enabled: bool) -> void:
	_record("Modifier la compatibilité", func():
		if enabled and hero_id not in document.working_copy.compatible_character_ids:
			document.working_copy.compatible_character_ids.append(hero_id)
		elif not enabled:
			document.working_copy.compatible_character_ids.erase(hero_id)
	)


func _on_reward_toggled(enabled: bool) -> void:
	if _updating or document.working_copy == null:
		return
	if not publication_service.set_reward_eligibility(document, enabled):
		_set_status_message("Seuls les équipements et les reliques peuvent rejoindre ce pool de récompenses.")


func _on_reward_bulk_apply_requested(changes: Array[Dictionary]) -> void:
	var written := 0
	var deferred := 0
	var failures: Array[String] = []
	for change in changes:
		var label := str(change.get("display_name", "Objet"))
		var enabled := bool(change.get("enabled", false))
		if str(change.get("path", "")) == document.source_path and document.working_copy != null:
			# L'objet ouvert porte peut-être d'autres modifications non
			# enregistrées : on ne réécrit pas son fichier dans son dos. Le
			# changement rejoint son historique, exactement comme la case de
			# l'onglet Disponibilité, et partira à la prochaine sauvegarde.
			if publication_service.set_reward_eligibility(document, enabled):
				deferred += 1
			else:
				failures.append(label)
			continue
		var result := _write_reward_eligibility(
			change.get("definition") as ItemDefinition,
			StringName(change.get("status", ItemStudioDocument.STATUS_SHARED)),
			enabled,
		)
		if result.get("ok", false):
			written += 1
		else:
			failures.append("%s (%s)" % [label, result.get("error", "erreur")])
	_refresh_catalog(document.source_path)
	_queue_refresh_flags(REFRESH_LIGHT)
	_set_status_message(_bulk_reward_message(written, deferred, failures))


func _write_reward_eligibility(
		definition: ItemDefinition,
		status: StringName,
		enabled: bool
	) -> Dictionary:
	if definition == null:
		return {"ok": false, "error": "définition introuvable"}
	# Document jetable : le même chemin d'édition que l'objet ouvert, donc la
	# même validation et la même écriture transactionnelle vérifiée.
	var staged := ItemStudioDocument.new()
	if not staged.open_definition(definition, status):
		return {"ok": false, "error": "ouverture impossible"}
	if not publication_service.set_reward_eligibility(staged, enabled):
		return {"ok": false, "error": "ni équipement ni relique"}
	# Un brouillon reste un brouillon : le publier le promouvrait en production.
	if status != ItemStudioDocument.STATUS_SHARED:
		return draft_service.save_draft(staged, catalog)
	return publication_service.publish(staged, catalog, true)


func _bulk_reward_message(written: int, deferred: int, failures: Array[String]) -> String:
	var parts: Array[String] = []
	if written > 0:
		parts.append("%d fichier%s écrit%s" % [written, _plural(written), _plural(written)])
	if deferred > 0:
		parts.append("%d en attente de sauvegarde (objet ouvert)" % deferred)
	if not failures.is_empty():
		parts.append("%d refusé%s : %s" % [
			failures.size(), _plural(failures.size()), ", ".join(failures),
		])
	if parts.is_empty():
		return "Récompenses : aucun changement appliqué."
	return "Récompenses : %s." % " · ".join(parts)


func _plural(count: int) -> String:
	return "s" if count > 1 else ""


func _record(action: String, mutator: Callable, merge_key := "") -> void:
	if _updating or document.working_copy == null:
		return
	document.record_edit(action, mutator, ItemStudioDocument.CHANGE_VALUE, action, merge_key)


func _queue_refresh() -> void:
	_queue_refresh_flags(REFRESH_LIGHT | REFRESH_STRUCTURE | REFRESH_HEAVY)


func _on_document_refresh_requested(kind: StringName, _path: String) -> void:
	match kind:
		ItemStudioDocument.CHANGE_VALUE, ItemStudioDocument.CHANGE_PREVIEW:
			_queue_refresh_flags(REFRESH_LIGHT | REFRESH_HEAVY)
		ItemStudioDocument.CHANGE_STRUCTURE:
			_queue_refresh_flags(REFRESH_LIGHT | REFRESH_STRUCTURE | REFRESH_HEAVY)
		_:
			_queue_refresh_flags(REFRESH_LIGHT | REFRESH_STRUCTURE | REFRESH_HEAVY)


func _queue_refresh_flags(flags: int) -> void:
	_pending_refresh |= flags
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_refresh_requests")


func _flush_refresh_requests() -> void:
	var flags := _pending_refresh
	_pending_refresh = 0
	_refresh_queued = false
	_refresh_document_views(bool(flags & REFRESH_STRUCTURE))
	if flags & REFRESH_HEAVY:
		_analysis_timer.start()


func _refresh_document_views(refresh_structure := false) -> void:
	var definition := document.working_copy
	var has_document := definition != null
	if refresh_structure:
		_updating = true
	id_edit.editable = has_document
	name_edit.editable = has_document
	description_edit.editable = has_document
	stack_spin.editable = has_document
	tags_edit.editable = has_document
	fx_edit.editable = has_document
	audio_edit.editable = has_document
	use_value_spin.editable = has_document
	category_option.disabled = not has_document
	rarity_option.disabled = not has_document
	slot_option.disabled = not has_document
	use_option.disabled = not has_document
	if has_document and refresh_structure:
		id_edit.text = str(definition.item_id)
		id_edit.editable = document.status != ItemStudioDocument.STATUS_SHARED
		name_edit.text = definition.display_name
		description_edit.text = definition.description
		_sync_texture_field(icon_picker, definition.icon)
		_sync_texture_field(inventory_icon_picker, definition.inventory_icon)
		_sync_texture_field(card_picker, definition.card_texture)
		category_option.select(clampi(definition.category, 0, category_option.item_count - 1))
		_select_option_metadata(rarity_option, definition.rarity)
		slot_option.select(clampi(definition.equipment_slot + 1, 0, slot_option.item_count - 1))
		stack_spin.value = definition.stack_limit
		tags_edit.text = ", ".join(_strings(definition.tags))
		fx_edit.text = str(definition.reward_fx_profile)
		audio_edit.text = str(definition.reward_audio_profile)
		use_option.select(clampi(definition.use_effect, 0, use_option.item_count - 1))
		use_value_spin.value = definition.use_value
		for hero_id in hero_checks:
			(hero_checks[hero_id] as CheckBox).button_pressed = hero_id in definition.compatible_character_ids
		reward_check.button_pressed = catalog.reward_eligible(definition)
		_refresh_field_visibility(definition)
		path_label.text = "Source : %s\nDestination : %s\nStatut : %s" % [
			document.source_path if not document.source_path.is_empty() else "nouvelle version en cours",
			document.destination_path if not document.destination_path.is_empty() else "calculée au moment du plan",
			document.status,
		]
		starting_inventory_label.text = "Inventaire initial : référence runtime en lecture seule" \
			if reference_service.readonly_starting_inventory_reference(definition) \
			else "Inventaire initial : aucune référence observée"
	elif not has_document:
		path_label.text = "Aucun objet sélectionné."
		starting_inventory_label.text = ""
	card_preview.show_definition(definition)
	card_full_preview.show_definition(definition)
	_refresh_header(definition)
	if effect_composer != null and refresh_structure:
		effect_composer.rebuild()
	elif effect_composer != null:
		effect_composer.refresh_summaries()
	if creation_wizard != null:
		creation_wizard.refresh()
	if refresh_structure:
		_rebuild_spell_analysis_choices(definition)
		_updating = false
	var comparison := _current_comparison(definition)
	var spell_projection := _selected_spell_projection(definition)
	analysis_panel.show_report(
		definition, _cached_validation, _cached_analysis, _cached_references,
		_cached_fingerprint, comparison, spell_projection,
	)
	_refresh_status_label(has_document)
	publish_button.disabled = not has_document or (project_context != null and project_context.edit_scope == StudioProjectContext.SCOPE_RUN_SPECIFIC)
	history_state_changed.emit()


func _refresh_header(definition: ItemDefinition) -> void:
	if header_identity_label == null:
		return
	if definition == null:
		header_identity_label.text = ""
		header_status_label.text = ""
		header_status_label.remove_theme_stylebox_override("normal")
		return
	header_identity_label.text = "%s · %s" % [
		definition.item_id,
		CATEGORY_LABELS[clampi(definition.category, 0, CATEGORY_LABELS.size() - 1)],
	]
	var status_text: String = STATUS_PILL_LABELS.get(document.status, str(document.status))
	var pill_color: Color = STATUS_PILL_COLORS.get(document.status, MUTED_COLOR)
	if _is_dirty:
		status_text += " · MODIFIÉ"
		pill_color = DIRTY_COLOR
	header_status_label.text = "  %s  " % status_text
	header_status_label.add_theme_color_override("font_color", pill_color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(pill_color.r, pill_color.g, pill_color.b, 0.14)
	style.border_color = Color(pill_color.r, pill_color.g, pill_color.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(3)
	header_status_label.add_theme_stylebox_override("normal", style)


func _refresh_status_label(has_document: bool) -> void:
	if status_label == null:
		return
	if not _status_message.is_empty():
		status_label.text = _status_message
		status_label.add_theme_color_override("font_color", MUTED_COLOR)
		return
	status_label.text = "" if not has_document else ("Modifié" if _is_dirty else "Sauvegardé")
	status_label.add_theme_color_override(
		"font_color", DIRTY_COLOR if _is_dirty else MUTED_COLOR
	)


func _set_status_message(message: String) -> void:
	_status_message = message
	_queue_refresh_flags(REFRESH_LIGHT)


func _run_heavy_analyses() -> void:
	var definition := document.working_copy
	_cached_validation = validation_service.validate_interactive(
		definition, catalog, document.destination_path, document.source_path,
		document.original_item_id if document.status == ItemStudioDocument.STATUS_SHARED else &"",
	)
	_cached_analysis = balance_service.analyze(document.preview_copy())
	_cached_references = reference_service.incoming_references(definition)
	_cached_fingerprint = document.current_fingerprint()
	_refresh_document_views(false)


func validate_document() -> Dictionary:
	var report := validation_service.validate(
		document.working_copy, catalog, document.destination_path,
		document.source_path,
		document.original_item_id if document.status == ItemStudioDocument.STATUS_SHARED else &"",
	)
	_cached_validation = report
	_queue_refresh_flags(REFRESH_LIGHT)
	return report


func test_document() -> Dictionary:
	var preview := document.preview_copy()
	var report := ItemRuntimePreviewService.new().preview_relic(preview) \
		if preview != null and preview.is_relic() else balance_service.analyze(preview)
	_queue_refresh_flags(REFRESH_LIGHT)
	return report


func save_as_draft() -> void:
	_show_save_plan(&"DRAFT")


func publish() -> void:
	if project_context != null and project_context.edit_scope == StudioProjectContext.SCOPE_RUN_SPECIFIC:
		_set_status_message("La portée « propre à une partie » est différée : aucun catalogue par partie n’existe.")
		return
	_show_save_plan(&"PUBLISH")


func _show_save_plan(mode: StringName) -> void:
	if document.working_copy == null:
		return
	_pending_save_mode = mode
	var reward_projection := publication_service.eligibility_projection(document, catalog)
	var reward_changed := bool(reward_projection.get("requires_publication_confirmation", false))
	var plan := draft_service.plan(document, catalog) if mode == &"DRAFT" \
		else publication_service.plan(document, catalog, reward_changed)
	if not plan.is_valid():
		conflict_dialog.show_conflicts(plan)
		return
	save_plan_dialog.show_plan(plan)


func _execute_pending_save(_confirmed_plan: ItemSavePlan) -> void:
	var result := {}
	if _pending_save_mode == &"DRAFT":
		result = draft_service.save_draft(document, catalog)
	elif _pending_save_mode == &"PUBLISH":
		var projection := publication_service.eligibility_projection(document, catalog)
		result = publication_service.publish(document, catalog, bool(projection.get("requires_publication_confirmation", false)))
	if not result.get("ok", false):
		_status_message = "Échec de sauvegarde : %s" % result.get("error", "erreur inconnue")
	else:
		_status_message = "Écriture vérifiée : %s" % result.get("path", "")
		if project_context != null:
			project_context.set_dirty(&"items", false)
			project_context.bump_generation(&"items")
		_refresh_catalog(str(result.get("path", "")))
	_pending_save_mode = &""
	_queue_refresh_flags(REFRESH_LIGHT)


func _reload_document() -> void:
	if document.source == null:
		return
	document.discard_changes()
	_queue_refresh()


func _show_duplication_dialog() -> void:
	if document.working_copy != null:
		duplication_dialog.open_for(document.working_copy)


func _focus_comparison() -> void:
	analysis_panel.open_section(ItemAnalysisPanel.SECTION_COMPARISON)
	if comparison_option != null:
		comparison_option.grab_focus()
	_queue_refresh_flags(REFRESH_LIGHT)


func _show_references() -> void:
	var references := reference_service.incoming_references(document.working_copy)
	analysis_panel.open_section(ItemAnalysisPanel.SECTION_REFERENCES)
	_set_status_message("%d référence(s) entrante(s) ; détail dans le tiroir d’analyse." % references.size())


func _rebuild_comparison_choices() -> void:
	if comparison_option == null:
		return
	var selected_path := str(comparison_option.get_item_metadata(comparison_option.selected)) if comparison_option.item_count > 0 else ""
	comparison_option.clear()
	comparison_option.add_item("Comparer avec…")
	comparison_option.set_item_metadata(0, "")
	for entry in catalog.entries(false):
		comparison_option.add_item("%s · %s" % [entry.get("display_name", "Objet"), entry.get("item_id", "")])
		comparison_option.set_item_metadata(comparison_option.item_count - 1, entry.get("path", ""))
		if str(entry.get("path", "")) == selected_path:
			comparison_option.select(comparison_option.item_count - 1)


func _current_comparison(definition: ItemDefinition) -> Dictionary:
	if definition == null or comparison_option == null or comparison_option.selected <= 0:
		return {}
	var path := str(comparison_option.get_item_metadata(comparison_option.selected))
	var other := load(path) as ItemDefinition
	return comparison_service.compare(definition, other)


func _rebuild_spell_analysis_choices(definition: ItemDefinition) -> void:
	if analysis_hero_option == null or analysis_spell_option == null:
		return
	var desired_hero := str(ui_state.get_value("comparison_hero", "elf"))
	var desired_spell := str(ui_state.get_value("comparison_spell", ""))
	analysis_hero_option.clear()
	for choice in balance_service.spell_choices(definition):
		analysis_hero_option.add_item(str(choice.get("display_name", "Héros")))
		var hero_index := analysis_hero_option.item_count - 1
		analysis_hero_option.set_item_metadata(hero_index, choice)
		if str(choice.get("character_id", "")) == desired_hero:
			analysis_hero_option.select(hero_index)
	if analysis_hero_option.item_count == 0:
		analysis_hero_option.add_item("Aucun héros compatible")
		analysis_hero_option.set_item_metadata(0, {})
		analysis_hero_option.disabled = true
		analysis_spell_option.clear()
		analysis_spell_option.add_item("Aucun sort disponible")
		analysis_spell_option.disabled = true
		return
	analysis_hero_option.disabled = false
	if analysis_hero_option.selected < 0:
		analysis_hero_option.select(0)
	var hero := analysis_hero_option.get_item_metadata(analysis_hero_option.selected) as Dictionary
	ui_state.set_value("comparison_hero", str(hero.get("character_id", "")))
	analysis_spell_option.clear()
	for spell_value in hero.get("spells", []) as Array:
		var spell := spell_value as Dictionary
		analysis_spell_option.add_item(str(spell.get("display_name", "Sort")))
		var spell_option_index := analysis_spell_option.item_count - 1
		analysis_spell_option.set_item_metadata(spell_option_index, spell)
		if str(spell.get("spell_id", "")) == desired_spell:
			analysis_spell_option.select(spell_option_index)
	if analysis_spell_option.item_count == 0:
		analysis_spell_option.add_item("Aucun sort disponible")
		analysis_spell_option.set_item_metadata(0, {})
		analysis_spell_option.disabled = true
		return
	analysis_spell_option.disabled = false
	if analysis_spell_option.selected < 0:
		analysis_spell_option.select(0)
	var selected_spell := analysis_spell_option.get_item_metadata(analysis_spell_option.selected) as Dictionary
	ui_state.set_value("comparison_spell", str(selected_spell.get("spell_id", "")))
	var desired_target := float(ui_state.get_value("comparison_target_hp", 1.0))
	for target_index in analysis_target_option.item_count:
		if is_equal_approx(float(analysis_target_option.get_item_metadata(target_index)), desired_target):
			analysis_target_option.select(target_index)
			break


func _selected_spell_projection(definition: ItemDefinition) -> Dictionary:
	if definition == null or analysis_hero_option == null or analysis_spell_option == null \
			or analysis_hero_option.disabled or analysis_spell_option.disabled:
		return {}
	var hero := analysis_hero_option.get_item_metadata(analysis_hero_option.selected) as Dictionary
	var spell := analysis_spell_option.get_item_metadata(analysis_spell_option.selected) as Dictionary
	if hero.is_empty() or spell.is_empty():
		return {}
	var target_hp_ratio := float(analysis_target_option.get_item_metadata(analysis_target_option.selected))
	return balance_service.project_selected_spell(
		definition, str(hero.get("path", "")), int(spell.get("index", -1)), target_hp_ratio,
	)


func _on_analysis_hero_selected(index: int) -> void:
	if _updating or index < 0:
		return
	var hero := analysis_hero_option.get_item_metadata(index) as Dictionary
	ui_state.set_value("comparison_hero", str(hero.get("character_id", "")))
	ui_state.set_value("comparison_spell", "")
	_queue_refresh_flags(REFRESH_LIGHT)


func _on_analysis_spell_selected(index: int) -> void:
	if _updating or index < 0:
		return
	var spell := analysis_spell_option.get_item_metadata(index) as Dictionary
	ui_state.set_value("comparison_spell", str(spell.get("spell_id", "")))
	_queue_refresh_flags(REFRESH_LIGHT)


func _on_analysis_target_selected(index: int) -> void:
	if _updating or index < 0:
		return
	ui_state.set_value("comparison_target_hp", analysis_target_option.get_item_metadata(index))
	_queue_refresh_flags(REFRESH_LIGHT)


func _discard_and_open_pending() -> void:
	if not _pending_catalog_entry.is_empty():
		_open_catalog_entry(_pending_catalog_entry)


func _on_dirty_custom_action(action: StringName) -> void:
	if action != &"save_draft":
		return
	var result := draft_service.save_draft(document, catalog)
	if result.get("ok", false):
		if project_context != null:
			project_context.set_dirty(&"items", false)
			project_context.bump_generation(&"items")
		_refresh_catalog()
		_open_catalog_entry(_pending_catalog_entry)
	else:
		_set_status_message("Brouillon refusé : %s" % result.get("error", "erreur"))


func _on_dirty_changed(dirty: bool) -> void:
	_is_dirty = dirty
	if project_context != null:
		project_context.set_dirty(&"items", dirty, {
			"item_id": str(document.working_copy.item_id) if document.working_copy != null else "",
			"path": document.source_path,
			"status": str(document.status),
		})
	history_state_changed.emit()


func _on_scope_changed(scope: StringName) -> void:
	if scope_label == null:
		return
	scope_label.text = "Portée : %s" % scope
	if scope == StudioProjectContext.SCOPE_RUN_SPECIFIC:
		scope_label.tooltip_text = "Différé : aucun catalogue d’objets propre à une partie n’existe pour le moment."
	else:
		scope_label.tooltip_text = "« Partagé » publie ; « Brouillon » conserve hors catalogue de production."
	_queue_refresh()


func _transition_save() -> Dictionary:
	if project_context != null and project_context.edit_scope == StudioProjectContext.SCOPE_RUN_SPECIFIC:
		return {"ok": false, "error": "RUN_SPECIFIC est différé pour les objets."}
	var result := publication_service.publish(document, catalog)
	if result.get("ok", false) and project_context != null:
		project_context.set_dirty(&"items", false)
		project_context.bump_generation(&"items")
	return result


func _transition_draft() -> Dictionary:
	var result := draft_service.save_draft(document, catalog)
	if result.get("ok", false) and project_context != null:
		project_context.set_dirty(&"items", false)
		project_context.bump_generation(&"items")
	return result


func _transition_discard() -> Dictionary:
	var result := document.discard_changes()
	if result.get("ok", false) and project_context != null:
		project_context.set_dirty(&"items", false)
	return result


func prepare_for_close() -> void:
	_remember_ui_state()


func get_state_snapshot() -> Dictionary:
	_remember_ui_state()
	return ui_state.snapshot()


func apply_state_snapshot(state: Dictionary) -> void:
	ui_state.restore(state)
	if catalog_panel == null:
		return
	var filters := state.get("filters", {}) as Dictionary
	catalog_panel.restore_filters(filters)
	open_section(int(state.get("section", SECTION_PRESENTATION)))
	if analysis_panel != null:
		analysis_panel.set_expanded(bool(state.get("analysis_expanded", analysis_panel.is_expanded())))
	_analysis_split_offset = int(state.get("analysis_split", _analysis_split_offset))
	if analysis_split != null and analysis_panel != null and analysis_panel.is_expanded():
		analysis_split.split_offset = _analysis_split_offset
	var selected_path := str(state.get("selected_path", ""))
	if catalog_panel.select_path(selected_path):
		for entry in catalog.entries(true):
			if str(entry.get("path", "")) == selected_path:
				_open_catalog_entry(entry)
				break


func _remember_ui_state() -> void:
	if catalog_panel == null:
		return
	ui_state.set_value("selected_path", document.source_path)
	ui_state.state["filters"] = catalog_panel.snapshot_filters()
	if section_tabs != null:
		ui_state.set_value("section", section_tabs.current_tab)
	ui_state.set_value("analysis_split", _analysis_split_offset)
	if analysis_panel != null:
		ui_state.set_value("analysis_expanded", analysis_panel.is_expanded())
	ui_state.set_value("scope", str(project_context.edit_scope) if project_context != null else "SHARED")
	if analysis_hero_option != null and analysis_hero_option.item_count > 0:
		var hero := analysis_hero_option.get_item_metadata(analysis_hero_option.selected) as Dictionary
		ui_state.set_value("comparison_hero", str(hero.get("character_id", "")))
	if analysis_spell_option != null and analysis_spell_option.item_count > 0:
		var spell := analysis_spell_option.get_item_metadata(analysis_spell_option.selected) as Dictionary
		ui_state.set_value("comparison_spell", str(spell.get("spell_id", "")))
	if analysis_target_option != null and analysis_target_option.item_count > 0:
		ui_state.set_value("comparison_target_hp", analysis_target_option.get_item_metadata(analysis_target_option.selected))


func history_can_undo() -> bool:
	return document.history.can_undo()


func history_can_redo() -> bool:
	return document.history.can_redo()


func history_undo() -> bool:
	return document.history.undo()


func history_redo() -> bool:
	return document.history.redo()


func history_undo_name() -> String:
	return document.history.get_undo_action_name()


func history_redo_name() -> String:
	return document.history.get_redo_action_name()


func history_entries() -> Array[Dictionary]:
	return document.history.get_history_entries()


func history_current_index() -> int:
	return document.history.get_current_index()


func history_jump_to(index: int) -> bool:
	return document.history.jump_to(index)


func history_document_name() -> String:
	if document.working_copy == null:
		return "Aucun objet"
	return "%s%s" % [document.working_copy.display_name, " *" if document.is_dirty() else ""]


func history_is_at_saved_state() -> bool:
	return document.history.is_at_saved_state()


func history_opening_is_saved() -> bool:
	return document.source != null


func cancel_active_gesture() -> bool:
	return false


func _section(parent: VBoxContainer, label_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	box.add_child(label)
	box.add_child(HSeparator.new())
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	box.add_child(content)
	return content


func _grid(parent: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid


func _line(parent: GridContainer, label_text: String, tooltip := "") -> LineEdit:
	var label := _label(label_text)
	parent.add_child(label)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = tooltip
	parent.add_child(field)
	_field_labels[field.get_instance_id()] = label
	return field


func _option(
		parent: GridContainer, label_text: String, values: Array, stored_values := []
	) -> OptionButton:
	var label := _label(label_text)
	parent.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	for index in range(values.size()):
		option.add_item(str(values[index]))
		if index < stored_values.size():
			option.set_item_metadata(index, stored_values[index])
	parent.add_child(option)
	_field_labels[option.get_instance_id()] = label
	return option


func _spin(parent: GridContainer, label_text: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var label := _label(label_text)
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	_field_labels[spin.get_instance_id()] = label
	return spin


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _set_field_visible(control: Control, is_visible: bool) -> void:
	if control == null:
		return
	control.visible = is_visible
	var label := _field_labels.get(control.get_instance_id()) as Label
	if label != null:
		label.visible = is_visible


func _refresh_field_visibility(definition: ItemDefinition) -> void:
	if definition == null:
		return
	var is_consumable := definition.is_consumable()
	_set_field_visible(stack_spin, is_consumable)
	_set_field_visible(use_option, is_consumable)
	_set_field_visible(
		use_value_spin,
		is_consumable and definition.use_effect != ItemDefinition.UseEffect.NONE,
	)
	if usage_section != null:
		usage_section.visible = is_consumable
	if hero_section != null:
		hero_section.visible = not definition.is_relic()
	reward_check.visible = definition.is_equippable() or definition.is_relic()


func _action_button(parent: Control, text: String, callback: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _bind_text_transaction(field: LineEdit, action: String, setter: Callable) -> void:
	field.focus_entered.connect(func(): _begin_text_transaction(field))
	field.text_changed.connect(func(value):
		if not _updating and document.working_copy != null:
			setter.call(value)
	)
	field.focus_exited.connect(func(): _finish_text_transaction(field, action))


func _bind_text_edit_transaction(field: TextEdit, action: String, setter: Callable) -> void:
	field.focus_entered.connect(func(): _begin_text_transaction(field))
	field.text_changed.connect(func():
		if not _updating and document.working_copy != null:
			setter.call(field.text)
	)
	field.focus_exited.connect(func(): _finish_text_transaction(field, action))


func _begin_text_transaction(field: Control) -> void:
	if document.working_copy != null:
		_text_snapshots[field.get_instance_id()] = ItemFingerprintService.semantic_snapshot(document.working_copy)


func _finish_text_transaction(field: Control, action: String) -> void:
	var instance_id := field.get_instance_id()
	if not _text_snapshots.has(instance_id):
		return
	var before := _text_snapshots[instance_id] as Dictionary
	_text_snapshots.erase(instance_id)
	document.record_snapshot(action, before)


func _select_option_metadata(option: OptionButton, value: StringName) -> void:
	for index in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			return


func _parse_string_names(value: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for part in value.split(","):
		var cleaned := part.strip_edges()
		if not cleaned.is_empty() and StringName(cleaned) not in result:
			result.append(StringName(cleaned))
	return result


func _to_string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
