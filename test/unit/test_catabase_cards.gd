extends GutTest
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
var managers: Array = []
var fields: Array = []

class Manager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void: pass
	func _request_scene_change(_path: String, _mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT) -> void: pass
	func _ensure_persistent_run_ui() -> PersistentRunUI: return null


func make_manager(weapon := "marteau", cards_mode := true):
	var manager := Manager.new()
	manager.expedition_save_path = "user://cards_test_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	assert_true(manager.start_expedition(2401, {}, false, true, "normal", cards_mode))
	assert_true(manager.confirm_catabase_preparation(CatabasePreparationCatalog.preset(weapon)).get("success", false))
	return manager


func after_each() -> void:
	for field in fields:
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()
	for manager in managers:
		manager.cleanup_run_state()
		ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
		manager.queue_free()
	managers.clear()
	await get_tree().process_frame


func finish_reward(manager) -> void:
	var session = manager.expedition
	while not session.advancement_step.is_empty():
		while session.character.champion_progression.unspent_attribute_points > 0:
			assert_true(session.character.champion_progression.spend_attribute(&"vitality"))
		assert_true(session.advance_level_step().get("success", false))
	if session.build.completed_depth == 12 and session.build.depth_eight_choice.is_empty():
		assert_true(session.build.choose_depth_eight("slot").success)
	assert_true(manager.claim_expedition_reward("leave_hub" if ExpeditionRouteCatalog.is_halt(str(session.route.get_current_node().kind)) else "supplies").success)


func test_six_decks_and_boundary_restores() -> void:
	for weapon in CatabasePreparationCatalog.WEAPONS:
		var manager = make_manager(str(weapon))
		var cards: CatabaseCards = manager.expedition.cards
		assert_eq(cards.active.size(), 10)
		assert_true(cards.valid_deck(cards.active))
		cards.start_turn()
		assert_eq(cards.hand.size(), 4)
		assert_eq(cards.spells_for(cards.hand[0]).size(), 1)
		assert_eq(cards.weapon_spells().size(), 2)
		var state: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
		assert_true(manager.restore_expedition_snapshot(state), weapon)
		manager.expedition.cards.start_turn()
		assert_eq(manager.expedition.cards.hand, cards.hand, "same committed opening")


func test_classic_has_no_cards_and_keeps_old_reward() -> void:
	var manager = make_manager("marteau", false)
	assert_null(manager.expedition.cards)
	assert_false(manager.get_expedition_snapshot().session.has("cards_run"))
	assert_true(manager.expedition.combat_won())
	finish_reward(manager)
	assert_eq(manager.expedition.gold, 135)


func test_loot_owned_idempotent_and_twenty_obole_provisions() -> void:
	var manager = make_manager()
	var session = manager.expedition
	assert_true(session.combat_won())
	var cards: CatabaseCards = session.cards
	assert_between(cards.last_drops.size(), 1, 2)
	assert_eq(cards.active.size(), 10, "loot goes to reserve")
	var count := cards.copies.size()
	cards.grant_loot(session.route.get_current_node())
	session.award_destination()
	assert_eq(cards.copies.size(), count)
	finish_reward(manager)
	assert_eq(session.gold, 115)
	assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))))
	assert_eq(manager.expedition.cards.copies.size(), count)


func test_sell_undo_and_bound_copy_protection() -> void:
	var manager = make_manager()
	var session = manager.expedition
	session.combat_won()
	var cards: CatabaseCards = session.cards
	assert_false(cards.sell(cards.active[0]))
	var id := str(cards.last_drops[0])
	var value: int = CatabaseCards.SELL[cards.rarity(str(cards.copy_for(id).family))]
	var before: int = session.gold
	assert_true(cards.sell(id))
	assert_eq(session.gold, before + value)
	assert_true(cards.snapshot().sale_undo.is_empty(), "sale cancellation is limited to the open screen")
	assert_false(cards.sell(id), "no double payment")
	cards.sync_learned()
	assert_true(cards.copy_for(id).is_empty())
	assert_true(cards.undo_sale(id))
	assert_eq(session.gold, before)
	assert_false(cards.undo_sale(id))
	assert_true(cards.move_card(cards.active[0]))
	assert_true(cards.move_card(cards.active[0]))
	assert_false(cards.move_card(cards.active[0]), "cannot shrink below eight")
	assert_true(cards.move_card(id, cards.active[0]))
	assert_false(cards.sell(id), "active cards are protected")


