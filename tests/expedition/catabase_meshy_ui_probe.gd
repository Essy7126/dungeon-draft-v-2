extends Node
## Real opening, menus and equipment actions. Later victories and item grants are fixtures.

const SCREEN_PATH := "res://ui/expedition/ExpeditionScreen.tscn"
const ICONS := preload("res://core/expedition/catabase_painted_icon_catalog.gd")
const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const OUTPUT := "res://artifacts/meshy_ui"
var is_observer := false
var _resolution := Vector2i(1280, 720)
var _output_dir := ""
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _screen: ExpeditionScreen
var _outcomes_only := false
var _halt_captured := false
var _ergonomics_only := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_observer:
		call_deferred("_run")
	else:
		var observer := Node.new()
		observer.set_script(get_script())
		observer.set("is_observer", true)
		get_tree().root.add_child.call_deferred(observer)


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "ergonomics_only=true":
			_ergonomics_only = true
		if argument == "outcomes_only=true":
			_outcomes_only = true
		if argument.begins_with("resolution="):
			var dimensions := argument.trim_prefix("resolution=").split("x")
			if dimensions.size() == 2:
				_resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_output_dir = ProjectSettings.globalize_path(OUTPUT.path_join("%dx%d" % [_resolution.x, _resolution.y]))
	if _ergonomics_only:
		_output_dir = _output_dir.path_join("ergonomics")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	GameManager.expedition_save_path = _output_dir.path_join("probe_%d.json" % Time.get_ticks_usec())
	get_window().size = _resolution
	if _outcomes_only:
		await _probe_result_screens()
		await _finish()
		return
	_check(GameManager.start_expedition(7642, {"achilles": "painted_g"}), "Canonical painted Catabase starts")
	if GameManager.expedition == null or not await _wait_for_combat():
		await _finish()
		return
	var persistent := GameManager.get_persistent_run_ui()
	var banner := persistent.combat_hud.get_turn_intro_banner() as Control
	var deadline := Time.get_ticks_msec() + 5000
	while banner != null and banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(banner == null or not banner.visible, "Turn introduction finishes naturally")
	await _settle()
	_check_hud_icons(persistent)
	await _capture("combat_hud", persistent.combat_hud)
	await _probe_keyboard_spell(persistent.combat_hud)
	_check(persistent.open_pause_menu(), "Actual pause menu opens from combat")
	await _settle()
	if persistent.is_pause_menu_open():
		_check(get_tree().paused and persistent.has_active_modal(), "Pause owns the real combat modal lock")
		var resume := persistent.pause_menu.get_action_button(&"resume") as Button
		_check(resume != null and resume.icon == ART_THEME.icon("nav", "continue"), "Actual pause action uses painted navigation")
		await _capture("combat_pause", persistent.pause_menu)
		var reduced_before := GameManager.is_reduced_motion_enabled()
		var options := persistent.pause_menu.get_action_button(&"options") as Button
		await _click_button(options)
		_check(GameManager.is_reduced_motion_enabled() != reduced_before, "Actual options click toggles reduced animation")
		await _capture("combat_pause_motion_option", persistent.pause_menu)
		await _click_button(options)
		_check(GameManager.is_reduced_motion_enabled() == reduced_before, "Second options click restores the original preference")
		persistent.pause_menu.resume_requested.emit()
		await _settle()
		_check(not get_tree().paused and not persistent.has_active_modal(), "Resume action releases pause and modal")
	var before_inspection := GameManager.expedition.to_snapshot().duplicate(true)
	(persistent.combat_hud.get_node("%MapButton") as Button).pressed.emit()
	await _settle()
	var inspection := persistent.get("_expedition_inspection") as Control
	_check(inspection != null and persistent.has_active_modal(), "Actual combat map button opens its modal")
	if inspection != null:
		_check(bool(inspection.get("inspection_only")), "Combat route remains inspection-only")
		await _capture("combat_map", inspection)
		persistent.call("_close_expedition_inspection")
		await _settle()
		_check(not persistent.has_active_modal(), "Closing the combat map releases its modal")
	_check(GameManager.expedition.to_snapshot() == before_inspection, "Map consultation does not change the run")
	GameManager.get("_combat_report_tracker").discard()
	_check(GameManager.expedition.combat_won(), "Opening fixture victory reaches reward")
	get_tree().change_scene_to_file(SCREEN_PATH)
	await _settle()
	_screen = get_tree().current_scene as ExpeditionScreen
	if _screen == null:
		_check(false, "Actual expedition screen loaded")
		await _finish()
		return
	_check_screen_art()
	await _check_reward_choices()
	await _capture("first_reward", _screen)
	_check(bool(GameManager.claim_expedition_reward("supplies").get("success", false)), "Claim first reward")
	_screen.call("_render")
	await _settle()
	await _capture("route", _screen)
	await _check_fixed_action("CommitDestination")
	await _probe_equipment()
	if _ergonomics_only:
		await _finish()
		return
	await _advance_to_twelfth_reward()
	if GameManager.expedition.build.completed_depth >= 12:
		await _probe_discoveries_and_capacity()
		await _probe_six_spell_combat()
	await _probe_failed_screen_close()
	await _finish()


