extends GutTest

const PROFILE_SAVE_ROOT := "user://studio_spell_icon_runtime"
const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
)
const REPLACEMENT_ICON_PATH := (
	"res://asset/ui/character_hud/refined/spells/sneak_strike.png"
)
const CHARACTER_CASES := [
	{
		"profile": "res://data/runs/progression/main/elf_progression_profile.tres",
		"test_profile": "res://data/runs/progression/test/elf_progression_profile.tres",
		"theme": "res://data/ui/elf_hud_theme_refined.tres",
	},
	{
		"profile": "res://data/runs/progression/main/mage_progression_profile.tres",
		"test_profile": "res://data/runs/progression/test/mage_progression_profile.tres",
		"theme": "res://data/ui/mage_hud_theme_refined.tres",
	},
	{
		"profile": "res://data/runs/progression/main/warrior_progression_profile.tres",
		"test_profile": "res://data/runs/progression/test/warrior_progression_profile.tres",
		"theme": "res://data/ui/warrior_hud_theme_refined.tres",
	},
	{
		"profile": "res://data/runs/progression/odyssey/achilles_progression_profile.tres",
		"test_profile": "",
		"theme": "res://data/ui/achilles_hud_theme_refined.tres",
	},
]
var _temporary_files := PackedStringArray()


func before_each() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PROFILE_SAVE_ROOT)
	), OK)


func after_each() -> void:
	for path in _temporary_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temporary_files.clear()


func test_playable_spells_own_their_canonical_icon() -> void:
	for character_case: Dictionary in CHARACTER_CASES:
		_assert_profile_spell_icons(character_case.profile)
		if not character_case.test_profile.is_empty():
			_assert_profile_spell_icons(character_case.test_profile)


func test_refined_themes_fall_back_to_the_canonical_spell_icon() -> void:
	for character_case: Dictionary in CHARACTER_CASES:
		var profile = load(character_case.profile)
		var theme = load(character_case.theme)
		assert_not_null(profile, character_case.profile)
		assert_not_null(theme, character_case.theme)
		if profile == null or theme == null:
			continue
		for spell in profile.spells:
			assert_false(
				theme.spell_icon_mapping.has(spell.get_effective_spell_id()),
				"Le thème raffiné ne doit pas dupliquer l’icône de %s." % spell.spell_name
			)
			assert_eq(
				theme.get_spell_icon_for(spell),
				spell.icon,
				"Le thème raffiné doit retomber sur Spell.icon pour %s." % spell.spell_name
			)


