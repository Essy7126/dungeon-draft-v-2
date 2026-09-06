class_name CharacterSelectionCatalog
extends RefCounted
## Browsable heroes keep the party defined by their run's content profile.
## Loading happens when the selection screen opens, not during script import.

const CATABASE_RUN_PATH := "res://data/runs/odyssey.tres"
const TRIO_RUN_PATH := "res://data/runs/first_run.tres"
const PHILOSOPHER_TRIAL_RUN_PATH := "res://data/runs/philosopher_trial.tres"


static func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_append_run_entries(entries, CATABASE_RUN_PATH)
	_append_run_entries(entries, TRIO_RUN_PATH)
	_append_run_entries(entries, PHILOSOPHER_TRIAL_RUN_PATH)
	return entries


static func _append_run_entries(entries: Array[Dictionary], run_path: String) -> void:
	var run := load(run_path) as RunData
	if run == null:
		push_error("CharacterSelectionCatalog: aventure introuvable : %s" % run_path)
		return
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		for error in resolution.errors:
			push_error("CharacterSelectionCatalog: %s" % error)
		return
	var party_names: Array[String] = []
	for hero in resolution.heroes:
		party_names.append(hero.unit_name)
	var party_note := "Aventure solo · %s" % party_names[0]
	if party_names.size() > 1:
		party_note = "Groupe fixe · %s" % " · ".join(party_names)
	for hero in resolution.heroes:
		entries.append({
			"id": hero.get_effective_unit_id(),
			"unit": hero,
			"run": run,
			"chapter": run.run_name if run_path == PHILOSOPHER_TRIAL_RUN_PATH else ("Catabase" if run_path == CATABASE_RUN_PATH else "L’Odyssée du trio"),
			"party_note": party_note,
			"description": "Défiez le mage et son spectre au Gué du Léthé. Utilisez l’eau, la glace, la lave et les vortex pour contrer ses soins et ses protections." if run_path == PHILOSOPHER_TRIAL_RUN_PATH else _description_for(hero),
			"accent": _accent_for(hero.get_effective_unit_id()),
		})


static func _description_for(hero: UnitData) -> String:
	match hero.get_effective_unit_id():
		&"achilles":
			return "Traversez les Enfers avec Achille. Prenez l’initiative, maîtrisez la distance et opposez votre garde aux ombres de Catabase."
		&"elf":
			return "Précision, magie et soin : l’Elfe adapte ses quatre voies aux besoins du groupe et soutient ses compagnons."
		&"mage":
			return "Combinez le feu, la glace, la foudre et la terre pour contrôler le champ de bataille aux côtés de l’Elfe et du Guerrier."
		&"warrior":
			return "Ouvrez la voie à vos compagnons. Frappez, chargez et protégez le groupe au cœur de la mêlée."
	return hero.presentation_summary if not hero.presentation_summary.is_empty() else hero.description


static func _accent_for(character_id: StringName) -> Color:
	match character_id:
		&"achilles":
			return Color("d6af68")
		&"elf":
			return Color("8fbf9a")
		&"mage":
			return Color("9ea7db")
		&"warrior":
			return Color("d59578")
	return Color("d6af68")