func test_card_gate_commit_and_weapon_shared_opportunity() -> void:
	var manager = make_manager()
	var session = manager.expedition
	var cards: CatabaseCards = session.cards
	cards.start_turn()
	var field = Factory.make_battlefield(10, 6)
	fields.append(field)
	var hero: Unit = session.character.unit
	hero.start_turn()
	field.grid.place_unit(hero, Vector2i(2, 2))
	var target := Factory.make_unit("Target", 1)
	field.grid.place_unit(target, Vector2i(3, 2))
	var spell := cards.weapon_spells()[0]
	var other := cards.weapon_spells()[1]
	var before := cards.hand.size()
	var rejected: CastContext = field.caster.begin_cast(hero, spell, Vector2i(9, 5))
	assert_true(rejected.failed)
	assert_eq(cards.hand.size(), before, "invalid target keeps the card")
	var context: CastContext = field.caster.begin_cast(hero, spell, target.grid_pos)
	assert_false(context.failed)
	assert_eq(cards.hand.size(), before, "fixed weapon does not consume a card")
	assert_eq(hero.current_ap, 2)
	assert_true(cards.is_weapon_spell(other), "second weapon gesture remains fixed")
	assert_true(cards.consume(other))
	assert_true(cards.card_for_spell(spell).is_empty())
	assert_ne(field.caster.get_cast_failure_reason(hero, spell, target.grid_pos), &"card_not_in_hand")
	var hand_before := cards.hand.duplicate()
	var uses_before := hero.get_spell_uses(spell)
	field.caster.cast_automatic(hero, spell, target.grid_pos, 0.1, &"card_test_reaction")
	assert_eq(cards.hand, hand_before, "automatic reactions do not consume manual cards")
	assert_eq(hero.get_spell_uses(spell), uses_before)


func test_retention_recomposition_and_recycling() -> void:
	var manager = make_manager()
	var cards: CatabaseCards = manager.expedition.cards
	var hero: Unit = manager.expedition.character.unit
	cards.start_turn()
	hero.start_turn()
	var old := cards.hand[0]
	assert_true(cards.recompose(old))
	assert_eq(hero.current_ap, 5)
	assert_false(old in cards.hand)
	assert_false(cards.recompose(cards.hand[0]))
	var keep := cards.hand[0]
	cards.retained = keep
	cards.end_turn()
	assert_eq(cards.hand, [keep])
	for index in 10:
		cards.start_turn()
		assert_eq(cards.hand.size(), 4)
		var seen := {}
		for id in cards.hand + cards.draw_pile + cards.discard:
			assert_false(seen.has(id), "one physical copy per zone")
			seen[id] = true
		assert_eq(seen.size(), 10)
		cards.end_turn()


func test_shared_heal_limit_exhausts_all_copies() -> void:
	var manager = make_manager("xiphos")
	var cards: CatabaseCards = manager.expedition.cards
	var hero: Unit = manager.expedition.character.unit
	cards.start_turn()
	var heal := cards.family_spell("exp_souffle")
	hero.mark_spell_used(heal)
	hero.mark_spell_used(heal)
	cards._prune_exhausted()
	assert_eq(cards.exhausted.size(), 2)
	assert_true(cards.card_for_spell(heal).is_empty())
	assert_eq(hero.get_spell_uses(heal), 2)


