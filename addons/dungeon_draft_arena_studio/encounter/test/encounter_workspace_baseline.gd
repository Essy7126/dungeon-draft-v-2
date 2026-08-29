extends Node

## Smoke du vrai workspace, sans sauvegarde de données de production.
## Exécuter avec Compatibility puis -- --width=1920 --height=1080.
const OUTPUT := "res://artifacts/encounter_shared_graph"
const CANONICAL := "res://data/runs/first_run.tres"
const SHARED := "res://data/runs/fixed_trio_prototype_run.tres"
var workspace: StudioWorkspace
var embedded: EmbeddedStudioHost
var native_host: NativeStudioWindowHost
var graph := StudioReferenceGraphService.new()
var checks: Array = []
var captures: Array = []
var scans := 0
var invalidations := 0
var resolution := Vector2i(1280, 720)
var root: Window


func _ready() -> void:
	root = get_tree().root
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)


func _frames(count := 4) -> void:
	for index in count:
		await get_tree().process_frame


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--width="):
			resolution.x = int(argument.get_slice("=", 1))
		elif argument.begins_with("--height="):
			resolution.y = int(argument.get_slice("=", 1))
	# Godot borne la taille initiale à la zone de travail Windows (1055 px sur
	# l'écran 1080 px). La taille demandée est appliquée après initialisation.
	root.borderless = true
	root.position = Vector2i.ZERO
	root.size = resolution
	root.content_scale_size = resolution
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	await _frames(2)
	_check(root.size == resolution, "Taille exacte de la fenêtre de rendu")
	graph.scan_started.connect(func(): scans += 1)
	graph.invalidated.connect(func(_keys): invalidations += 1)
	var context := StudioProjectContext.new()
	_check(bool(context.request_run(load(CANONICAL)).ok), "Contexte canonique")
	embedded = EmbeddedStudioHost.new()
	root.add_child(embedded)
	native_host = NativeStudioWindowHost.new()
	root.add_child(native_host)
	workspace = StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, graph)
	embedded.attach_workspace(workspace)
	await _frames()
	_check(workspace.encounter_studio.shared_reference_graph == graph, "Instance de graphe partagée")
	_check(workspace.encounter_studio.project_context == context, "Instance de contexte partagée")
	_check(scans == 0, "Aucun scan à l'ouverture du workspace")
	_check(bool(graph.scan().ok), "Scan initial du Studio")
	await _frames()
	workspace.tabs.current_tab = 1
	await _capture("canonical", true)
	_check(workspace.encounter_studio.open_run(SHARED), "Ouverture partie à rencontres partagées")
	await _frames()
	await _capture("shared", true)
	var ui := workspace.encounter_studio
	_check(int(ui._usage_summary(ui.session.current_encounter()).published.usage_count) > 1,
		"Partage canonique détecté")
	# Import de la salle canonique dans Terrain puis ouverture de sa working copy.
	workspace.tabs.current_tab = 0
	_check(workspace.arena_studio._open_context_room(context.active_room()), "Ouverture du terrain canonique")
	workspace.arena_studio.show_editor()
	workspace.create_encounters_button.pressed.emit()
	await _frames()
	_check(workspace.tabs.current_tab == 1, "Terrain vers Rencontre")
	_check(ui.session.draft_room == workspace.arena_studio.room_draft(), "Autorité Terrain du brouillon")
	_check(ui.session.room_draft_mode, "Mode brouillon")
	await _capture("room_draft", true)
	var identity := workspace.workspace_instance_id
	var session := ui.session
	var summary := ui._usage_summary(session.current_encounter())
	for tab in [0, 1, 2, 1]:
		workspace.tabs.current_tab = tab
		await _frames(2)
	_check(ui.session == session, "Même session après Terrain → Rencontre → Objets → Rencontre")
	_check(ui._usage_summary(session.current_encounter()) == summary, "Usages stables après navigation")
	native_host.attach_workspace(workspace)
	embedded.show_detached_placeholder()
	native_host.size = resolution
	native_host.show()
	await _frames()
	_check(workspace.get_parent() == native_host, "Détachement dans le véritable hôte natif")
	_check(workspace.workspace_instance_id == identity and ui.session == session, "Identités après détachement")
	_check(ui._usage_summary(session.current_encounter()) == summary, "Usages après détachement")
	_check_modal_windows()
	native_host.hide()
	embedded.attach_workspace(native_host.detach_workspace())
	await _frames()
	_check(workspace.get_parent() == embedded, "Réintégration")
	_check(workspace.workspace_instance_id == identity and ui.session == session, "Identités après réintégration")
	_check(ui._usage_summary(session.current_encounter()) == summary, "Usages après réintégration")
	for domain in [&"arena", &"arena_run", &"encounter", &"items"]:
		_check(bool(context.transition_handler_contract(domain).valid), "Handlers complets : " + str(domain))
	# Variante en mémoire : seul le brouillon Terrain perd ses affrontements.
	# Aucune édition de la source et aucune publication.
	var draft := workspace.arena_studio.room_draft()
	draft.waves.clear()
	draft.encounter_definition = null
	draft.enemies.clear()
	draft.minimum_wave_count = 1
	draft.maximum_wave_count = 1
	ui.session.select(0, 0)
	ui._refresh_all()
	ui.history_state_changed.emit()
	await _capture("no_first_encounter", false)
	_check(ui.map_preview.grid != null, "Terrain visible avant le premier affrontement")
	ui._add_wave()
	await _frames()
	_check(ui.session.current_encounter() != null, "Création du premier affrontement")
	_check(scans == 1 and graph.generation == 1, "Un seul scan pour tout le smoke")
	_check(invalidations == 0, "Zéro invalidation sans publication")
	_check_modal_windows()
	var report := {"resolution": [resolution.x, resolution.y], "checks": checks,
		"captures": captures, "scans": scans, "generation": graph.generation,
		"invalidations": invalidations, "graph": graph.report()}
	var file := FileAccess.open(OUTPUT.path_join("smoke_%dx%d.json" % [resolution.x, resolution.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	embedded.remove_child(workspace)
	workspace.free()
	native_host.free()
	embedded.free()
	await _frames()
	get_tree().quit(1 if checks.any(func(check): return not check.ok) else 0)


func _check_modal_windows() -> void:
	for node in _descendants(workspace):
		if node is Window:
			_check(not node.visible, "Aucune modale résiduelle : " + str(node.name))
	_check(not workspace.project_context.has_pending_transition(), "Aucune décision invisible en attente")


func _capture(label: String, expect_units: bool) -> void:
	await _frames(6)
	_check_modal_windows()
	var ui := workspace.encounter_studio
	_check(ui.map_preview.grid != null, label + " : terrain rendu")
	var placements: Array = ui.preview_result.get("placements", [])
	if expect_units:
		_check(not placements.is_empty(), label + " : unités placées")
	var frame := Rect2(Vector2.ZERO, Vector2(resolution))
	var outside: Array = []
	for node in _descendants(workspace):
		if node is Button and node.is_visible_in_tree() and not frame.encloses(node.get_global_rect()):
			outside.append({"text": node.text, "rect": str(node.get_global_rect())})
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == resolution, label + " : dimensions de capture")
	var path := OUTPUT.path_join("%s_%dx%d.png" % [label, resolution.x, resolution.y])
	_check(image.save_png(path) == OK, label + " : capture enregistrée")
	captures.append({"view": label, "path": path, "units": placements.size(),
		"usage": ui._usage_summary(ui.session.current_encounter()), "outside_buttons": outside,
		"validation": EncounterValidationService.summary(ui.session.validation_messages)})


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
