class_name RunHeroResolver
extends RefCounted

const EXPECTED_CHARACTER_IDS: Array[StringName] = [&"elf", &"mage", &"warrior"]
const LEGACY_HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


static func resolve_runtime_hero_data(
		run_data: RunData,
		allow_legacy_fallback := true
	) -> RunHeroResolution:
	var result := RunHeroResolution.new()
	if run_data == null:
		result.errors.append("Aucune RunData fournie.")
		return result
	if run_data.content_profile == null:
		if not allow_legacy_fallback:
			result.errors.append("La RunData %s ne possede aucun content_profile." % run_data.run_name)
			return result
		result.used_legacy_fallback = true
		result.warnings.append(
			"RunData legacy sans content_profile : utilisation temporaire du trio historique."
		)
		for path in LEGACY_HERO_PATHS:
			var legacy := load(path) as UnitData
			if legacy == null:
				result.errors.append("UnitData legacy introuvable : %s" % path)
				continue
			result.heroes.append(_runtime_copy(legacy, legacy.spells, legacy.disciplines, legacy.active_spell_slots))
		return result

	var content := run_data.content_profile
	result.errors.append_array(content.validation_errors())
	if content.hero_profiles.size() != EXPECTED_CHARACTER_IDS.size():
		result.errors.append(
			"Le profil %s doit contenir exactement trois heros." % content.profile_id
		)
		return result
	for index in range(EXPECTED_CHARACTER_IDS.size()):
		var expected_id := EXPECTED_CHARACTER_IDS[index]
		var hero_profile := content.hero_profiles[index]
		if hero_profile == null:
			continue
		if hero_profile.character_id != expected_id:
			result.errors.append(
				"Ordre de heros invalide a l'index %d : %s attendu, %s recu." % [
					index, expected_id, hero_profile.character_id,
				]
			)
			continue
		if not hero_profile.validation_errors().is_empty():
			continue
		var progression := hero_profile.progression_profile
		result.hero_profiles.append(hero_profile)
		result.heroes.append(
			_runtime_copy(
				hero_profile.base_unit_data,
				progression.spells,
				progression.disciplines,
				progression.active_spell_slots,
			)
		)
	if not result.errors.is_empty():
		result.heroes.clear()
		result.hero_profiles.clear()
	return result


static func _runtime_copy(
		base: UnitData,
		spells_source: Array[Spell],
		disciplines_source: Array[DisciplineData],
		active_spell_slots: int
	) -> UnitData:
	var runtime := base.duplicate(false) as UnitData
	runtime.set_path_cache("")
	var spells: Array[Spell] = []
	spells.assign(spells_source)
	var disciplines: Array[DisciplineData] = []
	disciplines.assign(disciplines_source)
	runtime.spells = spells
	runtime.disciplines = disciplines
	runtime.active_spell_slots = active_spell_slots
	return runtime
