@tool
class_name SkillTreeRunComparisonService
extends RefCounted


static func compare(
		left_run: RunData,
		right_run: RunData,
		character_id: StringName
	) -> Dictionary:
	var left := RunContentCatalogService.progression_profile_for(left_run, character_id)
	var right := RunContentCatalogService.progression_profile_for(right_run, character_id)
	if left == null or right == null:
		return {"ok": false, "error": "Profil absent dans l'une des runs."}
	var left_snapshot := _profile_snapshot(left)
	var right_snapshot := _profile_snapshot(right)
	var differences: Array[Dictionary] = []
	_compare_map("sort", left_snapshot.spells, right_snapshot.spells, differences)
	_compare_map("discipline", left_snapshot.disciplines, right_snapshot.disciplines, differences)
	return {
		"ok": true,
		"character_id": character_id,
		"left_run": left_run.run_name,
		"right_run": right_run.run_name,
		"left_profile_path": left.resource_path,
		"right_profile_path": right.resource_path,
		"same_profile": left.resource_path == right.resource_path,
		"differences": differences,
		"left": left_snapshot,
		"right": right_snapshot,
	}


static func format_report(report: Dictionary) -> String:
	if not report.get("ok", false):
		return str(report.get("error", "Comparaison impossible."))
	var lines := PackedStringArray([
		"COMPARAISON DE PROGRESSION",
		"%s  ↔  %s" % [report.get("left_run", ""), report.get("right_run", "")],
		"Heros : %s" % report.get("character_id", ""),
		"Profil gauche : %s" % report.get("left_profile_path", ""),
		"Profil droit : %s" % report.get("right_profile_path", ""),
		"Ressource partagee : %s" % ("oui" if report.get("same_profile", false) else "non"),
		"",
	])
	var differences := report.get("differences", []) as Array
	if differences.is_empty():
		lines.append("Aucune divergence de sorts, rangs, noeuds ou effets.")
	else:
		for difference in differences:
			lines.append("• %s %s : %s" % [
				difference.get("kind", "element"), difference.get("id", ""),
				difference.get("change", "modifie"),
			])
	return "\n".join(lines)


static func _profile_snapshot(profile: CharacterProgressionProfile) -> Dictionary:
	var spells := {}
	for spell in profile.spells:
		if spell != null:
			spells[str(spell.get_effective_spell_id())] = SkillTreeSnapshotService.storage_fingerprint(spell)
	var disciplines := {}
	for discipline in profile.disciplines:
		if discipline == null:
			continue
		var ranks := []
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			var nodes := []
			for node in rank_data.choices:
				if node != null:
					nodes.append({
						"id": str(node.upgrade_id),
						"effects": node.spell_modifiers.size(),
						"fingerprint": SkillTreeSnapshotService.storage_fingerprint(node),
					})
			ranks.append({"rank": rank_data.rank, "xp": rank_data.required_total_xp, "nodes": nodes})
		disciplines[str(discipline.discipline_id)] = {
			"fingerprint": SkillTreeSnapshotService.storage_fingerprint(discipline),
			"ranks": ranks,
		}
	return {
		"path": profile.resource_path,
		"active_spell_slots": profile.active_spell_slots,
		"spells": spells,
		"disciplines": disciplines,
	}


static func _compare_map(
		kind: String,
		left: Dictionary,
		right: Dictionary,
		differences: Array[Dictionary]
	) -> void:
	var ids := {}
	for id in left:
		ids[id] = true
	for id in right:
		ids[id] = true
	for id in ids:
		if not left.has(id):
			differences.append({"kind": kind, "id": id, "change": "ajoute a droite"})
		elif not right.has(id):
			differences.append({"kind": kind, "id": id, "change": "absent a droite"})
		elif JSON.stringify(left[id]) != JSON.stringify(right[id]):
			differences.append({"kind": kind, "id": id, "change": "contenu different"})