func _wait_for_combat() -> bool:
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		var battle := get_tree().current_scene
		if battle == null or not bool(battle.get("runtime_ready_state")):
			continue
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if bool(battle.call("_can_accept_player_intent")):
			_check(true, "Real controllable combat reaches idle")
			return true
	_check(false, "Real controllable combat reaches idle before timeout")
	return false


func _check_hud_icons(persistent: PersistentRunUI, expected_count: int = 4) -> void:
	var count := 0
	var occupied: Array[Dictionary] = []
	for id in ["MoveButton", "EndTurnButton", "InventoryButton", "MapButton", "SkillsButton"]:
		var action := persistent.combat_hud.get_node("%" + id) as Control
		if action != null and action.is_visible_in_tree():
			occupied.append({"name": id, "rect": action.get_global_rect()})
	for button in persistent.combat_hud.get("_spell_buttons"):
		var spell := button.get_meta("spell") as Spell if button.has_meta("spell") else null
		if spell == null:
			continue
		var icon := button.get_node("%SpellIcon") as TextureRect
		_check(icon.texture == ICONS.spell_icon(String(spell.get_effective_spell_id())), "Combat spell uses production artwork")
		var rect: Rect2 = button.get_global_rect()
		for previous in occupied:
			_check(not rect.intersects(previous.rect), "Spell %s does not overlap %s: %s vs %s" % [spell.get_effective_spell_id(), previous.name, rect, previous.rect])
		occupied.append({"name": String(spell.get_effective_spell_id()), "rect": rect})
		count += 1
	_check(count == expected_count, "Real combat HUD displays %d equipped spells" % expected_count)
	for pair in [["InventoryButton", "equipment"], ["MapButton", "map"], ["SkillsButton", "tree"]]:
		var button := persistent.combat_hud.get_node("%" + pair[0]) as Button
		_check(button != null and button.icon != null and button.icon == ART_THEME.icon("nav", pair[1]), "Actual combat navigation icon " + pair[0])
		if button != null:
			_check(button.visible and not button.disabled and not button.tooltip_text.is_empty(), "Combat navigation remains accessible and explained " + pair[0])


func _check_screen_art() -> void:
	_check(_screen.theme == ART_THEME.get_theme(), "Actual expedition screen uses the painted theme")
	for pair in [["map", "map"], ["build", "tree"], ["gear", "equipment"], ["hub", "halt"], ["journal", "journal"]]:
		var button := _screen.find_child("CatabaseTab_" + pair[0], true, false) as Button
		_check(button != null and button.icon != null and button.icon == ART_THEME.icon("nav", pair[1]), "Actual navigation icon " + pair[0])
	for id in ["health", "level", "destiny", "oboles"]:
		var badge := _screen.find_child("Resource_" + id, true, false)
		var matched := false
		if badge != null:
			for image in badge.find_children("*", "TextureRect", true, false):
				if image.texture != null and image.texture == ART_THEME.icon("resources", id):
					matched = true
		_check(matched, "Actual resource badge " + id)


