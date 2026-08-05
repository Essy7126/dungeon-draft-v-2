@tool
class_name ArenaSchemaMigrator
extends RefCounted


static func inspect(snapshot: Dictionary) -> Dictionary:
	var source_version := int(snapshot.get("schema_version", 0))
	return {
		"supported": source_version >= 0 and source_version <= ArenaDefinition.CURRENT_SCHEMA_VERSION,
		"requires_migration": source_version < ArenaDefinition.CURRENT_SCHEMA_VERSION,
		"from_version": source_version,
		"to_version": ArenaDefinition.CURRENT_SCHEMA_VERSION,
	}


static func migrate_snapshot(snapshot: Dictionary) -> Dictionary:
	var status := inspect(snapshot)
	if not bool(status.supported):
		return {"ok": false, "error": "Version de schema future non supportee."}
	var migrated := snapshot.duplicate(true)
	var version := int(status.from_version)
	if version == 0:
		migrated["border_thickness"] = int(migrated.get("border_thickness", 1))
		migrated["obstacles"] = migrated.get("obstacles", [])
		migrated["spawns"] = migrated.get("spawns", [])
		version = 1
	if version == 1:
		migrated["visual_mode"] = ArenaDefinition.VisualMode.PAINTED
		migrated["theme_id"] = str(migrated.get("theme_id", "painted_legacy"))
		migrated["modular_visual_profile"] = migrated.get("modular_visual_profile", {})
		migrated["decorations"] = migrated.get("decorations", [])
		migrated["objectives"] = migrated.get("objectives", [])
		version = 2
	migrated["schema_version"] = version
	return {
		"ok": true,
		"from_version": int(status.from_version),
		"to_version": version,
		"changed": int(status.from_version) != version,
		"snapshot": migrated,
	}
