extends GutTest
## Production assets must load, preserve the real mechanics, and hide unknown content.

const ART := preload("res://core/expedition/catabase_painted_icon_catalog.gd")
const TREE := preload("res://ui/expedition/expedition_tree_canvas.gd")
const MAP := preload("res://ui/expedition/expedition_map_canvas.gd")
const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const NEW_SPELLS := ["exp_tempest", "exp_braise", "exp_givre", "exp_foudre", "exp_serment_rempart", "exp_serment_brasier"]
const UI_TEXTURES := ["button_normal", "button_primary", "button_selected", "button_disabled", "tab_normal", "tab_selected",
	"panel", "card", "tooltip", "banner", "slot_normal", "slot_selected", "slot_locked", "portrait_frame",
	"background", "tree_fresco", "route_parchment"]
const NAV_IDS := ["map", "tree", "equipment", "halt", "journal", "home", "close", "settings", "save", "continue", "lock", "check"]
const RESOURCE_IDS := ["oboles", "destiny", "health", "level", "victory", "defeat"]


func test_every_real_spell_loads_art_and_the_six_new_silhouettes_are_distinct() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	assert_eq(catalog.all_spells().size(), 46)
	for spell in catalog.all_spells():
		var id := String(spell.get_effective_spell_id())
		var texture := ART.spell_icon(id)
		assert_not_null(texture, id)
		assert_same(spell.icon, texture, "The real runtime spell carries its painted artwork: " + id)
		if texture != null:
			assert_eq(texture.get_size(), Vector2(256, 256), id)
	var resources := {}
	for id in NEW_SPELLS:
		var texture := ART.spell_icon(id)
		if texture == null:
			continue
		assert_false(resources.has(texture.resource_path), "Different new techniques need distinct images: " + id)
		resources[texture.resource_path] = true
	assert_eq(resources.size(), 6)
	assert_not_same(ART.spell_icon("exp_tempest"), ART.spell_icon("achilles_peleid_strike"))
	assert_eq(catalog.get_spell("exp_serment_rempart").max_uses_per_combat, 2)
	assert_eq(catalog.get_spell("exp_serment_brasier").max_uses_per_combat, 2)


func test_all_twelve_equipment_images_reach_inventory_and_reward_presentations() -> void:
	var definitions := ExpeditionEquipmentCatalog.new().definitions()
	assert_eq(definitions.size(), 12)
	var resources := {}
	for definition in definitions:
		var id := String(definition.item_id)
		var texture := ART.item_icon(id)
		assert_not_null(texture, id)
		assert_same(definition.icon, texture)
		assert_same(definition.get_inventory_icon(), texture)
		assert_same(definition.get_reward_card_texture(), texture)
		assert_same(InventoryItemTile.presentation_icon(definition), texture)
		if texture != null:
			assert_eq(texture.get_size(), Vector2(256, 256), id)
			assert_false(resources.has(texture.resource_path), id)
			resources[texture.resource_path] = true
	assert_eq(resources.size(), 12)


func test_nine_stat_glyphs_and_five_doctrines_plus_achilles_are_available() -> void:
	assert_eq(ART.STAT_IDS.size(), 9)
	for id in ART.STAT_IDS:
		assert_not_null(ART.stat_icon(id), id)
	for id in ["colere", "chiron", "eaque", "elements", "serment", "achilles"]:
		assert_not_null(ART.emblem_icon(id), id)
	for node in ExpeditionBuildCatalog.new().nodes:
		assert_not_null(ART.node_icon(node), "Every real technique/stat node has artwork: " + String(node.id))
	assert_null(ART.stat_icon("../../unknown"))
	assert_null(ART.emblem_icon("../../unknown"))


func test_route_markers_never_reveal_an_unknown_destination_type() -> void:
	for kind in ART.ROUTE_IDS:
		assert_not_null(ART.route_icon(kind), String(kind))
		assert_not_null(ART.map_icon(kind), "Drawn map marker: " + String(kind))
	assert_null(ART.route_icon("../../unknown"))
	for hidden_field in ["knowledge", "kind", "presentation_kind"]:
		var node := {"kind": "boss", "presentation_kind": "boss", "knowledge": "known"}
		node[hidden_field] = "unknown"
		var before := node.duplicate(true)
		assert_eq(ART.route_presentation_kind(node), "unknown")
		assert_same(ART.route_node_icon(node), ART.route_icon("unknown"))
		assert_same(ART.map_node_icon(node), ART.map_icon("unknown"), "Drawn markers also conceal uncertain content")
		assert_eq(node, before, "Icon lookup cannot mutate the safe preview")
	assert_same(ART.route_node_icon({"kind": "merchant"}), ART.route_icon("merchant"))


