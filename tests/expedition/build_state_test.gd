extends Node

const Factory = preload("res://test/support/factory.gd")
var _checks := 0
var _failures: Array[String] = []
var _builds: Array[ExpeditionBuildState] = []
var _fields: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_loadout_atomicity()
	_test_canonical_start_and_discoveries()
	_test_specialists_and_budget()
	_test_cards_and_families()
	_test_snapshot_atomicity()
	_test_correction()
	_test_every_spell_casts()
	_test_sacrifice_and_healing()
	_test_movement_control_and_durations()
	_test_doctrine_roots_runtime()
	_test_equipment_catalog_and_runtime()
	_cleanup()
	print("Expedition build: %d checks, %d failures" % [_checks, _failures.size()])
	for message in _failures:
		printerr(message)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _build(unit: Unit = null) -> ExpeditionBuildState:
	var state := CharacterRunState.new()
	state.unit = unit if unit != null else Factory.make_unit()
	state.character_id = &"achilles"
	state.loadout = SpellLoadoutState.new()
	state.loadout.changed.connect(state.sync_loadout_to_unit)
	var build := ExpeditionBuildState.new()
	_check(build.initialize(state), "Build initialization")
	_builds.append(build)
	return build


func _field(cols: int, rows: int):
	var field = Factory.make_battlefield(cols, rows)
	_fields.append(field)
	return field


func _cleanup() -> void:
	for build in _builds:
		build.character_state.dispose()
		build.character_state = null
	_builds.clear()
	for field in _fields:
		for unit in field.grid.get_units():
			unit.active_statuses.clear()
			unit.clear_shield()
			field.grid.remove_unit(unit)
		field.terrain.runtime_service.reset()
		_disconnect_signals(field.terrain.runtime_service)
		_disconnect_signals(field.grid)
	_fields.clear()


func _disconnect_signals(object: Object) -> void:
	for definition in object.get_signal_list():
		for connection in object.get_signal_connection_list(definition.name):
			object.disconnect(definition.name, connection.callable)


func _test_loadout_atomicity() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var loadout := SpellLoadoutState.new()
	loadout.initialize(catalog.base_spells(), 4)
	_check(loadout.resize_slots(5), "Fifth slot opens")
	_check(loadout.learn_spell(catalog.get_spell("exp_crochet")), "Spell learned")
	_check(loadout.equip_spell(&"exp_crochet", 4), "Equip fifth")
	_check(not loadout.resize_slots(4), "Occupied slot cannot be silently discarded")
	var original := loadout.to_snapshot()
	var invalid := original.duplicate(true)
	invalid.equipped_spell_ids[4] = invalid.equipped_spell_ids[0]
	_check(not loadout.restore_snapshot(invalid, catalog.all_spells()), "Duplicate active spell rejected")
	_check(loadout.to_snapshot() == original, "Rejected snapshot leaves loadout untouched")
	invalid = original.duplicate(true)
	invalid.known_spell_ids.append("res://arbitrary_resource.tres")
	_check(not loadout.restore_snapshot(invalid, catalog.all_spells()), "Unknown resource paths rejected")
	_check(loadout.restore_snapshot(JSON.parse_string(JSON.stringify(original)), catalog.all_spells()), "JSON loadout round trip")
	loadout.unequip_slot(2)
	_check(loadout.get_spell_slot_ids()[2] == &"" and loadout.get_spell_slot_ids()[4] == &"exp_crochet", "Empty slots preserve indices")
	_check(not loadout.resize_slots(7), "Seventh slot refused")


