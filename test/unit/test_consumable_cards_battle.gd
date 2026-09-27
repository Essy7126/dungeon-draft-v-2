extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Battle := preload("res://core/expedition/consumable_cards_battle.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
var battles: Array = []


func after_each() -> void:
	for battle in battles:
		battle.dispose()
	battles.clear()


func create_battle(index := 1, class_id := "gardien"):
	var cards = Profile.create_cards(Catalog.preset(class_id))
	cards.level = index
	var battle := Battle.new()
	assert_true(battle.initialize(cards, index))
	battles.append(battle)
	return battle


func reload_battle(battle):
	var cards := Cards.new()
	assert_true(cards.restore(JSON.parse_string(JSON.stringify(battle.cards.snapshot()))))
	var restored = Battle.restore(cards, JSON.parse_string(JSON.stringify(battle.snapshot())))
	assert_not_null(restored, Battle.last_restore_error)
	if restored != null:
		battles.append(restored)
	return restored


func test_all_encounters_build_with_manifest_stats_and_restore() -> void:
	for index in range(1, 13):
		var battle = create_battle(index)
		assert_eq(battle.grid.cols, 7)
		assert_eq(battle.enemies.size(), Catalog.data().route[index - 1].roster.size())
		var restored = reload_battle(battle)
		if restored != null:
			assert_eq(JSON.stringify(restored.snapshot()), JSON.stringify(battle.snapshot()))
		if index == 12:
			assert_eq(battle.enemies[0].max_hp.get_int(), 840)


func test_after_each_actor_resume_does_not_repeat_attack_or_turn_draw() -> void:
	var battle = create_battle()
	assert_true(battle.command({ "kind": "fallback", "family": "fallback_guard", "cell": [3, 5] }).success)
	assert_true(battle.command({ "kind": "end_turn" }).success)
	var restored = reload_battle(battle)
	if restored == null:
		return
	while battle.phase != "hero" and battle.outcome.is_empty():
		assert_true(battle.next_actor().success)
		assert_true(restored.next_actor().success)
		assert_eq(JSON.stringify(restored.snapshot()), JSON.stringify(battle.snapshot()))
		assert_eq(restored.cards.hand, battle.cards.hand)
	assert_eq(battle.cards.round_index, 2)


func test_surface_reaction_and_group_limit_use_shared_terrain() -> void:
	var battle = create_battle(4, "thaumaturge")
	battle.hero.current_ap = 4
	var cards = battle.cards
	cards.active.clear()
	cards.hand.clear()
	cards.draw_pile.clear()
	cards.discard.clear()
	for family in ["t04", "t01", "t02"]:
		var uid: String = cards.acquire(family, "loot", "test")
		cards.active.append(uid)
		cards.hand.append(uid)
	# Keep legal hand capacity for the fixture; the actual draw API never overfills.
	while cards.hand.size() > 5:
		cards.draw_pile.append(cards.hand.pop_front())
	var wave_uid := ""
	for uid in cards.hand:
		if cards.copy_for(uid).family == "t04":
			wave_uid = uid
	assert_false(wave_uid.is_empty())
	assert_true(battle.command({ "kind": "card", "uid": wave_uid, "cell": [3, 3] }).success)
	assert_eq(battle.terrain.get_surface_id(Vector2i(3, 3)), &"water")
	assert_eq(cards.surface_groups.size(), 1)
	var restored = reload_battle(battle)
	if restored != null:
		assert_eq(restored.terrain.get_surface_id(Vector2i(3, 3)), &"water")
		assert_eq(restored.terrain.get_remaining_duration(Vector2i(3, 3)), 2)


func test_snapshot_rejects_overlap_and_illegal_hp() -> void:
	var battle = create_battle()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(battle.snapshot()))
	snapshot.units[1].cell = snapshot.units[0].cell
	assert_null(Battle.restore(battle.cards, snapshot))
	snapshot = JSON.parse_string(JSON.stringify(battle.snapshot()))
	snapshot.units[0].hp = 9999
	assert_null(Battle.restore(battle.cards, snapshot))
	assert_eq(battle.hero.current_hp, 110)
