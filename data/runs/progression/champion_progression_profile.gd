@tool
class_name ChampionProgressionProfile
extends Resource

const ATTRIBUTE_VITALITY: StringName = &"vitality"
const ATTRIBUTE_POWER: StringName = &"power"
const ATTRIBUTE_RESOLVE: StringName = &"resolve"
const ATTRIBUTE_WISDOM: StringName = &"wisdom"
const ATTRIBUTE_IDS: Array[StringName] = [
	ATTRIBUTE_VITALITY,
	ATTRIBUTE_POWER,
	ATTRIBUTE_RESOLVE,
	ATTRIBUTE_WISDOM,
]

@export var schema_version: int = 1
@export_range(1, 99, 1) var level_cap: int = 14
@export var cumulative_xp_thresholds: PackedInt32Array = PackedInt32Array()
@export var base_hp_by_level: PackedInt32Array = PackedInt32Array()
@export var base_prowess_by_level: PackedInt32Array = PackedInt32Array()
@export var attribute_point_levels: PackedInt32Array = PackedInt32Array()
@export var mastery_point_levels: PackedInt32Array = PackedInt32Array()

@export_group("Caractéristiques")
@export_range(0.0, 1.0, 0.01) var vitality_hp_percent_per_point: float = 0.06
@export_range(0.0, 1.0, 0.01) var power_prowess_percent_per_point: float = 0.05
@export_range(0, 100, 1) var resolve_armor_per_point: int = 4
@export_range(0.0, 1.0, 0.01) var resolve_shield_percent_per_point: float = 0.05
@export_range(0.0, 1.0, 0.01) var wisdom_bonus_per_point: float = 0.10
@export_range(0, 99, 1) var wisdom_cap: int = 5
@export_range(1.0, 3.0, 0.01) var glory_success_multiplier: float = 1.30
@export_range(0, 99, 1) var purchased_mastery_cap: int = 3

@export_group("Gates de maîtrise")
@export_range(1, 99, 1) var first_capstone_level: int = 10
@export_range(1, 99, 1) var second_capstone_level: int = 13
@export_range(1, 99, 1) var specialist_summit_level: int = 13
@export_range(1, 99, 1) var mythic_junction_level: int = 14
@export_range(1, 99, 1) var apotheosis_level: int = 14

## Extension générique pour les courbes de scaling propres à une progression.
## Les valeurs restent des Resources et sont clonées/remappées avec le profil.
@export var spell_scaling_profiles: Dictionary = {}


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != 1:
		errors.append("Version de profil Champion non prise en charge : %d." % schema_version)
	if level_cap < 1:
		errors.append("Le plafond de niveau Champion doit être positif.")
	for curve in [
		cumulative_xp_thresholds,
		base_hp_by_level,
		base_prowess_by_level,
	]:
		if curve.size() != level_cap:
			errors.append(
				"Chaque courbe Champion doit couvrir exactement les niveaux 1 à %d."
				% level_cap
			)
	if not cumulative_xp_thresholds.is_empty():
		if cumulative_xp_thresholds[0] != 0:
			errors.append("La courbe XP Champion doit commencer à zéro.")
		for index in range(1, cumulative_xp_thresholds.size()):
			if cumulative_xp_thresholds[index] <= cumulative_xp_thresholds[index - 1]:
				errors.append("La courbe XP Champion doit être strictement croissante.")
	for value in base_hp_by_level:
		if value <= 0:
			errors.append("Les PV de base Champion doivent être positifs.")
	for value in base_prowess_by_level:
		if value < 0:
			errors.append("La Prouesse Champion ne peut pas être négative.")
	errors.append_array(_validate_reward_levels(
		attribute_point_levels, "caractéristique"
	))
	errors.append_array(_validate_reward_levels(
		mastery_point_levels, "maîtrise"
	))
	if wisdom_cap < 0 \
			or not is_finite(wisdom_bonus_per_point) \
			or wisdom_bonus_per_point < 0.0:
		errors.append("La configuration de Sagesse est invalide.")
	if purchased_mastery_cap < 0:
		errors.append("Le plafond de maîtrises achetées ne peut pas être négatif.")
	if not is_equal_approx(glory_success_multiplier, 1.30):
		errors.append("Le multiplicateur de Gloire Odyssey doit être égal à 1,30.")
	if not is_finite(vitality_hp_percent_per_point) \
			or not is_finite(power_prowess_percent_per_point) \
			or not is_finite(resolve_shield_percent_per_point) \
			or vitality_hp_percent_per_point < 0.0 \
			or power_prowess_percent_per_point < 0.0 \
			or resolve_shield_percent_per_point < 0.0 \
			or resolve_armor_per_point < 0:
		errors.append("Les coefficients de caractéristiques sont invalides.")
	for gate in [
		first_capstone_level,
		second_capstone_level,
		specialist_summit_level,
		mythic_junction_level,
		apotheosis_level,
	]:
		if gate < 1 or gate > level_cap:
			errors.append("Une gate de maîtrise est hors de la courbe Champion.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func level_for_xp(total_xp: int) -> int:
	var level := 1
	for index in range(cumulative_xp_thresholds.size()):
		if total_xp < cumulative_xp_thresholds[index]:
			break
		level = index + 1
	return clampi(level, 1, level_cap)


func xp_for_level(level: int) -> int:
	return cumulative_xp_thresholds[clampi(level, 1, level_cap) - 1]


func base_hp_for_level(level: int) -> int:
	return base_hp_by_level[clampi(level, 1, level_cap) - 1]


func base_prowess_for_level(level: int) -> int:
	return base_prowess_by_level[clampi(level, 1, level_cap) - 1]


func attribute_points_through_level(level: int) -> int:
	return _reward_points_through_level(attribute_point_levels, level)


func mastery_points_through_level(level: int) -> int:
	return _reward_points_through_level(mastery_point_levels, level)


func encounter_xp(
		base_xp: int,
		wisdom_at_encounter_start: int,
		glory_accepted: bool,
		glory_succeeded: bool
	) -> int:
	var wisdom := clampi(wisdom_at_encounter_start, 0, wisdom_cap)
	var glory_multiplier := (
		glory_success_multiplier if glory_accepted and glory_succeeded else 1.0
	)
	return maxi(0, int(round(
		float(maxi(0, base_xp))
		* (1.0 + wisdom_bonus_per_point * float(wisdom))
		* glory_multiplier
	)))


func effective_max_hp(level: int, vitality_points: int) -> int:
	return int(round(
		float(base_hp_for_level(level))
		* (1.0 + vitality_hp_percent_per_point * float(maxi(0, vitality_points)))
	))


func effective_prowess(level: int, power_points: int) -> int:
	return int(round(
		float(base_prowess_for_level(level))
		* (1.0 + power_prowess_percent_per_point * float(maxi(0, power_points)))
	))


func _reward_points_through_level(levels: PackedInt32Array, level: int) -> int:
	var total := 0
	for reward_level in levels:
		if reward_level <= level:
			total += 1
	return total


func _validate_reward_levels(
		levels: PackedInt32Array,
		label: String
	) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for level in levels:
		if level < 2 or level > level_cap:
			errors.append("Niveau de point de %s hors limites : %d." % [label, level])
		elif seen.has(level):
			errors.append("Niveau de point de %s dupliqué : %d." % [label, level])
		seen[level] = true
	return errors
