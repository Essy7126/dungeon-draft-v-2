@tool
class_name ItemReactiveParameterData
extends Resource

## Paramètre fermé et typé d'un résultat réactif. Les reliques ne stockent ni
## expression, ni Callable, ni chemin de script : le registre valide chaque
## valeur contre le schéma du descripteur de résultat.

enum ValueType {
	FLOAT,
	INTEGER,
	BOOLEAN,
	STRING_NAME,
}

@export var parameter_id: StringName = &""
@export var value_type: ValueType = ValueType.FLOAT
@export var float_value := 0.0
@export var integer_value := 0
@export var boolean_value := false
@export var string_name_value: StringName = &""


func resolved_value() -> Variant:
	match value_type:
		ValueType.INTEGER:
			return integer_value
		ValueType.BOOLEAN:
			return boolean_value
		ValueType.STRING_NAME:
			return string_name_value
	return float_value


func is_valid() -> bool:
	return parameter_id != &"" \
		and value_type in ValueType.values() \
		and (value_type != ValueType.FLOAT or is_finite(float_value))


func validation_error(schema: Dictionary) -> String:
	if not is_valid():
		return "Paramètre vide, type invalide ou valeur non finie."
	if int(schema.get("type", -1)) != value_type:
		return "Le type ne correspond pas au schéma enregistré."
	var value: Variant = resolved_value()
	if bool(schema.get("non_empty", false)) and str(value).is_empty():
		return "Une valeur non vide est obligatoire."
	if value_type in [ValueType.FLOAT, ValueType.INTEGER]:
		var numeric := float(value)
		if schema.has("minimum") and numeric < float(schema.minimum):
			return "La valeur est inférieure au minimum autorisé."
		if schema.has("maximum") and numeric > float(schema.maximum):
			return "La valeur dépasse le maximum autorisé."
	var allowed := schema.get("allowed", []) as Array
	if not allowed.is_empty() and value not in allowed:
		return "La valeur n'appartient pas à l'ensemble autorisé."
	return ""


func to_snapshot() -> Dictionary:
	return {
		"parameter_id": str(parameter_id),
		"value_type": int(value_type),
		"value": resolved_value(),
	}
