extends GutTest

const Factory = preload("res://test/support/factory.gd")
const PAINTED_BATTLE_SCENE := preload(
	"res://data/rooms/maps/painted_battle.tscn"
)


class UnitAnchor:
	extends Node2D

	var unit: Unit = null


func before_each() -> void:
	ImpactJuice.juice_enabled = true
	Engine.time_scale = 1.0
	GameManager.set_reduced_motion_enabled(false)


func after_each() -> void:
	Engine.time_scale = 1.0
	GameManager.set_reduced_motion_enabled(false)
	ImpactJuice.juice_enabled = true


func test_normal_damage_creates_one_local_burst_and_deduplicates_event_id() -> void:
	var controller := _add_controller()
	var target := Factory.make_unit("Cible", 1)
	_add_anchor(target, Vector2(180.0, 120.0))
	var fact := CombatEventFact.create(
		&"hp_damage_taken", target, null, {"amount_applied": 12}
	)

	EventBus.hp_damage_taken.emit(fact)
	EventBus.hp_damage_taken.emit(fact)

	var snapshot := controller.get_debug_snapshot()
	assert_eq(snapshot["burst_count"], 1)
	assert_eq(snapshot["active_burst_count"], 1)
	assert_eq(snapshot["last_burst_kind"], CombatImpactBurst.DAMAGE)
	assert_eq(snapshot["punch_count"], 0)
	assert_eq(snapshot["seen_event_count"], 1)
	assert_eq(Engine.time_scale, 1.0)


func test_effect_layer_keeps_world_transform_through_node_controller() -> void:
	var world := Node2D.new()
	world.position = Vector2(90.0, 45.0)
	world.scale = Vector2(1.25, 1.25)
	add_child_autofree(world)
	var controller := ImpactJuice.new()
	world.add_child(controller)
	var target := Factory.make_unit("Cible", 1)
	var anchor := UnitAnchor.new()
	anchor.unit = target
	anchor.position = Vector2(160.0, 110.0)
	anchor.add_to_group("unit_views")
	world.add_child(anchor)

	EventBus.hp_damage_taken.emit(CombatEventFact.create(
		&"hp_damage_taken", target, null, {"amount_applied": 8}
	))

	var effect_root := controller.get("_effect_root") as Node2D
	assert_not_null(effect_root)
	assert_eq(effect_root.z_index, 55)
	assert_eq(effect_root.get_child_count(), 1)
	var burst := effect_root.get_child(0) as Node2D
	assert_not_null(burst)
	if burst != null:
		assert_almost_eq(
			burst.to_global(Vector2.ZERO).x,
			anchor.to_global(ImpactJuice.UNIT_IMPACT_OFFSET).x,
			0.001,
		)
		assert_almost_eq(
			burst.to_global(Vector2.ZERO).y,
			anchor.to_global(ImpactJuice.UNIT_IMPACT_OFFSET).y,
			0.001,
		)


func test_production_painted_battle_instantiates_node_compatible_controller() -> void:
	var battle := PAINTED_BATTLE_SCENE.instantiate()
	var controller := battle.get_node_or_null("ImpactJuice") as ImpactJuice
	assert_not_null(controller)
	assert_true(controller is Node)
	battle.free()