func test_offturn_recomposition_is_atomic_and_consumed_activation_is_locked() -> void:
	var manager = make_manager()
	var cards: CatabaseCards = manager.expedition.cards
	var hero: Unit = manager.expedition.character.unit
	hero.start_turn()
	cards.start_turn()
	var hand := cards.hand.duplicate()
	var draw := cards.draw_pile.duplicate()
	EventBus.turn_ended.emit(hero, &"test")
	assert_false(cards.recompose(hand[0]))
	assert_eq(cards.hand, hand)
	assert_eq(cards.draw_pile, draw)
	assert_eq(hero.current_ap, 6)
	cards.start_turn()
	hero.consume_current_activation()
	assert_false(cards.recompose(hand[0]))
	hero.start_turn()
	cards.start_turn()
	assert_true(cards.recompose(hand[0]))
	cards.end_turn()
	assert_false(cards.recompose(cards.retained))


func test_action_prerequisites_share_actual_cast_guards() -> void:
	var manager = make_manager("disque")
	var cards: CatabaseCards = manager.expedition.cards
	var hero: Unit = manager.expedition.character.unit
	var field = Factory.make_battlefield(10, 6)
	fields.append(field)
	field.grid.place_unit(hero, Vector2i(2, 2))
	var target := Factory.make_unit("Target", 1)
	field.grid.place_unit(target, Vector2i(4, 2))
	hero.start_turn()
	cards.start_turn()
	var launch := cards.family_spell("exp_ct_lancer")
	var recall := cards.family_spell("exp_ct_retour")
	assert_eq(field.caster.get_spell_preparation_failure_reason(hero, recall), &"Lancez d'abord le disque.")
	assert_eq(field.caster.get_cast_failure_reason(hero, recall, hero.grid_pos), &"Lancez d'abord le disque.")
	var cast: CastContext = field.caster.begin_cast(hero, launch, target.grid_pos)
	assert_false(cast.failed)
	field.caster.resolve_cast(cast)
	assert_eq(field.caster.get_spell_preparation_failure_reason(hero, recall), &"")
	assert_true(field.caster.can_cast(hero, recall, hero.grid_pos))
	hero.current_ap = 0
	assert_eq(field.caster.get_spell_preparation_failure_reason(hero, recall), &"pa")
	var urn_manager = make_manager("xiphos")
	var urn_hero: Unit = urn_manager.expedition.character.unit
	urn_hero.start_turn()
	urn_manager.expedition.cards.start_turn()
	var bronze: Spell = urn_manager.expedition.cards.family_spell("exp_ct_repercussion")
	var urn_cards: CatabaseCards = urn_manager.expedition.cards
	var bronze_id: String = urn_cards.active.filter(func(id): return urn_cards.copy_for(id).family == "exp_ct_repercussion")[0]
	if bronze_id not in urn_cards.hand:
		urn_cards.draw_pile.erase(bronze_id)
		urn_cards.hand.append(bronze_id)
	assert_eq(field.caster.get_spell_preparation_failure_reason(urn_hero, bronze), &"L'urne ne contient pas de bronze.")
	urn_hero.set_meta("ct_bronze", 20)
	assert_eq(field.caster.get_spell_preparation_failure_reason(urn_hero, bronze), &"")


func test_provisions_offer_matches_payment_and_cannot_be_claimed_twice() -> void:
	for is_cards in [true, false]:
		var manager = make_manager("marteau", is_cards)
		var session = manager.expedition
		assert_true(session.combat_won())
		var offers: Array = session.reward_options(manager.item_catalog, manager.run_inventory)
		var supplies: Dictionary = offers.filter(func(offer): return offer.id == "supplies")[0]
		assert_eq(int(supplies.gold_amount), 20 if is_cards else 40)
		finish_reward(manager)
		var gold: int = session.gold
		assert_false(session.claim("supplies", manager.run_inventory, manager.item_catalog).success)
		assert_eq(session.gold, gold)


