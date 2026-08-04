class_name ArenaMapExporter
extends RefCounted

const CANVAS_SCENE := preload("res://tools/arena_map_editor/ArenaMapCanvas.tscn")
const EXPORT_SIZE := Vector2i(1920, 1080)


func export_pack(host: Node, document: ArenaMapDocument, export_dir := "") -> Dictionary:
	if host == null or document == null:
		return {"ok": false, "error": "Document ou hote absent."}
	if not document.validation_errors().is_empty():
		return {"ok": false, "error": "Document invalide."}
	if export_dir.is_empty():
		export_dir = ArenaMapSerializer.suggested_export_dir(document)
	var metadata_error := ArenaMapSerializer.save_export_metadata(document, export_dir)
	if metadata_error != OK:
		return {"ok": false, "error": error_string(metadata_error)}

	var viewport := SubViewport.new()
	viewport.name = "ArenaMapExportViewport"
	viewport.size = EXPORT_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	host.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("101722")
	background.size = Vector2(EXPORT_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)

	var canvas := CANVAS_SCENE.instantiate() as ArenaMapCanvas
	viewport.add_child(canvas)
	await host.get_tree().process_frame
	var clone := ArenaMapDocument.new(Vector2i.ONE)
	clone.load_from_dict(document.snapshot())
	canvas.configure(clone)
	canvas.editor_input_enabled = false
	await host.get_tree().process_frame
	_fit_canvas(canvas)

	var outputs := {}
	var error := await _capture_mode(
		host, viewport, canvas, ArenaMapCanvas.DisplayMode.REFERENCE,
		export_dir.path_join("map_reference.png"), true
	)
	outputs["reference"] = error
	error = await _capture_mode(
		host, viewport, canvas, ArenaMapCanvas.DisplayMode.REFERENCE,
		export_dir.path_join("map_clean.png"), false
	)
	outputs["clean"] = error
	error = await _capture_mode(
		host, viewport, canvas, ArenaMapCanvas.DisplayMode.LOGIC,
		export_dir.path_join("map_logic.png"), true
	)
	outputs["logic"] = error
	error = await _capture_mode(
		host, viewport, canvas, ArenaMapCanvas.DisplayMode.DEBUG,
		export_dir.path_join("map_debug.png"), true
	)
	outputs["debug"] = error

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.remove_child(viewport)
	viewport.free()
	var all_ok := outputs.values().all(func(value): return value == OK)
	return {
		"ok": all_ok,
		"directory": export_dir,
		"outputs": outputs,
		"error": "" if all_ok else "Au moins une image n'a pas pu etre exportee.",
	}


func _fit_canvas(canvas: ArenaMapCanvas) -> void:
	var bounds := canvas.get_map_bounds().grow(120.0)
	var available := Vector2(1640, 820)
	var fit := minf(available.x / maxf(bounds.size.x, 1.0), available.y / maxf(bounds.size.y, 1.0))
	fit = minf(fit, 2.2)
	canvas.scale = Vector2.ONE * fit
	canvas.position = Vector2(EXPORT_SIZE) * 0.5 - bounds.get_center() * fit + Vector2(0, 36)


func _capture_mode(
		host: Node,
		viewport: SubViewport,
		canvas: ArenaMapCanvas,
		mode: int,
		path: String,
		show_markers: bool
	) -> Error:
	canvas.set_display_mode(mode)
	canvas.set_special_markers_visible(show_markers)
	for _frame in range(3):
		await host.get_tree().process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(ProjectSettings.globalize_path(path))
