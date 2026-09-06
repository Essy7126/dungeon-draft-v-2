extends GutTest

const GALLERY := preload("res://tools/ui_snapshots/HudGrayboxGallery.tscn")
const RUN: RunData = preload("res://data/runs/odyssey.tres")


func test_premium_gallery_uses_the_production_loadout_and_explicit_icons() -> void:
	var was_running: bool = GameManager.run_active
	var gallery := GALLERY.instantiate() as HudGrayboxGallery
	gallery.premium_skin = true
	add_child_autofree(gallery)
	await gallery.gallery_ready
	await get_tree().process_frame
	var metrics := gallery.get_validation_metrics()
	var resolution := RunHeroResolver.resolve_runtime_hero_data(RUN, false)
	var expected: Array[String] = []
	var expected_hero: UnitData = null
	for hero in resolution.heroes:
		if hero.get_effective_unit_id() == &"achilles":
			expected_hero = hero
			for spell in hero.spells:
				expected.append(String(spell.get_effective_spell_id()))
	assert_eq(expected.size(), 4)
	assert_eq_deep(metrics.spell_ids, expected)
	assert_true(metrics.setup_valid, str(metrics.setup_errors))
	assert_eq(metrics.loadout_source, RUN.resource_path)
	assert_eq(metrics.stats_source, RUN.resource_path)
	assert_not_null(expected_hero)
	if expected_hero == null:
		return
	assert_eq(metrics.fixture_stats.max_hp, expected_hero.max_hp)
	assert_eq(metrics.fixture_stats.max_ap, expected_hero.max_ap)
	assert_eq(metrics.fixture_stats.current_ap, expected_hero.max_ap)
	assert_eq(metrics.fixture_stats.max_mp, expected_hero.max_mp)
	assert_eq(metrics.fixture_stats.current_mp, expected_hero.max_mp)
	assert_eq(metrics.fixture_stats.basic_attack_enabled, expected_hero.basic_attack_enabled)
	var fixture := gallery.get("_fixture") as Unit
	assert_same(fixture.character_data, gallery.get("_premium_hero_data"))
	assert_same(fixture.preview_visual_scene, expected_hero.preview_visual_scene)
	assert_true(metrics.synthetic_current_hp, "Damaged health is an explicit art fixture, not live run evidence.")
	assert_almost_eq(metrics.synthetic_health_ratio, 86.0 / 110.0, 0.0001)
	assert_eq(metrics.fixture_stats.current_hp, roundi(expected_hero.max_hp * metrics.synthetic_health_ratio))
	var turn_queue := gallery.get("_turn_queue") as TurnQueue
	var timeline_achilles: Unit = null
	for unit in turn_queue.get_full_order():
		if unit.unit_id == &"achilles":
			timeline_achilles = unit
	assert_not_null(timeline_achilles)
	if timeline_achilles != null:
		assert_same(timeline_achilles.character_data, gallery.get("_premium_hero_data"))
		assert_eq(timeline_achilles.max_mp.get_int(), expected_hero.max_mp)
		assert_eq(timeline_achilles.basic_attack_enabled, expected_hero.basic_attack_enabled)
		assert_eq_deep(timeline_achilles.spells.map(func(spell: Spell): return String(spell.get_effective_spell_id())), expected)
	assert_true(metrics.synthetic_availability, "Gallery states must not be presented as live combat evidence.")
	assert_eq(GameManager.run_active, was_running, "Resolving an art fixture must not start a run.")


func test_legacy_component_gallery_keeps_its_explicit_fixture() -> void:
	var gallery := GALLERY.instantiate() as HudGrayboxGallery
	add_child_autofree(gallery)
	await gallery.gallery_ready
	await get_tree().process_frame
	var metrics := gallery.get_validation_metrics()
	assert_eq(metrics.loadout_source, "legacy_component_fixture")
	assert_eq(metrics.stats_source, "legacy_component_fixture")
	assert_eq(metrics.fixture_stats.current_mp, 4, "The historical component fixture remains unchanged.")
	assert_eq(metrics.spell_ids[0], "achilles_spear_thrust")
	assert_true(metrics.setup_valid, str(metrics.setup_errors))


func test_premium_unavailable_state_keeps_explicit_ap_simulation_with_canonical_maximum() -> void:
	var gallery := GALLERY.instantiate() as HudGrayboxGallery
	gallery.premium_skin = true
	gallery.state_id = &"unavailable"
	add_child_autofree(gallery)
	await gallery.gallery_ready
	await get_tree().process_frame
	var metrics := gallery.get_validation_metrics()
	var resolved_hero := gallery.get("_premium_hero_data") as UnitData
	assert_not_null(resolved_hero)
	if resolved_hero == null:
		return
	assert_true(metrics.setup_valid, str(metrics.setup_errors))
	assert_true(metrics.synthetic_availability)
	assert_eq(metrics.fixture_stats.current_ap, mini(1, resolved_hero.max_ap))
	assert_eq(metrics.fixture_stats.max_ap, resolved_hero.max_ap)
	assert_eq(metrics.fixture_stats.current_mp, resolved_hero.max_mp)
