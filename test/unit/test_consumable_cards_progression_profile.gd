extends GutTest
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")
const Profile := preload("res://core/expedition/consumable_progression_profile.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")
const Factory := preload("res://test/support/factory.gd")


func extended_rules() -> Dictionary:
	# Synthetic contract fixture, not an act II balance proposal or playable route.
	var source: Dictionary = Catalog.data().rules
	source.prototypeProgression.id = "test_campaign_18"
	source.prototypeProgression.levelCap = 18
	source.prototypeProgression.power.append_array([103, 114, 126, 139, 153, 168])
	source.hp.append_array([715, 760, 810, 865, 925, 990])
	source.prowess.append_array([120, 129, 139, 150, 162, 175])
	source.xpThresholds.append_array([2630, 2990, 3380, 3800, 4250, 4730])
	source.prototypeProgression.aptitudeLevels.append_array([12, 15, 18])
	source.trainingLevels.append(16)
	return source


func test_published_profile_matches_current_playable_numbers() -> void:
	var profile = Rules.profile()
	assert_eq(Profile.validation_errors(Catalog.data().rules), [])
	assert_eq(profile.id(), "paris_act_1_v1")
	assert_eq(
		profile.level_row(1),
		{
			"level": 1,
			"hp": 110,
			"power": 16,
			"legacy_power": 18,
			"xp_threshold": 0,
			"element_points": 4,
			"aptitude_points": 0,
			"training_slots": 0,
		},
	)
	assert_eq(
		profile.level_row(12),
		{
			"level": 12,
			"hp": 675,
			"power": 93,
			"legacy_power": 112,
			"xp_threshold": 2300,
			"element_points": 26,
			"aptitude_points": 3,
			"training_slots": 3,
		},
	)
	assert_eq(profile.aptitude_rank_cap(), 3)
	assert_eq(profile.specialization_level(), 4)
	assert_almost_eq(profile.mastery(26), .38, .000001)


func test_invalid_levels_cannot_silently_become_the_level_twelve_row() -> void:
	for level in [-1, 0, 13, 18]:
		assert_eq(Rules.profile().level_row(level), { })
		assert_eq(Math.stats(level, { }, { }), { })
		assert_eq(Rules.element_budget(level), -1)
		assert_eq(Rules.aptitude_budget(level), -1)
		assert_eq(Rules.training_slots(level), -1)
		assert_false(
			Rules.valid_allocation(
				Rules.empty_elements(),
				Rules.ELEMENTS,
				Rules.element_budget(level),
				Rules.element_point_cap(),
			)
		)


func test_profile_requires_complete_finite_integer_curves_and_strict_xp() -> void:
	for key in ["hp", "prowess", "xpThresholds"]:
		var source: Dictionary = Catalog.data().rules
		source[key].pop_back()
		assert_null(Profile.from_rules(source), key + " missing level")
		for invalid in [-1, 1.25, INF, NAN, 2147483648, "675", true]:
			source = Catalog.data().rules
			source[key][3] = invalid
			assert_null(Profile.from_rules(source), "%s : %s" % [key, invalid])
	var source: Dictionary = Catalog.data().rules
	source.prototypeProgression.power.pop_back()
	assert_null(Profile.from_rules(source))
	source = Catalog.data().rules
	source.xpThresholds[2] = source.xpThresholds[1]
	assert_null(Profile.from_rules(source), "duplicate XP thresholds")
	source.xpThresholds[2] = 50
	assert_null(Profile.from_rules(source), "descending XP thresholds")
	source = Catalog.data().rules
	source.xpThresholds[0] = 1
	assert_null(Profile.from_rules(source), "level one starts at zero")
	source = Catalog.data().rules
	source.hp[0] = 0
	assert_null(Profile.from_rules(source), "a champion must have positive HP")


func test_catalog_rejects_invalid_progression_before_publication() -> void:
	var manifest := Catalog.data()
	manifest.rules.prototypeProgression.levelCap = 18
	assert_false(Catalog.validation_errors(manifest).is_empty(), "cap alone is not an extension")
	manifest = Catalog.data()
	manifest.rules.erase("prototypeProgression")
	assert_false(Catalog.validation_errors(manifest).is_empty())


