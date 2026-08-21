extends GutTest

const TEST_ROOT := "user://relic_system"
var _services: Array[RelicRuntimeService] = []


func after_each() -> void:
	for service in _services:
		service.dispose()
	_services.clear()


func after_all() -> void:
	_remove_tree(TEST_ROOT)


func test_temporary_relic_is_valid_serializable_and_semantic() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var relic := _relic(&"serialized_relic")
	assert_true(relic.is_valid())
	var path := TEST_ROOT + "/serialized_relic.tres"
	assert_eq(ResourceSaver.save(relic, path), OK)
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	assert_not_null(restored)
	assert_true(restored.is_relic())
	assert_eq(restored.reactive_effects.size(), 1)
	assert_eq(
		ItemFingerprintService.semantic_fingerprint(restored),
		ItemFingerprintService.semantic_fingerprint(relic),
	)


func test_deep_copy_history_and_effect_operations_do_not_share_resources() -> void:
	var relic := _relic(&"copy_relic")
	var condition := ItemReactiveConditionData.new()
	condition.condition_id = &"hp_percent"
	condition.comparison = &"less_or_equal"
	condition.value = 0.5
	relic.reactive_effects[0].conditions = [condition]
	var copy := ItemDeepCopyService.new().duplicate_definition(relic)
	assert_ne(copy.reactive_effects[0], relic.reactive_effects[0])
	assert_ne(copy.reactive_effects[0].conditions[0], condition)
	copy.reactive_effects[0].conditions[0].value = 0.25
	assert_eq(condition.value, 0.5)
	assert_true(ItemDeepCopyService.new().mutable_sharing_audit(relic, copy).get("valid", false))

	var document := ItemStudioDocument.new()
	assert_true(document.create_new(relic))
	assert_true(document.record_edit("Ajouter", func(): document.working_copy.reactive_effects.append(ItemReactiveEffectData.new())))
	assert_eq(document.working_copy.reactive_effects.size(), 2)
	assert_true(document.record_edit("Dupliquer", func(): document.working_copy.reactive_effects.insert(1, ItemDeepCopyService.new().duplicate_effect(document.working_copy.reactive_effects[0]))))
	assert_ne(document.working_copy.reactive_effects[0], document.working_copy.reactive_effects[1])
	assert_true(document.record_edit("Réordonner", func(): document.working_copy.reactive_effects.reverse()))
	assert_true(document.record_edit("Retirer", func(): document.working_copy.reactive_effects.remove_at(0)))
	assert_true(document.history.undo())
	assert_true(document.history.redo())


func test_registry_filters_context_and_explains_invalid_combinations() -> void:
	var registry := RelicEffectRegistry.new()
	var effect := ItemReactiveEffectData.new()
	effect.trigger_id = ItemReactiveEffectData.TRIGGER_COMBAT_START
	effect.target_id = ItemReactiveEffectData.TARGET_DAMAGE_SOURCE
	effect.result_id = ItemReactiveEffectData.RESULT_HEAL_FLAT
	var issues := registry.validate_effect(effect)
	assert_false(issues.is_empty())
	assert_eq(issues[0].get("code"), &"REACTIVE_TARGET_INCOMPATIBLE")
	var targets := registry.compatible_descriptors(RelicEffectRegistry.KIND_TARGET, effect)
	assert_false(targets.any(func(value): return value.get("id") == ItemReactiveEffectData.TARGET_DAMAGE_SOURCE))
	effect.trigger_id = ItemReactiveEffectData.TRIGGER_HP_LOST
	assert_true(registry.validate_effect(effect).is_empty())


