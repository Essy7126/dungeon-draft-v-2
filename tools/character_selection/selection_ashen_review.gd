extends SceneTree
## Real-renderer material and input review. Never starts or configures an adventure.

const OUTPUT := "res://artifacts/character_selection_ashen/"
const SCREEN_PATH := "res://ui/selection/CharacterSelectionScreen.tscn"

var screen
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var checks := 0
var gallery: Control
var sample_buttons: Dictionary = {}
var sample_rects: Dictionary = {}
var _runs_before: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	_runs_before = _run_snapshot()
	root.size = Vector2i(1280, 720)
	var packed = load(SCREEN_PATH)
	if packed == null:
		_check(false, "Selection scene loads")
		_finish()
		return
	screen = packed.instantiate()
	root.add_child(screen)
	current_scene = screen
	await _settle()
	_check(screen.get_entries().size() == 5, "All five hero/adventure choices remain present")
	await _move_pointer(Vector2(2, 2))
	await _capture("selection_1280x720")
	root.size = Vector2i(1920, 1080)
	await _settle()
	await _capture("selection_1920x1080")
	await _click(screen._roster_buttons[2])
	_check(screen.selected_index == 2, "A click through the material selects Mage")
	_check(screen.get_selected_entry().get("run").resource_path == "res://data/runs/first_run.tres", "Mage still uses the trio adventure")
	await _capture("mage_1920x1080")
	await _click(screen._roster_buttons[4])
	_check(screen.selected_index == 4, "A click reaches the fifth adventure")
	_check(screen.get_selected_entry().get("run").resource_path == "res://data/runs/philosopher_trial.tres", "The fifth card preserves the philosopher adventure")
	await _capture("trial_1920x1080")
	await _click(screen._roster_buttons[0])
	await _click(screen._tab_buttons[0])
	await _click(screen._spell_buttons[3])
	var mastery_button: Button = screen._details.get_node("ExploreMasteries")
	await _click(mastery_button)
	var codex = screen.get_spell_tree()
	_check(is_instance_valid(codex), "The mastery button opens through its textured layer")
	if is_instance_valid(codex):
		_check(codex.is_consultative(), "The selection codex remains consultative")
		await _capture("codex_1920x1080")
		await _escape()
		_check(screen.get_spell_tree() == null, "Escape closes the codex")
		_check(root.gui_get_focus_owner() == mastery_button, "Closing the codex restores focus to its opening button")
		await _capture("focus_after_codex_1920x1080")
	_check(_run_snapshot() == _runs_before, "Material interaction never changes active or prepared runs")
	await _review_gallery()
	_check(_run_snapshot() == _runs_before, "Gallery buttons never launch an adventure")
	if is_instance_valid(gallery):
		gallery.queue_free()
	if is_instance_valid(screen):
		screen.queue_free()
	await process_frame
	await process_frame
	_finish()


