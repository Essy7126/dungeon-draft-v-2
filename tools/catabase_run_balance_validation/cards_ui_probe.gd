extends "res://tools/catabase_run_balance_validation/ui_probe.gd"
## Real UI, isolated user directory; setup victories are not claimed as playtests.


func _run() -> void:
	_output_root = _argument("output")
	DirAccess.make_dir_recursive_absolute(_output_root)
	GameManager.set_reduced_motion_enabled(true)
	for viewport_size in SIZES:
		GameManager.cleanup_run_state()
		DisplayServer.window_set_size(viewport_size)
		get_tree().root.size = viewport_size
		GameManager.select_run_variant("classic")
		var title: Node = load("res://ui/TitreEcran.tscn").instantiate()
		add_child(title)
		await _settle()
		var selector := title.find_child("RunVariantSelector", true, false) as OptionButton
		_check(selector != null and selector.item_count == 2, "title has both runs", viewport_size)
		selector.select(1)
		selector.item_selected.emit(1)
		_check(GameManager.expedition_save_path == ExpeditionSaveService.CARDS_SAVE_PATH, "title selects independent card save", viewport_size)
		await _capture("cards_title", viewport_size, [selector, title.bouton_nouvelle_partie])
		title.queue_free()
		await _settle()
		var creation: CharacterSelectionScreen = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
		add_child(creation)
		await _settle()
		_check(creation.get_selected_entry().display_name == "Passe-rive", "cards selection identifies Passe-rive", viewport_size)
		await _capture("cards_identity", viewport_size, [creation.start_button])
		for index in range(6):
			creation.start_button.pressed.emit()
			await _settle()
			if index == 0:
				creation.find_child("Choice_arc", true, false).pressed.emit()
				await _settle()
				await _capture("cards_selection_weapon", viewport_size, [creation.start_button, creation.find_child("ChoiceImpact", true, false)])
		_check("Passe-rive" in creation.start_button.text, "departure button uses selected identity", viewport_size)
		_check(creation._cards_setup.selection.weapon == "arc", "selection keeps chosen weapon across steps", viewport_size)
		await _capture("cards_selection_review", viewport_size, [creation.start_button])
		_check(creation.prepare_adventure(GameManager), "selection commits first decisions before cinematic", viewport_size)
		_check(GameManager._cards_departure_selection.get("weapon") == "arc", "selected weapon reaches next-run configuration", viewport_size)
		creation.queue_free()
		await _settle()
		await _reset_runtime(viewport_size)
		var session: ExpeditionSession = GameManager.expedition
		session.cards = CatabaseCards.new()
		session.cards.bind(session)
		session.card_inventory = GameManager.run_inventory
		var departure := SCREEN.instantiate()
		add_child(departure)
		await _settle()
		_check(departure.find_child("CardsDepartureStatus", true, false) != null, "cards launch has its own deck preparation", viewport_size)
		_check(departure.find_child("DepartureNext", true, false) == null, "cards launch does not use classical seven-window flow", viewport_size)
		for choice: OptionButton in departure.find_children("*", "OptionButton", true, false):
			_check(choice.size.y <= 50, "departure selector stays compact: " + choice.name, viewport_size)
		_check(departure.find_children("CardsSingleChoice", "VBoxContainer", true, false).size() == 1, "one card decision at a time", viewport_size)
		_check(departure.find_child("ConfirmCatabaseDeparture", true, false) == null, "cannot launch before confirming five choices", viewport_size)
		await _capture("cards_departure", viewport_size, [departure.find_child("CardsConfirmChoice", true, false), departure.find_child("ChoiceImpact", true, false)])
		for index in 5:
			if index == 0:
				departure.find_child("Choice_exp_feinte", true, false).pressed.emit()
				await _settle()
			departure.find_child("CardsConfirmChoice", true, false).pressed.emit()
			await _settle()
			_check(session.preparation_draft.get("step", -1) == index + 1, "card choice checkpoint %d" % (index + 1), viewport_size)
			_check(CatabasePreparationCatalog.valid(session.preparation_draft.get("selection", {})), "replacing a suggested family preserves five distinct choices", viewport_size)
			if index == 1:
				departure.queue_free()
				await _settle()
				departure = SCREEN.instantiate()
				add_child(departure)
				await _settle()
				_check(departure.find_child("CardsSingleChoice", true, false) != null, "reopened preparation resumes next choice", viewport_size)
		await _capture("cards_deck_review", viewport_size, [departure.find_child("ConfirmCatabaseDeparture", true, false)])
		departure.queue_free()
		await _settle()
		_check(session.prepare_start(CatabasePreparationCatalog.preset("marteau"), GameManager.run_inventory, GameManager.item_catalog).success, "cards preparation", viewport_size)
		_check(session.enter("d01_0"), "cards first combat entry", viewport_size)
		var room: RoomData = ExpeditionRunFactory.make_room(session.route.get_current_node(), GameManager.run_seed)
		GameManager.current_room_index = 0
		GameManager.current_wave_index = 0
		GameManager.rooms[0] = room
		get_tree().set_meta(DIRECT_TEST_TREE_META, {"active": true, "configuration": "cards_runtime", "spawn_heroes": true, "spawn_enemies": true, "deployment_enabled": false, "combat_enabled": true, "hud_enabled": true})
		var battle: Node = room.battle_scene.instantiate()
		add_child(battle)
		get_tree().remove_meta(DIRECT_TEST_TREE_META)
		var deadline := Time.get_ticks_msec() + 25000
		while not battle.runtime_ready_state and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		# Direct-test spawning deliberately leaves turn progression stopped.
		battle._start_battle()
		while battle.action_bar.find_child("CatabaseCardHand", true, false) == null and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		var hand: Control = battle.action_bar.find_child("CatabaseCardHand", true, false)
		_check(hand != null and hand.get_parent().name == "SpellSection", "card hand is mounted inside the real spell bar", viewport_size)
		if hand == null:
			get_tree().quit(1)
			return
		await get_tree().create_timer(1.0).timeout
		var card_id: String = session.cards.hand[0]
		var retain := hand.find_child("Retain_" + card_id, true, false) as Button
		_check(retain != null and not retain.disabled, "hand accepts real player input", viewport_size)
		if retain != null and not retain.disabled:
			retain.pressed.emit()
			_check(session.cards.retained == card_id, "retain button updates combat model", viewport_size)
		await _settle()
		await _capture("cards_combat", viewport_size, [hand])
		_check(hand.find_children("FixedWeapon_*", "Button", true, false).size() == 2, "both fixed weapon actions appear beside the hand", viewport_size)
		var fixed_actions := hand.find_children("FixedWeapon_*", "Button", true, false)
		var ready_fixed := fixed_actions.filter(func(button): return not button.disabled)
		_check(not ready_fixed.is_empty(), "a weapon action accepts input independently of the draw", viewport_size)
		if not ready_fixed.is_empty():
			var unchanged := session.cards.hand.duplicate()
			ready_fixed[0].pressed.emit()
			await _settle()
			_check(session.cards.is_weapon_spell(battle.turn_state.selected_spell) and session.cards.hand == unchanged, "fixed weapon button selects a weapon without consuming a maneuver", viewport_size)
			battle._cancel_action_selection_for_active_unit()
		# Layout-only capacity fixture, not a claim of reaching level XII here.
		session.character.loadout.resize_slots(5)
		session.cards.start_turn()
		await _settle()
		_check(session.cards.hand.size() == 4, "classical fifth slot does not change four-card hand", viewport_size)
		await _capture("cards_combat_five", viewport_size, [hand])
		session.character.loadout.resize_slots(6)
		session.cards.start_turn()
		await _settle()
		_check(session.cards.hand.size() == 4, "classical sixth slot does not change four-card hand", viewport_size)
		var hud_band := battle.action_bar.find_child("HudBand", true, false) as Control
		_check(hud_band != null and hud_band.visible and hand.get_global_rect().end.y <= viewport_size.y, "cards share the visible original HUD without leaving the viewport", viewport_size)
		_check(hud_band.size.y <= 210, "integrated HUD saves at least 42 pixels over the old 252px dock", viewport_size)
		for unit: Unit in battle.units:
			var point: Vector2 = battle.get_viewport().get_canvas_transform() * battle.grid_cell_to_global(unit.grid_pos)
			_check(point.y < hud_band.get_global_rect().position.y - 12, "actor feet remain above the complete integrated HUD", viewport_size)
		await _capture("cards_combat_six", viewport_size, [hand])
		battle._on_turn_order_unit_selected(session.character.unit)
		await _settle()
		var inspector: Control = battle.inspect_panel._panel
		_check(inspector.visible and inspector.get_global_rect().end.y <= hud_band.get_global_rect().position.y - 8, "locked inspector leaves the entire card HUD accessible", viewport_size)
		await _capture("cards_inspector", viewport_size, [inspector, hand])
		battle.inspect_panel.release_lock()
		await _settle()
		var objects: Button = battle.action_bar.find_child("ShowItemsButton", true, false)
		objects.pressed.emit()
		await _settle()
		_check(hud_band.visible and not hand.visible and battle.action_bar.get_active_bar_mode() == "item", "combat objects use the original tab and hide only the cards", viewport_size)
		await _capture("cards_combat_objects", viewport_size, [hud_band])
		(battle.action_bar.find_child("ShowSpellsButton", true, false) as Button).pressed.emit()
		await _settle()
		_check(hud_band.visible and hand.visible and session.cards.hand.size() == 4, "returning from objects preserves the hand and common HUD", viewport_size)
		var playable: Array = hand.find_children("Play_*", "Button", true, false).filter(func(button): return not button.disabled)
		_check(not playable.is_empty(), "integrated hand exposes a playable spell", viewport_size)
		if not playable.is_empty():
			var unchanged_hand := session.cards.hand.duplicate()
			playable[0].pressed.emit()
			await _settle()
			_check(battle.turn_state.selected_spell != null and session.cards.hand == unchanged_hand, "selecting a real card enters targeting without consuming it", viewport_size)
			await _capture("cards_combat_targeting", viewport_size, [hand])
			battle._cancel_action_selection_for_active_unit()
			await _settle()
			_check(hand.find_children("Play_*", "Button", true, false).all(func(button): return not button.button_pressed), "cancel removes the selected card visual", viewport_size)
		var actor: Unit = session.character.unit
		var original_ap := actor.current_ap
		actor.current_ap = 0
		actor.stats_changed.emit(actor)
		await _settle()
		_check(hand.find_children("Play_*", "Button", true, false).all(func(button): return button.disabled), "zero AP disables spell buttons through the shared resolver", viewport_size)
		await _capture("cards_combat_no_ap", viewport_size, [hand])
		actor.current_ap = original_ap
		actor.stats_changed.emit(actor)
		await _settle()
		var previous_hand := session.cards.hand.duplicate()
		var recompose := hand.find_child("Recompose_" + session.cards.hand[0], true, false) as Button
		_check(not recompose.disabled, "recomposition is enabled during player activation", viewport_size)
		recompose.pressed.emit()
		await _settle()
		_check(actor.current_ap == original_ap - 1 and session.cards.hand != previous_hand and session.cards.hand.size() == 4, "real recompose button exchanges one card for exactly one AP", viewport_size)
		_check(hand.find_children("Recompose_*", "Button", true, false).all(func(button): return button.disabled), "recomposition cannot repeat this activation", viewport_size)
		(hand.find_child("CardCombatJournal", true, false) as Button).pressed.emit()
		_check(battle.player_combat_log.visible, "integrated hand keeps the combat journal accessible", viewport_size)
		(hand.find_child("CardCombatJournal", true, false) as Button).pressed.emit()
		var persistent_bar = battle.action_bar
		var command_rects := {}
		for node_name in ["MoveButton", "EndTurnButton", "ShowSpellsButton", "ShowItemsButton"]:
			command_rects[node_name] = (battle.action_bar.find_child(node_name, true, false) as Control).get_global_rect()
		var activation := actor.activation_index
		battle.action_bar.end_turn_pressed.emit()
		await _settle()
		var confirmation = battle.get("_end_turn_confirmation")
		_check(is_instance_valid(confirmation) and confirmation.is_open(), "unused PA/PM still require explicit end-turn confirmation", viewport_size)
		if is_instance_valid(confirmation) and confirmation.is_open():
			await _capture("cards_end_turn_confirmation", viewport_size, [confirmation._confirm_button, confirmation._cancel_button])
			confirmation._confirm_button.pressed.emit()
		var turn_deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < turn_deadline and not battle._battle_over:
			if actor.activation_index > activation and battle.turn_queue.get_current_unit() == actor and battle._can_accept_player_intent(): break
			await get_tree().process_frame
		await _settle()
		_check(actor.activation_index > activation and not battle._battle_over, "end-turn command completes a real enemy/player cycle", viewport_size)
		_check(hand.visible and battle.action_bar.find_child("ShowSpellsButton", true, false).text == "CARTES", "card HUD survives turn changes", viewport_size)
		for node_name in command_rects:
			var actual_rect := (battle.action_bar.find_child(node_name, true, false) as Control).get_global_rect()
			_check(actual_rect.is_equal_approx(command_rects[node_name]), node_name + " keeps its geometry across a real turn cycle", viewport_size)
		await _capture("cards_combat_next_turn", viewport_size, [hand])
		await _close_battle(battle)
		_check(not is_instance_valid(persistent_bar) or persistent_bar.get("_card_hand_view") == null, "card presentation is removed on battle teardown", viewport_size)
		GameManager._combat_report_tracker.discard()
		# Exercise the actual reward widgets; this fixture advances via a setup win.
		_check(session.combat_won(), "setup reward boundary", viewport_size)
		while session.character.champion_progression.unspent_attribute_points > 0:
			session.character.champion_progression.spend_attribute(&"vitality")
		for step in 3:
			if session.advancement_step == "advancement": break
			_check(session.advance_level_step().success, "reach deck progression", viewport_size)
		var screen := SCREEN.instantiate()
		add_child(screen)
		await _settle()
		_check(screen.find_child("OpenLevelSpellTree", true, false) == null, "level-up offers deck decisions instead of the classic learning flow", viewport_size)
		var drafts := screen.find_children("ProgressionAdd_*", "Button", true, false)
		_check(drafts.size() == 3, "three explicit maneuver choices", viewport_size)
		await _capture("cards_progression", viewport_size, [screen.find_child("FinishLevelSpells", true, false)])
		var old_size := session.cards.active.size()
		var incoming := drafts.filter(func(button): return not button.disabled)
		_check(not incoming.is_empty(), "an offered maneuver can be selected", viewport_size)
		if not incoming.is_empty(): incoming[0].pressed.emit()
		await _settle()
		_check(session.advancement_step.is_empty() and session.cards.active.size() == old_size + 1, "real progression button adds one chosen copy and closes the decision", viewport_size)
		_check(screen.find_child("CatabaseCardCollection", true, false) != null, "loot owns acquired cards", viewport_size)
		var loot_picker := screen.find_child("CardReplacementTarget", true, false) as Control
		_check(loot_picker != null and loot_picker.get_global_rect().position.y >= 240 and loot_picker.get_global_rect().end.y < viewport_size.y - 100, "acquired loot starts above the fold", viewport_size)
		var loot_collection := screen.find_child("CatabaseCardCollection", true, false)
		for action: Control in loot_collection.find_children("ApplyCardReplacement", "Button", true, false):
			_check(action.get_global_rect().end.y <= viewport_size.y - 125, "each acquired card can be added without scrolling", viewport_size)
		for action: Button in loot_collection.find_children("*", "Button", true, false):
			if action.text.begins_with("Vendre 1"):
				_check(action.get_global_rect().end.y <= viewport_size.y - 125, "each acquired card can be sold without scrolling", viewport_size)
		await _capture("cards_loot", viewport_size, [screen.find_child("ConfirmExpeditionReward", true, false), loot_picker])
		var tab := screen.find_child("CatabaseTab_cards", true, false) as Button
		tab.pressed.emit()
		await _settle()
		_check(screen._page == "cards", "cards tab opens reserve", viewport_size)
		var collection := screen.find_child("CatabaseCardCollection", true, false)
		_check(collection.find_children("CardFamily_weapon_gesture", "PanelContainer", true, false).is_empty(), "weapon gestures are absent from the maneuver collection", viewport_size)
		var local_picker := collection.find_child("CardReplacementTarget", true, false) as OptionButton
		_check(local_picker != null and local_picker.item_count <= 7, "replacement groups outgoing copies by family", viewport_size)
		if local_picker != null and local_picker.item_count > 1:
			local_picker.select(1)
			local_picker.item_selected.emit(1)
			var replacement_button: Button = local_picker.get_parent().find_children("*", "Button", true, false).filter(func(button): return button.text == "Remplacer cette copie")[0]
			_check(not replacement_button.disabled, "local replacement preview allows a legal swap", viewport_size)
			var previous_active := session.cards.active.duplicate()
			replacement_button.pressed.emit()
			await _settle()
			_check(session.cards.active.size() == previous_active.size() and session.cards.active != previous_active and session.cards.valid_deck(session.cards.active), "real grouped reserve button replaces exactly one copy", viewport_size)
		await _capture("cards_reserve", viewport_size, [screen.find_child("CardReplacementTarget", true, false)])
		screen.queue_free()
		await _settle()
		_check(_advance_to_card_refuge(session), "setup reaches real refuge VII", viewport_size)
		var refuge := SCREEN.instantiate()
		add_child(refuge)
		await _settle()
		(refuge.find_child("CatabaseTab_cards", true, false) as Button).pressed.emit()
		await _settle()
		var buy := refuge.find_child("BuyCard_0", true, false) as Button
		_check(buy != null and not buy.disabled, "first refuge offers an affordable card", viewport_size)
		if buy != null and not buy.disabled:
			var previous_gold := session.gold
			buy.pressed.emit()
			_check(session.gold == previous_gold - 50 and session.cards.shop()[0].sold, "real shop button pays once and consumes stock", viewport_size)
		await _settle()
		await _capture("cards_shop", viewport_size, [refuge.find_child("BuyCard_1", true, false)])
		refuge.queue_free()
		await _settle()
	GameManager.cleanup_run_state()
	await _settle()
	var passed: bool = _checks.all(func(check): return check.passed)
	var file := FileAccess.open(_output_root.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": _checks, "captures": _captures, "limitations": "Reward fixture uses a setup victory; combat screenshot is real Battle, not a won run."}, "\t"))
	file.close()
	get_tree().quit(0 if passed else 1)


func _advance_to_card_refuge(session: ExpeditionSession) -> bool:
	for step in 8:
		if int(session.route.get_current_node().depth) == 7: return true
		if not _resolve_advancement(session): return false
		var is_halt: bool = ExpeditionRouteCatalog.is_halt(str(session.route.get_current_node().kind))
		if not session.claim("leave_hub" if is_halt else "supplies", GameManager.run_inventory, GameManager.item_catalog).get("success", false): return false
		var choices := session.route.get_available_nodes()
		if choices.is_empty() or not session.enter(str(choices[0].id)): return false
		if session.route.phase == "combat" and not session.combat_won(): return false
	return false
