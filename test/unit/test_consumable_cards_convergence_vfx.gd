extends "res://test/unit/test_consumable_cards_effects.gd"
const Player := preload("res://vfx/class_cards/convergence/player.gd")
const Controller := preload("res://vfx/class_cards/convergence/controller.gd")
var rigs: Array = []
const CENTER := Vector2i(3, 2)


class Host:
	extends Node2D
	var units: Array = []


class GridView:
	extends Node2D
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


func rig(f: Dictionary) -> Dictionary:
	var session := ExpeditionSession.new()
	session.cards = f.cards
	f.hero.set_meta("ct_session", weakref(session))
	var host := Host.new()
	add_child(host)
	host.units.assign(f.grid.get_units())
	var grid_view := GridView.new()
	host.add_child(grid_view)
	var manager: Node = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	manager.register_battle_view(grid_view)
	var result := {
		"host": host,
		"manager": manager,
		"router": manager._class_card_router,
		"session": session,
	}
	rigs.append(result)
	return result


func after_each() -> void:
	for r in rigs:
		r.manager.unregister_battle_view()
		r.manager.free()
		r.host.free()
	rigs.clear()
	super.after_each()


func enemy(f: Dictionary, cell: Vector2i, id: String) -> Unit:
	var unit := Factory.make_unit(id, 1)
	unit.unit_id = StringName(id)
	unit.max_hp.base_value = 500
	unit.current_hp = 500
	unit.set_meta("cc2_ruleset", Profile.ID)
	f.grid.place_unit(unit, cell)
	return unit


func test_three_actual_pulls_then_three_contacts_in_the_five_cell_cross() -> void:
	for upgraded in [false, true]:
		var f := field_for("thaumaturge")
		f.grid.relocate_unit(f.target, CENTER + Vector2i.UP * 2)
		var left := enemy(f, CENTER + Vector2i.LEFT * 2, "enemy_02")
		var right := enemy(f, CENTER + Vector2i.RIGHT * 2, "enemy_03")
		var outside := enemy(f, CENTER + Vector2i.RIGHT * 3, "enemy_04")
		if upgraded:
			f.cards.upgraded_ids.append("t08")
		var r := rig(f)
		var spell := force_hand(f, "t08")
		var fx: Node = r.router.prepare_sentence(f.hero, spell, CENTER)
		fx.manual = true
		fx.sample(.20)
		assert_false(fx.confirmed)
		assert_true(fx.sheets.is_empty(), "No damage or pull effect before confirmation")
		var report: Dictionary = f.caster.cast(f.hero, spell, CENTER)
		assert_false(report.get("failed", false))
		assert_eq(spell.spell_range, 5 if upgraded else 4)
		assert_eq(f.hero.current_ap, 1)
		assert_eq(f.target.grid_pos, CENTER + Vector2i.UP)
		assert_eq(left.grid_pos, CENTER + Vector2i.LEFT)
		assert_eq(right.grid_pos, CENTER + Vector2i.RIGHT)
		assert_eq(outside.grid_pos, CENTER + Vector2i.RIGHT * 3)
		assert_eq(outside.current_hp, 500)
		assert_eq(report.card_vfx.movement.size(), 3)
		assert_eq(report.card_vfx.cells.size(), 5)
		assert_eq(fx.pull_paths.size(), 3)
		assert_eq(fx.hit_points.size(), 3)
		assert_eq(fx.arm_points.size(), 4)
		var before := [
			f.hero.current_ap,
			f.target.current_hp,
			left.current_hp,
			right.current_hp,
			f.cards.snapshot(),
		]
		for time in [.28, .34, .45, .8]:
			fx.sample(time)
		assert_eq(
			[
				f.hero.current_ap,
				f.target.current_hp,
				left.current_hp,
				right.current_hp,
				f.cards.snapshot(),
			],
			before,
		)
		var count: int = r.router.effects.size()
		r.router.resolve(f.hero, spell, report)
		assert_eq(r.router.effects.size(), count, "Same action cannot replay")
		assert_true(r.router.flights.is_empty() and r.router.echoes.is_empty())
		assert_true(r.router.surface_holds.is_empty() and r.router.holds.is_empty())


