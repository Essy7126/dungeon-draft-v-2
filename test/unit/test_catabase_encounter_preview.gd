extends GutTest
## Player knowledge and real encounter agreement, independent of the route choice.
const PRESENTATION := preload("res://ui/expedition/expedition_encounter_preview.gd")
const ROUTE_VIEW := preload("res://ui/expedition/expedition_route_view.gd")


func _node(depth: int, reward: String, kind := "normal") -> Dictionary:
	return {"id": "preview_%d" % depth, "depth": depth, "reward": reward,
		"kind": kind, "knowledge": "near", "room_index": -1}


func test_known_preview_names_every_actual_enemy_and_technique_without_mutating_node() -> void:
	for fixture: Array in [[2, "ranged"], [6, "vitality"], [10, "ranged"], [18, "control"]]:
		var node := _node(int(fixture[0]), str(fixture[1]))
		var before := node.duplicate(true)
		var preview := PRESENTATION.describe(node)
		assert_false(preview.is_empty(), "Known combat exposes its formation")
		assert_eq(node, before, "Inspection preserves the saved choice")
		var resolved := node.duplicate(true)
		resolved.room_index = ExpeditionRouteCatalog.MAP_BY_DEPTH[int(node.depth)]
		var room := ExpeditionRunFactory.make_room(resolved, 2401)
		assert_eq(int(preview.get("count", 0)), room.enemies.size(), "Exact encounter count")
		assert_false(str(preview.get("summary", "")).is_empty(), "Threat explained")
		assert_false(str(preview.get("counterplay", "")).is_empty(), "An approach is explained")
		for data: UnitData in room.enemies:
			assert_string_contains(str(preview.get("details", "")), data.unit_name)
			assert_string_contains(str(preview.get("details", "")), "%d PV" % data.max_hp)
			assert_string_contains(str(preview.get("details", "")), "%d PM" % data.max_mp)
			for spell: Spell in data.spells:
				assert_string_contains(str(preview.get("details", "")), spell.spell_name)


func test_unknown_and_distant_nodes_never_disclose_composition_through_their_real_id() -> void:
	var node := _node(18, "control")
	for knowledge: String in ["unknown", "distant", ""]:
		node.knowledge = knowledge
		assert_true(PRESENTATION.describe(node).is_empty(), "No hidden encounter leakage")
	assert_true(PRESENTATION.describe({}).is_empty())
	node.erase("knowledge")
	assert_true(PRESENTATION.describe(node).is_empty(), "Missing knowledge fails closed")


func test_halts_and_protected_fights_do_not_gain_invented_monster_previews() -> void:
	for kind: String in ["hub", "merchant", "sanctuary", "lore", "unknown"]:
		assert_true(PRESENTATION.describe(_node(6, "armor", kind)).is_empty())
	for depth: int in [1, 7, 20]:
		assert_true(PRESENTATION.describe(_node(depth, "armor")).is_empty())


func test_inspecting_techniques_does_not_commit_or_modify_a_route() -> void:
	var session := ExpeditionSession.new()
	session.route.initialize(2401)
	assert_true(session.route.choose_node("d01_0"))
	assert_true(session.route.mark_combat_won())
	assert_true(session.route.complete_current_node())
	var view := ROUTE_VIEW.new()
	add_child_autofree(view)
	view.configure(session, "d02_0", false)
	var before := session.route.to_snapshot()
	var commits: Array = []
	view.destination_committed.connect(func(id: String): commits.append(id))
	view.call("_show_encounter_details")
	assert_eq(session.route.to_snapshot(), before, "Reading enemy moves cannot choose the room")
	assert_true(commits.is_empty())
	var details := view.find_child("EncounterTechniques", true, false) as RichTextLabel
	assert_not_null(details)
	assert_false(details.text.is_empty())


func test_selection_of_distant_node_clears_previous_details_and_disables_inspection() -> void:
	var session := ExpeditionSession.new()
	session.route.initialize(2401)
	assert_true(session.route.choose_node("d01_0"))
	assert_true(session.route.mark_combat_won())
	assert_true(session.route.complete_current_node())
	var view := ROUTE_VIEW.new()
	add_child_autofree(view)
	view.configure(session, "d02_0", false)
	assert_true((view.find_child("RouteEncounterPreview", true, false) as Control).visible)
	view.call("_on_destination_selected", "d18_0")
	assert_false((view.find_child("RouteEncounterPreview", true, false) as Control).visible)
	assert_true((view.find_child("InspectEncounter", true, false) as Button).disabled)
	assert_eq((view.find_child("EncounterTechniques", true, false) as RichTextLabel).text, "")