func _test_specialists_and_budget() -> void:
	for axis in ExpeditionBuildCatalog.AXES:
		if axis == "serment":
			continue
		var build := _build()
		_check(not build.purchase(axis + ".learn_a").success, "No precombat purchase " + axis)
		_check(not build.purchase(axis + ".signature").success, "Early signature blocked " + axis)
		for depth in range(1, 21):
			_check(build.grant_depth_reward(depth).success, "Depth granted %s %d" % [axis, depth])
			_check(not build.grant_depth_reward(depth).success, "Reward duplicate refused")
		_check(build.points == 24, "Run grants exactly 24 mastery points " + axis)
		var doctrine := build.catalog.doctrine_for_axis(axis)
		if not doctrine.is_empty():
			_check(build.purchase(doctrine + ".root").success, "Doctrine root " + axis)
		else:
			_check(build.unlock_branch(axis).success, "Discovered elemental branch")
		for suffix in ["learn_a", "learn_b", "mutation", "signature", "liaison_a", "legend", "liaison_b"]:
			_check(build.purchase(axis + "." + suffix).success, "Specialist node " + axis + suffix)
		var remaining := 14 if doctrine.is_empty() else 13
		_check(build.points == remaining, "Specialist leaves a hybrid budget " + axis)
		build.sync_level(5)
		_check(build.character_state.loadout.get_active_slot_count() == 5, "Level five capacity")
		_check(build.choose_depth_eight("slot").success, "Sixth-slot choice")
		_check(not build.choose_depth_eight("mutation").success, "Milestone choices exclusive")
		_check(build.character_state.loadout.get_active_slot_count() == 6, "Six-slot cap")
		var restored := _build()
		var serialized: Dictionary = JSON.parse_string(JSON.stringify(build.to_snapshot()))
		_check(restored.restore_snapshot(serialized), "Full specialist JSON restore " + axis)
		_check(restored.points == remaining, "Restore does not mint points")


func _advance(build: ExpeditionBuildState, depth: int) -> void:
	for current in range(build.completed_depth + 1, depth + 1):
		_check(build.grant_depth_reward(current).success, "Advance to " + str(current))


func _test_canonical_start_and_discoveries() -> void:
	var build := _build()
	var initial := build.to_snapshot()
	_check(build.points == 0, "Canonical start has no build currency")
	_check(not build.equip("", 3), "Cannot discard starter guard before the first combat")
	_check(not build.learn_spell_card("exp_crochet").success, "Cannot learn a card before first victory")
	_check(not build.purchase("colere.root").success, "Root cannot alter first combat")
	_check(build.to_snapshot() == initial, "Starting kit remains untouched")
	for index in build.catalog.base_spells().size():
		_check(build.character_state.loadout.get_equipped_spells()[index] == build.catalog.base_spells()[index], "Canonical resource identity preserved")
	_check(not build.unlock_branch("elements").success, "Discovery cannot occur early")
	_advance(build, 1)
	_check(build.purchase("colere.root").success, "First victory unlocks a base spell improvement")
	_check(build.purchase("briseur.learn_a").success, "First victory can also buy a new spell")
	_check(not build.purchase("chasseur.learn_a").success, "Other doctrine requires its root")
	_advance(build, 4)
	_check(not build.purchase("elements.learn_a").success, "Elemental branch remains sealed without discovery")
	_check(not build.learn_spell_card("exp_braise").success, "Card cannot bypass discovery")
	_check(build.unlock_branch("elements").success, "Sanctuary can discover elements at IV")
	_check(build.purchase("elements.learn_a").success, "Discovered branch teaches a real elemental spell")
	_check(not build.unlock_branch("elements").success, "Discovery is idempotent")
	_advance(build, 8)
	_check(build.unlock_branch("serment").success, "Styx branch appears at VIII")
	_check(build.purchase("serment.rempart").success, "A sanctuary serment can be learned")
	_check(not build.purchase("serment.brasier").success, "Serments are mutually exclusive")
	build.sync_level(5)
	_check(not build.choose_depth_eight("slot").success, "Sixth slot is not awarded at VIII anymore")
	_advance(build, 12)
	_check(build.choose_depth_eight("slot").success, "Sixth slot offered at XII")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(build.to_snapshot()))
	var restored := _build()
	_check(restored.restore_snapshot(snapshot), "Discoveries and exclusive branch survive JSON restore")
	_check(restored.is_axis_discovered("elements") and restored.is_axis_discovered("serment"), "Access persists")
	var bad := snapshot.duplicate(true)
	bad.discovered_branches = []
	_check(not restored.restore_snapshot(bad), "Purchased discovered branches require persisted access")
	_check(restored.to_snapshot() == build.to_snapshot(), "Rejected discovery restore is atomic")
	bad = initial.duplicate(true)
	bad.loadout.equipped_spell_ids[3] = ""
	_check(not _build().restore_snapshot(bad), "Starting loadout cannot be forged on disk")


