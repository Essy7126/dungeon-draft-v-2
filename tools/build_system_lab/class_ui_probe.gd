extends "res://tools/catabase_run_balance_validation/ui_probe.gd"
const Classes := preload("res://core/expedition/class_card_catalog.gd")


func _run() -> void:
	_output_root = _argument("output")
	DirAccess.make_dir_recursive_absolute(_output_root)
	GameManager.set_reduced_motion_enabled(true)
	get_tree().root.gui_embed_subwindows = true
	for viewport in SIZES:
		await _reset_runtime(viewport)
		GameManager.selected_run_variant = "cards"
		var creation: CharacterSelectionScreen = load(
			"res://ui/selection/CharacterSelectionScreen.tscn"
		).instantiate()
		add_child(creation)
		await _settle()
		creation.start_button.pressed.emit()
		await _settle()
		_check(
			creation.find_child("Choice_assassin", true, false) != null,
			"four class selection is reachable",
			viewport,
		)
		await _capture(
			"class_creation",
			viewport,
			[creation.start_button, creation.find_child("ChoiceImpact", true, false)],
		)
		creation.find_child("Choice_thaumaturge", true, false).pressed.emit()
		await _settle()
		_check(
			creation._cards_setup.payload().class_id == "thaumaturge",
			"class choice is carried by departure payload",
			viewport,
		)
		_check(
			creation.prepare_adventure(GameManager),
			"public character selection accepts the class departure",
			viewport,
		)
		_check(
			GameManager._cards_departure_selection.class_id == "thaumaturge",
			"public selection transfers class to the run manager",
			viewport,
		)
		creation.queue_free()
		await _settle()
		var session: ExpeditionSession = GameManager.expedition
		session.cards = preload("res://core/expedition/class_cards.gd").new()
		session.cards.bind(session)
		session.build.class_mode = true
		session.card_inventory = GameManager.run_inventory
		var ui_deck := Classes.preset("thaumaturge")
		# Exercise a legal mobility choice so the distant opening has a castable card.
		ui_deck.card_families[4] = "s_t_step"
		session.preparation_draft = { "selection": ui_deck, "step": 0 }
		var screen := SCREEN.instantiate()
		add_child(screen)
		await _settle()
		await _capture(
			"class_cards_departure",
			viewport,
			[
				screen.find_child("CardsConfirmChoice", true, false),
				screen.find_child("ChoiceImpact", true, false),
			],
		)
		for i in 5:
			screen.find_child("CardsConfirmChoice", true, false).pressed.emit()
			await _settle()
		_check(
			screen.find_child("ConfirmCatabaseDeparture", true, false) != null,
			"five choices reach deck review",
			viewport,
		)
		await _capture(
			"class_deck_review",
			viewport,
			[screen.find_child("ConfirmCatabaseDeparture", true, false)],
		)
		screen.queue_free()
		await _settle()
		_check(
			session
			.prepare_start(session.preparation_draft.selection, GameManager.run_inventory, GameManager.item_catalog)
			.success,
			"class preparation commits",
			viewport,
		)
		_check(session.enter("d01_0"), "first destination enters", viewport)
		await _class_combat(viewport)
		_check(session.combat_won(), "reward fixture reaches victory boundary", viewport)
		screen = SCREEN.instantiate()
		add_child(screen)
		await _settle()
		_check(
			screen.find_child("BeginLevelUp", true, false) == null,
			"loot precedes level notification",
			viewport,
		)
		await _capture(
			"class_loot",
			viewport,
			[screen.find_child("ClassLootContinue", true, false)],
		)
		var loot_icons := screen.find_children("LootReceipt_*", "Button", true, false)
		var discovery: Control = screen.find_child("CardDiscoverySummary", true, false)
		if discovery != null:
			await _hover_spell(discovery)
			await get_tree().create_timer(1.2).timeout
			await _capture("card_discovery_factors", viewport, [discovery])
			get_viewport().warp_mouse(Vector2(4, 4))
		_check(screen.find_child("CardDiscoverySummary", true, false) != null, "receipt explains card discovery", viewport)
		_check(session.cards.pending_card_reward().is_empty(), "cards arrive as loot without draft", viewport)
		var card_records := preload("res://ui/expedition/class_combat_results.gd").records_for(session).filter(func(record): return record.get("kind", "") == "C")
		var card_count := 0
		for record in card_records: card_count += int(record.count)
		_check(card_count == session.cards.last_drops.size(), "all dropped card copies are displayed alongside objects", viewport)
		_check(loot_icons.size() >= 1, "receipt shows equipment and any actual card drops", viewport)
		if not loot_icons.is_empty():
			get_viewport().warp_mouse(loot_icons[0].get_global_rect().get_center())
			var motion := InputEventMouseMotion.new()
			motion.position = loot_icons[0].get_global_rect().get_center()
			motion.global_position = motion.position
			get_viewport().push_input(motion)
			await get_tree().create_timer(1.2).timeout
			_check(
				get_viewport().gui_get_hovered_control() == loot_icons[0],
				"loot icon receives pointer hover",
				viewport,
			)
			var tooltip := get_tree().root.find_child("CardTooltip", true, false)
			_check(
				is_instance_valid(tooltip),
				"hover creates the illustrated item tooltip",
				viewport,
			)
			if is_instance_valid(tooltip):
				_check(
					tooltip.get_window().size.y <= viewport.y - 24,
					"loot tooltip fits within the screen height",
					viewport,
				)
			await _capture("class_loot_tooltip", viewport, [loot_icons[0]])
			loot_icons[0].pressed.emit()
			await _settle()
			await _capture(
				"class_loot_selected",
				viewport,
				[screen.find_child("ClassCombatResults", true, false)._detail],
			)
		screen.find_child("CloseDedicatedWindow", true, false).pressed.emit()
		await _settle()
		await _capture("class_level_up", viewport, [screen.find_child("BeginLevelUp", true, false)])
		screen.find_child("CloseDedicatedWindow", true, false).pressed.emit()
		await _settle()
		_check(
			session.advancement_step == "level_up",
			"closing notification preserves pending level",
			viewport,
		)
		_check(
			screen.find_child("CatabaseDecisionWindow", true, false) == null,
			"closing level returns to route overview",
			viewport,
		)
		await _capture(
			"class_pending_progression",
			viewport,
			[screen.find_child("ResumeCharacterProgression", true, false)],
		)
		screen._navigate("attributes")
		await _settle()
		await _capture(
			"class_character_details",
			viewport,
			[screen.find_child("ResumeCharacterProgression", true, false)],
		)
		var stat_scroll: ScrollContainer = screen.find_child("AttributeScroll", true, false)
		stat_scroll.scroll_vertical = 360
		await _settle()
		await _capture("class_character_defenses", viewport, [stat_scroll])
		screen.find_child("ResumeCharacterProgression", true, false).pressed.emit()
		await _settle()
		screen.find_child("BeginLevelUp", true, false).pressed.emit()
		await _settle()
		_check(
			screen.find_child("Attribute_wisdom", true, false) == null,
			"class progression excludes XP snowball attribute",
			viewport,
		)
		await _capture(
			"class_attributes",
			viewport,
			[screen.find_child("Attribute_power", true, false)],
		)
		while session.character.champion_progression.unspent_attribute_points > 0:
			screen.find_child("Attribute_power", true, false).pressed.emit()
			await _settle()
		screen.find_child("ContinueExpeditionFlow", true, false).pressed.emit()
		await _settle()
		_check(
			screen.find_child("ClassProgressionContinue", true, false) != null,
			"level flow opens class mastery window",
			viewport,
		)
		screen._navigate("build")
		await _settle()
		await _capture("class_mastery", viewport, [])
		screen._navigate("cards")
		await _settle()
		await _capture("class_deck", viewport, [])
		screen._open_inventory()
		await _settle()
		var equip := _button_by_text(screen, "Équiper cet objet")
		_check(_usable(equip), "received weapon has explicit equip action", viewport)
		if equip != null:
			equip.pressed.emit()
		await _settle()
		_check(
			session.character.equipment_loadout.get_equipped_items().size() == 1,
			"loot weapon equips through UI",
			viewport,
		)
		await _capture("class_equipment", viewport, [])
		var equipped_tile := screen.find_child("EquipmentSlot_0", true, false)
		var equipped_check: Control = equipped_tile.find_child("EquippedCheck", true, false)
		_check(
			equipped_check != null and equipped_check.visible,
			"equipped item has an explicit visible check",
			viewport,
		)
		var empty: Control = screen.find_child("InventoryEmptyState", true, false)
		_check(
			empty != null and empty.size.x >= 200 and empty.size.y < 100,
			"empty bag remains a readable paragraph",
			viewport,
		)
		_check(
			screen.find_children("EquipmentSlot_*", "Button", true, false).size() == 6,
			"all six equipment slots surround the character",
			viewport,
		)
		screen._navigate("attributes")
		await _settle()
		var power_total: Label = screen.find_child("Detailed_attack_power_total", true, false)
		_check(
			power_total != null
			and int(power_total.text) == session.character.unit.attack_power.get_int(),
			"character details reflect newly equipped weapon",
			viewport,
		)
		screen._close_current_view()
		await _settle()
		# Keep the probe scene alive; the final route state and destination are asserted below.
		screen.inspection_only = true
		screen.find_child("ClassProgressionContinue", true, false).pressed.emit()
		await _settle()
		_check(session.cards.pending_card_reward().is_empty(), "cards are actual drops, no draft step", viewport)
		_check(
			session.route.phase == "map",
			"level completion closes the receipt without showing it twice",
			viewport,
		)
		screen.queue_free()
		await _settle()
		_check(
			GameManager.get_expedition_destination_scene()
			== "res://hub/seuil_crossroads/SeuilCrossroads.tscn",
			"post-loot destination is the physical three-path map",
			viewport,
		)
		var routes := preload("res://hub/seuil_crossroads/seuil_route_choices.gd")
		for landmark in ["boat", "gate", "well"]:
			_check(
				not routes.destination(session, landmark).is_empty() and routes.can_depart(session),
				"physical exit available: " + landmark,
				viewport,
			)
		await _elite_loot(viewport)
		await _card_shop(viewport)
	GameManager.cleanup_run_state()
	await _settle()
	var passed := _checks.all(
		func(check):
			return check.passed,
	)
	var file := FileAccess.open(_output_root.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({ "passed": passed, "checks": _checks, "captures": _captures }, "\t")
	)
	file.close()
	get_tree().quit(0 if passed else 1)


