@tool
class_name StudioContextBar
extends PanelContainer

var context: StudioProjectContext = null
var reference_graph: StudioReferenceGraphService = null
var run_option: OptionButton
var room_option: OptionButton
var hero_option: OptionButton
var scope_option: OptionButton
var state_label: Label
var details_label: Label
var transition_dialog: ConfirmationDialog
var _runs: Array[RunData] = []
var _syncing := false


func setup(project_context: StudioProjectContext, graph_service: StudioReferenceGraphService) -> void:
	context = project_context
	reference_graph = graph_service


func _ready() -> void:
	custom_minimum_size.y = 62
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	add_child(rows)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	rows.add_child(bar)
	run_option = _labeled_option(bar, "Run")
	run_option.item_selected.connect(_on_run_selected)
	room_option = _labeled_option(bar, "Salle")
	room_option.item_selected.connect(_on_room_selected)
	hero_option = _labeled_option(bar, "Heros")
	hero_option.item_selected.connect(_on_hero_selected)
	scope_option = _labeled_option(bar, "Portee")
	for scope in StudioProjectContext.VALID_SCOPES:
		scope_option.add_item(_scope_label(scope))
		scope_option.set_item_metadata(scope_option.item_count - 1, scope)
	scope_option.item_selected.connect(_on_scope_selected)
	state_label = Label.new()
	state_label.custom_minimum_size.x = 160
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(state_label)
	details_label = Label.new()
	details_label.clip_text = true
	details_label.tooltip_text = "Chemins, usages et generation de l'index"
	rows.add_child(details_label)
	_build_transition_dialog()
	if context != null:
		context.context_changed.connect(_refresh.bind())
		context.transition_requested.connect(_show_transition)
	_refresh()


func _build_transition_dialog() -> void:
	transition_dialog = ConfirmationDialog.new()
	transition_dialog.title = "Modifications non sauvegardees"
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
			room_option.set_item_tooltip(index, room.resource_path if room != null else "Reference nulle")
		if context.active_room_index >= 0:
			room_option.select(context.active_room_index)
	hero_option.clear()
	var heroes := RunContentCatalogService.heroes_for_run(context.active_run)
	for index in range(heroes.size()):
		var hero := heroes[index]
		hero_option.add_item(str(hero.character_id) if hero != null else "Heros absent")
		if hero == context.active_hero:
			hero_option.select(index)
	for index in range(scope_option.item_count):
		if StringName(scope_option.get_item_metadata(index)) == context.edit_scope:
			scope_option.select(index)
			break
	var dirty := context.dirty_domains()
	state_label.text = "ETAT : %s" % ("MODIFIE · %s" % ", ".join(dirty.keys()) if not dirty.is_empty() else "SAUVEGARDE")
	state_label.add_theme_color_override(
		"font_color", Color(1.0, 0.66, 0.25) if not dirty.is_empty() else Color(0.48, 0.9, 0.62)
	)
	var snap := context.snapshot()
	var usage_count := 0
	if reference_graph != null and context.active_room() != null:
		usage_count = reference_graph.usages(context.active_room()).size()
	details_label.text = "Run: %s  ·  Salle: %s  ·  Profil: %s  ·  usages: %d  ·  index g%d" % [
		snap.get("run_path", ""), snap.get("room_path", ""),
		snap.get("progression_path", ""), usage_count,
		reference_graph.generation if reference_graph != null else 0,
	]
	details_label.tooltip_text = details_label.text
	_syncing = false


func _show_transition(transition: Dictionary) -> void:
	var domains := (transition.get("dirty_domains", {}) as Dictionary).keys()
	transition_dialog.dialog_text = "Le changement de contexte remplacerait une copie de travail modifiee.\n\nDomaines : %s\n\nChoisissez explicitement quoi faire." % ", ".join(domains)
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
			return "Specifique a la run"
		StudioProjectContext.SCOPE_SHARED:
			return "Ressource partagee"
		_:
			return "Brouillon isole"