func _test_cards_and_families() -> void:
	var build := _build()
	_advance(build, 2)
	_check(build.learn_spell_card("exp_crochet").success, "Card learns technique")
	_check(build.points == 3 and build.character_state.loadout.get_active_slot_count() == 4, "Card neither spends points nor adds a slot")
	_check(not build.purchase("briseur.learn_a").success, "Already taught learning cannot waste points")
	_check(build.purchase("briseur.mutation").success, "Card opens structural branch")
	_check(build.equip("exp_crochet", 3), "Offense replaces Guard")
	_check(not build.equip("exp_crochet_mutation", 2), "Two forms of a family cannot occupy slots")
	_check(build.equip("exp_crochet_mutation", 3), "Family replacement in same slot")
	_check(not build.learn_spell_card("exp_crochet_legend").success, "Cards cannot bypass legend gate")
	_check(not build.learn_spell_card("exp_crochet").success, "Repeated card refused")
	build.is_editable = false
	_check(not build.equip("achilles_bronze_guard", 3), "Combat locks equipment changes")
	_check(not build.learn_spell_card("exp_braise").success, "Combat locks learning")
	_check(not build.purchase("briseur.liaison_a").success, "Combat locks purchases")


func _test_snapshot_atomicity() -> void:
	var build := _build()
	_advance(build, 2)
	build.learn_spell_card("exp_crochet")
	build.purchase("briseur.mutation")
	build.equip("exp_crochet_mutation", 3)
	for depth in range(3, 13):
		build.grant_depth_reward(depth)
	build.sync_level(5)
	build.choose_depth_eight("mutation")
	var good := build.to_snapshot()
	_check(build.restore_snapshot(JSON.parse_string(JSON.stringify(good))), "Card-unlocked mutation and milestone restore")
	for key in ["points", "current_level", "completed_depth"]:
		var bad := good.duplicate(true)
		bad[key] = 99
		_check(not build.restore_snapshot(bad), "Invalid scalar rejected: " + key)
		_check(build.to_snapshot() == good, "Invalid scalar restore atomic")
	var bad := good.duplicate(true)
	bad.loadout.known_spell_ids.append("exp_entaille_legend")
	_check(not build.restore_snapshot(bad), "Unearned legend knowledge rejected")
	_check(build.to_snapshot() == good, "Unearned restore atomic")
	bad = good.duplicate(true)
	bad.loadout.equipped_spell_ids[1] = "achilles_peleid_strike"
	bad.loadout.equipped_spell_ids[0] = "exp_tempest"
	_check(not build.restore_snapshot(bad), "Two family forms rejected on disk")
	_check(build.to_snapshot() == good, "Family rejection atomic")
	bad = good.duplicate(true)
	bad.unlocked_node_ids.append("sang.legend")
	_check(not build.restore_snapshot(bad), "Missing prerequisites rejected")
	_check(build.to_snapshot() == good, "Prerequisite rejection atomic")


func _test_every_spell_casts() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	_check(catalog.card_spell_ids().size() == 15, "Fifteen autonomous techniques")
	_check(catalog.nodes.size() == 55, "Seven axes, three original doctrine roots, two exclusive serments")
	var classified: Array[String] = []
	for entry in catalog.get_action_classifications():
		_check(not classified.has(String(entry.ability_id)) and catalog.get_spell(String(entry.ability_id)) != null, "Unique known classification " + String(entry.ability_id))
		classified.append(String(entry.ability_id))
	for spell in catalog.all_spells():
		if String(spell.spell_id).begins_with("exp_"):
			_check(classified.has(String(spell.spell_id)), "Every experimental action explicitly classified " + spell.spell_name)
		var field = _field(12, 12)
		var hero := Factory.make_unit("Achille")
		var enemy := Factory.make_unit("Cible", 1)
		hero.current_hp = 60
		hero.set_meta(ExpeditionSpellModifier.ENTRY_HP_META, 100)
		hero.set_meta(ExpeditionSpellModifier.HEAL_BUDGET_META, 30)
		field.grid.place_unit(hero, Vector2i(5, 5))
		var target := Vector2i(5, 5 + maxi(1, spell.minimum_range))
		if spell.is_self_only():
			field.grid.place_unit(enemy, Vector2i(6, 5))
			target = hero.grid_pos
		elif spell.caster_movement != Spell.CasterMovement.NONE:
			field.grid.place_unit(enemy, Vector2i(6, 5))
		else:
			field.grid.place_unit(enemy, target)
		var report: Dictionary = field.caster.cast(hero, spell, target)
		_check(not bool(report.get("failed", false)), "Actual SpellCaster cast " + spell.spell_name + ": " + str(report.get("reason", "")))
		_check(hero.current_ap == 6 - spell.ap_cost, "Real AP payment " + spell.spell_name)
		if spell.deals_damage():
			_check(enemy.current_hp < 100, "Real damage " + spell.spell_name)
		if spell.caster_movement != Spell.CasterMovement.NONE:
			_check(hero.grid_pos == target, "Real movement " + spell.spell_name)
		if spell.damage_scaling != null:
			_check(spell.damage_scaling.is_valid(), "Valid scaling " + spell.spell_name)
		_check(spell.skill_tree == null or not String(spell.spell_id).begins_with("exp_"), "Experimental forms do not attach legacy trees")
	# Deep duplication must not mutate parent spells when configuring variants.
	_check(is_equal_approx((catalog.get_spell("exp_entaille").modifiers[0] as ExpeditionSpellModifier).sacrifice_fraction, 0.05), "Variant retains independent modifiers")
	_check((catalog.get_spell("exp_feinte").modifiers[0] as ExpeditionSpellModifier).temporary_stats.has("esquive"), "Mobility mutation leaves original defense intact")