func test_filtered_pool_and_numeric_tables() -> void:
	var manager = make_manager("marteau")
	assert_false("exp_ct_repercussion" in manager.expedition.cards.eligible_pool())
	var urn = make_manager("xiphos")
	assert_true("exp_ct_repercussion" in urn.expedition.cards.eligible_pool())
	for depth in [1, 6, 13, 17]:
		var sum := 0.0
		for weight in CatabaseCards.weights(depth): sum += float(weight)
		assert_almost_eq(sum, 100.0, 0.0001)
	for rank in 5: assert_gt(CatabaseCards.BUY[rank], CatabaseCards.SELL[rank])


func test_route_loot_elites_shops_and_replay() -> void:
	var manager = make_manager("xiphos")
	var session = manager.expedition
	var total := 0
	for depth in range(1, 20):
		if session.route.phase == "combat":
			assert_true(session.combat_won())
			total += session.cards.last_drops.size()
			if depth in [6, 10, 15]:
				assert_between(session.cards.last_drops.size(), 2, 3)
				var high := false
				for id in session.cards.last_drops:
					high = high or session.cards.rarity(str(session.cards.copy_for(id).family)) >= 2
				assert_true(high)
		if depth in [7, 11, 16]:
			var stock: Array = session.cards.shop().duplicate(true)
			assert_eq(stock.size(), 3)
			assert_eq(session.cards.shop(), stock)
			var before: int = session.gold
			assert_true(session.cards.buy(0))
			assert_eq(session.gold, before - 50)
			assert_false(session.cards.buy(0))
		if depth == 19: assert_true(session.cards.shop().is_empty())
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
		assert_true(manager.restore_expedition_snapshot(snapshot), "restore depth %d" % depth)
		session = manager.expedition
		finish_reward(manager)
		var next: Array = session.route.get_available_nodes()
		assert_false(next.is_empty())
		assert_true(manager.choose_expedition_node(str(next[0].id)))
	assert_between(total, 14, 25)
	assert_true(session.combat_won())
	assert_true(session.cards.last_drops.is_empty(), "no unusable final card")


func test_invalid_duplicate_copy_snapshot_is_rejected_without_replacing_live_run() -> void:
	var manager = make_manager()
	var current = manager.expedition
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	snapshot.session.cards_run.copies.append(snapshot.session.cards_run.copies[0].duplicate())
	assert_false(manager.restore_expedition_snapshot(snapshot))
	assert_same(manager.expedition, current)


func test_two_canonical_saves_resume_and_death_are_isolated() -> void:
	# dev.ps1 supplies an isolated APPDATA; these are never the player's files.
	var manager = make_manager("marteau", false)
	var temporary_path: String = manager.expedition_save_path
	manager.cleanup_run_state()
	assert_true(manager.select_run_variant("classic"))
	assert_true(manager.start_expedition(2401, {}, false, true, "normal", false))
	assert_true(manager.confirm_catabase_preparation(CatabasePreparationCatalog.preset("arc")).success)
	var classic_hash := FileAccess.get_sha256(ExpeditionSaveService.SAVE_PATH)
	manager.cleanup_run_state()
	assert_true(manager.select_run_variant("cards"))
	assert_true(manager.configure_next_run(ExpeditionRunFactory.create(2402, {"achilles": "passe_rive"}), 0))
	assert_true(manager.start_configured_run(), "same public launch used by character selection")
	assert_true(manager.expedition.needs_preparation)
	assert_true(manager.confirm_catabase_preparation(CatabasePreparationCatalog.preset("xiphos")).success)
	assert_eq(FileAccess.get_sha256(ExpeditionSaveService.SAVE_PATH), classic_hash)
	assert_true(manager.get_expedition_snapshot().session.has("cards_run"))
	manager.cleanup_run_state()
	assert_true(manager.select_run_variant("classic"))
	assert_true(manager.resume_expedition())
	assert_null(manager.expedition.cards)
	manager.cleanup_run_state()
	assert_true(manager.select_run_variant("cards"))
	assert_true(manager.resume_expedition())
	assert_not_null(manager.expedition.cards)
	assert_eq(manager.expedition.cards.active.size(), 10)
	assert_false(manager.select_run_variant("classic"), "cannot switch a live run")
	manager.begin_combat_report()
	manager.expedition.character.unit.current_hp = 0
	manager.expedition.character.unit.is_alive = false
	manager.on_battle_lost()
	assert_false(FileAccess.file_exists(ExpeditionSaveService.CARDS_SAVE_PATH))
	assert_eq(FileAccess.get_sha256(ExpeditionSaveService.SAVE_PATH), classic_hash)
	assert_true(manager.request_new_catabase_attempt())
	assert_eq(manager.selected_run_variant, "cards")
	assert_eq(manager.expedition_save_path, ExpeditionSaveService.CARDS_SAVE_PATH)
	ExpeditionSaveService.remove_snapshot(ExpeditionSaveService.SAVE_PATH)
	ExpeditionSaveService.remove_snapshot(temporary_path)