func test_relic_preview_reports_scenarios_frequency_resets_and_canonical_integrity() -> void:
	var relic := _relic(
		&"preview_relic",
		ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED,
		ItemReactiveEffectData.RESULT_CURRENT_AP,
		1.0,
	)
	var fingerprint := ItemFingerprintService.semantic_fingerprint(relic)
	var report := ItemRuntimePreviewService.new().preview_relic(relic)
	assert_true(report.get("ok", false), str(report))
	assert_true(report.get("canonical_unchanged", false))
	assert_eq(ItemFingerprintService.semantic_fingerprint(relic), fingerprint)
	assert_true(report.get("frequency_reset_confirmed", false))
	var resets := report.get("frequency_resets", {}) as Dictionary
	for frequency in [
		ItemReactiveEffectData.FREQUENCY_ACTION,
		ItemReactiveEffectData.FREQUENCY_TURN,
		ItemReactiveEffectData.FREQUENCY_ROUND,
		ItemReactiveEffectData.FREQUENCY_COMBAT,
	]:
		assert_true(resets.get(frequency, false), str(frequency))
	var scenarios := report.get("scenarios", []) as Array
	assert_true(scenarios.any(func(value):
		var scenario := value as Dictionary
		return scenario.get("scenario_id") == &"action_resolved" \
			and scenario.get("triggered", false) \
			and scenario.has("before") and scenario.has("after") \
			and scenario.has("remaining")
	))


func test_relic_draft_publication_and_reward_eligibility_are_isolated() -> void:
	var definitions_root := TEST_ROOT + "/publication/definitions"
	var drafts_root := TEST_ROOT + "/publication/drafts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(definitions_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(drafts_root))
	var catalog_path := TEST_ROOT + "/publication/catalog.tres"
	var resource_catalog := ItemCatalog.new()
	resource_catalog.auto_discovery_directories = PackedStringArray([definitions_root])
	assert_eq(ResourceSaver.save(resource_catalog, catalog_path), OK)
	var catalog := ItemStudioCatalogService.new()
	catalog.configure(catalog_path, drafts_root)
	assert_true(catalog.rebuild().get("ok", false))
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_relic(&"published_fixture_relic")))
	assert_true(ItemPublicationService.new().set_reward_eligibility(document, true))
	assert_true(catalog.reward_eligible(document.working_copy))
	var draft := ItemDraftService.new().save_draft(document, catalog)
	assert_true(draft.get("ok", false), str(draft))
	assert_true(draft.get("not_in_production_catalog", false))
	var published := ItemPublicationService.new().publish(document, catalog, true)
	assert_true(published.get("ok", false), str(published))
	assert_eq(published.get("catalog_occurrences"), 1)
	assert_true(published.get("reward_eligible", false))
	assert_not_null(catalog.production_catalog.get_definition(&"published_fixture_relic"))


func test_inventory_acquisition_is_unique_non_stackable_and_restorable() -> void:
	var relic := _relic(&"inventory_relic")
	var catalog := _catalog([relic])
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog))
	assert_true(inventory.try_add(relic.item_id).get("success", false))
	assert_false(inventory.try_add(relic.item_id).get("success", true))
	assert_false(inventory.can_accept(relic.item_id, 2))
	var snapshot := inventory.to_snapshot()
	var restored := RunInventory.new()
	assert_true(restored.initialize(catalog))
	assert_true(restored.restore_snapshot(snapshot))
	assert_true(restored.contains_definition(relic.item_id))
	assert_eq(restored.get_empty_slot_count(), 23)


func test_runtime_activates_multiple_relics_and_respects_combat_frequency() -> void:
	var first := _relic(&"first_relic", ItemReactiveEffectData.TRIGGER_COMBAT_START, ItemReactiveEffectData.RESULT_CURRENT_AP, 1.0)
	first.reactive_effects[0].frequency_id = ItemReactiveEffectData.FREQUENCY_COMBAT
	var second := _relic(&"second_relic", ItemReactiveEffectData.TRIGGER_COMBAT_START, ItemReactiveEffectData.RESULT_CURRENT_MP, 2.0)
	var catalog := _catalog([first, second])
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog))
	inventory.try_add(first.item_id)
	inventory.try_add(second.item_id)
	var hero := _unit(&"runtime_hero", 0)
	var service := _service(inventory, catalog, [hero])
	service.begin_combat([hero])
	assert_eq(service.active_relic_count(), 2)
	assert_eq(hero.current_ap, 7)
	assert_eq(hero.current_mp, 5)
	service.process_trigger(ItemReactiveEffectData.TRIGGER_COMBAT_START, {"eligible_heroes": [hero]})
	assert_eq(hero.current_ap, 7, "La fréquence combat bloque le second déclenchement")
	assert_eq(hero.current_mp, 7, "La seconde relique sans limite coexiste")
	service.end_combat()
	service.begin_combat([hero])
	assert_eq(hero.current_ap, 8, "Le compteur combat est réinitialisé")


