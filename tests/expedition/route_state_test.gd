extends SceneTree

## Run: godot --headless --path . --script res://tests/expedition/route_state_test.gd
const RouteState = preload("res://core/expedition/expedition_route_state.gd")
const RouteCatalog = preload("res://core/expedition/expedition_route_catalog.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _path_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_determinism_and_graph()
	_test_lane_junctions()
	_test_legacy_snapshot()
	_test_transitions_and_isolation()
	_test_knowledge()
	_test_snapshot_round_trips()
	_test_snapshot_rejections()
	print("Expedition route: %d checks, %d complete paths, %d failures" % [
		_checks, _path_count, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_determinism_and_graph() -> void:
	var fingerprints: Dictionary = {}
	for seed_value in 8:
		var state := RouteState.new()
		state.initialize(seed_value)
		var same := RouteState.new()
		same.initialize(seed_value)
		_check(state.nodes == same.nodes, "Same seed changed catalogue %d" % seed_value)
		_check(state.nodes.size() == 55, "Expected 53 main nodes and 2 secrets")
		_check(state.get_visible_nodes().size() == 53, "Secrets leaked in initial graph")
		fingerprints[state.to_snapshot()["graph_fingerprint"]] = true
		var by_id: Dictionary = {}
		for node in state.nodes:
			var node_id := String(node["id"])
			_check(not by_id.has(node_id), "Duplicate destination %s" % node_id)
			by_id[node_id] = node
			var is_combat: bool = RouteCatalog.is_combat(String(node["kind"]))
			_check(int(node["room_index"]) in range(15) if is_combat else int(node["room_index"]) == -1,
				"Invalid combat room mapping %s" % node_id)
		var reached: Dictionary = {}
		for node in state.nodes:
			for edge in node["edges"]:
				_check(by_id.has(edge), "Unknown edge %s" % edge)
				_check(int(by_id[edge]["depth"]) == int(node["depth"]) + 1,
					"Edge skips a depth or creates a cycle")
			if int(node["depth"]) == 1:
				_walk_paths(node, by_id, 0, 0, reached)
		_check(reached.size() == state.nodes.size(), "Unreachable catalogue destination")
	_check(fingerprints.size() > 1, "Seeds do not vary the expedition")


func _test_lane_junctions() -> void:
	for seed_value in 32:
		var state := RouteState.new()
		state.initialize(seed_value)
		var widths := {}
		for node in state.nodes:
			if not bool(node.hidden):
				widths[int(node.depth)] = int(widths.get(int(node.depth), 0)) + 1
		_check(widths.values().has(3) and widths.values().has(4), "Missing wider forks")
		_check(widths[7] == 1 and widths[15] == 1, "Missing common trials")
		_resolve_first(state)
		var before := state.to_snapshot()
		var halts := {}
		for option in state.get_available_nodes():
			var preview := state.get_choice_preview(str(option.id))
			_check(preview.accessible_halts.size() == 1, "First choice must gate one different halt")
			_check(preview.foregone_halts.size() == 2, "First choice must forgo two other halt types")
			_check(preview.join_depth == 7, "First section rejoins at bronze trial")
			halts[str(preview.accessible_halts[0])] = true
			_check(not preview.path_ids.has("d08_secret"), "Preview leaked undiscovered passage")
		_check(halts.size() == 3, "First choices have identical services")
		_check(state.to_snapshot() == before, "Inspection mutated route")
		_check(state.get_choice_preview("d20_0").is_empty(), "Unavailable node has commitment preview")
		var choices := state.get_available_nodes()
		state.choose_node(str(choices[0].id))
		state.mark_combat_won()
		state.complete_current_node()
		_check(not state.choose_node(str(choices[1].id)), "Can switch to a discarded path")
		# Every pair of neighboring edges preserves lane order: no crossing ladders.
		var by_id := {}
		for node in state.nodes:
			by_id[str(node.id)] = node
		for node in state.nodes:
			if node.hidden:
				continue
			for other in state.nodes:
				if other.hidden or node.depth != other.depth or node.lane >= other.lane:
					continue
				for edge in node.edges:
					for other_edge in other.edges:
						if not by_id[edge].hidden and not by_id[other_edge].hidden:
							_check(by_id[edge].lane <= by_id[other_edge].lane, "Crossed neighboring paths")


func _test_legacy_snapshot() -> void:
	for revision in [2, 3]:
		var legacy := RouteState.new()
		legacy.initialize(2401, revision)
		_check(legacy.to_snapshot().catalog_revision == revision, "Legacy revision lost")
		for depth in 20:
			_round_trip(legacy)
			_resolve_first(legacy)
		_round_trip(legacy)
		var current := RouteState.new()
		current.initialize(2401)
		_check(current.to_snapshot().catalog_revision == 4, "New run does not use itineraries")
		var bad := legacy.to_snapshot()
		bad.catalog_revision = 4
		_check(not current.restore_snapshot(bad), "Legacy graph silently changed topology")


func _walk_paths(node: Dictionary, by_id: Dictionary, length: int, combats: int,
		reached: Dictionary) -> void:
	reached[node["id"]] = true
	length += 1
	combats += 1 if RouteCatalog.is_combat(String(node["kind"])) else 0
	if node["edges"].is_empty():
		_path_count += 1
		_check(length == 20, "A path does not resolve exactly 20 destinations")
		_check(combats >= 14 and combats <= 16, "A path violates its 14–16 combat budget")
		_check(node["kind"] == "boss", "A path terminates before the boss")
		return
	for next_id in node["edges"]:
		_walk_paths(by_id[next_id], by_id, length, combats, reached)


func _test_transitions_and_isolation() -> void:
	var state := RouteState.new()
	state.initialize(101)
	var initial := state.to_snapshot()
	_check(not state.choose_node("d20_0"), "Allowed jumping directly to boss")
	_check(not state.choose_node("missing"), "Allowed unknown destination")
	_check(not state.complete_current_node(), "Completed without active reward")
	_check(not state.mark_combat_won(), "Won combat while on map")
	_check(state.to_snapshot() == initial, "Invalid actions mutated route")
	# UI/caller edits cannot alter the authoritative catalogue.
	state.nodes[0]["edges"].clear()
	var available: Array[Dictionary] = state.get_available_nodes()
	available[0]["edges"].clear()
	_check(not state.get_available_nodes()[0]["edges"].is_empty(), "Preview mutation changed graph")
	for depth in range(1, 21):
		available = state.get_available_nodes()
		_check(not available.is_empty(), "Route softlocked at depth %d" % depth)
		if available.is_empty():
			break
		_check(state.choose_node(String(available[0]["id"])), "Rejected accessible destination")
		_check(not state.choose_node(String(available[0]["id"])), "Engaged a node twice")
		_check(state.get_available_nodes().is_empty(), "Offered route during pending node")
		if state.phase == "combat":
			_check(not state.complete_current_node(), "Completed combat before victory")
			_check(state.mark_combat_won(), "Victory was not accepted")
			_check(not state.mark_combat_won(), "Victory was accepted twice")
		_check(state.complete_current_node(), "Reward did not finish node")
		var completed := state.to_snapshot()
		_check(not state.complete_current_node(), "Completed reward twice")
		_check(state.to_snapshot() == completed, "Double completion mutated route")
	_check(state.phase == "complete", "Boss completion did not finish run")
	_check(state.completed_node_ids.size() == 20, "Wrong number of resolved destinations")
	_check(state.get_available_nodes().is_empty(), "Available destinations after completion")


func _test_knowledge() -> void:
	var state := RouteState.new()
	state.initialize(204)
	var visible: Array[Dictionary] = state.get_visible_nodes()
	for node in visible:
		_check(not bool(node["hidden"]), "Undiscovered secret displayed")
		for edge in node["edges"]:
			_check(not String(edge).contains("secret"), "Secret connection displayed before discovery")
		if int(node["depth"]) > 2:
			_check(node["reward"] == "unknown", "Future reward family leaked")
		_check(not node.has("service_profile"), "Hidden service profile leaked")
		_check(node["room_index"] == -1, "Unvisited room content leaked")
	_check(state.reveal_next_hidden_node() == "d08_secret", "Wrong next secret discovered")
	_check(not state.reveal_hidden_node("d08_secret"), "Secret discovered twice")
	_check(not state.reveal_hidden_node("d01_0"), "Ordinary node accepted as secret")
	_check(state.get_visible_nodes().size() == 54, "Discovered secret absent from map")
	for depth in range(1, 8):
		_resolve_first(state)
	var found_secret := false
	for node in state.get_available_nodes():
		if node["id"] == "d08_secret":
			found_secret = true
	_check(found_secret, "Discovered secret not reachable from its previous depth")
	_check(state.choose_node("d08_secret"), "Cannot visit a revealed secret")
	_check(state.phase == "reward", "Secret cache incorrectly entered combat")
	_check(state.complete_current_node(), "Cannot finish secret")
	_check(state.completed_node_ids.size() == 8, "Secret added an extra step")
	_check(not state.reveal_hidden_node("d08_secret"), "Past secret rediscovery accepted")
	var unknown_test := RouteState.new()
	unknown_test.initialize(204)
	for depth in 4:
		_resolve_first(unknown_test)
	var unknown_id := ""
	for node in unknown_test.get_visible_nodes():
		if int(node["depth"]) == 6 and bool(node["uncertain"]):
			unknown_id = String(node["id"])
			_check(node["kind"] == "unknown", "Unknown encounter's real function leaked")
			_check(node["reward"] != "unknown", "Near unknown lost its promised reward family")
			_check(String(node["hint"]).contains("combat"), "Unknown did not advertise combat risk")
	_check(not unknown_id.is_empty(), "No unknown encounter in catalogue")
	# The source content must not be rerolled by inspection or discovery.
	var actual: Array[Dictionary] = unknown_test.nodes.duplicate(true)
	for index in 4:
		unknown_test.get_visible_nodes()
		unknown_test.get_available_nodes()
	_check(actual == unknown_test.nodes, "Inspection rerolled hidden content")


func _test_snapshot_round_trips() -> void:
	var state := RouteState.new()
	state.initialize(481)
	state.reveal_next_hidden_node()
	_round_trip(state)
	for depth in 20:
		var available: Array[Dictionary] = state.get_available_nodes()
		_check(state.choose_node(String(available.back()["id"])), "Roundtrip path cannot advance")
		_round_trip(state)
		if state.phase == "combat":
			state.mark_combat_won()
			_round_trip(state)
		state.complete_current_node()
		_round_trip(state)
	_check(state.phase == "complete", "Roundtrip traversal unfinished")


func _round_trip(state: RefCounted) -> void:
	var restored := RouteState.new()
	restored.initialize(999)
	# JSON deliberately converts integral numbers to floating point Variants.
	var parsed: Variant = JSON.parse_string(JSON.stringify(state.to_snapshot()))
	_check(parsed is Dictionary, "Snapshot did not serialize as JSON object")
	_check(restored.restore_snapshot(parsed), "Valid snapshot rejected: %s" % restored.last_restore_error)
	_check(restored.to_snapshot() == state.to_snapshot(), "Snapshot did not restore exact state")
	_check(restored.get_visible_nodes() == state.get_visible_nodes(), "Snapshot changed acquired knowledge")
	_check(restored.get_available_nodes() == state.get_available_nodes(), "Snapshot changed legal routes")


func _test_snapshot_rejections() -> void:
	var state := RouteState.new()
	state.initialize(617)
	_resolve_first(state)
	var valid := state.to_snapshot()
	var invalid: Array[Dictionary] = []
	for key in ["version", "catalog_revision", "seed", "phase", "current_node_id", "completed_node_ids", "revealed_node_ids"]:
		var missing := valid.duplicate(true)
		missing.erase(key)
		invalid.append(missing)
	for entry in [
		["version", 999], ["seed", -1], ["seed", 12.5], ["seed", "617"],
		["graph_fingerprint", "altered"], ["phase", "complete"], ["phase", "combat"],
		["current_node_id", "d20_0"], ["completed_node_ids", ["d01_0", "d20_0"]],
		["completed_node_ids", ["d01_0", "d01_0"]], ["revealed_node_ids", ["d01_0"]],
		["revealed_node_ids", ["d08_secret", "d08_secret"]], ["revealed_node_ids", [7]],
	]:
		var tampered := valid.duplicate(true)
		tampered[entry[0]] = entry[1]
		invalid.append(tampered)
	for snapshot in invalid:
		_check(not state.restore_snapshot(snapshot), "Accepted corrupt snapshot %s" % JSON.stringify(snapshot))
		_check(state.to_snapshot() == valid, "Rejected snapshot partially replaced live run")
		_check(not state.last_restore_error.is_empty(), "Rejected snapshot has no diagnostic")
	# A valid secret path cannot load without its discovery; stale revealed state is not inferred.
	var secret := RouteState.new()
	secret.initialize(100)
	secret.reveal_next_hidden_node()
	for depth in 7:
		_resolve_first(secret)
	secret.choose_node("d08_secret")
	secret.complete_current_node()
	var secret_snapshot := secret.to_snapshot()
	secret_snapshot["revealed_node_ids"] = []
	_check(not state.restore_snapshot(secret_snapshot), "Secret path loaded without discovery")
	_check(state.to_snapshot() == valid, "Rejected secret snapshot mutated existing run")


func _resolve_first(state: RefCounted) -> void:
	var available: Array[Dictionary] = state.get_available_nodes()
	_check(not available.is_empty(), "No next destination in helper")
	if available.is_empty():
		return
	_check(state.choose_node(String(available[0]["id"])), "Helper destination rejected")
	if state.phase == "combat":
		state.mark_combat_won()
	_check(state.complete_current_node(), "Helper failed to complete reward")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