func test_real_critical_resolution_uses_v2_once_despite_legacy_signals() -> void:
	var controller := _add_controller()
	var camera := _add_camera(Vector2(7.0, 9.0))
	var target := Factory.make_unit("Cible", 1)
	var attacker := Factory.make_unit("Attaquant", 0)
	_add_anchor(target, Vector2(240.0, 140.0))
	_add_anchor(attacker, Vector2(120.0, 140.0))
	await get_tree().process_frame

	target.take_damage(
		10,
		attacker,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{
			"force_crit": true,
			"ignore_defense": true,
			"cannot_be_dodged": true,
			"impact_id": &"critical_once",
		},
	)

	var snapshot := controller.get_debug_snapshot()
	assert_eq(snapshot["burst_count"], 1)
	assert_eq(snapshot["last_burst_kind"], CombatImpactBurst.CRITICAL)
	assert_eq(snapshot["punch_count"], 1)
	assert_eq(snapshot["last_punch_kind"], ImpactJuice.PUNCH_CRITICAL)
	assert_true(snapshot["owns_time_scale"])
	assert_eq(Engine.time_scale, 0.0)
	assert_false(camera.offset.is_equal_approx(Vector2(7.0, 9.0)))

	await get_tree().create_timer(0.20, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(camera.offset, Vector2(7.0, 9.0))
	assert_false(controller.get_debug_snapshot()["camera_punch_active"])
	controller.set_reduced_motion(true)


func test_reduced_motion_keeps_critical_cue_without_freeze_or_camera_punch() -> void:
	var controller := _add_controller()
	var camera := _add_camera(Vector2(4.0, 6.0))
	var target := Factory.make_unit("Cible", 1)
	_add_anchor(target, Vector2(180.0, 120.0))
	await get_tree().process_frame
	controller.set_reduced_motion(true)
	EventBus.hp_damage_taken.emit(CombatEventFact.create(
		&"hp_damage_taken",
		target,
		null,
		{"amount_applied": 16, "is_critical": true},
	))

	var snapshot := controller.get_debug_snapshot()
	assert_eq(snapshot["burst_count"], 1)
	assert_eq(snapshot["last_burst_kind"], CombatImpactBurst.CRITICAL)
	assert_eq(snapshot["punch_count"], 0)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(camera.offset, Vector2(4.0, 6.0))
	var effect_root := controller.get("_effect_root") as Node2D
	var burst := effect_root.get_child(0) as CombatImpactBurst
	assert_true(burst.get_debug_snapshot()["reduced_motion"])


func test_lethal_fact_outranks_critical_and_signature_does_not_double_punch() -> void:
	var controller := _add_controller()
	var target := Factory.make_unit("Cible", 1)
	var attacker := Factory.make_unit("Attaquant", 0)
	target.current_hp = 0
	target.is_alive = false
	_add_anchor(target, Vector2(240.0, 140.0))
	_add_anchor(attacker, Vector2(120.0, 140.0))
	var fact := CombatEventFact.create(
		&"hp_damage_taken",
		target,
		attacker,
		{"amount_applied": 40, "is_critical": true},
	)

	EventBus.hp_damage_taken.emit(fact)
	EventBus.hazard_kill.emit(target, "lave")

	var snapshot := controller.get_debug_snapshot()
	assert_eq(snapshot["burst_count"], 1)
	assert_eq(snapshot["last_burst_kind"], CombatImpactBurst.LETHAL)
	assert_eq(snapshot["punch_count"], 1)
	assert_eq(snapshot["last_punch_kind"], ImpactJuice.PUNCH_LETHAL)
	controller.set_reduced_motion(true)


func test_shield_heal_and_grant_have_distinct_bursts_without_camera_motion() -> void:
	var controller := _add_controller()
	var target := Factory.make_unit("Cible", 1)
	_add_anchor(target, Vector2(180.0, 120.0))
	controller.set_reduced_motion(true)

	EventBus.shield_absorption_resolved.emit(CombatEventFact.create(
		&"shield_absorbed", target, null, {"amount_absorbed": 7}
	))
	EventBus.heal_received.emit(CombatEventFact.create(
		&"heal_received", target, null, {"amount_applied": 6}
	))
	EventBus.shield_granted.emit(CombatEventFact.create(
		&"shield_granted", target, null, {"amount_applied": 9}
	))

	var snapshot := controller.get_debug_snapshot()
	assert_eq(snapshot["burst_count"], 3)
	assert_eq(snapshot["active_burst_count"], 3)
	assert_eq(snapshot["last_burst_kind"], CombatImpactBurst.SHIELD_GRANTED)
	assert_eq(snapshot["punch_count"], 0)
	assert_false(snapshot["owns_time_scale"])


func test_exit_tree_restores_camera_time_scale_and_disconnects_v2_signals() -> void:
	var controller := ImpactJuice.new()
	add_child(controller)
	var camera := _add_camera(Vector2(11.0, -4.0))
	var target := Factory.make_unit("Cible", 1)
	_add_anchor(target, Vector2(220.0, 120.0))
	await get_tree().process_frame
	var fact := CombatEventFact.create(
		&"hp_damage_taken",
		target,
		null,
		{"amount_applied": 15, "is_critical": true},
	)
	EventBus.hp_damage_taken.emit(fact)
	assert_eq(Engine.time_scale, 0.0)
	assert_false(camera.offset.is_equal_approx(Vector2(11.0, -4.0)))

	controller.free()

	assert_eq(Engine.time_scale, 1.0)
	assert_eq(camera.offset, Vector2(11.0, -4.0))
	assert_false(EventBus.hp_damage_taken.is_connected(
		Callable(controller, "_on_hp_damage_taken")
	))


func _add_controller() -> ImpactJuice:
	var controller := ImpactJuice.new()
	add_child_autofree(controller)
	return controller


func _add_anchor(unit: Unit, position: Vector2) -> UnitAnchor:
	var anchor := UnitAnchor.new()
	anchor.unit = unit
	anchor.position = position
	anchor.add_to_group("unit_views")
	add_child_autofree(anchor)
	return anchor


func _add_camera(base_offset: Vector2) -> Camera2D:
	var camera := Camera2D.new()
	camera.offset = base_offset
	camera.enabled = true
	add_child_autofree(camera)
	return camera