func test_map_uses_only_safe_previews_and_selection_does_not_commit_the_route() -> void:
	var route := ExpeditionRouteState.new()
	route.initialize(7642)
	var before := route.to_snapshot().duplicate(true)
	var previews := route.get_visible_nodes()
	var map := MAP.new()
	add_child_autofree(map)
	map.set_route(route)
	watch_signals(map)
	assert_eq(map._buttons.size(), previews.size())
	assert_eq(map._preview_nodes, previews)
	for node in previews:
		assert_false(bool(node.hidden))
		var button := map.get_node_or_null("Destination_" + String(node.id)) as Button
		assert_not_null(button, String(node.id))
		if button != null:
			var icon := button.get_node_or_null("Content/Kind/DestinationIcon") as TextureRect
			assert_not_null(icon, "Every visible destination uses its real marker texture")
			if icon != null:
				assert_same(icon.texture, ART.map_node_icon(node), "The map uses the simplified drawing of its safe preview")
				assert_eq(String(icon.get_meta("presentation_kind", "")), ART.route_presentation_kind(node))
		if String(node.kind) == "unknown":
			assert_eq(ART.route_presentation_kind(node), "unknown")
	if not previews.is_empty():
		var id := String(previews[0].id)
		(map.get_node("Destination_" + id) as Button).pressed.emit()
		assert_signal_emitted_with_parameters(map, "node_selected", [id])
	assert_eq(route.to_snapshot(), before, "Inspecting a route marker is never a path commitment")


func test_discovered_tree_uses_the_new_spell_but_unknown_nodes_have_no_image() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var shown := catalog.get_node("elements.learn_a").duplicate(true)
	var hidden := catalog.get_node("serment.rempart").duplicate(true)
	shown.merge({"discovered": true, "owned": false, "available": true})
	hidden.merge({"discovered": false, "owned": false, "available": false})
	var tree := TREE.new()
	add_child_autofree(tree)
	tree.configure([shown, hidden], String(shown.id))
	watch_signals(tree)
	var shown_button := tree.get_node("Technique_elements_learn_a") as Button
	var hidden_button := tree.get_node("Technique_serment_rempart") as Button
	assert_same(shown_button.icon, ART.spell_icon("exp_braise"))
	assert_null(hidden_button.icon)
	assert_string_contains(hidden_button.text, "À découvrir")
	shown_button.pressed.emit()
	assert_signal_emitted_with_parameters(tree, "technique_selected", [String(shown.id)])


func test_every_ui_texture_navigation_icon_and_resource_glyph_loads() -> void:
	for name in UI_TEXTURES:
		var texture := ART_THEME.texture(name)
		assert_not_null(texture, name)
		if texture != null:
			assert_gt(texture.get_width(), 0, name)
			assert_gt(texture.get_height(), 0, name)
	for id in NAV_IDS:
		assert_not_null(ART_THEME.icon("nav", id), id)
	for id in RESOURCE_IDS:
		assert_not_null(ART_THEME.icon("resources", id), id)


func test_button_and_panel_states_use_textures_with_preserved_readable_interiors() -> void:
	for pair in [["button", "normal"], ["button", "primary"], ["button", "selected"], ["button", "disabled"],
		["tab", "normal"], ["tab", "selected"], ["slot", "normal"], ["slot", "selected"], ["slot", "locked"],
		["panel", "normal"], ["card", "normal"], ["tooltip", "normal"], ["banner", "normal"]]:
		var style := ART_THEME.style(pair[0], pair[1]) as StyleBoxTexture
		assert_not_null(style, String(pair[0]) + "/" + String(pair[1]))
		if style != null:
			assert_not_null(style.texture)
			assert_gt(style.content_margin_left, 0.0)
			assert_gt(style.content_margin_top, 0.0)
			assert_lt(style.get_texture_margin(SIDE_LEFT) + style.get_texture_margin(SIDE_RIGHT), float(style.texture.get_width()))
			assert_lt(style.get_texture_margin(SIDE_TOP) + style.get_texture_margin(SIDE_BOTTOM), float(style.texture.get_height()))
	assert_true(ART_THEME.style("button", "focus") is StyleBoxFlat, "Keyboard focus stays a crisp separate outline")
	for variation in ["PremiumScreen", "PremiumPanel", "PremiumInset", "PremiumHeader", "PremiumFooter", "PremiumCard"]:
		var original := PremiumUI.get_theme().get_stylebox("panel", variation)
		var painted := ART_THEME.get_theme().get_stylebox("panel", variation)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			assert_eq(painted.get_margin(side), original.get_margin(side), "Painting preserves the effective layout margin: " + variation)


func test_inventory_theme_is_reversible_for_other_adventures() -> void:
	var inventory := load("res://ui/inventory/InventoryScreen.tscn").instantiate() as InventoryScreen
	add_child_autofree(inventory)
	var button := inventory.get_node("%EquipButton") as Button
	var original_theme := inventory.theme
	var original_icon := button.icon
	var original_expand := button.expand_icon
	var had_width_override := button.has_theme_constant_override("icon_max_width")
	var original_width := button.get_theme_constant("icon_max_width")
	var actions := button.get_parent()
	var original_actions_parent := actions.get_parent()
	var original_actions_index := actions.get_index()
	var details := inventory.get_node("%DetailScroll")
	var original_scroll_parent := details.get_parent()
	ART_THEME.apply_inventory(inventory, true)
	assert_same(inventory.theme, ART_THEME.get_theme())
	assert_same(button.icon, ART_THEME.icon("nav", "equipment"))
	assert_eq(actions.get_parent().name, &"CatabaseActionFooter")
	assert_false(details.is_ancestor_of(actions), "Actions stay outside the long details scroll")
	ART_THEME.apply_inventory(inventory, true)
	ART_THEME.apply_inventory(inventory, false)
	assert_same(inventory.theme, original_theme)
	assert_same(button.icon, original_icon)
	assert_eq(button.expand_icon, original_expand)
	assert_eq(button.has_theme_constant_override("icon_max_width"), had_width_override)
	assert_eq(button.get_theme_constant("icon_max_width"), original_width)
	assert_same(actions.get_parent(), original_actions_parent)
	assert_eq(actions.get_index(), original_actions_index)
	assert_same(details.get_parent(), original_scroll_parent)


