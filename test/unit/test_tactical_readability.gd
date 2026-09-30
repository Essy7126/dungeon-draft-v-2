extends GutTest

const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
const Hover := preload("res://battle/tactical_hover_preview.gd")
const GridView := preload("res://battle/grid_view.gd")
const Marker := preload("res://battle/combat_highlight_marker.gd")
var field
var hero: Unit
var enemy: Unit


class BattleFixture:
	extends "res://battle/battle.gd"
	func _ready() -> void:
		pass


func before_each() -> void:
	field = Factory.make_battlefield(9, 7)
	hero = Factory.make_unit("Achille", 0)
	enemy = Factory.make_unit("Gardien", 1)
	field.grid.place_unit(hero, Vector2i(2, 3))
	field.grid.place_unit(enemy, Vector2i(5, 3))


func after_each() -> void:
	Cleanup.dispose_grid(field.grid)


func test_unit_targeted_spell_shows_empty_cells_without_allowing_casts_on_them() -> void:
	var spell := Factory.make_spell({ "spell_range": 4, "can_target_free_cell": false })
	var empty_cell := Vector2i(4, 3)
	assert_has(field.caster.get_spell_range_cells(hero, spell), empty_cell)
	assert_does_not_have(field.caster.get_targetable_cells(hero, spell), empty_cell)
	assert_has(field.caster.get_targetable_cells(hero, spell), enemy.grid_pos)
	assert_false(field.caster.can_cast(hero, spell, empty_cell))


func test_range_shares_minimum_bonus_line_and_sight_constraints() -> void:
	var spell := Factory.make_spell(
		{
			"spell_range": 3,
			"minimum_range": 2,
			"line_from_caster": true,
			"needs_line_of_sight": true,
		}
	)
	var bonus := SpellModRangeBonus.new()
	bonus.range_bonus = 2
	spell.modifiers.append(bonus)
	var cells: Array = field.caster.get_spell_range_cells(hero, spell)
	assert_has(cells, Vector2i(7, 3), "Le bonus réel est visible")
	assert_does_not_have(cells, Vector2i(3, 3), "Portée minimale")
	assert_does_not_have(cells, Vector2i(4, 4), "Lancer en ligne")
	field.grid.set_type(Vector2i(4, 3), GridData.CellType.WALL)
	cells = field.caster.get_spell_range_cells(hero, spell)
	assert_does_not_have(cells, enemy.grid_pos, "Mur et ligne de vue")
	assert_does_not_have(cells, Vector2i(4, 3), "Pas de portée sur un mur")


func test_self_only_spell_has_only_the_caster_cell() -> void:
	var spell := Factory.make_spell(
		{
			"can_target_self": true,
			"can_target_enemy": false,
			"can_target_ally": false,
			"can_target_free_cell": false,
			"spell_range": 0,
		}
	)
	assert_eq(field.caster.get_spell_range_cells(hero, spell), [hero.grid_pos])
	assert_eq(field.caster.get_targetable_cells(hero, spell), [hero.grid_pos])


func _battle() -> BattleFixture:
	var battle := BattleFixture.new()
	battle.grid = field.grid
	battle.pathfinder = field.pathfinder
	battle.spell_caster = field.caster
	battle.grid_view = GridView.new()
	battle.grid_view.setup(field.grid)
	battle.add_child(battle.grid_view)
	battle.turn_state = TurnState.new()
	battle.turn_queue = TurnQueue.new()
	battle.turn_queue.setup([hero, enemy])
	battle.turn_queue._current_index = 0
	add_child_autofree(battle)
	return battle


func _hover(battle: Node2D):
	var hover := Hover.new()
	hover.battle = battle
	battle.add_child(hover)
	hover.set_process(false)
	return hover


func test_hover_enemy_uses_its_remaining_mp_and_respects_obstacles() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	enemy.current_mp = 1
	field.grid.set_type(Vector2i(5, 2), GridData.CellType.WALL)
	hover.show_unit(enemy)
	var cells: Dictionary = battle.grid_view.get_highlight_snapshot()
	assert_has(cells, Vector2i(6, 3))
	assert_does_not_have(cells, Vector2i(7, 3))
	assert_does_not_have(cells, Vector2i(5, 2))
	assert_same(battle.get_active_unit(), hero, "Survol ne sélectionne pas l'ennemi")
	assert_eq(enemy.current_mp, 1)
	assert_string_contains(hover._hint.text, "1 PM")
	hover.show_unit(null)
	assert_true(battle.grid_view.get_highlight_snapshot().is_empty())


