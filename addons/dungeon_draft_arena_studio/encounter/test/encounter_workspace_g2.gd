extends "res://addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_baseline.gd"

## Géométrie du vrai workspace ; aucune publication, aucune écriture sous data/.
const G2_OUTPUT := "res://artifacts/encounter_g2"


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--width="):
			resolution.x = int(argument.get_slice("=", 1))
		elif argument.begins_with("--height="):
			resolution.y = int(argument.get_slice("=", 1))
	root.borderless = true
	root.gui_embed_subwindows = true
	root.position = Vector2i.ZERO
	root.size = resolution
	root.content_scale_size = resolution
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	await _frames(2)
	root.warp_mouse(Vector2(resolution.x - 2, resolution.y - 2))
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
	_check(scans == 0, "Aucun scan à l'ouverture")
	_check(bool(graph.scan().ok), "Scan partagé initial")
	workspace.tabs.current_tab = 1
	await _capture("canonical", true)
	var ui := workspace.encounter_studio
	_check(not ui.validation_panel.visible, "Validation fermée par défaut")
	_check(ui.open_run(SHARED), "Rencontre partagée")
	await _capture("shared", true)
	var document := _document_state()
	var initial_layout := ui.get_layout_snapshot()
	var map_size := ui.map_preview.size
	ui.navigation_toggle.button_pressed = false
	ui.navigation_toggle.pressed.emit()
	await _capture("navigation_closed", true)
	_check(ui.map_preview.size.x > map_size.x + 150, "Repli gauche : espace rendu au terrain")
	ui.validation_toggle.button_pressed = true
	ui.validation_toggle.pressed.emit()
	await _capture("validation_open", true)
	_check(ui.validation_panel.size.y >= 50, "Zone de validation utilisable")
	_check(ui.map_preview.size.y >= 160, "Terrain prioritaire avec validation ouverte")
	ui.navigation_toggle.button_pressed = true
	ui.navigation_toggle.pressed.emit()
	await _capture("all_panels", true)
	await _drag_split(ui.navigation_split, Vector2(35, 0))
	_check(ui.navigation_panel.size.x > 240, "Séparateur gauche déplacé à la souris")
	await _drag_split(ui.properties_split, Vector2(-35, 0))
	_check(ui.properties_panel.size.x > 380, "Séparateur droit déplacé à la souris")
	var dragged_layout := ui.get_layout_snapshot()
	ui.apply_layout_snapshot(initial_layout)
	ui.apply_layout_snapshot(dragged_layout)
	await _frames(8)
	_check(absf(ui.navigation_panel.size.x - float(dragged_layout.navigation_width)) <= 1,
		"Largeur gauche exacte après restauration")
	_check(absf(ui.properties_panel.size.x - float(dragged_layout.properties_width)) <= 1,
		"Largeur droite exacte après restauration")
	ui.apply_layout_snapshot(initial_layout.merged({"validation_open": true}, true))
	await _frames(8)
	ui.timeline_scroll.ensure_control_visible(ui.timeline.get_child(ui.timeline.get_child_count() - 1))
	await _frames(3)
	_check(ui.timeline_scroll.scroll_horizontal > 0, "Dernier affrontement accessible horizontalement")
	_check(ui.timeline_scroll.get_global_rect().encloses(ui.timeline.get_child(ui.timeline.get_child_count() - 1).get_global_rect()),
		"Dernière carte entière après défilement")
	ui.timeline_scroll.scroll_horizontal = 0
	for index in ui.properties_tabs.get_tab_count():
		(ui.properties_navigation.get_child(index) as Button).pressed.emit()
		await _capture("properties_%d" % index, true)
		await _check_numeric_fields()
	ui.properties_tabs.current_tab = 3
	await ui.analyze_seeds(10)
	await _capture("analysis_results", true)
	for button in ui.analysis_presets.get_children():
		if button is Button:
			_check(_frame().encloses(button.get_global_rect()), "Analyse accessible : " + button.text)
	ui.properties_tabs.current_tab = 0
	_check(_document_state() == document, "Disposition, onglets, défilement et analyse sans mutation")
	# Persistance via le service réel, uniquement dans APPDATA isolé du runner.
	ui.apply_layout_snapshot({"navigation_open": true, "validation_open": true,
		"navigation_width": 250.0, "properties_width": 400.0, "validation_height": 160.0})
	await _frames(8)
	var saved := ui.get_layout_snapshot()
	_check(StudioUiStateService.save_state({"workspace": workspace.get_state_snapshot()}), "État UI écrit")
	ui.apply_layout_snapshot(initial_layout)
	workspace.apply_state_snapshot(StudioUiStateService.load_state().workspace)
	await _frames(8)
	_check(ui.get_layout_snapshot() == saved, "Disposition relue depuis le disque")
	_check(_document_state() == document, "Préférences sans mutation documentaire")
	await _capture("restored_layout", true)
	# Une grande préférence doit survivre à un aller-retour de taille.
	var original_resolution := resolution
	resolution = Vector2i(1920, 1080)
	await _resize()
	var large_map := ui.map_preview.size
	resolution = Vector2i(1280, 720)
	await _resize()
	_check(ui.map_preview.size.x < large_map.x, "Largeur supplémentaire donnée au terrain")
	_check(ui.map_preview.size.y < large_map.y, "Hauteur supplémentaire donnée au terrain")
	_check(ui.get_layout_snapshot() == saved, "Redimensionnement sans écrasement des préférences")
	resolution = original_resolution
	await _resize()
	ui.apply_layout_snapshot(initial_layout)
	# Navigation de domaine, brouillon, hôtes réels et premier affrontement.
	workspace.tabs.current_tab = 0
	_check(workspace.arena_studio._open_context_room(context.active_room()), "Terrain canonique ouvert")
	workspace.arena_studio.show_editor()
	workspace.create_encounters_button.pressed.emit()
	await _capture("room_draft", true)
	ui.validation_toggle.button_pressed = true
	ui.validation_toggle.pressed.emit()
	await _capture("room_draft_validation", true)
	ui.validation_toggle.button_pressed = false
	ui.validation_toggle.pressed.emit()
	_check(ui.session.draft_room == workspace.arena_studio.room_draft(), "Même autorité brouillon Terrain")
	document = _document_state()
	var session := ui.session
	for tab in [0, 1, 2, 1]:
		workspace.tabs.current_tab = tab
		await _frames(2)
	_check(_document_state() == document, "Navigation sans mutation ni historique")
	var identity := workspace.workspace_instance_id
	var before_detach := ui.get_layout_snapshot()
	native_host.attach_workspace(workspace)
	embedded.show_detached_placeholder()
	native_host.size = resolution
	native_host.show()
	await _frames(8)
	_check(workspace.get_parent() == native_host, "Hôte natif réel")
	_check(workspace.workspace_instance_id == identity and ui.session == session, "Identités au détachement")
	_check(ui.get_layout_snapshot() == before_detach, "Disposition au détachement")
	native_host.hide()
	embedded.attach_workspace(native_host.detach_workspace())
	await _capture("reattached", true)
	_check(ui.get_layout_snapshot() == before_detach, "Disposition à la réintégration")
	_check(_document_state() == document, "Hôtes sans mutation")
	# Le snapshot brouillon restaure la disposition, jamais un document Terrain.
	var draft_state := ui.get_state_snapshot()
	ui.apply_layout_snapshot(saved)
	ui.apply_state_snapshot(draft_state)
	await _frames(8)
	_check(ui.get_layout_snapshot() == before_detach, "Disposition du brouillon restaurée")
	_check(_document_state() == document, "Restauration UI du brouillon sans changement de source")
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
	for node in _descendants(ui.composition_box):
		if node is Button and node.text == "Créer le premier affrontement":
			_check(_frame().encloses(node.get_global_rect()), "Premier affrontement : bouton entier")
	ui._add_wave()
	await _frames()
	_check(ui.session.current_encounter() != null, "Création toujours fonctionnelle")
	_check(scans == 1 and graph.generation == 1, "Un scan, génération 1")
	_check(invalidations == 0, "Aucune invalidation sans publication")
	_check_modal_windows()
	var file := FileAccess.open(G2_OUTPUT.path_join("smoke_%dx%d.json" % [resolution.x, resolution.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "captures": captures,
		"scans": scans, "invalidations": invalidations}, "  "))
	file.close()
	embedded.remove_child(workspace)
	workspace.free()
	native_host.free()
	embedded.free()
	await _frames()
	get_tree().quit(1 if checks.any(func(check): return not check.ok) else 0)


