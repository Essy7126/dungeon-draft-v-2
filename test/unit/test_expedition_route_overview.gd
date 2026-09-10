extends GutTest

const ROUTE_VIEW := preload("res://ui/expedition/expedition_route_view.gd")


func _session() -> ExpeditionSession:
	var session := ExpeditionSession.new()
	session.route.initialize(2401)
	session.route.choose_node("d01_0")
	session.route.mark_combat_won()
	session.route.complete_current_node()
	return session


func _settle() -> void:
	for frame in 6:
		await get_tree().process_frame


func test_full_map_inspection_preserves_progress_and_requires_explicit_confirmation() -> void:
	var session := _session()
	var view := ROUTE_VIEW.new()
	add_child_autofree(view)
	view.configure(session, "d02_0", false)
	await _settle()
	var before := session.route.to_snapshot()
	var commits: Array[String] = []
	view.destination_committed.connect(
		func(id: String):
			commits.append(id),
	)
	view.find_child("ExpandFullRoute", true, false).pressed.emit()
	await _settle()
	var overview := view.find_child("FullRouteOverview", true, false)
	assert_not_null(overview)
	if overview == null:
		return
	var canvas := overview.find_child("OverviewMapCanvas", true, false) as ExpeditionMapCanvas
	assert_eq(canvas._buttons.size(), 53, "All ordinary nodes visible, secrets excluded")
	assert_false(canvas._buttons.has("d08_secret"))
	canvas._on_pressed("d20_0")
	await _settle()
	assert_eq(view.get("_selected_node_id"), "d20_0")
	assert_true(view.find_child("CommitDestination", true, false).disabled)
	assert_eq(session.route.to_snapshot(), before)
	assert_true(commits.is_empty(), "Clicking the full map never starts travel")
	canvas._on_pressed("d02_1")
	overview.find_child("CloseFullRoute", true, false).pressed.emit()
	await _settle()
	assert_null(view.find_child("FullRouteOverview", true, false))
	assert_false(view.find_child("CommitDestination", true, false).disabled)
	assert_true(commits.is_empty())
	view.find_child("CommitDestination", true, false).pressed.emit()
	assert_eq(commits, ["d02_1"])


func test_overview_fits_twenty_depths_and_revealed_passages_without_overlapping() -> void:
	var session := _session()
	session.route.reveal_hidden_node("d08_secret")
	session.route.reveal_hidden_node("d16_secret")
	var canvas := ExpeditionMapCanvas.new()
	add_child_autofree(canvas)
	canvas.set_route(session.route)
	for dimensions in [Vector2(940, 626), Vector2(1580, 986)]:
		canvas.set_overview_height(dimensions.y)
		canvas.size = dimensions
		await _settle()
		assert_eq(canvas._rects.size(), 55)
		var bounds := Rect2(Vector2.ZERO, dimensions)
		for id in canvas._rects:
			var rect: Rect2 = canvas._rects[id]
			assert_true(bounds.encloses(rect), "Destination fits complete map: " + id)
			assert_true(
				bounds.encloses(canvas._buttons[id].get_rect()),
				"Actual click target fits: " + id,
			)
			for other in canvas._rects:
				if other > id:
					assert_false(
						rect.intersects(canvas._rects[other]),
						"Separate targets: %s / %s" % [id, other],
					)
		assert_eq(canvas._buttons["d18_0"].get_meta("presentation_kind"), "unknown", "Distant details stay concealed")


func test_combat_overview_stays_read_only_and_escape_only_closes_overview() -> void:
	var session := _session()
	session.route.choose_node("d02_0")
	var view := ROUTE_VIEW.new()
	add_child_autofree(view)
	view.configure(session, "d02_0", true)
	await _settle()
	var before := session.route.to_snapshot()
	view.find_child("ExpandFullRoute", true, false).pressed.emit()
	await _settle()
	var overview := view.find_child("FullRouteOverview", true, false)
	var canvas := overview.find_child("OverviewMapCanvas", true, false) as ExpeditionMapCanvas
	canvas._on_pressed("d03_0")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event)
	await _settle()
	assert_null(view.find_child("FullRouteOverview", true, false))
	assert_true(view.is_inside_tree())
	assert_true(view.find_child("CommitDestination", true, false).disabled)
	assert_eq(session.route.to_snapshot(), before)