func test_invalid_rewards_gains_and_bands_are_rejected() -> void:
	for key in [
		"initialElementPoints",
		"elementPointsPerLevel",
		"aptitudeRankCap",
		"specializationLevel",
		"levelCap",
	]:
		for invalid in [-1, 2.5, INF, NAN, "4", true]:
			var source: Dictionary = Catalog.data().rules
			source.prototypeProgression[key] = invalid
			assert_null(Profile.from_rules(source), "%s : %s" % [key, invalid])
	for invalid in [[3, 3], [6, 3], [0], [13], [3.5], ["3"]]:
		var source: Dictionary = Catalog.data().rules
		source.prototypeProgression.aptitudeLevels = invalid
		assert_null(Profile.from_rules(source))
		source = Catalog.data().rules
		source.trainingLevels = invalid
		assert_null(Profile.from_rules(source))
	for invalid in [-.01, INF, NAN, 1.01, "0.08"]:
		var source: Dictionary = Catalog.data().rules
		source.prototypeProgression.aptitudeGains.vitality = invalid
		assert_null(Profile.from_rules(source))
	for invalid in [
		[],
		[{ "upTo": 4, "gain": .03 }],
		[{ "upTo": 0, "gain": .03 }, { "upTo": 0, "gain": .01 }],
		[{ "upTo": 4, "gain": NAN }, { "upTo": 0, "gain": .01 }],
		[{ "upTo": 4.5, "gain": .03 }, { "upTo": 0, "gain": .01 }],
	]:
		var source: Dictionary = Catalog.data().rules
		source.prototypeProgression.masteryBands = invalid
		assert_null(Profile.from_rules(source))
	for invalid in [2, 1.5, INF, NAN, "1", true]:
		var incompatible: Dictionary = Catalog.data().rules
		incompatible.prototypeProgression.schemaVersion = invalid
		assert_null(Profile.from_rules(incompatible))
	var source: Dictionary = Catalog.data().rules
	source = Catalog.data().rules
	source.prototypeProgression.id = " "
	assert_null(Profile.from_rules(source))


func test_profile_and_compatibility_views_are_detached() -> void:
	var source := extended_rules()
	var profile = Profile.from_rules(source)
	source.hp[17] = 1
	source.prototypeProgression.power[17] = 1
	profile.curve("hp")[17] = 1
	profile.aptitude_gains().vitality = 1
	profile.level_row(18).hp = 1
	assert_eq(profile.level_row(18).hp, 990)
	assert_eq(profile.level_row(18).power, 168)
	assert_almost_eq(float(profile.aptitude_gains().vitality), .08, .000001)
	Rules.POWER[11] = 1
	Rules.APTITUDE_GAINS.contact = 1
	assert_eq(Rules.POWER[11], 93)
	assert_almost_eq(float(Rules.APTITUDE_GAINS.contact), .06, .000001)


func test_extended_profile_drives_shared_xp_adapter_and_reward_budgets() -> void:
	var profile = Profile.from_rules(extended_rules())
	assert_not_null(profile)
	if profile == null:
		return
	var champion := ChampionProgressionProfile.new()
	Integration.configure_profile(champion, profile)
	assert_true(champion.validation_errors().is_empty())
	assert_eq(champion.level_cap, 18)
	assert_eq(champion.cumulative_xp_thresholds[17], 4730)
	assert_eq(champion.base_hp_by_level[17], 990)
	assert_eq(champion.base_prowess_by_level[17], 175, "shared legacy intermediate power preserved")
	assert_eq(profile.element_budget(18), 38)
	assert_eq(profile.aptitude_budget(18), 6)
	assert_eq(profile.training_slots(18), 4)
	assert_almost_eq(profile.mastery(38), .50, .000001)
	assert_eq(profile.level_row(19), { })
	assert_eq(Rules.level_cap(), 12, "laboratory does not select an unpublished campaign")
	var hero: Unit = autofree(Factory.make_unit("Extended champion", 0))
	var progression := ChampionProgressionState.new()
	assert_true(progression.initialize(champion, hero))
	assert_true(progression.award_encounter_xp(&"act_one_end", 2300, true).granted)
	assert_eq(progression.current_level, 12)
	assert_true(progression.award_encounter_xp(&"act_two_end", 2430, true).granted)
	assert_eq(progression.current_level, 18)
	assert_false(progression.award_encounter_xp(&"act_two_end", 2430, true).granted)
	assert_eq(progression.current_xp, 4730, "encounter receipt cannot double its XP")
	assert_eq(progression.unspent_attribute_points, 0, "cards remain the allocation owner")
	assert_eq(progression.unspent_mastery_points, 0)
	progression.dispose()


