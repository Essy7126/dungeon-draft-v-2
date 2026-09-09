extends GutTest
## Real resource, spell, AI and route contracts. Missing art is a failure.

const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
const SLUGS := ["sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe"]
const SCENES := ["SentinelleAirain", "RejetonBraise", "MolosseStyx", "LamieLethe"]
const ACTION_COUNTS := {"idle": 8, "walk": 12, "attack": 8, "cast": 8, "hit": 4, "death": 8}
var _fixture_grids: Array[GridData] = []


func after_each() -> void:
	# GridData and Unit own each other while placed. Release fixture occupancy
	# explicitly rather than leaving RefCounted cycles until process shutdown.
	for grid: GridData in _fixture_grids:
		Cleanup.dispose_grid(grid)
	_fixture_grids.clear()


func _data(slug: String) -> UnitData:
	return load("res://data/units/enemies/catabase_%s.tres" % slug) as UnitData


func _spell(data: UnitData, special: bool) -> Spell:
	for value: Spell in data.spells:
		if (value.visual_action == Spell.VisualAction.HEAVY) == special:
			return value
	return null


func _fixture(data: UnitData, spell: Spell) -> Dictionary:
	var field := Factory.make_battlefield(14, 7)
	_fixture_grids.append(field.grid)
	var enemy := Unit.from_data(data)
	var target := Unit.new("Cible de validation", 0, 500, 10, 6, 4, 20)
	field.grid.place_unit(enemy, Vector2i(3, 3))
	field.grid.place_unit(target, Vector2i(3 + maxi(1, spell.minimum_range), 3))
	for activation in range(4):
		enemy.start_turn()
	return {"field": field, "enemy": enemy, "target": target}


func test_logic_four_monsters_bind_real_visuals_and_have_distinct_tactical_roles() -> void:
	var roles := {}
	for index in SLUGS.size():
		var data := _data(SLUGS[index])
		assert_not_null(data, SLUGS[index])
		if data == null: continue
		assert_eq(str(data.unit_id), "catabase_" + SLUGS[index])
		assert_eq(data.team, 1)
		assert_false(data.basic_attack_enabled, "AI must pay for the authored attacks")
		assert_eq(data.spells.size(), 2)
		assert_gt(data.max_hp, 0)
		assert_gt(data.max_mp, 0)
		assert_not_null(data.visual_scene)
		if data.visual_scene != null:
			assert_eq(data.visual_scene.resource_path,
				"res://characters/enemies/catabase_monsters/%sIsoUnitView.tscn" % SCENES[index])
		roles[str([data.max_hp, data.max_mp, data.ai_behavior, data.armure])] = true
		assert_not_null(_spell(data, false), "primary attack")
		assert_not_null(_spell(data, true), "special technique")
	assert_eq(roles.size(), 4, "Four different combat profiles")
	assert_gt(_data("sentinelle_airain").armure, _data("rejeton_braise").armure)
	assert_gt(_data("molosse_styx").max_mp, _data("sentinelle_airain").max_mp)


