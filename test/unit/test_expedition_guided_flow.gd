extends GutTest
## Simulated encounter outcomes exercise the actual saved session and screen.
## All checkpoints go to a unique fixture file, never the player's save.

const FLOW := preload("res://core/expedition/expedition_flow.gd")
const SCREEN := preload("res://ui/expedition/ExpeditionScreen.tscn")

var _save_path := ""
var _previous_save_path := ""
var _previous_reduced_motion := false
var _screens: Array[Control] = []


func before_each() -> void:
	_previous_save_path = GameManager.expedition_save_path
	_previous_reduced_motion = GameManager.is_reduced_motion_enabled()
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	_save_path = "res://artifacts/guided_flow_test_%d.json" % Time.get_ticks_usec()
	GameManager.expedition_save_path = _save_path
	var run := ExpeditionRunFactory.create(2401)
	var resolution := GameManager.resolve_run_hero_data(run, false)
	assert_true(resolution.is_valid())
	assert_true(GameManager._prepare_preconfigured_run(run, resolution.heroes))
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(GameManager.get_character_state(&"achilles"), 2401)
	assert_true(GameManager.expedition.enter("d01_0"))


func after_each() -> void:
	for screen in _screens:
		if is_instance_valid(screen):
			screen.queue_free()
	_screens.clear()
	await get_tree().process_frame
	GameManager.cleanup_run_state()
	GameManager.expedition_save_path = _previous_save_path
	GameManager.set_reduced_motion_enabled(_previous_reduced_motion)
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	await get_tree().process_frame


func test_guide_does_not_interrupt_the_opening_combat() -> void:
	assert_eq(FLOW.required_step(null), "map")
	assert_eq(GameManager.expedition.route.phase, "combat")
	assert_eq(FLOW.required_step(GameManager.expedition), "map")
	assert_eq(GameManager.expedition.build.points, 0)


func test_attributes_precede_rewards_and_destiny_can_be_saved() -> void:
	var session := GameManager.expedition
	assert_true(session.combat_won())
	assert_gt(session.character.champion_progression.unspent_attribute_points, 0)
	assert_eq(FLOW.required_step(session), "progression")
	_spend_attributes()
	assert_eq(FLOW.required_step(session), "rewards")
	var destiny := session.build.points
	assert_gt(destiny, 0)
	assert_true(bool(session.claim("supplies", GameManager.run_inventory, GameManager.item_catalog).success))
	assert_eq(FLOW.required_step(session), "map")
	assert_eq(session.build.points, destiny, "The guide never forces spending optional destiny points")


func test_twelfth_choice_precedes_halt_services_and_survives_reopening() -> void:
	_reach_reward(ExpeditionBuildState.CAPACITY_DEPTH)
	_spend_attributes()
	var session := GameManager.expedition
	assert_eq(FLOW.required_step(session), "capacity")
	var before := session.to_snapshot()
	assert_eq(FLOW.required_step(session), "capacity")
	assert_eq(session.to_snapshot(), before, "Finding the next step is read-only")
	assert_false(bool(session.claim("leave_hub", GameManager.run_inventory, GameManager.item_catalog).success))
	assert_true(bool(session.build.choose_depth_eight("slot").success))
	assert_eq(FLOW.required_step(session), "hub")
	assert_eq(session.character.loadout.get_active_slot_count(), 6)


func test_halt_is_a_service_step_and_never_a_single_reward_choice() -> void:
	_reach_reward(4)
	_spend_attributes()
	var session := GameManager.expedition
	assert_true(ExpeditionRouteCatalog.is_halt(str(session.route.get_current_node().kind)))
	assert_eq(FLOW.required_step(session), "hub")
	var services := session.hub_services(GameManager.item_catalog)
	assert_false(services.is_empty())
	session.character.unit.current_hp -= 20
	assert_true(bool(session.use_hub_service(str(services[0].id), GameManager.run_inventory, GameManager.item_catalog).success))
	assert_eq(FLOW.required_step(session), "hub", "Using one service keeps the halt open")
	assert_true(bool(session.claim("leave_hub", GameManager.run_inventory, GameManager.item_catalog).success))
	assert_eq(FLOW.required_step(session), "map")


