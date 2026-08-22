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
		return {"ok": false, "error": "Version de schéma future non supportee."}
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
	if version == 2:
		var networks: Array = migrated.get("vortex_networks", []).duplicate(true)
		if networks.is_empty():
			var index := 1
			for pair in migrated.get("vortex_pairs", []):
				if not pair is Dictionary:
					continue
				var pair_id := str(pair.get("pair_id", "")).strip_edges()
				var network_id := pair_id if not pair_id.is_empty() \
					else "vortex_network_%03d" % index
				networks.append({
					"network_id": network_id,
					"display_name": "Vortex migré %s" % network_id,
					"cells": [
						pair.get("entry_cell", [0, 0]),
						pair.get("exit_cell", [1, 1]),
					],
					"enabled": bool(pair.get("runtime_enabled", true)),
					"allowed_teams": 3,
					"editor_color": ArenaVortexNetworkService.color_for_id(
						StringName(network_id)
					).to_html(true),
					"single_vortex_effect_id": "void_impulse",
					"random_destination": false,
					"production_notes": "Migré automatiquement depuis vortex_pairs.",
				})
				index += 1
		migrated["vortex_networks"] = networks
		version = 3
	migrated["schema_version"] = version
	return {
		"ok": true,
		"from_version": int(status.from_version),
		"to_version": version,
		"changed": int(status.from_version) != version,
		"snapshot": migrated,
	}