func test_classic_mastery_cannot_generate_a_free_maneuver() -> void:
	var manager = make_manager("marteau")
	var session = manager.expedition
	assert_true(session.combat_won())
	finish_reward(manager)
	var build: ExpeditionBuildState = session.build
	var candidate := ""
	var family := ""
	for offer in build.get_offers():
		if not offer.available or str(offer.spell_id).is_empty(): continue
		var root: String = build.catalog.get_spell_family(str(offer.spell_id))
		if not session.cards.known_family(root):
			candidate = str(offer.id)
			family = root
			break
	assert_false(candidate.is_empty(), "fixture finds a newly taught family")
	if candidate.is_empty(): return
	var before: Array = session.cards.copies.duplicate(true)
	assert_false(manager.purchase_expedition_technique(candidate).success)
	session.cards.sync_learned()
	assert_eq(session.cards.copies, before)
	assert_false(session.cards.known_family(family))


func test_family_form_choice_is_shared_frozen_and_persisted() -> void:
	var manager = make_manager("marteau")
	var session = manager.expedition
	assert_true(session.combat_won())
	finish_reward(manager)
	var cards: CatabaseCards = session.cards
	# Isolated card-service fixture: both forms are known; no forged full-run save.
	var variant: Spell = session.build.catalog.get_spell("exp_crochet_mutation")
	session.character.loadout.learn_spell(variant)
	assert_true(cards.choose_form("exp_crochet", str(variant.spell_id)))
	var restored := CatabaseCards.new()
	restored.bind(session)
	assert_true(restored.restore(cards.snapshot(), false))
	assert_eq(restored.family_spell("exp_crochet"), variant)
	assert_false(cards.choose_form("exp_crochet", "exp_feinte"))
	session.route.phase = "combat"
	cards.begin_combat()
	var count := 0
	for card in cards.copies:
		if card.family != "exp_crochet": continue
		count += 1
		assert_eq(cards.spells_for(str(card.id))[0], variant)
	assert_eq(count, 2)
	assert_false(cards.choose_form("exp_crochet", "exp_crochet"), "form is locked during combat")
	assert_eq(cards.family_spell("exp_crochet"), variant)


func test_random_opening_fixed_capacity_and_maneuver_commit() -> void:
	var manager = make_manager()
	var cards: CatabaseCards = manager.expedition.cards
	var hero: Unit = manager.expedition.character.unit
	hero.start_turn()
	manager.expedition.character.loadout.resize_slots(6)
	cards.start_turn()
	assert_eq(cards.hand.size(), 4, "classical slots must not grow the hand")
	assert_false(cards.hand.any(func(id): return cards.copy_for(id).family == CatabaseCards.GESTURE))
	var field = Factory.make_battlefield(10, 6)
	fields.append(field)
	field.grid.place_unit(hero, Vector2i(2, 2))
	var target := Factory.make_unit("Target", 1)
	field.grid.place_unit(target, Vector2i(3, 2))
	var id: String = cards.active.filter(func(copy_id): return cards.copy_for(copy_id).family == "exp_crochet")[0]
	# Pin a known maneuver for a target-validation fixture, not an opening rule.
	cards.hand.assign([id])
	cards.draw_pile.assign(cards.active.filter(func(copy_id): return copy_id != id))
	var spell := cards.spells_for(id)[0]
	assert_true(field.caster.begin_cast(hero, spell, Vector2i(9, 5)).failed)
	assert_eq(cards.hand, [id])
	assert_false(field.caster.begin_cast(hero, spell, target.grid_pos).failed)
	assert_true(cards.hand.is_empty())
	assert_eq(field.caster.get_spell_preparation_failure_reason(hero, spell), &"card_not_in_hand")
	assert_ne(field.caster.get_spell_preparation_failure_reason(hero, cards.weapon_spells()[1]), &"card_not_in_hand")


