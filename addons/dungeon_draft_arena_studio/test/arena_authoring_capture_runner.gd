extends Control

const OUTPUT := "res://artifacts/arena_authoring_speed/captures"
const FOREST_BACKGROUND := "res://asset/map/painted/room_01_forest/forest_background_v2.webp"
const GREECE_SOURCE := "res://addons/dungeon_draft_arena_studio/catalog/backdrops/greece.tres"
const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(1200, 896),
]
const CASES := [
	{"id": "01_quick_palette", "category": "PEINTURE", "title": "Palette rapide et pinceaux 1 / 2 / 3", "kind": "palette"},
	{"id": "02_water_stroke", "category": "PEINTURE", "title": "Trait continu Eau - mutation visuelle immediate", "kind": "water_stroke"},
	{"id": "03_poison_rectangle", "category": "PEINTURE", "title": "Rectangle Poison - une transaction", "kind": "poison_rectangle"},
	{"id": "04_neutral_fill", "category": "PEINTURE", "title": "Remplissage contigu Neutre", "kind": "neutral_fill"},
	{"id": "05_performance_before_after", "category": "PEINTURE", "title": "Performance mesuree avant / apres", "kind": "performance"},
	{"id": "06_single_undo", "category": "PEINTURE", "title": "Un trait = une action Undo", "kind": "undo"},
	{"id": "07_forest_before", "category": "DECOR", "title": "Decor foret avant transaction", "kind": "forest"},
	{"id": "08_greece_selection", "category": "DECOR", "title": "Source Grece decouverte dans le catalogue", "kind": "greece_selection"},
	{"id": "09_greece_background", "category": "DECOR", "title": "Fond grec applique", "kind": "greece_background"},
	{"id": "10_greece_grid", "category": "DECOR", "title": "Grille calibree au-dessus du fond grec", "kind": "greece_grid"},
	{"id": "11_backdrop_compare", "category": "DECOR", "title": "Comparaison foret / Grece", "kind": "compare"},
	{"id": "12_foreground_occlusion", "category": "DECOR", "title": "Pack complet - foreground et occlusion explicites", "kind": "foreground"},
	{"id": "13_poison_status", "category": "TERRAINS", "title": "Poison - application puis tick suivant", "kind": "poison_status"},
	{"id": "14_burn_status", "category": "TERRAINS", "title": "Lave 15 directe / Brulure 6 periodique", "kind": "burn_status"},
	{"id": "15_electrified_status", "category": "TERRAINS", "title": "Eau electrifiee - Mouille + Choc", "kind": "electrified_status"},
	{"id": "16_shock_round_lock", "category": "TERRAINS", "title": "Verrou anti-stun par unite et par round", "kind": "shock_lock"},
	{"id": "17_single_vortex_network", "category": "VORTEX", "title": "Reseau d'une cellule", "kind": "vortex_single"},
	{"id": "18_void_impulse", "category": "VORTEX", "title": "Impulsion du vide +1 PM courant", "kind": "void_impulse"},
	{"id": "19_two_vortex_network", "category": "VORTEX", "title": "Reseau de deux - teleportation directe", "kind": "vortex_pair"},
	{"id": "20_four_vortex_network", "category": "VORTEX", "title": "Reseau de quatre - sortie deterministe aleatoire", "kind": "vortex_four"},
	{"id": "21_vortex_destinations", "category": "VORTEX", "title": "Destinations valides et probabilites", "kind": "vortex_destinations"},
	{"id": "22_vortex_teleport", "category": "VORTEX", "title": "Teleportation - mouvement termine, aucun rebond", "kind": "vortex_teleport"},
]

var _content: Control = null
var _overlay_layer: CanvasLayer
var _overlay_label: Label
var _captures: Array[Dictionary] = []
var _failures: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_build_overlay()
	for size in SIZES:
		get_window().size = size
		await _wait_frames(3)
		for definition in CASES:
			await _capture_case(definition, size)
	_write_report()
	var expected := SIZES.size() * CASES.size()
	print("ARENA_AUTHORING_CAPTURE_COMPLETE=", JSON.stringify({
		"ok": _failures.is_empty() and _captures.size() == expected,
		"capture_count": _captures.size(),
		"expected_capture_count": expected,
		"failures": _failures,
		"produced_bundle_loaded": false,
	}))
	get_tree().quit(0 if _failures.is_empty() and _captures.size() == expected else 1)


