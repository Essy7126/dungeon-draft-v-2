@tool
class_name ArenaMigrationService
extends RefCounted


static func migrate_snapshot(snapshot: Dictionary) -> Dictionary:
	return ArenaSchemaMigrator.migrate_snapshot(snapshot)
