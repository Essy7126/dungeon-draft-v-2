extends Node
## Read-only project inspection. The runtime remains the authority for behavior.


func _ready() -> void:
	call_deferred("_inspect")


func _inspect() -> void:
	var resource_path := ""
	var output_path := ""
	var include_references := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--resource="):
			resource_path = argument.trim_prefix("--resource=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument == "--references":
			include_references = true
	var result := { "ok": false, "resource": resource_path }
	if not resource_path.begins_with("res://") or ".." in resource_path:
		result["error"] = "A project resource path is required."
	else:
		var resource := ResourceLoader.load(resource_path)
		if resource == null:
			result["error"] = "Resource could not be loaded."
		else:
			result["ok"] = true
			result["type"] = resource.get_class()
			result["dependencies"] = Array(ResourceLoader.get_dependencies(resource_path))
			var properties := { }
			for property in resource.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					properties[property.name] = _compact(resource.get(property.name))
			result["properties"] = properties
			if include_references:
				var graph := StudioReferenceGraphService.new()
				var scan := graph.scan(true)
				result["graph"] = {
					"ok": scan.ok,
					"nodes": scan.nodes,
					"edges": scan.edges,
					"duration_ms": scan.duration_ms,
				}
				result["usages"] = graph.usages(resource)
				result["references"] = graph.references_from(resource)
				result["scope"] = "Production roots discovered by Dungeon Draft Studio"
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write inspection report.")
			get_tree().quit(2)
			return
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print("DEV_INSPECTION=" + JSON.stringify({ "ok": result.ok, "report": output_path }))
	get_tree().quit(0 if result.ok else 1)


func _compact(value: Variant) -> Variant:
	if value is Resource:
		return { "type": value.get_class(), "path": value.resource_path }
	if value is Array or value is Dictionary:
		return { "type": type_string(typeof(value)), "count": value.size() }
	if value is String and value.length() > 300:
		return { "preview": value.left(300), "truncated": true, "length": value.length() }
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
		return value
	return str(value)
