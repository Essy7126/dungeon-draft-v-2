extends GutTest

const Serializer := preload("res://tools/observatory/observatory_serializer.gd")


func test_serializes_godot_value_types_to_json_values() -> void:
	assert_eq(Serializer.sanitize(&"alpha"), "alpha")
	assert_eq(Serializer.sanitize(Vector2(1.5, 2.5)), {"x": 1.5, "y": 2.5})
	assert_eq(Serializer.sanitize(Vector2i(3, 4)), {"x": 3, "y": 4})
	var color := Serializer.sanitize(Color(0.1, 0.2, 0.3, 0.4)) as Dictionary
	assert_almost_eq(float(color["r"]), 0.1, 0.00001)
	assert_almost_eq(float(color["g"]), 0.2, 0.00001)
	assert_almost_eq(float(color["b"]), 0.3, 0.00001)
	assert_almost_eq(float(color["a"]), 0.4, 0.00001)


func test_serializes_arrays_and_string_keyed_dictionaries() -> void:
	var source := {&"b": [Vector2i(1, 2)], &"a": true}
	var serialized := Serializer.sanitize(source) as Dictionary
	assert_eq(serialized.keys(), ["a", "b"])
	assert_eq(serialized["b"], [{"x": 1, "y": 2}])


func test_resource_is_reduced_to_safe_type_and_res_path() -> void:
	var resource := load("res://data/units/alliés/elfe.tres") as Resource
	var serialized := Serializer.sanitize(resource) as Dictionary
	assert_eq(serialized["resource_type"], "UnitData")
	assert_eq(serialized["resource_path"], "res://data/units/alliés/elfe.tres")


func test_subresource_is_never_dumped_implicitly() -> void:
	var resource := Resource.new()
	var serialized := Serializer.sanitize(resource) as Dictionary
	assert_eq(serialized["resource_path"], "")
	assert_eq(serialized["resource_type"], "Resource")
	assert_eq(serialized.size(), 2)


func test_cycle_is_truncated_at_a_controlled_depth() -> void:
	var warnings: Array[String] = []
	var cyclic: Array = []
	cyclic.append(cyclic)
	var serialized := Serializer.sanitize(cyclic, warnings) as Array
	assert_not_null(serialized)
	assert_false(warnings.is_empty())
	assert_true("Profondeur maximale" in warnings[0])


func test_non_serializable_object_becomes_null_with_warning() -> void:
	var warnings: Array[String] = []
	var node := Node.new()
	var serialized: Variant = Serializer.sanitize(node, warnings)
	node.free()
	assert_null(serialized)
	assert_eq(warnings.size(), 1)


func test_absolute_paths_are_refused_without_leaking_the_path() -> void:
	var warnings: Array[String] = []
	var serialized: Variant = Serializer.sanitize("C:\\Users\\example\\secret.tres", warnings)
	assert_null(serialized)
	assert_eq(warnings.size(), 1)
	assert_false("example" in warnings[0])


func test_explicit_resource_only_exports_allowlisted_properties() -> void:
	var item := load(
		"res://data/items/definitions/minor_healing_potion.tres"
	) as Resource
	var serialized := Serializer.explicit_resource(
		item,
		[&"item_id", &"display_name"],
	)
	assert_true(serialized.has("item_id"))
	assert_true(serialized.has("display_name"))
	assert_false(serialized.has("icon"))
