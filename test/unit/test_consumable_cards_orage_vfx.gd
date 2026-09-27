extends "res://test/unit/test_consumable_cards_effects.gd"
const Orage := preload("res://vfx/class_cards/orage/player.gd")
const Router := preload("res://vfx/class_cards/class_card_vfx_router.gd")


func test_orage_evidence_respects_real_area_allies_and_death() -> void:
	var f := field_for("thaumaturge")
	assert_true(f.grid.relocate_unit(f.target, Vector2i(3, 2)))
	assert_true(f.grid.relocate_unit(f.hero, Vector2i(3, 3)))
	f.target.current_hp = 1
	var ally := Factory.make_unit("Ally", 0)
	f.grid.place_unit(ally, Vector2i(2, 3))
	var far := Factory.make_unit("Far", 1)
	f.grid.place_unit(far, Vector2i(3, 0))
	var spell := force_hand(f, "l01")
	var report: Dictionary = f.caster.cast(f.hero, spell, f.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(report.card_vfx.origin, Vector2i(3, 3))
	assert_eq(report.card_vfx.targets.size(), 1)
	assert_eq(report.card_vfx.targets[0].cell, Vector2i(3, 2))
	assert_true(f.target in report.damaged_enemies)
	assert_false(f.target.is_alive, "A killed target still retains its contact position")
	assert_eq(ally.current_hp, 100)
	assert_eq(far.current_hp, 100)
	assert_eq(f.terrain.active_surface_cells().size(), 0)
	assert_eq(spell.ap_cost, 3)
	assert_eq(spell.modifiers.size(), 1, "One original gameplay modifier")


func test_orage_upgrade_changes_damage_without_extra_hits_or_targets() -> void:
	var damage: Array[int] = []
	for upgraded in [false, true]:
		var f := field_for("thaumaturge")
		if upgraded:
			f.cards.upgraded_ids.append("l01")
		var spell := force_hand(f, "l01")
		var report: Dictionary = f.caster.cast(f.hero, spell, f.hero.grid_pos)
		assert_false(report.get("failed", false))
		assert_eq(report.damaged_enemies.size(), 1)
		damage.append(int(report.hp_damage_total))
	assert_gt(damage[1], damage[0])


func test_orage_charge_waits_then_only_confirmed_points_discharge() -> void:
	var fx := Orage.new()
	add_child(fx)
	fx.configure({ "id": "cc2_l01", "orage_preparing": true }, Vector2.ZERO, 128)
	fx.manual = true
	fx.sample(.8)
	assert_false(fx.confirmed)
	assert_lt(fx._clock, fx.CONTACT)
	assert_eq(fx.sheets.size(), 2)
	fx.set_impacts([Vector2(100, 20), Vector2(100, 20), Vector2(-100, 20)])
	assert_eq(fx.hit_points.size(), 2)
	for sheet in fx.sheets:
		if sheet.id == "bolt":
			assert_false(sheet.sprite.visible)
	fx.confirm()
	assert_eq(fx.elapsed, .3)
	var contact_frames := []
	for sheet in fx.sheets:
		if sheet.id == "bolt":
			assert_true(sheet.sprite.visible)
			contact_frames.append(sheet.sprite.frame)
	assert_eq(contact_frames, [0, 0], "One simultaneous contact frame")
	fx.sample(.91)
	for sheet in fx.sheets:
		assert_false(sheet.sprite.visible, "No persistent storm")
	fx.cancel()
	assert_true(fx.closed)
	await wait_process_frames(1)


func test_orage_cancel_removes_actor_parented_crown_and_no_damage_sheets() -> void:
	var view := Node2D.new()
	add_child(view)
	var fx := Orage.new()
	add_child(fx)
	fx.configure({ "id": "cc2_l01", "orage_preparing": true }, Vector2.ZERO, 128, view)
	assert_eq(view.get_child_count(), 2)
	fx.cancel()
	await wait_process_frames(1)
	assert_eq(view.get_child_count(), 0)
	view.queue_free()


func test_orage_empty_confirmation_dissipates_without_inventing_targets() -> void:
	var fx := Orage.new()
	add_child(fx)
	fx.configure({ "id": "cc2_l01", "orage_preparing": true }, Vector2.ZERO, 128)
	fx.manual = true
	fx.confirm()
	assert_true(fx.hit_points.is_empty())
	assert_eq(fx.sheets.size(), 2)
	fx.cancel()
	await wait_process_frames(1)


func test_orage_assets_match_authored_rgba_exports() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Orage.ART + "provenance.json")
	)
	assert_eq(manifest.assets.size(), 4)
	for id in manifest.assets:
		var asset: Dictionary = manifest.assets[id]
		assert_eq(FileAccess.get_sha256(Orage.ART + id + ".png"), asset.sha256)
		assert_eq(asset.rendered_frames.size(), int(asset.frames))


