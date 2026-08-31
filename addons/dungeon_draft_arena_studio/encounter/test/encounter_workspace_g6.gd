extends Node

## Smoke graphique G6 : finition visuelle et accessibilité, vérifiées sur le
## Studio intégré (G1 à G5 ensemble). Runner indépendant : ne remplace aucun
## runner précédent (baseline, G1, G2, G3-G4, G5). Exécuter avec
## --rendering-method gl_compatibility puis -- --width=1280 --height=720 (ou
## 1920x1080).
##
## Deux phases avec deux workspaces distincts : la première (brouillon,
## composition, carte, validation) accumule volontairement des changements
## sur un même brouillon ; la seconde (rencontre partagée, panneaux) part
## d'un contexte neuf pour éviter toute transition documentaire parasite —
## exactement le même choix que les runners G1/G2/G3-G4 déjà validés.
const OUTPUT := "res://artifacts/encounter_g6"
const CANONICAL := "res://data/runs/first_run.tres"
const SHARED := "res://data/runs/fixed_trio_prototype_run.tres"
var workspace: StudioWorkspace
var embedded: EmbeddedStudioHost
var graph := StudioReferenceGraphService.new()
var checks: Array = []
var captures: Array = []
var resolution := Vector2i(1280, 720)
var ui_scale := 1.0
var output_root := OUTPUT
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
		elif argument.begins_with("--scale="):
			ui_scale = maxf(1.0, float(argument.get_slice("=", 1)))
	root.borderless = true
	root.gui_embed_subwindows = true
	root.position = Vector2i.ZERO
	root.size = resolution
	root.content_scale_size = Vector2i(
		roundi(resolution.x / ui_scale), roundi(resolution.y / ui_scale)
	)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	await _frames(2)
	_check(root.size == resolution, "Taille exacte de la fenêtre de rendu")
	_check(is_equal_approx(
		float(resolution.x) / float(root.content_scale_size.x), ui_scale
	), "Échelle de contenu réellement appliquée : %.2f" % ui_scale)

	await _phase_draft_and_validation()
	await _phase_shared_and_panels()

	# Filet de sécurité : une erreur GDScript non interceptée par _check()
	# (accès à une propriété inexistante, par exemple) peut interrompre une
	# coroutine sans faire échouer un seul _check() — vérifier explicitement
	# que les 18 états attendus ont bien produit une capture chacun.
	var expected_views := PackedStringArray([
		"01_salle_sans_affrontement", "02_brouillon", "03_composition_vide",
		"04_catalogue", "05_composition_remplie", "06_placement",
		"07_carte_en_consultation", "08_outil_cases_interdites",
		"09_action_destructrice_visible", "10_validation_repliee",
		"11_validation_ouverte", "12_diagnostic_actionnable",
		"13_details_techniques", "14_etat_sans_probleme_bloquant",
		"15_textes_longs", "16_rencontre_partagee", "17_panneaux_ouverts",
		"18_panneaux_replies", "19_focus_clavier_visible",
	])
	var captured_views := PackedStringArray()
	for entry in captures:
		captured_views.append(str(entry.view))
	for expected in expected_views:
		_check(captured_views.has(expected), "État attendu réellement capturé : " + expected)

	var report := {
		"resolution": [resolution.x, resolution.y],
		"content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		"ui_scale": ui_scale,
		"checks": checks,
		"captures": captures,
	}
	var suffix := "_%dpct" % roundi(ui_scale * 100.0) if ui_scale > 1.0 else ""
	var file := FileAccess.open(output_root.path_join(
		"g6_closure_%dx%d%s.json" % [resolution.x, resolution.y, suffix]
	), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	get_tree().quit(1 if checks.any(func(check): return not check.ok) else 0)


func _open_workspace(run_path: String) -> Dictionary:
	var context := StudioProjectContext.new()
	_check(bool(context.request_run(load(run_path)).ok), "Contexte %s" % run_path.get_file())
	var host := EmbeddedStudioHost.new()
	root.add_child(host)
	var ws := StudioWorkspace.new()
	ws.arena_auto_load_enabled = false
	ws.arena_production_planning_enabled = false
	ws.setup(null, null, context, graph)
	host.attach_workspace(ws)
	await _frames()
	return {"context": context, "host": host, "workspace": ws}


func _close_workspace(bundle: Dictionary) -> void:
	var host: EmbeddedStudioHost = bundle.host
	var ws: StudioWorkspace = bundle.workspace
	host.remove_child(ws)
	ws.free()
	host.free()
	await _frames()


## --- Phase 1 : brouillon, composition, carte, validation --------------------

func _phase_draft_and_validation() -> void:
	var bundle := await _open_workspace(CANONICAL)
	workspace = bundle.workspace
	var context: StudioProjectContext = bundle.context
	_check(bool(graph.scan().ok), "Scan initial du Studio")
	await _frames()
	var ui := workspace.encounter_studio

	workspace.tabs.current_tab = 0
	_check(workspace.arena_studio._open_context_room(context.active_room()), "Ouverture du terrain canonique")
	workspace.arena_studio.show_editor()
	workspace.create_encounters_button.pressed.emit()
	await _frames()
	_check(workspace.tabs.current_tab == 1, "Terrain vers Rencontre")
	_check(ui.session.room_draft_mode, "Brouillon de salle actif")
	var draft := workspace.arena_studio.room_draft()
	draft.waves.clear()
	draft.encounter_definition = null
	draft.enemies.clear()
	draft.minimum_wave_count = 0
	draft.maximum_wave_count = 1
	ui.session.select(0, 0)
	ui._refresh_all()
	await _capture("01_salle_sans_affrontement")
	_check(ui.map_preview.grid != null, "Terrain visible avant le premier affrontement")
	# La bannière de brouillon est déjà visible depuis l'état 1 : la capture
	# dédiée documente explicitement ce même état, nommé pour lui-même.
	await _capture("02_brouillon")

	ui._add_wave()
	await _frames(2)
	await _capture("03_composition_vide")
	await _capture("04_catalogue")

	if not ui.enemy_catalog.is_empty() and ui.catalog_cards_box.get_child_count() > 0:
		var roster_before := ui.session.current_encounter().roster_units.size()
		var catalog_card := ui.catalog_cards_box.get_child(0) as EncounterEnemyCard
		catalog_card.focus_add_control()
		await _frames(1)
		await _send_key(KEY_ENTER)
		_check(ui.session.current_encounter().roster_units.size() == roster_before + 1,
			"Entrée ajoute réellement un ennemi depuis le catalogue")
	if ui.enemy_catalog.size() > 1:
		ui._add_unit(ui.enemy_catalog[1])
	await _frames(2)
	await _capture("05_composition_remplie")

	ui.generate_preview()
	await _frames(2)
	await _capture("06_placement")

	var room := ui.session.runtime_room()
	ui.map_preview.grid = EncounterGridFactory.build_from_room(room)
	ui.map_preview._configure_projection()
	var cell := Vector2i(mini(2, maxi(0, room.grid_size.x - 1)), mini(2, maxi(0, room.grid_size.y - 1)))
	ui.map_preview.selected_cell = cell
	ui._on_cell_selected(cell)
	ui.map_preview.queue_redraw()
	await _frames(2)
	await _capture("07_carte_en_consultation")

	ui.forbidden_tool_toggle.button_pressed = true
	ui.map_preview.set_edit_mode(true)
	await _frames(2)
	await _capture("08_outil_cases_interdites")
	ui.map_preview.set_edit_mode(false)
	ui.forbidden_tool_toggle.button_pressed = false

	ui.properties_tabs.current_tab = 0
	await _frames(2)
	await _capture("09_action_destructrice_visible")

	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide (G6)")
	ui.validate_session()
	ui.validation_toggle.button_pressed = false
	ui.validation_toggle.pressed.emit()
	await _capture("10_validation_repliee")
	ui.validation_toggle.button_pressed = true
	ui.validation_toggle.pressed.emit()
	await _capture("11_validation_ouverte")

	var error_card := _card(ui, &"living_cap_too_low")
	if error_card != null:
		var scroll := error_card.get_parent().get_parent() as ScrollContainer
		if scroll != null:
			scroll.ensure_control_visible(error_card)
		await _capture("12_diagnostic_actionnable")
	var error_card_again := _card(ui, &"living_cap_too_low")
	if error_card_again != null:
		error_card_again.details_requested.emit()
		await _capture("13_details_techniques", true)
		ui.validation_details_dialog.hide()
		await _frames(2)
		error_card_again.fix_requested.emit()
		if ui.shared_dialog.visible:
			ui.shared_dialog.confirmed.emit()
		await _frames(2)
	ui.validate_session()
	await _capture("14_etat_sans_probleme_bloquant")

	if not ui.session.current_encounter().roster_units.is_empty():
		ui.session.current_encounter().roster_units[0].unit_name = (
			"Un nom d'ennemi extrêmement long destiné à vérifier que le Studio "
			+ "replie le texte au lieu de déborder de l'écran, même à 1280 pixels"
		)
	ui.validate_session()
	await _capture("15_textes_longs")

	await _keyboard_checks(ui)
	await _capture("19_focus_clavier_visible")

	await _close_workspace(bundle)


## --- Phase 2 : rencontre partagée, panneaux ouverts/repliés -----------------

func _phase_shared_and_panels() -> void:
	var bundle := await _open_workspace(SHARED)
	workspace = bundle.workspace
	await _frames()
	var ui := workspace.encounter_studio
	workspace.tabs.current_tab = 1
	await _frames(2)
	await _capture("16_rencontre_partagee")

	ui.validation_panel.show()
	ui.validation_toggle.set_pressed_no_signal(true)
	ui.navigation_toggle.button_pressed = true
	ui.navigation_toggle.pressed.emit()
	await _frames(2)
	await _capture("17_panneaux_ouverts")

	ui.navigation_toggle.button_pressed = false
	ui.navigation_toggle.pressed.emit()
	ui.validation_toggle.button_pressed = false
	ui.validation_toggle.pressed.emit()
	await _frames(2)
	await _capture("18_panneaux_replies")

	await _close_workspace(bundle)


func _card(ui: EncounterStudioMain, code: StringName) -> EncounterDiagnosticCard:
	for candidate in ui.validation_cards_box.get_children():
		if candidate.message != null and candidate.message.code == code:
			return candidate
	return null


func _check_modal_windows(allow_modal: bool) -> void:
	if allow_modal:
		return
	for node in _descendants(workspace):
		if node is Window:
			_check(not node.visible, "Aucune modale résiduelle : " + str(node.name))


func _capture(label: String, allow_modal := false) -> void:
	await _frames(6)
	root.warp_mouse(Vector2(resolution.x - 2, resolution.y - 2))
	await _frames(1)
	_check_modal_windows(allow_modal)
	var frame := Rect2(Vector2.ZERO, Vector2(root.content_scale_size))
	var outside: Array = []
	for node in _descendants(workspace):
		if node is Button and node.is_visible_in_tree() and not frame.encloses(node.get_global_rect()) \
				and not _inside_scroll_container(node) and not _inside_dialog(node):
			outside.append({"text": node.text, "rect": str(node.get_global_rect())})
	_check(outside.is_empty(), label + " : aucun bouton hors écran (hors zones défilables/dialogues)")
	for node in _descendants(workspace):
		if node is Window and node.visible:
			_check(frame.encloses(Rect2(Vector2(node.position), Vector2(node.size))),
				label + " : fenêtre modale entièrement dans l'écran (" + str(node.name) + ")")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == resolution, label + " : dimensions de capture")
	var suffix := "_%dpct" % roundi(ui_scale * 100.0) if ui_scale > 1.0 else ""
	var path := output_root.path_join(
		"%s_%dx%d%s.png" % [label, resolution.x, resolution.y, suffix]
	)
	_check(image.save_png(path) == OK, label + " : capture enregistrée")
	captures.append({"view": label, "path": path, "outside_buttons": outside})