func _probe_equipment() -> void:
	# Fixture grants expose every real icon; equip/unequip still use production actions.
	for id in ICONS.ITEM_IDS:
		_check(bool(GameManager.run_inventory.try_add(StringName(id), 1).get("success", false)), "Fixture inventory grant " + id)
	for id in ["catabase_levier", "catabase_cuirasse", "catabase_prisme"]:
		var instance := _find_inventory_item(id)
		_check(instance != null, "Equipment fixture exists " + id)
		if instance != null:
			var definition := GameManager.item_catalog.get_definition(instance.definition_id)
			_check(bool(GameManager.equip_inventory_item(instance.instance_id, &"achilles", definition.equipment_slot).get("success", false)), "Equip real slot " + id)
	await _navigate("gear")
	await _capture("gear_stats", _screen)
	var body := _screen.get("_body") as Control
	for scroll in body.find_children("*", "ScrollContainer", true, false):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("gear_equipped", _screen)
	var persistent := GameManager.get_persistent_run_ui()
	_check(persistent.open_inventory_screen(&"achilles"), "Real inventory opens between destinations")
	await _settle()
	if persistent.is_inventory_open():
		var inventory := persistent.inventory_screen
		var seen := {}
		for node in inventory.find_children("*", "Button", true, false):
			var tile := node as InventoryItemTile
			if tile == null:
				continue
			var instance: ItemInstance = null
			if tile.instance_id != &"":
				instance = GameManager.run_inventory.get_instance(tile.instance_id)
			elif tile.equipment_slot != ItemDefinition.EquipmentSlot.NONE:
				instance = GameManager.expedition.character.equipment_loadout.get_item(tile.equipment_slot)
			if instance != null and ICONS.ITEM_IDS.has(String(instance.definition_id)):
				seen[String(instance.definition_id)] = true
				_check(tile.icon_view.texture == ICONS.item_icon(String(instance.definition_id)), "Visible inventory/equipment tile matches " + String(instance.definition_id))
		_check(seen.size() == 12, "All twelve painted items are wired into actual inventory/equipment tiles")
		var selected := _find_inventory_item("catabase_lame_sang")
		if selected != null:
			for tile in inventory.find_children("*", "Button", true, false):
				if tile is InventoryItemTile and tile.instance_id == selected.instance_id:
					await _click_button(tile)
					_check(tile.get_theme_color("font_hover_pressed_color").a == 0.0, "Selected hovered tile never draws its native accessibility text over the item label")
					break
		await _settle()
		_check((inventory.get_node("%DetailIcon") as TextureRect).texture == ICONS.item_icon("catabase_lame_sang"), "Selecting the real item displays the painted detail image")
		var details := inventory.get_node("%DetailScroll") as ScrollContainer
		var equip := inventory.get_node("%EquipButton") as Button
		var action_rect := equip.get_global_rect()
		_check(equip.visible and not equip.disabled, "Selected equipment has an enabled equip action immediately")
		_check(not details.is_ancestor_of(equip), "Equip action lives outside the long detail scroll")
		_check(Rect2(Vector2.ZERO, Vector2(_resolution)).encloses(action_rect), "Equip action remains inside the game viewport before scrolling")
		await _capture("inventory_selected", inventory)
		details.scroll_vertical = int(details.get_v_scroll_bar().max_value)
		await _settle()
		_check(equip.get_global_rect() == action_rect, "Equip action stays fixed while the details scroll")
		await _capture("inventory_actions", inventory)
		await _click_button(equip)
		var equipped := GameManager.expedition.character.equipment_loadout.get_item(ItemDefinition.EquipmentSlot.WEAPON)
		_check(equipped != null and String(equipped.definition_id) == "catabase_lame_sang", "Actual mouse click equips the selected painted weapon")
		_check(_find_inventory_item("catabase_levier") != null, "The replaced weapon returns to the real inventory")
		await _capture("inventory_equipped", inventory)
		_check(not details.is_ancestor_of(inventory.get_node("%Feedback")), "Equipment feedback stays with the fixed actions")
		_check(get_viewport().gui_get_focus_owner() != null, "Equipping restores keyboard focus after its action hides")
		(inventory.get_node("%CloseButton") as Button).pressed.emit()
		await _settle()
		_check(not persistent.is_inventory_open() and not persistent.has_active_modal(), "Inventory close releases modal")