class OrageHost:
	extends Node2D
	var units: Array = []


class OrageGridView:
	extends Node2D
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


func test_orage_router_failure_deduplication_and_real_report() -> void:
	var f := field_for("thaumaturge")
	var session := ExpeditionSession.new()
	session.cards = f.cards
	f.hero.set_meta("ct_session", weakref(session))
	var host := OrageHost.new()
	add_child(host)
	host.units.assign([f.hero, f.target])
	var grid_view := OrageGridView.new()
	host.add_child(grid_view)
	var manager: Node = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	manager.register_battle_view(grid_view)
	var router: Node = manager._class_card_router
	var spell := force_hand(f, "l01")
	var cancelled_fx: Node = router.prepare_sentence(f.hero, spell, f.hero.grid_pos)
	assert_not_null(cancelled_fx)
	router.resolve(f.hero, spell, { "failed": true })
	assert_true(cancelled_fx.closed)
	assert_true(router.sentence_preparations.is_empty())
	var fx: Node = router.prepare_sentence(f.hero, spell, f.hero.grid_pos)
	fx.manual = true
	var report: Dictionary = f.caster.cast(f.hero, spell, f.hero.grid_pos)
	assert_false(report.get("failed", false))
	router.resolve(f.hero, spell, report)
	assert_true(fx.confirmed)
	assert_eq(fx.hit_points.size(), 1)
	var count: int = router.effects.size()
	router.resolve(f.hero, spell, report)
	assert_eq(router.effects.size(), count)
	assert_true(router.echoes.is_empty())
	manager.unregister_battle_view()
	assert_true(fx.closed)
	manager.queue_free()
	host.queue_free()
	await wait_process_frames(1)


func test_orage_border_area_has_no_outside_cells() -> void:
	var f := field_for("thaumaturge")
	f.grid.relocate_unit(f.hero, Vector2i.ZERO)
	f.grid.relocate_unit(f.target, Vector2i(1, 0))
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "l01"), f.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(report.card_vfx.cells.size(), 6)
	assert_eq(report.card_vfx.targets.size(), 1)
	for cell in report.card_vfx.cells:
		assert_true(f.grid.is_valid(cell))
		assert_lte(f.grid.manhattan(f.hero.grid_pos, cell), 2)


class WithoutPresentation:
	extends "res://core/expedition/consumable_card_modifier.gd"
	func on_targets_finalized(_ctx) -> void:
		pass


func test_orage_evidence_has_no_damage_or_resource_side_effect() -> void:
	var outcomes := []
	for observed in [false, true]:
		var f := field_for("thaumaturge")
		var spell := force_hand(f, "l01")
		if not observed:
			var plain := WithoutPresentation.new()
			plain.card = Catalog.card("l01")
			spell.modifiers[0] = plain
		var report: Dictionary = f.caster.cast(f.hero, spell, f.hero.grid_pos)
		assert_eq(report.has("card_vfx"), observed)
		outcomes.append(
			[report.hp_damage_total, f.hero.current_ap, f.target.current_hp, f.target.grid_pos]
		)
	assert_eq(outcomes[0], outcomes[1])


func test_orage_wall_filters_out_occluded_enemy_and_cell() -> void:
	var f := field_for("thaumaturge")
	assert_true(f.grid.relocate_unit(f.target, Vector2i(3, 1)))
	assert_true(f.grid.relocate_unit(f.hero, Vector2i(3, 3)))
	f.grid.set_type(Vector2i(3, 2), GridData.CellType.WALL)
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "l01"), f.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_false(Vector2i(3, 1) in report.card_vfx.cells)
	assert_true(report.card_vfx.targets.is_empty())
	assert_true(report.damaged_enemies.is_empty())
	assert_eq(f.target.current_hp, 500)
