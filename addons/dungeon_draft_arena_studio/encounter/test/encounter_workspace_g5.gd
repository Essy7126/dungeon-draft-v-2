extends "res://addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_baseline.gd"

## Extension G5 : diagnostics compréhensibles et actionnables. Les artefacts
## G1/G2/G3-G4 restent intacts ; ce runner est indépendant.
const G5_OUTPUT := "res://artifacts/encounter_g5"


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
	workspace.tabs.current_tab = 1
	var ui := workspace.encounter_studio
	await _frames()

	# --- État 1 : aucun problème bloquant --------------------------------
	ui.validate_session()
	ui.validation_toggle.button_pressed = true
	ui.validation_toggle.pressed.emit()
	await _g5_capture("01_aucun_probleme_bloquant")
	_check(ui.validation_empty_label.visible, "L'état positif s'affiche sans erreur")

	# --- État 2 : validation repliée avec erreurs ------------------------
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide (G5)")
	ui.validate_session()
	ui.validation_toggle.button_pressed = false
	ui.validation_toggle.pressed.emit()
	await _g5_capture("02_validation_repliee_avec_erreurs")
	_check(
		ui.validation_toggle.text.begins_with("▸") and ui.validation_toggle.text.contains("✖"),
		"Le résumé replié annonce l'erreur sur le bouton qui déplie le détail"
	)

	# --- État 3 : validation ouverte, plusieurs gravités -----------------
	ui.validation_toggle.button_pressed = true
	ui.validation_toggle.pressed.emit()
	await _g5_capture("03_validation_ouverte_plusieurs_gravites")
	var severities := {}
	for message in ui.session.validation_messages:
		severities[message.severity] = true
	_check(severities.size() >= 3, "Erreur, avertissement et information coexistent")

	# --- État 4 : carte d'erreur, carte avec Voir, carte avec Corriger ---
	var error_card := _g5_card(ui, &"living_cap_too_low")
	_check(error_card != null, "Carte d'erreur trouvée")
	if error_card != null:
		var scroll := error_card.get_parent().get_parent() as ScrollContainer
		if scroll != null:
			scroll.ensure_control_visible(error_card)
		await _g5_capture("04_carte_erreur")
		_check(error_card.view_button != null, "living_cap_too_low propose Voir (rattaché à une salle)")
		_check(error_card.fix_button != null, "living_cap_too_low propose Corriger")
		await _g5_capture("05_carte_avec_corriger")

	# --- État 5 : diagnostic sur une case ---------------------------------
	ui.session.current_encounter().forbidden_initial_spawn_cells = [Vector2i(99, 99)]
	ui.validate_session()
	var cell_card := _g5_card(ui, &"forbidden_cell_outside")
	if cell_card != null:
		var scroll2 := cell_card.get_parent().get_parent() as ScrollContainer
		if scroll2 != null:
			scroll2.ensure_control_visible(cell_card)
		_check(cell_card.view_button != null, "Un diagnostic de case propose Voir")
		cell_card.view_requested.emit()
		await _frames(2)
		_check(ui.map_preview.selected_cell == Vector2i(99, 99), "La case est mise en évidence sur la carte")
		await _g5_capture("06_diagnostic_sur_une_case")

	# --- État 6 : détails techniques ---------------------------------------
	# ui.validate_session() (état 5) a reconstruit les cartes : la carte
	# d'erreur doit être retrouvée à nouveau plutôt que réutilisée par
	# référence, exactement comme un vrai clic le ferait après un
	# rafraîchissement.
	var error_card_again := _g5_card(ui, &"living_cap_too_low")
	if error_card_again != null:
		error_card_again.details_requested.emit()
		await _g5_capture("07_details_techniques")
		_check(ui.validation_details_dialog.visible, "Le dialogue technique s'ouvre à la demande")
		ui.validation_details_dialog.hide()

	# --- État 7 : texte long -----------------------------------------------
	var unit := ui.session.current_encounter().roster_units[0]
	unit.unit_name = "Un nom d'ennemi extrêmement long destiné à vérifier que les cartes de diagnostic replient le texte au lieu de déborder de l'écran, même à 1280 pixels de large"
	ui.validate_session()
	await _g5_capture("08_texte_long")

	_check_modal_windows()
	var report := {
		"resolution": [resolution.x, resolution.y], "checks": checks, "captures": captures,
	}
	var file := FileAccess.open(G5_OUTPUT.path_join("g5_%dx%d.json" % [resolution.x, resolution.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	embedded.remove_child(workspace)
	workspace.free()
	embedded.free()
	await _frames()
	get_tree().quit(1 if checks.any(func(check): return not check.ok) else 0)


func _g5_card(ui: EncounterStudioMain, code: StringName) -> EncounterDiagnosticCard:
	for candidate in ui.validation_cards_box.get_children():
		if candidate.message != null and candidate.message.code == code:
			return candidate
	return null


func _g5_capture(label: String) -> void:
	await _frames(6)
	var frame := Rect2(Vector2.ZERO, Vector2(resolution))
	var outside: Array = []
	for node in _descendants(workspace):
		# Un contrôle scrollé hors de la fenêtre visible d'un ScrollContainer
		# n'est pas un débordement : c'est le rôle du défilement. Seuls les
		# boutons hors écran EN DEHORS de toute zone volontairement
		# défilable comptent comme un vrai débordement.
		if node is Button and node.is_visible_in_tree() and not frame.encloses(node.get_global_rect()) \
				and not _inside_scroll_container(node):
			outside.append({"text": node.text, "rect": str(node.get_global_rect())})
	_check(outside.is_empty(), label + " : aucun bouton hors écran (hors zones défilables)")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == resolution, label + " : dimensions de capture")
	var path := G5_OUTPUT.path_join("%s_%dx%d.png" % [label, resolution.x, resolution.y])
	_check(image.save_png(path) == OK, label + " : capture enregistrée")
	captures.append({"view": label, "path": path, "outside_buttons": outside})


func _inside_scroll_container(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false
