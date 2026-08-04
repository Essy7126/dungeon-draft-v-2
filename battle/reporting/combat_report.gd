class_name CombatReport
extends RefCounted

var report_id: StringName = &""
var room_index := -1
var room_name := "Salle"
var started_at_msec := 0
var completed_at_msec := 0
var victory := false
var finalized := false
var waves_included := 1
var character_reports: Array[CharacterCombatReport] = []
var reward_result: Dictionary = {}


func get_character_report(character_id: StringName) -> CharacterCombatReport:
	for report in character_reports:
		if report != null and report.character_id == character_id:
			return report
	return null


func merge_wave_report(wave_report: CombatReport) -> bool:
	if wave_report == null \
			or wave_report == self \
			or wave_report.room_index != room_index:
		return false
	report_id = wave_report.report_id
	room_name = wave_report.room_name
	if started_at_msec <= 0:
		started_at_msec = wave_report.started_at_msec
	completed_at_msec = wave_report.completed_at_msec
	victory = wave_report.victory
	finalized = wave_report.finalized
	waves_included += maxi(1, wave_report.waves_included)
	for wave_character in wave_report.character_reports:
		if wave_character == null:
			continue
		var cumulative_character := get_character_report(
			wave_character.character_id
		)
		if cumulative_character == null:
			character_reports.append(wave_character)
		else:
			cumulative_character.merge_wave_report(wave_character)
	if not wave_report.reward_result.is_empty():
		reward_result = wave_report.reward_result.duplicate(true)
	return true


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
		"waves_included": waves_included,
		"character_reports": characters,
		"reward_result": reward_result.duplicate(true),
	}
