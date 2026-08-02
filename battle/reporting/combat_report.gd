class_name CombatReport
extends RefCounted

var report_id: StringName = &""
var room_index := -1
var room_name := "Salle"
var started_at_msec := 0
var completed_at_msec := 0
var victory := false
var finalized := false
var character_reports: Array[CharacterCombatReport] = []
var reward_result: Dictionary = {}


func get_character_report(character_id: StringName) -> CharacterCombatReport:
	for report in character_reports:
		if report != null and report.character_id == character_id:
			return report
	return null


func to_dictionary() -> Dictionary:
	var characters: Array[Dictionary] = []
	for report in character_reports:
		if report != null:
			characters.append(report.to_dictionary())
	return {
		"report_id": report_id,
		"room_index": room_index,
		"room_name": room_name,
		"started_at_msec": started_at_msec,
		"completed_at_msec": completed_at_msec,
		"victory": victory,
		"finalized": finalized,
		"character_reports": characters,
		"reward_result": reward_result.duplicate(true),
	}
