extends GutTest

const UNIT_VIEW_SCENE := preload("res://battle/unit_view.tscn")
const ODYSSEY_RUN: RunData = preload("res://data/runs/odyssey.tres")


class ReadabilityVisual extends Node2D:
	var call_count := 0

	func set_painted_readability(
			_enabled: bool,
			_outline_color: Color,
			_outline_width_px: float,
			_shadow_enabled: bool,
			_shadow_scale: float,
			_shadow_opacity: float
		) -> void:
		call_count += 1


func test_hidden_achilles_sprite_routes_feedback_to_3d_self_modulate() -> void:
	var fixture := _create_achilles_view()
	var view = fixture[0]
	var achilles: Unit = fixture[1]
	var optional := view.get_optional_visual() as Node2D
	var sprite := view.get("_sprite") as AnimatedSprite2D
	assert_not_null(optional)
	assert_not_null(sprite)
	assert_false(sprite.visible)
	var persistent_modulate := Color(0.72, 0.81, 0.93, 0.88)
	var base_self_modulate := Color(0.91, 0.87, 0.79, 0.96)
	optional.modulate = persistent_modulate
	optional.self_modulate = base_self_modulate
	var cases := [
		["_on_damage_dealt", [achilles, null, 8, 0, 0, false], Color(1.0, 0.35, 0.28)],
		["_on_unit_healed", [achilles, 8], Color(0.42, 1.0, 0.52)],
		["_on_shield_gained", [achilles, 8], Color(0.95, 0.78, 0.24)],
		["_on_shield_absorbed", [achilles, 8], Color(0.4, 0.65, 1.0)],
		["_on_shield_broken", [achilles], Color(1.0, 0.45, 0.1)],
	]
	for entry in cases:
		view.callv(entry[0], entry[1])
		assert_eq(optional.self_modulate, entry[2], entry[0])
		assert_eq(optional.modulate, persistent_modulate, entry[0])
		assert_eq(sprite.self_modulate, Color.WHITE, entry[0])
	await get_tree().create_timer(0.3).timeout
	assert_eq(optional.self_modulate, base_self_modulate)
	assert_eq(optional.modulate, persistent_modulate)


func test_visible_base_sprite_receives_flash_without_modulate_overwrite() -> void:
	var fixture := _create_achilles_view()
	var view = fixture[0]
	var achilles: Unit = fixture[1]
	var optional := view.get_optional_visual() as Node2D
	var sprite := view.get("_sprite") as AnimatedSprite2D
	sprite.visible = true
	var persistent_modulate := Color(0.61, 0.72, 0.83, 0.94)
	var base_self_modulate := Color(0.88, 0.91, 0.95, 0.97)
	sprite.modulate = persistent_modulate
	sprite.self_modulate = base_self_modulate
	var optional_self_modulate := optional.self_modulate
	view.call("_on_damage_dealt", achilles, null, 3, 0, 0, false)
	assert_eq(sprite.self_modulate, Color(1.0, 0.35, 0.28))
	assert_eq(sprite.modulate, persistent_modulate)
	assert_eq(optional.self_modulate, optional_self_modulate)
	await get_tree().create_timer(0.2).timeout
	assert_eq(sprite.self_modulate, base_self_modulate)
	assert_eq(sprite.modulate, persistent_modulate)


func test_achilles_keeps_iso_shadow_without_painted_readability_api() -> void:
	var fixture := _create_achilles_view()
	var view = fixture[0]
	var optional := view.get_optional_visual() as Node2D
	assert_false(optional.has_method("set_painted_readability"))
	var shadow := _add_iso_shadow(view)
	view.apply_painted_presentation(BattlePresentationProfile.new(), false, true)
	assert_true(shadow.visible)


func test_optional_readability_api_replaces_iso_shadow() -> void:
	var view = UNIT_VIEW_SCENE.instantiate()
	add_child_autofree(view)
	view.unit = _create_odyssey_achilles()
	var optional := ReadabilityVisual.new()
	view.add_child(optional)
	view.set("_optional_visual", optional)
	view.set("_painted_optional_base_scale", optional.scale)
	var shadow := _add_iso_shadow(view)
	view.apply_painted_presentation(BattlePresentationProfile.new(), false, true)
	assert_false(shadow.visible)
	assert_eq(optional.call_count, 1)


func _create_achilles_view() -> Array:
	var achilles := _create_odyssey_achilles()
	var view = UNIT_VIEW_SCENE.instantiate()
	add_child_autofree(view)
	view.setup(achilles)
	return [view, achilles]


func _create_odyssey_achilles() -> Unit:
	var resolution = RunHeroResolver.resolve_runtime_hero_data(ODYSSEY_RUN, false)
	assert_not_null(resolution)
	assert_true(resolution.is_valid())
	assert_eq(resolution.heroes.size(), 1)
	return Unit.from_data(resolution.heroes[0])


func _add_iso_shadow(view: Node2D) -> Node2D:
	var shadow := Node2D.new()
	shadow.add_to_group("iso_ground_shadow")
	view.add_child(shadow)
	shadow.visible = true
	return shadow
