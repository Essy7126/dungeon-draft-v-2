extends "res://tools/catabase_run_balance_validation/cards_ui_probe.gd"
## Extra descriptive measurements; functional assertions remain in parent probe.
var ui_observations: Array[Dictionary] = []


func _capture(label: String, viewport_size: Vector2i, controls: Array) -> void:
	await super._capture(label, viewport_size, controls)
	var row := {"screen": label, "viewport": [viewport_size.x, viewport_size.y], "buttons": [], "clipped_buttons": [], "labels": []}
	_collect_ui(self, Rect2(Vector2.ZERO, Vector2(viewport_size)), row)
	# PersistentRunUI lives beside the scene probe, not below it.
	if label.begins_with("cards_combat") and not controls.is_empty() and not is_ancestor_of(controls[0]):
		var hud: Node = controls[0]
		while hud.get_parent() != null and not hud is CanvasLayer: hud = hud.get_parent()
		_collect_ui(hud, Rect2(Vector2.ZERO, Vector2(viewport_size)), row)
	if label.begins_with("cards_combat") and not controls.is_empty():
		var rect: Rect2 = controls[0].get_global_rect()
		row["hand_area_fraction"] = rect.get_area() / (viewport_size.x * viewport_size.y)
		row["hand_rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		_check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(rect), "card dock remains entirely inside the viewport", viewport_size)
		if label != "cards_combat_objects":
			_check(rect.size.y <= 182.0, "long spell names do not inflate the compact hand", viewport_size)
		for button in row.buttons:
			if not str(button.name).begins_with("Play_"): continue
			var button_rect := Rect2(button.rect[0], button.rect[1], button.rect[2], button.rect[3])
			_check(rect.encloses(button_rect), "spell action remains inside the card dock", viewport_size)
	if label == "cards_combat_six":
		# GPU readback, PNG encoding and screenshot analysis contaminate the
		# last Performance.TIME_PROCESS sample. Do not turn it into fake p95s.
		await get_tree().create_timer(1.2).timeout
		var samples: Array[float] = []
		var previous_frame := Time.get_ticks_usec()
		for frame in 120:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous_frame) / 1000.0)
			previous_frame = now
		samples.sort()
		row["performance"] = {"samples": samples.size(), "render_interval_ms_median": samples[60], "render_interval_ms_p95": samples[114], "render_interval_ms_max": samples[-1], "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "scope": "wall-clock cadence between 120 rendered frames after screenshot settling; stationary local offscreen renderer, not a GPU-only or full-combat benchmark"}
	ui_observations.append(row)
	var file := FileAccess.open(_output_root.path_join("ui_observations.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(ui_observations, "\t"))
	file.close()


func _collect_ui(node: Node, clip: Rect2, row: Dictionary) -> void:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree(): return
		var rect := control.get_global_rect()
		if control.clip_contents: clip = clip.intersection(rect)
		if node is Button and clip.intersects(rect) and (not (node as Button).text.is_empty() or str(node.name).begins_with("Play_")):
			var button := node as Button
			var font := button.get_theme_font("font")
			var size := button.get_theme_font_size("font_size")
			var style := button.get_theme_stylebox("normal")
			var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var room := rect.size.x - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
			if button.icon != null: room -= button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")
			var info := {"name": str(button.name), "text": button.text, "font_size": size, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "disabled": button.disabled}
			row.buttons.append(info)
			if button.clip_text and width > room: row.clipped_buttons.append(info)
		if node is Label and clip.intersects(rect):
			row.labels.append({"text": (node as Label).text, "font_size": control.get_theme_font_size("font_size"), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	for child in node.get_children(): _collect_ui(child, clip, row)