func test_extended_profile_is_used_by_stats_and_every_component_path() -> void:
	var source := extended_rules()
	source.prototypeProgression.aptitudeGains.contact = .11
	source.prototypeProgression.aptitudeGains.distance = .09
	source.prototypeProgression.aptitudeGains.protection = .12
	source.prototypeProgression.masteryBands = [{ "upTo": 0, "gain": .02 }]
	var profile = Profile.from_rules(source)
	var cards = Cards.new()
	cards.initialize_deck(Catalog.preset("thaumaturge"))
	cards.masteries.fire = 38
	cards.aptitudes = { "vitality": 3, "protection": 1, "contact": 1, "distance": 1 }
	var stats := Math.stats(18, { }, { }, cards, profile)
	assert_eq(stats.hp, 1228)
	assert_eq(stats.power, 168.0)
	assert_eq(stats.ap, 4)
	assert_eq(stats.mp, 3)
	assert_eq(stats.hand, 5)
	assert_almost_eq(float(stats.guard), .12, .000001)
	var card := {
		"op": "hit",
		"type": "magic",
		"damage": .5,
		"amount": .2,
		"elements": { "damage": { "fire": 1.0 }, "amount": { "fire": 1.0 } },
	}
	var contact := Math.impact(
		card,
		stats.power,
		{ "distance": 1 },
		{ },
		"thaumaturge",
		"",
		{ },
		cards,
		profile,
	)
	var ranged := Math.impact(
		card,
		stats.power,
		{ "distance": 3 },
		{ },
		"thaumaturge",
		"",
		{ },
		cards,
		profile,
	)
	assert_almost_eq(float(contact.raw), 84.0 * (1.0 + .76 + .11), .000001)
	assert_almost_eq(float(ranged.raw), 84.0 * (1.0 + .76 + .09), .000001)
	assert_almost_eq(
		Math.component(card, "amount", 168.0, cards, "guard", 0.0, { }, profile),
		33.6 * (1.0 + .76 + .12),
		.000001,
	)
	assert_almost_eq(
		Math.component(card, "amount", 168.0, cards, "heal", 0.0, { }, profile),
		33.6 * (1.0 + .76),
		.000001,
	)
	assert_eq(Math.stats(19, { }, { }, cards, profile), { })


func test_save_pins_profile_and_keeps_old_saves_compatible_atomically() -> void:
	var cards = Cards.new()
	cards.initialize_deck(Catalog.preset("assassin"))
	cards.level = 12
	cards.masteries.night = 26
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(cards.snapshot()))
	assert_eq(snapshot.progression_profile_id, "paris_act_1_v1")
	var restored = Cards.new()
	assert_true(restored.restore(snapshot))
	var before: Dictionary = restored.snapshot()
	snapshot.progression_profile_id = "test_campaign_18"
	assert_false(restored.restore(snapshot))
	assert_eq(restored.snapshot(), before, "unknown profile cannot partially replace the state")
	snapshot.erase("progression_profile_id")
	assert_true(restored.restore(snapshot), "old Pâris save has frozen migration identity")
	assert_eq(restored.progression_profile_id, "paris_act_1_v1")
	snapshot.level = 13
	assert_false(restored.restore(snapshot))
	assert_eq(restored.snapshot(), before, "out-of-profile level is not clamped")
	var legacy = Cards.new()
	var old: Dictionary = JSON.parse_string(JSON.stringify(legacy.snapshot()))
	for key in [
		"prototype_revision",
		"masteries",
		"aptitudes",
		"correction_visits",
		"full_reorientation_used",
		"progression_profile_id",
	]:
		old.erase(key)
	assert_true(legacy.restore(old))
	assert_eq(legacy.prototype_revision, 0, "battle migration policy unchanged")