func _find_inventory_item(id: String) -> ItemInstance:
	for item in GameManager.run_inventory.get_slots():
		if item != null and String(item.definition_id) == id:
			return item
	return null


func _advance_to_twelfth_reward() -> void:
	var session := GameManager.expedition
	while session.build.completed_depth < 12:
		if session.route.phase == "reward":
			var node := session.route.get_current_node()
			if not _halt_captured and ExpeditionRouteCatalog.is_halt(String(node.kind)):
				await _navigate("hub")
				var sanctuary := _screen.find_child("EnterSanctuary", true, false) as Button
				_check(sanctuary != null and not sanctuary.disabled and sanctuary.icon == ART_THEME.icon("nav", "halt"), "The real halt exposes its Sanctuary entry")
				await _check_fixed_action("EnterSanctuary")
				await _check_fixed_action("LeaveHub")
				await _capture("halt", _screen)
				_halt_captured = true
			var claim := "leave_hub" if ExpeditionRouteCatalog.is_halt(String(node.kind)) else "supplies"
			_check(bool(GameManager.claim_expedition_reward(claim).get("success", false)), "Fixture reward claim " + String(node.id))
		var available := session.route.get_available_nodes()
		if available.is_empty():
			_check(false, "Fixture route retains a next destination")
			return
		_check(session.enter(String(available[0].id)), "Follow an authored route connection")
		if session.route.phase == "combat":
			_check(session.combat_won(), "Intermediate fixture victory")
	await _navigate("map")
	await _capture("twelfth_choice", _screen)


func _probe_discoveries_and_capacity() -> void:
	var session := GameManager.expedition
	for axis in ["elements", "serment"]:
		_check(bool(session.build.unlock_branch(axis).get("success", false)), "Fixture discovery through production branch API " + axis)
	await _navigate("build")
	for doctrine in ["colere", "chiron", "eaque", "elements", "serment"]:
		_screen.set("_doctrine", doctrine)
		_screen.set("_selected_technique", "")
		_screen.set("_show_loadout", false)
		_screen.call("_render")
		await _settle()
		await _capture("tree_" + doctrine, _screen)
		await _check_fixed_action("PurchaseTechnique")
		if doctrine == "colere":
			await _probe_tree_keyboard()
	# Compare both exclusive XII choices from the exact same valid build state.
	var before_choice := session.build.to_snapshot().duplicate(true)
	_check(bool(GameManager.choose_expedition_capacity("mutation").get("success", false)), "Actual XII mutation choice")
	_check(session.character.loadout.knows_spell_id(&"exp_tempest"), "Tempest is learned by the production reward")
	_screen.set("_show_loadout", true)
	_screen.call("_render")
	await _settle()
	await _capture("tempest_kit", _screen)
	_check(session.build.restore_snapshot(before_choice), "Restore pre-choice fixture for the alternative XII branch")
	_check(bool(GameManager.choose_expedition_capacity("slot").get("success", false)), "Actual alternate XII sixth slot choice")
	for id in ["exp_braise", "exp_givre", "exp_foudre"]:
		_check(bool(session.build.learn_spell_card(id).get("success", false)), "Learn fixture elemental card via production API " + id)
	_check(bool(GameManager.purchase_expedition_technique("serment.rempart").get("success", false)), "Buy the actual rempart oath")
	_check(not bool(GameManager.purchase_expedition_technique("serment.brasier").get("success", false)), "Paintings preserve mutually exclusive oath mechanics")
	_check(GameManager.equip_expedition_spell(&"exp_braise", 4), "Equip painted fifth spell")
	_check(GameManager.equip_expedition_spell(&"exp_givre", 5), "Equip painted sixth spell")
	_check(session.character.loadout.get_equipped_spells().size() == 6, "Six real equipped spells")
	_screen.call("_render")
	await _settle()
	await _capture("six_spell_kit", _screen)
	await _navigate("journal")
	await _capture("journal", _screen)