func test_progression_has_its_own_screen_and_explicit_continue() -> void:
	assert_true(GameManager.expedition.combat_won())
	var screen := _open_screen()
	await _settle()
	assert_eq(screen.get("_page"), "progression")
	assert_eq(_map_count(screen), 0, "Attribute choices do not share the parchment")
	assert_null(screen.find_child("CommitDestination", true, false))
	screen.call("_navigate", "map")
	assert_eq(screen.get("_page"), "progression", "Map navigation cannot skip unspent attributes")
	for point in GameManager.expedition.character.champion_progression.unspent_attribute_points:
		_press(screen, "Attribute_vitality")
		await _settle()
	assert_eq(screen.get("_page"), "progression", "The final stat remains readable before continuing")
	_press(screen, "ContinueExpeditionFlow")
	await _settle()
	assert_eq(screen.get("_page"), "rewards")
	assert_eq(_map_count(screen), 0, "Reward choices have a dedicated screen")
	assert_null(screen.find_child("CommitDestination", true, false))


func test_reward_selection_requires_confirmation_then_leads_to_preparation_and_map() -> void:
	assert_true(GameManager.expedition.combat_won())
	_spend_attributes()
	var screen := _open_screen()
	await _settle()
	assert_eq(screen.get("_page"), "rewards")
	var before := GameManager.expedition.to_snapshot()
	_press(screen, "RewardOption_0")
	await _settle()
	assert_eq(GameManager.expedition.to_snapshot(), before, "Previewing a reward does not claim it")
	_press(screen, "ConfirmExpeditionReward")
	await _settle()
	assert_eq(GameManager.expedition.route.phase, "map")
	assert_eq(screen.get("_page"), "preparation")
	assert_gt(GameManager.expedition.build.points, 0)
	assert_null(screen.find_child("CommitDestination", true, false))
	_press(screen, "OpenRouteMap")
	await _settle()
	assert_eq(screen.get("_page"), "map")
	assert_eq(_map_count(screen), 1)
	var commit := screen.find_child("CommitDestination", true, false) as Button
	assert_not_null(commit)
	if commit != null:
		assert_false(commit.disabled, "Saved destiny points do not prevent choosing a path")
	assert_null(screen.find_child("ConfirmExpeditionReward", true, false))
	assert_null(screen.find_child("Attribute_vitality", true, false))


func test_inspection_keeps_full_map_read_only_even_with_pending_characteristics() -> void:
	assert_true(GameManager.expedition.combat_won())
	var before := GameManager.expedition.to_snapshot()
	var screen := _open_screen(true)
	await _settle()
	assert_eq(screen.get("_page"), "map")
	assert_eq(_map_count(screen), 1)
	for button in screen.find_children("CommitDestination", "Button", true, false):
		assert_true(button.disabled)
	assert_eq(GameManager.expedition.to_snapshot(), before)



	_press(screen, "CatabaseTab_attributes")
	await _settle()
	assert_eq(screen.get("_page"), "attributes")
	for id in ["vitality", "power", "resolve", "wisdom"]:
		var button := screen.find_child("Attribute_" + id, true, false) as Button
		assert_not_null(button)
		if button != null:
			assert_true(button.disabled, "Inspection cannot spend even when points are pending")
	assert_eq(GameManager.expedition.to_snapshot(), before)
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	assert_false(is_instance_valid(screen), "Closing inspection releases the overlay")
	assert_true(GameManager.run_active)
	assert_eq(GameManager.expedition.to_snapshot(), before)

func test_checkpoint_reopens_the_remaining_decision_without_rerolling_rewards() -> void:
	assert_true(GameManager.expedition.combat_won())
	var offers := GameManager.expedition.reward_options(GameManager.item_catalog).duplicate(true)
	assert_true(GameManager.save_expedition())
	assert_true(GameManager.restore_expedition_snapshot(ExpeditionSaveService.read_snapshot(_save_path)))
	var progression := _open_screen()
	await _settle()
	assert_eq(progression.get("_page"), "progression")
	assert_eq(_map_count(progression), 0)
	progression.queue_free()
	await _settle()
	_spend_attributes()
	assert_true(GameManager.save_expedition())
	assert_true(GameManager.restore_expedition_snapshot(ExpeditionSaveService.read_snapshot(_save_path)))
	var rewards := _open_screen()
	await _settle()
	assert_eq(rewards.get("_page"), "rewards")
	assert_eq(GameManager.expedition.reward_options(GameManager.item_catalog), offers)
	assert_eq(_map_count(rewards), 0)