func _test_correction() -> void:
	var build := _build()
	_advance(build, 4)
	build.purchase("colere.root")
	build.purchase("briseur.learn_a")
	build.equip("exp_crochet", 3)
	build.purchase("briseur.mutation")
	_check(build.character_state.loadout.get_spell_slot_ids()[3] == &"exp_crochet_mutation", "Purchase replaces equipped family")
	build.unlock_branch("elements")
	build.learn_spell_card("exp_braise")
	build.is_editable = false
	_check(not build.undo_last_purchase().success, "Correction forbidden during combat")
	build.is_editable = true
	_check(build.undo_last_purchase().success and build.points == 3, "Latest purchase refunded once")
	_check(build.character_state.loadout.get_spell_slot_ids()[3] == &"exp_crochet", "Undo restores last remaining form")
	_check(not build.character_state.loadout.knows_spell_id(&"exp_crochet_mutation"), "Refund revokes learned form")
	_check(build.character_state.loadout.knows_spell_id(&"exp_braise"), "Refund preserves card rewards")
	_check(not build.undo_last_purchase().success, "No infinite respec")
	var restored := _build()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(build.to_snapshot()))
	_check(restored.restore_snapshot(snapshot), "Corrected build round trip")
	_check(restored.correction_used and not restored.undo_last_purchase().success, "Correction remains spent after reload")
	var first := _build()
	_advance(first, 1)
	first.purchase("colere.root")
	first.purchase("briseur.learn_a")
	first.equip("exp_crochet", 3)
	_check(first.undo_last_purchase().success and first.points == 1, "Initial learning can be corrected")
	_check(first.character_state.loadout.get_spell_slot_ids()[3] == &"", "Removed family frees its slot without inventing a spell")