func _navigate(page: String) -> void:
	var button := _screen.find_child("CatabaseTab_" + page, true, false) as Button
	_check(button != null and not button.disabled, "Accessible real navigation button " + page)
	if button == null:
		return
	button.pressed.emit()
	await _settle()
	_check(String(_screen.get("_page")) == page and button.button_pressed, "Navigation action opens and selects " + page)


func _click_button(button: Button) -> void:
	if button == null:
		_check(false, "Mouse interaction requires an actual button")
		return
	var rect := button.get_global_rect()
	var scale_before := button.scale
	var pointer := InputEventMouseMotion.new()
	pointer.position = rect.get_center()
	pointer.global_position = pointer.position
	Input.parse_input_event(pointer)
	await _settle()
	var press := InputEventMouseButton.new()
	press.position = rect.get_center()
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	_check(button.get_global_rect() == rect and button.scale == scale_before, "Hover and press preserve %s target: %s -> %s, scale %s -> %s" % [button.name, rect, button.get_global_rect(), scale_before, button.scale])
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()


func _probe_six_spell_combat() -> void:
	var session := GameManager.expedition
	var current := session.route.get_current_node()
	var claim := "leave_hub" if ExpeditionRouteCatalog.is_halt(String(current.kind)) else "supplies"
	_check(bool(GameManager.claim_expedition_reward(claim).get("success", false)), "Claim XII reward before the next real combat")
	var available := session.route.get_available_nodes()
	var destination := ""
	for node in available:
		if ExpeditionRouteCatalog.is_combat(String(node.kind)):
			destination = String(node.id)
			break
	_check(not destination.is_empty(), "Fixture route offers a real combat after XII")
	if destination.is_empty() or not GameManager.choose_expedition_node(destination):
		_check(false, "Next combat launches through the canonical route action")
		return
	if not await _wait_for_combat():
		return
	var persistent := GameManager.get_persistent_run_ui()
	var banner := persistent.combat_hud.get_turn_intro_banner() as Control
	var deadline := Time.get_ticks_msec() + 5000
	while banner != null and banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(banner == null or not banner.visible, "Second real combat introduction finishes naturally")
	await _settle()
	_check_hud_icons(persistent, 6)
	await _capture("six_spell_combat", persistent.combat_hud)


func _probe_keyboard_spell(hud: Node) -> void:
	var buttons: Array = hud.get("_spell_buttons")
	if buttons.is_empty():
		_check(false, "A real spell is available for keyboard inspection")
		return
	var button := buttons[0] as Button
	button.grab_focus()
	await _settle()
	var tooltip := get_tree().get_first_node_in_group("keyword_tooltip_layer") as KeywordTooltipLayer
	var panel := tooltip.get("_panel") as Control if tooltip != null else null
	_check(panel != null and panel.visible, "Keyboard focus displays the real spell card")
	if panel != null:
		_check(Rect2(Vector2.ZERO, Vector2(_resolution)).encloses(panel.get_global_rect()), "Keyboard spell card stays inside the viewport")
		_check(panel.get_global_rect().end.y < (hud.get_node("%MoveButton") as Control).get_global_rect().position.y, "Spell card remains above the combat action bar")
		await _capture("combat_spell_keyboard", hud)
	button.release_focus()
	if tooltip != null:
		tooltip.hide_all()
	await _settle()


func _check_fixed_action(action_name: String) -> void:
	var button := _screen.find_child(action_name, true, false) as Button
	_check(button != null, "Fixed action exists: " + action_name)
	if button == null:
		return
	var rect := button.get_global_rect()
	_check(Rect2(Vector2.ZERO, Vector2(_resolution)).encloses(rect), "Fixed action is inside the viewport: " + action_name)
	var scrolls := button.get_parent().find_children("*", "ScrollContainer", true, false)
	for scroll in scrolls:
		_check(not scroll.is_ancestor_of(button), "Action is outside the description scroll: " + action_name)
		var original: int = scroll.scroll_vertical
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _settle()
		_check(button.get_global_rect() == rect, "Description scrolling preserves action position: " + action_name)
		scroll.scroll_vertical = original
	await _settle()


