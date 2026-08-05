@tool
class_name EncounterReferenceGraphService
extends RefCounted


static func build_for_run(run: RunData, run_path := "") -> Dictionary:
	var graph := {}
	if run == null:
		return graph
	for room_index in range(run.rooms.size()):
		var room := run.rooms[room_index]
		if room == null:
			continue
		if room.waves.is_empty():
			_append_usage(graph, room.encounter_definition, {
				"run_path": run_path,
				"room_path": room.resource_path,
				"room_index": room_index,
				"wave_index": 0,
				"mode": "historique",
			})
		else:
			for wave_index in range(room.waves.size()):
				var wave := room.waves[wave_index]
				_append_usage(graph, wave.encounter_definition if wave != null else null, {
					"run_path": run_path,
					"room_path": room.resource_path,
					"room_index": room_index,
					"wave_index": wave_index,
					"mode": "vagues",
				})
	return graph


static func build_project_graph() -> Dictionary:
	var graph := {}
	for run_path in StudioResourceCatalog.find_run_paths():
		var run := ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_REUSE) \
			as RunData
		var run_graph := build_for_run(run, run_path)
		for key in run_graph:
			if not graph.has(key):
				graph[key] = []
			(graph[key] as Array).append_array(run_graph[key])
	return graph


static func usages_for(encounter: EncounterDefinition, graph: Dictionary) -> Array:
	return (graph.get(key_for(encounter), []) as Array).duplicate(true)


static func summary_for(encounter: EncounterDefinition, graph: Dictionary) -> Dictionary:
	var usages := usages_for(encounter, graph)
	var rooms := {}
	for usage in usages:
		rooms["%s#%d" % [usage.get("run_path", ""), usage.get("room_index", -1)]] = true
	return {
		"key": key_for(encounter),
		"resource_path": encounter.resource_path if encounter != null else "",
		"usage_count": usages.size(),
		"room_count": rooms.size(),
		"external": encounter != null and not encounter.resource_path.is_empty(),
		"usages": usages,
	}


static func key_for(encounter: EncounterDefinition) -> String:
	if encounter == null:
		return "missing"
	if not encounter.resource_path.is_empty():
		return encounter.resource_path
	return "embedded:%d" % encounter.get_instance_id()


static func _append_usage(
		graph: Dictionary,
		encounter: EncounterDefinition,
		usage: Dictionary
	) -> void:
	if encounter == null:
		return
	var key := key_for(encounter)
	if not graph.has(key):
		graph[key] = []
	(graph[key] as Array).append(usage)
