extends "res://test/unit/test_sentence_rempart_vfx.gd"
const ApprovedPlayer := preload("res://vfx/class_cards/approved/player.gd")
const Frost := preload("res://vfx/class_cards/approved/frost_ground.gd")


func test_approved_windups_wait_for_confirmation_and_cancel_cleanly() -> void:
	for id in ["g_hook", "a_reap", "r_scatter"]:
		var spell := Cards.make_spell(id)
		var fx: Node = router.prepare_sentence(hero, spell, Vector2i(2, 1))
		assert_eq(fx.get_script(), ApprovedPlayer)
		fx.manual = true
		fx.sample(.7)
		assert_false(fx.confirmed)
		assert_lt(fx._clock, fx.CONTACT)
		router.resolve(hero, spell, { "failed": true })
		assert_true(fx.closed)
		assert_false(fx.hit)
		assert_true(router.sentence_preparations.is_empty())
	assert_null(router.prepare_sentence(hero, Cards.make_spell("t_glacier"), Vector2i(2, 1)))


func test_evidence_uses_pre_hit_hp_and_does_not_change_damage() -> void:
	for hp in [36, 35]:
		var bf = Factory.make_battlefield(7, 5)
		var caster := Factory.make_unit("Moisson", 0)
		var enemy := Factory.make_unit("Cible", 1)
		bf.grid.place_unit(caster, Vector2i(2, 2))
		bf.grid.place_unit(enemy, Vector2i(3, 2))
		enemy.current_hp = hp
		var spell := Cards.make_spell("a_reap")
		var report: Dictionary = bf.caster.cast(caster, spell, enemy.grid_pos)
		assert_false(report.get("failed", false))
		assert_eq(report.card_vfx.targets[0].execute, hp <= 35)
		var actual_hp := enemy.current_hp
		# Same real resolution without the observer must produce identical damage.
		var plain := Cards.make_spell("a_reap")
		plain.modifiers.pop_back()
		enemy.current_hp = hp
		enemy.is_alive = true
		caster.current_ap = 6
		bf.grid.remove_unit(enemy)
		bf.grid.place_unit(enemy, Vector2i(3, 2))
		bf.caster.cast(caster, plain, enemy.grid_pos)
		assert_eq(enemy.current_hp, actual_hp)
		caster.clear_combat_effect_history()
		enemy.clear_combat_effect_history()
		preload("res://test/support/isolated_battlefield_cleanup.gd").dispose_grid(bf.grid)


func test_confirmed_moisson_has_one_hit_and_authoritative_bonus() -> void:
	var victim := Factory.make_unit("Cible", 1)
	host.units.append(victim)
	var spell := Cards.make_spell("a_reap")
	var fx: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
	fx.manual = true
	router.resolve(
		hero,
		spell,
		{
			"action_id": "reap-1",
			"cell": Vector2i(1, 0),
			"damaged_enemies": [victim],
			"card_vfx": {
				"cells": [Vector2i(1, 0)],
				"targets": [{ "unit": victim, "cell": Vector2i(1, 0), "execute": false }],
			},
		},
	)
	assert_true(fx.confirmed)
	assert_true(fx.hit)
	assert_false(fx.empowered, "Post-hit low HP cannot fabricate the conditional bonus")
	assert_eq(router.effects.size(), 1)
	assert_true(router.echoes.is_empty())
	router.clear()
	victim.clear_combat_effect_history()
	host.units.erase(victim)


func test_volley_uses_five_real_cells_and_only_one_enemy_contact() -> void:
	var victim := Factory.make_unit("Cible", 1)
	host.units.append(victim)
	var cells := [Vector2i(3, 2), Vector2i(2, 2), Vector2i(4, 2), Vector2i(3, 1), Vector2i(3, 3)]
	var spell := Cards.make_spell("r_scatter")
	var report := {
		"action_id": "volley-1",
		"cell": cells[0],
		"damaged_enemies": [victim],
		"card_vfx": {
			"cells": cells,
			"targets": [{ "unit": victim, "cell": cells[0], "execute": false }],
		},
	}
	router.resolve(hero, spell, report)
	var fx: Node = router.effects.back()
	fx.manual = true
	assert_eq(fx.destinations.size(), 5)
	assert_eq(fx.sprites.size(), 5)
	assert_eq(fx.hit_points.size(), 1)
	assert_eq(fx._clock, fx.CONTACT, "Immediate casts begin at the confirmed contact")
	router.resolve(hero, spell, report)
	assert_eq(router.effects.size(), 1)
	assert_true(router.echoes.is_empty())
	router.clear()
	victim.clear_combat_effect_history()
	host.units.erase(victim)


func test_chain_releases_at_real_destination_and_shutdown_snaps_only_owned_motion() -> void:
	var victim := Factory.make_unit("Attiré", 1)
	victim.grid_pos = Vector2i(1, 0)
	var view := Node2D.new()
	host.add_child(view)
	var fx := ApprovedPlayer.new()
	host.add_child(fx)
	fx.configure({ "id": "g_hook" }, Vector2.ZERO, 128.0, view)
	fx.manual = true
	fx.follow_displacement(victim, view, Vector2(300, 0), Vector2(100, 0))
	fx.sample(.10)
	assert_gt(view.global_position.x, 100.0)
	assert_lt(view.global_position.x, 300.0)
	assert_eq(victim.grid_pos, Vector2i(1, 0), "Movement presentation never moves the grid")
	fx.cancel()
	assert_eq(view.global_position, Vector2(100, 0))
	var next := ApprovedPlayer.new()
	host.add_child(next)
	next.configure({ "id": "g_hook" }, Vector2.ZERO, 128.0, view)
	next.manual = true
	next.follow_displacement(victim, view, Vector2(300, 0), Vector2(100, 0))
	view.global_position = Vector2(450, 0)
	next.cancel()
	assert_eq(view.global_position, Vector2(450, 0), "A later movement retains ownership")
	victim.clear_combat_effect_history()


