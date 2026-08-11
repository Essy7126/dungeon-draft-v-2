@tool
class_name ArenaBundleVersioningService
extends RefCounted

const MAX_VERSION_ATTEMPTS := 999


static func next_destination(destination: String) -> Dictionary:
	if destination.is_empty() or destination in ["res://", "user://"]:
		return {"ok": false, "error": "invalid_destination"}
	var base := destination.trim_suffix("/")
	var stem := base
	var first_version := 2
	var marker := base.rfind("_v")
	if marker >= 0:
		var suffix := base.substr(marker + 2)
		if suffix.is_valid_int() and int(suffix) >= 2:
			stem = base.left(marker)
			first_version = int(suffix) + 1
	for version in range(first_version, MAX_VERSION_ATTEMPTS + 1):
		var candidate := "%s_v%d" % [stem, version]
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)) \
				and ArenaBundleInspectionService._files(candidate).is_empty():
			return {
				"ok": true,
				"source_destination": destination,
				"destination": candidate,
				"version": version,
				"arena_id_unchanged": true,
			}
	return {"ok": false, "error": "version_space_exhausted"}