func _probe_tree_keyboard() -> void:
	var scroll := _screen.get("_tree_scroll") as ScrollContainer
	var buttons := scroll.find_children("Technique_*", "Button", true, false)
	if buttons.is_empty():
		_check(false, "Tree has actual keyboard destinations")
		return
	var previous := scroll.scroll_vertical
	var button := buttons.back() as Button
	button.grab_focus()
	await _settle()
	_check(scroll.get_global_rect().encloses(button.get_global_rect()), "Focusing a lower tree card scrolls it entirely into view")
	await _capture("tree_keyboard", _screen)
	button.release_focus()
	scroll.scroll_vertical = previous
	await _settle()


func _probe_failed_screen_close() -> void:
	# The failure is isolated to a unique missing fixture directory; no user save is touched.
	var session := GameManager.expedition
	if session == null:
		return
	if session.route.phase == "combat":
		GameManager.get("_combat_report_tracker").discard()
		session.combat_won()
	get_tree().change_scene_to_file(SCREEN_PATH)
	await _settle()
	_screen = get_tree().current_scene as ExpeditionScreen
	var path := GameManager.expedition_save_path
	GameManager.expedition_save_path = _output_dir.path_join("missing_%d/save.json" % Time.get_ticks_usec())
	_screen.call("_close")
	await _settle()
	_check(is_instance_valid(_screen) and get_tree().current_scene == _screen and GameManager.expedition == session, "Failed Accueil save keeps the actual expedition screen and run")
	_check(not str((_screen.get("_status") as Label).text).is_empty(), "Failed Accueil save gives readable feedback on the actual screen")
	var persistent := GameManager.get_persistent_run_ui()
	var dialog := persistent.get("_save_failure_dialog") as ConfirmationDialog
	_check(dialog != null and dialog.visible, "Failed Accueil save offers retry or stay")
	await _capture("save_failure", _screen)
	if dialog != null:
		dialog.hide()
		dialog.canceled.emit()
	GameManager.expedition_save_path = path
	_check(GameManager.retry_expedition_save(), "The preserved run can retry its save")
	await _settle()
	_check(get_tree().current_scene == _screen, "Choosing stay prevents a later retry from leaving the screen")


func _settle() -> void:
	await get_tree().create_timer(0.25, true).timeout
	for frame in 10:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var frame_seen := {"drawn": false}
		var mark_drawn := func() -> void: frame_seen.drawn = true
		RenderingServer.frame_post_draw.connect(mark_drawn, CONNECT_ONE_SHOT)
		# Off-screen verification still needs an explicit draw when the window is idle.
		RenderingServer.force_draw(false)
		var deadline := Time.get_ticks_msec() + 1500
		while not bool(frame_seen.drawn) and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(0.05, true).timeout
		if RenderingServer.frame_post_draw.is_connected(mark_drawn):
			RenderingServer.frame_post_draw.disconnect(mark_drawn)
		_check(bool(frame_seen.drawn), "Rendered frame arrives within the bounded wait")


func _check_reward_choices() -> void:
	var heading := _screen.find_child("RewardHeading", true, false) as Label
	_check(heading != null and heading.size.y < 50, "Reward heading remains horizontal and compact")
	var choices: Array[Button] = []
	for button in _screen.find_children("*", "Button", true, false):
		if button.text == "Choisir cette récompense":
			choices.append(button)
	_check(not choices.is_empty(), "The opening reward offers actual choice buttons")
	var scroll: ScrollContainer
	for button in choices:
		button.grab_focus()
		await _settle()
		var ancestor := button.get_parent()
		while ancestor != null and not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		scroll = ancestor as ScrollContainer
		_check(scroll != null and scroll.get_global_rect().encloses(button.get_global_rect()), "Reward choice is fully reachable by keyboard scrolling")
		_check(Rect2(Vector2.ZERO, Vector2(_resolution)).encloses(button.get_global_rect()), "Reward choice is inside the visible viewport")
		button.release_focus()
	if scroll != null:
		scroll.scroll_vertical = 0
	await _settle()