func _resize() -> void:
	root.size = resolution
	root.content_scale_size = resolution
	await _frames(12)
	root.warp_mouse(Vector2(resolution.x - 2, resolution.y - 2))


func _drag_split(split: SplitContainer, delta: Vector2) -> void:
	var dragger := split.get_drag_area_controls()[0]
	var origin: Vector2 = dragger.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = origin
	root.push_input(press)
	await _frames(2)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = origin + delta
	move.relative = delta
	root.push_input(move)
	await _frames(2)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = origin + delta
	root.push_input(release)
	root.warp_mouse(Vector2(resolution.x - 2, resolution.y - 2))
	await _frames(8)


func _document_state() -> Dictionary:
	var ui := workspace.encounter_studio
	return {"fingerprint": ui.session.document_fingerprint(), "dirty": ui.session.is_dirty(),
		"history": ui.history_entries(), "index": ui.history_current_index(),
		"room": ui.session.selected_room_index, "wave": ui.session.selected_wave_index,
		"cell": ui.map_preview.selected_cell}


func _frame() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(resolution))


func _scroll_ancestor(node: Node) -> ScrollContainer:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return parent
		parent = parent.get_parent()
	return null


func _check_numeric_fields() -> void:
	for node in _descendants(workspace.encounter_studio.properties_tabs):
		if node is SpinBox and node.is_visible_in_tree():
			var scroll := _scroll_ancestor(node)
			if scroll != null:
				scroll.ensure_control_visible(node)
				await _frames(2)
				_check(scroll.get_global_rect().encloses(node.get_global_rect()), "Champ numérique accessible au défilement")
			_check(_frame().encloses(node.get_global_rect()), "Champ numérique entier dans la fenêtre")


