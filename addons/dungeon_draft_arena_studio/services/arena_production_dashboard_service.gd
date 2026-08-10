@tool
class_name ArenaProductionDashboardService
extends RefCounted

## Inventaire strictement en lecture seule des productions et récupérations.
## Les mutations restent des actions explicites des services d'ownership.

const UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE := \
	&"UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE"

const AUXILIARY_ROOTS := {
	&"ARCHIVE": ArenaBundleOwnershipService.ARCHIVE_ROOT,
	&"BACKUP": "user://dungeon_draft_studio/production_transactions",
	&"DRAFT": "user://dungeon_draft_studio/drafts",
	&"LAB_TRANSFER": "user://dungeon_draft_studio/art_lab",
	&"RECOVERY": "user://dungeon_draft_studio/room_integration/recovery",
}


static func scan(graph: StudioReferenceGraphService = null) -> Dictionary:
	var records: Array[Dictionary] = []
	for directory in _child_directories(ArenaProductionService.DEFAULT_ROOT):
		var inspection := ArenaBundleInspectionService.inspect(directory, graph)
		records.append(_bundle_record(inspection))
	for kind in AUXILIARY_ROOTS:
		for directory in _child_directories(str(AUXILIARY_ROOTS[kind])):
			records.append(_auxiliary_record(StringName(kind), directory))
	records.sort_custom(func(a: Dictionary, b: Dictionary):
		return str(a.get("path", "")) < str(b.get("path", ""))
	)
	var counts := {}
	for record in records:
		var category := StringName(record.get("category", &"UNKNOWN"))
		counts[category] = int(counts.get(category, 0)) + 1
	return {
		"ok": true,
		"read_only": true,
		"scanned_at": Time.get_datetime_string_from_system(true),
		"records": records,
		"counts": counts,
		"automatic_deletion": false,
	}


static func format_human(report: Dictionary) -> String:
	var lines := PackedStringArray([
		"[b]PRODUCTIONS ET RÉCUPÉRATIONS[/b]",
		"Inventaire en lecture seule — aucune suppression automatique.",
		"",
	])
	var records := report.get("records", []) as Array
	if records.is_empty():
		lines.append("Aucune production ni récupération détectée.")
		return "\n".join(lines)
	for record_value in records:
		var record := record_value as Dictionary
		lines.append("[b]%s[/b] — %s" % [
			str(record.get("label", "État inconnu")),
			str(record.get("display_name", record.get("path", ""))),
		])
		lines.append("  %s" % str(record.get("path", "")))
		var actions := record.get("actions", PackedStringArray()) as PackedStringArray
		if not actions.is_empty():
			lines.append("  Actions explicites : %s" % ", ".join(actions))
	return "\n".join(lines)


static func _bundle_record(inspection: Dictionary) -> Dictionary:
	var state := StringName(inspection.get("state", ArenaBundleInspectionService.UNKNOWN))
	var referenced := bool(inspection.get("referenced", false))
	var category := state
	var label := _state_label(state, referenced)
	if state == ArenaBundleInspectionService.OWNED_INCOMPLETE and not referenced:
		category = UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE
		label = "Bundle incomplet non référencé"
	var actions := PackedStringArray(["Ouvrir", "Comparer", "Ouvrir le rapport", "Voir les usages"])
	if state in [ArenaBundleInspectionService.OWNED_COMPLETE, ArenaBundleInspectionService.LEGACY_BUNDLE]:
		actions.append("Intégrer")
	if category == UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE:
		actions.append("Archiver")
	return {
		"kind": &"BUNDLE",
		"category": category,
		"source_state": state,
		"label": label,
		"display_name": str(inspection.get("directory", "")).get_file(),
		"path": inspection.get("directory", ""),
		"referenced": referenced,
		"complete": bool(inspection.get("complete", false)),
		"inspection": inspection,
		"actions": actions,
		"deletable_after_confirmation": false,
	}


static func _auxiliary_record(kind: StringName, directory: String) -> Dictionary:
	var transaction_report := directory.path_join("transaction_report.json")
	var category := kind
	var label := {
		&"ARCHIVE": "Archive restaurable",
		&"BACKUP": "Backup / transaction",
		&"DRAFT": "Brouillon",
		&"LAB_TRANSFER": "Transfert Lab",
		&"RECOVERY": "Récupération d'intégration",
	}.get(kind, "Récupération")
	if kind == &"BACKUP" and FileAccess.file_exists(transaction_report):
		var parsed := ArenaProductionService._read_json(transaction_report)
		var status := str(parsed.get("status", ""))
		if "FAILED" in status or "ROLLBACK" in status:
			category = &"FAILED_TRANSACTION"
			label = "Transaction échouée ou annulée"
	var actions := PackedStringArray(["Ouvrir", "Ouvrir le rapport"])
	if kind in [&"ARCHIVE", &"RECOVERY"]:
		actions.append("Restaurer")
	return {
		"kind": kind,
		"category": category,
		"label": label,
		"display_name": directory.get_file(),
		"path": directory,
		"actions": actions,
		"deletable_after_confirmation": true,
	}


static func _state_label(state: StringName, referenced: bool) -> String:
	match state:
		ArenaBundleInspectionService.OWNED_COMPLETE:
			return "Bundle complet non référencé"
		ArenaBundleInspectionService.REFERENCED_COMPLETE:
			return "Bundle complet intégré"
		ArenaBundleInspectionService.OWNED_INCOMPLETE:
			return "Bundle incomplet"
		ArenaBundleInspectionService.REFERENCED_INCOMPLETE:
			return "Bundle incomplet référencé — action bloquée"
		ArenaBundleInspectionService.LEGACY_BUNDLE:
			return "Bundle legacy"
		ArenaBundleInspectionService.OWNED_DIRTY:
			return "Bundle modifié ou conflictuel"
		ArenaBundleInspectionService.FOREIGN_CONTENT:
			return "Contenu étranger"
		ArenaBundleInspectionService.CORRUPT_MANIFEST:
			return "Manifeste corrompu"
		_:
			return "État inconnu%s" % (" référencé" if referenced else "")


static func _child_directories(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var access := DirAccess.open(ProjectSettings.globalize_path(root))
	if access == null:
		return result
	for child in access.get_directories():
		if child.begins_with("."):
			continue
		result.append(root.path_join(child))
	result.sort()
	return result
