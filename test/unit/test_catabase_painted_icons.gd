extends GutTest

const ART := preload("res://core/expedition/catabase_painted_icon_catalog.gd")
const TREE := preload("res://ui/expedition/expedition_tree_canvas.gd")
const MISSING := "res://test/fixtures/absent_catabase_paintings"
const OLD_STRIKE := "res://asset/ui/character_hud/generated/spell_icon_r02_c02.png"
const OLD_DASH := "res://asset/ui/character_hud/generated/spell_icon_r02_c05.png"
const FIRST_BATCH := ["peleid_strike", "fulminant_dash", "pelion_shot", "bronze_guard",
	"crochet", "fauchage", "entaille", "moisson", "rupture", "marque", "feinte",
	"contretemps", "heurt", "posture", "souffle", "marche"]


func test_registry_covers_exactly_the_46_real_spells_and_preserves_their_21_families() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var mapped: Array[String] = []
	assert_eq(ART.SPELL_FAMILIES.size(), 21)
	for family in ART.SPELL_FAMILIES:
		var members: Array = ART.SPELL_FAMILIES[family]
		var gameplay_family := catalog.get_spell_family(String(members[0]))
		for id in members:
			assert_false(mapped.has(String(id)), "Each spell has one presentation family")
			mapped.append(String(id))
			assert_not_null(catalog.get_spell(String(id)), String(id))
			assert_eq(ART.spell_family(String(id)), String(family))
			assert_eq(catalog.get_spell_family(String(id)), gameplay_family)
	var actual: Array[String] = []
	for spell in catalog.all_spells():
		actual.append(String(spell.get_effective_spell_id()))
	actual.sort()
	mapped.sort()
	assert_eq(actual.size(), 46)
	assert_eq(mapped, actual)


func test_all_55_tree_nodes_resolve_to_41_techniques_or_nine_stat_glyphs() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	assert_eq(catalog.nodes.size(), 55)
	var spell_nodes := 0
	var stat_nodes := 0
	var stats := {}
	for node in catalog.nodes:
		var paths := ART.node_candidate_paths(node)
		assert_false(paths.is_empty(), String(node.id))
		if not String(node.spell_id).is_empty():
			spell_nodes += 1
			assert_not_null(catalog.get_spell(String(node.spell_id)))
			for spell_path in ART.spell_candidate_paths(String(node.spell_id)):
				assert_true(paths.has(spell_path), "Tree and HUD share the same technique artwork")
		else:
			stat_nodes += 1
			stats[String(node.stat[0])] = true
			assert_eq(paths, [ART.ASSET_ROOT.path_join("tree/stats/%s.png" % node.stat[0])])
	assert_eq(spell_nodes, 41)
	assert_eq(stat_nodes, 14)
	assert_eq(stats.size(), 9)


func test_all_12_equipment_ids_share_art_between_inventory_and_rewards() -> void:
	var definitions := ExpeditionEquipmentCatalog.new().definitions()
	assert_eq(definitions.size(), 12)
	var seen := {}
	for item in definitions:
		var id := String(item.item_id)
		seen[id] = true
		assert_true(ART.ITEM_IDS.has(id), id)
		assert_eq(ART.item_candidate_paths(id), [ART.EQUIPMENT_ROOT.path_join(id + ".png")])
		assert_same(item.icon, ART.item_icon(id))
		assert_same(item.get_inventory_icon(), item.icon)
		assert_same(item.get_reward_card_texture(), item.icon)
		assert_true(item.compatible_character_ids.has(&"achilles"))
	assert_eq(seen.size(), ART.ITEM_IDS.size())


func test_missing_and_unknown_assets_preserve_fallback_without_loading_invalid_paths() -> void:
	var fallback := load(OLD_STRIKE) as Texture2D
	for family in ART.SPELL_FAMILIES:
		for id in ART.SPELL_FAMILIES[family]:
			assert_same(ART.spell_icon(String(id), fallback, MISSING), fallback)
	for id in ART.ITEM_IDS:
		assert_same(ART.item_icon(String(id), fallback, MISSING), fallback)
	for node in ExpeditionBuildCatalog.new().nodes:
		assert_same(ART.node_icon(node, fallback, MISSING), fallback)
	assert_same(ART.spell_icon("unknown", fallback), fallback)
	assert_same(ART.item_icon("../../unknown", fallback), fallback)
	assert_eq(ART.spell_candidate_paths("../../unknown"), [])
	assert_eq(ART.node_candidate_paths({"id": "unknown", "stat": "invalid"}), [])


func test_specific_forms_have_priority_and_tempest_never_uses_a_thrust_image() -> void:
	var paths := ART.spell_candidate_paths("exp_crochet_mutation")
	assert_eq(paths, [ART.ICON_ROOT + "/exp_crochet_mutation.png", ART.ICON_ROOT + "/crochet.png"])
	assert_eq(ART.spell_candidate_paths("exp_tempest"), [ART.ICON_ROOT + "/exp_tempest.png"])
	var strike := load(OLD_STRIKE) as Texture2D
	var dash := load(OLD_DASH) as Texture2D
	assert_same(ART._first_texture([MISSING + "/missing.png", OLD_STRIKE, OLD_DASH], null), strike)
	assert_same(ART._first_texture([OLD_DASH, OLD_STRIKE], null), dash)
	assert_same(ART._first_texture([MISSING + "/missing.png"], dash), dash)


