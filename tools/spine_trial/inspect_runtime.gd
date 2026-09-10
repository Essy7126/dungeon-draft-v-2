extends SceneTree


func _initialize() -> void:
	var result := { }
	for class_name_to_inspect in [
		"SpineSprite",
		"SpineAnimationState",
		"SpineSkeleton",
		"SpineBone",
		"SpineTrackEntry",
		"SpineAnimation",
		"SpineEvent",
		"SpineEventData",
		"SpineSkeletonFileResource",
		"SpineAtlasResource",
		"SpineSkeletonDataResource",
	]:
		result[class_name_to_inspect] = (
			ClassDB.class_get_method_list(class_name_to_inspect, true)
			if ClassDB.class_exists(class_name_to_inspect)
			else []
		)
	result["sprite_constants"] = ClassDB.class_get_integer_constant_list("SpineSprite", true)
	result["sprite_signals"] = ClassDB.class_get_signal_list("SpineSprite", true)
	var output := FileAccess.open("res://artifacts/spine_trial/runtime_api.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	quit(0 if ClassDB.class_exists("SpineSprite") else 1)
