extends "res://test/unit/test_consumable_cards_effects.gd"
const Player := preload("res://vfx/class_cards/permutation/player.gd")
const Controller := preload("res://vfx/class_cards/permutation/controller.gd")


func test_swap_records_original_sites_without_damage_or_extra_cost() -> void:
	var f := field_for("arpenteur")
	var from: Vector2i = f.hero.grid_pos
	var to: Vector2i = f.target.grid_pos
	var hp := [f.hero.current_hp, f.target.current_hp]
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "r08"), to)
	assert_false(report.get("failed", false))
	assert_eq(report.card_vfx.origin, from)
	assert_eq(report.card_vfx.targets.size(), 1)
	assert_eq(report.card_vfx.targets[0].cell, to)
	assert_same(report.card_vfx.targets[0].unit, f.target)
	assert_eq([f.hero.grid_pos, f.target.grid_pos], [to, from])
	assert_eq(f.hero.current_ap, 2)
	assert_eq([f.hero.current_hp, f.target.current_hp], hp)
	assert_true(report.damaged_enemies.is_empty())
	assert_eq(f.terrain.active_surface_cells().size(), 0)
	assert_false(
		f.caster.spell_moves_caster(f.hero, Spells.make_spell("r08")),
		"Swap uses immediate position exchange, no dash tween",
	)


func test_rejected_boss_empty_and_ally_leave_both_sites_untouched() -> void:
	for kind in ["boss", "empty", "ally"]:
		var f := field_for("arpenteur")
		f.target.set_meta("cc2_boss", kind == "boss")
		if kind == "ally":
			f.target.team = 0
		var from: Vector2i = f.hero.grid_pos
		var to: Vector2i = f.target.grid_pos
		var report: Dictionary = f.caster.cast(
			f.hero,
			force_hand(f, "r08"),
			Vector2i(2, 4) if kind == "empty" else to,
		)
		assert_true(report.get("failed", false), kind)
		assert_eq([f.hero.grid_pos, f.target.grid_pos, f.hero.current_ap], [from, to, 4])
		assert_false(report.has("card_vfx"))


func test_upgrade_extends_reach_without_extra_effects_or_damage() -> void:
	for upgraded in [false, true]:
		var f := field_for("arpenteur")
		assert_true(f.grid.relocate_unit(f.hero, Vector2i(0, 3)))
		assert_true(f.grid.relocate_unit(f.target, Vector2i(6, 3)))
		if upgraded:
			f.cards.upgraded_ids.append("r08")
		var spell := force_hand(f, "r08")
		assert_eq(spell.spell_range, 6 if upgraded else 5)
		var report: Dictionary = f.caster.cast(f.hero, spell, f.target.grid_pos)
		assert_eq(bool(report.get("failed", false)), not upgraded)
		assert_eq(f.target.current_hp, 500)


func test_anticipation_waits_for_confirmation_and_keeps_fixed_ground_sites() -> void:
	var a := Node2D.new()
	var b := Node2D.new()
	add_child(a)
	add_child(b)
	b.position = Vector2(180, 50)
	var fx := Player.new()
	add_child(fx)
	fx.configure(
		{
			"id": "cc2_r08",
			"permutation_preparing": true,
			"permutation_sites": [
				{ "point": a.position, "view": a },
				{ "point": b.position, "view": b },
			],
		},
		Vector2.ZERO,
		128,
	)
	fx.manual = true
	fx.sample(.8)
	assert_false(fx.confirmed)
	assert_lt(fx._clock, Player.CONTACT)
	assert_eq(fx.sheets.size(), 6)
	var p := a.position
	a.position = b.position
	b.position = p
	fx.confirm([b, a])
	assert_true(fx.confirmed)
	assert_eq(fx.elapsed, Player.CONTACT)
	for sheet in fx.sheets:
		assert_eq(sheet.sprite.global_position, fx.sites[sheet.site].point)
		assert_same(sheet.sprite.get_parent(), b if sheet.site == 0 else a)
	fx.sample(.70)
	for sheet in fx.sheets:
		assert_false(sheet.sprite.visible)
	fx.cancel()
	await wait_process_frames(1)
	assert_eq(a.get_child_count() + b.get_child_count(), 0)
	a.queue_free()
	b.queue_free()