func test_imported_art_has_all_explicit_directions_and_real_atlas_regions() -> void:
	for slug: String in SLUGS:
		var atlas_images := {}
		var frames := load("res://assets/characters/catabase_monsters/%s/sprite_frames.tres" % slug) as SpriteFrames
		assert_not_null(frames, slug)
		if frames == null: continue
		var data := _data(slug)
		var portrait := data.preview_sprite_frames
		assert_not_null(portrait, slug + ": portrait resource bound for timeline and inspection")
		if portrait != null:
			assert_true(portrait.has_animation(data.preview_sprite_animation))
			var portrait_image := portrait.get_frame_texture(data.preview_sprite_animation, 0).get_image()
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://assets/characters/catabase_monsters/%s/manifest.json" % slug))
			var source := _load_source_png("res://art/source/characters/catabase_monsters/%s/base_frame_E.png" % slug)
			var crop: Array = manifest.portrait_rect
			var expected_portrait := source.get_region(Rect2i(crop[0], crop[1], crop[2], crop[3]))
			if portrait_image.is_compressed(): assert_eq(portrait_image.decompress(), OK)
			portrait_image.convert(Image.FORMAT_RGBA8)
			expected_portrait.convert(Image.FORMAT_RGBA8)
			_assert_visible_pixels_equal(portrait_image, expected_portrait, "Portrait preserves the fixed E view")
		for direction: String in ["N", "E", "S", "W"]:
			for action: String in ACTION_COUNTS:
				var animation := StringName(action + "_" + direction)
				assert_true(frames.has_animation(animation), slug + ": " + str(animation))
				if not frames.has_animation(animation): continue
				assert_eq(frames.get_frame_count(animation), int(ACTION_COUNTS[action]))
				var distinct_poses := {}
				for frame in frames.get_frame_count(animation):
					var texture := frames.get_frame_texture(animation, frame) as AtlasTexture
					assert_not_null(texture, slug + ": nonempty atlas frame")
					if texture == null: continue
					assert_not_null(texture.atlas, "Imported GPU texture exists")
					assert_eq(texture.get_size(), Vector2(512, 384), "Margins retain the logical canvas")
					assert_eq(texture.region.size + texture.margin.size, Vector2(512, 384))
					assert_true(texture.filter_clip, "Linear filtering cannot bleed adjacent poses")
					assert_true(Rect2(Vector2.ZERO, Vector2(512, 384)).encloses(
						Rect2(texture.margin.position, texture.region.size)))
					if texture.atlas != null:
						assert_true(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region))
						if not atlas_images.has(texture.atlas.resource_path):
							var imported_image := texture.atlas.get_image()
							if imported_image.is_compressed(): assert_eq(imported_image.decompress(), OK)
							imported_image.convert(Image.FORMAT_RGBA8)
							atlas_images[texture.atlas.resource_path] = imported_image
					else: continue
					# AtlasTexture.get_image() returns only the packed region. Restore
					# its logical margin before checking ground/canvas or source bytes.
					var atlas_image: Image = atlas_images[texture.atlas.resource_path]
					var pixels := Image.create(512, 384, false, Image.FORMAT_RGBA8)
					pixels.blit_rect(atlas_image, Rect2i(texture.region), Vector2i(texture.margin.position))
					if action == "idle" and frame == 0:
						var reference := _load_source_png("res://art/source/characters/catabase_monsters/%s/base_frame_%s.png" % [slug, direction])
						reference.convert(Image.FORMAT_RGBA8)
						_assert_visible_pixels_equal(pixels, reference, "Frame zero preserves source pixels and placement")
					var used := pixels.get_used_rect()
					assert_gt(used.size.x, 0, "Every pose is visible")
					assert_gt(used.size.y, 0, "Every pose is visible")
					assert_gt(used.position.x, 0, "No clipping at left edge")
					assert_gt(used.position.y, 0, "No clipping at top edge")
					assert_lt(used.end.x, 512, "No clipping at right edge")
					assert_lt(used.end.y, 384, "No clipping at bottom edge")
					assert_almost_eq(pixels.get_pixel(0, 0).a, 0.0, 0.001)
					assert_almost_eq(pixels.get_pixel(511, 383).a, 0.0, 0.001)
					distinct_poses[hash(pixels.get_data())] = true
				var minimum_poses := 3 if action == "hit" else (9 if action == "walk" else 6)
				assert_gte(distinct_poses.size(), minimum_poses, "Actual changing poses: " + str(animation))


func _load_source_png(path: String) -> Image:
	# Read source bytes explicitly; these are authoring references, not exports.
	var image := Image.new()
	assert_eq(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)), OK, path)
	return image


func _assert_visible_pixels_equal(actual: Image, expected: Image, message: String) -> void:
	# Match the actual importer: fix_alpha_border recolors RGB below alpha 20/255,
	# including faint visible fringes. Keep exact composited equality afterwards;
	# the independent Python audit also checks every original PNG RGBA byte.
	var composited := actual.duplicate() as Image
	var reference := expected.duplicate() as Image
	reference.fix_alpha_edges()
	composited.premultiply_alpha()
	reference.premultiply_alpha()
	assert_true(composited.get_data() == reference.get_data(), message)


func test_logic_every_primary_attack_spends_ap_and_reduces_health_once() -> void:
	for slug: String in SLUGS:
		var data := _data(slug)
		var spell := _spell(data, false)
		assert_not_null(spell, slug)
		if spell == null: continue
		var fixture := _fixture(data, spell)
		var enemy: Unit = fixture.enemy
		var target: Unit = fixture.target
		var caster: SpellCaster = fixture.field.caster
		assert_true(caster.can_cast(enemy, spell, target.grid_pos), slug + ": legal primary target")
		var ap_before := enemy.current_ap
		var hp_before := target.current_hp
		var context := caster.begin_cast(enemy, spell, target.grid_pos)
		assert_false(context.failed)
		caster.resolve_cast(context)
		assert_eq(enemy.current_ap, ap_before - spell.ap_cost)
		assert_lt(target.current_hp, hp_before, slug + ": real impact")
		var hp_after := target.current_hp
		caster.resolve_cast(context)
		assert_eq(target.current_hp, hp_after, "Repeated resolve cannot double-hit")