func test_zero_mp_and_control_costs_are_visible_without_free_movement() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	hero.current_mp = 0
	hover.show_unit(hero)
	assert_lte(battle.grid_view.get_highlight_snapshot().size(), 1)
	assert_eq(hover._hint.text, "Aucun PM restant")
	field.grid.move_unit(enemy.grid_pos, Vector2i(2, 2))
	enemy.control_level = UnitData.ControlLevel.HEAVY_CONTROL
	hero.current_mp = 2
	hover.show_unit(hero)
	var snapshot: Dictionary = battle.grid_view.get_highlight_snapshot()
	assert_eq(snapshot[Vector2i(3, 3)].marker, Marker.CONTROL_LIMITED)
	assert_string_contains(hover._hint.text, "Engagement")


func test_leaving_hover_restores_movement_and_never_overwrites_spell_selection() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	battle.turn_state.current = TurnState.State.MOVE
	battle._on_request_show_move_range()
	var original: Dictionary = battle.grid_view.get_highlight_snapshot()
	hover.show_unit(enemy)
	battle._set_target_hover_feedback(Vector2i.ZERO, false)
	hover.show_unit(enemy)
	assert_true(
		battle.grid_view.get_cell_feedback_snapshot().is_empty(),
		"Le corps survolé masque les cases situées derrière",
	)
	hover.show_unit(null)
	assert_eq(battle.grid_view.get_highlight_snapshot(), original)
	hover.show_unit(enemy)
	var spell := Factory.make_spell({ "spell_range": 4 })
	battle.turn_state.current = TurnState.State.TARGET_SPELL
	battle.turn_state.selected_spell = spell
	battle._on_request_show_spell_range(spell)
	var spell_cells: Dictionary = battle.grid_view.get_highlight_snapshot()
	hover.show_unit(enemy)
	assert_eq(battle.grid_view.get_highlight_snapshot(), spell_cells)
	assert_false(hover._panel.visible)
	assert_has(spell_cells, Vector2i(4, 3))
	assert_eq(spell_cells[Vector2i(4, 3)].marker, &"")
	assert_eq(spell_cells[enemy.grid_pos].marker, Marker.SPELL)


func test_lock_clears_passive_range_and_hover_panel() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	hover.show_unit(hero)
	battle.presentation_state = CombatPresentationState.new()
	battle.presentation_state.set_lock(&"inventory", true)
	hover.show_unit(hero)
	assert_false(hover._panel.visible)
	assert_true(battle.grid_view.get_highlight_snapshot().is_empty())


func test_pointer_can_find_torso_and_leaving_map_returns_nothing() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	var view := Node2D.new()
	view.position = Vector2(320, 220)
	battle.add_child(view)
	battle._unit_views[enemy] = view
	assert_same(hover.pick_unit(Vector2(320, 185)), enemy)
	assert_null(hover.pick_unit(Vector2(-40, -40)))
	assert_eq(battle.grid_view.world_to_grid(Vector2(-1, -1)), Vector2i(-1, -1))


func test_hover_tracks_scaled_sprite_head_and_ignores_transparent_margins() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	var view := Node2D.new()
	view.position = Vector2(900, 400)
	battle.add_child(view)
	battle._unit_views[hero] = view
	var sprite := AnimatedSprite2D.new()
	var image := Image.create(100, 160, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(40, 20, 20, 140), Color.WHITE)
	var frames := SpriteFrames.new()
	frames.add_frame(&"default", ImageTexture.create_from_image(image))
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-50, -160)
	sprite.scale = Vector2.ONE * 1.5
	view.add_child(sprite)
	assert_same(
		hover.pick_unit(Vector2(900, 200)),
		hero,
		"La tête dépasse largement le torse logique",
	)
	assert_null(
		hover.pick_unit(Vector2(845, 200)),
		"Les marges transparentes ne capturent pas le survol",
	)


func test_hover_ignores_freed_view_during_death_cleanup() -> void:
	var battle := _battle()
	var hover = _hover(battle)
	var view := Node2D.new()
	battle.add_child(view)
	battle._unit_views[enemy] = view
	view.free()
	assert_null(hover.pick_unit(Vector2(-40, -40)))