func _test_sacrifice_and_healing() -> void:
	var field = _field(8, 3)
	var hero := Factory.make_unit("Achille")
	var enemy := Factory.make_unit("Cible", 1)
	field.grid.place_unit(hero, Vector2i(1, 1))
	field.grid.place_unit(enemy, Vector2i(2, 1))
	var build := _build(hero)
	build.begin_encounter("one")
	_check(build.catalog.get_spell("exp_souffle").get_scaled_heal(hero) == 8, "Heal preview uses real entry HP")
	hero.current_hp = 5
	var report: Dictionary = field.caster.cast(hero, build.catalog.get_spell("exp_entaille"), enemy.grid_pos)
	_check(bool(report.get("failed", false)), "Lethal sacrifice blocked before spending")
	_check(hero.current_ap == 6 and hero.current_hp == 5, "Rejected sacrifice changes no resources")
	hero.current_hp = 60
	hero.current_shield = 12
	report = field.caster.cast(hero, build.catalog.get_spell("exp_entaille"), enemy.grid_pos)
	_check(hero.current_hp == 55 and hero.current_shield == 12, "HP cost bypasses shields without damaging them")
	_check(build.get_healing_reserve() == 20, "Sacrifice never recharges reserve")
	hero.start_turn()
	enemy.current_hp = 1
	report = field.caster.cast(hero, build.catalog.get_spell("exp_moisson"), enemy.grid_pos)
	_check(int(report.get("healing_total", 0)) == 0, "Overkill cannot fund lifesteal (half of one HP floors to zero)")
	hero.start_turn()
	report = field.caster.cast(hero, build.catalog.get_spell("exp_souffle"), hero.grid_pos)
	_check(int(report.get("healing_total", 0)) == 8, "Percent heal uses entry max HP")
	_check(build.get_healing_reserve() == 12, "Healing spends actual reserve")
	_check(not build.begin_encounter("one") and build.get_healing_reserve() == 12, "Duplicate encounter start cannot refill reserve")
	hero.start_turn()
	field.caster.cast(hero, build.catalog.get_spell("exp_souffle"), hero.grid_pos)
	hero.start_turn()
	report = field.caster.cast(hero, build.catalog.get_spell("exp_souffle"), hero.grid_pos)
	_check(bool(report.get("failed", false)), "Two-use limit is enforced by Unit")
	hero.set_meta(ExpeditionSpellModifier.HEAL_BUDGET_META, 2)
	_check(build.catalog.get_spell("exp_souffle_legend").get_scaled_heal(hero) == 2, "Heal preview respects remaining shared reserve")
	_check(build.catalog.get_spell("exp_souffle_legend").get_scaled_heal(hero, 100) == 2, "Additional healing modifiers cannot exceed reserve")
	var legacy_heal := Spell.new()
	legacy_heal.heal = 13
	_check(legacy_heal.get_scaled_heal(hero, 3) == 16, "Historical flat heal plus bonus unchanged")
	hero.start_turn()
	report = field.caster.cast(hero, build.catalog.get_spell("exp_souffle_legend"), hero.grid_pos)
	_check(int(report.get("healing_total", 0)) == 2 and build.get_healing_reserve() == 0, "Different healing form shares remaining budget")
	_check(build.begin_encounter("two") and build.get_healing_reserve() == 20, "New occurrence resets reserve")


func _test_movement_control_and_durations() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var field = _field(9, 3)
	var hero := Factory.make_unit("Achille")
	var enemy := Factory.make_unit("Cible", 1)
	field.grid.place_unit(hero, Vector2i(1, 1))
	field.grid.place_unit(enemy, Vector2i(3, 1))
	field.caster.cast(hero, catalog.get_spell("exp_crochet"), enemy.grid_pos)
	_check(enemy.grid_pos == Vector2i(2, 1), "Crochet creates melee contact")
	field.caster.cast(hero, catalog.get_spell("exp_heurt"), enemy.grid_pos)
	_check(enemy.grid_pos == Vector2i(3, 1), "Heurt opens melee contact")
	hero.start_turn()
	field.caster.cast(hero, catalog.get_spell("exp_posture"), hero.grid_pos)
	_check(hero.armure.get_int() == 45, "Posture immediately protects")
	hero.start_turn()
	_check(hero.armure.get_int() == 0 and hero.current_mp == 2, "Posture expires at next activation and charges its MP price")
	field.caster.cast(hero, catalog.get_spell("exp_feinte"), Vector2i(1, 2))
	_check(is_equal_approx(hero.esquive.get_value(), 0.25), "Feinte creates actual dodge window")
	hero.start_turn()
	_check(is_zero_approx(hero.esquive.get_value()), "Dodge expires next activation")
	field.caster.cast(hero, catalog.get_spell("exp_givre"), enemy.grid_pos)
	enemy.start_turn()
	enemy.process_statuses()
	_check(enemy.current_mp == 2, "Givre actually reduces target MP")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _equipment_field() -> Dictionary:
	var field = _field(12, 5)
	var hero := Factory.make_unit("Achille")
	var enemy := Factory.make_unit("Épreuve", 1)
	field.grid.place_unit(hero, Vector2i(1, 2))
	field.grid.place_unit(enemy, Vector2i(3, 2))
	var build := _build(hero)
	build.character_state.equipment_loadout = EquipmentLoadout.new()
	build.character_state.equipment_loadout.initialize(&"achilles")
	var catalog := ExpeditionEquipmentCatalog.merge_into(null)
	var inventory := RunInventory.new()
	inventory.initialize(catalog)
	var equipment := EquipmentService.new()
	equipment.initialize(catalog)
	return {"field": field, "hero": hero, "enemy": enemy, "build": build,
		"catalog": catalog, "inventory": inventory, "equipment": equipment}


