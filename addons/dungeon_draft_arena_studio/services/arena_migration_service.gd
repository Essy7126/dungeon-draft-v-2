@tool
class_name ArenaMigrationService
extends RefCounted


static func migrate_snapshot(snapshot: Dictionary) -> Dictionary:
	var source_version := int(snapshot.get("schema_version", 0))
	if source_version > ArenaDefinition.CURRENT_SCHEMA_VERSION:
		return {
			"ok": false,
			"error": "Cette arene utilise une version de schema plus recente.",
		}
	var migrated := snapshot.duplicate(true)
	if source_version == 0:
		migrated["schema_version"] = 1
		if not migrated.has("border_thickness"):
			migrated["border_thickness"] = 1
		if not migrated.has("obstacles"):
			migrated["obstacles"] = []
		if not migrated.has("spawns"):
			migrated["spawns"] = []
	return {
		"ok": true,
		"from_version": source_version,
		"to_version": ArenaDefinition.CURRENT_SCHEMA_VERSION,
		"changed": source_version != ArenaDefinition.CURRENT_SCHEMA_VERSION,
		"snapshot": migrated,
	}
