extends GutTest

const CARD_SCENE := preload("res://ui/combat/turn_order_card.tscn")
const PARIS_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"


func test_real_form_change_updates_only_its_card_without_mutating_shared_unit_data() -> void:
	var data := load(PARIS_PATH) as UnitData
	var original := data.preview_sprite_frames
	var first := Unit.from_data(data)
	var second := Unit.from_data(data)
	var first_card := _card(first)
	var second_card := _card(second)
	assert_eq(first_card.preview.get_sprite_instance().sprite_frames, original)
	assert_eq(second_card.preview.get_sprite_instance().sprite_frames, original)
	first.take_damage(97)
	assert_eq(first.combat_form_id, &"infernal")
	assert_eq(first_card.preview.get_sprite_instance().sprite_frames,
		data.combat_form_change.preview_sprite_frames)
	assert_eq(first_card.preview.get_sprite_instance().animation, &"idle_E")
	assert_false(first_card.preview.get_sprite_instance().is_playing())
	assert_false(first_card.preview.get_sprite_instance().flip_h)
	assert_eq(second_card.preview.get_sprite_instance().sprite_frames, original)
	assert_eq(data.preview_sprite_frames, original)
	assert_eq(first.character_data, data)
	assert_eq(data.max_hp, 120)
	assert_true(first_card.tooltip_text.contains("Infernal"))
	assert_false(second_card.tooltip_text.contains("Infernal"))


func test_rebinding_and_freeing_card_disconnect_old_phase_listeners() -> void:
	var data := load(PARIS_PATH) as UnitData
	var first := Unit.from_data(data)
	var second := Unit.from_data(data)
	var card := _card(first)
	assert_true(first.combat_form_changed.is_connected(card._on_combat_form_changed))
	card.configure(second)
	assert_false(first.combat_form_changed.is_connected(card._on_combat_form_changed))
	assert_true(second.combat_form_changed.is_connected(card._on_combat_form_changed))
	first.take_damage(97)
	assert_eq(card.preview.get_sprite_instance().sprite_frames, data.preview_sprite_frames)
	card.queue_free()
	await wait_process_frames(2)
	assert_eq(second.combat_form_changed.get_connections().size(), 0)
	second.take_damage(97)
	assert_eq(second.combat_form_id, &"infernal")


func test_card_created_after_transformation_immediately_uses_infernal_portrait() -> void:
	var unit := Unit.from_data(load(PARIS_PATH) as UnitData)
	unit.take_damage(97)
	var card := _card(unit)
	assert_eq(card.preview.get_sprite_instance().sprite_frames,
		unit.combat_form_change.preview_sprite_frames)
	assert_true(card.preview.is_using_sprite_preview())
	assert_null(card.preview.get_visual_instance())
	assert_false(card.preview.viewport_container.visible)
	assert_eq(card.preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func _card(unit: Unit) -> TurnOrderCard:
	var card := CARD_SCENE.instantiate() as TurnOrderCard
	add_child_autofree(card)
	card.configure(unit)
	return card