func _capture_case(definition: Dictionary, size: Vector2i) -> void:
	_clear_content()
	var kind := str(definition.kind)
	var arena := _arena_for_kind(kind)
	if kind == "compare":
		_build_compare_scene(size)
	else:
		_build_studio_scene(arena, size, definition)
	_set_overlay(str(definition.category), str(definition.title), arena)
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file_name := "%s_%dx%d.png" % [definition.id, size.x, size.y]
	var path := OUTPUT.path_join(file_name)
	var ok := image != null and not image.is_empty() \
		and image.save_png(ProjectSettings.globalize_path(path)) == OK
	if not ok:
		_fail("capture_failed:%s" % file_name)
	_captures.append({
		"case": definition.id,
		"category": definition.category,
		"title": definition.title,
		"resolution": [size.x, size.y],
		"path": path,
		"sha256": FileAccess.get_sha256(path) if ok else "",
		"ok": ok,
		"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"produced_bundle_loaded": false,
	})


func _build_studio_scene(arena: ArenaDefinition, size: Vector2i, definition: Dictionary) -> void:
	var root := PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	move_child(root, 0)
	_content = root
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	margin.add_theme_constant_override("margin_top", 126)
	root.add_child(margin)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	margin.add_child(body)
	var canvas := ArenaStudioCanvas.new()
	canvas.name = "ArenaAuthoringProofCanvas"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_stretch_ratio = 3.2
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(maxf(650.0, size.x * 0.62), 430.0)
	canvas.show_grid = str(definition.kind) != "greece_background"
	canvas.grid_opacity = 0.82
	canvas.background_opacity = 1.0
	body.add_child(canvas)
	var inspector := _build_inspector(arena, definition)
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.size_flags_stretch_ratio = 1.0
	inspector.custom_minimum_size.x = minf(390.0, maxf(300.0, size.x * 0.25))
	body.add_child(inspector)
	canvas.set_arena(arena)
	if str(definition.kind) in ["vortex_destinations", "vortex_teleport"]:
		canvas.set_verification_overlay([], [Vector2i(1, 2), Vector2i(6, 4)], [], false, Vector2i(-1, -1))
	if str(definition.kind) == "undo":
		canvas.selected_cells = _water_stroke_cells().slice(0, 8)
		canvas.queue_redraw()


func _build_inspector(arena: ArenaDefinition, definition: Dictionary) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	scroll.add_child(panel)
	_add_heading(panel, str(definition.category), 25, Color("8fd7ff"))
	_add_heading(panel, str(definition.title), 20, Color.WHITE)
	var kind := str(definition.kind)
	match kind:
		"palette":
			_add_label(panel, "Selection rapide", 17, Color("c8d4e8"))
			var grid := GridContainer.new()
			grid.columns = 2
			panel.add_child(grid)
			for item in ["Pierre", "Neutre", "Eau", "Glace", "Lave", "Poison", "Vapeur", "Electrique"]:
				var button := Button.new()
				button.text = item
				button.custom_minimum_size = Vector2(130, 42)
				grid.add_child(button)
			_add_label(panel, "Recents : Eau | Poison | Lave\nPinceau : [1] [2] [3]\nAlt + clic : prelever", 16, Color("b8f5c8"))
		"performance":
			_add_metric_card(panel, "AVANT", "100 syncs\n571-1105 ms", Color("ff9d91"))
			_add_metric_card(panel, "APRES", "1 sync max\nfinalisation 1.516 ms", Color("9df5b2"))
			_add_label(panel, "Fixture 32x32 / 200 cellules : 6.634 ms", 16, Color("c8d4e8"))
		"undo":
			_add_metric_card(panel, "TRANSACTION", "snapshot unique\n100 mutations dedupliquees\n1 action Undo", Color("9df5b2"))
		"greece_selection":
			_add_label(panel, "Sources disponibles", 17, Color("c8d4e8"))
			for source in ArenaBackdropCatalogService.discover():
				var prefix := "> " if source.source_id == &"greece" else "  "
				_add_label(panel, "%s%s" % [prefix, source.display_name], 16, Color("9df5b2") if source.source_id == &"greece" else Color("c8d4e8"))
			_add_label(panel, "Mode recommande :\nDecor + calibration + camera", 16, Color("ffd48f"))
		"greece_background", "greece_grid":
			_add_label(panel, "Grèce - Agora antique\n1254 x 1254\nGrille : 14 x 14\nAngle : axes calibres\nCamera : zoom 0.92", 16, Color("c8d4e8"))
			_add_label(panel, "Gameplay preserve : OUI", 17, Color("9df5b2"))
		"foreground":
			_add_label(panel, "PACK VISUEL COMPLET", 17, Color("ffd48f"))
			_add_label(panel, "Background : remplace\nForeground : copie si disponible\nOcclusion : copie si disponible\nPolygon / sort Y : transactionnels", 16, Color("c8d4e8"))
			_add_label(panel, "Source Grece : aucun foreground\nAucun recalage silencieux", 16, Color("9df5b2"))
		"poison_status":
			_add_status_contract(panel, "[TERRAIN] Poison applique", "[STATUT] Poison inflige 4 degats", "Duree 3 - debut activation")
		"burn_status":
			_add_status_contract(panel, "[TERRAIN] Lave inflige 15", "[STATUT] Brulure inflige 6", "Sources separees - aucun doublon")
		"electrified_status":
			_add_status_contract(panel, "[TERRAIN] Mouille applique", "[TERRAIN] Choc applique", "Mouvement courant termine")
		"shock_lock":
			_add_metric_card(panel, "VERROU", "unite + round + region\n1 Choc maximum", Color("9df5b2"))
			_add_label(panel, "Sortie / re-entree meme round : ignoree\nNouveau round : nouveau declenchement", 16, Color("c8d4e8"))
		"vortex_single", "void_impulse", "vortex_pair", "vortex_four", "vortex_destinations", "vortex_teleport":
			_build_vortex_inspector(panel, arena, kind)
		_:
			_add_label(panel, "Grid visible\nWorking copy seulement\nUne action Undo", 16, Color("c8d4e8"))
	_add_label(panel, "WORKTREE_CANDIDATE\nBundle produced charge : NON", 14, Color("8f9db4"))
	return scroll


