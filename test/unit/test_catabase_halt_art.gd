extends GutTest
## Real route generation and interactive service controls; no media or save writes.

const ART := preload("res://ui/expedition/catabase_halt_art_catalog.gd")
const HUB := preload("res://ui/expedition/catabase_hub_canvas.gd")
const ROUTES := preload("res://core/expedition/expedition_route_catalog.gd")
const ROUTE_STATE := preload("res://core/expedition/expedition_route_state.gd")


func test_all_seventeen_destinations_resolve_across_seeded_lane_swaps_and_variants() -> void:
	assert_eq(ART.all_keys().size(), 17)
	var seen := {}
	var camp_ids := {}
	for seed_value in range(64):
		for destination in ROUTES.create_nodes(seed_value):
			var key := ART.resolve_key(destination)
			if ROUTES.is_halt(str(destination.kind)):
				assert_false(key.is_empty(), str(destination.title))
				if key.is_empty():
					continue
				seen[key] = true
				assert_eq(str(ART.DESTINATIONS[key].title), str(destination.title))
				assert_eq(ART.texture_path(key), "res://assets/catabase/painted/halts/%s.png" % key)
				if key == "camp_compagnons":
					camp_ids[str(destination.id)] = true
			else:
				assert_eq(key, "", "Combat variants cannot display the corresponding halt")
	assert_eq(seen.size(), 17, "Both secret destinations and the conditional sanctuary are covered")
	assert_gt(camp_ids.size(), 1, "Stable art survives real lane inversions")


func test_metadata_can_rename_a_halt_but_cannot_expose_unknown_or_combat_content() -> void:
	var destination := {"halt_art_key": "camp_compagnons", "title": "Titre localisé", "kind": "hub"}
	assert_eq(ART.resolve_key(destination), "camp_compagnons")
	for field in ["kind", "presentation_kind", "knowledge"]:
		var unknown := destination.duplicate(true)
		unknown[field] = "unknown"
		assert_eq(ART.resolve_key(unknown), "", "Unknown preview masks even explicit art metadata")
	destination.kind = "normal"
	assert_eq(ART.resolve_key(destination), "")
	destination.kind = "merchant"
	assert_eq(ART.resolve_key(destination), "", "Metadata cannot substitute a different service layout")
	assert_eq(ART.resolve_key({"halt_art_key": "../../private", "title": "Unknown"}), "")
	assert_eq(ART.texture_path("../../private"), "")
	assert_null(ART.load_texture("../../private"))


func test_resolving_safe_previews_preserves_route_snapshots_and_hidden_destinations() -> void:
	for seed_value in [0, 1, 42, 2026]:
		var route := ROUTE_STATE.new()
		route.initialize(seed_value)
		var before := route.to_snapshot().duplicate(true)
		for preview in route.get_visible_nodes():
			var preview_before := preview.duplicate(true)
			var key := ART.resolve_key(preview)
			assert_eq(preview, preview_before)
			assert_false(bool(preview.hidden), "Unrevealed secret has no presentation node")
			if str(preview.kind) == "unknown":
				assert_eq(key, "")
		assert_eq(route.to_snapshot(), before, "Presentation does not change graph, receipt or save state")
		var restored := ROUTE_STATE.new()
		assert_true(restored.restore_snapshot(before))
		assert_eq(restored.to_snapshot(), before)


func test_service_anchors_follow_the_transaction_role_when_services_are_reordered() -> void:
	var hub := HUB.new()
	add_child_autofree(hub)
	hub.size = Vector2(580, 420)
	var services := _services(["lore", "branch:elements", "rest", "buy:levier"])
	var before := services.duplicate(true)
	hub.configure("Le camp des compagnons", services, "rest")
	await wait_process_frames(2)
	_assert_anchor(hub, "buy:levier", Vector2(0.31, (0.44 * 1288.1 - 44.0) / 1200.0))
	_assert_anchor(hub, "rest", Vector2(0.28, (0.72 * 1288.1 - 44.0) / 1200.0))
	_assert_anchor(hub, "lore", Vector2(0.79, (0.46 * 1288.1 - 44.0) / 1200.0))
	_assert_anchor(hub, "branch:elements", Vector2(0.78, (0.74 * 1288.1 - 44.0) / 1200.0))
	for first in hub._buttons:
		for second in hub._buttons:
			if first != second:
				assert_false(first.get_rect().intersects(second.get_rect()), "Camp services remain separately clickable")
	assert_eq(services, before, "Visual configuration never changes transaction availability or costs")
	hub.configure("Le camp des compagnons", _services(["wager", "rest", "lore", "buy:levier"]), "wager")
	_assert_anchor(hub, "wager", Vector2(0.78, (0.74 * 1288.1 - 44.0) / 1200.0))


func test_merchant_has_three_distinct_purchase_anchors_and_shared_letterbox_transform() -> void:
	var hub := HUB.new()
	add_child_autofree(hub)
	hub.configure("L'étal du passeur", _services(["rest", "buy:a", "lore", "buy:b", "buy:c"]), "")
	for available_size in [Vector2(580, 420), Vector2(1400, 420), Vector2(580, 800), Vector2(1920, 1200)]:
		hub.size = available_size
		hub._layout()
		await wait_process_frames(2)
		var rect := hub.get_art_rect()
		assert_almost_eq(rect.size.x / rect.size.y, 1.6, 0.00001)
		assert_almost_eq(rect.get_center().x, hub.size.x * 0.5, 0.00001)
		assert_almost_eq(rect.get_center().y, hub.size.y * 0.5, 0.00001)
		_assert_anchor(hub, "buy:a", Vector2(0.18, 0.46))
		_assert_anchor(hub, "buy:b", Vector2(0.43, 0.40))
		_assert_anchor(hub, "buy:c", Vector2(0.70, 0.46))
		_assert_anchor(hub, "rest", Vector2(0.29, 0.78))
		_assert_anchor(hub, "lore", Vector2(0.76, 0.80))
		for first in hub._buttons:
			assert_true(Rect2(Vector2.ZERO, hub.size).encloses(first.get_rect()))
			for second in hub._buttons:
				if first != second:
					assert_false(first.get_rect().intersects(second.get_rect()), "Merchant offers remain separately clickable")


