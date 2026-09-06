extends GutTest
## Asset completeness and consumer integration against the actual Champion catalog.

const ART = preload("res://ui/progression/champion/mastery_atlas_art.gd")
const CODEX = preload("res://ui/progression/champion/champion_codex.gd")
const PROFILE: CharacterProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
const MANIFEST := "res://tools/mastery_atlas_art/manifest.json"
var _state: CharacterRunState
var _codex
var _profile_before: String
var _manager_before: Dictionary


func before_each() -> void:
	_profile_before = RunProgressionCloneService.semantic_fingerprint(PROFILE)
	_manager_before = GameManager.get_inventory_equipment_snapshot().duplicate(true)
	var data := UnitData.new()
	data.unit_id = PROFILE.character_id
	data.unit_name = "Achille"
	data.max_hp = 110
	data.attack_power = 18
	data.spells = PROFILE.spells
	data.progression_profile = PROFILE
	_state = CharacterRunState.new()
	assert_true(_state.initialize(Unit.from_data(data), data))


func after_each() -> void:
	if is_instance_valid(_codex):
		_codex.queue_free()
	await get_tree().process_frame
	_state.dispose()
	assert_eq(RunProgressionCloneService.semantic_fingerprint(PROFILE), _profile_before)
	assert_eq(GameManager.get_inventory_equipment_snapshot(), _manager_before)


func test_every_authored_mastery_and_attribute_has_a_unique_atlas_region() -> void:
	var nodes := PROFILE.mastery_catalog.node_catalog()
	assert_eq(nodes.size(), 36)
	assert_eq(ART.node_ids().size(), 36)
	assert_eq(ART.attribute_ids().size(), 4)
	var regions: Dictionary = {}
	for node_id in nodes:
		assert_true(ART.node_ids().has(node_id), "Artwork covers " + str(node_id))
		var texture: Texture2D = ART.node_icon(node_id)
		_assert_unique_region(texture, str(node_id), regions)
		assert_same(ART.node_icon(node_id), texture, "Repeated UI requests share the cached texture")
		assert_gt(ART.node_accent(node_id).a, 0.0)
	for attribute_id in ChampionProgressionProfile.ATTRIBUTE_IDS:
		assert_true(ART.attribute_ids().has(attribute_id))
		_assert_unique_region(ART.attribute_icon(attribute_id), str(attribute_id), regions)
	assert_eq(regions.size(), 40, "No two gameplay identities silently share a fallback illustration")


func test_manifest_names_and_grid_cells_match_the_runtime_catalog() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_eq(int(manifest.version), 2)
	var entries: Dictionary = {}
	var nodes := PROFILE.mastery_catalog.node_catalog()
	for atlas in manifest.atlases:
		assert_true(ResourceLoader.exists(str(atlas.path)), "Authored atlas exists: " + str(atlas.path))
		var columns := int(atlas.columns)
		var rows := int(atlas.rows)
		assert_gt(columns, 0)
		assert_gt(rows, 0)
		for entry in atlas.entries:
			var id := StringName(entry.id)
			assert_false(entries.has(str(id)), "Manifest IDs are unique")
			entries[str(id)] = entry
			assert_false(str(entry.motif).strip_edges().is_empty())
			if nodes.has(id):
				assert_eq(str(entry.name), (nodes[id] as SkillTreeNodeData).display_name)
			var texture: Texture2D = ART.node_icon(id) if nodes.has(id) else ART.attribute_icon(id)
			assert_true(texture is AtlasTexture)
			if not texture is AtlasTexture:
				continue
			var mapped := texture as AtlasTexture
			assert_eq(mapped.atlas.resource_path, str(atlas.path))
			var cell_size := mapped.atlas.get_size() / Vector2(columns, rows)
			var cell := Rect2(Vector2(int(entry.column), int(entry.row)) * cell_size, cell_size)
			assert_true(cell.grow(1.0).encloses(mapped.region), "%s stays in its documented grid cell" % id)
	assert_eq(entries.size(), 40)
	for node_id in ART.node_ids():
		assert_true(entries.has(str(node_id)))
	for attribute_id in ART.attribute_ids():
		assert_true(entries.has(str(attribute_id)))