func _card_shop(viewport: Vector2i) -> void:
	var session: ExpeditionSession = GameManager.expedition
	for transition in 12:
		if session.route.phase == "reward":
			if not session.cards.shop().is_empty():
				session.gold = 1000 # Fixture budget; actual debit is asserted below.
				var screen := SCREEN.instantiate()
				add_child(screen)
				await _settle()
				screen._navigate("cards")
				await _settle()
				var offers := screen.find_children("ShopCard_*", "Button", true, false)
				_check(offers.size() == 6, "six illustrated shop offers", viewport)
				await _capture("class_card_shop", viewport, offers.slice(0, 3))
				if offers.size() == 6:
					var stock: Array = session.cards.shop()
					var price: int = session.cards.BUY[session.cards.rarity(stock[0].family)]
					var gold := session.gold
					var copies: int = session.cards.copies.size()
					offers[0].pressed.emit()
					await _settle()
					_check(session.gold == gold - price and session.cards.copies.size() == copies + 1, "shop click buys exactly one reserve copy", viewport)
					_check(session.cards.shop()[0].sold, "purchased offer is exhausted", viewport)
				screen.queue_free()
				await _settle()
				return
			while session.character.champion_progression.unspent_attribute_points > 0:
				session.character.spend_champion_attribute(&"power")
			if session.character.champion_progression.current_level >= 4 and session.cards.specialization.is_empty():
				session.cards.specialize(Classes.SPECS[session.cards.primary_class][0][0])
			while not session.advancement_step.is_empty():
				if session.advancement_step == "advancement": session.cards.resolve_progression("skip")
				else: session.advance_level_step()
			if not session.cards.pending_card_reward().is_empty(): session.cards.choose_card_reward("")
			if not session.claim("class_continue", GameManager.run_inventory, GameManager.item_catalog).success: break
		var next := session.route.get_available_nodes()
		if next.is_empty() or not session.enter(str(next[0].id)): break
		if session.route.phase == "combat": session.combat_won()
	_check(false, "card shop is reachable", viewport)


