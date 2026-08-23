class_name RunHeroResolver
extends RefCounted

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
			result.heroes.append(_runtime_copy(legacy, legacy.spells, legacy.active_spell_slots))
		return result

	var content := run_data.content_profile
	result.errors.append_array(content.validation_errors())
	if not result.errors.is_empty():
		return result
	for hero_profile in content.hero_profiles:
		if hero_profile == null:
			continue
		if not hero_profile.validation_errors().is_empty():
			continue
		var progression := hero_profile.progression_profile
		result.hero_profiles.append(hero_profile)
		result.heroes.append(
			_runtime_copy(
				hero_profile.base_unit_data,
				progression.spells,
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
		active_spell_slots: int
	) -> UnitData:
	var runtime := base.duplicate(false) as UnitData
	runtime.set_path_cache("")
	var spells: Array[Spell] = []
	spells.assign(spells_source)
	runtime.spells = spells
	runtime.active_spell_slots = active_spell_slots
	return runtime