func test_logic_specials_apply_push_periodic_damage_or_movement_penalty() -> void:
	var verified_statuses := 0
	var verified_pushes := 0
	for slug: String in SLUGS:
		var data := _data(slug)
		var spell := _spell(data, true)
		assert_not_null(spell, slug)
		if spell == null: continue
		var fixture := _fixture(data, spell)
		var enemy: Unit = fixture.enemy
		var target: Unit = fixture.target
		var caster: SpellCaster = fixture.field.caster
		var before_hp := target.current_hp
		var before_pos := target.grid_pos
		assert_true(caster.can_cast(enemy, spell, target.grid_pos), slug)
		caster.cast(enemy, spell, target.grid_pos)
		if spell.is_delayed():
			assert_eq(target.current_hp, before_hp, "Telegraph precedes damage")
			enemy.start_turn()
			var pending := caster.resolve_pending_activation(enemy, [enemy, target])
			assert_true(bool(pending.resolved), "Telegraphed ability really resolves")
		assert_lt(target.current_hp, before_hp, slug + ": special impact")
		assert_gt(enemy.get_spell_cooldown_remaining(spell), 0, "Special cannot spam each activation")
		if spell.push_distance > 0:
			assert_ne(target.grid_pos, before_pos, "Sentinel push changes occupied cell")
			verified_pushes += 1
		if spell.applied_status != null:
			var found := false
			for entry: Dictionary in target.get_active_statuses():
				var status := entry.get("data") as StatusData
				found = found or (status != null and status.get_effective_status_id() == spell.applied_status.get_effective_status_id())
			assert_true(found, slug + ": promised status must exist on target")
			target.start_turn()
			var hp_before_tick := target.current_hp
			var mp_before_tick := target.current_mp
			target.process_statuses()
			if spell.applied_status.damage_per_turn > 0:
				assert_lt(target.current_hp, hp_before_tick, "Burn/bleed actually ticks")
			if spell.applied_status.mp_reduction > 0:
				assert_lt(target.current_mp, mp_before_tick, "Slow actually removes movement points")
			verified_statuses += 1
	assert_gte(verified_statuses, 3, "Fire, bleed and slow exercised")
	assert_gte(verified_pushes, 1)


func test_logic_ai_approaches_and_executes_legal_spells_with_authored_budgets() -> void:
	for slug: String in SLUGS:
		var data := _data(slug)
		var field := Factory.make_battlefield(15, 3)
		_fixture_grids.append(field.grid)
		var enemy := Unit.from_data(data)
		var target := Unit.new("Cible IA", 0, 1000, 10, 6, 4, 20)
		field.grid.place_unit(enemy, Vector2i(1, 1))
		field.grid.place_unit(target, Vector2i(11, 1))
		var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
		var moves := 0
		var casts := 0
		for activation in range(8):
			enemy.start_turn()
			var pending: Dictionary = field.caster.resolve_pending_activation(enemy, [enemy, target])
			if bool(pending.consume_activation): continue
			var actions: Array = ai.build_action_plan(enemy, [enemy, target]).to_actions()
			for action: Dictionary in actions:
				if action.type == "move":
					var path: Array = action.path
					assert_eq(path[0], enemy.grid_pos)
					var cost := int(field.pathfinder.path_cost_breakdown(path, enemy).total)
					assert_lte(cost, enemy.current_mp, slug + ": affordable path")
					assert_true(enemy.spend_mp(cost))
					assert_true(field.grid.relocate_unit(enemy, path[-1]))
					moves += 1
				elif action.type == "cast":
					assert_true(field.caster.can_cast(enemy, action.spell, action.cell), slug + ": AI cast is legal")
					field.caster.cast(enemy, action.spell, action.cell)
					casts += 1
				else:
					fail_test("Unexpected free basic attack for " + slug)
		assert_gt(moves, 0, slug + ": moves from distant spawn")
		assert_gt(casts, 0, slug + ": reaches attack range")
		assert_lt(target.current_hp, 1000, slug + ": AI causes real health loss")