func test_runtime_reentrancy_guard_and_action_turn_round_scopes() -> void:
	var relic := _relic(&"scoped_relic", ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, ItemReactiveEffectData.RESULT_CURRENT_AP, 1.0)
	relic.reactive_effects[0].frequency_id = ItemReactiveEffectData.FREQUENCY_ACTION
	var catalog := _catalog([relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	inventory.try_add(relic.item_id)
	var hero := _unit(&"scope_hero", 0)
	var service := _service(inventory, catalog, [hero])
	service.begin_combat([hero])
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, {"trigger_hero": hero, "active_unit": hero, "action_id": &"a"})
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, {"trigger_hero": hero, "active_unit": hero, "action_id": &"a"})
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, {"trigger_hero": hero, "active_unit": hero, "action_id": &"b"})
	assert_eq(hero.current_ap, 8)


func test_turn_round_and_cooldown_frequencies_reset_automatically() -> void:
	var turn_relic := _relic(&"turn_frequency", ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, ItemReactiveEffectData.RESULT_CURRENT_AP, 1.0)
	turn_relic.reactive_effects[0].frequency_id = ItemReactiveEffectData.FREQUENCY_TURN
	var round_relic := _relic(&"round_frequency", ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, ItemReactiveEffectData.RESULT_CURRENT_MP, 1.0)
	round_relic.reactive_effects[0].frequency_id = ItemReactiveEffectData.FREQUENCY_ROUND
	var catalog := _catalog([turn_relic, round_relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	inventory.try_add(turn_relic.item_id)
	inventory.try_add(round_relic.item_id)
	var hero := _unit(&"frequency_hero", 0)
	var service := _service(inventory, catalog, [hero])
	service.begin_combat([hero])
	EventBus.round_started.emit(1)
	EventBus.turn_started.emit(hero)
	var context := {"trigger_hero": hero, "active_unit": hero, "action_id": &"one"}
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, context)
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, context)
	assert_eq(hero.current_ap, 7)
	assert_eq(hero.current_mp, 4)
	EventBus.turn_started.emit(hero)
	context.action_id = &"two"
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, context)
	assert_eq(hero.current_ap, 8)
	assert_eq(hero.current_mp, 4)
	EventBus.round_started.emit(2)
	context.action_id = &"three"
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, context)
	assert_eq(hero.current_mp, 5)