func test_auxiliary_pages_return_to_the_pending_decision() -> void:
	assert_true(GameManager.expedition.combat_won())
	var screen := _open_screen()
	await _settle()
	_press(screen, "CatabaseTab_build")
	await _settle()
	assert_eq(screen.get("_page"), "build")
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	assert_eq(screen.get("_page"), "progression")
	_spend_attributes()
	screen.call("_continue_flow")
	_press(screen, "CatabaseTab_attributes")
	await _settle()
	assert_eq(screen.get("_page"), "attributes")
	assert_null(screen.find_child("ContinueExpeditionFlow", true, false), "Consulting stats is separate from the guided spending step")
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	assert_eq(screen.get("_page"), "rewards")
	assert_null(screen.find_child("CommitDestination", true, false))
	assert_true(GameManager.run_active, "Closing a sheet preserves the expedition")


func test_characteristics_can_be_consulted_without_points_and_close_back_to_map() -> void:
	assert_true(GameManager.expedition.combat_won())
	_spend_attributes()
	assert_true(bool(GameManager.expedition.claim("supplies", GameManager.run_inventory, GameManager.item_catalog).success))
	var screen := _open_screen()
	await _settle()
	assert_eq(screen.get("_page"), "map")
	var before := GameManager.expedition.to_snapshot()
	_press(screen, "CatabaseTab_attributes")
	await _settle()
	assert_eq(screen.get("_page"), "attributes")
	assert_eq(_map_count(screen), 0)
	for id in ["health", "power", "armor", "dodge"]:
		assert_not_null(screen.find_child("CurrentStat_" + id, true, false))
	for id in ["vitality", "power", "resolve", "wisdom"]:
		var button := screen.find_child("Attribute_" + id, true, false) as Button
		assert_not_null(button)
		if button != null:
			assert_true(button.disabled, "Consultation cannot spend absent points")
	assert_null(screen.find_child("ContinueExpeditionFlow", true, false))
	var close := screen.find_child("CloseExpeditionScreen", true, false) as Button
	assert_not_null(close)
	if close != null:
		assert_true(close.has_focus(), "Keyboard users can leave a completed character sheet")
		var view := screen.find_child("ExpeditionAttributesView", true, false) as Control
		assert_lt(close.get_global_rect().position.y, view.get_global_rect().position.y, "Closing is in the persistent header")
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	assert_eq(screen.get("_page"), "map", "Closing returns to the page that opened the sheet")
	assert_eq(GameManager.expedition.to_snapshot(), before)
	assert_true(GameManager.run_active)
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	assert_eq(screen.get("_page"), "preparation", "Leaving the full map returns to preparation")
	assert_true(GameManager.run_active, "The map close button never exits the expedition")


func test_characteristic_previews_preserve_state_and_match_the_actual_purchase() -> void:
	assert_true(GameManager.expedition.combat_won())
	var state := GameManager.expedition.character
	state.unit.attack_power.add_modifier(100.0, Stat.ModType.FLAT, "fixture_equipment")
	var expected := state.get_champion_attribute_rows()
	var before := GameManager.expedition.to_snapshot()
	var screen := _open_screen()
	await _settle()
	var view := screen.find_child("ExpeditionAttributesView", true, false) as Control
	assert_not_null(view)
	if view == null:
		return
	var power_button := screen.find_child("Attribute_power", true, false) as Button
	assert_not_null(power_button)
	var power_after := 0
	for row in expected:
		var preview := screen.find_child("AttributePreview_" + str(row.id), true, false) as Label
		assert_not_null(preview)
		if preview != null:
			assert_string_contains(preview.text, str(row.current))
			assert_string_contains(preview.text, "→")
			assert_string_contains(preview.text, str(row.next))
		if str(row.id) == "power":
			power_after = int(row.next)
	view.call("refresh")
	assert_eq(GameManager.expedition.to_snapshot(), before, "Displaying equipment-aware previews and refreshing never spends points")
	_press(screen, "Attribute_power")
	await _settle()
	assert_eq(state.unit.attack_power.get_int(), power_after, "The displayed prediction becomes the actual equipped stat")
	assert_eq(screen.find_child("ExpeditionAttributesView", true, false), view, "Spending preserves the sheet and its scroll position")
	assert_eq(screen.find_child("Attribute_power", true, false), power_button, "Spending updates the same card and button")
	assert_eq(screen.get("_page"), "progression")
	if state.champion_progression.unspent_attribute_points == 0:
		assert_true((screen.find_child("ContinueExpeditionFlow", true, false) as Button).has_focus())


