extends GutTest
const Text := preload("res://ui/expedition/catabase_card_text.gd")
const Hover := preload("res://ui/expedition/spell_hover_card.gd")
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const Factory := preload("res://test/support/factory.gd")


class ReachBonus:
	extends SpellModifier
	func get_range_bonus(_caster, _spell) -> int:
		return 2


	func ignores_minimum_range(_caster, _spell) -> bool:
		return true


func test_range_uses_targeting_resolver_and_self_casts() -> void:
	var actor := Factory.make_unit()
	var spell := Catalog.make_spell("r_slow", 2)
	assert_eq(Text.range_text(spell, actor), "2–4")
	spell.modifiers.append(ReachBonus.new())
	assert_eq(Text.range_text(spell, actor), "0–6")
	assert_string_contains(Text.effect(spell, actor), "Portée : 0–6")
	for id in Catalog.pool():
		var card := Catalog.make_spell(id, 4, true)
		var resolver := SpellCaster.new(null, null, null)
		assert_eq(
			Text.range_text(card, actor),
			(
				"sur soi"
				if card.is_self_only()
				else "%d–%d"
				% [
					resolver.get_effective_spell_minimum_range(actor, card),
					resolver.get_effective_spell_range(actor, card),
				]
			),
			id,
		)


func test_hover_is_delayed_passive_outside_bar_and_disappears() -> void:
	var actor := Factory.make_unit()
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 720)
	add_child_autofree(surface)
	var viewport := Vector2(surface.size)
	var bar := Control.new()
	bar.position = Vector2(10, viewport.y - 170)
	bar.size = Vector2(viewport.x - 20, 160)
	surface.add_child(bar)
	var button := Button.new()
	button.size = Vector2(120, 90)
	bar.add_child(button)
	var controller = Hover.attach(button, Catalog.make_spell("t_mark", 2), actor, bar)
	button.mouse_entered.emit()
	assert_null(controller._panel, "does not pop up during a quick pointer crossing")
	await get_tree().create_timer(.30).timeout
	await get_tree().process_frame
	var panel: Control = controller._panel
	assert_true(panel.visible)
	assert_false(
		panel.get_global_rect().intersects(bar.get_global_rect()),
		"panel %s / bar %s" % [panel.get_global_rect(), bar.get_global_rect()],
	)
	assert_true(
		Rect2(Vector2.ZERO, viewport).encloses(panel.get_global_rect()),
		"viewport %s / panel %s" % [viewport, panel.get_global_rect()],
	)
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in panel.find_children("*", "Control", true, false):
		if child.is_visible_in_tree():
			assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE, str(child.get_path()))
	var effects: RichTextLabel = panel.find_child("SpellHoverEffects", true, false)
	assert_string_contains(effects.text, "[color=")
	assert_false(button.has_focus(), "hover never steals keyboard focus")
	button.mouse_exited.emit()
	assert_false(panel.visible)
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	await get_tree().create_timer(.30).timeout
	assert_false(panel.visible, "no delayed ghost after leaving")


func test_deck_tile_resolves_grid_after_configuration() -> void:
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 720)
	add_child_autofree(surface)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 320)
	scroll.size = Vector2(630, 330)
	surface.add_child(scroll)
	var grid := GridContainer.new()
	scroll.add_child(grid)
	var tile := preload("res://ui/expedition/class_card_tile.gd").new()
	tile.configure(Catalog.make_spell("t_step", 2), Factory.make_unit(), "Au deck")
	grid.add_child(tile)
	var hover = tile.find_child("SpellHoverController", true, false)
	assert_eq(hover.exclusion, scroll, "configuration precedes attachment to the grid")
	hover._pointer = true
	hover._show()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(hover._panel.get_global_rect().intersects(scroll.get_global_rect()))
	assert_true(Rect2(Vector2.ZERO, Vector2(surface.size)).encloses(hover._panel.get_global_rect()))


func test_every_class_effect_fits_above_the_hand() -> void:
	var actor := Factory.make_unit()
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 720)
	add_child_autofree(surface)
	var viewport := Vector2(surface.size)
	var bar := Control.new()
	bar.position = Vector2(10, viewport.y - 170)
	bar.size = Vector2(viewport.x - 20, 160)
	surface.add_child(bar)
	var button := Button.new()
	button.size = Vector2(120, 90)
	bar.add_child(button)
	var hover = Hover.attach(button, Catalog.make_spell("t_mark", 4, true), actor, bar)
	for id in Catalog.pool():
		hover.spell = Catalog.make_spell(id, 4, true)
		hover._pointer = true
		hover._show()
		await get_tree().process_frame
		await get_tree().process_frame
		var rect: Rect2 = hover._panel.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, viewport).encloses(rect), id + " remains within viewport")
		assert_false(rect.intersects(bar.get_global_rect()), id + " leaves every card accessible")