func test_studio_icon_edit_is_saved_reloaded_and_displayed_by_runtime() -> void:
	var source_run := load(
		"res://data/runs/fixed_trio_prototype_run.tres"
	) as RunData
	assert_not_null(source_run)
	var source_hero := RunContentCatalogService.heroes_for_run(source_run).filter(
		func(hero: RunHeroProfile): return hero.character_id == &"elf"
	)[0] as RunHeroProfile
	var profile_copy := source_hero.progression_profile.duplicate(true) \
		as CharacterProgressionProfile
	profile_copy.set_path_cache("")
	var suffix := str(Time.get_ticks_usec())
	var profile_path := PROFILE_SAVE_ROOT.path_join("profile_%s.tres" % suffix)
	var run_path := PROFILE_SAVE_ROOT.path_join("run_%s.tres" % suffix)
	_temporary_files.append(profile_path)
	_temporary_files.append(run_path)
	assert_eq(ResourceSaver.save(profile_copy, profile_path), OK)

	var hero_fixture := RunHeroProfile.new()
	hero_fixture.character_id = &"elf"
	hero_fixture.base_unit_data = source_hero.base_unit_data
	hero_fixture.progression_profile = ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	var content := RunContentProfile.new()
	content.profile_id = &"studio_spell_icon_runtime"
	content.display_name = "Fixture icône Studio vers runtime"
	content.hero_profiles = [hero_fixture]
	var run_fixture := RunData.new()
	run_fixture.run_name = "Fixture icône Studio vers runtime"
	run_fixture.content_profile = content
	assert_eq(ResourceSaver.save(run_fixture, run_path), OK)

	var canonical_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var canonical_hero := RunContentCatalogService.heroes_for_run(canonical_run)[0]
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(canonical_run, canonical_hero))
	var working_spell := _spell_by_id(
		session.working_unit.spells, &"elf_precise_shot"
	)
	var source_spell := _spell_by_id(
		session.source_progression_profile.spells, &"elf_precise_shot"
	)
	var replacement_icon := load(REPLACEMENT_ICON_PATH) as Texture2D
	assert_not_null(working_spell)
	assert_not_null(source_spell)
	assert_not_null(replacement_icon)
	assert_ne(source_spell.icon.resource_path, REPLACEMENT_ICON_PATH)

	var sheet := SkillTreeCharacterScreen.new()
	add_child_autofree(sheet)
	sheet.property_change_requested.connect(
		func(target: Object, property_name: StringName, value: Variant, action_name: String):
			session.change_property(target, property_name, value, action_name)
	)
	sheet.call(
		"_emit_target_change", working_spell, &"icon", replacement_icon,
		"Modifier Icône"
	)
	assert_eq(working_spell.icon.resource_path, REPLACEMENT_ICON_PATH)
	assert_ne(source_spell.icon.resource_path, REPLACEMENT_ICON_PATH)
	assert_true(session.is_dirty())

	var plan := SkillTreeSaveTransactionService.build_plan(session, {
		"allowed_roots": PackedStringArray([PROFILE_SAVE_ROOT + "/", "res://data/"]),
	})
	assert_false(plan.has_blocking_conflicts(), str(plan.conflicts))
	assert_true(plan.writable_entries().any(
		func(entry): return entry.target_path == profile_path
	))
	var saved := SkillTreeSaveTransactionService.save(session, null, {
		"allowed_roots": PackedStringArray([PROFILE_SAVE_ROOT + "/", "res://data/"]),
	})
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false):
		session.release_document(false)
		return
	assert_true((saved.saved_paths as PackedStringArray).has(profile_path))
	assert_false((saved.saved_paths as PackedStringArray).has(run_path))
	assert_false(session.is_dirty())

	var reloaded_profile := ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	var runtime_spell := _spell_by_id(
		reloaded_profile.spells, &"elf_precise_shot"
	)
	assert_eq(runtime_spell.icon.resource_path, REPLACEMENT_ICON_PATH)
	var runtime_unit := RunContentCatalogService.as_editable_unit_view(
		canonical_hero.base_unit_data, reloaded_profile
	)
	var runtime_theme := CharacterHUDThemeCatalog.resolve_refined(runtime_unit)
	assert_not_null(runtime_theme)
	assert_eq(
		runtime_theme.get_spell_icon_for(runtime_spell).resource_path,
		REPLACEMENT_ICON_PATH
	)
	var slot = SPELL_SLOT_SCENE.instantiate()
	add_child_autofree(slot)
	await get_tree().process_frame
	slot.configure(runtime_spell, runtime_spell.ap_cost, "1")
	slot.set_icon_override(runtime_theme.get_spell_icon_for(runtime_spell))
	assert_eq(slot.get_displayed_icon().resource_path, REPLACEMENT_ICON_PATH)
	assert_true(session.reopen_from_disk())
	assert_eq(
		_spell_by_id(session.working_unit.spells, &"elf_precise_shot").icon.resource_path,
		REPLACEMENT_ICON_PATH
	)
	session.release_document(false)


func _assert_profile_spell_icons(profile_path: String) -> void:
	var profile = load(profile_path)
	assert_not_null(profile, profile_path)
	if profile == null:
		return
	for spell in profile.spells:
		assert_not_null(
			spell.icon,
			"%s doit définir son icône canonique dans %s." % [spell.spell_name, profile_path]
		)


func _spell_by_id(spells: Array, spell_id: StringName) -> Spell:
	for spell_value in spells:
		var spell := spell_value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null