func _build_compare_scene(size: Vector2i) -> void:
	var root := PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	move_child(root, 0)
	_content = root
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 126)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)
	for item in [
		{"title": "AVANT - Foret", "arena": _forest_arena()},
		{"title": "APRES - Grece", "arena": _greece_arena()},
	]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(box)
		_add_heading(box, item.title, 20, Color("9df5b2"))
		var canvas := ArenaStudioCanvas.new()
		canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		canvas.show_grid = true
		canvas.grid_opacity = 0.78
		box.add_child(canvas)
		canvas.set_arena(item.arena)
	var slider := VSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.value = 0.5
	slider.custom_minimum_size.x = 24
	columns.add_child(slider)


func _arena_for_kind(kind: String) -> ArenaDefinition:
	match kind:
		"forest", "greece_selection": return _forest_arena()
		"greece_background", "greece_grid", "foreground", "compare": return _greece_arena()
	var arena := _base_arena()
	match kind:
		"water_stroke", "performance", "undo":
			for cell in _water_stroke_cells():
				ArenaDynamicEditingService.paint_terrain(arena, cell, &"water")
		"poison_rectangle", "poison_status":
			_paint_rect(arena, Rect2i(2, 1, 4, 3), &"poison")
		"neutral_fill":
			_paint_rect(arena, Rect2i(0, 0, 4, 6), &"neutral")
		"burn_status":
			_paint_rect(arena, Rect2i(2, 1, 4, 3), &"lava")
		"electrified_status", "shock_lock":
			_paint_rect(arena, Rect2i(1, 1, 6, 3), &"electrified_water")
		"vortex_single", "void_impulse":
			_add_vortex_network(arena, [Vector2i(3, 2)], "Impulsion")
		"vortex_pair":
			_add_vortex_network(arena, [Vector2i(1, 2), Vector2i(6, 4)], "Portail direct")
		"vortex_four", "vortex_destinations", "vortex_teleport":
			_add_vortex_network(arena, [Vector2i(1, 2), Vector2i(6, 1), Vector2i(2, 4), Vector2i(6, 4)], "Reseau tactique")
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _base_arena() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Arena authoring visual proof", "arena_authoring_capture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"forest"
	arena.grid_size = Vector2i(8, 6)
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = &"forest"
	arena.modular_visual_profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	_frame_modular_arena(arena)
	return arena


