@tool
class_name StudioContextBar
extends PanelContainer

var context: StudioProjectContext = null
var reference_graph: StudioReferenceGraphService = null
var run_option: OptionButton
var room_option: OptionButton
var room_label: Label
var hero_option: OptionButton
var scope_option: OptionButton
var state_label: Label
var human_summary_label: Label
var details_label: Label
var details_button: Button
var context_button: Button
var context_popup: PopupPanel
var transition_dialog: ConfirmationDialog
var _runs: Array[RunData] = []
var _syncing := false
var _compact := false
var _context_button_full_text := "Contexte"


func setup(project_context: StudioProjectContext, graph_service: StudioReferenceGraphService) -> void:
	context = project_context
	reference_graph = graph_service


## La barre reste identique dans tout le Studio, mais un domaine peut annoncer
## qu'un sélecteur ne le concerne pas. La sélection reste possible et partagée :
## seule sa mise en avant baisse, avec une explication. Utilisé par Skills, où
## la salle n'a aucun effet sur les compétences.
func mark_room_unused(explanation: String) -> void:
	var muted := Color(0.55, 0.59, 0.65)
	if room_label != null:
		room_label.add_theme_color_override("font_color", muted)
		room_label.tooltip_text = explanation
	if room_option != null:
		room_option.modulate = Color(1.0, 1.0, 1.0, 0.55)
		room_option.tooltip_text = explanation


func _ready() -> void:
	custom_minimum_size.y = 30
	context_button = Button.new()
	context_button.text = "Contexte ▾"
	context_button.tooltip_text = "Partie, salle, personnage, portée, usages et erreurs"
	context_button.pressed.connect(_toggle_context_popup)
	add_child(context_button)
	context_popup = PopupPanel.new()
	context_popup.name = "StudioContextPopup"
	context_popup.size = Vector2i(760, 170)
	add_child(context_popup)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(740, 150)
	rows.add_theme_constant_override("separation", 2)
	context_popup.add_child(rows)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	rows.add_child(bar)
	run_option = _labeled_option(bar, "Partie")
	run_option.item_selected.connect(_on_run_selected)
	room_option = _labeled_option(bar, "Salle")
	room_label = bar.get_child(bar.get_child_count() - 2) as Label
	room_option.item_selected.connect(_on_room_selected)
	hero_option = _labeled_option(bar, "Personnage")
	hero_option.item_selected.connect(_on_hero_selected)
	scope_option = _labeled_option(bar, "Portée")
	for scope in StudioProjectContext.VALID_SCOPES:
		scope_option.add_item(_scope_label(scope))
		scope_option.set_item_metadata(scope_option.item_count - 1, scope)
	scope_option.item_selected.connect(_on_scope_selected)
	state_label = Label.new()
	state_label.custom_minimum_size.x = 160
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(state_label)
	human_summary_label = Label.new()
	human_summary_label.clip_text = true
	human_summary_label.tooltip_text = "Contexte actif, état et destination de production"
	rows.add_child(human_summary_label)
	details_button = Button.new()
	details_button.text = "Détails techniques ▾"
	details_button.flat = true
	details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	details_button.pressed.connect(_toggle_technical_details)
	details_button.visible = false
	rows.add_child(details_button)
	details_label = Label.new()
	details_label.clip_text = true
	details_label.visible = false
	details_label.tooltip_text = "Chemins, usages et génération de l'index"
	rows.add_child(details_label)
	_build_transition_dialog()
	if context != null:
		context.context_changed.connect(_refresh.bind())
		context.transition_requested.connect(_show_transition)
	_refresh()


func set_compact(value: bool) -> void:
	_compact = value
	_refresh_context_button()


func _toggle_context_popup() -> void:
	if context_popup == null:
		return
	if context_popup.visible:
		context_popup.hide()
		return
	context_popup.position = Vector2i(
		int(global_position.x + size.x - context_popup.size.x),
		int(global_position.y + size.y + 4.0)
	)
	context_popup.popup()


func _refresh_context_button() -> void:
	if context_button == null:
		return
	context_button.text = "Contexte ▾" if _compact else "%s ▾" % _context_button_full_text