func test_inventory_opens_the_bag_and_returns_to_the_same_decision() -> void:
	assert_true(GameManager.expedition.combat_won())
	_spend_attributes()
	var screen := _open_screen()
	await _settle()
	var before := GameManager.expedition.to_snapshot()
	_press(screen, "CatabaseTab_gear")
	await _settle()
	var persistent := GameManager.get_persistent_run_ui()
	assert_not_null(persistent)
	if persistent == null:
		return
	var inventory := persistent.inventory_screen
	assert_true(inventory.is_open(), "The inventory button opens the real bag and equipment interface")
	assert_eq(screen.get("_page"), "rewards", "Opening the bag keeps the current reward choice underneath")
	assert_eq(inventory.get_selected_character_id(), &"achilles")
	assert_null(inventory.find_child("Attribute_vitality", true, false), "Inventory contains item management, not attribute spending")
	assert_null(inventory.find_child("SkillsTab_learn", true, false), "Inventory does not duplicate the skill tree")
	var stats := inventory.find_child("StatsSummary", true, false) as Label
	assert_not_null(stats)
	if stats != null:
		assert_false(stats.text.contains("STATISTIQUES ACTUELLES"), "Inventory gives item guidance instead of duplicating the character sheet")
	_press(inventory, "CloseButton")
	await _settle()
	assert_false(inventory.is_open())
	assert_eq(screen.get("_page"), "rewards")
	assert_true((screen.find_child("CatabaseTab_gear", true, false) as Button).has_focus())
	assert_eq(GameManager.expedition.to_snapshot(), before)
	assert_true(GameManager.run_active)


func test_skills_start_with_equipped_actions_and_keep_learning_separate() -> void:
	assert_true(GameManager.expedition.combat_won())
	var screen := _open_screen()
	await _settle()
	var before := GameManager.expedition.to_snapshot()
	_press(screen, "CatabaseTab_build")
	await _settle()
	assert_eq(screen.get("_page"), "build")
	assert_not_null(screen.find_child("EquippedSkill_0", true, false), "New players first see the actions they can actually use")
	assert_not_null(screen.find_child("SkillsTab_equipped", true, false))
	assert_not_null(screen.find_child("SkillsTab_learn", true, false))
	assert_null(screen.find_child("Attribute_vitality", true, false), "Skills do not embed the separate characteristics page")
	assert_null(screen.find_child("InventoryGrid", true, false))
	_press(screen, "SkillsTab_learn")
	await _settle()
	assert_null(screen.find_child("EquippedSkill_0", true, false), "Learning has its own view")
	assert_eq(GameManager.expedition.to_snapshot(), before, "Reading either skill view does not buy anything")
	_press(screen, "CatabaseTab_attributes")
	await _settle()
	assert_eq(screen.get("_page"), "attributes")
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	assert_eq(screen.get("_page"), "progression", "Switching between reference pages retains the initial guided decision")
	assert_eq(GameManager.expedition.to_snapshot(), before)


func test_reward_cards_keep_selection_explicit_with_reduced_motion() -> void:
	assert_true(GameManager.expedition.combat_won())
	_spend_attributes()
	GameManager.set_reduced_motion_enabled(true)
	var screen := _open_screen()
	await _settle()
	var before := GameManager.expedition.to_snapshot()
	var confirm := screen.find_child("ConfirmExpeditionReward", true, false) as Button
	assert_not_null(confirm)
	if confirm != null:
		assert_true(confirm.disabled, "A reward is never preselected")
	var options := GameManager.expedition.reward_options(GameManager.item_catalog)
	assert_gt(options.size(), 1)
	for index in options.size():
		var wrapper := screen.find_child("ExpeditionRewardCard_%d" % index, true, false) as Control
		assert_not_null(wrapper)
		if wrapper == null:
			continue
		assert_eq(str(wrapper.get_meta("reward_id", "")), str(options[index].id))
		var card := wrapper.find_child("CollectibleCard", true, false) as RewardCardChoice
		assert_not_null(card, "Each choice uses the illustrated collectible card component")
		if card != null:
			assert_true(card.reduced_motion)
		_press(screen, "RewardOption_%d" % index)
		await _settle()
		assert_true(bool(wrapper.get_meta("selected", false)))
		if card != null:
			assert_false(card.particles.emitting, "Selected cards remain readable without moving particles")
		for other in options.size():
			var other_card := screen.find_child("ExpeditionRewardCard_%d" % other, true, false)
			if other_card != null:
				assert_eq(bool(other_card.get_meta("selected", false)), other == index, "Exactly one card is highlighted")
		assert_eq(GameManager.expedition.to_snapshot(), before, "Switching cards only previews a choice")
	if confirm != null:
		assert_false(confirm.disabled)