func test_cancel_does_not_change_actor_visibility_scale_or_position() -> void:
	var a := Node2D.new()
	add_child(a)
	a.position = Vector2(40, 80)
	a.scale = Vector2(1.3, .7)
	a.modulate = Color(.7, .8, .9, .6)
	var fx := Player.new()
	add_child(fx)
	fx.configure(
		{
			"id": "cc2_r08",
			"permutation_preparing": true,
			"permutation_sites": [{ "point": a.position, "view": a }],
		},
		a.position,
		128,
	)
	fx.sample(.25)
	fx.cancel()
	await wait_process_frames(1)
	assert_eq(a.position, Vector2(40, 80))
	assert_eq(a.scale, Vector2(1.3, .7))
	assert_eq(a.modulate, Color(.7, .8, .9, .6))
	assert_true(a.visible)
	assert_eq(a.get_child_count(), 0)
	a.queue_free()


class Host:
	extends Node2D
	var units: Array = []


class GridView:
	extends Node2D
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


func test_router_confirms_only_exchange_and_suppresses_generic_travel() -> void:
	var f := field_for("arpenteur")
	var session := ExpeditionSession.new()
	session.cards = f.cards
	f.hero.set_meta("ct_session", weakref(session))
	var host := Host.new()
	add_child(host)
	host.units.assign([f.hero, f.target])
	var grid_view := GridView.new()
	host.add_child(grid_view)
	var manager: Node = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	manager.register_battle_view(grid_view)
	var router: Node = manager._class_card_router
	var spell := force_hand(f, "r08")
	var refused: Node = router.prepare_sentence(f.hero, spell, f.target.grid_pos)
	assert_not_null(refused)
	router.resolve(f.hero, spell, { "failed": true })
	assert_true(refused.closed)
	var fx: Node = router.prepare_sentence(f.hero, spell, f.target.grid_pos)
	fx.manual = true
	var report: Dictionary = f.caster.cast(f.hero, spell, f.target.grid_pos)
	router.resolve(f.hero, spell, report)
	assert_true(fx.confirmed)
	assert_eq(fx.sites.size(), 2)
	assert_true(router.arrivals.is_empty())
	assert_true(router.echoes.is_empty())
	var count: int = router.effects.size()
	router.resolve(f.hero, spell, report)
	assert_eq(router.effects.size(), count)
	manager.unregister_battle_view()
	assert_true(fx.closed)
	manager.queue_free()
	host.queue_free()
	await wait_process_frames(1)


func test_no_arrival_for_unconfirmed_or_partial_exchange() -> void:
	var f := field_for("arpenteur")
	var fx := Player.new()
	add_child(fx)
	fx.configure({ "id": "cc2_r08", "permutation_preparing": true }, Vector2.ZERO, 128)
	var report := {
		"card_vfx": {
			"origin": f.hero.grid_pos,
			"targets": [{ "unit": f.target, "cell": f.target.grid_pos }],
		}
	}
	Controller.resolve(null, f.hero, Spells.make_spell("r08"), report, fx)
	assert_true(fx.closed)
	assert_false(fx.confirmed)
	await wait_process_frames(1)


func test_original_atlases_have_48_verified_poses() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Player.ART + "provenance.json")
	)
	var poses := 0
	for id in manifest.assets:
		var asset: Dictionary = manifest.assets[id]
		assert_eq(FileAccess.get_sha256(Player.ART + id + ".png"), asset.sha256)
		poses += int(asset.frames)
	assert_eq(poses, 48)