func _capture(label: String, expect_units: bool) -> void:
	await _frames(10)
	_check_modal_windows()
	var ui := workspace.encounter_studio
	_check(not workspace.guided_toggle.is_visible_in_tree(), label + " : G1 sans interrupteur")
	_check(ui.map_preview.grid != null, label + " : terrain rendu")
	if expect_units:
		_check(not ui.preview_result.get("placements", []).is_empty(), label + " : unités rendues")
	var outside: Array = []
	for node in _descendants(workspace):
		if not node is Control or not node.is_visible_in_tree():
			continue
		if not (node is Button or node is SpinBox or node is Label or node is ScrollContainer):
			continue
		var scroll := _scroll_ancestor(node)
		var rect: Rect2 = node.get_global_rect()
		if scroll != null:
			# Un contenu défilable peut sortir de son viewport, pas élargir celui-ci.
			if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				continue
			if rect.position.x >= 0 and rect.end.x <= resolution.x + 1:
				continue
		elif _frame().grow(1).encloses(rect):
			continue
		outside.append({"node": str(node.get_path()), "rect": str(rect)})
	_check(outside.is_empty(), label + " : aucun contrôle hors fenêtre : " + str(outside))
	for panel in [ui.map_preview, ui.timeline_scroll, ui.properties_panel]:
		_check(_frame().encloses(panel.get_global_rect()), label + " : zone bornée " + panel.get_class())
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == resolution, label + " : dimensions exactes")
	var path := G2_OUTPUT.path_join("%s_%dx%d.png" % [label, resolution.x, resolution.y])
	_check(image.save_png(path) == OK, label + " : capture")
	captures.append({"view": label, "path": path, "outside": outside,
		"terrain": str(ui.map_preview.get_global_rect()), "properties": str(ui.properties_panel.get_global_rect()),
		"layout": ui.get_layout_snapshot()})
