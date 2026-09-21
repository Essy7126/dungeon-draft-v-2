class_name RunHeroResolver
extends RefCounted

## The second argument preserves older callers; an implicit roster is no
## longer supported. Every run must supply its own content profile.
static func resolve_runtime_hero_data(
		run_data: RunData,
		_allow_legacy_fallback := false
	) -> RunHeroResolution:
	var result := RunHeroResolution.new()
	if run_data == null:
		result.errors.append("Aucune RunData fournie.")
		return result
	result.errors.append_array(RunHeroVisualVariants.validation_errors(run_data.hero_visual_variants))
	if not result.errors.is_empty():
		return result
	if run_data.content_profile == null:
		if not run_data.hero_visual_variants.is_empty():
			result.errors.append("Une apparence de héros exige un content_profile explicite.")
			return result
		result.errors.append("La RunData %s ne possede aucun content_profile." % run_data.run_name)
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
		var runtime := _runtime_copy(
				hero_profile.base_unit_data,
				progression.spells,
				progression.active_spell_slots,
				progression,
			)
		if not RunHeroVisualVariants.apply_to_runtime(runtime, run_data.hero_visual_variants):
			result.errors.append("Apparence du héros indisponible : %s." % runtime.get_effective_unit_id())
		result.heroes.append(runtime)
	for character_id in run_data.hero_visual_variants:
		if not result.heroes.any(func(hero): return str(hero.get_effective_unit_id()) == str(character_id)):
			result.errors.append("Le héros de l’apparence choisie ne fait pas partie de cette run : %s." % str(character_id))
	if not result.errors.is_empty():
		result.heroes.clear()
		result.hero_profiles.clear()
	return result


static func _runtime_copy(
		base: UnitData,
		spells_source: Array[Spell],
		active_spell_slots: int,
		progression: CharacterProgressionProfile = null
	) -> UnitData:
	var runtime := base.duplicate(false) as UnitData
	runtime.set_path_cache("")
	var spells: Array[Spell] = []
	spells.assign(spells_source)
	runtime.spells = spells
	runtime.active_spell_slots = active_spell_slots
	runtime.progression_profile = progression if progression != null else base.progression_profile
	return runtime