func _elite_loot(viewport: Vector2i) -> void:
	# Controlled victory boundaries: this checks the mixed loot presentation,
	# while class_balance_probe measures actual encounters.
	var session: ExpeditionSession = GameManager.expedition
	for transition in 12:
		var choices := session.route.get_available_nodes()
		if choices.is_empty():
			break
		var elite := choices.filter(
			func(node):
				return node.kind == "elite",
		)
		var next: Dictionary = elite[0] if not elite.is_empty() else choices[0]
		if not session.enter(str(next.id)):
			break
		if session.route.phase == "combat":
			session.combat_won()
		while session.character.champion_progression.unspent_attribute_points > 0:
			session.character.spend_champion_attribute(&"power")
		if (
			session.character.champion_progression.current_level >= 4
			and session.cards.specialization.is_empty()
		):
			session.cards.specialize(Classes.SPECS[session.cards.primary_class][0][0])
		while not session.advancement_step.is_empty():
			if session.advancement_step == "advancement":
				session.cards.resolve_progression("skip")
			else:
				session.advance_level_step()
		if next.kind == "elite":
			_check(
				session.cards.battle_results[str(next.id)].enemies.is_empty(),
				"an unstarted fixture never inherits the previous encounter roster",
				viewport,
			)
			var screen := SCREEN.instantiate()
			add_child(screen)
			await _settle()
			var records := preload("res://ui/expedition/class_combat_results.gd").records_for(
				session
			)
			_check(
				records.any(
					func(row):
						return str(row.id).begins_with("class_gear_"),
				),
				"elite receipt contains equipment",
				viewport,
			)
			_check(
				records.any(
					func(row):
						return str(row.id).begins_with("ct_relic_"),
				),
				"elite receipt contains a relic",
				viewport,
			)
			_check(
				records.any(
					func(row):
						return str(row.id).begins_with("class_rune_"),
				),
				"elite receipt contains a rune",
				viewport,
			)
			var icons := screen.find_children("LootReceipt_*", "Button", true, false)
			await _capture("class_elite_loot", viewport, icons)
			var equipment := screen.find_child("LootReceipt_class_gear_*", true, false) as Button
			if equipment != null:
				equipment.pressed.emit()
				await _settle()
				await _capture(
					"class_elite_equipment_detail",
					viewport,
					[screen.find_child("ClassCombatResults", true, false)._detail],
				)
				var description: Control = screen.find_child("SelectedLootDescription", true, false)
				var continue_button: Control = screen.find_child("ClassLootContinue", true, false)
				_check(
					description.get_global_rect().end.y <= continue_button.global_position.y,
					"selected equipment effects and sale price are above the footer",
					viewport,
				)
			screen.queue_free()
			await _settle()
			return
		if not session.cards.pending_card_reward().is_empty(): session.cards.choose_card_reward("")
		var reward := "leave_hub" if ExpeditionRouteCatalog.is_halt(str(next.kind)) else "class_continue"
		if not session.claim(reward, GameManager.run_inventory, GameManager.item_catalog).success:
			break
	_check(false, "elite mixed loot fixture is reachable", viewport)