func _test_doctrine_roots_runtime() -> void:
	var field = _field(8, 3)
	var hero := Factory.make_unit("Achille")
	var enemy := Factory.make_unit("Armure", 1)
	enemy.armure.base_value = 30
	field.grid.place_unit(hero, Vector2i(1, 1))
	field.grid.place_unit(enemy, Vector2i(2, 1))
	var catalog := ExpeditionBuildCatalog.new()
	field.caster.cast(hero, catalog.get_spell("exp_frappe_ouverte"), enemy.grid_pos)
	_check(enemy.armure.get_int() == 15, "Colère root exposes actual target armor")
	hero.start_turn()
	field.caster.cast(hero, catalog.get_spell("exp_garde_eaque"), hero.grid_pos)
	_check(hero.current_shield == 12 and hero.resist_magique.get_int() == 10, "Éaque root increases guard and temporary magic resistance")
	hero.start_turn()
	_check(hero.current_shield == 0 and hero.resist_magique.get_int() == 0, "Éaque root protection expires at next activation")
	enemy.armure.base_value = 0
	enemy.active_statuses.clear()
	field.grid.relocate_unit(enemy, Vector2i(5, 1))
	var before := enemy.current_hp
	field.caster.cast(hero, catalog.get_spell("exp_tir_de_guet"), enemy.grid_pos)
	_check(before - enemy.current_hp == 12, "Chiron root's four-cell shot bonus is real")


func _equip_item(test: Dictionary, id: StringName) -> void:
	_check(test.inventory.try_add(id).success, "Grant equipment " + String(id))
	var instance: ItemInstance = null
	for candidate in test.inventory.get_slots():
		if candidate != null and candidate.definition_id == id:
			instance = candidate
	var definition: ItemDefinition = test.catalog.get_definition(id)
	_check(instance != null and test.equipment.equip(test.inventory, test.build.character_state,
		instance.instance_id, definition.equipment_slot).success, "Real equipment transaction " + String(id))