func test_known_reward_technique_shows_oboles_and_preserves_the_selected_choice() -> void:
	_reach_reward(3)
	_spend_attributes()
	var session := GameManager.expedition
	var offers := session.reward_options(GameManager.item_catalog)
	var spell_index := -1
	for index in offers.size():
		if offers[index].has("spell_id"):
			spell_index = index
			break
	assert_gte(spell_index, 0, "The third destination offers a technique card")
	if spell_index < 0:
		return
	var spell_offer := offers[spell_index]
	var screen := _open_screen()
	await _settle()
	_press(screen, "RewardOption_%d" % spell_index)
	var original := screen.find_child("ExpeditionRewardCard_%d" % spell_index, true, false)
	assert_false(bool(original.call("is_known_technique_compensation")))
	_press(screen, "CatabaseTab_build")
	await _settle()
	# Simulate learning the offered technique while consulting the build. The
	# pending reward remains available and converts to the real claim fallback.
	assert_true(bool(session.build.learn_spell_card(str(spell_offer.spell_id)).get("success", false)))
	var before_reopening := session.to_snapshot()
	var gold_before := session.gold
	var known_before := session.character.loadout.get_known_spells().size()
	_press(screen, "CloseExpeditionScreen")
	await _settle()
	var wrapper := screen.find_child("ExpeditionRewardCard_%d" % spell_index, true, false)
	assert_not_null(wrapper)
	if wrapper == null:
		return
	assert_true(bool(wrapper.get_meta("selected", false)), "Returning keeps the player's pending selection")
	assert_true(bool(wrapper.call("is_known_technique_compensation")))
	assert_eq(str(wrapper.call("get_destination_summary")), "+40 oboles à la validation")
	var card := wrapper.find_child("CollectibleCard", true, false) as RewardCardChoice
	assert_eq(card.fallback_meta.text, "COMPENSATION · OBOLES")
	assert_true(card.fallback_description.text.contains("40 oboles"))
	assert_false(card.fallback_footer.text.contains("équiper"))
	var summary := screen.find_child("RewardSelectionSummary", true, false) as Label
	assert_true(summary.text.contains("40 oboles"), "Confirmation describes the actual reward")
	assert_eq(session.to_snapshot(), before_reopening, "Refreshing the card never grants its compensation")
	_press(screen, "ConfirmExpeditionReward")
	await _settle()
	assert_eq(session.gold, gold_before + 40)
	assert_eq(session.character.loadout.get_known_spells().size(), known_before)
	assert_eq(screen.get("_page"), "preparation")

func _open_screen(inspection := false) -> Control:
	var screen := SCREEN.instantiate() as Control
	screen.set("inspection_only", inspection)
	screen.set("initial_page", "map")
	_screens.append(screen)
	add_child(screen)
	return screen


func _spend_attributes() -> void:
	var state := GameManager.expedition.character
	while state.champion_progression.unspent_attribute_points > 0:
		assert_true(state.spend_champion_attribute(&"vitality"))


func _reach_reward(depth: int) -> void:
	var session := GameManager.expedition
	assert_true(session.combat_won())
	while int(session.route.get_current_node().depth) < depth:
		_spend_attributes()
		var offers := session.reward_options(GameManager.item_catalog)
		assert_false(offers.is_empty())
		if offers.is_empty():
			return
		assert_true(bool(session.claim(str(offers.back().id), GameManager.run_inventory, GameManager.item_catalog).success))
		var available := session.route.get_available_nodes()
		assert_false(available.is_empty())
		if available.is_empty():
			return
		assert_true(session.enter(str(available[0].id)))
		if session.route.phase == "combat":
			assert_true(session.combat_won())


func _press(screen: Control, button_name: String) -> void:
	var button := screen.find_child(button_name, true, false) as Button
	assert_not_null(button, button_name)
	if button == null:
		return
	assert_false(button.disabled, button_name + " must be available")
	if not button.disabled:
		button.pressed.emit()


func _map_count(screen: Control) -> int:
	var count := 0
	for control in screen.find_children("*", "Control", true, false):
		if control is ExpeditionMapCanvas:
			count += 1
	return count


func _settle() -> void:
	for frame in 3:
		await get_tree().process_frame
