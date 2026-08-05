@tool
class_name StudioResourceCatalog
extends RefCounted


static func find_run_paths(root := "res://data/runs") -> PackedStringArray:
	return _find_typed_paths(root, "RunData")


static func find_unit_paths(root := "res://data/units") -> PackedStringArray:
	return _find_typed_paths(root, "UnitData")


static func load_enemy_units(root := "res://data/units") -> Array[UnitData]:
	var result: Array[UnitData] = []
	for path in find_unit_paths(root):
		if not _declares_enemy_team(path):
			continue
		# Certaines anciennes fiches du depot referencent des images ou sorts
		# supprimes. Les ignorer avant ResourceLoader evite des erreurs d'import
		# tout en gardant le catalogue derive des ressources réellement valides.
		if _has_missing_file_dependencies(path):
			continue
		var unit := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) \
			as UnitData
		if unit != null and unit.team == 1:
			result.append(unit)
	result.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		var fa := str(a.faction_id)
		var fb := str(b.faction_id)
		if fa != fb:
			return fa < fb
		return a.unit_name.naturalnocasecmp_to(b.unit_name) < 0
	)
	return result


static func _declares_enemy_team(path: String) -> bool:
	if path.get_extension().to_lower() != "tres":
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	while not file.eof_reached():
		if file.get_line().strip_edges() == "team = 1":
			return true
	return false


static func _find_typed_paths(root: String, class_name_value: String) -> PackedStringArray:
	var result := PackedStringArray()
	_collect_resource_paths(root, result)
	var filtered := PackedStringArray()
	for path in result:
		if _declares_script_class(path, class_name_value):
			filtered.append(path)
	filtered.sort()
	return filtered


static func _declares_script_class(path: String, class_name_value: String) -> bool:
	if path.get_extension().to_lower() != "tres":
		# Les classes de script ne sont pas inspectables sans charger un .res
		# binaire ; le catalogue V1 cible les ressources texte editables.
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var header := file.get_line()
	return ('script_class="%s"' % class_name_value) in header


static func _has_missing_file_dependencies(path: String) -> bool:
	if path.get_extension().to_lower() != "tres":
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	var expression := RegEx.new()
	expression.compile('path="(res://[^"]+)"')
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("[ext_resource"):
			continue
		var matched := expression.search(line)
		if matched != null and not FileAccess.file_exists(matched.get_string(1)):
			return true
	return false


static func _collect_resource_paths(directory_path: String, result: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_resource_paths(path, result)
		elif entry.get_extension().to_lower() in ["tres", "res"]:
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