func _test_equipment_catalog_and_runtime() -> void:
	var catalog := ExpeditionEquipmentCatalog.merge_into(null)
	_check(catalog.rebuild_index() and catalog.get_definitions().size() == 12, "Twelve valid unique equipment definitions")
	_check(ExpeditionEquipmentCatalog.merge_into(catalog).get_definitions().size() == 12, "Catalog merge does not duplicate equipment")
	for axis in ExpeditionBuildCatalog.AXES:
		_check(not ExpeditionEquipmentCatalog.item_ids(axis).is_empty(), "Equipment supports axis " + axis)
	for definition in catalog.get_definitions():
		var test := _equipment_field()
		_check(definition.is_compatible_with(&"achilles") and not definition.is_compatible_with(&"orpheus"), "Achilles equipment compatibility")
		_equip_item(test, definition.item_id)
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(test.build.character_state.equipment_loadout.to_snapshot()))
		var loaded := EquipmentLoadout.new()
		loaded.initialize(&"achilles")
		_check(loaded.restore_snapshot(snapshot, catalog), "Equipment loadout JSON " + String(definition.item_id))
		_check(test.equipment.unequip(test.inventory, test.build.character_state, definition.equipment_slot).success, "Unequip " + String(definition.item_id))
		_check(test.hero.get_equipment_spell_modifiers().is_empty(), "Unequip removes runtime effects " + String(definition.item_id))
		_check(test.hero.max_hp.get_int() == 100 and test.hero.max_mp.get_int() == 3, "Unequip restores base stats " + String(definition.item_id))
	var t := _equipment_field()
	_equip_item(t, &"catabase_levier")
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_crochet"), t.enemy.grid_pos)
	_check(t.hero.get_equipment_condition_facts(t.enemy).target_moved_or_collided, "Crochet records authoritative moved-target condition")
	var before: int = t.enemy.current_hp
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_peleid_strike"), t.enemy.grid_pos)
	_check(before - t.enemy.current_hp == 14, "Levier rewards real Crochet then Frappe combo")
	t = _equipment_field()
	_equip_item(t, &"catabase_lame_sang")
	t.field.grid.relocate_unit(t.enemy, Vector2i(2, 2))
	t.hero.current_hp = 43
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_entaille"), t.enemy.grid_pos)
	_check(t.hero.current_hp == 38 and t.enemy.current_hp == 79, "Sacrifice opens 40-percent weapon window before damage")
	t = _equipment_field()
	_equip_item(t, &"catabase_javeline")
	var report: Dictionary = t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_pelion_shot"), t.enemy.grid_pos)
	_check(report.get("failed", false) and t.hero.current_ap == 6, "Javeline's enlarged blind spot rejects near targets without costs")
	t.field.grid.relocate_unit(t.enemy, Vector2i(8, 2))
	report = t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_pelion_shot"), t.enemy.grid_pos)
	_check(not report.get("failed", false) and t.enemy.current_hp == 87, "Javeline extends actual range and rewards distance")
	t = _equipment_field()
	_equip_item(t, &"catabase_xiphos_danse")
	t.field.grid.relocate_unit(t.enemy, Vector2i(4, 2))
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_feinte"), Vector2i(3, 2))
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_peleid_strike"), t.enemy.grid_pos)
	_check(t.enemy.current_hp == 86, "Xiphos rewards two cells actually moved by Feinte")
	t = _equipment_field()
	_equip_item(t, &"catabase_masse_airain")
	t.field.grid.relocate_unit(t.enemy, Vector2i(2, 2))
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_posture"), t.hero.grid_pos)
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_heurt"), t.enemy.grid_pos)
	_check(t.enemy.current_hp == 89, "Masse turns effective Posture armor into bounded Heurt damage")
	t = _equipment_field()
	_equip_item(t, &"catabase_fer_braise")
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_givre"), t.enemy.grid_pos)
	_check(t.enemy.current_hp == 95, "Fournaise buffs direct elemental damage")
	t.field.grid.relocate_unit(t.enemy, Vector2i(2, 2))
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_peleid_strike"), t.enemy.grid_pos)
	_check(t.enemy.current_hp == 86, "Fournaise also applies its physical drawback")
	t = _equipment_field()
	_equip_item(t, &"catabase_cuirasse")
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_bronze_guard"), t.hero.grid_pos)
	_check(t.hero.current_shield == 13 and t.hero.max_mp.get_int() == 2, "Cuirasse strengthens actual shield at a movement cost")
	t = _equipment_field()
	_equip_item(t, &"catabase_lin_survivant")
	t.build.begin_encounter("linen")
	t.hero.current_hp = 40
	report = t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_souffle"), t.hero.grid_pos)
	_check(report.healing_total == 11 and t.build.get_healing_reserve() == 12, "Lin increases real heal and spends the same finite reserve")
	t.hero.start_turn()
	t.hero.set_meta(ExpeditionSpellModifier.HEAL_BUDGET_META, 2)
	report = t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_souffle"), t.hero.grid_pos)
	_check(report.healing_total == 2 and t.build.get_healing_reserve() == 0, "Equipment cannot bypass healing reserve")
	t = _equipment_field()
	_equip_item(t, &"catabase_sceau_chasse")
	t.field.grid.relocate_unit(t.enemy, Vector2i(2, 2))
	t.enemy.current_hp = 30
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_peleid_strike"), t.enemy.grid_pos)
	_check(t.enemy.current_hp == 16 and t.hero.max_hp.get_int() == 90, "Sceau grants execution damage with real HP drawback")
	t = _equipment_field()
	_equip_item(t, &"catabase_prisme")
	t.field.grid.relocate_unit(t.enemy, Vector2i(7, 2))
	report = t.field.caster.cast(t.hero, t.build.catalog.get_spell("exp_givre"), t.enemy.grid_pos)
	_check(not report.get("failed", false) and t.enemy.current_hp == 96, "Prisme extends elemental range through shared targeting")
	t = _equipment_field()
	_equip_item(t, &"catabase_agrafe")
	t.field.grid.relocate_unit(t.enemy, Vector2i(2, 2))
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_bronze_guard"), t.hero.grid_pos)
	t.field.caster.cast(t.hero, t.build.catalog.get_spell("achilles_peleid_strike"), t.enemy.grid_pos)
	_check(t.enemy.current_hp == 87 and t.hero.current_shield == 10, "Agrafe rewards preserved guard without consuming or creating it")