func _review_gallery() -> void:
	root.size = Vector2i(1440, 900)
	await _settle()
	screen.hide()
	gallery = Control.new()
	gallery.name = "AshenMaterialGallery"
	root.add_child(gallery)
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.theme = screen.theme
	var background := ColorRect.new()
	background.color = Color("12100e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gallery.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_label("MATIÈRES CENDRÉES", Rect2(54, 35, 1332, 54), 32, Color("f0e8d8"))
	_gallery_label("Contrôles réels · texte et cadre natifs · texture décorative", Rect2(54, 93, 1332, 35), 19, Color("b8aa97"))
	var names := ["normal", "hover", "pressed", "selected_hover", "focus", "disabled"]
	var titles := ["REPOS", "SURVOL", "PRESSION", "SÉLECTION + SURVOL", "FOCUS CLAVIER", "INDISPONIBLE"]
	for index in range(names.size()):
		var origin := Vector2(54 + (index % 3) * 456, 190 + (index / 3) * 280)
		var rect := Rect2(origin, Vector2(420, 220))
		sample_rects[names[index]] = rect
		_gallery_label(titles[index], Rect2(origin + Vector2(12, 10), Vector2(396, 36)), 19, Color("d1baa0"))
		var button: Button = screen._button(gallery, "Explorer les maîtrises   ›", Rect2(origin + Vector2(12, 72), Vector2(396, 68)), index == 5)
		button.name = "MaterialSample_" + names[index]
		button.focus_mode = Control.FOCUS_ALL
		if index == 3:
			button.toggle_mode = true
			button.pressed.connect(func(): screen._mark_selected(button, button.button_pressed))
		if index == 5:
			button.disabled = true
		sample_buttons[names[index]] = button
		_gallery_label("Aucun lancement d’aventure", Rect2(origin + Vector2(12, 160), Vector2(396, 31)), 16, Color("9e9283"))
	await _settle()
	await _move_pointer(Vector2(2, 2))
	root.gui_release_focus()
	await _capture("material_gallery")
	await _capture("state_normal", sample_rects["normal"])
	var normal: Button = sample_buttons["normal"]
	_check(not _state(normal).get("hovered", true), "Normal sample is not hovered")
	var hover: Button = sample_buttons["hover"]
	await _move_pointer(hover.get_global_rect().get_center())
	_check(_state(hover).get("hovered", false), "Injected motion updates the hovered material")
	await _capture("state_hover", sample_rects["hover"])
	var pressed: Button = sample_buttons["pressed"]
	var pressed_point := pressed.get_global_rect().get_center()
	await _move_pointer(pressed_point)
	await _mouse_button(pressed_point, true)
	_check(_state(pressed).get("depressed", false), "Holding the pointer updates the pressed material")
	await _capture("state_pressed", sample_rects["pressed"])
	await _mouse_button(pressed_point, false)
	var selected: Button = sample_buttons["selected_hover"]
	await _click(selected)
	_check(_state(selected).get("selected", false) and _state(selected).get("hovered", false), "Selection and hover remain simultaneously represented")
	await _capture("state_selected_hover", sample_rects["selected_hover"])
	var focus: Button = sample_buttons["focus"]
	await _move_pointer(Vector2(2, 2))
	focus.grab_focus()
	await _settle(4)
	_check(root.gui_get_focus_owner() == focus, "Native button receives keyboard focus above the material")
	await _capture("state_focus", sample_rects["focus"])
	var disabled: Button = sample_buttons["disabled"]
	_check(_state(disabled).get("disabled", false), "Disabled state is reflected by the surface")
	await _capture("state_disabled", sample_rects["disabled"])
	await _capture("material_gallery_selected_and_focus")


func _gallery_label(caption: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label := Label.new()
	gallery.add_child(label)
	label.text = caption
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _state(button: Button) -> Dictionary:
	var surface := button.get_node_or_null("AshenSurface")
	if surface == null or not surface.has_method("get_surface_state"):
		_check(false, "Material surface is present on " + button.name)
		return {}
	return surface.get_surface_state()


func _settle(frames: int = 40) -> void:
	for frame in range(frames):
		await process_frame


func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await _settle(3)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	await _settle(3)


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	await _move_pointer(point)
	await _mouse_button(point, true)
	await _mouse_button(point, false)
	await _settle()


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _capture(label: String, crop: Rect2 = Rect2()) -> void:
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	_check(captured != null and not captured.is_empty(), "Rendered image exists: " + label)
	if captured == null or captured.is_empty():
		return
	if crop.has_area():
		captured = captured.get_region(Rect2i(crop))
	var path := OUTPUT + label + ".png"
	var jpeg_path := OUTPUT + label + ".jpg"
	_check(captured.save_png(ProjectSettings.globalize_path(path)) == OK, "PNG saved: " + label)
	_check(captured.save_jpg(ProjectSettings.globalize_path(jpeg_path), 0.92) == OK, "JPEG saved: " + label)
	captures.append({"state": label, "path": path, "jpeg_path": jpeg_path, "width": captured.get_width(), "height": captured.get_height()})


func _run_snapshot() -> Dictionary:
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		return {}
	var active = manager.get_active_run_data()
	var prepared = manager.peek_next_run_data()
	return {"active": active.get_instance_id() if active != null else 0, "prepared": prepared.get_instance_id() if prepared != null else 0}


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures, "heading_font": _heading_font_snapshot()}
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write ashen selection review report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SELECTION_ASHEN_REVIEW: ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures.size()}))
	quit(0 if failures.is_empty() else 1)


func _heading_font_snapshot() -> Dictionary:
	var font := load("res://asset/ui/character_selection/selection_title_font.tres") as FontVariation
	if font == null:
		return {}
	var result := {"configured": font.variation_opentype, "font_weight": font.get_font_weight()}
	var text_server := TextServerManager.get_primary_interface()
	var rids := font.get_rids()
	if not rids.is_empty():
		if text_server.has_method("font_get_variation_coordinates"):
			result["effective_coordinates"] = text_server.call("font_get_variation_coordinates", rids[0])
		if text_server.has_method("font_supported_variation_list"):
			result["supported_axes"] = text_server.call("font_supported_variation_list", rids[0])
	print("SELECTION_ASHEN_HEADING_FONT: ", JSON.stringify(result))
	return result