func test_runtime_icons_and_hud_share_paintings_without_modifying_authored_spells() -> void:
	var authored: Array[Spell] = []
	var original_icons: Array[Texture2D] = []
	for path in ExpeditionBuildCatalog.BASE_PATHS:
		var spell := load(path) as Spell
		authored.append(spell)
		original_icons.append(spell.icon)
	var catalog := ExpeditionBuildCatalog.new()
	var theme := load("res://data/ui/achilles_hud_theme_refined.tres") as CharacterHUDThemeData
	for index in authored.size():
		var source := authored[index]
		var runtime := catalog.base_spells()[index]
		var id := String(source.get_effective_spell_id())
		var painted := ART.spell_icon(id)
		assert_same(source.icon, original_icons[index])
		assert_same(runtime.icon, painted if painted != null else original_icons[index])
		assert_same(runtime.damage_scaling, source.damage_scaling)
		assert_same(runtime.skill_tree, source.skill_tree)
		assert_eq(runtime.ap_cost, source.ap_cost)
		assert_eq(runtime.get_effective_spell_id(), source.get_effective_spell_id())
		assert_same(theme.get_spell_icon_for(source), theme.get_spell_icon(source.get_effective_spell_id()), "Canonical spells retain the original HUD presentation")
		if painted != null:
			assert_not_same(runtime, source)
			assert_same(theme.get_spell_icon_for(runtime), painted)
	for spell in catalog.all_spells():
		var painted := ART.spell_icon(String(spell.get_effective_spell_id()))
		if painted != null:
			assert_same(spell.icon, painted)
			assert_same(theme.get_spell_icon_for(spell), painted)
	var tempest := catalog.get_spell("exp_tempest")
	assert_same(tempest.icon, ART.spell_icon("exp_tempest", authored[0].icon))


func test_tree_keeps_its_real_selection_signal_and_does_not_illustrate_undiscovered_nodes() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var offers: Array[Dictionary] = []
	for id in ["briseur.learn_a", "chiron.root", "danseur.learn_a", "elements.learn_a"]:
		var offer := catalog.get_node(id).duplicate(true)
		offer.merge({"owned": false, "available": true, "discovered": id != "elements.learn_a"})
		offers.append(offer)
	var tree := TREE.new()
	add_child_autofree(tree)
	tree.configure(offers, "briseur.learn_a")
	watch_signals(tree)
	for offer in offers:
		var button := tree.get_node("Technique_" + String(offer.id).replace(".", "_")) as Button
		assert_string_contains(button.text, String(offer.title))
		if offer.discovered:
			assert_same(button.icon, ART.node_icon(offer))
		else:
			assert_null(button.icon)
	var crochet := tree.get_node("Technique_briseur_learn_a") as Button
	crochet.pressed.emit()
	assert_signal_emitted_with_parameters(tree, "technique_selected", ["briseur.learn_a"])


func test_available_first_batch_paintings_are_256_pixels_and_cover_37_appropriate_spells() -> void:
	var supported := 0
	for family in FIRST_BATCH:
		var path := ART.ICON_ROOT.path_join(String(family) + ".png")
		var texture := ART._first_texture([path], null)
		if texture != null:
			assert_eq(texture.get_size(), Vector2(256, 256), path)
		for id in ART.SPELL_FAMILIES[family]:
			if id == "exp_tempest":
				continue
			supported += 1
			assert_true(ART.spell_candidate_paths(String(id)).has(path))
	assert_eq(supported, 37)


func test_reconfiguring_the_tree_replaces_previous_buttons_icons_and_selection_handlers() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var first := catalog.get_node("briseur.learn_a").duplicate(true)
	first.merge({"owned": false, "available": true, "discovered": true})
	var second := catalog.get_node("danseur.learn_a").duplicate(true)
	second.merge({"owned": false, "available": true, "discovered": true})
	var tree := TREE.new()
	add_child_autofree(tree)
	tree.configure([first], String(first.id))
	tree.configure([second], String(second.id))
	await wait_process_frames(2)
	watch_signals(tree)
	assert_null(tree.get_node_or_null("Technique_briseur_learn_a"))
	assert_eq(tree._buttons.size(), 1)
	assert_eq(tree._rects.size(), 1)
	var layout_connections := tree.get_signal_connection_list("resized").filter(func(entry: Dictionary) -> bool: return entry.callable == Callable(tree, "_layout"))
	assert_eq(layout_connections.size(), 1)
	var button := tree.get_node("Technique_danseur_learn_a") as Button
	assert_same(button.icon, ART.node_icon(second))
	button.pressed.emit()
	assert_signal_emitted_with_parameters(tree, "technique_selected", ["danseur.learn_a"])
	assert_signal_emit_count(tree, "technique_selected", 1)


func test_real_catabase_initialization_and_build_restore_sync_icons_for_both_appearances() -> void:
	var theme := load("res://data/ui/achilles_hud_theme_refined.tres") as CharacterHUDThemeData
	for variants in [{}, {"achilles": "painted_g"}]:
		var run := ExpeditionRunFactory.create(7642, variants)
		var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
		assert_true(resolution.is_valid(), str(resolution.errors))
		if not resolution.is_valid():
			continue
		var data: UnitData = resolution.heroes[0]
		var state := CharacterRunState.new()
		assert_true(state.initialize(Unit.from_data(data), data, 4, data.progression_profile))
		var session := ExpeditionSession.new()
		session.initialize(state, 7642)
		var snapshot := session.build.to_snapshot()
		for pass_index in range(2):
			if pass_index == 1:
				assert_true(session.build.restore_snapshot(snapshot))
			assert_eq(state.unit.spells.size(), 4)
			for spell in state.unit.spells:
				var id := String(spell.get_effective_spell_id())
				assert_same(spell, session.build.catalog.get_spell(id), "The actual combat unit uses the Catabase catalog copy")
				var painted := ART.spell_icon(id)
				if painted != null:
					assert_same(spell.icon, painted)
					assert_same(theme.get_spell_icon_for(spell), painted)
		state.dispose()
		session.build.character_state = null
		session.character = null