func test_progression_is_one_explicit_deck_decision_and_survives_reload() -> void:
	var manager = make_manager()
	var session: ExpeditionSession = manager.expedition
	assert_false(session.cards.resolve_progression("add", "exp_crochet"))
	assert_true(session.combat_won())
	while session.character.champion_progression.unspent_attribute_points > 0:
		session.character.champion_progression.spend_attribute(&"vitality")
	while session.advancement_step != "advancement":
		assert_true(session.advance_level_step().success)
	var offers := session.cards.progression_offers()
	var before := session.cards.active.duplicate()
	assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))))
	session = manager.expedition
	assert_eq(session.cards.progression_offers(), offers)
	var chosen := ""
	for family in offers:
		if session.cards.active.filter(func(id): return session.cards.copy_for(id).family == family).size() < 2:
			chosen = family
			break
	assert_false(chosen.is_empty())
	assert_true(manager.resolve_cards_progression("add", chosen, before[0]).success)
	assert_eq(session.cards.active.size(), before.size())
	assert_false(before[0] in session.cards.active)
	assert_false(session.cards.copy_for(before[0]).is_empty(), "replaced copy remains owned")
	assert_false(manager.resolve_cards_progression("add", chosen).success)
	assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))))
	assert_eq(manager.expedition.advancement_step, "")


func test_legacy_cards_migrate_without_losing_owned_copies_or_gold() -> void:
	var manager = make_manager()
	var session: ExpeditionSession = manager.expedition
	# Reconstruct the actual v1 boundary contract, then load via the public API.
	session.build.starting_selection.erase("card_families")
	session.character.loadout.initialize(session.build._starting_spells(session.build.starting_selection), 4)
	var old := CatabaseCards.new()
	old.bind(session)
	old.rules_revision = 1
	for index in 6: old.active.append(old.add_copy(CatabaseCards.GESTURE, true))
	for family in session.build.starting_selection.techniques:
		for index in 3: old.active.append(old.add_copy(family, true))
	old._repair_opening()
	session.cards = old
	var original := old.copies.duplicate(true)
	var gold := session.gold
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	snapshot.session.cards_run.erase("rules_revision")
	assert_true(manager.restore_expedition_snapshot(snapshot))
	var cards: CatabaseCards = manager.expedition.cards
	assert_eq(cards.rules_revision, 2)
	assert_eq(manager.expedition.gold, gold)
	assert_true(cards.valid_deck(cards.active))
	assert_eq(cards.active.size(), 10)
	for card in original: assert_eq(cards.copy_for(str(card.id)), card)
	assert_true(cards.opening.is_empty())
	var migrated: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	assert_true(manager.restore_expedition_snapshot(migrated), "migration remains valid after another save/load")
	assert_eq(manager.expedition.cards.snapshot(), cards.snapshot())