func _class_combat(viewport: Vector2i) -> void:
	var session: ExpeditionSession = GameManager.expedition
	var room := ExpeditionRunFactory.make_room(
		session.route.get_current_node(),
		GameManager.run_seed,
	)
	GameManager.current_room_index = 0
	GameManager.current_wave_index = 0
	GameManager.rooms[0] = room
	get_tree().set_meta(
		DIRECT_TEST_TREE_META,
		{
			"active": true,
			"configuration": "class_runtime",
			"spawn_heroes": true,
			"spawn_enemies": true,
			"deployment_enabled": false,
			"combat_enabled": true,
			"hud_enabled": true,
		},
	)
	var battle: Node = room.battle_scene.instantiate()
	add_child(battle)
	get_tree().remove_meta(DIRECT_TEST_TREE_META)
	var deadline := Time.get_ticks_msec() + 25000
	while not battle.runtime_ready_state and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(battle.runtime_ready_state, "class battle initializes", viewport)
	if not battle.runtime_ready_state:
		await _close_battle(battle)
		return
	battle._start_battle()
	while battle.action_bar.find_child("CatabaseCardHand", true, false) == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(1.).timeout
	var hand := battle.action_bar.find_child("CatabaseCardHand", true, false) as Control
	_check(
		hand != null and session.cards.hand.size() == 4,
		"class hand mounted in production battle",
		viewport,
	)
	if hand == null:
		await _close_battle(battle)
		return
	var deck_button := hand.find_child("OpenCombatDeck", true, false) as Button
	_check(_usable(deck_button), "deck access is visible in combat", viewport)
	if deck_button != null:
		deck_button.pressed.emit()
		await _settle()
		var persistent := GameManager.get_persistent_run_ui()
		var inspection: Control = persistent._expedition_inspection
		_check(is_instance_valid(inspection), "deck button opens combat inspection", viewport)
		if is_instance_valid(inspection):
			var workshop := inspection.find_child("ClassWorkshop", true, false)
			_check(
				workshop != null and workshop.read_only,
				"combat deck cannot be edited",
				viewport,
			)
			_check(
				inspection.find_children("ClassChoice_*", "Button", true, false).size() == 10,
				"all ten deck cards can be inspected",
				viewport,
			)
			await _capture("class_combat_deck", viewport, [inspection])
			var list_scroll := inspection.find_child("CardListScroll", true, false) as ScrollContainer
			list_scroll.scroll_vertical = 10000
			await _settle()
			var last_card: Button = inspection \
					.find_children("ClassChoice_*", "Button", true, false) \
					.back()
			last_card.pressed.emit()
			await _settle()
			_check(
				workshop.selected_id == str(last_card.name).trim_prefix("ClassChoice_"),
				"last card updates the persistent detail pane",
				viewport,
			)
			await _capture("class_deck_last_card", viewport, [last_card, workshop.detail])
			_check(
				last_card.button_pressed,
				"selected deck card remains visibly selected",
				viewport,
			)
			await _hover_spell(last_card)
			await get_tree().create_timer(.7).timeout
			_check(
				get_tree().root.find_children("CardTooltip", "", true, false).is_empty(),
				"only the passive explanation appears after a sustained hover",
				viewport,
			)
			var deck_hover = last_card.find_child("SpellHoverController", true, false)
			var explanation: Control = deck_hover._panel
			var grid_clear := not explanation.get_global_rect().intersects(
				list_scroll.get_global_rect()
			)
			_check(
				explanation.visible and grid_clear,
				"deck explanation leaves the card grid visible",
				viewport,
			)
			await _capture("class_deck_hover", viewport, [explanation, last_card])
			persistent._close_expedition_inspection()
			await _settle()
			_check(
				battle._can_accept_player_intent(),
				"closing deck restores combat inputs",
				viewport,
			)
			_check(
				persistent.open_inventory_screen(&"achilles"),
				"HUD opens dedicated class inventory",
				viewport,
			)
			await _settle()
			inspection = persistent._expedition_inspection
			_check(persistent.is_inventory_open(), "inventory API tracks the new window", viewport)
			_check(
				inspection.find_child("ClassInventoryView", true, false).read_only,
				"equipment is locked during combat",
				viewport,
			)
			_check(
				not battle._can_accept_player_intent(),
				"inventory blocks battle input",
				viewport,
			)
			await _capture(
				"class_combat_inventory",
				viewport,
				[inspection.find_child("InventoryCharacterPreview", true, false)],
			)
			_check(
				persistent.close_inventory_screen(),
				"inventory API closes the new window",
				viewport,
			)
			await _settle()
			_check(
				not persistent.is_inventory_open() and battle._can_accept_player_intent(),
				"closing inventory restores combat inputs",
				viewport,
			)
	var playable: Array = hand.find_children("Play_*", "Button", true, false).filter(
		func(button):
			return not button.disabled,
	)
	_check(not playable.is_empty(), "a class card accepts input", viewport)
	var range_badges := hand.find_children("CardRange", "Label", true, false)
	_check(range_badges.size() == 4, "every hand card displays its range", viewport)
	for badge: Label in range_badges:
		var button: Control = badge.get_parent().get_parent().get_parent()
		_check(button.get_global_rect().encloses(badge.get_global_rect()), "range badge fits its clickable icon", viewport)
	if not playable.is_empty():
		var source: Button = playable[0]
		await _hover_spell(source)
		var hover = source.find_child("SpellHoverController", true, false)
		var popup: Control = hover._panel
		_check(popup != null and popup.visible, "pointer opens the spell explanation", viewport)
		if popup != null:
			_check(
				not popup.get_global_rect().intersects(hand.get_global_rect()),
				"explanation stays above the entire hand",
				viewport,
			)
			_check(
				Rect2(Vector2.ZERO, viewport).encloses(popup.get_global_rect()),
				"spell explanation stays in viewport",
				viewport,
			)
			_check(
				get_viewport().gui_get_hovered_control() == source,
				"tooltip does not intercept card selection",
				viewport,
			)
			_check(
				battle._can_accept_player_intent(),
				"hover does not lock combat controls",
				viewport,
			)
			await _capture("class_spell_hover", viewport, [popup, source])
		if playable.size() > 1:
			await _hover_spell(playable[1])
			_check(not popup.visible, "moving to another card hides the old explanation", viewport)
			await _hover_spell(source)
	if not playable.is_empty():
		var click := InputEventMouseButton.new()
		click.position = playable[0].get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		get_viewport().push_input(click)
		click = click.duplicate()
		click.pressed = false
		get_viewport().push_input(click)
		await _settle()
		_check(
			battle.turn_state.selected_spell != null
			and str(battle.turn_state.selected_spell.spell_id).begins_with("class_"),
			"class card enters real targeting",
			viewport,
		)
		await _capture("class_combat_targeting", viewport, [hand])
		battle._cancel_action_selection_for_active_unit()
	var actor: Unit = session.character.unit
	await _cast_one_card(battle, hand, viewport)
	var activation := actor.activation_index
	battle.action_bar.end_turn_pressed.emit()
	await _settle()
	var confirmation = battle.get("_end_turn_confirmation")
	if is_instance_valid(confirmation) and confirmation.is_open():
		confirmation._confirm_button.pressed.emit()
	deadline = Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline and not battle._battle_over:
		if (
			actor.activation_index > activation and battle.turn_queue.get_current_unit() == actor
			and battle._can_accept_player_intent()
		):
			break
		await get_tree().process_frame
	_check(
		actor.activation_index > activation and not battle._battle_over,
		"real enemy/player cycle completes",
		viewport,
	)
	await _capture("class_combat_next_turn", viewport, [hand])
	await _close_battle(battle)
	GameManager._combat_report_tracker.discard()


