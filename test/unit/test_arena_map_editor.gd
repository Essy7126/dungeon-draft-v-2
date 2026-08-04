extends GutTest

const DOCUMENT_SCRIPT := preload("res://tools/arena_map_editor/arena_map_document.gd")
const CANVAS_SCENE := preload("res://tools/arena_map_editor/ArenaMapCanvas.tscn")
const EDITOR_SCENE := preload("res://tools/arena_map_editor/ArenaMapEditor.tscn")
const EXAMPLE_PATH := "res://tools/arena_map_editor/examples/reference_arena.json"
const TEST_MAP_PATH := "res://artifacts/labs/arena_map_editor/roundtrip_test.json"


func test_document_accepte_une_taille_variable_et_preserve_les_cellules() -> void:
	var document := ArenaMapDocument.new(Vector2i(8, 6))
	assert_eq(document.grid_size, Vector2i(8, 6))
	assert_eq(document.counts().active, 48)
	document.set_layer(Vector2i(7, 5), ArenaMapDocument.EditLayer.BASE, ArenaMapDocument.BaseTile.RUNE)
	document.resize(Vector2i(20, 14))
	assert_eq(document.grid_size, Vector2i(20, 14))
	assert_eq(document.get_cell(Vector2i(7, 5)).base, ArenaMapDocument.BaseTile.RUNE)
	assert_eq(document.get_cell(Vector2i(19, 13)).base, ArenaMapDocument.BaseTile.STONE)
	document.resize(Vector2i(5, 4))
	assert_eq(document.grid_size, Vector2i(5, 4))
	assert_eq(document.counts().total, 20)
	assert_eq(document.validation_errors(), PackedStringArray())


func test_regles_void_surfaces_speciales_et_murs_sont_coherentes() -> void:
	var document := ArenaMapDocument.new(Vector2i(3, 3))
	var cell := Vector2i(1, 1)
	assert_true(document.set_layer(cell, ArenaMapDocument.EditLayer.SURFACE, ArenaMapDocument.SurfaceEffect.FIRE))
	assert_true(document.set_layer(cell, ArenaMapDocument.EditLayer.SPECIAL, ArenaMapDocument.SpecialTile.OBJECTIVE))
	assert_true(document.set_layer(cell, ArenaMapDocument.EditLayer.WALL, ArenaMapDocument.WallType.ICE))
	var state := document.get_cell(cell)
	assert_eq(state.wall, ArenaMapDocument.WallType.ICE)
	assert_eq(state.surface, ArenaMapDocument.SurfaceEffect.NONE)
	assert_eq(state.special, ArenaMapDocument.SpecialTile.NONE)
	assert_true(document.set_layer(cell, ArenaMapDocument.EditLayer.SURFACE, ArenaMapDocument.SurfaceEffect.WATER))
	assert_eq(document.get_cell(cell).wall, ArenaMapDocument.WallType.NONE)
	assert_true(document.set_layer(cell, ArenaMapDocument.EditLayer.BASE, ArenaMapDocument.BaseTile.VOID))
	state = document.get_cell(cell)
	assert_eq(state.base, ArenaMapDocument.BaseTile.VOID)
	assert_eq(state.surface, ArenaMapDocument.SurfaceEffect.NONE)
	assert_eq(state.special, ArenaMapDocument.SpecialTile.NONE)
	assert_eq(state.wall, ArenaMapDocument.WallType.NONE)
	assert_false(document.set_layer(cell, ArenaMapDocument.EditLayer.WALL, ArenaMapDocument.WallType.BASE))


func test_exemple_reference_charge_tous_les_types_de_contenu() -> void:
	var document := ArenaMapSerializer.load_json(EXAMPLE_PATH)
	assert_not_null(document)
	assert_eq(document.validation_errors(), PackedStringArray())
	assert_eq(document.map_id, "reference_arena")
	assert_eq(document.map_kind, "reference")
	assert_eq(document.theme_id, "ancient_forest")
	var counts := document.counts()
	assert_eq(counts.total, 120)
	assert_eq(counts.active, 108)
	assert_eq(counts.void, 12)
	assert_eq(counts.surfaces, 6)
	assert_eq(counts.walls, 5)
	assert_eq(counts.specials, 7)


