@tool
class_name RunContentCatalogService
extends RefCounted

const RUNS_ROOT := "res://data/runs"


static func discover_runs() -> Array[RunData]:
	var runs: Array[RunData] = []
	_discover_runs_recursive(RUNS_ROOT, runs)
	runs.sort_custom(func(a: RunData, b: RunData) -> bool:
		return a.resource_path < b.resource_path
	)
	return runs


static func heroes_for_run(run_data: RunData) -> Array[RunHeroProfile]:
	var heroes: Array[RunHeroProfile] = []
	if run_data != null and run_data.content_profile != null:
		heroes.assign(run_data.content_profile.hero_profiles)
	return heroes


static func progression_profile_for(
		run_data: RunData,
		character_id: StringName
	) -> CharacterProgressionProfile:
	for hero in heroes_for_run(run_data):
		if hero != null and hero.character_id == character_id:
			return hero.progression_profile
	return null


static func usages_for_progression_profile(
		profile: CharacterProgressionProfile
	) -> Array[Dictionary]:
	var usages: Array[Dictionary] = []
	if profile == null:
		return usages
	for run_data in discover_runs():
		for hero in heroes_for_run(run_data):
			if hero != null and hero.progression_profile == profile:
				usages.append({
					"run": run_data,
					"run_path": run_data.resource_path,
					"character_id": hero.character_id,
				})
	return usages


static func is_shared_between_runs(resource: Resource) -> bool:
	if resource == null:
		return false
	var run_paths := {}
	for run_data in discover_runs():
		for hero in heroes_for_run(run_data):
			if hero == null or hero.progression_profile == null:
				continue
			for candidate in RunProgressionCloneService.progression_resources(hero.progression_profile):
				if candidate == resource or (
						not resource.resource_path.is_empty()
						and candidate.resource_path == resource.resource_path
					):
					run_paths[run_data.resource_path] = true
	return run_paths.size() > 1


static func create_run_specific_copy(
		base_unit_data: UnitData,
		source: CharacterProgressionProfile,
		destination_path: String,
		run_id: StringName
	) -> RunProgressionCloneResult:
	if source != null:
		return RunProgressionCloneService.clone_profile(source, run_id, destination_path)
	return RunProgressionCloneService.clone_from_unit(base_unit_data, run_id, destination_path)


static func as_editable_unit_view(
		base_unit_data: UnitData,
		profile: CharacterProgressionProfile
	) -> UnitData:
	if base_unit_data == null or profile == null:
		return null
	var view := base_unit_data.duplicate(false) as UnitData
	view.set_path_cache("")
	view.active_spell_slots = profile.active_spell_slots
	var view_spells: Array[Spell] = []
	view_spells.assign(profile.spells)
	view.spells = view_spells
	var view_disciplines: Array[DisciplineData] = []
	view_disciplines.assign(profile.disciplines)
	view.disciplines = view_disciplines
	return view


static func _discover_runs_recursive(path: String, runs: Array[RunData]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var resource := load(path.path_join(file_name))
		if resource is RunData:
			runs.append(resource as RunData)
	for child in directory.get_directories():
		_discover_runs_recursive(path.path_join(child), runs)
