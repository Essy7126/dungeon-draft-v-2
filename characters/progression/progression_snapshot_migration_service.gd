class_name ProgressionSnapshotMigrationService
extends RefCounted

const CURRENT_VERSION := 3


static func migrate(
		snapshot: Dictionary,
		spells: Array[Spell],
		expected_model: int = CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP
	) -> Dictionary:
	var version := int(snapshot.get("version", 1))
	if version > CURRENT_VERSION:
		return {
			"ok": false,
			"snapshot": snapshot.duplicate(true),
			"diagnostics": PackedStringArray([
				"Version de snapshot de progression plus recente que le runtime.",
			]),
			"unresolved": {},
		}
	if version == CURRENT_VERSION:
		var stored_model := int(snapshot.get("progression_model", -1))
		if stored_model != expected_model:
			return {
				"ok": false,
				"snapshot": snapshot.duplicate(true),
				"diagnostics": PackedStringArray([
					"La politique de progression du snapshot est incompatible.",
				]),
				"unresolved": {},
			}
		return {
			"ok": true,
			"snapshot": snapshot.duplicate(true),
			"diagnostics": PackedStringArray(),
			"unresolved": {},
		}
	if expected_model \
			== CharacterProgressionProfile.ProgressionModel.CHAMPION_LEVEL_AND_MASTERY:
		return {
			"ok": false,
			"snapshot": snapshot.duplicate(true),
			"diagnostics": PackedStringArray([
				"Une sauvegarde legacy ne peut pas etre convertie silencieusement en progression Champion.",
			]),
			"unresolved": {},
		}
	if version == 2:
		var upgraded := snapshot.duplicate(true)
		upgraded["version"] = CURRENT_VERSION
		upgraded["progression_model"] = (
			CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP
		)
		return {
			"ok": true,
			"snapshot": upgraded,
			"diagnostics": PackedStringArray([
				"Snapshot legacy v2 migre explicitement vers v3.",
			]),
			"unresolved": upgraded.get(
				"unresolved_legacy_progressions", {}
			),
		}
	var migrated := {
		"version": CURRENT_VERSION,
		"progression_model": (
			CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP
		),
		"character_id": snapshot.get("character_id", &""),
		"spell_progressions": {},
		"unresolved_legacy_progressions": {},
	}
	var diagnostics := PackedStringArray()
	var legacy := snapshot.get("disciplines", {}) as Dictionary
	for legacy_key_value in legacy:
		var legacy_id := StringName(legacy_key_value)
		var candidates: Array[Spell] = []
		for spell in spells:
			if spell == null:
				continue
			if spell.get_skill_tree_id() == legacy_id or spell.discipline_id == legacy_id:
				candidates.append(spell)
		if candidates.size() != 1:
			var candidate_ids: Array[String] = []
			for candidate in candidates:
				candidate_ids.append(str(candidate.get_effective_spell_id()))
			var reason := (
				"aucun sort ne reference cet arbre"
				if candidates.is_empty()
				else "plusieurs sorts referencent cet arbre"
			)
			migrated.unresolved_legacy_progressions[str(legacy_id)] = {
				"reason": reason,
				"candidate_spell_ids": candidate_ids,
				"snapshot": (legacy[legacy_key_value] as Dictionary).duplicate(true),
			}
			diagnostics.append("Progression legacy %s non migree : %s." % [legacy_id, reason])
			continue
		var spell_id := candidates[0].get_effective_spell_id()
		if spell_id == &"spell:unassigned" \
				or migrated.spell_progressions.has(str(spell_id)):
			migrated.unresolved_legacy_progressions[str(legacy_id)] = {
				"reason": "spell_id absent ou deja utilise",
				"candidate_spell_ids": [str(spell_id)],
				"snapshot": (legacy[legacy_key_value] as Dictionary).duplicate(true),
			}
			diagnostics.append("Progression legacy %s non migree : spell_id invalide." % legacy_id)
			continue
		var entry := (legacy[legacy_key_value] as Dictionary).duplicate(true)
		entry.erase("discipline_id")
		entry["spell_id"] = spell_id
		migrated.spell_progressions[str(spell_id)] = entry
	return {
		"ok": migrated.unresolved_legacy_progressions.is_empty(),
		"snapshot": migrated,
		"diagnostics": diagnostics,
		"unresolved": migrated.unresolved_legacy_progressions.duplicate(true),
	}
