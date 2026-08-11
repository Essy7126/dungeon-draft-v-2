@tool
class_name RunContentProfile
extends Resource

@export var schema_version: int = 1
@export var profile_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var hero_profiles: Array[RunHeroProfile] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != 1:
		errors.append("Version de profil de contenu non prise en charge : %d." % schema_version)
	if str(profile_id).strip_edges().is_empty():
		errors.append("Le profile_id est absent.")
	if display_name.strip_edges().is_empty():
		errors.append("Le nom du profil de contenu est absent.")
	if hero_profiles.is_empty():
		errors.append("Le profil de contenu doit contenir au moins un heros.")
	var seen := {}
	for index in range(hero_profiles.size()):
		var hero_profile := hero_profiles[index]
		if hero_profile == null:
			errors.append("Le profil de heros %d est absent." % index)
			continue
		if seen.has(hero_profile.character_id):
			errors.append("Le heros %s est duplique." % hero_profile.character_id)
		seen[hero_profile.character_id] = true
		errors.append_array(hero_profile.validation_errors())
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
