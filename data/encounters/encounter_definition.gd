@tool
class_name EncounterDefinition
extends Resource

## Description immuable d'une rencontre. Les compteurs consommables vivent
## exclusivement dans EncounterRuntimeState.

const FORMATION_IDS: Array[StringName] = [
	&"line",
	&"double_line",
	&"left_flank",
	&"right_flank",
	&"chief_forward",
	&"centurion_rear",
	&"split",
]

@export_range(1, 99, 1) var room_index := 1
@export var roster_units: Array[UnitData] = []
@export var roster_counts := PackedInt32Array()
@export var allowed_spawn_groups: Array[StringName] = [&"enemy"]
@export var formation_profiles: Array[StringName] = FORMATION_IDS.duplicate()
@export_range(0, 99, 1) var living_enemy_cap := 0
@export_range(0, 99, 1) var shared_normal_summon_budget := 0
@export_range(0, 99, 1) var shared_chief_summon_budget := 0
@export var disabled_ability_ids: Array[StringName] = []

@export_group("Progression")
## Identite stable de la recompense. Elle est l'autorite d'idempotence : ni le
## numero de salle ni le nombre d'ennemis ne doivent permettre de recreer l'XP.
@export var encounter_id: StringName = &""
@export_range(0, 1000000, 1) var base_xp: int = 0
@export_range(0, 1000000, 1) var optional_xp_budget: int = 0
@export var glory_challenge: GloryChallengeData = null

@export_group("Placement")
@export_range(1, 99, 1) var maximum_formation_attempts := 7
@export var minimum_path_distance_by_role := {
	&"skeleton_normal": 6,
	&"skeleton_chief": 6,
	&"skeleton_centurion": 7,
}
@export var maximum_path_distance_by_role := {
	&"skeleton_normal": 9,
	&"skeleton_chief": 8,
	&"skeleton_centurion": 10,
}
@export_range(0, 8, 1) var summon_free_neighbor_requirement := 1
## Cellules jouables mais masquees integralement par un foreground peint.
## Elles restent dans GridData pour la navigation, mais ne peuvent pas recevoir
## une unite au deploiement initial.
@export var forbidden_initial_spawn_cells: Array[Vector2i] = []


func get_initial_enemy_count() -> int:
	var total := 0
	for count in roster_counts:
		total += maxi(0, count)
	return total


func expanded_roster() -> Array[UnitData]:
	var result: Array[UnitData] = []
	for index in range(mini(roster_units.size(), roster_counts.size())):
		var data := roster_units[index]
		for _copy in maxi(0, roster_counts[index]):
			result.append(data)
	return result


func is_ability_enabled(ability_id: StringName) -> bool:
	return ability_id != &"" and not disabled_ability_ids.has(ability_id)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if room_index <= 0:
		errors.append("room_index doit etre positif.")
	if roster_units.is_empty() or roster_units.size() != roster_counts.size():
		errors.append("roster_units et roster_counts doivent etre non vides et paralleles.")
	if (base_xp > 0 or optional_xp_budget > 0 or glory_challenge != null) \
			and encounter_id == &"":
		errors.append("Une rencontre recompensee exige un encounter_id stable.")
	if glory_challenge != null:
		errors.append_array(glory_challenge.validation_errors())
		if not is_equal_approx(glory_challenge.xp_multiplier, 1.30):
			errors.append("Le multiplicateur de Gloire Odyssey doit etre egal a 1,30.")
	var seen := {}
	for index in range(mini(roster_units.size(), roster_counts.size())):
		var data := roster_units[index]
		if data == null or roster_counts[index] <= 0:
			errors.append("Entree de roster invalide a l'index %d." % index)
			continue
		var unit_id := data.get_effective_unit_id()
		if seen.has(unit_id):
			errors.append("UnitData dupliquee dans le roster : %s." % unit_id)
		seen[unit_id] = true
	var initial_count := get_initial_enemy_count()
	if living_enemy_cap < initial_count:
		errors.append("Le plafond vivant est inferieur au roster initial.")
	if formation_profiles.is_empty():
		errors.append("Aucune formation autorisee.")
	for formation_id in formation_profiles:
		if formation_id not in FORMATION_IDS:
			errors.append("Formation inconnue : %s." % formation_id)
	var seen_forbidden := {}
	for cell in forbidden_initial_spawn_cells:
		if seen_forbidden.has(cell):
			errors.append("Cellule de spawn interdite dupliquee : %s." % cell)
		seen_forbidden[cell] = true
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
