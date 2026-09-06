extends GutTest
## Missing cosmetic portraits cannot make gameplay resources unloadable.

const EXISTING_FRAMES := "res://assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres"
const MISSING_FRAMES := "res://assets/characters/__absent_portrait_for_regression.tres"


func test_missing_optional_portraits_return_null_without_breaking_resources() -> void:
	for resource in [UnitData.new(), CombatFormChangeData.new()]:
		resource.preview_sprite_frames_path = MISSING_FRAMES
		assert_null(resource.preview_sprite_frames)
		assert_null(resource.preview_sprite_frames)
		assert_eq(resource.preview_sprite_frames_path, MISSING_FRAMES)


func test_existing_path_resolves_and_explicit_frames_keep_priority() -> void:
	var authored := load(EXISTING_FRAMES) as SpriteFrames
	assert_not_null(authored)
	for resource in [UnitData.new(), CombatFormChangeData.new()]:
		resource.preview_sprite_frames_path = EXISTING_FRAMES
		assert_same(resource.preview_sprite_frames, authored)
		var override := SpriteFrames.new()
		resource.preview_sprite_frames = override
		assert_same(resource.preview_sprite_frames, override)
		assert_same((resource.duplicate(false)).preview_sprite_frames, override)
		resource.preview_sprite_frames = null
		assert_same(resource.preview_sprite_frames, authored)


func test_missing_path_can_be_replaced_without_caching_a_failed_load() -> void:
	for resource in [UnitData.new(), CombatFormChangeData.new()]:
		resource.preview_sprite_frames_path = MISSING_FRAMES
		assert_null(resource.preview_sprite_frames)
		resource.preview_sprite_frames_path = EXISTING_FRAMES
		assert_not_null(resource.preview_sprite_frames)


func test_paris_gameplay_and_form_load_without_their_optional_portraits() -> void:
	var paris := load("res://data/units/enemies/catabase_shadow_paris.tres") as UnitData
	assert_not_null(paris)
	if paris == null:
		return
	assert_eq(paris.preview_sprite_frames_path, "res://assets/characters/paris/sprites_v1/paris_portrait.tres")
	assert_eq(paris.spells.size(), 5)
	assert_not_null(paris.combat_form_change)
	assert_true(paris.combat_form_change.is_valid())
	assert_eq(paris.combat_form_change.preview_sprite_frames_path, "res://assets/characters/paris/sprites_v1/paris_infernal_portrait.tres")
	var unit := Unit.from_data(paris)
	assert_eq(unit.combat_form_id, &"spectral")
	unit.take_damage(97)
	assert_eq(unit.combat_form_id, &"infernal")
	assert_eq(unit.current_hp, 23, "The cosmetic fix must not heal or respawn Paris")
	assert_eq(unit.spells.size(), 4)
