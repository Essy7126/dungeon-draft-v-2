@tool
class_name EncounterReportExporter
extends RefCounted

const VERSION := "1.0.0"
const ROOT := "res://artifacts/encounter_studio"


static func export_report(
		session: EncounterEditSession,
		preview: Dictionary,
		analysis: Dictionary = {},
		test_result: Dictionary = {}
	) -> Dictionary:
	if session == null or session.current_room() == null:
		return {"ok": false, "error": "session_missing"}
	var run_slug := _slug(session.working_run.run_name)
	var room_slug := _slug(session.current_room().room_name)
	var directory := ROOT.path_join(run_slug).path_join(room_slug).path_join(
		"%02d" % (session.selected_wave_index + 1)
	)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return {"ok": false, "error": "directory_failed"}
	var messages := session.validation_messages
	if messages.is_empty():
		messages = EncounterValidationService.validate_session(
			session, session.working_run.default_seed
		)
	var validation_summary := EncounterValidationService.summary(messages)
	var verdict := "ENCOUNTER_INVALID" if validation_summary.errors > 0 \
		else "ENCOUNTER_VALID_WITH_WARNINGS" if validation_summary.warnings > 0 \
		else "ENCOUNTER_VALID"
	var wave := session.current_wave()
	var encounter := session.current_encounter()
	var payload := {
		"studio_version": VERSION,
		"godot_version": Engine.get_version_info().get("string", ""),
		"git": _git_context(),
		"run_path": session.source_run_path,
		"room_flow_mode": session.working_run.get_room_flow_mode_name(),
		"uses_wave_chain": session.working_run.uses_wave_chain(),
		"room_path": (session.source_for(session.current_room()) as Resource).resource_path \
			if session.source_for(session.current_room()) != null else "",
		"wave_path": wave.resource_path if wave != null else "sous-ressource",
		"encounter_path": encounter.resource_path if encounter != null else str(
			session.new_resource_paths.get(encounter, "")
		),
		"room_index": session.selected_room_index,
		"wave_index": session.selected_wave_index,
		"room_mode": session.room_mode_label(),
		"wave": {
			"name": wave.wave_name if wave != null else "Rencontre historique",
			"health_multiplier": wave.enemy_health_multiplier if wave != null else 1.0,
			"attack_multiplier": wave.enemy_attack_multiplier if wave != null else 1.0,
			"reward_multiplier": wave.reward_multiplier if wave != null else 1.0,
		},
		"encounter": EncounterCopyService.encounter_snapshot(encounter),
		"preview": EncounterPreviewService.serializable(preview),
		"analysis": analysis,
		"validation": messages.map(func(message): return message.to_dictionary()),
		"validation_summary": validation_summary,
		"test_result": test_result,
		"verdict": verdict,
	}
	var json_path := directory.path_join("encounter_report.json")
	var markdown_path := directory.path_join("encounter_report.md")
	if not _write(json_path, JSON.stringify(payload, "  ")):
		return {"ok": false, "error": "json_write_failed"}
	if not _write(markdown_path, _markdown(payload)):
		return {"ok": false, "error": "markdown_write_failed"}
	return {
		"ok": true,
		"directory": directory,
		"json_path": json_path,
		"markdown_path": markdown_path,
		"verdict": verdict,
		"markdown": FileAccess.get_file_as_string(markdown_path),
	}


static func _markdown(payload: Dictionary) -> String:
	var preview := payload.preview as Dictionary
	var summary := payload.validation_summary as Dictionary
	var encounter := payload.encounter as Dictionary
	return """# Rapport Encounter Studio

- Verdict : **%s**
- Run : `%s`
- Déroulement : `%s`
- Salle / Affrontement : %d / %d
- Mode : %s
- Seed de run : %s
- Seed effective : %s
- Formation : `%s`
- Placement : %s
- Composition initiale : %d ennemi(s)
- Plafond vivant : %s
- Budgets d'invocation : normal %s, chef %s
- Validation : %d erreur(s), %d avertissement(s)

## Placement

```json
%s
```

## Analyse de seeds

```json
%s
```

## Messages

```json
%s
```
""" % [
		payload.verdict,
		payload.run_path,
		payload.room_flow_mode,
		int(payload.room_index) + 1,
		int(payload.wave_index) + 1,
		payload.room_mode,
		preview.get("run_seed", ""),
		preview.get("effective_seed", ""),
		preview.get("formation_id", ""),
		"valide" if preview.get("valid", false) else preview.get("reason", "echec"),
		(payload.encounter.get("roster_counts", []) as Array).reduce(
			func(total, value): return total + int(value), 0
		),
		encounter.get("living_enemy_cap", 0),
		encounter.get("shared_normal_summon_budget", 0),
		encounter.get("shared_chief_summon_budget", 0),
		summary.errors,
		summary.warnings,
		JSON.stringify(preview, "  "),
		JSON.stringify(payload.analysis, "  "),
		JSON.stringify(payload.validation, "  "),
	]


static func _git_context() -> Dictionary:
	var branch_output: Array = []
	var head_output: Array = []
	OS.execute("git", ["branch", "--show-current"], branch_output, true)
	OS.execute("git", ["rev-parse", "HEAD"], head_output, true)
	return {
		"branch": str(branch_output[0]).strip_edges() if not branch_output.is_empty() else "",
		"head": str(head_output[0]).strip_edges() if not head_output.is_empty() else "",
	}


static func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	return true


static func _slug(value: String) -> String:
	var slug := value.to_lower().strip_edges().replace(" ", "_").replace("—", "_")
	while "__" in slug:
		slug = slug.replace("__", "_")
	return slug if not slug.is_empty() else "sans_nom"