func test_pause_theme_restores_original_art_and_keeps_unavailable_actions_disabled() -> void:
	var pause := load("res://ui/menus/dark_pause_menu.tscn").instantiate() as DarkPauseMenu
	add_child_autofree(pause)
	var root := pause.get_node("%PauseRoot") as Control
	var header := pause.find_child("HeaderTexture", true, false) as TextureRect
	var frame := pause.find_child("MainFrame", true, false) as TextureRect
	var button := pause.get_action_button(&"resume") as Button
	var close := pause.get_close_button()
	var original_theme := root.theme
	var original_header := header.texture
	var original_close := close.texture_normal
	var original_icon := button.icon
	ART_THEME.apply_pause(pause, true)
	assert_same(root.theme, ART_THEME.get_theme())
	var header_plate := header.get_parent().get_node("CatabaseHeaderPlate") as Panel
	assert_true(header_plate.visible)
	assert_true(header_plate.get_theme_stylebox("panel") is StyleBoxTexture)
	assert_false(header.visible, "The original header is hidden behind the painted nine-slice plate")
	assert_same(close.texture_normal, ART_THEME.icon("nav", "close"))
	assert_same(button.icon, ART_THEME.icon("nav", "continue"))
	assert_true(bool(button.get_meta("catabase_motion_enabled", false)))
	button.scale = Vector2.ONE * 1.012
	button.call("_sync_emphasis")
	assert_eq(button.scale, Vector2.ONE, "Catabase pause keeps the hit target stable")
	assert_false(frame.visible)
	assert_true(pause.get_action_button(&"characters").disabled)
	assert_true(pause.get_action_button(&"compendium").disabled)
	ART_THEME.apply_pause(pause, true)
	ART_THEME.apply_pause(pause, false)
	assert_same(root.theme, original_theme)
	assert_same(header.texture, original_header)
	assert_true(header.visible)
	assert_false(header_plate.visible)
	assert_same(close.texture_normal, original_close)
	assert_same(button.icon, original_icon)
	assert_false(bool(button.get_meta("catabase_motion_enabled", false)))
	assert_true(frame.visible)
	assert_false((frame.get_parent().get_node("CatabasePaintedFrame") as Control).visible)


func test_button_feedback_preserves_clicks_geometry_and_reduced_motion() -> void:
	var previous_reduced := GameManager.is_reduced_motion_enabled()
	GameManager.set_reduced_motion_enabled(false)
	var button := Button.new()
	button.text = "Choisir"
	button.position = Vector2(40, 32)
	button.size = Vector2(180, 48)
	add_child_autofree(button)
	ART_THEME.bind_button_motion(button)
	ART_THEME.bind_button_motion(button)
	watch_signals(button)
	var before_rect := button.get_rect()
	var before_scale := button.scale
	var before_modulate := button.self_modulate
	button.button_down.emit()
	await wait_process_frames(2)
	assert_eq(button.get_rect(), before_rect)
	assert_eq(button.scale, before_scale)
	button.button_up.emit()
	button.pressed.emit()
	assert_signal_emit_count(button, "pressed", 1)
	assert_false(button.disabled)
	GameManager.set_reduced_motion_enabled(true)
	ART_THEME.reveal(button)
	button.button_down.emit()
	ART_THEME.finish_motion(button)
	assert_eq(button.get_rect(), before_rect)
	assert_eq(button.scale, before_scale)
	assert_eq(button.modulate.a, 1.0)
	var tween := button.get_meta("catabase_motion_tween") as Tween if button.has_meta("catabase_motion_tween") else null
	assert_true(tween == null or not tween.is_valid() or not tween.is_running(), "Reduced motion has no active feedback animation")
	ART_THEME.bind_button_motion(button, false)
	assert_eq(button.self_modulate, before_modulate, "Other adventures recover the original button appearance")
	var tile := load("res://ui/inventory/InventoryItemTile.tscn").instantiate() as InventoryItemTile
	add_child_autofree(tile)
	tile.mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(tile.scale, Vector2.ONE, "Reduced motion also disables the pre-existing inventory tile zoom")
	var tile_tween := tile.get("_hover_tween") as Tween
	assert_true(tile_tween == null or not tile_tween.is_valid() or not tile_tween.is_running())
	GameManager.set_reduced_motion_enabled(previous_reduced)
