extends GutTest

const ICON_ROOT := "res://asset/ui/recraft_hud_v1/icons/achilles_v1"
const MANIFEST_PATH := ICON_ROOT + "/icon_manifest_v1.json"
const EXPECTED_ICON_FILES := [
	"ability_achilles_spear_thrust.svg",
	"ability_achilles_advance.svg",
	"ability_achilles_sweep.svg",
	"ability_achilles_guard.svg",
	"action_move.svg",
	"action_end_turn.svg",
	"resource_action_points.svg",
	"resource_movement_points.svg",
	"state_cooldown.svg",
	"state_locked.svg",
	"state_unavailable.svg",
	"state_resolving.svg",
	"target_valid.svg",
	"target_invalid.svg",
]


func test_manifest_maps_every_expected_icon_to_an_existing_resource() -> void:
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	assert_false(manifest_text.is_empty(), MANIFEST_PATH)
	var manifest_value: Variant = JSON.parse_string(manifest_text)
	assert_typeof(manifest_value, TYPE_DICTIONARY)
	if not manifest_value is Dictionary:
		return
	var manifest := manifest_value as Dictionary
	assert_eq(manifest.get("schema", ""), "dungeon-draft.hud-icon-kit.v1")
	assert_eq(manifest.get("kit_id", ""), "achilles_hud_icons_v1")
	var mapped_paths := _collect_paths(manifest.get("icons", {}))
	assert_eq(mapped_paths.size(), EXPECTED_ICON_FILES.size())
	for file_name in EXPECTED_ICON_FILES:
		var resource_path := ICON_ROOT.path_join(file_name)
		assert_true(FileAccess.file_exists(resource_path), resource_path)
		assert_true(mapped_paths.has(resource_path), resource_path)


func test_svg_sources_follow_the_shared_monochrome_contract() -> void:
	for file_name in EXPECTED_ICON_FILES:
		var resource_path := ICON_ROOT.path_join(file_name)
		var source := FileAccess.get_file_as_string(resource_path)
		assert_false(source.is_empty(), resource_path)
		assert_string_contains(source, "width=\"64\"")
		assert_string_contains(source, "height=\"64\"")
		assert_string_contains(source, "viewBox=\"0 0 64 64\"")
		assert_string_contains(source, "stroke=\"#FFFFFF\"")
		assert_string_contains(source, "stroke-width=\"4\"")
		assert_false(source.contains("<text"), resource_path)
		assert_false(source.contains("<style"), resource_path)
		assert_false(source.contains("filter="), resource_path)
		assert_false(source.contains("mask="), resource_path)
		assert_false(source.contains("gradient"), resource_path)


func test_godot_rasterizes_every_svg_at_the_declared_canvas_size() -> void:
	for file_name in EXPECTED_ICON_FILES:
		var resource_path := ICON_ROOT.path_join(file_name)
		var image := Image.new()
		var error := image.load_svg_from_string(
			FileAccess.get_file_as_string(resource_path), 1.0
		)
		assert_eq(error, OK, resource_path)
		assert_eq(image.get_size(), Vector2i(64, 64), resource_path)
		assert_false(image.is_empty(), resource_path)


func _collect_paths(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is Dictionary:
		for nested_value: Variant in (value as Dictionary).values():
			result.append_array(_collect_paths(nested_value))
	elif value is String:
		result.append(value)
	return result