func test_reinitialization_does_not_duplicate_event_subscriptions() -> void:
	var relic := _relic(&"subscription_relic", ItemReactiveEffectData.TRIGGER_COMBAT_START, ItemReactiveEffectData.RESULT_CURRENT_AP, 1.0)
	var catalog := _catalog([relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	inventory.try_add(relic.item_id)
	var hero := _unit(&"subscription_hero", 0)
	var service := _service(inventory, catalog, [hero])
	assert_true(service.initialize(inventory, catalog, [hero]))
	EventBus.combat_started.emit([hero], null)
	assert_eq(hero.current_ap, 7)


func test_damage_source_threshold_and_nonlethal_health_cost_are_distinct() -> void:
	var threshold_relic := _relic(
		&"threshold_relic",
		ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED,
		ItemReactiveEffectData.RESULT_HEAL_FLAT,
		10.0,
	)
	threshold_relic.reactive_effects[0].threshold = 0.5
	var enemy_condition := ItemReactiveConditionData.new()
	enemy_condition.condition_id = &"enemy_source_required"
	threshold_relic.reactive_effects[0].conditions = [enemy_condition]
	var cost_relic := _relic(
		&"health_cost_relic",
		ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED,
		ItemReactiveEffectData.RESULT_PAY_HP_FLAT,
		200.0,
	)
	var catalog := _catalog([threshold_relic, cost_relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	inventory.try_add(threshold_relic.item_id)
	inventory.try_add(cost_relic.item_id)
	var hero := _unit(&"damage_hero", 0)
	var enemy := _unit(&"damage_enemy", 1)
	var service := _service(inventory, catalog, [hero])
	service.begin_combat([hero, enemy])
	hero.current_hp = 40
	EventBus.hp_damage_taken.emit(CombatEventFact.create(
		&"hp_damage_taken", hero, null,
		{"amount_applied": 20, "action_id": &"terrain"},
	))
	assert_eq(hero.current_hp, 40, "Les dégâts sans source ennemie ne satisfont pas la condition")
	EventBus.hp_damage_taken.emit(CombatEventFact.create(
		&"hp_damage_taken", hero, enemy,
		{"amount_applied": 20, "action_id": &"enemy_hit"},
	))
	assert_eq(hero.current_hp, 50, "Le franchissement 60 % vers 40 % déclenche le soin")
	var costs: Array[Dictionary] = []
	var on_cost := func(unit, amount: int, metadata: Dictionary):
		costs.append({"unit": unit, "amount": amount, "metadata": metadata})
	EventBus.health_cost_paid.connect(on_cost)
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, {
		"trigger_hero": hero, "active_unit": hero, "action_id": &"cost_action",
	})
	EventBus.health_cost_paid.disconnect(on_cost)
	assert_eq(hero.current_hp, 1, "Un coût de PV de relique ne peut pas tuer")
	assert_eq(costs.size(), 1)
	assert_eq(costs[0].metadata.get("origin"), &"relic")


func test_direct_interception_consumes_its_configured_frequency() -> void:
	var relic := _relic(
		&"interception_relic",
		ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED,
		ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS,
	)
	relic.reactive_effects[0].frequency_id = ItemReactiveEffectData.FREQUENCY_COMBAT
	var catalog := _catalog([relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	inventory.try_add(relic.item_id)
	var hero := _unit(&"intercept_hero", 0)
	var service := _service(inventory, catalog, [hero])
	service.begin_combat([hero])
	var context := {
		"voluntary": true, "interceptable": true, "distance": 2,
		"action_id": &"move_once",
	}
	assert_true(service.try_intercept(
		hero, ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, context
	))
	assert_false(service.try_intercept(
		hero, ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, context
	))


func test_movement_discount_is_used_by_reachable_preview_and_payment_cost() -> void:
	var relic := _relic(&"movement_relic", ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, ItemReactiveEffectData.RESULT_REDUCE_VOLUNTARY_MOVE_COST, 1.0)
	var catalog := _catalog([relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	inventory.try_add(relic.item_id)
	var hero := _unit(&"move_hero", 0)
	hero.grid_pos = Vector2i(0, 0)
	var grid := GridData.new(4, 1)
	grid.place_unit(hero, hero.grid_pos)
	var service := _service(inventory, catalog, [hero])
	service.begin_combat([hero], grid)
	var pathfinder := Pathfinder.new(grid)
	pathfinder.set_voluntary_cost_modifier(Callable(service, "modify_voluntary_transition_cost"))
	var path := pathfinder.find_path(Vector2i(0, 0), Vector2i(3, 0), hero)
	var breakdown := pathfinder.path_cost_breakdown(path, hero)
	assert_eq(breakdown.get("unmodified_total"), 3)
	assert_eq(breakdown.get("total"), 0)
	assert_true(pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero).has(Vector2i(3, 0)))
	assert_true(hero.spend_mp(int(breakdown.get("total", -1))))
	assert_eq(hero.current_mp, 3)


func test_reward_accepts_relic_without_character_and_excludes_owned() -> void:
	var first := _relic(&"reward_relic_a")
	var second := _relic(&"reward_relic_b")
	first.tags = [FirstRunEquipmentRewardService.POOL_TAG]
	second.tags = [FirstRunEquipmentRewardService.POOL_TAG]
	var catalog := _catalog([first, second])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	var reward := FirstRunEquipmentRewardService.new()
	assert_true(reward.reset(catalog, 42))
	var report := CombatReport.new()
	report.report_id = &"relic_reward_report"
	report.victory = true
	report.finalized = true
	var options := reward.build_options(report, [], inventory)
	assert_eq(options.size(), 2)
	var selected_id := StringName(options[0].get("item_id", &""))
	var result := reward.apply(report, selected_id, &"", [], inventory)
	assert_true(result.get("success", false))
	assert_eq(result.get("target_character_id"), &"")
	assert_false(result.get("equipped", true))
	assert_true(inventory.contains_definition(selected_id))


func test_inventory_screen_marks_relic_active_and_hides_actions() -> void:
	var relic := _relic(&"ui_relic")
	var catalog := _catalog([relic])
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	var added := inventory.try_add(relic.item_id)
	var unit_data := UnitData.new()
	unit_data.unit_id = &"ui_hero"
	unit_data.unit_name = "Héros UI"
	var hero := Unit.from_data(unit_data)
	var state := CharacterRunState.new()
	assert_true(state.initialize(hero, unit_data))
	var screen := preload("res://ui/inventory/InventoryScreen.tscn").instantiate() as InventoryScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	screen._selected_instance_id = StringName((added.get("instance_ids", []) as Array)[0])
	screen._refresh_details(state, inventory, catalog)
	assert_true(screen._modifier_summary.text.contains("ACTIVE POUR LA RUN"))
	assert_false(screen._equip_button.visible)
	assert_false(screen._use_button.visible)
	assert_false(screen._unequip_button.visible)
	screen._rebuild_inventory(inventory, catalog)
	var item_button := screen._inventory_grid.get_child(0) as Button
	assert_true(item_button.text.contains("Relique active"))
	state.dispose()


func test_inventory_relic_layout_remains_responsive_at_supported_resolutions() -> void:
	var screen := preload("res://ui/inventory/InventoryScreen.tscn").instantiate() as InventoryScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080)]:
		screen.apply_viewport_size_for_test(viewport_size)
		await get_tree().process_frame
		var snapshot := screen.get_layout_snapshot()
		var panel_size := snapshot.get("panel_minimum_size") as Vector2
		assert_lte(panel_size.x, viewport_size.x - 48.0, str(viewport_size))
		assert_lte(panel_size.y, viewport_size.y - 40.0, str(viewport_size))
		assert_eq(
			int(snapshot.get("inventory_columns")),
			3 if viewport_size.x < 1500.0 else 4,
		)


func test_turn_end_fact_is_emitted_once() -> void:
	var hero := _unit(&"turn_hero", 0)
	var queue := TurnQueue.new()
	queue.setup([hero])
	queue.start()
	var battle := preload("res://battle/battle.gd").new()
	battle.turn_queue = queue
	var count := [0]
	var callback := func(_unit, _reason): count[0] += 1
	EventBus.turn_ended.connect(callback)
	assert_true(battle._finish_active_turn(&"test"))
	assert_false(battle._finish_active_turn(&"duplicate"))
	assert_eq(count[0], 1)
	EventBus.turn_ended.disconnect(callback)
	battle.free()


func _relic(
		item_id: StringName,
		trigger_id: StringName = ItemReactiveEffectData.TRIGGER_COMBAT_START,
		result_id: StringName = ItemReactiveEffectData.RESULT_HEAL_FLAT,
		value := 1.0
	) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = item_id
	definition.display_name = "Relique temporaire %s" % item_id
	definition.description = "Fixture isolée de test."
	definition.category = ItemDefinition.Category.RELIC
	definition.equipment_slot = ItemDefinition.EquipmentSlot.NONE
	definition.stack_limit = 1
	var effect := ItemReactiveEffectData.new()
	effect.trigger_id = trigger_id
	effect.target_id = ItemReactiveEffectData.TARGET_TRIGGER_HERO
	effect.result_id = result_id
	effect.value = value
	definition.reactive_effects = [effect]
	return definition


func _catalog(definitions: Array) -> ItemCatalog:
	var typed: Array[ItemDefinition] = []
	for definition in definitions:
		typed.append(definition as ItemDefinition)
	var catalog := ItemCatalog.new()
	catalog.definitions = typed
	assert_true(catalog.rebuild_index())
	return catalog


func _unit(unit_id: StringName, team: int) -> Unit:
	var unit := Unit.new(str(unit_id), team, 100, 10, 6, 3, 20)
	unit.unit_id = unit_id
	return unit


func _service(inventory: RunInventory, catalog: ItemCatalog, heroes: Array) -> RelicRuntimeService:
	var service := RelicRuntimeService.new()
	assert_true(service.initialize(inventory, catalog, heroes))
	_services.append(service)
	return service


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
