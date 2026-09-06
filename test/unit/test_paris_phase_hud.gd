extends GutTest

const HUD_SCENE := preload("res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn")
const PARIS_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"
const SPECTRAL_KIT: Array[StringName] = [
	&"paris_spectral_arrow", &"paris_fire_arrow", &"paris_ice_arrow",
	&"paris_vortex_arrow", &"paris_vortex_step",
]
const INFERNAL_KIT: Array[StringName] = [
	&"paris_infernal_whip", &"paris_infernal_sweep", &"paris_infernal_pull",
	&"paris_vortex_step",
]


class CombatContext extends Node:
	var active_unit: Unit

	func get_active_unit() -> Unit:
		return active_unit

	func get_combat_presentation_snapshot() -> Dictionary:
		return {"phase_name": &"ENEMY_ACTING", "ownership": &"enemy", "controls_enabled": false}


func test_active_hud_switches_rendered_portrait_and_real_slots_only_below_twenty_percent() -> void:
	var data := load(PARIS_PATH) as UnitData
	var original_frames := data.preview_sprite_frames
	var original_spells := data.spells.duplicate()
	var unit := Unit.from_data(data)
	var context := _context(unit)
	var hud = _hud(context)
	var spectral_buttons: Array = hud.get("_spell_buttons").duplicate()
	_assert_portrait(hud, original_frames)
	_assert_kit(hud, SPECTRAL_KIT)

	unit.take_damage(96)
	assert_eq(unit.current_hp, 24)
	assert_eq(unit.combat_form_id, &"spectral")
	_assert_portrait(hud, original_frames)
	assert_eq(hud.get("_spell_buttons"), spectral_buttons, "HP refreshes preserve the current slots")
	unit.take_damage(1)
	assert_eq(unit.current_hp, 23)
	assert_eq(unit.combat_form_id, &"infernal")
	_assert_portrait(hud, data.combat_form_change.preview_sprite_frames)
	_assert_kit(hud, INFERNAL_KIT)
	for old_button: Button in spectral_buttons:
		assert_true(old_button.is_queued_for_deletion())
		assert_true(old_button.is_blocking_signals(), "An obsolete arrow cannot emit a late command")
	assert_eq(unit.character_data, data)
	assert_eq(data.preview_sprite_frames, original_frames)
	assert_eq(data.spells, original_spells)

	var infernal_buttons: Array = hud.get("_spell_buttons").duplicate()
	var rendered_portrait := _portrait(hud)
	assert_true(unit.spend_ap(1))
	unit.grant_current_activation_mp_bonus(1)
	assert_eq(hud.get("_spell_buttons"), infernal_buttons, "PA/PM signals do not rebuild the new kit")
	assert_eq(_portrait(hud), rendered_portrait, "Resource updates do not recreate the portrait")
	_assert_kit(hud, INFERNAL_KIT)


func test_hud_rebind_disconnects_old_form_and_displays_infernal_state_on_return() -> void:
	var data := load(PARIS_PATH) as UnitData
	var first := Unit.from_data(data)
	var second := Unit.from_data(data)
	var first_context := _context(first)
	var second_context := _context(second)
	var hud = _hud(first_context)
	var callback := Callable(hud, "_on_combat_form_changed")
	hud.bind_combat_context(first_context)
	assert_eq(_callback_count(first, callback), 1, "Repeated bind keeps one phase listener")
	hud.bind_combat_context(second_context)
	assert_false(first.combat_form_changed.is_connected(callback))
	assert_eq(_callback_count(second, callback), 1)
	var second_buttons: Array = hud.get("_spell_buttons").duplicate()
	first.take_damage(97)
	_assert_portrait(hud, data.preview_sprite_frames)
	_assert_kit(hud, SPECTRAL_KIT)
	assert_eq(hud.get("_spell_buttons"), second_buttons, "The previous room cannot refresh current slots")

	hud.bind_combat_context(first_context)
	_assert_portrait(hud, data.combat_form_change.preview_sprite_frames)
	_assert_kit(hud, INFERNAL_KIT)
	assert_false(second.combat_form_changed.is_connected(callback))
	hud.unbind_combat_context()
	assert_false(first.combat_form_changed.is_connected(callback))
	assert_null(hud.get("_portrait_view").character_data)
	assert_true(hud.get("_spell_buttons").is_empty())
	assert_false(hud.visible)


