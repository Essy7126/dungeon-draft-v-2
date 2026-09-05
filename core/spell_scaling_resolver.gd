class_name SpellScalingResolver
extends RefCounted


## Résout une valeur depuis les statistiques runtime. Une Resource absente
## conserve la valeur plate legacy; une Resource invalide échoue à zéro sans
## muter ni la Resource ni les statistiques du lanceur.
static func resolve(
		scaling: SpellScalingData,
		source: Unit,
		fallback_value: int = 0,
		level: int = 1
	) -> int:
	if scaling == null:
		return maxi(0, fallback_value)
	if source == null or not scaling.is_valid():
		return 0
	return resolve_from_values(
		scaling,
		source.attack_power.get_value(),
		source.max_hp.get_value(),
		level,
		fallback_value,
	)


## Variante pure pour les Studios, tooltips et simulations, qui ne requiert pas
## de Unit runtime et applique exactement la même formule.
static func resolve_from_values(
		scaling: SpellScalingData,
		prowess: float,
		max_hp: float,
		level: int = 1,
		fallback_value: int = 0
	) -> int:
	if scaling == null:
		return maxi(0, fallback_value)
	if not scaling.is_valid() or not is_finite(prowess) or not is_finite(max_hp):
		return 0
	var total := scaling.flat_value \
		+ prowess * scaling.prowess_coefficient \
		+ max_hp * scaling.max_hp_coefficient \
		+ scaling.level_value(level)
	var rounded := 0
	match scaling.rounding_policy:
		SpellScalingData.RoundingPolicy.FLOOR:
			rounded = int(floor(total))
		SpellScalingData.RoundingPolicy.CEIL:
			rounded = int(ceil(total))
		_:
			rounded = int(round(total))
	return maxi(0, rounded)
