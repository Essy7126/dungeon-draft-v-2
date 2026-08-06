extends SceneTree


func _initialize() -> void:
	var report := RunContentMigrationService.migrate_official_runs()
	print("RUN_CONTENT_MIGRATION_REPORT=" + JSON.stringify(report))
	quit(0 if report.get("ok", false) else 1)
