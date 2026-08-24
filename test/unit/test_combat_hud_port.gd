extends GutTest

const COMBAT_HUD_PORT := preload("res://ui/combat/combat_hud_port.gd")


class FakeHud extends CanvasLayer:
	signal move_pressed
	signal attack_pressed
	signal spell_pressed(spell)
	signal end_turn_pressed
	signal item_activation_requested(instance_id)

	var controls_enabled := false
	var info_unit = null
	var actions_unit = null
	var active_mode := ""
	var active_spell = null
	var last_snapshot: Dictionary = {}
	var feedback := ""
	var bound_context: Node = null

	func set_player_controls_enabled(enabled: bool) -> void:
		controls_enabled = enabled

	func are_player_controls_enabled() -> bool:
		return controls_enabled

	func update_info(unit) -> void:
		info_unit = unit

	func build_spell_buttons(unit) -> void:
		actions_unit = unit

	func set_active_mode(mode: String, spell = null) -> void:
		active_mode = mode
		active_spell = spell

	func apply_presentation_snapshot(snapshot: Dictionary) -> void:
		last_snapshot = snapshot.duplicate(true)
		controls_enabled = bool(snapshot.get("controls_enabled", false))

	func show_context_feedback(message: String, _kind: StringName) -> void:
		feedback = message

	func bind_combat_context(context: Node) -> void:
		bound_context = context

	func unbind_combat_context() -> void:
		bound_context = null

	func get_combat_context() -> Node:
		return bound_context


class FakeContext extends Node:
	var intents: Array = []

	func _on_move_pressed() -> void:
		intents.append(&"move")

	func _on_attack_pressed() -> void:
		intents.append(&"attack")

	func _on_spell_pressed(spell) -> void:
		intents.append([&"spell", spell])

	func _on_end_turn_pressed() -> void:
		intents.append(&"end_turn")

	func _on_item_activation_requested(instance_id: StringName) -> void:
		intents.append([&"item", instance_id])


func test_port_audits_and_drives_the_smallest_shared_contract() -> void:
	var hud := FakeHud.new()
	add_child_autofree(hud)
	var port = COMBAT_HUD_PORT.new(hud)
	var audit: Dictionary = port.audit_contract()
	assert_true(audit["valid"])
	assert_true(audit["supports_presentation_snapshot"])
	assert_true(audit["supports_context_binding"])
	assert_true(audit["supports_items"])

	var unit := RefCounted.new()
	port.set_controls_enabled(true)
	port.update_info(unit)
	port.build_actions(unit)
	port.set_active_mode("spell", unit)
	port.apply_presentation_snapshot({"controls_enabled": false})
	port.show_feedback("Hors de portee", &"warning")
	assert_false(port.are_controls_enabled())
	assert_same(hud.info_unit, unit)
	assert_same(hud.actions_unit, unit)
	assert_eq(hud.active_mode, "spell")
	assert_same(hud.active_spell, unit)
	assert_eq(hud.feedback, "Hors de portee")


func test_port_owns_exactly_one_reversible_intent_binding() -> void:
	var hud := FakeHud.new()
	var context := FakeContext.new()
	add_child_autofree(hud)
	add_child_autofree(context)
	var port = COMBAT_HUD_PORT.new(hud)
	assert_true(port.connect_intents(context))
	assert_eq(port.get_connection_count(), 5)
	assert_same(port.get_connected_context(), context)

	hud.move_pressed.emit()
	hud.attack_pressed.emit()
	hud.spell_pressed.emit(&"spell_a")
	hud.end_turn_pressed.emit()
	hud.item_activation_requested.emit(&"relic_a")
	assert_eq(context.intents, [
		&"move",
		&"attack",
		[&"spell", &"spell_a"],
		&"end_turn",
		[&"item", &"relic_a"],
	])

	port.connect_intents(context)
	assert_eq(port.get_connection_count(), 5, "Le rebind reste idempotent")
	port.disconnect_intents()
	hud.move_pressed.emit()
	assert_eq(context.intents.size(), 5)
	assert_null(port.get_connected_context())


func test_legacy_action_bar_satisfies_the_port_without_scene_migration() -> void:
	var legacy := CanvasLayer.new()
	legacy.set_script(load("res://ui/action_bar.gd"))
	var port = COMBAT_HUD_PORT.new(legacy)
	var audit: Dictionary = port.audit_contract()
	assert_true(audit["valid"], str(audit))
	assert_false(audit["supports_context_binding"])
	legacy.free()
