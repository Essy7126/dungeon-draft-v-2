@tool
class_name SpellScalingData
extends Resource

## Politique unique d'arrondi pour le runtime, les Studios, les tooltips et les
## simulations. NEAREST utilise l'arrondi entier standard de Godot.
enum RoundingPolicy {
	NEAREST,
	FLOOR,
	CEIL,
}

@export var flat_value: float = 0.0
@export var prowess_coefficient: float = 0.0
@export var max_hp_coefficient: float = 0.0
## Bonus plat par niveau, indexé depuis le niveau 1. Un niveau au-delà de la
## courbe conserve sa dernière valeur; une courbe vide ajoute zéro.
@export var level_curve: PackedFloat32Array = PackedFloat32Array()
@export var rounding_policy: RoundingPolicy = RoundingPolicy.NEAREST


func has_effect() -> bool:
	if not is_zero_approx(flat_value) \
			or not is_zero_approx(prowess_coefficient) \
			or not is_zero_approx(max_hp_coefficient):
		return true
	for value in level_curve:
		if not is_zero_approx(value):
			return true
	return false


func is_valid() -> bool:
	if not is_finite(flat_value) \
			or not is_finite(prowess_coefficient) \
			or not is_finite(max_hp_coefficient):
		return false
	for value in level_curve:
		if not is_finite(value):
			return false
	return true


func level_value(level: int) -> float:
	if level_curve.is_empty():
		return 0.0
	var index := clampi(maxi(1, level) - 1, 0, level_curve.size() - 1)
	return level_curve[index]
