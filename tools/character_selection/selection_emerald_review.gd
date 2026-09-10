extends "res://tools/ui_chrome/menus_review.gd"
## Native captures and real input for both public appearances.


func _run() -> void:
	_output = "res://artifacts/dev/selection-emerald-restored/captures"
	DirAccess.make_dir_recursive_absolute(_output)
	GameManager.set_reduced_motion_enabled(true)
	var title: Node = load("res://ui/TitreEcran.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _settle()
	await _click(title.get_node("UI/Boutons/BoutonNouvellePartie"))
	var selection := get_tree().current_scene as CharacterSelectionScreen
	_check(selection != null, "Title opens the emerald character selection")
	if selection == null:
		await _finish()
		return
	_check(selection.get_entries().size() == 2, "Only the two Catabase appearances are public")
	for dimensions in [Vector2i(1280, 720), Vector2i(1200, 896), Vector2i(1920, 1080)]:
		_review_size = dimensions
		await _settle()
		await _capture(
			"classic_%dx%d" % [dimensions.x, dimensions.y],
			[
				selection.start_button,
				selection._details,
				selection._roster_buttons[0],
				selection._roster_buttons[1],
				selection._pose_buttons[2],
			],
		)
	await _click(selection._roster_buttons[1])
	_check(
		selection.get_selected_entry().get("id") == &"achilles_painted_g",
		"Real click selects painted Achille",
	)
	await _capture("painted_1920x1080", [selection.start_button, selection._details])
	var orientation := selection.orientation_index
	await _click(selection.find_child("RotateRight", true, false))
	_check(
		selection.orientation_index != orientation,
		"Rotation control reaches the preview",
	)
	await _click(selection._pose_buttons[1])
	_check(selection._pose == &"walk", "Pose control changes the animation")
	await _click(selection._tab_buttons[1])
	_check(selection._lore.is_visible_in_tree(), "History tab remains reachable")
	await _capture("painted_history_1920x1080", [selection._lore, selection.start_button])
	var opening := selection._lore.get_node("ExploreMasteriesFromLore") as Button
	await _click(opening)
	var codex := selection.get_spell_tree()
	_check(codex != null, "History opens the consultative codex")
	if codex != null:
		codex.close_screen()
		await _settle()
		_check(
			get_viewport().gui_get_focus_owner() == opening,
			"Closing the codex restores keyboard focus",
		)
	selection.queue_free()
	get_tree().current_scene = null
	await _settle()
	await _finish()