func _build_transition_dialog() -> void:
	transition_dialog = ConfirmationDialog.new()
	transition_dialog.title = "Modifications non sauvegardées"
	transition_dialog.ok_button_text = "Sauvegarder et continuer"
	transition_dialog.add_button("Garder comme brouillon", false, "draft")
	transition_dialog.add_button("Abandonner", true, "discard")
	transition_dialog.confirmed.connect(func(): _resolve(StudioProjectContext.ACTION_SAVE))
	transition_dialog.custom_action.connect(func(action):
		if action == "draft":
			_resolve(StudioProjectContext.ACTION_DRAFT)
		elif action == "discard":
			_resolve(StudioProjectContext.ACTION_DISCARD)
	)
	transition_dialog.canceled.connect(func():
		_resolve(StudioProjectContext.ACTION_CANCEL)
	)
	add_child(transition_dialog)


func _refresh(_unused = {}) -> void:
	if context == null or run_option == null:
		return
	_syncing = true
	_runs = RunContentCatalogService.discover_runs()
	run_option.clear()
	var selected_run := -1
	for index in range(_runs.size()):
		var run_data := _runs[index]
		run_option.add_item(run_data.run_name)
		run_option.set_item_tooltip(index, run_data.resource_path)
		if run_data == context.active_run:
			selected_run = index
	if selected_run >= 0:
		run_option.select(selected_run)
	room_option.clear()
	if context.active_run != null:
		for index in range(context.active_run.rooms.size()):
			var room := context.active_run.rooms[index]
			room_option.add_item("%02d  %s" % [index + 1, room.room_name if room != null else "Salle absente"])
			room_option.set_item_tooltip(index, room.resource_path if room != null else "Référence nulle")
		if context.active_room_index >= 0:
			room_option.select(context.active_room_index)
	hero_option.clear()
	var heroes := RunContentCatalogService.heroes_for_run(context.active_run)
	for index in range(heroes.size()):
		var hero := heroes[index]
		var hero_name := "Héros absent"
		if hero != null:
			hero_name = str(hero.character_id)
			if hero.base_unit_data != null and not hero.base_unit_data.unit_name.strip_edges().is_empty():
				hero_name = hero.base_unit_data.unit_name
		hero_option.add_item(hero_name)
		hero_option.set_item_tooltip(index, str(hero.character_id) if hero != null else "Référence nulle")
		if hero == context.active_hero:
			hero_option.select(index)
	if context.active_hero == null and context.active_character != null:
		var outside_index := hero_option.item_count
		hero_option.add_item("%s (hors partie)" % context.active_character.unit_name)
		hero_option.set_item_tooltip(
			outside_index, context.active_character.resource_path
		)
		hero_option.set_item_disabled(outside_index, true)
		hero_option.select(outside_index)
	for index in range(scope_option.item_count):
		if StringName(scope_option.get_item_metadata(index)) == context.edit_scope:
			scope_option.select(index)
			break
	var dirty := context.dirty_domains()
	state_label.text = "ÉTAT : %s" % ("MODIFIÉ · %s" % ", ".join(dirty.keys()) if not dirty.is_empty() else "SAUVEGARDÉ")
	state_label.add_theme_color_override(
		"font_color", Color(1.0, 0.66, 0.25) if not dirty.is_empty() else Color(0.48, 0.9, 0.62)
	)
	var snap := context.snapshot()
	var opened_resource: Resource = context.active_character
	var authority_label := "Fiche générale"
	var usage_label := "usage(s) de la fiche générale"
	var opened_scope_label := "Ressource partagée"
	if context.active_authority \
			== RunContentCatalogService.AUTHORITY_PROGRESSION_PROFILE \
			and context.active_hero != null:
		opened_resource = context.active_hero.progression_profile
		authority_label = "Profil de progression"
		usage_label = "usage(s) du profil"
		opened_scope_label = _scope_label(context.edit_scope)
	var usage_count := 0
	if reference_graph != null and opened_resource != null:
		usage_count = reference_graph.usages(opened_resource).size()
	var error_count := 0
	for metadata_value in dirty.values():
		if metadata_value is Dictionary:
			error_count += int((metadata_value as Dictionary).get("errors", 0))
	var target := str(context.persisted_ui.get("production_target", "Non définie"))
	var hero_display := "Aucun personnage"
	if context.active_character != null:
		hero_display = context.active_character.unit_name
		if context.active_hero == null:
			hero_display += " (hors partie)"
	var room_display := "Aucune salle"
	if context.active_run != null and context.active_room_index >= 0 \
		and context.active_room_index < context.active_run.rooms.size():
		var active_room: RoomData = context.active_run.rooms[context.active_room_index]
		room_display = "%02d · %s" % [
			context.active_room_index + 1,
			active_room.room_name if active_room != null else "Salle absente",
		]
	_context_button_full_text = "%s · %s · %s" % [
		str(snap.get("run_name", "Aucune partie")), room_display, hero_display,
	]
	_refresh_context_button()
	human_summary_label.text = "%s · %s · %s · %s · %d %s · %d erreur(s) · Cible : %s" % [
		str(snap.get("run_name", "Aucune partie")), hero_display,
		authority_label, opened_scope_label, usage_count, usage_label,
		error_count, target,
	]
	human_summary_label.tooltip_text = human_summary_label.text
	details_label.text = "Partie : %s  ·  Autorité : %s  ·  UnitData : %s  ·  Profil : %s  ·  %s : %d  ·  index g%d" % [
		snap.get("run_path", ""), authority_label, snap.get("character_path", ""),
		snap.get("progression_path", ""), usage_label, usage_count,
		reference_graph.generation if reference_graph != null else 0,
	]
	details_label.tooltip_text = details_label.text
	# Les informations techniques restent accessibles au survol sans réserver
	# une troisième ligne vide dans tous les onglets du Studio.
	human_summary_label.tooltip_text = "%s\n%s" % [human_summary_label.text, details_label.text]
	context_button.tooltip_text = "%s\n%s\n%s" % [
		_context_button_full_text, human_summary_label.text, details_label.text,
	]
	_syncing = false


