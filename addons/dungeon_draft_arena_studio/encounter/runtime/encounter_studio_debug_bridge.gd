class_name EncounterStudioDebugBridge
extends Node

var request := {}
var started_ticks := 0
var result_written := false


func configure(value: Dictionary) -> void:
	request = value.duplicate(true)
	started_ticks = Time.get_ticks_msec()


func _ready() -> void:
	if not GameManager.combat_report_ready.is_connected(_on_combat_report_ready):
		GameManager.combat_report_ready.connect(_on_combat_report_ready)


func _exit_tree() -> void:
	if GameManager.combat_report_ready.is_connected(_on_combat_report_ready):
		GameManager.combat_report_ready.disconnect(_on_combat_report_ready)
	GameManager.cleanup_run_state()
	EncounterTestLauncher.cleanup_context(request)


func _on_combat_report_ready(report: CombatReport) -> void:
	if result_written or report == null:
		return
	result_written = true
	var battle := get_tree().current_scene
	var formation := {}
	if battle != null and _has_property(battle, &"encounter_formation_snapshot"):
		formation = EncounterPreviewService.serializable(
			battle.get(&"encounter_formation_snapshot")
		)
	var payload := {
		"context_id": request.get("context_id", ""),
		"run_seed": request.get("run_seed", 0),
		"victory": report.victory,
		"duration_seconds": float(Time.get_ticks_msec() - started_ticks) / 1000.0,
		"formation": formation,
		"combat_report": report.to_dictionary(),
		"completed_at": Time.get_datetime_string_from_system(),
	}
	EncounterTestLauncher.finalize_context(request, payload)


func _has_property(object: Object, property_name: StringName) -> bool:
	for descriptor in object.get_property_list():
		if StringName(descriptor.get("name", &"")) == property_name:
			return true
	return false
