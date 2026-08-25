extends Control

## Runner de captures de la refonte Terrain. Il instancie le veritable
## StudioWorkspace, celui que le plugin place dans l'editeur, afin qu'aucune
## capture ne montre une barre interne que l'hote reel masque.
##
## Usage :
##   godot --headless --path . res://addons/dungeon_draft_arena_studio/test/TerrainStudioCaptureRunner.tscn \
##     -- --width=1280 --height=720 --views=home,creation,edit,selection,vortex,validation,advanced

const OUTPUT_ROOT := "res://artifacts/terrain_studio/screenshots"
const DEFAULT_VIEWS := "home,creation,edit,selection,vortex,validation,advanced,focus"

var _studio: StudioWorkspace
var _arena: ArenaStudioMain
var _size := Vector2i(1280, 720)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var options := _options()
	_size = Vector2i(int(options.get("width", 1280)), int(options.get("height", 720)))
	get_window().size = _size
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_window().content_scale_size = _size
	print("TERRAIN_STUDIO_CAPTURE_START ", _size)
	_studio = StudioWorkspace.new()
	_studio.arena_auto_load_enabled = false
	_studio.arena_production_planning_enabled = false
	# Le plugin fournit toujours un contexte projet partagé : sans lui, la
	# capture montrerait un accueil dégradé qui n'existe pas dans l'usage réel.
	var context := StudioProjectContext.new()
	context.initialize()
	print("TERRAIN_STUDIO_CAPTURE_STAGE context_ready")
	# Le runner fournit le vrai contexte partagé, mais ouvre lui-même sa fixture
	# Arena : éviter l'ouverture automatique d'une salle et son smoke de
	# production asynchrone rend la capture déterministe.
	context.active_room_index = -1
	_studio.setup(null, null, context, StudioReferenceGraphService.new())
	_studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_studio)
	print("TERRAIN_STUDIO_CAPTURE_STAGE workspace_added")
	for _frame in range(10):
		await get_tree().process_frame
	print("TERRAIN_STUDIO_CAPTURE_STAGE workspace_ready")
	_arena = _studio.arena_studio
	if _arena == null:
		push_error("Studio Terrain : ArenaStudioMain introuvable dans le workspace.")
		get_tree().quit(1)
		return
	_studio.tabs.current_tab = 0
	var arena := ArenaLegacyImporter.import_production(&"room_01_forest")
	print("TERRAIN_STUDIO_CAPTURE_STAGE arena_imported")
	if arena == null:
		push_error("Studio Terrain : la carte de référence n'a pas pu être importée.")
		get_tree().quit(1)
		return
	ArenaEditingService.apply_safety_border(arena, 1)
	_arena._set_arena(arena, false, "terrain_capture:forest")
	print("TERRAIN_STUDIO_CAPTURE_STAGE arena_opened")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var failures := 0
	for view in str(options.get("views", DEFAULT_VIEWS)).split(",", false):
		if not await _capture_view(view.strip_edges()):
			failures += 1
	print("TERRAIN_STUDIO_CAPTURE_DONE failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _capture_view(view: String) -> bool:
	print("TERRAIN_STUDIO_CAPTURE_STAGE view_begin ", view)
	if view != "focus":
		_arena.set_focus_map(false)
	# Le tiroir est fermé par défaut : seule la vue « validation » l'ouvre.
	if view != "validation" and _arena.bottom_drawer_content.visible:
		_arena._toggle_bottom_drawer()
	match view:
		"home":
			_arena.set_guided(true)
			_arena.show_home()
		"creation":
			_arena.set_guided(true)
			_arena.show_creation_wizard()
		"edit":
			_arena.set_guided(true)
			_arena.show_editor()
			_arena._on_tool_selected(ArenaStudioCanvas.Tool.TERRAIN)
		"selection":
			_arena.set_guided(true)
			_arena.show_editor()
			_arena._on_spatial_selection_requested(Vector2i(2, 2))
		"grid":
			_arena.set_guided(true)
			_arena.show_editor()
			_arena.set_current_step(TerrainWorkflowService.Step.SCENERY)
			_arena._start_manual_grid_alignment()
		"vortex":
			_arena.set_guided(true)
			_arena.show_editor()
			var entry := TerrainPlaceableCatalogService.entry_by_id(
				_arena.arena, &"vortex_portal_multi", true
			)
			if not entry.is_empty():
				_arena._on_library_placeable_selected(entry)
		"validation":
			_arena.set_guided(true)
			_arena.show_editor()
			_arena.set_current_step(TerrainWorkflowService.Step.VERIFY)
			# Une erreur de validation reelle : un point de depart de heros
			# pose sur la bordure de securite.
			_break_a_spawn()
			_arena.validate_arena()
			if not _arena.bottom_drawer_content.visible:
				_arena._toggle_bottom_drawer()
		"advanced":
			_arena.set_guided(false)
			_arena.show_editor()
			_arena.set_current_step(TerrainWorkflowService.Step.SCENERY)
		"focus":
			_arena.set_guided(true)
			_arena.show_editor()
			_arena.set_focus_map(true)
		_:
			push_error("Studio Terrain : vue de capture inconnue « %s »." % view)
			return false
	for _frame in range(6):
		await get_tree().process_frame
	print("TERRAIN_STUDIO_CAPTURE_STAGE view_stable ", view)
	# La vue est recadrée après stabilisation de la disposition : sinon la
	# capture montrerait le zoom calculé pour une zone de canvas transitoire.
	if _arena.canvas != null and _arena.canvas.is_visible_in_tree():
		_arena.canvas.fit_to_image()
	for _frame in range(3):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	print("TERRAIN_STUDIO_CAPTURE_STAGE render_ready ", view)
	_report_layout(view)
	var path := OUTPUT_ROOT.path_join(
		"terrain_studio_%s_%dx%d.png" % [view, _size.x, _size.y]
	)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Studio Terrain : le renderer actif ne fournit pas d'image de viewport.")
		return false
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("TERRAIN_STUDIO_CAPTURE ", path, " ", error_string(error))
	return error == OK


## Contrôle de débordement : chaque bloc principal doit rester dans la fenêtre.
func _report_layout(view: String) -> void:
	var blocks := {
		"header": _arena.header_bar,
		"checklist": _arena.checklist_panel,
		"library": _arena.library_panel,
		"canvas": _arena.view_stack,
		"drawer": _arena.bottom_drawer,
		"status": _arena.status_label,
		"rail": _arena.left_panel,
		"inspector": _arena.right_panel,
	}
	var lines := PackedStringArray()
	for key in blocks:
		var control := blocks[key] as Control
		if control == null:
			continue
		var rect := control.get_global_rect()
		lines.append("%s=%d..%d%s" % [
			key, int(rect.position.y), int(rect.end.y),
			"" if control.is_visible_in_tree() else "(masqué)",
		])
	# Une action placée dans une zone défilante reste atteignable : seules les
	# actions réellement hors fenêtre sont comptées.
	var overflow := 0
	for control in _arena.primary_action_controls():
		if control == null or not control.is_visible_in_tree() or _is_scrollable(control):
			continue
		var rect := control.get_global_rect()
		if rect.end.x > float(_size.x) + 1.0 or rect.end.y > float(_size.y) + 1.0:
			overflow += 1
	var ratio := _arena.canvas_occupation_ratio()
	print("TERRAIN_STUDIO_LAYOUT %s | window=%d | ratio=%.3f,%.3f | hors_ecran=%d | %s" % [
		view, _size.y, ratio.x, ratio.y, overflow, " ".join(lines),
	])


func _is_scrollable(control: Control) -> bool:
	var node := control.get_parent()
	while node != null and node != _arena:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


func _break_a_spawn() -> void:
	var arena := _arena.arena
	if arena == null or arena.spawns.is_empty():
		return
	var border := arena.border_cells()
	if border.is_empty():
		return
	var before := arena.to_snapshot()
	arena.spawns[0].cell = border[0]
	_arena._commit_change("Poser un départ sur la bordure", before, arena.to_snapshot())


func _options() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