func test_card_upgrade_is_one_paid_decision_without_extra_copies() -> void:
	var manager = make_manager()
	var session: ExpeditionSession = manager.expedition
	assert_true(session.combat_won())
	finish_reward(manager)
	assert_true(manager.choose_expedition_node(str(session.route.get_available_nodes()[0].id)))
	assert_true(session.combat_won())
	while session.character.champion_progression.unspent_attribute_points > 0:
		session.character.champion_progression.spend_attribute(&"vitality")
	while session.advancement_step != "advancement":
		assert_true(session.advance_level_step().success)
	var offers := session.cards.upgrade_offers()
	assert_false(offers.is_empty())
	if offers.is_empty(): return
	var chosen: Dictionary = offers[0]
	var copies := session.cards.copies.duplicate(true)
	var points := session.build.points
	assert_true(manager.resolve_cards_progression("upgrade", str(chosen.id)).success)
	assert_eq(session.build.points, points - int(chosen.cost))
	assert_eq(session.cards.copies, copies)
	assert_false(manager.resolve_cards_progression("upgrade", str(chosen.id)).success)
	assert_true(session.character.loadout.knows_spell_id(StringName(chosen.spell_id)))
	assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))))


func test_progression_offer_does_not_reroll_when_recomposing_deck() -> void:
	var manager = make_manager()
	var session: ExpeditionSession = manager.expedition
	assert_true(session.combat_won())
	var offers := session.cards.progression_offers()
	assert_eq(offers.size(), 3)
	assert_true(session.cards.move_card(session.cards.active[0]))
	assert_eq(session.cards.progression_offers(), offers)
	assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))))
	assert_eq(manager.expedition.cards.progression_offers(), offers)


func test_invalid_starting_maneuvers_are_rejected_without_equipment_or_save_changes() -> void:
	var manager := Manager.new()
	manager.expedition_save_path = "user://cards_invalid_start_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	assert_true(manager.start_expedition(2401, {}, false, true, "normal", true))
	var before := manager.get_expedition_snapshot()
	var saved := FileAccess.get_sha256(manager.expedition_save_path)
	for invalid in ["not_an_array", [], ["exp_crochet", "exp_crochet", "exp_feinte", "exp_heurt", "exp_marche"], ["unknown", "exp_souffle", "exp_feinte", "exp_heurt", "exp_marche"]]:
		var selection := CatabasePreparationCatalog.preset("marteau")
		selection.card_families = invalid
		assert_false(manager.confirm_catabase_preparation(selection).success)
		assert_eq(manager.get_expedition_snapshot(), before)
		assert_eq(FileAccess.get_sha256(manager.expedition_save_path), saved)

func test_selection_choices_survive_threshold_and_pending_save() -> void:
	var manager := Manager.new()
	manager.expedition_save_path = "user://cards_setup_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	manager.selected_run_variant = "cards"
	var run := load("res://data/runs/odyssey.tres") as RunData
	assert_true(manager.configure_next_run(run, 0))
	var choice := CatabasePreparationCatalog.preset("arc")
	choice.armor = "mixte"
	choice.difficulty_id = "easy"
	assert_true(manager.configure_cards_departure(choice))
	assert_true(manager.continue_after_intro())
	assert_true(manager.finish_catabase_threshold().success)
	assert_eq(manager.expedition.preparation_draft.selection, choice, "cleanup during launch preserves first decisions")
	choice.card_families = CatabaseCards.starter_families(choice)
	assert_true(manager.save_cards_preparation_draft(choice, 3))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	assert_true(manager.restore_expedition_snapshot(saved))
	assert_eq(manager.expedition.preparation_draft.step, 3.0)
	assert_eq(manager.expedition.preparation_draft.selection, choice)
	assert_true(manager.confirm_catabase_preparation(choice).success)
	assert_eq(manager.expedition.build.starting_selection.weapon, "arc")
	assert_eq(manager.expedition.route.difficulty_id, "easy")
	assert_eq(manager.expedition.cards.active.size(), 10)
	assert_false(manager.expedition.to_snapshot().has("preparation_draft"))

func test_pending_card_draft_rejects_invalid_and_fractional_steps() -> void:
	var choice := CatabasePreparationCatalog.preset("marteau")
	for invalid in [-1, 6, 2.5, "3", null]:
		assert_false(ExpeditionSession.valid_preparation_draft({"selection": choice, "step": invalid}))
	assert_false(ExpeditionSession.valid_preparation_draft({"selection": {}, "step": 0}))
	assert_true(ExpeditionSession.valid_preparation_draft({}))
