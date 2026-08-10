@tool
class_name StudioReferenceGraphService
extends RefCounted

## Index transversal cache. Le scan est interruptible et le cache peut etre
## invalide par ressource sans reconstruire l'interface.

signal scan_started
signal scan_progress(completed: int, total: int, label: String)
signal scan_completed(report: Dictionary)
signal scan_cancelled(report: Dictionary)
signal invalidated(keys: PackedStringArray)

var generation := 0
var nodes := {}
var outgoing := {}
var incoming := {}
var scanned_at := ""
var last_duration_ms := 0.0
var last_memory_delta_bytes := 0
var last_object_delta := 0
var _cancel_requested := false
var _invalid_keys := {}


func scan(force := false) -> Dictionary:
	if not force and not nodes.is_empty() and _invalid_keys.is_empty():
		return report(true, true)
	var started_usec := Time.get_ticks_usec()
	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_cancel_requested = false
	scan_started.emit()
	var next_nodes := {}
	var next_outgoing := {}
	var next_incoming := {}
	var visited := {}
	var runs := RunContentCatalogService.discover_runs()
	var total := maxi(1, runs.size())
	for run_index in range(runs.size()):
		if _cancel_requested:
			var cancelled_report := report(false, false)
			cancelled_report["cancelled"] = true
			scan_cancelled.emit(cancelled_report)
			return cancelled_report
		var run_data := runs[run_index]
		var run_key := _record_resource(run_data, &"RUN", next_nodes)
		for room_index in range(run_data.rooms.size()):
			var room := run_data.rooms[room_index]
			if room == null:
				continue
			var room_key := _walk_resource(room, &"ROOM", next_nodes, next_outgoing, next_incoming, visited)
			_link(run_key, room_key, &"ROOM_AT", {"index": room_index}, next_outgoing, next_incoming)
		for hero_index in range(RunContentCatalogService.heroes_for_run(run_data).size()):
			var hero := RunContentCatalogService.heroes_for_run(run_data)[hero_index]
			if hero == null:
				continue
			var hero_key := _walk_resource(hero, &"RUN_HERO", next_nodes, next_outgoing, next_incoming, visited)
			_link(run_key, hero_key, &"HERO_AT", {"index": hero_index}, next_outgoing, next_incoming)
			scan_progress.emit(run_index + 1, total, run_data.run_name)
	nodes = next_nodes
	outgoing = next_outgoing
	incoming = next_incoming
	generation += 1
	scanned_at = Time.get_datetime_string_from_system(true)
	last_duration_ms = float(Time.get_ticks_usec() - started_usec) / 1000.0
	last_memory_delta_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC)) - memory_before
	last_object_delta = int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects_before
	_invalid_keys.clear()
	var result := report(true, false)
	scan_completed.emit(result)
	return result


func cancel() -> void:
	_cancel_requested = true


func invalidate(resource_or_path: Variant = null) -> void:
	var keys := PackedStringArray()
	if resource_or_path == null:
		for key in nodes:
			_invalid_keys[key] = true
			keys.append(str(key))
	elif resource_or_path is Resource:
		var key := resource_key(resource_or_path)
		_invalid_keys[key] = true
		keys.append(key)
	else:
		var key := str(resource_or_path)
		_invalid_keys[key] = true
		keys.append(key)
	invalidated.emit(keys)


func usages(resource_or_path: Variant) -> Array[Dictionary]:
	var key := resource_key(resource_or_path) if resource_or_path is Resource else str(resource_or_path)
	var result: Array[Dictionary] = []
	for edge_value in incoming.get(key, []):
		result.append((edge_value as Dictionary).duplicate(true))
	return result


func references_from(resource_or_path: Variant) -> Array[Dictionary]:
	var key := resource_key(resource_or_path) if resource_or_path is Resource else str(resource_or_path)
	var result: Array[Dictionary] = []
	for edge_value in outgoing.get(key, []):
		result.append((edge_value as Dictionary).duplicate(true))
	return result