func test_frost_restores_settled_and_only_real_terrain_expiration_releases_it() -> void:
	var bf = Factory.make_battlefield(7, 5)
	bf.grid.place_unit(hero, Vector2i(1, 2))
	session.cards.hand.assign([session.cards.add_copy("t_glacier")])
	var report: Dictionary = bf.caster.cast(hero, Cards.make_spell("t_glacier"), Vector2i(3, 2))
	assert_false(report.get("failed", false))
	router.bind_terrain(bf.terrain)
	assert_eq(router.surface_holds.size(), 5)
	var fx: Node = router.surface_holds[Vector2i(3, 2)]
	assert_eq(fx.get_script(), Frost)
	assert_eq(fx.canopy.frame, 23, "Restore does not replay an eruption")
	fx.manual = true
	fx.sample(400.0)
	assert_eq(fx.remaining, 2)
	assert_false(fx.fading)
	bf.terrain.tick_all_effects()
	assert_eq(router.surface_holds.size(), 5)
	assert_eq(fx.remaining, 1)
	bf.terrain.tick_all_effects()
	assert_true(router.surface_holds.is_empty())
	assert_true(fx.fading)
	router.bind_terrain(null)
	preload("res://test/support/isolated_battlefield_cleanup.gd").dispose_grid(bf.grid)


func test_approved_assets_match_blender_provenance() -> void:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://vfx/class_cards/approved/provenance.json")
	)
	var count := 0
	for id: String in data.assets:
		var asset: Dictionary = data.assets[id]
		var path := "res://vfx/class_cards/approved/" + id + ".png"
		assert_eq(FileAccess.get_sha256(path), asset.sha256)
		assert_eq(
			(load(path) as Texture2D).get_size(),
			Vector2(asset.columns * asset.size, asset.rows * asset.size),
		)
		count += int(asset.frames)
	assert_eq(count, 58)


func test_real_pull_evidence_records_partial_and_blocked_attractions() -> void:
	for blocker_x in [3, 4]:
		var bf = Factory.make_battlefield(8, 5)
		var caster := Factory.make_unit("Chaîne", 0)
		var victim := Factory.make_unit("Attiré", 1)
		var blocker := Factory.make_unit("Obstacle vivant", 0)
		bf.grid.place_unit(caster, Vector2i(1, 2))
		bf.grid.place_unit(victim, Vector2i(5, 2))
		bf.grid.place_unit(blocker, Vector2i(blocker_x, 2))
		var report: Dictionary = bf.caster.cast(caster, Cards.make_spell("g_hook"), victim.grid_pos)
		assert_false(report.get("failed", false))
		assert_eq(victim.grid_pos, Vector2i(blocker_x + 1, 2))
		var movement: Array = report.card_vfx.movement
		if blocker_x == 3:
			assert_eq(movement.size(), 1)
			assert_eq(movement[0].from, Vector2i(5, 2))
			assert_eq(
				movement[0].to,
				Vector2i(4, 2),
				"Never invent three cells through an obstacle",
			)
		else:
			assert_true(movement.is_empty(), "A blocked pull has no visual travel")
		for unit in [caster, victim, blocker]:
			unit.clear_combat_effect_history()
		preload("res://test/support/isolated_battlefield_cleanup.gd").dispose_grid(bf.grid)


func test_real_volley_preserves_allies_and_clips_cross_at_board_edge() -> void:
	var bf = Factory.make_battlefield(6, 5)
	var caster := Factory.make_unit("Volée", 0)
	var enemy := Factory.make_unit("Cible", 1)
	var ally := Factory.make_unit("Allié", 0)
	bf.grid.place_unit(caster, Vector2i(2, 2))
	bf.grid.place_unit(enemy, Vector2i(0, 0))
	bf.grid.place_unit(ally, Vector2i(1, 0))
	var report: Dictionary = bf.caster.cast(caster, Cards.make_spell("r_scatter"), enemy.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(report.card_vfx.cells.size(), 3, "Only valid cells get arrows at a corner")
	assert_eq(ally.current_hp, 100)
	assert_eq(report.card_vfx.targets.size(), 1)
	assert_eq(report.damaged_enemies, [enemy])
	for unit in [caster, enemy, ally]:
		unit.clear_combat_effect_history()
	preload("res://test/support/isolated_battlefield_cleanup.gd").dispose_grid(bf.grid)


func test_dodge_has_a_swing_without_hit_or_execution_flash() -> void:
	var victim := Factory.make_unit("Esquive", 1)
	host.units.append(victim)
	var spell := Cards.make_spell("a_reap")
	var fx: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
	fx.manual = true
	router.resolve(
		hero,
		spell,
		{
			"action_id": "reap-dodged",
			"cell": Vector2i(1, 0),
			"damaged_enemies": [],
			"card_vfx": {
				"cells": [Vector2i(1, 0)],
				"targets": [{ "unit": victim, "cell": Vector2i(1, 0), "execute": true }],
			},
		},
	)
	assert_true(fx.confirmed)
	assert_false(fx.hit)
	assert_false(fx.empowered)
	router.clear()
	victim.clear_combat_effect_history()
	host.units.erase(victim)