func test_logic_delayed_burn_cancels_when_target_escapes_or_dies() -> void:
	var data := _data("rejeton_braise")
	var spell := _spell(data, true)
	assert_true(spell.is_delayed(), "Fournaise must retain its avoidable telegraph")
	for escape in [true, false]:
		var fixture := _fixture(data, spell)
		var enemy: Unit = fixture.enemy
		var target: Unit = fixture.target
		var caster: SpellCaster = fixture.field.caster
		assert_true(caster.can_cast(enemy, spell, target.grid_pos))
		caster.cast(enemy, spell, target.grid_pos)
		if escape:
			fixture.field.grid.relocate_unit(target, Vector2i(13, 6))
		else:
			target.take_damage(5000, enemy)
		var hp_before := target.current_hp
		enemy.start_turn()
		var result := caster.resolve_pending_activation(enemy, [enemy, target])
		assert_true(bool(result.blocked))
		assert_false(bool(result.resolved))
		assert_eq(target.current_hp, hp_before, "Cancelled telegraph causes no extra damage")
		assert_true(target.get_active_statuses().is_empty(), "Cancelled telegraph must not apply burn")
		assert_true(enemy.pending_ability.is_empty())


func test_logic_delayed_burn_respects_cover_and_never_attaches_to_a_lethal_target() -> void:
	var data := _data("rejeton_braise")
	var spell := _spell(data, true)
	for cover in [true, false]:
		var fixture := _fixture(data, spell)
		var enemy: Unit = fixture.enemy
		var target: Unit = fixture.target
		var caster: SpellCaster = fixture.field.caster
		assert_true(caster.can_cast(enemy, spell, target.grid_pos))
		caster.cast(enemy, spell, target.grid_pos)
		if cover:
			fixture.field.grid.set_type(Vector2i(4, 3), GridData.CellType.WALL)
		else:
			target.current_hp = 1 # Explicit lethal-impact fixture.
		var hp_before := target.current_hp
		enemy.start_turn()
		var result := caster.resolve_pending_activation(enemy, [enemy, target])
		assert_eq(bool(result.resolved), not cover)
		assert_eq(bool(result.blocked), cover)
		if cover:
			assert_eq(target.current_hp, hp_before, "Cover cancels the impact")
		else:
			assert_false(target.is_alive, "The real delayed impact is lethal")
		assert_true(target.get_active_statuses().is_empty(), "No burn on cancelled or lethal target")


func test_logic_seeded_run_rosters_spawn_all_four_monsters_without_overfilling_rooms() -> void:
	var seen := {}
	var checked := 0
	for seed_value in [2401, 42, 777]:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
			var room := ExpeditionRunFactory.make_room(node, seed_value)
			assert_not_null(room)
			assert_lte(room.enemies.size(), room.enemy_spawn_zone.size(), str(node.id))
			assert_false(room.enemies.is_empty())
			var grid := EncounterGridFactory.build_from_room(room)
			assert_not_null(grid, str(node.id) + ": production topology")
			if grid != null:
				var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
				var plan := planner.build_plan(room.encounter_definition,
					room.hero_spawn_zone, room.enemy_spawn_zone, seed_value)
				assert_true(bool(plan.get("valid", false)),
					"Role-distance placement %s seed %d: %s" % [node.id, seed_value, plan.get("reason", "")])
				assert_eq((plan.get("placements", []) as Array).size(), room.enemies.size())
			for role in CatabaseMonsterEncounterCatalog.composition_for(node):
				seen[CatabaseMonsterEncounterCatalog.Evolution.family_for(role)] = true
			checked += 1
	assert_gt(checked, 40, "Full seeded production routes inspected")
	for family in [&"sentinelle", &"rejeton", &"molosse", &"lamie", &"archer", &"officiant"]:
		assert_true(seen.has(family), str(family) + ": reachable run encounter")


func test_logic_runtime_difficulty_copies_do_not_mutate_source_stats_or_spells() -> void:
	var source_signatures := {}
	for slug: String in SLUGS:
		var data := _data(slug)
		source_signatures[slug] = [data.max_hp, data.attack_power, data.spells.map(func(spell: Spell): return spell.damage)]
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(2401):
		if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
		ExpeditionRunFactory.make_room(node, 2401)
	for slug: String in SLUGS:
		var data := _data(slug)
		assert_eq([data.max_hp, data.attack_power, data.spells.map(func(spell: Spell): return spell.damage)], source_signatures[slug])
