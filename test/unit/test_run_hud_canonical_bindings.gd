extends GutTest

const ICON_ROOT := "res://asset/ui/recraft_hud_v1/icons/achilles_painted_v2/"
const THEME_PATH := "res://data/ui/achilles_hud_theme_refined.tres"
const RUN_PATHS := [
	"res://data/runs/odyssey.tres",
	"res://data/runs/philosopher_trial.tres",
]
const CANONICAL_ICON_FILES := {
	&"achilles_peleid_strike": "ability_achilles_spear_thrust.png",
	&"achilles_fulminant_dash": "ability_achilles_advance.png",
	&"achilles_pelion_shot": "ability_achilles_pelion_shot.png",
	&"achilles_bronze_guard": "ability_achilles_guard.png",
}
const LEGACY_ICON_FILES := {
	&"achilles_spear_thrust": "ability_achilles_spear_thrust.png",
	&"achilles_sweep": "ability_achilles_sweep.png",
	&"achilles_advance": "ability_achilles_advance.png",
	&"achilles_guard": "ability_achilles_guard.png",
	&"basic_attack": "ability_achilles_spear_thrust.png",
}


func test_production_run_loadouts_resolve_exact_painted_icons_without_fallback() -> void:
	for run_path in RUN_PATHS:
		var run := load(run_path) as RunData
		assert_not_null(run, run_path)
		if run == null:
			continue
		var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
		assert_true(resolution.is_valid(), str(resolution.errors))
		assert_false(resolution.used_legacy_fallback, run_path)
		assert_eq(resolution.heroes.size(), 1, run_path)
		for hero in resolution.heroes:
			assert_eq(hero.get_effective_unit_id(), &"achilles", run_path)
			assert_eq(hero.spells.size(), CANONICAL_ICON_FILES.size(), run_path)
			var theme := CharacterHUDThemeCatalog.resolve_refined(hero)
			assert_not_null(theme, run_path)
			if theme == null:
				continue
			assert_eq(theme.resource_path, THEME_PATH)
			var seen_ids: Array[StringName] = []
			for spell in hero.spells:
				var spell_id := spell.get_effective_spell_id()
				assert_true(CANONICAL_ICON_FILES.has(spell_id), str(spell_id))
				assert_false(seen_ids.has(spell_id), str(spell_id))
				seen_ids.append(spell_id)
				if CANONICAL_ICON_FILES.has(spell_id):
					_assert_explicit_texture(theme, spell, CANONICAL_ICON_FILES[spell_id])


func test_runtime_spell_copies_keep_the_canonical_hud_identity() -> void:
	var theme := load(THEME_PATH) as CharacterHUDThemeData
	var run := load(RUN_PATHS[0]) as RunData
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	assert_true(resolution.is_valid(), str(resolution.errors))
	if not resolution.is_valid():
		return
	for spell in resolution.heroes[0].spells:
		# Mastery modifiers and runtime copies keep the capability ID. There is
		# no separate base-ID API to guess from presentation variant names.
		var runtime_spell := spell.duplicate(true) as Spell
		assert_eq(runtime_spell.get_effective_spell_id(), spell.get_effective_spell_id())
		_assert_explicit_texture(theme, runtime_spell,
			CANONICAL_ICON_FILES[spell.get_effective_spell_id()])


func test_retired_capability_aliases_remain_explicit_and_distinct_from_bow() -> void:
	var theme := load(THEME_PATH) as CharacterHUDThemeData
	assert_not_null(theme)
	if theme == null:
		return
	for spell_id in LEGACY_ICON_FILES:
		var spell := Spell.new()
		spell.spell_id = spell_id
		_assert_explicit_texture(theme, spell, LEGACY_ICON_FILES[spell_id])
	assert_ne(theme.get_spell_icon(&"achilles_pelion_shot"),
		theme.get_spell_icon(&"achilles_sweep"), "A bow shot must never use the sweeping spear icon.")


func _assert_explicit_texture(theme: CharacterHUDThemeData, spell: Spell,
		file_name: String) -> void:
	var spell_id := spell.get_effective_spell_id()
	var mapped := theme.get_spell_icon(spell_id)
	assert_not_null(mapped, "Missing explicit HUD binding for %s" % spell_id)
	if mapped == null:
		return
	assert_eq(mapped.resource_path, ICON_ROOT + file_name, str(spell_id))
	assert_same(theme.get_spell_icon_for(spell), mapped,
		"Canonical and legacy bindings must not silently use spell.icon.")