func test_reconfiguration_replaces_old_controls_and_emits_only_the_current_service() -> void:
	var hub := HUB.new()
	add_child_autofree(hub)
	hub.size = Vector2(800, 600)
	hub.configure("L'étal du passeur", _services(["buy:old_a", "buy:old_b", "buy:old_c", "rest", "lore"]), "")
	var previous: Array = hub._buttons.duplicate()
	previous.append_array(hub._labels)
	hub.configure("Le camp des compagnons", _services(["buy:new", "rest", "lore", "branch:serment"]), "lore")
	assert_eq(hub.get_child_count(), 8)
	assert_eq(hub._buttons.size(), 4)
	assert_eq(hub._labels.size(), 4)
	assert_eq(hub.get_art_key(), "camp_compagnons")
	for old_button in previous:
		assert_false(is_instance_valid(old_button))
	var emitted: Array[String] = []
	hub.zone_selected.connect(func(service_id: String): emitted.append(service_id))
	for button in hub._buttons:
		button.pressed.emit()
	assert_eq(emitted, ["buy:new", "rest", "lore", "branch:serment"])
	hub._labels[2].pressed.emit()
	assert_eq(emitted[-1], "lore", "The discreet label selects the same transaction as the ring")
	assert_eq(hub.resized.get_connections().size(), 1, "Refresh cannot multiply the layout callback")
	assert_eq(hub._selected, "lore")


func test_optional_art_status_distinguishes_missing_known_paintings_and_unmapped_nodes() -> void:
	var hub := HUB.new()
	add_child_autofree(hub)
	hub.size = Vector2(800, 600)
	for key in ART.all_keys():
		var definition: Dictionary = ART.DESTINATIONS[key]
		hub.configure(str(definition.title), _services(["rest", "lore"]), "", definition)
		assert_eq(hub.get_art_key(), key)
		var texture := ART.load_texture(key)
		assert_eq(hub.get_art_status(), "ready" if texture != null else "pending")
		assert_same(hub._art_texture, texture)
	hub.configure("Destination inconnue", _services([]), "", {"kind": "unknown"})
	assert_eq(hub.get_art_key(), "")
	assert_eq(hub.get_art_status(), "unmapped")
	assert_null(hub._art_texture, "Previous painting must not survive an unknown destination")


func test_measured_library_and_camp_labels_leave_their_painted_targets_visible() -> void:
	var hub := HUB.new()
	add_child_autofree(hub)
	var expected_labels := {
		"camp_compagnons": {"buy:x": Vector2(0.31, 0.60), "rest": Vector2(0.28, 0.87), "lore": Vector2(0.79, 0.62), "branch:elements": Vector2(0.78, 0.89)},
		"bibliotheque_engloutie": {"buy:x": Vector2(0.15, 0.72), "rest": Vector2(0.42, 0.90), "lore": Vector2(0.34, 0.55), "branch:elements": Vector2(0.72, 0.64)},
	}
	for key in expected_labels:
		for available_size in [Vector2(580, 420), Vector2(1200, 740)]:
			hub.size = available_size
			var definition: Dictionary = ART.DESTINATIONS[key]
			hub.configure(str(definition.title), _services(["buy:x", "rest", "lore", "branch:elements"]), "rest", definition)
			await wait_process_frames(2)
			for label in hub._labels:
				var service_id := str(label.get_meta("service_id"))
				var expected: Vector2 = expected_labels[key][service_id]
				assert_eq(label.get_meta("art_anchor"), expected)
				assert_lt((label.position + label.size * 0.5).distance_to(hub.get_art_rect().position + hub.get_art_rect().size * expected), 0.001)
				assert_true(Rect2(Vector2.ZERO, hub.size).encloses(label.get_rect()))
				for target in hub._buttons:
					assert_false(label.get_rect().intersects(target.get_rect()), "Labels cannot cover an interactive painted object")
				for other in hub._labels:
					if label != other:
						assert_false(label.get_rect().intersects(other.get_rect()), "Labels remain separately readable at 580 px")
			if key == "bibliotheque_engloutie":
				_assert_anchor(hub, "buy:x", Vector2(0.15, 0.58))
				_assert_anchor(hub, "rest", Vector2(0.43, 0.77))
				_assert_anchor(hub, "lore", Vector2(0.33, 0.40))
				_assert_anchor(hub, "branch:elements", Vector2(0.70, 0.42))


func _services(ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ids:
		result.append({"id": str(id), "title": str(id), "description": "Transaction fixture", "cost": 45, "used": false})
	return result


func _assert_anchor(hub, service_id: String, normalized: Vector2) -> void:
	var found := false
	for button in hub._buttons:
		if str(button.get_meta("service_id")) != service_id:
			continue
		found = true
		assert_eq(button.get_meta("art_anchor"), normalized)
		var expected: Vector2 = hub.get_art_rect().position + hub.get_art_rect().size * normalized
		var actual: Vector2 = button.position + button.size * 0.5
		assert_lt(actual.distance_to(expected), 0.001, service_id + " stays attached to its painted object")
	assert_true(found, "Missing service " + service_id)