func _cast_one_card(battle: Node, hand: Control, viewport: Vector2i) -> void:
	var cards = GameManager.expedition.cards
	var actor: Unit = GameManager.expedition.character.unit
	for id in cards.hand.duplicate():
		var spell: Spell = cards.spells_for(id)[0]
		for y in battle.grid.rows:
			for x in battle.grid.cols:
				var cell := Vector2i(x, y)
				var target: Unit = battle.grid.get_unit(cell)
				var meaningful := (
					spell.caster_movement != Spell.CasterMovement.NONE
					or (target != null and (target.team != actor.team or spell.can_target_self))
				)
				if not meaningful or not battle.spell_caster.can_cast(actor, spell, cell):
					continue
				var button := hand.find_child("Play_" + id + "_" + str(spell.spell_id), true, false) as Button
				if button == null or button.disabled:
					continue
				button.pressed.emit()
				await _settle()
				var ap_before := actor.current_ap
				battle._on_cell_clicked(cell)
				var deadline := Time.get_ticks_msec() + 15000
				while id in cards.hand and Time.get_ticks_msec() < deadline:
					await get_tree().process_frame
				_check(
					id not in cards.hand and id in cards.discard,
					"UI cast consumes exactly the selected copy",
					viewport,
				)
				_check(
					actor.current_ap == ap_before - spell.ap_cost,
					"UI cast pays card AP",
					viewport,
				)
				await get_tree().create_timer(1.).timeout
				await _capture("class_combat_card_played", viewport, [hand])
				return
	_check(false, "a useful card has a reachable target in the opening hand", viewport)


func _hover_spell(button: Control) -> void:
	get_viewport().warp_mouse(button.get_global_rect().get_center())
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion)
	await get_tree().create_timer(.4).timeout
	await _settle()