func test_occupied_destination_does_not_create_a_pull_or_remote_impact() -> void:
	var f := field_for("thaumaturge")
	f.grid.relocate_unit(f.target, CENTER + Vector2i.UP * 2)
	var ally := Factory.make_unit("Ally", 0)
	f.grid.place_unit(ally, CENTER + Vector2i.UP)
	var r := rig(f)
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "t08"), CENTER)
	assert_false(report.get("failed", false))
	assert_eq(f.target.grid_pos, CENTER + Vector2i.UP * 2)
	assert_eq(f.target.current_hp, 500)
	var fx: Node = r.router.effects.back()
	assert_true(fx.pull_paths.is_empty())
	assert_true(fx.hit_points.is_empty())
	assert_eq(fx.arm_points.size(), 4, "Cross geometry remains; the ally receives no local contact")


func test_wall_blocks_pull_and_clips_the_cross_blade() -> void:
	var f := field_for("thaumaturge")
	f.grid.relocate_unit(f.target, CENTER + Vector2i.UP * 2)
	f.grid.set_type(CENTER + Vector2i.UP, GridData.CellType.WALL)
	var r := rig(f)
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "t08"), CENTER)
	assert_false(report.get("failed", false))
	assert_eq(f.target.current_hp, 500)
	var fx: Node = r.router.effects.back()
	assert_true(fx.pull_paths.is_empty() and fx.hit_points.is_empty())
	assert_false(r.manager._grid_cell_global(CENTER + Vector2i.UP) in fx.arm_points)


func test_shield_contact_and_lethal_contact_use_post_pull_cell() -> void:
	for lethal in [false, true]:
		var f := field_for("thaumaturge")
		f.grid.relocate_unit(f.target, CENTER + Vector2i.UP * 2)
		if lethal:
			f.target.current_hp = 1
		else:
			f.target.add_shield(100)
		var r := rig(f)
		var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "t08"), CENTER)
		var fx: Node = r.router.effects.back()
		assert_eq(report.card_vfx.contacts.size(), 1)
		assert_eq(report.card_vfx.contacts[0].cell, CENTER + Vector2i.UP)
		assert_eq(fx.hit_points.size(), 1)
		assert_eq(fx.hit_points[0], r.manager._grid_cell_global(CENTER + Vector2i.UP))
		assert_eq(f.target.is_alive, not lethal)
		assert_eq(f.target.current_hp, 0 if lethal else 500)


func test_refused_cast_and_closed_battle_remove_preparation_without_spending() -> void:
	var f := field_for("thaumaturge")
	var r := rig(f)
	var spell := force_hand(f, "t08")
	var fx: Node = r.router.prepare_sentence(f.hero, spell, Vector2i(0, 0))
	fx.manual = true
	var before: Dictionary = f.cards.snapshot()
	var report: Dictionary = f.caster.cast(f.hero, spell, Vector2i(0, 0))
	assert_true(report.get("failed", false))
	r.router.resolve(f.hero, spell, report)
	assert_true(fx.closed)
	assert_eq(f.cards.snapshot(), before)
	assert_eq(f.hero.current_ap, 4)
	fx = r.router.prepare_sentence(f.hero, spell, CENTER)
	r.router.clear(true)
	assert_true(fx.closed)
	assert_true(r.router.sentence_preparations.is_empty())
	assert_true(r.router.effects.is_empty())


func test_current_cards_only_and_no_replay_on_restoration() -> void:
	var f := field_for("thaumaturge")
	var r := rig(f)
	assert_true(Controller.handles({ "id": "cc2_t08" }))
	assert_false(Controller.handles({ "id": "t_pull" }))
	assert_false(Controller.handles({ "id": "cc2_t08", "feedback_phase": "tick" }))
	r.router._restore_unit_holds()
	assert_true(r.router.effects.is_empty())
	f.hero.remove_meta("ct_session")
	assert_null(r.router.prepare_sentence(f.hero, Spells.make_spell("t08"), CENTER))


func test_atlas_provenance_and_short_finite_release() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Player.ART + "provenance.json")
	)
	var poses := 0
	for id in manifest.assets:
		assert_eq(FileAccess.get_sha256(Player.ART + id + ".png"), manifest.assets[id].sha256)
		poses += int(manifest.assets[id].frames)
	assert_eq(poses, 34)
	var fx := Player.new()
	add_child(fx)
	fx.configure({ }, Vector2(130, 200), 128)
	fx.confirm([Vector2(194, 232)], [Vector2(194, 232)], [])
	assert_true(fx.confirmed)
	fx._process(.5)
	assert_true(fx.closed, "Direct cast fully releases in less than half a second")
	await wait_process_frames(1)