func _toggle_technical_details() -> void:
	if details_label == null:
		return
	details_label.visible = not details_label.visible
	details_button.text = "Détails techniques ▴" if details_label.visible else "Détails techniques ▾"


func _show_transition(transition: Dictionary) -> void:
	var domains: Array[String] = []
	for domain_value in (transition.get("dirty_domains", {}) as Dictionary).keys():
		domains.append(context.human_domain_name(StringName(domain_value)))
	var intent := StringName(transition.get("intent", &""))
	var action_text := str({
		&"terrain_home": "Quitter le terrain courant",
		&"vfx_profile_change": "Ouvrir un autre profil d'effet visuel",
		&"vfx_reload_draft": "Recharger le brouillon de l'effet visuel",
	}.get(intent, "Changer de contexte"))
	transition_dialog.dialog_text = "%s remplacerait une version en cours modifiée.\n\nDomaines : %s\n\nChoisissez explicitement quoi faire." % [
		action_text, ", ".join(domains),
	]
	transition_dialog.popup_centered()


func _resolve(action: StringName) -> void:
	if context == null:
		return
	var result := context.resolve_pending_transition(action)
	if not result.get("ok", false):
		transition_dialog.dialog_text = "Transition impossible :\n%s" % result.get("error", "Erreur inconnue")
		transition_dialog.popup_centered()
	else:
		transition_dialog.hide()
		_refresh()


func _on_run_selected(index: int) -> void:
	if not _syncing and context != null and index >= 0 and index < _runs.size():
		context.request_run(_runs[index], &"context_bar")


func _on_room_selected(index: int) -> void:
	if not _syncing and context != null:
		context.request_room(index, &"context_bar")


func _on_hero_selected(index: int) -> void:
	if _syncing or context == null:
		return
	var heroes := RunContentCatalogService.heroes_for_run(context.active_run)
	if index >= 0 and index < heroes.size() and heroes[index] != null:
		context.request_hero(heroes[index].character_id, &"context_bar")


func _on_scope_selected(index: int) -> void:
	if not _syncing and context != null:
		context.request_scope(StringName(scope_option.get_item_metadata(index)), &"context_bar")


func _labeled_option(parent: Container, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text + " :"
	parent.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 145
	option.fit_to_longest_item = false
	option.clip_text = true
	parent.add_child(option)
	return option


func _scope_label(scope: StringName) -> String:
	match scope:
		StudioProjectContext.SCOPE_RUN_SPECIFIC:
			return "Spécifique à la partie"
		StudioProjectContext.SCOPE_SHARED:
			return "Ressource partagée"
		_:
			return "Brouillon isolé"