func test_phase_change_preserves_item_tab_and_reassigns_shortcuts_to_infernal_slots() -> void:
	var unit := Unit.from_data(load(PARIS_PATH) as UnitData)
	var hud = _hud(_context(unit))
	hud._set_active_bar_mode("item")
	unit.take_damage(97)
	assert_eq(hud.get_active_bar_mode(), "item")
	_assert_portrait(hud, unit.combat_form_change.preview_sprite_frames)
	_assert_kit(hud, INFERNAL_KIT)
	for button: Button in hud.get("_spell_buttons"):
		assert_null(button.shortcut, "Hidden spell slots do not intercept item shortcuts")
	for button: Button in hud.get("_item_buttons"):
		assert_not_null(button.shortcut)
	hud._set_active_bar_mode("spell")
	var buttons: Array = hud.get("_spell_buttons")
	for index in buttons.size():
		var shortcut: Shortcut = buttons[index].shortcut
		assert_not_null(shortcut)
		assert_eq((shortcut.events[0] as InputEventKey).physical_keycode, KEY_1 + index)
	for button: Button in hud.get("_item_buttons"):
		assert_null(button.shortcut)


func test_freeing_hud_disconnects_live_form_hp_and_stats_callbacks() -> void:
	var unit := Unit.from_data(load(PARIS_PATH) as UnitData)
	var hud = _hud(_context(unit))
	var phase_callback := Callable(hud, "_on_combat_form_changed")
	var resource_callback := Callable(hud, "_on_resource_changed")
	assert_true(unit.combat_form_changed.is_connected(phase_callback))
	assert_true(unit.hp_changed.is_connected(resource_callback))
	assert_true(unit.stats_changed.is_connected(resource_callback))
	hud.queue_free()
	await wait_process_frames(2)
	assert_eq(unit.combat_form_changed.get_connections().size(), 0)
	assert_eq(unit.hp_changed.get_connections().size(), 0)
	assert_eq(unit.stats_changed.get_connections().size(), 0)
	unit.take_damage(97)
	assert_eq(unit.combat_form_id, &"infernal")


func _context(unit: Unit) -> CombatContext:
	var context := CombatContext.new()
	context.active_unit = unit
	add_child_autofree(context)
	return context


func _hud(context: CombatContext):
	var hud := HUD_SCENE.instantiate()
	add_child_autofree(hud)
	hud.set_reduced_motion(true)
	hud.bind_combat_context(context)
	return hud


func _portrait(hud) -> AnimatedSprite2D:
	return hud.get("_portrait_view").character_preview.get_sprite_instance()


func _assert_portrait(hud, expected: SpriteFrames) -> void:
	var portrait: RecraftPortraitView = hud.get("_portrait_view")
	assert_true(portrait.character_preview.visible)
	assert_true(portrait.character_preview.is_using_sprite_preview())
	var sprite := _portrait(hud)
	assert_not_null(sprite)
	assert_eq(sprite.sprite_frames, expected)
	assert_eq(sprite.animation, &"idle_E")
	assert_eq(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame), expected.get_frame_texture(&"idle_E", 0))
	assert_false(sprite.is_playing())
	assert_false(portrait.portrait_texture.visible)


func _assert_kit(hud, expected: Array[StringName]) -> void:
	var slots: Array = hud.get("_spell_buttons")
	var unit: Unit = hud.get("_current_unit")
	assert_eq(slots.size(), expected.size())
	for index in mini(slots.size(), expected.size()):
		var slot := slots[index] as RecraftSpellSlotView
		var spell := slot.get_meta("spell") as Spell
		assert_eq(spell, unit.spells[index], "The button uses the actual runtime spell resource")
		assert_eq(slot.spell, spell)
		assert_eq(spell.spell_id, expected[index])
		assert_not_null(spell.icon)
		assert_eq(slot.spell_icon.texture, spell.icon)
		assert_eq(slot.cost_label.text, str(unit.get_spell_ap_cost(spell)))
		assert_true(slot.disabled, "The HUD does not grant player control over Paris")


func _callback_count(unit: Unit, callback: Callable) -> int:
	var count := 0
	for connection: Dictionary in unit.combat_form_changed.get_connections():
		if connection.callable == callback:
			count += 1
	return count
