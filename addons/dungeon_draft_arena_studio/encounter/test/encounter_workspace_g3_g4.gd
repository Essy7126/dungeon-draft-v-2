extends Node

## Smoke graphique G3 (composition novice) + G4 (langage visuel de la carte).
## Runner indépendant : ne remplace ni encounter_workspace_baseline, ni G1, ni
## G2. Exécuter avec Compatibility puis -- --width=1280 --height=720 (ou
## 1920x1080).
const OUTPUT := "res://artifacts/encounter_g3_g4"
const CANONICAL := "res://data/runs/first_run.tres"
const SHARED := "res://data/runs/fixed_trio_prototype_run.tres"
var workspace: StudioWorkspace
var embedded: EmbeddedStudioHost
var graph := StudioReferenceGraphService.new()
var checks: Array = []
var captures: Array = []
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
	root.borderless = true
	root.position = Vector2i.ZERO
	root.size = resolution
	root.content_scale_size = resolution
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	await _frames(2)
	_check(root.size == resolution, "Taille exacte de la fenêtre de rendu")
	var context := StudioProjectContext.new()
	_check(bool(context.request_run(load(CANONICAL)).ok), "Contexte canonique")
	embedded = EmbeddedStudioHost.new()
	root.add_child(embedded)
	workspace = StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, graph)
	embedded.attach_workspace(workspace)
	await _frames()
	_check(bool(graph.scan().ok), "Scan initial du Studio")
	await _frames()
	var ui := workspace.encounter_studio

	# 1) Rencontre partagée réelle (repère visuel avant toute modification).
	workspace.tabs.current_tab = 1
	_check(ui.open_run(SHARED), "Ouverture partie à rencontres partagées")
	await _frames()
	await _capture("shared_encounter")

	# 2) Brouillon de salle depuis Terrain, vidé pour obtenir l'état sans
	# affrontement — le terrain doit rester visible.
	workspace.tabs.current_tab = 0
	_check(workspace.arena_studio._open_context_room(context.active_room()), "Ouverture du terrain canonique")
	workspace.arena_studio.show_editor()
	workspace.create_encounters_button.pressed.emit()
	await _frames()
	_check(workspace.tabs.current_tab == 1, "Terrain vers Rencontre")
	var draft := workspace.arena_studio.room_draft()
	draft.waves.clear()
	draft.encounter_definition = null
	draft.enemies.clear()
	draft.minimum_wave_count = 0
	draft.maximum_wave_count = 1
	ui.session.select(0, 0)
	ui._refresh_all()
	await _capture("no_first_encounter")
	_check(ui.map_preview.grid != null, "Terrain visible avant le premier affrontement")

	# 3) Premier affrontement créé, catalogue visible, aucun ennemi encore.
	ui._add_wave()
	await _frames(2)
	await _capture("empty_encounter_catalog")

	# 4) Catalogue avec plusieurs ennemis, dont une unité sans illustration
	# ajoutée temporairement en mémoire (aucune Resource source modifiée).
	var fallback_unit := UnitData.new()
	fallback_unit.unit_name = "Ennemi de secours sans illustration au nom volontairement démesuré pour vérifier le retour à la ligne"
	fallback_unit.unit_id = &"g3g4_runner_fallback"
	fallback_unit.faction_id = &"skeleton_legion"
	fallback_unit.tactical_role_id = &"skeleton_normal"
	fallback_unit.max_hp = 30
	fallback_unit.max_ap = 5
	fallback_unit.max_mp = 3
	var extended_catalog: Array[UnitData] = ui.enemy_catalog.duplicate()
	extended_catalog.append(fallback_unit)
	ui.enemy_catalog = extended_catalog
	ui._refresh_composition()
	await _frames(2)
	_scroll_composition_to(ui, ui.catalog_cards_box)
	await _capture("catalog_with_fallback_unit")

	# 5) Composition avec plusieurs ennemis ajoutés.
	if not ui.enemy_catalog.is_empty():
		ui._add_unit(ui.enemy_catalog[0])
	ui._add_unit(fallback_unit)
	if ui.enemy_catalog.size() > 1:
		ui._add_unit(ui.enemy_catalog[1])
	await _frames(2)
	await _capture("composition_multiple_enemies")

	# 6) Recherche sans résultat.
	ui._filter_catalog("aucune-correspondance-possible-zzz")
	await _frames(2)
	_scroll_composition_to(ui, ui.catalog_empty_label)
	await _capture("catalog_search_no_results")
	ui._filter_catalog("")
	await _frames(2)

	# 7) Génère un placement réel pour la carte.
	ui.generate_preview()
	await _frames(2)
	await _capture("map_view_mode")

	# 8) Outil des cases interdites activé.
	ui.forbidden_tool_toggle.button_pressed = true
	ui.map_preview.set_edit_mode(true)
	await _frames(2)
	await _capture("map_forbidden_tool_active")

	# 9) Case survolée puis sélectionnée.
	var room := ui.session.runtime_room()
	ui.map_preview.grid = EncounterGridFactory.build_from_room(room)
	ui.map_preview._configure_projection()
	var hover_cell := Vector2i(mini(2, maxi(0, room.grid_size.x - 1)), mini(2, maxi(0, room.grid_size.y - 1)))
	ui.map_preview.hover_cell = hover_cell
	ui.map_preview.queue_redraw()
	await _frames(2)
	await _capture("map_cell_hovered")
	ui.map_preview.set_edit_mode(false)
	ui.forbidden_tool_toggle.button_pressed = false
	ui.map_preview.selected_cell = hover_cell
	ui._on_cell_selected(hover_cell)
	ui.map_preview.queue_redraw()
	await _frames(2)
	await _capture("map_cell_selected")

	var report := {"resolution": [resolution.x, resolution.y], "checks": checks, "captures": captures}
	var file := FileAccess.open(OUTPUT.path_join("smoke_%dx%d.json" % [resolution.x, resolution.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	embedded.remove_child(workspace)
	workspace.free()
	embedded.free()
	await _frames()
	get_tree().quit(1 if checks.any(func(check): return not check.ok) else 0)


func _check_modal_windows() -> void:
	for node in _descendants(workspace):
		if node is Window:
			_check(not node.visible, "Aucune modale résiduelle : " + str(node.name))


func _capture(label: String) -> void:
	# Une infobulle réelle déclenchée par la position du curseur ne doit pas
	# être comptée comme une fenêtre résiduelle : le curseur est écarté avant
	# le contrôle, sans masquer une vraie modale.
	root.warp_mouse(Vector2(resolution.x - 2, resolution.y - 2))
	await _frames(6)
	_check_modal_windows()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == resolution, label + " : dimensions de capture")
	var path := OUTPUT.path_join("%s_%dx%d.png" % [label, resolution.x, resolution.y])
	_check(image.save_png(path) == OK, label + " : capture enregistrée")
	captures.append({"view": label, "path": path})


func _scroll_composition_to(ui: EncounterStudioMain, target: Control) -> void:
	var scroll := ui.composition_box.get_parent() as ScrollContainer
	if scroll != null and target != null:
		scroll.ensure_control_visible(target)


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