func test_json_round_trip_preserve_exactement_document_et_projection() -> void:
	var source := ArenaMapSerializer.load_json(EXAMPLE_PATH)
	assert_eq(ArenaMapSerializer.save_json(source, TEST_MAP_PATH), OK)
	var restored := ArenaMapSerializer.load_json(TEST_MAP_PATH)
	assert_not_null(restored)
	assert_eq(restored.to_dict(), source.to_dict())
	assert_eq(restored.to_dict().projection.tile_width, 64)
	assert_eq(restored.to_dict().projection.tile_height, 32)
	var absolute := ProjectSettings.globalize_path(TEST_MAP_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_canvas_reutilise_isogridview_et_rend_chaque_couche() -> void:
	var document := ArenaMapSerializer.load_json(EXAMPLE_PATH)
	var canvas := CANVAS_SCENE.instantiate() as ArenaMapCanvas
	add_child_autofree(canvas)
	canvas.configure(document)
	assert_same(canvas.document, document)
	assert_eq(canvas.grid.cols, 12)
	assert_eq(canvas.grid.rows, 10)
	assert_eq(canvas.floor_layer.get_child_count(), 103)
	assert_eq(canvas.surface_layer.get_child_count(), 6)
	assert_eq(canvas.marker_layer.get_child_count(), 7)
	var wall_count := 0
	for cell in document.all_cells():
		for node in canvas._cell_visuals.get(cell, []):
			if node is ArenaEditorWallPreview:
				wall_count += 1
	assert_eq(wall_count, 5)
	for cell in document.all_cells():
		assert_eq(canvas.local_to_cell(canvas.cell_to_local(cell)), cell)


func test_canvas_modes_reference_logic_debug_et_grille() -> void:
	var canvas := CANVAS_SCENE.instantiate() as ArenaMapCanvas
	add_child_autofree(canvas)
	canvas.configure(ArenaMapSerializer.load_json(EXAMPLE_PATH))
	canvas.set_display_mode(ArenaMapCanvas.DisplayMode.REFERENCE)
	assert_false(canvas.grid_view.visible)
	assert_true(canvas.floor_layer.visible)
	canvas.set_display_mode(ArenaMapCanvas.DisplayMode.LOGIC)
	assert_false(canvas.floor_layer.visible)
	assert_false(canvas.grid_view.visible)
	canvas.set_display_mode(ArenaMapCanvas.DisplayMode.DEBUG)
	assert_true(canvas.floor_layer.visible)
	assert_true(canvas.grid_view.visible)
	assert_true(canvas.grid_view.draw_cell_centers)


func test_editeur_expose_tous_les_outils_et_undo_redo() -> void:
	var editor := EDITOR_SCENE.instantiate() as ArenaMapEditor
	add_child_autofree(editor)
	for path in [
		"ArenaMapCanvas", "Camera2D", "UI/LeftPanel", "UI/RightPanel",
		"UI/TopBar", "UI/SaveDialog", "UI/OpenDialog",
	]:
		assert_not_null(editor.get_node_or_null(path), path)
	var status_bar := editor.get_node("UI/StatusBar") as Control
	assert_almost_eq(status_bar.anchor_top, 1.0, 0.001)
	assert_almost_eq(status_bar.anchor_bottom, 1.0, 0.001)
	assert_false(editor.save_dialog.visible)
	assert_false(editor.open_dialog.visible)
	assert_true(editor.width_spin.allow_greater)
	assert_true(editor.height_spin.allow_greater)
	var cell := Vector2i(5, 5)
	var previous: int = int(editor.document.get_cell(cell).base)
	editor.current_layer = ArenaMapDocument.EditLayer.BASE
	editor.current_value = ArenaMapDocument.BaseTile.VOID
	editor._on_stroke_started()
	editor._on_paint_requested(cell, false)
	editor._on_stroke_finished()
	assert_eq(editor.document.get_cell(cell).base, ArenaMapDocument.BaseTile.VOID)
	editor.undo()
	assert_eq(editor.document.get_cell(cell).base, previous)
	editor.redo()
	assert_eq(editor.document.get_cell(cell).base, ArenaMapDocument.BaseTile.VOID)


func test_brief_nano_banana_protege_la_geometrie_logique() -> void:
	var document := ArenaMapSerializer.load_json(EXAMPLE_PATH)
	var brief := ArenaMapSerializer.build_nano_banana_brief(document)
	for contract in [
		"Projection isometrique 64 x 32", "Ne pas modifier la silhouette",
		"cellules VOID", "murs, spawns, objectifs", "map_logic.png",
		"map_reference.png",
	]:
		assert_true(contract in brief, contract)
	assert_eq(ArenaMapExporter.EXPORT_SIZE, Vector2i(1920, 1080))


func test_scene_de_production_et_dynamic_arena_ne_sont_pas_remplaces() -> void:
	var first_room := load("res://data/rooms/first_run_room_01.tres") as RoomData
	assert_eq(first_room.battle_scene.resource_path, "res://data/rooms/maps/painted_battle.tscn")
	assert_true(FileAccess.file_exists("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn"))
	assert_true(FileAccess.file_exists("res://tools/arena_map_editor/ArenaMapEditor.tscn"))