func test_graph_and_inspector_use_the_same_dedicated_icon_for_all_36_masteries() -> void:
	await _open()
	var before := _state.get_progression_snapshot().duplicate(true)
	var sections: Array[StringName] = []
	for doctrine in PROFILE.mastery_catalog.doctrines:
		sections.append(doctrine.discipline_id)
	sections.append(&"advanced")
	for section in sections:
		_codex.select_section(section)
		for node_id in _codex.get_node_buttons():
			var node_button := _codex.get_node_buttons()[node_id] as Button
			var graph_icon := node_button.get_node("MasteryIcon") as TextureRect
			assert_same(graph_icon.texture, ART.node_icon(node_id))
			assert_eq(graph_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			_codex.inspect_node(node_id)
			var detail_icon := _codex.find_child("MasteryDetailIcon", true, false) as TextureRect
			assert_not_null(detail_icon, "Inspector identifies " + str(node_id))
			if detail_icon != null:
				assert_same(detail_icon.texture, ART.node_icon(node_id))
				assert_eq(detail_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_true(_codex.get_action_button().disabled)
	assert_eq(_state.get_progression_snapshot(), before)


func test_attributes_and_doctrine_progress_display_real_state_without_spending() -> void:
	assert_true(_state.champion_progression.grant_purchased_mastery(1))
	assert_true(bool(_state.purchase_mastery_node(&"achilles_wrath_focused_fury").get("purchased", false)))
	await _open()
	var before := _state.get_progression_snapshot().duplicate(true)
	for index in PROFILE.mastery_catalog.doctrines.size():
		var doctrine := PROFILE.mastery_catalog.doctrines[index]
		var progress := _codex.find_child("DoctrineProgress_" + str(doctrine.discipline_id), true, false) as ProgressBar
		assert_not_null(progress)
		if progress != null:
			assert_eq(progress.max_value, 9.0)
			assert_eq(progress.value, 1.0 if index == 0 else 0.0)
	_codex.select_section(&"attributes")
	for attribute_id in ChampionProgressionProfile.ATTRIBUTE_IDS:
		var icon := _codex.find_child("AttributeIcon_" + str(attribute_id), true, false) as TextureRect
		assert_not_null(icon)
		if icon != null:
			assert_same(icon.texture, ART.attribute_icon(attribute_id))
			assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for button in _codex.get("_content").find_children("*", "Button", true, false):
		assert_true(button.disabled, "Consultative characteristic cards cannot spend points")
	assert_eq(_state.get_progression_snapshot(), before)


func test_minimap_keeps_filtered_context_and_never_turns_inspection_into_a_purchase() -> void:
	await _open()
	var before := _state.get_progression_snapshot().duplicate(true)
	var graph = _codex.get_graph()
	assert_not_null(graph.get_minimap())
	_codex.set_search_query("Fureur lucide")
	await get_tree().process_frame
	await get_tree().process_frame
	var map: Dictionary = graph.get_minimap_snapshot()
	var map_nodes: Array = map.nodes
	assert_eq(map_nodes.size(), 9, "Minimap retains the entire doctrine while search dims context")
	assert_eq(map_nodes.filter(func(node): return bool(node.matched)).size(), 1)
	_codex.inspect_node(&"achilles_wrath_focused_fury")
	assert_true(_codex.get_action_button().disabled)
	_codex.get_action_button().pressed.emit()
	assert_eq(_state.get_progression_snapshot(), before)


func test_inspector_keeps_the_graph_exclusion_state_when_points_are_exhausted() -> void:
	var champion := _state.champion_progression
	champion.award_encounter_xp(&"atlas_exclusion_fixture", champion.profile.xp_for_level(14), true)
	var doctrine := PROFILE.mastery_catalog.doctrines[0]
	var path: Array = SkillTreeResolver.champion_capstone_paths(doctrine, 14)[0]
	for id in path:
		assert_true(bool(_state.purchase_mastery_node(StringName(id)).get("purchased", false)))
	champion.unspent_mastery_points = 0
	await _open()
	for node in SkillTreeResolver.champion_doctrine_nodes(doctrine):
		if node.node_type != SkillTreeNodeData.NodeType.CAPSTONE or champion.selected_node_ids.has(node.upgrade_id):
			continue
		_codex.inspect_node(node.upgrade_id)
		assert_eq(_codex.get_node_buttons()[node.upgrade_id].get_meta("mastery_state"), "excluded")
		assert_eq((_codex.find_child("MasteryIdentityState", true, false) as Label).text, "EXCLUE")
		assert_true(_codex.get_action_button().disabled)


func _open() -> void:
	_codex = CODEX.new()
	_codex.configure(_state, true)
	add_child(_codex)
	await get_tree().process_frame
	await get_tree().process_frame


func _assert_unique_region(texture: Texture2D, id: String, regions: Dictionary) -> void:
	assert_not_null(texture, "Dedicated illustration exists for " + id)
	assert_true(texture is AtlasTexture, "Illustration comes from the new artwork atlases: " + id)
	if not texture is AtlasTexture:
		return
	var atlas := texture as AtlasTexture
	assert_not_null(atlas.atlas)
	if atlas.atlas == null:
		return
	assert_gte(atlas.region.size.x, 96.0)
	assert_gte(atlas.region.size.y, 96.0)
	assert_true(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region))
	var key := "%s:%s" % [atlas.atlas.resource_path, atlas.region]
	assert_false(regions.has(key), "A unique cropped motif is assigned to " + id)
	regions[key] = id
