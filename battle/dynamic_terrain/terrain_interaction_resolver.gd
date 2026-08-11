class_name TerrainInteractionResolver
extends RefCounted

## Table centrale et pure des interactions de surfaces. Les sorts fournissent
## uniquement un effet entrant ; cette classe decide du resultat et de la
## creation eventuelle de vapeur.


static func resolve(current: int, incoming: int) -> Dictionary:
	var current_id := TerrainSurfaceIdResolver.surface_id_for_dynamic(current)
	var incoming_id := TerrainSurfaceIdResolver.surface_id_for_dynamic(incoming)
	var result := resolve_ids(current_id, incoming_id)
	result["surface"] = TerrainSurfaceIdResolver.dynamic_surface(
		StringName(result.result_surface_id)
	)
	result["steam"] = StringName(result.get("reaction", &"")) == &"steam"
	return result


static func resolve_ids(
		current: StringName,
		incoming: StringName
	) -> Dictionary:
	if incoming == &"none" or incoming == &"":
		return _result(&"none", &"clear")
	if current == &"none" or current == &"":
		return _result(incoming, &"apply")
	if current == incoming:
		return _result(current, &"same", true)
	var pair := [str(current), str(incoming)]
	pair.sort()
	var key := "%s|%s" % [pair[0], pair[1]]
	match key:
		"fire|water":
			return _result(&"steam", &"steam")
		"fire|ice":
			return _result(&"water", &"melt")
		"ice|water":
			return _result(&"ice", &"freeze")
		"lightning|water":
			return _result(&"none", &"shock")
	return _result(incoming, &"replace")


static func _result(
		result_surface_id: StringName,
		reaction: StringName,
		same := false
	) -> Dictionary:
	return {
		"result_surface_id": result_surface_id,
		"reaction": reaction,
		"same": same,
	}