func _keyboard_checks(ui: EncounterStudioMain) -> void:
	ui.forbidden_tool_toggle.grab_focus()
	await _frames(1)
	var first_focus := root.gui_get_focus_owner()
	await _send_key(KEY_TAB)
	var next_focus := root.gui_get_focus_owner()
	_check(next_focus != null and next_focus != first_focus, "Tab avance le focus")
	await _send_key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == first_focus, "Maj+Tab revient au contrôle précédent")

	ui.validation_toggle.set_pressed_no_signal(false)
	ui.validation_panel.hide()
	ui.validation_toggle.grab_focus()
	await _send_key(KEY_ENTER)
	_check(ui.validation_toggle.button_pressed and ui.validation_panel.visible,
		"Entrée active le bouton Validation")

	ui.forbidden_tool_toggle.grab_focus()
	await _send_key(KEY_SPACE)
	_check(ui.map_preview.edit_forbidden_mode, "Espace active l'outil des cases interdites")
	var dirty_before_escape := ui.session.document_fingerprint()
	await _send_key(KEY_ESCAPE)
	_check(not ui.map_preview.edit_forbidden_mode, "Échap quitte l'outil des cases interdites")
	_check(ui.session.document_fingerprint() == dirty_before_escape,
		"Échap ne modifie pas le document")

	var card := _card(ui, &"living_cap_too_low")
	if card == null and ui.validation_cards_box.get_child_count() > 0:
		card = ui.validation_cards_box.get_child(0) as EncounterDiagnosticCard
	if card != null:
		card.details_requested.emit()
		await _frames(1)
		_check(ui.validation_details_dialog.visible, "Détails techniques ouverts")
		await _send_key(KEY_ESCAPE)
		_check(not ui.validation_details_dialog.visible, "Échap ferme les détails techniques")

	ui.forbidden_tool_toggle.grab_focus()
	await _frames(1)


func _send_key(keycode: Key, shift := false) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	pressed.shift_pressed = shift
	root.push_input(pressed, true)
	await get_tree().process_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	root.push_input(released, true)
	await get_tree().process_frame


func _inside_scroll_container(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false


## Un bouton dans une fenêtre modale (AcceptDialog, ConfirmationDialog...) a
## son propre système de coordonnées de fenêtre : la comparer au rectangle de
## l'écran principal donne un faux positif, la fenêtre se recentre elle-même.
func _inside_dialog(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is Window:
			return true
		current = current.get_parent()
	return false


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