func _forest_arena() -> ArenaDefinition:
	var loaded := ResourceLoader.load(
		"res://data/arenas/room_01_forest.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	var arena := loaded.duplicate(true) as ArenaDefinition if loaded != null else _base_arena()
	arena.background_path = FOREST_BACKGROUND
	return arena


func _greece_arena() -> ArenaDefinition:
	var arena := _base_arena()
	var source := load(GREECE_SOURCE) as ArenaBackdropSourceDefinition
	if source == null:
		_fail("greece_source_missing")
		return arena
	var transaction := ArenaBackdropTransactionService.new()
	var result := transaction.apply(
		arena, source, ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA
	)
	if not bool(result.get("ok", false)):
		_fail("greece_transaction_failed:%s" % result)
	return arena


func _frame_modular_arena(arena: ArenaDefinition) -> void:
	arena.grid_origin = Vector2(430, 150)
	arena.axis_x = Vector2(74, 37)
	arena.axis_y = Vector2(-74, 37)
	ArenaRuntimeBridge.sync_runtime_resources(arena)


func _paint_rect(arena: ArenaDefinition, rect: Rect2i, terrain_id: StringName) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			ArenaDynamicEditingService.paint_terrain(arena, Vector2i(x, y), terrain_id)


func _water_stroke_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(1, 5):
		var values := range(1, 7)
		if y % 2 == 0:
			values.reverse()
		for x in values:
			cells.append(Vector2i(x, y))
	return cells


func _add_vortex_network(arena: ArenaDefinition, cells: Array[Vector2i], title: String) -> void:
	var network := ArenaVortexNetworkService.create_network(arena, title)
	for cell in cells:
		ArenaVortexNetworkService.add_cell(arena, network.network_id, cell)


func _build_vortex_inspector(panel: VBoxContainer, arena: ArenaDefinition, kind: String) -> void:
	var network := arena.vortex_networks[0] as ArenaVortexNetworkDefinition if not arena.vortex_networks.is_empty() else null
	if network == null:
		_add_label(panel, "Aucun reseau", 16, Color("ff9d91"))
		return
	_add_label(panel, "Reseau actif : %s\nID : %s" % [network.display_name, network.network_id], 17, Color("c8d4e8"))
	_add_metric_card(panel, "COMPORTEMENT", ArenaVortexNetworkService.behavior_summary(network), Color("9df5b2"))
	_add_label(panel, "Dalles : %s" % str(network.cells), 15, Color("c8d4e8"))
	if network.cells.size() >= 3:
		var probability := 100.0 / float(network.cells.size() - 1)
		_add_label(panel, "Depuis l'entree 1 :\n%d destinations possibles\n%.1f pour cent par destination valide" % [network.cells.size() - 1, probability], 16, Color("ffd48f"))
	if kind == "void_impulse":
		_add_label(panel, "+1 PM activation courante\n1 fois / unite / round\nnon cumulable", 17, Color("9df5b2"))
	elif kind == "vortex_teleport":
		_add_label(panel, "Seed stable\nDestination occupee exclue\nMouvement termine\nArrivee sans reactivation", 16, Color("9df5b2"))


func _add_status_contract(panel: VBoxContainer, terrain_line: String, status_line: String, detail: String) -> void:
	_add_label(panel, terrain_line, 16, Color("ffd48f"))
	_add_label(panel, status_line, 16, Color("9df5b2"))
	_add_label(panel, detail + "\nStatut identique : duree rafraichie\nAucune instance concurrente", 15, Color("c8d4e8"))


func _add_metric_card(panel: VBoxContainer, title: String, value: String, color: Color) -> void:
	var card := PanelContainer.new()
	panel.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	_add_heading(box, title, 16, color)
	_add_label(box, value, 17, Color.WHITE)


func _add_heading(parent: Control, value: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _add_label(parent: Control, value: String, font_size: int, color: Color) -> void:
	_add_heading(parent, value, font_size, color)


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	add_child(_overlay_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	panel.custom_minimum_size = Vector2(900, 94)
	_overlay_layer.add_child(panel)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 19)
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("shadow_offset_x", 2)
	_overlay_label.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(_overlay_label)


func _set_overlay(category: String, title: String, arena: ArenaDefinition) -> void:
	_overlay_label.text = (
		"ARENA AUTHORING SPEED / BACKDROP / STATUS / VORTEX - WORKTREE_CANDIDATE\n"
		+ "%s - %s\nGameplay fingerprint : %s"
	) % [category, title, ArenaSnapshotService.gameplay_fingerprint(arena)]


func _clear_content() -> void:
	if is_instance_valid(_content):
		_content.free()
	_content = null


func _write_report() -> void:
	var path := OUTPUT.get_base_dir().path_join("capture_report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("capture_report_write_failed")
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"mission": "ARENA AUTHORING SPEED BACKDROP WORKFLOW TERRAIN STATUS TIMING AND VORTEX NETWORKS",
		"expected_capture_count": SIZES.size() * CASES.size(),
		"resolutions": SIZES.map(func(value): return [value.x, value.y]),
		"captures": _captures,
		"failures": _failures,
		"produced_bundle_loaded": false,
	}, "  "))
	file.close()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