func is_shared(resource_or_path: Variant) -> bool:
	var run_paths := {}
	var frontier := []
	var seen := {}
	var key := resource_key(resource_or_path) if resource_or_path is Resource else str(resource_or_path)
	frontier.append(key)
	while not frontier.is_empty():
		var current := str(frontier.pop_back())
		if seen.has(current):
			continue
		seen[current] = true
		var node := nodes.get(current, {}) as Dictionary
		if node.get("kind", &"") == &"RUN":
			run_paths[current] = true
		for edge_value in incoming.get(current, []):
			frontier.append(str((edge_value as Dictionary).get("from", "")))
	return run_paths.size() > 1


func node_for(resource_or_path: Variant) -> Dictionary:
	var key := resource_key(resource_or_path) if resource_or_path is Resource else str(resource_or_path)
	return (nodes.get(key, {}) as Dictionary).duplicate(true)


func report(ok := true, cached := false) -> Dictionary:
	var edge_count := 0
	for edges_value in outgoing.values():
		edge_count += (edges_value as Array).size()
	return {
		"ok": ok,
		"cached": cached,
		"generation": generation,
		"nodes": nodes.size(),
		"edges": edge_count,
		"invalidated": _invalid_keys.size(),
		"scanned_at": scanned_at,
		"duration_ms": last_duration_ms,
		"under_ui_threshold": last_duration_ms < 250.0,
		"memory_delta_bytes": last_memory_delta_bytes,
		"object_delta": last_object_delta,
		"stable_path_nodes": nodes.keys().filter(func(key): return str(key).begins_with("res://")),
	}


func resource_key(resource: Resource) -> String:
	if resource == null:
		return ""
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return "memory://%s/%d" % [resource.get_class(), resource.get_instance_id()]


func _record_resource(resource: Resource, kind: StringName, target_nodes: Dictionary) -> String:
	var key := resource_key(resource)
	if key.is_empty():
		return key
	var effective_kind := kind if kind != &"RESOURCE" else StringName(resource.get_class().to_upper())
	target_nodes[key] = {
		"key": key,
		"path": resource.resource_path,
		"kind": effective_kind,
		"class": resource.get_class(),
		"resource": weakref(resource),
	}
	return key


func _walk_resource(
		resource: Resource,
		kind: StringName,
		target_nodes: Dictionary,
		target_outgoing: Dictionary,
		target_incoming: Dictionary,
		visited: Dictionary
	) -> String:
	if resource == null:
		return ""
	var key := _record_resource(resource, kind, target_nodes)
	if visited.has(resource.get_instance_id()):
		return key
	visited[resource.get_instance_id()] = true
	for property in resource.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		if property_name == &"script":
			continue
		_walk_variant(
			key, resource.get(property_name), property_name, {}, target_nodes,
			target_outgoing, target_incoming, visited
		)
	return key


func _walk_variant(
		parent_key: String,
		value: Variant,
		relation: StringName,
		metadata: Dictionary,
		target_nodes: Dictionary,
		target_outgoing: Dictionary,
		target_incoming: Dictionary,
		visited: Dictionary
	) -> void:
	if value is Resource:
		var child_key := _walk_resource(
			value, &"RESOURCE", target_nodes, target_outgoing, target_incoming, visited
		)
		_link(parent_key, child_key, relation, metadata, target_outgoing, target_incoming)
	elif value is Array:
		for index in range(value.size()):
			var child_metadata := metadata.duplicate(true)
			child_metadata["index"] = index
			_walk_variant(
				parent_key, value[index], relation, child_metadata, target_nodes,
				target_outgoing, target_incoming, visited
			)
	elif value is Dictionary:
		for dictionary_key in value:
			var child_metadata := metadata.duplicate(true)
			child_metadata["dictionary_key"] = str(dictionary_key)
			_walk_variant(
				parent_key, value[dictionary_key], relation, child_metadata,
				target_nodes, target_outgoing, target_incoming, visited
			)


func _link(
		from: String,
		to: String,
		relation: StringName,
		metadata: Dictionary,
		target_outgoing: Dictionary,
		target_incoming: Dictionary
	) -> void:
	if from.is_empty() or to.is_empty():
		return
	var edge := {
		"from": from,
		"to": to,
		"relation": relation,
		"metadata": metadata.duplicate(true),
	}
	if not target_outgoing.has(from):
		target_outgoing[from] = []
	if not target_incoming.has(to):
		target_incoming[to] = []
	(target_outgoing[from] as Array).append(edge)
	(target_incoming[to] as Array).append(edge)
