extends SceneTree


func _initialize() -> void:
	var report := RunContentMigrationService.migrate_rule_fixtures()
	print("RUN_CONTENT_MIGRATION_REPORT=" + JSON.stringify(report))
	quit(0 if report.get("ok", false) else 1)