func _probe_result_screens() -> void:
	get_tree().change_scene_to_file("res://ui/RunResultScreen.tscn")
	await _settle()
	var result := get_tree().current_scene as Control
	_check(result != null, "Actual result screen is instantiated")
	if result == null:
		return
	var original_crest := result.get("crest").texture as Texture2D
	var original_theme := result.theme
	for victory in [true, false]:
		var fixture := {"is_catabase": true, "victory": victory, "run_name": "Catabase", "featured_hero_name": "Achille",
			"rooms_cleared": 20 if victory else 12, "room_total": 20, "reached_room_number": 20 if victory else 13,
			"reached_room_name": "Le dernier seuil" if victory else "Les remparts de l'oubli", "seed_available": true,
			"seed": 7642, "epitaph": "Achille a traversé les ombres du Styx." if victory else "Les serments demeurent, même lorsque la marche s'achève."}
		result.call("_apply_result", fixture)
		await _settle()
		var icon_name := "victory" if victory else "defeat"
		_check(result.get("crest").texture == ART_THEME.icon("resources", icon_name), "Actual result uses the correct " + icon_name + " emblem")
		_check(result.theme == ART_THEME.get_theme(), "Actual Catabase outcome theme")
		var button := result.get("return_button") as Button
		_check(button != null and not button.disabled and button.icon == ART_THEME.icon("nav", "home"), "Outcome keeps its accessible return action")
		await _capture("result_" + icon_name, result)
	result.call("_apply_result", {"is_catabase": false, "victory": true, "run_name": "Le trio", "room_total": 5})
	await _settle()
	_check(result.theme == original_theme and result.get("crest").texture == original_crest, "Other adventures recover the original result theme and crest")
	_check((result.get("return_button") as Button).icon == null, "Other adventures recover the original return action")


func _capture(label: String, root: Node) -> void:
	var overflows: Array[String] = []
	var enabled_buttons := 0
	for control in root.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree():
			continue
		if control is Button and not control.disabled:
			enabled_buttons += 1
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < -1 or rect.end.x > _resolution.x + 1:
			overflows.append("%s: x=%.1f width=%.1f" % [root.get_path_to(control), rect.position.x, rect.size.x])
	_check(overflows.is_empty(), label + " horizontal overflow: " + str(overflows))
	_check(enabled_buttons > 0, label + " retains usable buttons")
	var path := ""
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		_check(image != null and image.get_size() == _resolution, label + " exact capture resolution")
		if image != null:
			path = _output_dir.path_join(label + ".png")
			_check(image.save_png(path) == OK, label + " screenshot saved")
	_captures.append({"view": label, "path": path, "rendered": not path.is_empty(), "horizontal_overflows": overflows, "enabled_buttons": enabled_buttons})


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var report := {"checks": _checks, "failures": _failures, "captures": _captures,
		"scope": "Real opening, pause/resume, item selection and equipment actions. Intermediate victories, item grants and discoveries are fixtures; exclusive XII alternatives use a restored pre-choice build snapshot."}
	if _outcomes_only:
		report["scope"] = "Actual result scene with explicit victory/defeat fixtures and restoration of another adventure's presentation; no claim of playing the final boss."
	if _ergonomics_only:
		report["scope"] = "Targeted final ergonomics regression: real opening HUD, keyboard spell card, pause, route inspection, first reward choices and hovered selected inventory actions. One victory and item grants are fixtures; later trees, halts and six-spell combat are not repeated."
	var file := FileAccess.open(_output_dir.path_join("outcomes_report.json" if _outcomes_only else "report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	file = null
	print("Catabase Meshy UI %dx%d: %d checks, %d failures, %d views" % [_resolution.x, _resolution.y, _checks, _failures.size(), _captures.size()])
	for failure in _failures:
		printerr(failure)
	var persistent := GameManager.get_persistent_run_ui()
	if persistent != null:
		persistent.close_pause_menu()
		persistent.close_inventory_screen()
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	_screen = null
	if scene != null:
		scene.queue_free()
	# Let queued scene destruction and its renderer work finish before shutdown.
	await _settle()
	GameManager.cleanup_run_state()
	await _settle()
	get_tree().quit(0 if _failures.is_empty() else 1)
